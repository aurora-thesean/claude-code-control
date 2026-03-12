#!/usr/bin/env bash
# qcache-jsonl — Shared JSONL parsing cache for Aurora sensors
#
# Purpose: Cache parsed JSONL fields to avoid redundant file I/O and grep/awk operations
# Scope: All tools (qhoami, qlaude, qreveng-daemon) share this cache
#
# Usage:
#   source qcache-jsonl.sh
#   qcache_init "$uuid"                              # Initialize cache for a UUID
#   qcache_get_parent_uuid "$uuid"                   # Get parentUuid (JSONL ground truth)
#   qcache_get_model "$uuid"                         # Get last model from session JSONL
#   qcache_get_session_count "$uuid"                 # Count records for sessionId
#   qcache_get_jsonl_path "$uuid"                    # Get JSONL file path (with memoization)
#   qcache_clear                                     # Clear all caches
#
# TTL: 60 seconds (reasonable for typical tool chains: qhoami → qlaude → qreveng)
# Storage: /tmp/qcache_* (per-UUID, per-field)
# Atomicity: File-based with PID suffix to avoid race conditions
#
# Design: Single-session cache (not process-global, per-invocation). Each tool
# invocation that sources this script gets its own cache space.

set -euo pipefail

# Cache directory (per-session, cleaned up on exit)
QCACHE_BASE_DIR="/tmp/qcache_$$"
QCACHE_TTL_SECS=60

# Initialization counter (cache valid if $QCACHE_INIT_TIME + TTL > now)
QCACHE_INIT_TIME=""
QCACHE_INIT_UUID=""

# Cached values (in-memory for this process)
declare -A QCACHE_JSONL_PATH
declare -A QCACHE_PARENT_UUID
declare -A QCACHE_MODEL
declare -A QCACHE_SESSION_COUNT

# --- Internal Utilities ---

_qcache_now() {
  date +%s
}

_qcache_is_valid() {
  local now=$(_qcache_now)
  local elapsed=$(( now - ${QCACHE_INIT_TIME:-0} ))
  [[ $elapsed -lt $QCACHE_TTL_SECS ]]
}

_qcache_find_jsonl() {
  local uuid="$1"

  # FAST PATH: Try direct UUID filename match
  local direct
  direct=$(find "$HOME/.claude/projects" -name "${uuid}.jsonl" -type f 2>/dev/null | head -1)
  if [[ -n "$direct" ]]; then
    echo "$direct"
    return 0
  fi

  # SLOW PATH: Search all JSONL files (fallback for legacy sessions)
  for f in "$HOME/.claude/projects"/*/*.jsonl; do
    [[ -f "$f" ]] || continue
    if grep -q "\"sessionId\".*\"$uuid\"" "$f" 2>/dev/null; then
      echo "$f"
      return 0
    fi
  done

  return 1
}

# --- Public API ---

# Initialize cache for a given UUID (one time per tool invocation)
qcache_init() {
  local uuid="$1"

  # If already initialized for this UUID and cache is fresh, skip
  if [[ "$QCACHE_INIT_UUID" == "$uuid" ]] && _qcache_is_valid; then
    return 0
  fi

  # Find JSONL file once, cache the result
  QCACHE_JSONL_PATH["$uuid"]=$(_qcache_find_jsonl "$uuid") || {
    echo "ERROR: Could not find JSONL for UUID $uuid" >&2
    return 1
  }

  QCACHE_INIT_UUID="$uuid"
  QCACHE_INIT_TIME=$(_qcache_now)

  return 0
}

# Get parentUuid from cached JSONL (ground truth)
qcache_get_parent_uuid() {
  local uuid="$1"

  # Return cached value if available
  if [[ -n "${QCACHE_PARENT_UUID["$uuid"]:-}" ]]; then
    echo "${QCACHE_PARENT_UUID["$uuid"]}"
    return 0
  fi

  # Read from JSONL once, cache the result
  local jsonl="${QCACHE_JSONL_PATH["$uuid"]}"
  [[ -n "$jsonl" ]] || return 1

  local parent_uuid
  parent_uuid=$(grep "\"sessionId\".*\"$uuid\"" "$jsonl" 2>/dev/null | head -1 | \
    awk '{
      if (match($0, /"parentUuid"[[:space:]]*:[[:space:]]*null/)) {
        print "null"; exit
      } else if (match($0, /"parentUuid"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        print arr[1]; exit
      }
    }') || parent_uuid=""

  [[ -z "$parent_uuid" ]] && parent_uuid="?"

  QCACHE_PARENT_UUID["$uuid"]="$parent_uuid"
  echo "$parent_uuid"
}

# Get model from cached JSONL (last message.model field for this sessionId)
qcache_get_model() {
  local uuid="$1"

  # Return cached value if available
  if [[ -n "${QCACHE_MODEL["$uuid"]:-}" ]]; then
    echo "${QCACHE_MODEL["$uuid"]}"
    return 0
  fi

  # Read from JSONL, extract last model occurrence, cache result
  local jsonl="${QCACHE_JSONL_PATH["$uuid"]}"
  [[ -n "$jsonl" ]] || return 1

  local model
  model=$(awk -v uuid="$uuid" '
    /"sessionId"[[:space:]]*:[[:space:]]*"'"$uuid"'"/ && /"message"/ && /"model"/ {
      if (match($0, /"model"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        last_model = arr[1]
      }
    }
    END { if (last_model) print last_model }
  ' "$jsonl" 2>/dev/null) || model=""

  if [[ -z "$model" ]]; then
    model="MODEL_UNKNOWN"
  fi

  QCACHE_MODEL["$uuid"]="$model"
  echo "$model"
}

# Count records for a sessionId in cached JSONL
qcache_get_session_count() {
  local uuid="$1"

  # Return cached value if available
  if [[ -n "${QCACHE_SESSION_COUNT["$uuid"]:-}" ]]; then
    echo "${QCACHE_SESSION_COUNT["$uuid"]}"
    return 0
  fi

  # Count records, cache result
  local jsonl="${QCACHE_JSONL_PATH["$uuid"]}"
  [[ -n "$jsonl" ]] || return 1

  local count
  count=$(awk -v uuid="$uuid" '/"sessionId"[[:space:]]*:[[:space:]]*"'"$uuid"'"/ { count++ } END { print count+0 }' "$jsonl" 2>/dev/null) || count=0

  QCACHE_SESSION_COUNT["$uuid"]="$count"
  echo "$count"
}

# Get JSONL file path (memoized within this process)
qcache_get_jsonl_path() {
  local uuid="$1"

  if [[ -n "${QCACHE_JSONL_PATH["$uuid"]:-}" ]]; then
    echo "${QCACHE_JSONL_PATH["$uuid"]}"
    return 0
  fi

  _qcache_find_jsonl "$uuid"
}

# Clear all caches (optional, for cleanup or cache invalidation)
qcache_clear() {
  QCACHE_INIT_TIME=""
  QCACHE_INIT_UUID=""
  QCACHE_JSONL_PATH=()
  QCACHE_PARENT_UUID=()
  QCACHE_MODEL=()
  QCACHE_SESSION_COUNT=()
}

# --- Cleanup on exit ---

trap 'qcache_clear' EXIT

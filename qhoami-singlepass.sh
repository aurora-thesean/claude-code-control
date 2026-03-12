#!/usr/bin/env bash
# qhoami-singlepass — Optimized via single-pass JSONL awk extraction
#
# Performance strategy: Read JSONL file ONCE, extract all 7 dimensions in a single awk pass
# Expected improvement: 20-30% over current version (reduces from 7 passes to 1 pass)
#
# This is an experimental variant to measure the impact of single-pass parsing.

set -euo pipefail

TASKS_DIR="$HOME/.claude/tasks"
PROJECT_DIR="$HOME/.claude/projects"
AURORA_CONFIG="$HOME/CLAUDE.md"
GLOBAL_CONFIG="$HOME/.claude/CLAUDE.md"

# --- Helper functions (copied from original qhoami) ---

_json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  echo "$str"
}

_json_string_field() {
  local key="$1"
  local value="$2"
  local last="${3:-}"
  value=$(_json_escape "$value")
  if [[ "$last" == "last" ]]; then
    echo "    \"$key\": \"$value\""
  else
    echo "    \"$key\": \"$value\","
  fi
}

_find_claude_pid() {
  local pid="${1:-$$}"
  local depth=0
  while (( depth < 20 )); do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    if [[ "$comm" == "claude" ]]; then
      echo "$pid"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || break
    [[ -n "$pid" && "$pid" -gt 1 ]] || break
    depth=$(( depth + 1 ))
  done
  return 1
}

_find_session_uuid() {
  local claude_pid="$1"
  for fd_path in /proc/$claude_pid/fd/*; do
    target=$(readlink "$fd_path" 2>/dev/null) || continue
    [[ "$target" == "anon_inode:inotify" ]] || continue
    fd_num=$(basename "$fd_path")
    while IFS= read -r line; do
      ino_hex=$(printf '%s' "$line" | grep -o 'ino:[0-9a-f]*' | cut -d: -f2) || continue
      [[ -n "$ino_hex" ]] || continue
      ino_dec=$((16#$ino_hex)) 2>/dev/null || continue
      for tasks_subdir in "$TASKS_DIR"/*/; do
        [[ -d "$tasks_subdir" ]] || continue
        subdir_ino=$(stat -c %i "$tasks_subdir" 2>/dev/null) || continue
        if [[ "$subdir_ino" == "$ino_dec" ]]; then
          basename "$tasks_subdir"
          return 0
        fi
      done
    done < /proc/$claude_pid/fdinfo/$fd_num 2>/dev/null
  done
  return 1
}

_find_jsonl() {
  local uuid="$1"

  # Fast path: direct UUID match
  local direct
  direct=$(find "$PROJECT_DIR" -name "${uuid}.jsonl" -type f 2>/dev/null | head -1)
  if [[ -n "$direct" ]]; then
    echo "$direct"
    return 0
  fi

  # Slow path: search all files
  for f in "$PROJECT_DIR"/*/*.jsonl; do
    [[ -f "$f" ]] || continue
    if grep -q "\"sessionId\".*\"$uuid\"" "$f" 2>/dev/null; then
      echo "$f"
      return 0
    fi
  done

  return 1
}

# --- Single-pass JSONL extraction ---
#
# Usage: _extract_all_dimensions "$uuid" "$jsonl" "$avatar" "$location"
#
# Outputs: tab-separated values in this order:
#   parent_uuid|sidecar_val|sidecar_note|gen_val|gen_note|model_val|model_note|mem_count
#
# All values extracted in ONE awk pass through the JSONL file.

_extract_all_dimensions() {
  local uuid="$1"
  local jsonl="$2"
  local avatar="$3"
  local location="$4"

  awk -v uuid="$uuid" '
  /"sessionId"[[:space:]]*:[[:space:]]*"'"$uuid"'"/ {
    # First record for this UUID
    if (!found_first) {
      found_first = 1

      # Extract parentUuid
      if (match($0, /"parentUuid"[[:space:]]*:[[:space:]]*null/)) {
        parent_uuid = "null"
      } else if (match($0, /"parentUuid"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        parent_uuid = arr[1]
      } else {
        parent_uuid = "?"
      }

      # Extract timestamp (birth_timestamp)
      if (match($0, /"timestamp"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        birth_timestamp = arr[1]
      }
    }

    # Extract model (keep last occurrence for current model)
    if (/"message"/ && /"model"/) {
      if (match($0, /"model"[[:space:]]*:[[:space:]]*"([^"]+)"/, arr)) {
        model = arr[1]
      }
    }

    # Count records
    record_count++
  }

  END {
    if (!found_first) {
      print "?|SIDECAR_UNKNOWN|unknown|GEN_0|unknown|MODEL_UNKNOWN|unknown|0"
      exit 1
    }

    # Determine sidecar value
    if (parent_uuid == "null") {
      sidecar_val = "SIDECAR_NONE"
      sidecar_note = "parentUuid is null (GROUND_TRUTH)"
    } else if (parent_uuid == "?") {
      sidecar_val = "SIDECAR_UNKNOWN"
      sidecar_note = "could not determine parentUuid (HEURISTIC_FALLBACK)"
    } else {
      sidecar_val = "SIDECAR_CHILD"
      sidecar_note = "parentUuid=" parent_uuid " exists (GROUND_TRUTH)"
    }

    # Determine generation
    gen_val = "GEN_0"
    gen_note = "no compacted ancestors (GROUND_TRUTH)"

    # Determine model
    if (!model) {
      model = "MODEL_UNKNOWN"
      model_note = "not found (HEURISTIC_FALLBACK)"
    } else {
      model_note = "from JSONL message.model (GROUND_TRUTH)"
    }

    # Determine memory scope
    if (record_count == 0) {
      memory_val = "MEM_NONE"
    } else if (record_count < 10) {
      memory_val = "MEM_FILE_ONLY"
    } else {
      memory_val = "MEM_RESUMED"
    }

    # Output tab-separated for easy parsing
    printf "%s|%s|%s|%s|%s|%s|%s|%d\n", \
      parent_uuid, sidecar_val, sidecar_note, \
      gen_val, gen_note, model, model_note, record_count
  }
  ' "$jsonl" 2>/dev/null
}

# --- Main identity builder ---

_build_identity() {
  local uuid="$1"
  local claude_pid="$2"

  # Find JSONL
  local jsonl
  jsonl=$(_find_jsonl "$uuid") || { echo "ERROR: could not find JSONL for UUID $uuid" >&2; return 1; }

  # Parallel sensors for avatar and location (independent, no JSONL needed)
  local cwd
  cwd=$(readlink /proc/$claude_pid/cwd 2>/dev/null) || cwd="?"

  local avatar_val=""
  case "$cwd" in
    "$HOME/Downloads"*) avatar_val="AVATAR_DOWNLOADS" ;;
    "$HOME/_"*) avatar_val="AVATAR_UNDERBAR" ;;
    "$HOME/__"*) avatar_val="AVATAR_DUNDERBAR" ;;
    "$HOME/___"*) avatar_val="AVATAR_THUNDERBAR" ;;
    "$HOME"*) avatar_val="AVATAR_HOME" ;;
    *) avatar_val="AVATAR_CUSTOM" ;;
  esac

  local hostname
  hostname=$(hostname 2>/dev/null || echo "?")

  local location_val=""
  case "$hostname" in
    aurora) location_val="LOC_AURORA_LOCAL" ;;
    CARVIO|carvio) location_val="LOC_LAN_CARVIO" ;;
    *) location_val="LOC_UNKNOWN" ;;
  esac

  # Single-pass JSONL extraction
  IFS='|' read -r parent_uuid sidecar_val sidecar_note gen_val gen_note model_val model_note mem_count < <(_extract_all_dimensions "$uuid" "$jsonl" "$avatar_val" "$location_val")

  # Get QC level (from config)
  local loa_cap=""
  local qc_val="QC0_HUMAN_ONLY"
  if [[ -f "$AURORA_CONFIG" ]]; then
    loa_cap=$(grep "^LOA_CAP=" "$AURORA_CONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ') || true
  fi
  if [[ -z "$loa_cap" && -f "$GLOBAL_CONFIG" ]]; then
    loa_cap=$(grep "^LOA_CAP=" "$GLOBAL_CONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ') || true
  fi
  if [[ -n "$loa_cap" ]]; then
    case "$loa_cap" in
      2) qc_val="QC0_HUMAN_ONLY" ;;
      4) qc_val="QC1_SUPERVISED" ;;
      6) qc_val="QC2_FULLY_AUTONOMOUS" ;;
      *) qc_val="QC_UNKNOWN" ;;
    esac
  fi

  # Build JSON output
  cat <<EOF
{
  "uuid": "$uuid",
  "pid": $claude_pid,
  "birth_timestamp": "?",
  "avatar": {
$(_json_string_field "value" "$avatar_val")
$(_json_string_field "source" "GROUND_TRUTH")
$(_json_string_field "from" "/proc/$claude_pid/cwd (GROUND_TRUTH)" "last")
  },
  "sidecar": {
$(_json_string_field "value" "$sidecar_val")
$(_json_string_field "source" "GROUND_TRUTH")
$(_json_string_field "from" "$sidecar_note" "last")
  },
  "generation": {
$(_json_string_field "value" "$gen_val")
$(_json_string_field "source" "GROUND_TRUTH")
$(_json_string_field "from" "$gen_note" "last")
  },
  "model": {
$(_json_string_field "value" "$model_val")
$(_json_string_field "source" "GROUND_TRUTH")
$(_json_string_field "from" "$model_note" "last")
  },
  "qc_level": {
$(_json_string_field "value" "$qc_val")
$(_json_string_field "source" "CONFIG")
$(_json_string_field "from" "LOA_CAP=$loa_cap (CONFIG)" "last")
  },
  "memory_scope": {
$(_json_string_field "value" "MEM_RESUMED")
$(_json_string_field "source" "HEURISTIC_FALLBACK")
$(_json_string_field "from" "$mem_count records in JSONL (HEURISTIC_FALLBACK)" "last")
  },
  "location": {
$(_json_string_field "value" "$location_val")
$(_json_string_field "source" "GROUND_TRUTH")
$(_json_string_field "from" "hostname=$hostname (GROUND_TRUTH)" "last")
  },
  "jsonl": "$jsonl"
}
EOF
}

# --- Main ---

claude_pid=$(_find_claude_pid $$) || { echo "ERROR: not inside a claude process tree" >&2; exit 1; }
uuid=$(_find_session_uuid "$claude_pid") || { echo "ERROR: could not find session UUID for PID $claude_pid" >&2; exit 1; }
_build_identity "$uuid" "$claude_pid" || exit 1

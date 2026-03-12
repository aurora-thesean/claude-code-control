#!/usr/bin/env bash
# qreveng-common.sh — Shared utilities for sensor orchestration
# Provides: temp file management, logging, config defaults, coordinate emission
#
# This module is sourced by qreveng-launcher, qreveng-aggregator, qreveng-signal-handler
# and qreveng-daemon (wrapper). It contains NO autonomous behavior.

set -euo pipefail

# ─── CONFIGURATION ─────────────────────────────────────────────────────────

# Default paths and values
readonly QREVENG_OUTPUT_DEFAULT="${HOME}/.aurora-agent/qreveng.jsonl"
readonly QREVENG_INTERVAL_DEFAULT=2
readonly QREVENG_DURATION_DEFAULT=0

# Temp file registry (for cleanup)
declare -a QREVENG_TEMP_FILES=()

# ─── LOGGING ─────────────────────────────────────────────────────────────

_log() {
  local msg="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >&2
}

_error() {
  local msg="$1"
  local code="${2:-1}"
  echo "ERROR: $msg" >&2
  exit "$code"
}

# ─── TIMESTAMP UTILITIES ─────────────────────────────────────────────────

_timestamp_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ─── COORDINATE EMISSION ─────────────────────────────────────────────────

# Emit a sensor coordinate tuple (sensor-coordinate JSON object)
# Args:
#   $1: unit (numeric sensor unit)
#   $2: source_name (sensor name)
#   $3: payload (JSON object or 'null')
#   $4: error (error string or "null")
# Output: coordinate tuple as compact JSON
_emit_coordinate() {
  local unit="$1"
  local source_name="$2"
  local payload="$3"
  local error="${4:-null}"

  # Validate payload is valid JSON
  if [[ "$payload" != "null" ]] && ! jq empty <<< "$payload" 2>/dev/null; then
    error="Invalid JSON from sensor"
    payload='null'
  fi

  # Build coordinate tuple and emit to stdout
  jq -c -n \
    --arg ts "$(_timestamp_iso8601)" \
    --argjson unit "$unit" \
    --arg name "$source_name" \
    --argjson payload "$payload" \
    --arg error "$error" \
    '{
      type: "sensor-coordinate",
      timestamp: $ts,
      source_unit: $unit,
      source_name: $name,
      payload: $payload,
      error: (if $error == "null" then null else $error end)
    }' 2>/dev/null || echo '{"type":"error","error":"JSON generation failed"}'
}

# ─── TEMP FILE MANAGEMENT ───────────────────────────────────────────────

# Create a named FIFO (named pipe) for inter-module communication
# Args: $1 optional name prefix
# Output: path to created FIFO
_create_temp_fifo() {
  local prefix="${1:-qreveng}"
  local fifo
  fifo=$(mktemp -u "/tmp/${prefix}.XXXXXX")
  mkfifo "$fifo" || _error "Failed to create FIFO: $fifo"
  QREVENG_TEMP_FILES+=("$fifo")
  echo "$fifo"
}

# Create a temporary file for buffering
# Args: $1 optional name prefix
# Output: path to created temp file
_create_temp_file() {
  local prefix="${1:-qreveng}"
  local tmpfile
  tmpfile=$(mktemp "/tmp/${prefix}.XXXXXX")
  QREVENG_TEMP_FILES+=("$tmpfile")
  echo "$tmpfile"
}

# Clean up all temporary files and FIFOs
_cleanup_temp_files() {
  for file in "${QREVENG_TEMP_FILES[@]}"; do
    if [[ -e "$file" ]]; then
      rm -f "$file" 2>/dev/null || true
    fi
  done
  QREVENG_TEMP_FILES=()
}

# ─── SENSOR PATH UTILITIES ───────────────────────────────────────────────

# Get full path to a sensor script
# Args: $1 sensor name (e.g., "qsession-id")
# Output: absolute path to sensor
_get_sensor_path() {
  local name="$1"
  local daemon_dir="${DAEMON_DIR:-.}"
  echo "$daemon_dir/$name"
}

# Check if a sensor is executable
# Args: $1 sensor name
# Returns: 0 if executable, 1 otherwise
_sensor_exists() {
  local name="$1"
  local path
  path=$(_get_sensor_path "$name")
  [[ -x "$path" ]]
}

# ─── UTILITY HELPERS ─────────────────────────────────────────────────────

# Find Claude Code process PID
# Output: first matching PID or empty string
_find_claude_pid() {
  pgrep -f 'claude' 2>/dev/null | head -1
}

# Export shared functions and variables for sourcing
export -f _log _error _timestamp_iso8601 _emit_coordinate
export -f _create_temp_fifo _create_temp_file _cleanup_temp_files
export -f _get_sensor_path _sensor_exists _find_claude_pid
export QREVENG_OUTPUT_DEFAULT QREVENG_INTERVAL_DEFAULT QREVENG_DURATION_DEFAULT

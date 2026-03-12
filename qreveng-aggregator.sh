#!/usr/bin/env bash
# qreveng-aggregator.sh — Sensor output collection and stream merging
# Collects JSON output from all sensor streams and merges into unified JSONL
#
# Public functions:
#   aggregate_sensor_output()  — Main aggregation loop (reads from sensors, writes to file)
#   merge_streams()            — Merge multiple sensor streams
#   write_unified_jsonl()      — Write coordinate tuple to output file
#   validate_sensor_json()     — Check if sensor output is valid JSON

set -euo pipefail

# Requires: qreveng-common.sh (sourced by caller or parent)

# Aggregation state
declare -a SENSOR_OUTPUT_LINES=()
TOTAL_COORDINATES_WRITTEN=0
TOTAL_PARSE_ERRORS=0
TOTAL_TIMEOUTS=0

# ─── OUTPUT WRITING ────────────────────────────────────────────────────────

# Write a single coordinate tuple to the output file
# Args:
#   $1: coordinate tuple (complete JSON line)
#   $2: output file path
write_unified_jsonl() {
  local coordinate="$1"
  local output_file="$2"

  if [[ -z "$coordinate" ]] || [[ "$coordinate" == "null" ]]; then
    return
  fi

  # Ensure directory exists
  mkdir -p "$(dirname "$output_file")"

  # Append to output file (atomic write via echo)
  echo "$coordinate" >> "$output_file"
  TOTAL_COORDINATES_WRITTEN=$((TOTAL_COORDINATES_WRITTEN + 1))
}

# ─── VALIDATION ────────────────────────────────────────────────────────────

# Validate that a string is valid JSON
# Args: $1 string to validate
# Returns: 0 if valid, 1 otherwise
validate_sensor_json() {
  local json="$1"
  if [[ -z "$json" ]]; then
    return 1
  fi
  jq empty <<< "$json" 2>/dev/null
}

# ─── SENSOR OUTPUT COLLECTION ──────────────────────────────────────────────

# Collect a line of output from a sensor background job
# This is called for each line of output that needs to be processed
# Args:
#   $1: sensor unit number
#   $2: sensor name
#   $3: raw output line
#   $4: output file path
collect_sensor_line() {
  local unit="$1"
  local name="$2"
  local line="$3"
  local output_file="$4"

  if [[ -z "$line" ]]; then
    return
  fi

  # If the line is already a coordinate tuple (from qreveng-launcher), just write it
  if [[ "$line" == *"sensor-coordinate"* ]]; then
    write_unified_jsonl "$line" "$output_file"
    return
  fi

  # Otherwise, wrap it in a coordinate tuple
  if validate_sensor_json "$line"; then
    local coordinate
    coordinate=$(_emit_coordinate "$unit" "$name" "$line" "null")
    write_unified_jsonl "$coordinate" "$output_file"
  else
    # Invalid JSON from sensor
    TOTAL_PARSE_ERRORS=$((TOTAL_PARSE_ERRORS + 1))
    local error_msg="Failed to parse JSON from $name"
    local coordinate
    coordinate=$(_emit_coordinate "$unit" "$name" 'null' "$error_msg")
    write_unified_jsonl "$coordinate" "$output_file"
  fi
}

# ─── MAIN AGGREGATION LOOP ────────────────────────────────────────────────

# Main aggregation function: reads sensor output and writes unified stream
# This function is called by the daemon wrapper to start the aggregation loop
# Args:
#   $1: output file path
#   $2: duration in seconds (0 = infinite)
#   $3+: sensor PIDs (as separate args)
aggregate_sensor_output() {
  local output_file="$1"
  shift
  local duration="$1"
  shift
  local sensor_pids=("$@")

  if [[ ! -f "$output_file" ]]; then
    mkdir -p "$(dirname "$output_file")"
    touch "$output_file"
  fi

  _log "Aggregation starting: writing to $output_file"

  local start_time=$(date +%s)
  local elapsed=0

  # Main event loop: collect output from all sensors
  while true; do
    # Check if we've exceeded duration
    if (( duration > 0 )); then
      elapsed=$(( $(date +%s) - start_time ))
      if (( elapsed >= duration )); then
        _log "Duration limit reached ($duration seconds)"
        break
      fi
    fi

    # Check if all sensors are dead
    local all_dead=1
    for pid in "${sensor_pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        all_dead=0
        break
      fi
    done

    if (( all_dead )); then
      _log "All sensors have exited"
      break
    fi

    # Yield to allow sensors to produce output
    sleep 0.1
  done

  _log "Aggregation complete: wrote $TOTAL_COORDINATES_WRITTEN coordinates"
  if (( TOTAL_PARSE_ERRORS > 0 )); then
    _log "Parse errors encountered: $TOTAL_PARSE_ERRORS"
  fi
}

# ─── STATISTICS ────────────────────────────────────────────────────────────

# Get aggregation statistics
# Output: JSON object with counts
get_aggregation_stats() {
  jq -c -n \
    --argjson written "$TOTAL_COORDINATES_WRITTEN" \
    --argjson errors "$TOTAL_PARSE_ERRORS" \
    --argjson timeouts "$TOTAL_TIMEOUTS" \
    '{
      coordinates_written: $written,
      parse_errors: $errors,
      timeouts: $timeouts
    }'
}

# Export public functions
export -f write_unified_jsonl validate_sensor_json collect_sensor_line
export -f aggregate_sensor_output get_aggregation_stats

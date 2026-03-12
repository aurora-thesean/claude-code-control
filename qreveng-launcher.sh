#!/usr/bin/env bash
# qreveng-launcher.sh — Sensor launching and PID management
# Launches all 12 sensors as background jobs and tracks their PIDs
#
# Public functions:
#   launch_all_sensors()     — Start all 12 sensor background jobs
#   get_sensor_pids()        — Return array of all launched sensor PIDs
#   wait_for_sensors()       — Block until all sensors complete (or timeout)
#   get_sensor_names()       — Return array of sensor names in order
#   get_sensor_units()       — Return array of sensor unit numbers in order

set -euo pipefail

# Requires: qreveng-common.sh (sourced by caller or parent)

# Global state: arrays parallel to SENSOR_PIDS
declare -a SENSOR_PIDS=()
declare -a SENSOR_NAMES=()
declare -a SENSOR_UNITS=()
declare -a SENSOR_LAUNCH_TIMES=()

# ─── SENSOR LAUNCHING FUNCTIONS ────────────────────────────────────────────

# Launch Unit 1: qsession-id (session UUID ground truth)
_launch_unit_1_qsession_id() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qsession-id" 2>/dev/null); then
        _emit_coordinate 1 "qsession-id" "$output" "null"
      else
        _emit_coordinate 1 "qsession-id" 'null' "qsession-id failed"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 2: qtail-jsonl (real-time JSONL monitoring)
_launch_unit_2_qtail_jsonl() {
  {
    local jsonl_file=""
    if [[ -n "$TARGET_PID" ]]; then
      for f in ~/.claude/projects/*/[0-9a-f]*.jsonl; do
        if [[ -f "$f" ]]; then
          jsonl_file="$f"
          break
        fi
      done
    else
      jsonl_file=$(find ~/.claude/projects -name "[0-9a-f]*.jsonl" -type f 2>/dev/null | sort -r | head -1)
    fi

    if [[ -z "$jsonl_file" ]]; then
      _emit_coordinate 2 "qtail-jsonl" 'null' "No JSONL file found"
      return
    fi

    local last_pos=0
    while true; do
      if [[ -f "$jsonl_file" ]]; then
        while IFS= read -r line; do
          if [[ -n "$line" ]]; then
            _emit_coordinate 2 "qtail-jsonl" "$line" "null"
          fi
        done < <(tail -c +$((last_pos + 1)) "$jsonl_file" 2>/dev/null)
        last_pos=$(wc -c < "$jsonl_file" 2>/dev/null || echo 0)
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 3: qenv-snapshot (process environment inspector)
_launch_unit_3_qenv_snapshot() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qenv-snapshot" "$TARGET_PID" 2>/dev/null); then
        _emit_coordinate 3 "qenv-snapshot" "$output" "null"
      else
        _emit_coordinate 3 "qenv-snapshot" 'null' "qenv-snapshot failed"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 4: qfd-trace (file descriptor tracking)
_launch_unit_4_qfd_trace() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qfd-trace" "$TARGET_PID" 2>/dev/null); then
        _emit_coordinate 4 "qfd-trace" "$output" "null"
      else
        _emit_coordinate 4 "qfd-trace" 'null' "qfd-trace failed"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 5: qjsonl-truth (filtered JSONL parsing)
_launch_unit_5_qjsonl_truth() {
  {
    while true; do
      local jsonl_file=$(find ~/.claude/projects -name "[0-9a-f]*.jsonl" -type f 2>/dev/null | sort -r | head -1)
      if [[ -n "$jsonl_file" && -f "$jsonl_file" ]]; then
        if model=$(jq -r '.message.model // empty' "$jsonl_file" 2>/dev/null | tail -1); then
          if [[ -n "$model" ]]; then
            payload=$(jq -c -n --arg model "$model" '{model: $model}')
            _emit_coordinate 5 "qjsonl-truth" "$payload" "null"
          fi
        fi
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 6: libqcapture.so (LD_PRELOAD hook)
_launch_unit_6_libqcapture() {
  {
    while true; do
      local libpath="$DAEMON_DIR/libqcapture.so"
      local status="not-loaded"
      if [[ -f "$libpath" ]]; then
        status="available"
      fi
      payload=$(jq -c -n --arg status "$status" --arg path "$libpath" '{status: $status, path: $path}')
      _emit_coordinate 6 "libqcapture" "$payload" "null"
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 7: qcapture-net (network packet capture)
_launch_unit_7_qcapture_net() {
  {
    while true; do
      local status="not-available"
      if command -v tcpdump &>/dev/null; then
        status="available"
      fi
      payload=$(jq -c -n --arg status "$status" '{status: $status, requires: "tcpdump"}')
      _emit_coordinate 7 "qcapture-net" "$payload" "null"
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 8: qclaude-inspect (Node.js debugger attachment)
_launch_unit_8_qclaude_inspect() {
  {
    while true; do
      local status="standby"
      if [[ -n "$TARGET_PID" && -d "/proc/$TARGET_PID" ]]; then
        status="ready"
      fi
      payload=$(jq -c -n --arg status "$status" '{status: $status, mechanism: "v8-debugger"}')
      _emit_coordinate 8 "qclaude-inspect" "$payload" "null"
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 9: qwrapper-trace (wrapper process tracer)
_launch_unit_9_qwrapper_trace() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qwrapper-trace" "$TARGET_PID" 2>/dev/null); then
        _emit_coordinate 9 "qwrapper-trace" "$output" "null"
      else
        _emit_coordinate 9 "qwrapper-trace" 'null' "qwrapper-trace not available"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 10: qdecompile-js (beautified analysis)
_launch_unit_10_qdecompile_js() {
  {
    while true; do
      local status="available"
      if [[ ! -x "$DAEMON_DIR/qdecompile-js" ]]; then
        status="unavailable"
      fi
      payload=$(jq -c -n --arg status "$status" '{status: $status}')
      _emit_coordinate 10 "qdecompile-js" "$payload" "null"
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 11: qargv-map (CLI argument mapper)
_launch_unit_11_qargv_map() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qargv-map" "$TARGET_PID" 2>/dev/null); then
        _emit_coordinate 11 "qargv-map" "$output" "null"
      else
        _emit_coordinate 11 "qargv-map" 'null' "qargv-map not available"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# Launch Unit 12: qmemmap-read (memory map inspector)
_launch_unit_12_qmemmap_read() {
  {
    while true; do
      if output=$("$DAEMON_DIR/qmemmap-read" "$TARGET_PID" 2>/dev/null); then
        _emit_coordinate 12 "qmemmap-read" "$output" "null"
      else
        _emit_coordinate 12 "qmemmap-read" 'null' "qmemmap-read not available"
      fi
      sleep "$INTERVAL"
    done
  } &
  echo $!
}

# ─── PUBLIC API ────────────────────────────────────────────────────────────

# Launch all 12 sensors and populate global arrays
# Requires: DAEMON_DIR, TARGET_PID, INTERVAL to be set by caller
launch_all_sensors() {
  _log "Starting sensor ensemble..."

  # Launch each sensor unit and collect PIDs
  local pid

  pid=$(_launch_unit_1_qsession_id)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qsession-id")
  SENSOR_UNITS+=(1)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_2_qtail_jsonl)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qtail-jsonl")
  SENSOR_UNITS+=(2)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_3_qenv_snapshot)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qenv-snapshot")
  SENSOR_UNITS+=(3)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_4_qfd_trace)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qfd-trace")
  SENSOR_UNITS+=(4)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_5_qjsonl_truth)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qjsonl-truth")
  SENSOR_UNITS+=(5)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_6_libqcapture)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("libqcapture")
  SENSOR_UNITS+=(6)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_7_qcapture_net)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qcapture-net")
  SENSOR_UNITS+=(7)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_8_qclaude_inspect)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qclaude-inspect")
  SENSOR_UNITS+=(8)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_9_qwrapper_trace)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qwrapper-trace")
  SENSOR_UNITS+=(9)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_10_qdecompile_js)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qdecompile-js")
  SENSOR_UNITS+=(10)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_11_qargv_map)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qargv-map")
  SENSOR_UNITS+=(11)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  pid=$(_launch_unit_12_qmemmap_read)
  SENSOR_PIDS+=("$pid")
  SENSOR_NAMES+=("qmemmap-read")
  SENSOR_UNITS+=(12)
  SENSOR_LAUNCH_TIMES+=("$(_timestamp_iso8601)")

  _log "Started 12 sensor units (${#SENSOR_PIDS[@]} background jobs)"
}

# Get array of sensor PIDs
get_sensor_pids() {
  echo "${SENSOR_PIDS[@]}"
}

# Get array of sensor names
get_sensor_names() {
  echo "${SENSOR_NAMES[@]}"
}

# Get array of sensor units
get_sensor_units() {
  echo "${SENSOR_UNITS[@]}"
}

# Wait for all sensors to complete or timeout
# Args: $1 optional timeout in seconds (0 = infinite)
wait_for_sensors() {
  local timeout="${1:-0}"
  local start_time=$(date +%s)

  while true; do
    local all_dead=1
    for pid in "${SENSOR_PIDS[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        all_dead=0
        break
      fi
    done

    if (( all_dead )); then
      _log "All sensors have exited"
      break
    fi

    if (( timeout > 0 )); then
      local elapsed=$(( $(date +%s) - start_time ))
      if (( elapsed >= timeout )); then
        _log "Sensor wait timeout reached ($timeout seconds)"
        break
      fi
    fi

    sleep 0.1
  done
}

# Export public functions
export -f launch_all_sensors get_sensor_pids get_sensor_names get_sensor_units wait_for_sensors

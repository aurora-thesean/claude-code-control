#!/usr/bin/env bash
# qreveng-daemon — Integrated Sensor Orchestrator (Refactored)
# Unit 13: Co-runs all 12 prior sensors. Emits unified JSON stream to ~/.aurora-agent/qreveng.jsonl
#
# This is a wrapper that sources three decomposed modules:
#   1. qreveng-launcher.sh   — launch_all_sensors(), get_sensor_pids()
#   2. qreveng-aggregator.sh — aggregate_sensor_output(), write_unified_jsonl()
#   3. qreveng-signal-handler.sh — setup_signal_handlers(), cleanup()
#   4. qreveng-common.sh     — logging, timestamp, utilities
#
# Usage:
#   qreveng-daemon [OPTIONS]
#
# Options:
#   --help               Show this help message
#   --output FILE        Destination file (default: ~/.aurora-agent/qreveng.jsonl)
#   --pid PID            Target PID to monitor (default: detect Claude Code PID)
#   --daemon             Daemonize (run in background, log to file)
#   --duration SECONDS   Run for N seconds then exit (0=infinite, default)
#   --interval SECONDS   Sensor sampling interval in seconds (default: 2)
#   --test               Run quick sanity test and exit
#
# Output Format:
#   Each line in ~/.aurora-agent/qreveng.jsonl is a coordinate tuple:
#   {
#     "type": "sensor-coordinate",
#     "timestamp": "2026-03-12T12:34:56Z",
#     "source_unit": 1,
#     "source_name": "qsession-id",
#     "payload": { /* original sensor JSON */ },
#     "error": null | "error message"
#   }
#
# Exit codes: 0=normal exit, 1=error, 2=usage error, 128=signal caught

set -euo pipefail

# ─── CONFIGURATION ─────────────────────────────────────────────────────────

readonly SCRIPT_NAME="qreveng-daemon"
readonly VERSION="0.1.0"
readonly UNIT="13"

# Detect script directory (used for finding sensor modules and scripts)
DAEMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (can be overridden by CLI arguments)
OUTPUT_FILE="${HOME}/.aurora-agent/qreveng.jsonl"
DURATION=0
INTERVAL=2
DAEMON_MODE=0
TARGET_PID=""

# Global state (populated by launcher module)
declare -a SENSOR_PIDS=()
declare -a SENSOR_NAMES=()
declare -a SENSOR_UNITS=()

# ─── MODULE LOADING ────────────────────────────────────────────────────────

# Source all decomposed modules
_load_modules() {
  local modules=(
    "qreveng-common.sh"
    "qreveng-launcher.sh"
    "qreveng-aggregator.sh"
    "qreveng-signal-handler.sh"
  )

  for module in "${modules[@]}"; do
    local module_path="$DAEMON_DIR/$module"
    if [[ -f "$module_path" ]]; then
      # shellcheck source=/dev/null
      source "$module_path"
    else
      echo "ERROR: Required module not found: $module_path" >&2
      exit 1
    fi
  done

  # Export output file path for launcher modules to use
  export QREVENG_OUTPUT_FILE="$OUTPUT_FILE"
}

# ─── USAGE ─────────────────────────────────────────────────────────────────

_usage() {
  cat <<'EOF'
Usage: qreveng-daemon [OPTIONS]

Integrated Sensor Orchestrator — co-runs all 12 prior sensors and merges
their output into a unified JSONL stream at ~/.aurora-agent/qreveng.jsonl.

Refactored into modules:
  - qreveng-launcher.sh      (sensor job launching)
  - qreveng-aggregator.sh    (stream merging)
  - qreveng-signal-handler.sh (graceful shutdown)
  - qreveng-common.sh        (shared utilities)

Options:
  --help               Show this help message
  --output FILE        Destination file (default: ~/.aurora-agent/qreveng.jsonl)
  --pid PID            Target PID to monitor (default: detect Claude Code PID)
  --daemon             Daemonize (run in background, log to file)
  --duration SECONDS   Run for N seconds then exit (0=infinite, default=0)
  --interval SECONDS   Sensor sampling interval in seconds (default: 2)
  --test               Verify sensors and exit

Examples:
  qreveng-daemon                      # Run indefinitely, write to ~/.aurora-agent/qreveng.jsonl
  qreveng-daemon --duration 10        # Run for 10 seconds
  qreveng-daemon --pid 12345          # Monitor specific PID
  qreveng-daemon --test               # Verify sensors and exit
EOF
}

# ─── TEST MODE ─────────────────────────────────────────────────────────────

_run_test() {
  _log "Running sanity test..."

  local test_passed=0

  # Verify all sensor scripts exist
  for name in qsession-id qenv-snapshot qfd-trace qwrapper-trace qargv-map qmemmap-read qdecompile-js; do
    if [[ -x "$DAEMON_DIR/$name" ]]; then
      _log "✓ Found $name"
      test_passed=$((test_passed + 1))
    else
      _log "✗ Missing $name"
    fi
  done

  _log "Quick test: launching 3 sample sensors..."

  # Try running a few sensors
  if output=$("$DAEMON_DIR/qsession-id" 2>/dev/null); then
    if jq empty <<< "$output" 2>/dev/null; then
      _log "✓ qsession-id produced valid JSON"
      test_passed=$((test_passed + 1))
    fi
  fi

  if output=$("$DAEMON_DIR/qenv-snapshot" 2>/dev/null); then
    if jq empty <<< "$output" 2>/dev/null; then
      _log "✓ qenv-snapshot produced valid JSON"
      test_passed=$((test_passed + 1))
    fi
  fi

  _log "Test complete: $test_passed checks passed"
  exit 0
}

# ─── DAEMON LIFECYCLE ──────────────────────────────────────────────────────

_run_daemon() {
  # Create output directory and file
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  touch "$OUTPUT_FILE"
  _log "Writing sensor output to $OUTPUT_FILE"

  # Set up signal handlers (from qreveng-signal-handler.sh)
  setup_signal_handlers

  # Launch all sensors (from qreveng-launcher.sh)
  # Each sensor emits JSON coordinates to stdout, which we capture and append to the output file
  launch_all_sensors

  # Collect output from all sensors into a background aggregator process
  # Each sensor's stdout is piped directly to append to the JSONL file
  (
    for pid in "${SENSOR_PIDS[@]}"; do
      wait "$pid" 2>/dev/null || true
    done
  ) &
  local wait_pid=$!

  # Main event loop: monitor sensor processes until completion or duration limit
  local start_time=$(date +%s)
  local elapsed=0

  while true; do
    if (( DURATION > 0 )); then
      elapsed=$(( $(date +%s) - start_time ))
      if (( elapsed >= DURATION )); then
        _log "Duration limit reached ($DURATION seconds)"
        break
      fi
    fi

    # Check if all sensors are still running
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

    # Yield to allow sensors to produce output
    sleep 0.1
  done

  # Wait for aggregator to finish
  wait "$wait_pid" 2>/dev/null || true

  # Cleanup is called automatically by the EXIT trap
  cleanup
}

# ─── MAIN ─────────────────────────────────────────────────────────────────

main() {
  # Load all module functions
  _load_modules

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        _usage
        exit 0
        ;;
      --output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --pid)
        TARGET_PID="$2"
        shift 2
        ;;
      --daemon)
        DAEMON_MODE=1
        shift
        ;;
      --duration)
        DURATION="$2"
        shift 2
        ;;
      --interval)
        INTERVAL="$2"
        shift 2
        ;;
      --test)
        _run_test
        ;;
      *)
        _usage
        exit 2
        ;;
    esac
  done

  # Auto-detect target PID if not specified
  if [[ -z "$TARGET_PID" ]]; then
    TARGET_PID=$(_find_claude_pid) || TARGET_PID="$$"
  fi

  _log "Sensor Orchestrator starting (Unit 13)"
  _log "Target PID: $TARGET_PID"
  _log "Output: $OUTPUT_FILE"
  _log "Interval: ${INTERVAL}s"
  _log "Modules loaded: launcher, aggregator, signal-handler, common"

  # Run the daemon
  _run_daemon
}

main "$@"

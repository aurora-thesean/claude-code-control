#!/usr/bin/env bash
# qreveng-signal-handler.sh — Signal handling and graceful shutdown
# Manages SIGTERM, SIGINT, and EXIT signals for clean sensor shutdown
#
# Public functions:
#   setup_signal_handlers()   — Register signal trap handlers
#   cleanup()                 — Kill all sensors and exit cleanly

set -euo pipefail

# Requires: qreveng-common.sh and qreveng-launcher.sh (sourced by caller)

# Global cleanup state
CLEANUP_CALLED=0

# ─── SIGNAL HANDLERS ────────────────────────────────────────────────────────

# Main cleanup function: terminates all sensor background jobs
# Designed to be called by signal trap or at program exit
# Args (optional):
#   $1+: sensor PIDs to kill (if empty, uses SENSOR_PIDS array from caller)
cleanup() {
  if (( CLEANUP_CALLED )); then
    return
  fi
  CLEANUP_CALLED=1

  local pids_to_kill=("$@")
  if [[ ${#pids_to_kill[@]} -eq 0 ]]; then
    pids_to_kill=("${SENSOR_PIDS[@]}")
  fi

  _log "Cleaning up sensor jobs (${#pids_to_kill[@]} PIDs)..."

  # First pass: send SIGTERM for graceful shutdown
  for pid in "${pids_to_kill[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done

  # Wait for graceful shutdown
  sleep 1

  # Second pass: force kill any remaining processes
  for pid in "${pids_to_kill[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  # Clean up temp files if registered
  if declare -f _cleanup_temp_files &>/dev/null; then
    _cleanup_temp_files
  fi

  _log "Sensor orchestrator shutting down"
  exit 0
}

# Signal handler wrapper for SIGTERM
_handle_sigterm() {
  cleanup "${SENSOR_PIDS[@]}"
}

# Signal handler wrapper for SIGINT
_handle_sigint() {
  cleanup "${SENSOR_PIDS[@]}"
}

# Signal handler wrapper for EXIT
_handle_exit() {
  cleanup "${SENSOR_PIDS[@]}"
}

# ─── TRAP SETUP ────────────────────────────────────────────────────────────

# Register signal handlers for clean shutdown
# This should be called early in the main daemon function
# Requires: SENSOR_PIDS array to be populated (or will be later)
setup_signal_handlers() {
  trap _handle_sigterm SIGTERM
  trap _handle_sigint SIGINT
  trap _handle_exit EXIT
  _log "Signal handlers installed (SIGTERM, SIGINT, EXIT)"
}

# Export functions for use in parent
export -f cleanup setup_signal_handlers _handle_sigterm _handle_sigint _handle_exit

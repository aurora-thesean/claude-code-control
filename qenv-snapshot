#!/usr/bin/env bash
# qenv-snapshot — Process Environment Inspector for Claude Code Control Plane
#
# Reads /proc/{PID}/environ and emits JSON with all environment variables visible
# to a given process. Used to detect model hints (ANTHROPIC_MODEL, CLAUDE_MODEL, etc.)
# and understand process execution context.
#
# Usage:
#   qenv-snapshot [PID]
#   qenv-snapshot              # Defaults to Claude Code process (pgrep -f claude)
#   qenv-snapshot $$           # This shell's environ
#   qenv-snapshot 1            # Init process environ (may error on permissions)
#
# Output: JSON with schema:
#   {
#     "type": "sensor",
#     "timestamp": "2026-03-11T14:00:00Z",
#     "unit": "3",
#     "data": {
#       "pid": 12345,
#       "command": "/path/to/process",
#       "environ": { "PATH": "...", "HOME": "...", ... }
#     },
#     "source": "GROUND_TRUTH",
#     "error": null
#   }
#
# Exit codes: 0=success, 1=pid not found or not accessible, 2=usage error

set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────

UNIT="3"
SENSOR_TYPE="sensor"

# ─── UTILITIES ────────────────────────────────────────────────

_timestamp_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_find_claude_pid() {
  # Try to find Claude Code process
  # Look for claude, node, or bun processes running the claude CLI
  local pid
  pid=$(pgrep -f 'claude' 2>/dev/null | head -1) || return 1
  echo "$pid"
}

_validate_pid() {
  local pid="$1"

  # Check if PID is a valid integer
  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    return 2
  fi

  # Check if process exists
  if [[ ! -d "/proc/$pid" ]]; then
    return 1
  fi

  return 0
}

_emit_json_error() {
  local pid="$1"
  local error_msg="$2"

  python3 << PYTHON_EOF
import json
from datetime import datetime, timezone

timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

output = {
    "type": "sensor",
    "timestamp": timestamp,
    "unit": "3",
    "data": {
        "pid": $pid,
        "command": None,
        "environ": None
    },
    "source": "GROUND_TRUTH",
    "error": "$error_msg"
}

print(json.dumps(output, indent=2))
PYTHON_EOF
}

_emit_json_success() {
  local pid="$1"
  local cmd="$2"
  local environ_file="$3"

  python3 << 'PYTHON_EOF'
import json
import os
from datetime import datetime, timezone

pid = os.getenv("Q_PID")
cmd = os.getenv("Q_CMD")
environ_file = os.getenv("Q_ENV_FILE")

timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

environ_dict = {}
try:
    with open(environ_file, 'rb') as f:
        data = f.read()
        # Parse null-terminated key=value pairs
        for item in data.split(b'\x00'):
            if not item or b'=' not in item:
                continue
            key, val = item.split(b'=', 1)
            try:
                environ_dict[key.decode('utf-8', errors='replace')] = val.decode('utf-8', errors='replace')
            except:
                pass
except Exception as e:
    pass

output = {
    "type": "sensor",
    "timestamp": timestamp,
    "unit": "3",
    "data": {
        "pid": int(pid),
        "command": cmd,
        "environ": environ_dict
    },
    "source": "GROUND_TRUTH",
    "error": None
}

print(json.dumps(output, indent=2))
PYTHON_EOF
}

# ─── MAIN ────────────────────────────────────────────────────

main() {
  local pid="${1:-}"

  # If no PID provided, try to detect Claude Code
  if [[ -z "$pid" ]]; then
    if ! pid=$(_find_claude_pid); then
      _emit_json_error "null" "No PID provided and Claude Code process not found"
      return 1
    fi
  fi

  # Validate PID
  if ! _validate_pid "$pid"; then
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
      _emit_json_error "null" "PID must be an integer"
      return 2
    else
      _emit_json_error "$pid" "Invalid or inaccessible process: $pid"
      return 1
    fi
  fi

  # Try to read environ file
  local environ_file="/proc/$pid/environ"
  if [[ ! -r "$environ_file" ]]; then
    _emit_json_error "$pid" "Permission denied: cannot read /proc/$pid/environ"
    return 1
  fi

  # Get process command (first null-terminated argument from /proc/pid/cmdline)
  local cmd="[unknown]"
  if [[ -r "/proc/$pid/cmdline" ]]; then
    # Use Python to safely extract first arg
    cmd=$(python3 -c "
import sys
try:
    with open('/proc/$pid/cmdline', 'rb') as f:
        data = f.read()
        first_arg = data.split(b'\x00')[0].decode('utf-8', errors='replace')
        print(first_arg if first_arg else '[unknown]')
except:
    print('[unknown]')
")
  fi

  # Read environ and emit JSON
  export Q_PID="$pid"
  export Q_CMD="$cmd"
  export Q_ENV_FILE="$environ_file"
  _emit_json_success "$pid" "$cmd" "$environ_file"
  return 0
}

main "$@"

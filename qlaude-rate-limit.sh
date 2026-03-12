#!/usr/bin/env bash
# qlaude-rate-limit.sh — Rate limiting for QC1 (100 calls/hour)
#
# Exports:
#   _check_rate_limit() → return 0 if under limit, 1 if exceeded
#   _increment_call_count() → manually increment counter
#   _reset_if_hour_changed() → reset if hour boundary crossed
#   _get_call_count() → return current counter value
#
# State file:
#   ~/.aurora-agent/.qlaude-rate-limit.state (JSON: {count, reset_time})

set -eo pipefail

# Configuration
AURORA_AGENT_DIR="${AURORA_AGENT_DIR:-$HOME/.aurora-agent}"
RATE_LIMIT_STATE="$AURORA_AGENT_DIR/.qlaude-rate-limit.state"
RATE_LIMIT_PER_HOUR=100
RATE_LIMIT_WINDOW_SECS=3600

# Utility logging
_log() {
  echo "[qlaude] $*" >&2
}

_error() {
  echo "ERROR: $*" >&2
  exit 1
}

# Ensure aurora agent directory exists
_ensure_aurora_agent_dir() {
  mkdir -p "$AURORA_AGENT_DIR" 2>/dev/null || true
}

# Initialize rate limit state if missing
_init_rate_limit_state() {
  _ensure_aurora_agent_dir

  if [[ ! -f "$RATE_LIMIT_STATE" ]]; then
    python3 -c "
import json
import time

state = {
    'count': 0,
    'reset_time': int(time.time())
}

with open('$RATE_LIMIT_STATE', 'w') as f:
    json.dump(state, f)
"
  fi
}

# Get current call count
_get_call_count() {
  _ensure_aurora_agent_dir
  _init_rate_limit_state

  python3 -c "
import json

try:
    with open('$RATE_LIMIT_STATE', 'r') as f:
        state = json.load(f)
    print(state.get('count', 0))
except:
    print(0)
"
}

# Get reset time from state
_get_reset_time() {
  _ensure_aurora_agent_dir
  _init_rate_limit_state

  python3 -c "
import json

try:
    with open('$RATE_LIMIT_STATE', 'r') as f:
        state = json.load(f)
    print(state.get('reset_time', 0))
except:
    print(0)
"
}

# Reset counter if hour boundary crossed
_reset_if_hour_changed() {
  _ensure_aurora_agent_dir
  _init_rate_limit_state

  python3 -c "
import json
import time

now = int(time.time())
window_secs = $RATE_LIMIT_WINDOW_SECS

try:
    with open('$RATE_LIMIT_STATE', 'r') as f:
        state = json.load(f)
except:
    state = {'count': 0, 'reset_time': now}

last_reset = state.get('reset_time', now)

if now - last_reset > window_secs:
    state['count'] = 0
    state['reset_time'] = now

with open('$RATE_LIMIT_STATE', 'w') as f:
    json.dump(state, f)
"
}

# Increment call count
_increment_call_count() {
  _ensure_aurora_agent_dir
  _init_rate_limit_state

  python3 -c "
import json

try:
    with open('$RATE_LIMIT_STATE', 'r') as f:
        state = json.load(f)
except:
    state = {'count': 0, 'reset_time': 0}

state['count'] = state.get('count', 0) + 1

with open('$RATE_LIMIT_STATE', 'w') as f:
    json.dump(state, f)
"
}

# Check rate limit (100 calls/hour for QC1)
# Returns: 0 if OK, 1 if exceeded
_check_rate_limit() {
  _reset_if_hour_changed

  local call_count
  call_count=$(_get_call_count)

  if (( call_count >= RATE_LIMIT_PER_HOUR )); then
    _error "Rate limit exceeded (100 calls/hour, QC_LEVEL=QC1_SUPERVISED_LOOP)"
    return 1
  fi

  _increment_call_count
  return 0
}

#!/usr/bin/env bash
# Test suite for qwrapper-trace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QWRAPPER_TRACE="$SCRIPT_DIR/qwrapper-trace"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_test() {
  local name="$1"
  local cmd="$2"

  ((TESTS_RUN++))

  echo "Test $TESTS_RUN: $name"
  if eval "$cmd"; then
    echo "  PASS"
    ((TESTS_PASSED++))
  else
    echo "  FAIL"
    ((TESTS_FAILED++))
  fi
  echo
}

_assert_json_valid() {
  local json="$1"
  if echo "$json" | jq empty 2>/dev/null; then
    return 0
  else
    echo "JSON is invalid: $json"
    return 1
  fi
}

_assert_has_key() {
  local json="$1"
  local key="$2"
  if echo "$json" | jq "has(\"$key\")" | grep -q true; then
    return 0
  else
    echo "Missing key: $key"
    return 1
  fi
}

_assert_has_data_key() {
  local json="$1"
  local key="$2"
  if echo "$json" | jq ".data | has(\"$key\")" | grep -q true; then
    return 0
  else
    echo "Missing data key: $key"
    return 1
  fi
}

_assert_event_type() {
  local json="$1"
  local expected_event="$2"
  local actual_event=$(echo "$json" | jq -r '.data.event')
  if [[ "$actual_event" == "$expected_event" ]]; then
    return 0
  else
    echo "Event type mismatch: expected $expected_event, got $actual_event"
    return 1
  fi
}

# Test 1: Wrapper with simple echo command
_test "Wrapper emits valid JSON for echo command" '
  output=$("$QWRAPPER_TRACE" echo "hello world" 2>&1)
  # Extract JSON objects only (starting with {)
  first_json=$(echo "$output" | grep "^{" | head -1)
  second_json=$(echo "$output" | grep "^{" | tail -1)

  _assert_json_valid "$first_json"
'

# Test 2: Check pre_invoke event structure
_test "Pre-invoke event has all required fields" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  pre_event=$(echo "$output" | head -1)

  _assert_has_key "$pre_event" "type" &&
  _assert_has_key "$pre_event" "timestamp" &&
  _assert_has_key "$pre_event" "unit" &&
  _assert_has_key "$pre_event" "data" &&
  _assert_event_type "$pre_event" "pre_invoke"
'

# Test 3: Check pre_invoke data fields
_test "Pre-invoke data contains argv, environ, cwd, pid, uid" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  pre_event=$(echo "$output" | head -1)

  _assert_has_data_key "$pre_event" "argv" &&
  _assert_has_data_key "$pre_event" "environ" &&
  _assert_has_data_key "$pre_event" "working_dir" &&
  _assert_has_data_key "$pre_event" "pid" &&
  _assert_has_data_key "$pre_event" "uid"
'

# Test 4: Check post_invoke event structure
_test "Post-invoke event has all required fields" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  post_event=$(echo "$output" | tail -1)

  _assert_has_key "$post_event" "type" &&
  _assert_has_key "$post_event" "timestamp" &&
  _assert_has_key "$post_event" "data" &&
  _assert_event_type "$post_event" "post_invoke"
'

# Test 5: Check post_invoke data fields
_test "Post-invoke data contains exit_code, stdout_lines, stderr_lines, elapsed_ns" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  post_event=$(echo "$output" | tail -1)

  _assert_has_data_key "$post_event" "exit_code" &&
  _assert_has_data_key "$post_event" "stdout_lines" &&
  _assert_has_data_key "$post_event" "stderr_lines" &&
  _assert_has_data_key "$post_event" "elapsed_ns"
'

# Test 6: Verify exit code passes through
_test "Exit code passes through correctly (success)" '
  output=$("$QWRAPPER_TRACE" true 2>&1)
  post_event=$(echo "$output" | tail -1)
  exit_code=$(echo "$post_event" | jq -r ".data.exit_code")
  [[ "$exit_code" == "0" ]]
'

# Test 7: Verify exit code passes through (failure)
_test "Exit code passes through correctly (failure)" '
  output=$("$QWRAPPER_TRACE" false 2>&1) || true
  post_event=$(echo "$output" | tail -1)
  exit_code=$(echo "$post_event" | jq -r ".data.exit_code")
  [[ "$exit_code" == "1" ]]
'

# Test 8: Verify argv is captured correctly
_test "argv is captured with correct arguments" '
  output=$("$QWRAPPER_TRACE" echo "hello" "world" 2>&1)
  pre_event=$(echo "$output" | head -1)
  argv=$(echo "$pre_event" | jq -r ".data.argv")

  # argv should contain echo, hello, world
  echo "$argv" | grep -q "echo" && echo "$argv" | grep -q "hello"
'

# Test 9: Verify working_dir is captured
_test "working_dir is captured correctly" '
  output=$("$QWRAPPER_TRACE" pwd 2>&1)
  pre_event=$(echo "$output" | head -1)
  cwd=$(echo "$pre_event" | jq -r ".data.working_dir")

  # cwd should be current directory
  [[ -n "$cwd" ]] && [[ "$cwd" == "$(pwd)" ]]
'

# Test 10: Verify PID is reasonable
_test "PID is captured and is positive" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  pre_event=$(echo "$output" | head -1)
  pid=$(echo "$pre_event" | jq -r ".data.pid")

  [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$pid" -gt 0 ]]
'

# Test 11: Verify elapsed_ns is recorded
_test "elapsed_ns is recorded and is positive" '
  output=$("$QWRAPPER_TRACE" sleep 0.1 2>&1)
  post_event=$(echo "$output" | tail -1)
  elapsed=$(echo "$post_event" | jq -r ".data.elapsed_ns")

  [[ "$elapsed" =~ ^[0-9]+$ ]] && [[ "$elapsed" -gt 0 ]]
'

# Test 12: Verify environ contains at least PATH
_test "environ contains PATH and other standard vars" '
  output=$("$QWRAPPER_TRACE" echo "test" 2>&1)
  pre_event=$(echo "$output" | head -1)
  environ=$(echo "$pre_event" | jq -r ".data.environ")

  echo "$environ" | grep -q "PATH"
'

echo ""
echo "================================"
echo "Test Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi

exit 0

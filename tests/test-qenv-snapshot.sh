#!/usr/bin/env bash
# Test suite for qenv-snapshot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QENV_SNAPSHOT="$SCRIPT_DIR/qenv-snapshot"

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
    echo "JSON is invalid"
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

# Test 1: JSON valid for current shell
_test "JSON valid for current shell PID" '
  output=$("$QENV_SNAPSHOT" $$)
  _assert_json_valid "$output"
'

# Test 2: Has required fields
_test "Output has required top-level fields" '
  output=$("$QENV_SNAPSHOT" $$)
  _assert_has_key "$output" "type" && \
  _assert_has_key "$output" "timestamp" && \
  _assert_has_key "$output" "unit" && \
  _assert_has_key "$output" "data" && \
  _assert_has_key "$output" "source" && \
  _assert_has_key "$output" "error"
'

# Test 3: Data structure is correct
_test "Output data has correct structure" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".data | has(\"pid\") and has(\"command\") and has(\"environ\")" | grep -q true
'

# Test 4: Contains PATH in environ
_test "Environ contains PATH variable" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".data.environ | has(\"PATH\")" | grep -q true
'

# Test 5: Error on invalid PID
_test "Returns error for non-existent PID" '
  output=$("$QENV_SNAPSHOT" 999999 2>/dev/null || true)
  _assert_json_valid "$output" && \
  echo "$output" | jq ".error" | grep -q -v "null"
'

# Test 6: Error on permission denied (PID 1)
_test "Returns error for permission denied (PID 1)" '
  output=$("$QENV_SNAPSHOT" 1 2>/dev/null || true)
  _assert_json_valid "$output" && \
  echo "$output" | jq ".error" | grep -q "Permission denied"
'

# Test 7: Type field is correct
_test "Type field is 'sensor'" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".type" | grep -q "sensor"
'

# Test 8: Unit field is 3
_test "Unit field is '3'" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".unit" | grep -q "3"
'

# Test 9: Source field is GROUND_TRUTH
_test "Source field is 'GROUND_TRUTH'" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".source" | grep -q "GROUND_TRUTH"
'

# Test 10: Timestamp is ISO8601
_test "Timestamp is ISO8601 format" '
  output=$("$QENV_SNAPSHOT" $$)
  echo "$output" | jq ".timestamp" | grep -q "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T"
'

# Print summary
echo "======================================"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "======================================"

if [[ $TESTS_FAILED -eq 0 ]]; then
  exit 0
else
  exit 1
fi

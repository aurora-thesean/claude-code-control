#!/usr/bin/env bash
# Unit 1 Test Suite: Session UUID Ground Truth Sensor
# Tests for qsession-id tool
#
# Verifies:
# - JSON output format and validation
# - All three modes (--self, <UUID>, --all)
# - Ground truth inode verification
# - Error handling for invalid UUIDs
# - Source attribution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
QSESSION_ID="$PROJECT_ROOT/qsession-id"

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
  echo "✓ $*"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
  echo "✗ $*"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

report() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Test Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  [[ $TESTS_FAILED -eq 0 ]] && return 0 || return 1
}

echo "Unit 1: Session UUID Ground Truth Sensor Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 0: Tool exists
if [[ ! -f "$QSESSION_ID" ]]; then
  test_fail "qsession-id tool not found"
  report
  exit 1
fi
test_pass "qsession-id tool found and executable"

# ─── TEST GROUP 1: JSON FORMAT ─────────────────────────────────

echo ""
echo "Test Group 1: JSON Output Format"
echo "─────────────────────────────────"

# Test 1: --all produces valid JSON
echo -n "Test 1: qsession-id --all produces valid JSON ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
if echo "$output" | jq empty 2>/dev/null; then
  test_pass "JSON is valid"
else
  test_fail "JSON is invalid"
fi

# Test 2: --all output is array
echo -n "Test 2: --all output is JSON array ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
if echo "$output" | jq -e 'type == "array"' >/dev/null 2>&1; then
  test_pass "Output is array"
else
  test_fail "Output is not array"
fi

# Test 3: Array contains sessions
echo -n "Test 3: --all contains at least one session ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
count=$(echo "$output" | jq 'length' 2>/dev/null || echo "0")
if [[ "$count" -ge 1 ]]; then
  test_pass "Found $count session(s)"
else
  test_fail "No sessions found"
fi

# ─── TEST GROUP 2: UUID VERIFICATION ───────────────────────────

echo ""
echo "Test Group 2: UUID Verification Mode"
echo "─────────────────────────────────────"

known_uuid=$(
  "$QSESSION_ID" --all 2>/dev/null | jq -r '.[0].data.session_uuid' 2>/dev/null || echo ""
)

if [[ -n "$known_uuid" ]]; then
  test_pass "Extracted UUID: $known_uuid"

  # Test 4: UUID lookup returns JSON
  echo -n "Test 4: qsession-id <UUID> returns valid JSON ... "
  output=$("$QSESSION_ID" "$known_uuid" 2>/dev/null) || output=""
  if echo "$output" | jq empty 2>/dev/null; then
    test_pass "JSON is valid"
  else
    test_fail "JSON is invalid"
  fi

  # Test 5: UUID lookup returns matching UUID
  echo -n "Test 5: <UUID> returns correct UUID ... "
  output=$("$QSESSION_ID" "$known_uuid" 2>/dev/null) || output=""
  returned=$(echo "$output" | jq -r '.data.session_uuid' 2>/dev/null || echo "")
  if [[ "$returned" == "$known_uuid" ]]; then
    test_pass "UUID matches: $returned"
  else
    test_fail "UUID mismatch: expected $known_uuid, got $returned"
  fi

  # Test 6: UUID prefix matching
  echo -n "Test 6: UUID prefix matching (first 8 chars) ... "
  prefix="${known_uuid:0:8}"
  output=$("$QSESSION_ID" "$prefix" 2>/dev/null) || output=""
  returned=$(echo "$output" | jq -r '.data.session_uuid' 2>/dev/null || echo "")
  if [[ "$returned" == "$known_uuid" ]]; then
    test_pass "Prefix match works: $prefix"
  else
    test_fail "Prefix match failed"
  fi
else
  test_fail "Could not extract UUID from --all"
fi

# ─── TEST GROUP 3: GROUND TRUTH DATA ───────────────────────────

echo ""
echo "Test Group 3: Ground Truth Data"
echo "────────────────────────────────"

# Test 7: Inode is numeric
echo -n "Test 7: Inode field is numeric ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
inode=$(echo "$output" | jq -r '.[0].data.inode' 2>/dev/null || echo "")
if [[ "$inode" =~ ^[0-9]+$ ]]; then
  test_pass "Inode is numeric: $inode"
else
  test_fail "Inode not numeric: $inode"
fi

# Test 8: tasks_dir path format
echo -n "Test 8: tasks_dir follows /.../.claude/tasks/... format ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
tasks_dir=$(echo "$output" | jq -r '.[0].data.tasks_dir' 2>/dev/null || echo "")
if [[ "$tasks_dir" == *"/.claude/tasks/"* ]]; then
  test_pass "Path format correct: $tasks_dir"
else
  test_fail "Path format wrong: $tasks_dir"
fi

# Test 9: tasks_dir exists
echo -n "Test 9: tasks_dir path exists on filesystem ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
tasks_dir=$(echo "$output" | jq -r '.[0].data.tasks_dir' 2>/dev/null || echo "")
if [[ -d "$tasks_dir" ]]; then
  test_pass "Directory exists: $tasks_dir"
else
  test_fail "Directory missing: $tasks_dir"
fi

# Test 10: Inode matches filesystem
echo -n "Test 10: Reported inode matches filesystem inode ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
tasks_dir=$(echo "$output" | jq -r '.[0].data.tasks_dir' 2>/dev/null || echo "")
reported=$(echo "$output" | jq -r '.[0].data.inode' 2>/dev/null || echo "")
if [[ -d "$tasks_dir" ]]; then
  actual=$(stat -c %i "$tasks_dir" 2>/dev/null || echo "")
  if [[ "$reported" == "$actual" ]]; then
    test_pass "Inode matches: $reported == $actual"
  else
    test_fail "Inode mismatch: $reported != $actual"
  fi
else
  test_fail "tasks_dir missing"
fi

# ─── TEST GROUP 4: SOURCE ATTRIBUTION ──────────────────────────

echo ""
echo "Test Group 4: Source Attribution"
echo "────────────────────────────────"

# Test 11: Source field is GROUND_TRUTH
echo -n "Test 11: source field is 'GROUND_TRUTH' ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
source=$(echo "$output" | jq -r '.[0].source' 2>/dev/null || echo "")
if [[ "$source" == "GROUND_TRUTH" ]]; then
  test_pass "Source is correct: $source"
else
  test_fail "Source incorrect: $source"
fi

# Test 12: Required top-level fields
echo -n "Test 12: All required top-level fields present ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
has_all=true
for field in type timestamp unit data source error; do
  if ! echo "$output" | jq ".[0].$field" >/dev/null 2>&1; then
    has_all=false
    break
  fi
done
if $has_all; then
  test_pass "All fields: type, timestamp, unit, data, source, error"
else
  test_fail "Some required fields missing"
fi

# Test 13: Data object fields
echo -n "Test 13: Data object has required fields ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
has_all=true
for field in session_uuid inode tasks_dir; do
  if ! echo "$output" | jq ".[0].data.$field" >/dev/null 2>&1; then
    has_all=false
    break
  fi
done
if $has_all; then
  test_pass "Data fields: session_uuid, inode, tasks_dir"
else
  test_fail "Some data fields missing"
fi

# ─── TEST GROUP 5: ERROR HANDLING ─────────────────────────────

echo ""
echo "Test Group 5: Error Handling"
echo "────────────────────────────"

# Test 14: Invalid UUID returns error
echo -n "Test 14: Invalid UUID returns error ... "
output=$("$QSESSION_ID" "invalid-uuid-xxxx" 2>&1) || output=""
if echo "$output" | jq -e '.type == "error"' >/dev/null 2>&1; then
  test_pass "Error returned for invalid UUID"
else
  test_fail "Should return error for invalid UUID"
fi

# Test 15: Nonexistent UUID returns error
echo -n "Test 15: Nonexistent UUID returns error ... "
output=$("$QSESSION_ID" "ffffffff-ffff" 2>&1) || output=""
if echo "$output" | jq -e '.type == "error"' >/dev/null 2>&1; then
  test_pass "Error returned for nonexistent UUID"
else
  test_fail "Should return error for nonexistent UUID"
fi

# ─── TEST GROUP 6: METADATA ───────────────────────────────────

echo ""
echo "Test Group 6: Timestamp and Metadata"
echo "───────────────────────────────────"

# Test 16: Timestamp is ISO8601
echo -n "Test 16: Timestamp in ISO8601 format ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
timestamp=$(echo "$output" | jq -r '.[0].timestamp' 2>/dev/null || echo "")
if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  test_pass "Timestamp OK: $timestamp"
else
  test_fail "Timestamp format wrong: $timestamp"
fi

# Test 17: Unit field
echo -n "Test 17: Unit field is set to '1' ... "
output=$("$QSESSION_ID" --all 2>/dev/null) || output=""
unit=$(echo "$output" | jq -r '.[0].unit' 2>/dev/null || echo "")
if [[ "$unit" == "1" ]]; then
  test_pass "Unit field correct: $unit"
else
  test_fail "Unit field wrong: $unit"
fi

# ─── FINAL REPORT ──────────────────────────────────────────────

report

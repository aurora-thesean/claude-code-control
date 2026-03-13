#!/usr/bin/env bash
# Test NESTED_LOA progress reporting in qlaude

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QLAUDE="$SCRIPT_DIR/../qlaude"
AURORA_AGENT_DIR="$HOME/.aurora-agent"

test_pass() {
  echo "✓ $*"
}

test_fail() {
  echo "✗ $*"
  exit 1
}

# Setup
mkdir -p "$AURORA_AGENT_DIR"

# Use proper UUIDs
WARRANT_ID="00000000-0000-0000-0000-000000000001"
CHILD_UUID="11111111-1111-1111-1111-111111111111"

cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=4
IMPRINT_STATUS=test
CLAUDEMD
echo "$CHILD_UUID" > "$AURORA_AGENT_DIR/home-session-id"

# Test 1: Report progress with valid status
echo "Test 1: Report progress with valid status (IN_PROGRESS)"
output=$(bash "$QLAUDE" --report-progress "$WARRANT_ID" 5 5 0 IN_PROGRESS 2>&1)

if echo "$output" | grep -q '"status": "IN_PROGRESS"'; then
  test_pass "Progress report created successfully"
else
  test_fail "Progress report failed: $output"
fi

# Verify report file
report_file="$AURORA_AGENT_DIR/warrants/progress/${WARRANT_ID}_"*.jsonl
if ls "$report_file" 2>/dev/null | head -1 > /dev/null; then
  test_pass "Progress report file created"
else
  test_fail "Progress report file not found"
fi

# Test 2: Report completion
echo "Test 2: Report completion status"
output=$(bash "$QLAUDE" --report-progress "$WARRANT_ID" 10 9 1 COMPLETED 2>&1)

if echo "$output" | grep -q '"status": "COMPLETED"'; then
  test_pass "Completion report recorded"
  if echo "$output" | grep -q '"approval_rate"'; then
    test_pass "Approval rate calculated"
  else
    test_fail "Approval rate not calculated"
  fi
else
  test_fail "Completion report failed: $output"
fi

# Test 3: Report failure
echo "Test 3: Report failure status"
output=$(bash "$QLAUDE" --report-progress "$WARRANT_ID" 7 5 2 FAILED 2>&1)

if echo "$output" | grep -q '"status": "FAILED"'; then
  test_pass "Failure report recorded"
else
  test_fail "Failure report failed: $output"
fi

# Test 4: Invalid status rejected
echo "Test 4: Invalid status rejected"
output=$( { bash "$QLAUDE" --report-progress "$WARRANT_ID" 5 5 0 INVALID_STATUS 2>&1; } || true )

if echo "$output" | grep -q "Invalid status"; then
  test_pass "Invalid status correctly rejected"
else
  test_fail "Should reject invalid status (got: $output)"
fi

# Test 5: Invalid warrant_id rejected
echo "Test 5: Invalid warrant_id rejected"
output=$( { bash "$QLAUDE" --report-progress "not-a-uuid" 5 5 0 2>&1; } || true )

if echo "$output" | grep -q "Invalid warrant_id"; then
  test_pass "Invalid warranty_id correctly rejected"
else
  test_fail "Should reject invalid warranty_id (got: $output)"
fi

# Test 6: Progress reports are valid JSON
echo "Test 6: Progress reports are valid JSON"
for report_file in "$AURORA_AGENT_DIR/warrants/progress"/*.jsonl; do
  if [[ -f "$report_file" ]]; then
    if python3 -m json.tool "$report_file" > /dev/null 2>&1; then
      test_pass "Valid JSON: $(basename "$report_file")"
    else
      test_fail "Invalid JSON: $(basename "$report_file")"
    fi
  fi
done

echo ""
echo "All progress reporting tests passed! ✓"

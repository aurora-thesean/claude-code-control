#!/usr/bin/env bash
# Test NESTED_LOA warrant validation in qlaude

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

# Test 1: Create a warrant and validate it
echo "Test 1: Valid warrant passes validation"
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=6
IMPRINT_STATUS=test
CLAUDEMD
echo "00000000-0000-0000-0000-000000000001" > "$AURORA_AGENT_DIR/home-session-id"

# Create warrant
create_output=$(bash "$QLAUDE" --delegate "test task" --to "11111111-1111-1111-1111-111111111111" --with-loa 4 2>&1)
warrant_id=$(echo "$create_output" | grep -o '"warrant_id": "[^"]*"' | cut -d'"' -f4)
warrant_file="$AURORA_AGENT_DIR/warrants/$warrant_id.json"

# Validate
validate_output=$(bash "$QLAUDE" --validate-warrant "$warrant_file" 2>&1)
if echo "$validate_output" | grep -q '"status": "VALID"'; then
  test_pass "Warrant validates successfully"
else
  test_fail "Warrant validation failed: $validate_output"
fi

# Test 2: Non-existent warrant fails validation
echo "Test 2: Non-existent warrant fails validation"
nonexistent="$AURORA_AGENT_DIR/warrants/nonexistent.json"
output=$( { bash "$QLAUDE" --validate-warrant "$nonexistent" 2>&1; } || true )
if echo "$output" | grep -q "not found"; then
  test_pass "Non-existent warrant correctly rejected"
else
  test_fail "Should reject non-existent warrant (got: $output)"
fi

# Test 3: Invalid JSON warrant
echo "Test 3: Invalid JSON warrant fails validation"
invalid_file="$AURORA_AGENT_DIR/warrants/invalid.json"
echo "{ invalid json" > "$invalid_file"
output=$(bash "$QLAUDE" --validate-warrant "$invalid_file" 2>&1)
if echo "$output" | grep -q "not valid JSON"; then
  test_pass "Invalid JSON correctly rejected"
else
  test_fail "Should reject invalid JSON (got: $output)"
fi

# Test 4: Expired warrant fails validation
echo "Test 4: Expired warrant fails validation"
cat > "$AURORA_AGENT_DIR/warrants/expired.json" << 'WJSON'
{
  "type": "loa_proposal",
  "warrant_id": "expired-test",
  "parent_uuid": "parent-test",
  "child_uuid": "child-test",
  "task_description": "test task",
  "proposed_loa_cap": 4,
  "parent_loa_cap": 6,
  "expires_at": "2020-01-01T00:00:00Z"
}
WJSON

output=$(bash "$QLAUDE" --validate-warrant "$AURORA_AGENT_DIR/warrants/expired.json" 2>&1)
if echo "$output" | grep -q '"status": "EXPIRED"'; then
  test_pass "Expired warrant correctly rejected"
else
  test_fail "Should reject expired warrant (got: $output)"
fi

# Test 5: LOA_CAP violation detected
echo "Test 5: LOA_CAP hierarchy violation detected"
cat > "$AURORA_AGENT_DIR/warrants/bad-loa.json" << 'WJSON'
{
  "type": "loa_proposal",
  "warrant_id": "bad-loa-test",
  "parent_uuid": "parent-test",
  "child_uuid": "child-test",
  "task_description": "test task",
  "proposed_loa_cap": 8,
  "parent_loa_cap": 4,
  "expires_at": "2099-01-01T00:00:00Z"
}
WJSON

output=$(bash "$QLAUDE" --validate-warrant "$AURORA_AGENT_DIR/warrants/bad-loa.json" 2>&1)
if echo "$output" | grep -q "exceeds parent LOA_CAP"; then
  test_pass "LOA_CAP violation correctly detected"
else
  test_fail "Should detect LOA_CAP violation (got: $output)"
fi

echo ""
echo "All warrant validation tests passed! ✓"

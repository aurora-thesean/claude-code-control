#!/usr/bin/env bash
# Test NESTED_LOA warrant creation in qlaude

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

# Test 1: Warrant creation requires QC2
echo "Test 1: Warrant creation gate (requires QC2)"
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=2
IMPRINT_STATUS=test
CLAUDEMD
echo "00000000-0000-0000-0000-000000000001" > "$AURORA_AGENT_DIR/home-session-id"

# Capture stderr/stdout and check for rejection
output=$( { bash "$QLAUDE" --delegate "test task" --to "11111111-1111-1111-1111-111111111111" --with-loa 4 2>&1; } || true )
if echo "$output" | grep -q "QC0"; then
  test_pass "QC0 correctly rejects warrant creation"
else
  test_fail "QC0 should reject warrant creation (got: $output)"
fi

# Test 2: Valid warrant creation with QC2
echo "Test 2: Valid warrant creation with QC2"
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=6
IMPRINT_STATUS=test
CLAUDEMD

output=$(bash "$QLAUDE" --delegate "optimize database queries" --to "22222222-2222-2222-2222-222222222222" --with-loa 4 2>&1)

if echo "$output" | grep -q "warrant_id"; then
  test_pass "Warrant created successfully"
  warrant_id=$(echo "$output" | grep -o '"warrant_id": "[^"]*"' | cut -d'"' -f4)
  test_pass "Warrant ID: $warrant_id"
else
  test_fail "Warrant creation failed: $output"
fi

# Test 3: Warrant file exists and is valid JSON
echo "Test 3: Warrant file validation"
warrant_file="$AURORA_AGENT_DIR/warrants/$warrant_id.json"
if [[ ! -f "$warrant_file" ]]; then
  test_fail "Warrant file not found: $warrant_file"
fi

if python3 -m json.tool "$warrant_file" > /dev/null 2>&1; then
  test_pass "Warrant file contains valid JSON"
else
  test_fail "Warrant file is not valid JSON"
fi

# Test 4: Warrant contains required fields
echo "Test 4: Warrant field validation"
for field in type warrant_id parent_uuid child_uuid proposed_loa_cap created_at expires_at; do
  if grep -q "\"$field\"" "$warrant_file"; then
    test_pass "Field present: $field"
  else
    test_fail "Required field missing: $field"
  fi
done

# Test 5: Invalid child UUID rejected
echo "Test 5: Invalid UUID rejection"
output=$( { bash "$QLAUDE" --delegate "task" --to "not-a-uuid" --with-loa 4 2>&1; } || true )
if echo "$output" | grep -q "Invalid.*UUID"; then
  test_pass "Invalid UUID correctly rejected"
else
  test_fail "Should reject invalid UUID (got: $output)"
fi

# Test 6: LOA_CAP validation
echo "Test 6: LOA_CAP validation"
output=$( { bash "$QLAUDE" --delegate "task" --to "22222222-2222-2222-2222-222222222222" --with-loa 8 2>&1; } || true )
if echo "$output" | grep -q "Cannot propose"; then
  test_pass "Proposed LOA > parent LOA correctly rejected"
else
  test_fail "Should reject proposed LOA > parent LOA (got: $output)"
fi

echo ""
echo "All warrant creation tests passed! ✓"

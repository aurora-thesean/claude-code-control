#!/usr/bin/env bash
# Test NESTED_LOA warrant acceptance in qlaude

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

# Use proper UUIDs for testing
PARENT_UUID="00000000-0000-0000-0000-000000000001"
CHILD_UUID="11111111-1111-1111-1111-111111111111"
CHILD2_UUID="22222222-2222-2222-2222-222222222222"

# Setup parent as QC2
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=6
IMPRINT_STATUS=test
CLAUDEMD
echo "$PARENT_UUID" > "$AURORA_AGENT_DIR/home-session-id"

# Create warrant from parent
parent_output=$(bash "$QLAUDE" --delegate "optimize database" --to "$CHILD_UUID" --with-loa 4 2>&1)
warrant_id=$(echo "$parent_output" | grep -o '"warrant_id": "[^"]*"' | tail -1 | cut -d'"' -f4)
warrant_file="$AURORA_AGENT_DIR/warrants/$warrant_id.json"

if [[ -z "$warrant_id" ]]; then
  test_fail "Could not extract warrant_id from parent output"
fi

test_pass "Parent created warrant: $warrant_id"

# Switch to child identity
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=4
IMPRINT_STATUS=test
CLAUDEMD
echo "$CHILD_UUID" > "$AURORA_AGENT_DIR/home-session-id"

# Test 1: Child accepts warrant
echo "Test 1: Child accepts warrant"
acceptance=$(bash "$QLAUDE" --accept-warrant "$warrant_file" 2>&1)

if echo "$acceptance" | grep -q '"status": "ACCEPTED"'; then
  test_pass "Child successfully accepted warrant"
  # Verify acceptance record was created
  if [[ -f "$AURORA_AGENT_DIR/warrants/acceptances/${warrant_id}_acceptance.jsonl" ]]; then
    test_pass "Acceptance record file created"
  else
    test_fail "Acceptance record file not created"
  fi
else
  test_fail "Child acceptance failed: $acceptance"
fi

# Test 2: Child with lower LOA counter-proposes
echo "Test 2: Child with lower LOA counter-proposes"
# Keep parent LOA high enough (6), but propose LOA=4 to child
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=6
IMPRINT_STATUS=test
CLAUDEMD
echo "$PARENT_UUID" > "$AURORA_AGENT_DIR/home-session-id"

parent_output=$(bash "$QLAUDE" --delegate "complex task" --to "$CHILD2_UUID" --with-loa 4 2>&1)
warrant_id_2=$(echo "$parent_output" | grep -o '"warrant_id": "[^"]*"' | tail -1 | cut -d'"' -f4)
warrant_file_2="$AURORA_AGENT_DIR/warrants/$warrant_id_2.json"

if [[ -z "$warrant_id_2" ]]; then
  test_fail "Could not extract warrant_id_2 from parent output"
fi

# Switch child to lower LOA
cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEMD'
LOA_CAP=2
IMPRINT_STATUS=test
CLAUDEMD
echo "$CHILD2_UUID" > "$AURORA_AGENT_DIR/home-session-id"

acceptance=$(bash "$QLAUDE" --accept-warrant "$warrant_file_2" --counter-propose 2 2>&1)

if echo "$acceptance" | grep -q '"status": "NEGOTIATED"'; then
  test_pass "Child correctly counter-proposed lower LOA"
  if echo "$acceptance" | grep -q '"accepted_loa_cap": 2'; then
    test_pass "Counter-proposal value correct (LOA_CAP=2)"
  else
    test_fail "Counter-proposal value incorrect"
  fi
else
  test_fail "Counter-proposal failed: $acceptance"
fi

# Test 3: Acceptance records are valid JSON
echo "Test 3: Acceptance records are valid JSON"
for acceptance_file in "$AURORA_AGENT_DIR/warrants/acceptances"/*.jsonl; do
  if [[ -f "$acceptance_file" ]]; then
    if python3 -m json.tool "$acceptance_file" > /dev/null 2>&1; then
      test_pass "Valid JSON: $(basename "$acceptance_file")"
    else
      test_fail "Invalid JSON: $(basename "$acceptance_file")"
    fi
  fi
done

echo ""
echo "All warrant acceptance tests passed! ✓"

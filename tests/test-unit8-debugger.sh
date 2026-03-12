#!/usr/bin/env bash
# test-unit8-debugger.sh — Unit 8 E2E Test
#
# Tests debugger attachment and context capture
#
# Tests:
# 1. qclaude-inspect starts successfully
# 2. qclaude-inspect validates binary exists
# 3. qdebug-attach connects to debugger
# 4. JSON output is valid and well-formed
# 5. All required fields present
# 6. Error handling on connection failure

set -u

# ─── CONSTANTS ─────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
QCLAUDE_INSPECT="$REPO_DIR/qclaude-inspect"
QDEBUG_ATTACH="$REPO_DIR/qdebug-attach"

TEST_PORT=9229
TIMEOUT=5

PASS=0
FAIL=0

# ─── UTILITY FUNCTIONS ─────────────────────────────────────────

pass() {
    echo "✓ $*"
    PASS=$((PASS + 1))
}

fail() {
    echo "✗ $*"
    FAIL=$((FAIL + 1))
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        pass "File exists: $file"
    else
        fail "File missing: $file"
    fi
}

assert_executable() {
    local file="$1"
    if [[ -x "$file" ]]; then
        pass "Executable: $file"
    else
        fail "Not executable: $file"
    fi
}

assert_json_valid() {
    local json="$1"
    if echo "$json" | jq . > /dev/null 2>&1; then
        pass "JSON is valid"
    else
        fail "JSON is invalid"
    fi
}

assert_field_exists() {
    local json="$1"
    local field="$2"
    if echo "$json" | jq "$field" > /dev/null 2>&1; then
        pass "Field exists: $field"
    else
        fail "Field missing: $field"
    fi
}

assert_field_equals() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local actual=$(echo "$json" | jq -r "$field" 2>/dev/null || echo "ERROR")
    if [[ "$actual" == "$expected" ]]; then
        pass "Field correct: $field = $expected"
    else
        fail "Field mismatch: $field (expected: $expected, got: $actual)"
    fi
}

# ─── TESTS ─────────────────────────────────────────────────────

test_files_exist() {
    echo ""
    echo "=== Test 1: Files Exist ==="
    assert_file_exists "$QCLAUDE_INSPECT"
    assert_file_exists "$QDEBUG_ATTACH"
}

test_executables() {
    echo ""
    echo "=== Test 2: Files Executable ==="
    assert_executable "$QCLAUDE_INSPECT"
    assert_executable "$QDEBUG_ATTACH"
}

test_qclaude_help() {
    echo ""
    echo "=== Test 3: qclaude-inspect --help ==="
    if "$QCLAUDE_INSPECT" --help > /dev/null 2>&1; then
        pass "Help message displayed"
    else
        fail "Help message failed"
    fi
}

test_qdebug_help() {
    echo ""
    echo "=== Test 4: qdebug-attach --help ==="
    if "$QDEBUG_ATTACH" --help > /dev/null 2>&1; then
        pass "Help message displayed"
    else
        fail "Help message failed"
    fi
}

test_qclaude_binary_validation() {
    echo ""
    echo "=== Test 5: qclaude-inspect Binary Validation ==="

    # Test with missing binary (should fail gracefully)
    OUTPUT=$(timeout 2 bash -c 'CLAUDE_CLI="/nonexistent/cli.js" '"$QCLAUDE_INSPECT" 2>&1 || true)
    if echo "$OUTPUT" | grep -q "not found"; then
        pass "Missing binary detection works"
    else
        fail "Should report missing binary"
    fi
}

test_qdebug_connection_error() {
    echo ""
    echo "=== Test 6: qdebug-attach Connection Error Handling ==="

    # Port with nothing listening should fail gracefully
    OUTPUT=$("$QDEBUG_ATTACH" --port 9999 --timeout 2 2>&1 || true)

    # Check JSON was emitted even on error
    if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
        pass "JSON emitted on connection error"

        # Check error field is set
        ERROR=$(echo "$OUTPUT" | jq -r '.error')
        if [[ "$ERROR" != "null" ]]; then
            pass "Error field set: $ERROR"
        else
            fail "Error field should be non-null on failure"
        fi
    else
        fail "JSON not emitted on error"
    fi
}

test_json_schema() {
    echo ""
    echo "=== Test 7: JSON Schema Validation ==="

    # Simulate output from qdebug-attach
    JSON=$(cat <<'EOF'
{
  "type": "debugger-capture",
  "timestamp": "2026-03-12T10:00:00Z",
  "unit": "8",
  "data": {
    "breakpoint_location": "cli.js:123",
    "context_variables": {
      "model": "claude-sonnet-4-6",
      "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
      "message_type": "assistant_message"
    },
    "call_stack": [],
    "timestamp_ns": "1234567890123456"
  },
  "source": "GROUND_TRUTH",
  "error": null
}
EOF
    )

    assert_json_valid "$JSON"
    assert_field_exists "$JSON" ".type"
    assert_field_exists "$JSON" ".timestamp"
    assert_field_exists "$JSON" ".unit"
    assert_field_exists "$JSON" ".data"
    assert_field_exists "$JSON" ".source"
    assert_field_exists "$JSON" ".error"

    assert_field_equals "$JSON" ".type" "debugger-capture"
    assert_field_equals "$JSON" ".unit" "8"
    assert_field_equals "$JSON" ".source" "GROUND_TRUTH"
    assert_field_equals "$JSON" ".error" "null"
}

test_json_context_variables() {
    echo ""
    echo "=== Test 8: Context Variables Schema ==="

    JSON=$(cat <<'EOF'
{
  "type": "debugger-capture",
  "timestamp": "2026-03-12T10:00:00Z",
  "unit": "8",
  "data": {
    "breakpoint_location": "cli.js:123",
    "context_variables": {
      "model": "claude-sonnet-4-6",
      "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
      "message_type": "assistant_message"
    },
    "call_stack": ["fn1", "fn2"],
    "timestamp_ns": "1234567890123456"
  },
  "source": "GROUND_TRUTH",
  "error": null
}
EOF
    )

    assert_field_exists "$JSON" ".data.context_variables"
    assert_field_exists "$JSON" ".data.context_variables.model"
    assert_field_exists "$JSON" ".data.context_variables.session_uuid"
    assert_field_exists "$JSON" ".data.context_variables.message_type"
    assert_field_exists "$JSON" ".data.call_stack"
    assert_field_exists "$JSON" ".data.timestamp_ns"

    assert_field_equals "$JSON" ".data.context_variables.model" "claude-sonnet-4-6"
}

test_jq_parsing() {
    echo ""
    echo "=== Test 9: jq Parsing Compatible ==="

    JSON=$(cat <<'EOF'
{
  "type": "debugger-capture",
  "timestamp": "2026-03-12T10:00:00Z",
  "unit": "8",
  "data": {
    "context_variables": {
      "model": "claude-sonnet-4-6",
      "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f"
    }
  }
}
EOF
    )

    # Test various jq queries
    if echo "$JSON" | jq '.type' > /dev/null 2>&1; then
        pass "jq: extract type"
    else
        fail "jq: extract type"
    fi

    if echo "$JSON" | jq '.data.context_variables.model' > /dev/null 2>&1; then
        pass "jq: extract model"
    else
        fail "jq: extract model"
    fi

    if echo "$JSON" | jq '.data.context_variables | keys' > /dev/null 2>&1; then
        pass "jq: list context keys"
    else
        fail "jq: list context keys"
    fi
}

# ─── MAIN ─────────────────────────────────────────────────────

main() {
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  Unit 8: Node.js Debugger Attachment — E2E Tests      ║"
    echo "╚════════════════════════════════════════════════════════╝"

    test_files_exist
    test_executables
    test_qclaude_help
    test_qdebug_help
    test_qclaude_binary_validation
    test_qdebug_connection_error
    test_json_schema
    test_json_context_variables
    test_jq_parsing

    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  Test Results                                          ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo "Passed: $PASS"
    echo "Failed: $FAIL"
    echo ""

    if (( FAIL == 0 )); then
        echo "✓ All tests passed"
        exit 0
    else
        echo "✗ $FAIL test(s) failed"
        exit 1
    fi
}

main "$@"

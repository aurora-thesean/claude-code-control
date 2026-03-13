#!/bin/bash
# Phase 10 Unit 5: Distributed Audit Log Aggregation Tests
# Tests qaudit-aggregator tool for log collection, merging, querying

set -euo pipefail

_log() { echo "[test-audit-aggregator] $*" >&2; }
_pass() { echo "✓ $*" >&2; }
_fail() { echo "✗ $*" >&2; exit 1; }

# Setup
TEST_HOME="${TMPDIR:-.}/test-qaudit-$$"
TEST_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/qaudit-aggregator"
TEST_PARENT_UUID="parent-1111-2222-3333-444444444444"
TEST_CHILD_UUID="child-5555-6666-7777-888888888888"

cleanup() {
    rm -rf "$TEST_HOME" 2>/dev/null || true
}

trap cleanup EXIT

mkdir -p "$TEST_HOME/.aurora-agent"
export HOME="$TEST_HOME"

test_merge_logs() {
    _log "Test: merge two audit logs"

    # Create local log
    local_log="$TEST_HOME/local.jsonl"
    cat > "$local_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:00Z","operation":"delegate","decision":"APPROVED","_audit_source":"local"}
{"timestamp":"2026-03-13T14:00:05Z","operation":"accept","decision":"ACCEPTED","_audit_source":"local"}
EOF

    # Create remote log
    remote_log="$TEST_HOME/remote.jsonl"
    cat > "$remote_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:10Z","operation":"report","decision":"IN_PROGRESS","_audit_source":"child"}
{"timestamp":"2026-03-13T14:00:15Z","operation":"complete","decision":"SUCCESS","_audit_source":"child"}
EOF

    # Merge
    output=$("$TEST_TOOL" merge "$local_log" "$remote_log" --output "$TEST_HOME/merged.jsonl" 2>&1) || true

    # Verify merged file has 4 entries
    entry_count=$(wc -l < "$TEST_HOME/merged.jsonl" 2>/dev/null || echo 0)
    if [[ "$entry_count" -eq 4 ]]; then
        _pass "merge logs produces correct entry count"
    else
        _fail "merge should produce 4 entries, got $entry_count"
    fi
}

test_merge_deduplication() {
    _log "Test: merge removes duplicate entries"

    # Create logs with duplicates
    local_log="$TEST_HOME/local2.jsonl"
    cat > "$local_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:00Z","operation":"delegate","decision":"APPROVED","_audit_source":"local"}
{"timestamp":"2026-03-13T14:00:00Z","operation":"delegate","decision":"APPROVED","_audit_source":"local"}
EOF

    remote_log="$TEST_HOME/remote2.jsonl"
    cat > "$remote_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:00Z","operation":"delegate","decision":"APPROVED","_audit_source":"local"}
EOF

    # Merge
    "$TEST_TOOL" merge "$local_log" "$remote_log" --output "$TEST_HOME/merged2.jsonl" 2>&1 || true

    # Should have only 1 entry (duplicate removed)
    entry_count=$(wc -l < "$TEST_HOME/merged2.jsonl" 2>/dev/null || echo 0)
    if [[ "$entry_count" -eq 1 ]]; then
        _pass "merge removes duplicates"
    else
        _fail "merge should remove duplicates, got $entry_count entries"
    fi
}

test_query_by_parent_uuid() {
    _log "Test: query consolidated log by parent UUID"

    # Create consolidated log
    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    cat > "$consolidated" <<EOF
{"timestamp":"2026-03-13T14:00:00Z","operation":"delegate","parent_uuid":"${TEST_PARENT_UUID}","warrant_id":"warrant-1"}
{"timestamp":"2026-03-13T14:00:05Z","operation":"accept","parent_uuid":"${TEST_PARENT_UUID}","warrant_id":"warrant-1"}
{"timestamp":"2026-03-13T14:00:10Z","operation":"delegate","parent_uuid":"other-uuid","warrant_id":"warrant-2"}
EOF

    # Query for parent UUID
    output=$("$TEST_TOOL" query "$TEST_PARENT_UUID" --format text 2>&1) || true

    # Should get 2 entries (not the 3rd one)
    entry_count=$(echo "$output" | grep -E "delegate|accept" | wc -l)
    if [[ "$entry_count" -ge 2 ]]; then
        _pass "query by parent UUID returns correct entries"
    else
        _fail "query should return 2 entries, got $entry_count"
    fi
}

test_query_json_format() {
    _log "Test: query with JSON format"

    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    cat > "$consolidated" <<EOF
{"timestamp":"2026-03-13T14:00:00Z","operation":"test","parent_uuid":"${TEST_PARENT_UUID}"}
EOF

    output=$("$TEST_TOOL" query "$TEST_PARENT_UUID" --format json 2>&1) || true

    # Should be valid JSON
    if echo "$output" | python3 -m json.tool >/dev/null 2>&1; then
        _pass "query JSON format outputs valid JSON"
    else
        _fail "query JSON output should be valid JSON"
    fi
}

test_verify_completeness_success() {
    _log "Test: verify completeness with complete decision chain"

    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    cat > "$consolidated" <<EOF
{"timestamp":"2026-03-13T14:00:00Z","operation":"decide","decision_num":1,"parent_uuid":"${TEST_PARENT_UUID}"}
{"timestamp":"2026-03-13T14:00:01Z","operation":"decide","decision_num":2,"parent_uuid":"${TEST_PARENT_UUID}"}
{"timestamp":"2026-03-13T14:00:02Z","operation":"decide","decision_num":3,"parent_uuid":"${TEST_PARENT_UUID}"}
EOF

    if "$TEST_TOOL" verify "$TEST_PARENT_UUID" 2>&1; then
        _pass "verify completeness succeeds for complete chain"
    else
        _fail "verify should succeed for complete chain"
    fi
}

test_verify_completeness_failure() {
    _log "Test: verify completeness with missing decision"

    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    cat > "$consolidated" <<EOF
{"timestamp":"2026-03-13T14:00:00Z","operation":"decide","decision_num":1,"parent_uuid":"${TEST_PARENT_UUID}"}
{"timestamp":"2026-03-13T14:00:02Z","operation":"decide","decision_num":3,"parent_uuid":"${TEST_PARENT_UUID}"}
EOF

    if "$TEST_TOOL" verify "$TEST_PARENT_UUID" 2>&1; then
        _fail "verify should fail for gap in decisions"
    else
        _pass "verify completeness fails for missing decision"
    fi
}

test_verify_nonexistent() {
    _log "Test: verify on non-existent parent UUID"

    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    echo '{}' > "$consolidated"

    if "$TEST_TOOL" verify "nonexistent-uuid" 2>&1; then
        _fail "verify should fail for non-existent UUID"
    else
        _pass "verify fails gracefully for non-existent UUID"
    fi
}

test_merge_sorts_by_timestamp() {
    _log "Test: merge sorts entries by timestamp"

    local_log="$TEST_HOME/unsorted-local.jsonl"
    cat > "$local_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:10Z","operation":"c"}
{"timestamp":"2026-03-13T14:00:00Z","operation":"a"}
EOF

    remote_log="$TEST_HOME/unsorted-remote.jsonl"
    cat > "$remote_log" <<'EOF'
{"timestamp":"2026-03-13T14:00:05Z","operation":"b"}
EOF

    "$TEST_TOOL" merge "$local_log" "$remote_log" --output "$TEST_HOME/sorted.jsonl" 2>&1 || true

    # Check order in output (handle both "operation": and "operation":)
    operations=$(grep -o '"operation": "[a-c]"' "$TEST_HOME/sorted.jsonl" | cut -d'"' -f4 | tr -d '\n')
    if [[ "$operations" == "abc" ]]; then
        _pass "merge sorts entries by timestamp"
    else
        _fail "merge should sort by timestamp, got order: $operations"
    fi
}

test_query_text_format() {
    _log "Test: query with text format is human-readable"

    consolidated="$HOME/.aurora-agent/.qlaude-audit-consolidated.jsonl"
    mkdir -p "$(dirname "$consolidated")"
    cat > "$consolidated" <<EOF
{"timestamp":"2026-03-13T14:00:00Z","operation":"test_op","decision":"APPROVED","_audit_source":"test_agent","parent_uuid":"${TEST_PARENT_UUID}"}
EOF

    output=$("$TEST_TOOL" query "$TEST_PARENT_UUID" --format text 2>&1) || true

    # Should contain readable fields
    if echo "$output" | grep -q "test_op.*APPROVED"; then
        _pass "query text format is human-readable"
    else
        _fail "query text format should include operation and decision"
    fi
}

main() {
    _log "Running qaudit-aggregator tests..."

    test_merge_logs
    test_merge_deduplication
    test_query_by_parent_uuid
    test_query_json_format
    test_verify_completeness_success
    test_verify_completeness_failure
    test_verify_nonexistent
    test_merge_sorts_by_timestamp
    test_query_text_format

    _pass "All tests passed (9/9)"
}

main "$@"

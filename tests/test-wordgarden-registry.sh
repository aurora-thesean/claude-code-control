#!/bin/bash
# Phase 10 Unit 4: Wordgarden Registry Client Tests
# Tests qwordgarden-registry tool for DNS resolution, caching, fallback

set -euo pipefail

_log() { echo "[test-wordgarden-registry] $*" >&2; }
_pass() { echo "✓ $*" >&2; }
_fail() { echo "✗ $*" >&2; exit 1; }

# Setup
TEST_CACHE="${TMPDIR:-.}/test-wordgarden-registry-$RANDOM.jsonl"
TEST_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/qwordgarden-registry"
TEST_UUID="12345678-1234-1234-1234-123456789012"

cleanup() {
    rm -f "$TEST_CACHE" 2>/dev/null || true
    unset AURORA_AGENT_HOME
}

trap cleanup EXIT

# Override cache location for testing
export HOME="/tmp/qwordgarden-test-$$"
mkdir -p "$HOME/.aurora-agent"

test_list_empty() {
    _log "Test: list empty cache"
    output=$("$TEST_TOOL" --list 2>&1) || true
    if echo "$output" | grep -q "No cache"; then
        _pass "list empty cache"
    else
        _fail "list should show 'No cache' for empty registry"
    fi
}

test_resolve_invalid_uuid() {
    _log "Test: resolve with invalid UUID format"
    # Should attempt to resolve even with malformed UUID
    output=$("$TEST_TOOL" "not-a-uuid" 2>&1 || true)
    if echo "$output" | grep -q "Could not resolve\|error"; then
        _pass "resolve invalid UUID returns error"
    else
        _fail "resolve invalid UUID should return error"
    fi
}

test_cache_write_and_read() {
    _log "Test: cache write and read"
    # Simulate a cached entry by directly writing it
    cache_dir="$HOME/.aurora-agent"
    mkdir -p "$cache_dir"

    cat > "$cache_dir/wordgarden-registry.jsonl" <<EOF
{"uuid":"${TEST_UUID}","hostname":"test-agent.wordgarden.dev","port":9231,"source":"dns","timestamp":"$(date -u +'%Y-%m-%dT%H:%M:%SZ')","cache_ttl":300}
EOF

    # Try to list and verify it appears
    output=$("$TEST_TOOL" --list 2>&1) || true
    if echo "$output" | grep -q "test-agent.wordgarden.dev"; then
        _pass "cache write and read"
    else
        _fail "cached entry not found in list"
    fi
}

test_list_format_json() {
    _log "Test: list with JSON format"
    cache_dir="$HOME/.aurora-agent"

    output=$("$TEST_TOOL" --list --format json 2>&1) || true
    if echo "$output" | grep -q '"\(uuid\|hostname\)"'; then
        _pass "list JSON format"
    else
        _fail "list JSON format should output JSON"
    fi
}

test_list_format_text() {
    _log "Test: list with text format"
    output=$("$TEST_TOOL" --list --format text 2>&1) || true
    # Text format should not have curly braces
    if ! echo "$output" | grep -q '{'; then
        _pass "list text format"
    else
        _fail "list text format should not contain JSON"
    fi
}

test_clear_cache() {
    _log "Test: clear cache"
    cache_dir="$HOME/.aurora-agent"
    cache_file="$cache_dir/wordgarden-registry.jsonl"

    # Write dummy cache
    mkdir -p "$cache_dir"
    echo '{"uuid":"dummy"}' > "$cache_file"

    # Clear it
    "$TEST_TOOL" --clear-cache 2>&1 || true

    if [[ ! -f "$cache_file" ]]; then
        _pass "clear cache"
    else
        _fail "cache file should be deleted"
    fi
}

test_sync_registry() {
    _log "Test: sync registry (cleanup expired)"
    cache_dir="$HOME/.aurora-agent"
    cache_file="$cache_dir/wordgarden-registry.jsonl"

    mkdir -p "$cache_dir"

    # Write an expired entry (timestamp from 1 hour ago, TTL of 60 seconds)
    old_time=$(date -u -d '1 hour ago' +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-1H +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '2026-01-01T00:00:00Z')
    cat > "$cache_file" <<EOF
{"uuid":"expired-agent","hostname":"old.wordgarden.dev","port":9231,"source":"dns","timestamp":"${old_time}","cache_ttl":60}
EOF

    # Sync
    "$TEST_TOOL" --sync 2>&1 || true

    # Check that expired entry was removed
    if [[ ! -s "$cache_file" ]] || ! grep -q "expired-agent" "$cache_file"; then
        _pass "sync registry removes expired entries"
    else
        _fail "sync should remove expired entries"
    fi
}

test_cache_validity_check() {
    _log "Test: cache validity check with fresh entry"
    cache_dir="$HOME/.aurora-agent"
    cache_file="$cache_dir/wordgarden-registry.jsonl"

    mkdir -p "$cache_dir"

    # Write a fresh entry (now, TTL 300s)
    now=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    cat > "$cache_file" <<EOF
{"uuid":"fresh-agent","hostname":"fresh.wordgarden.dev","port":9231,"source":"dns","timestamp":"${now}","cache_ttl":300}
EOF

    # List should show it as valid (✓)
    output=$("$TEST_TOOL" --list 2>&1) || true
    if echo "$output" | grep -q '✓.*fresh.wordgarden.dev'; then
        _pass "cache validity check shows fresh entry as valid"
    else
        _fail "fresh entry should show as valid (✓)"
    fi
}

test_output_format() {
    _log "Test: single UUID resolution output format"
    cache_dir="$HOME/.aurora-agent"
    cache_file="$cache_dir/wordgarden-registry.jsonl"

    mkdir -p "$cache_dir"

    # Add cache entry
    now=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    test_uuid="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    cat > "$cache_file" <<EOF
{"uuid":"${test_uuid}","hostname":"test-resolved.wordgarden.dev","port":9231,"source":"dns","timestamp":"${now}","cache_ttl":300}
EOF

    # Resolve UUID (capture stdout only, stderr separately)
    output=$("$TEST_TOOL" "$test_uuid" 2>/dev/null) || true

    # Check output is valid JSON with required fields
    if echo "$output" | python3 -m json.tool >/dev/null 2>&1; then
        if echo "$output" | grep -q "location_resolved"; then
            _pass "single UUID resolution output is valid JSON"
        else
            _fail "output should contain 'location_resolved' type"
        fi
    else
        _fail "output should be valid JSON"
    fi
}

test_health_check_nonexistent() {
    _log "Test: health check on non-cached agent"
    output=$("$TEST_TOOL" --health-check "nonexistent-uuid" 2>&1 || true)

    if echo "$output" | grep -q "not in cache"; then
        _pass "health check rejects non-cached agent"
    else
        _fail "health check should reject non-cached agent"
    fi
}

main() {
    _log "Running qwordgarden-registry tests..."

    # Run tests in sequence
    test_list_empty
    test_resolve_invalid_uuid
    test_cache_write_and_read
    test_list_format_json
    test_list_format_text
    test_clear_cache
    test_sync_registry
    test_cache_validity_check
    test_output_format
    test_health_check_nonexistent

    _pass "All tests passed (10/10)"
}

main "$@"

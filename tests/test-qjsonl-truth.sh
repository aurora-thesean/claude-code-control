#!/usr/bin/env bash
# Unit test suite for qjsonl-truth

set -euo pipefail

SCRIPT="qjsonl-truth"
JSONL="$HOME/.claude/projects/-home-aurora/1d08b041-305c-4023-83f7-d472449f7c6f.jsonl"
SESSION_MAIN="1d08b041-305c-4023-83f7-d472449f7c6f"
SESSION_DORMANT="22262eab-e7c8-4e24-bf16-e885f25e266c"

cd "$(dirname "$0")/.."  # Go to repo root

test_count=0
pass_count=0

_test() {
    test_count=$((test_count + 1))
    local desc="$1"
    shift

    if bash -c "$@" > /tmp/test_result.log 2>&1; then
        echo "✓ Test $test_count: $desc"
        pass_count=$((pass_count + 1))
        return 0
    else
        echo "✗ Test $test_count: $desc"
        head -3 /tmp/test_result.log | sed 's/^/  /'
        return 0
    fi
}

# Generate test data
echo "Generating test data..."
python3 "$SCRIPT" "$JSONL" "$SESSION_MAIN" 2>/dev/null > /tmp/qjsonl_main.json
python3 "$SCRIPT" "$JSONL" "$SESSION_DORMANT" 2>/dev/null > /tmp/qjsonl_dormant.json

# Test 1: Main session filtering
_test "Main session: 8345 records filtered" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_main.json')); assert d['data']['record_count'] == 8345, f\\\"Expected 8345, got {d['data']['record_count']}\\\"\""

# Test 2: Dormant session filtering
_test "Dormant session: 1161 records filtered" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_dormant.json')); assert d['data']['record_count'] == 1161, f\\\"Expected 1161, got {d['data']['record_count']}\\\"\""

# Test 3: Models in main session
_test "Main session contains Sonnet and Haiku models" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_main.json')); models=set(d['data']['models_found']); assert 'claude-sonnet-4-6' in models and 'claude-haiku-4-5-20251001' in models\""

# Test 4: Models in dormant session (only Sonnet)
_test "Dormant session contains only Sonnet" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_dormant.json')); models=d['data']['models_found']; assert models == ['claude-sonnet-4-6'], f\\\"Expected ['claude-sonnet-4-6'], got {models}\\\"\""

# Test 5: JSON structure validation
_test "JSON output has correct structure" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_main.json')); assert d['type']=='jsonl-truth' and d['unit']=='5' and d['source']=='GROUND_TRUTH' and d['error'] is None\""

# Test 6: Records have sessionId field
_test "All records have correct sessionId" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_main.json')); recs=[r for r in d['data']['records'][:100]]; assert all(r.get('sessionId')=='$SESSION_MAIN' for r in recs)\""

# Test 7: File not found error
_test "File not found returns error" \
    "python3 '$SCRIPT' /nonexistent/file.jsonl '$SESSION_MAIN' 2>/dev/null | python3 -c \"import json,sys; d=json.load(sys.stdin); assert d['error'] is not None and d['source']=='ERROR'\""

# Test 8: Timestamp is ISO format
_test "Timestamp is ISO format" \
    "python3 -c \"import json; d=json.load(open('/tmp/qjsonl_main.json')); assert d['timestamp'].endswith('Z') and 'T' in d['timestamp']\""

echo ""
echo "Results: $pass_count / $test_count tests passed"

# Cleanup
rm -f /tmp/qjsonl_main.json /tmp/qjsonl_dormant.json

if [ $pass_count -eq $test_count ]; then
    exit 0
else
    exit 1
fi

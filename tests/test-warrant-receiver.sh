#!/usr/bin/env bash
# Phase 10 Unit 2: Test warrant receiver

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECEIVER="$HOME/.local/bin/qlaude-warrant-receiver"
WARRANT_DIR="$HOME/.aurora-agent/warrants"
TEST_PORT=19231

test_pass() {
  echo "✓ $*"
}

test_fail() {
  echo "✗ $*"
  exit 1
}

cleanup() {
  # Kill any running receiver
  pkill -f "qlaude-warrant-receiver.*$TEST_PORT" 2>/dev/null || true
  sleep 1
}

trap cleanup EXIT

echo "Phase 10 Unit 2: Warrant Receiver Tests"
echo "========================================"
echo ""

# Test 1: Health check endpoint
echo "Test 1: Health check endpoint"
cleanup
"$RECEIVER" --port $TEST_PORT --host 127.0.0.1 &
RECEIVER_PID=$!
sleep 2

health=$(curl -s http://127.0.0.1:$TEST_PORT/health 2>/dev/null)
if echo "$health" | grep -q '"status": "ok"'; then
  test_pass "Health endpoint working"
else
  test_fail "Health endpoint failed"
fi

# Test 2: Receive valid warrant
echo "Test 2: Receive valid warrant"
WARRANTY_JSON=$(cat <<'WARRANTY'
{
  "type": "loa_proposal",
  "warrant_id": "00000000-0000-0000-0000-000000000001",
  "parent_uuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "child_uuid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
  "task_description": "test task",
  "proposed_loa_cap": 4,
  "parent_loa_cap": 6,
  "expires_at": "2099-01-01T00:00:00Z"
}
WARRANTY

response=$(curl -s -X POST http://127.0.0.1:$TEST_PORT/warrant \
  -H "Content-Type: application/json" \
  -d "$WARRANTY_JSON" 2>/dev/null)

if echo "$response" | grep -q '"status": "RECEIVED"'; then
  test_pass "Warrant received successfully"
  if [[ -f "$WARRANT_DIR/00000000-0000-0000-0000-000000000001.json" ]]; then
    test_pass "Warranty file created"
  else
    test_fail "Warranty file not created"
  fi
else
  test_fail "Warrant reception failed: $response"
fi

# Test 3: Reject duplicate warranty
echo "Test 3: Reject duplicate warranty"
response=$(curl -s -X POST http://127.0.0.1:$TEST_PORT/warrant \
  -H "Content-Type: application/json" \
  -d "$WARRANTY_JSON" 2>/dev/null)

if echo "$response" | grep -q "409"; then
  test_pass "Duplicate warranty correctly rejected"
else
  test_fail "Should reject duplicate warranty"
fi

# Test 4: Reject invalid JSON
echo "Test 4: Reject invalid JSON"
response=$(curl -s -X POST http://127.0.0.1:$TEST_PORT/warrant \
  -H "Content-Type: application/json" \
  -d "{ invalid json }" 2>/dev/null)

if echo "$response" | grep -q '"error"'; then
  test_pass "Invalid JSON correctly rejected"
else
  test_fail "Should reject invalid JSON"
fi

# Test 5: Reject missing warranty_id
echo "Test 5: Reject missing warranty_id"
MISSING_ID=$(cat <<'WARRANTY'
{
  "type": "loa_proposal",
  "parent_uuid": "test"
}
WARRANTY

response=$(curl -s -X POST http://127.0.0.1:$TEST_PORT/warrant \
  -H "Content-Type: application/json" \
  -d "$MISSING_ID" 2>/dev/null)

if echo "$response" | grep -q "Missing warrant_id"; then
  test_pass "Missing warranty_id correctly rejected"
else
  test_fail "Should reject missing warranty_id"
fi

# Test 6: Return 404 for invalid endpoint
echo "Test 6: Return 404 for invalid endpoint"
response=$(curl -s -w "%{http_code}" http://127.0.0.1:$TEST_PORT/invalid 2>/dev/null)
http_code=$(echo "$response" | tail -c 4)

if [[ "$http_code" == "404" ]]; then
  test_pass "Invalid endpoint returns 404"
else
  test_fail "Invalid endpoint should return 404, got $http_code"
fi

# Cleanup
cleanup

echo ""
echo "All warrant receiver tests passed! ✓"

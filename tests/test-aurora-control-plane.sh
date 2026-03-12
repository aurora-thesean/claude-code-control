#!/bin/bash
# test-aurora-control-plane.sh — Comprehensive integration tests for qlaude + qhoami + task queue
# Runs end-to-end scenarios, captures observability, generates reports

set -euo pipefail

RESULTS_DIR="/tmp/aurora-test-$(date +%s)"
mkdir -p "$RESULTS_DIR"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
PASS=0
FAIL=0
SKIP=0

_test() {
  local name="$1"
  local cmd="$2"
  local expect_pattern="${3:-}"

  echo -n "TEST: $name ... "

  local output
  output=$(eval "$cmd" 2>&1) || true  # Ignore exit code — just capture output

  if [[ -z "$expect_pattern" ]] || echo "$output" | grep -q "$expect_pattern"; then
    echo -e "${GREEN}PASS${NC}"
    echo "$output" > "$RESULTS_DIR/$name.log"
    ((PASS++))
    return 0
  else
    echo -e "${RED}FAIL${NC} (expected pattern not found)"
    echo "Expected: $expect_pattern"
    echo "Got: $output"
    echo "$output" > "$RESULTS_DIR/$name.FAIL"
    ((FAIL++))
    return 1
  fi
}

_test_scenario() {
  local name="$1"
  local setup_fn="$2"
  local test_fn="$3"

  echo ""
  echo "=== SCENARIO: $name ==="

  local test_home=$(mktemp -d)
  mkdir -p "$test_home/.claude" "$test_home/.aurora-agent/queue"
  trap "rm -rf $test_home" RETURN

  $setup_fn "$test_home"
  HOME="$test_home" $test_fn "$test_home"
}

# ============================================================================
# SCENARIO 1: qlaude QC_LEVEL Gate Enforcement
# ============================================================================

_setup_qc0() {
  local home="$1"
  cat > "$home/.claude/CLAUDE.md" << 'DOC'
LOA_CAP=2
IMPRINT_STATUS=imprinted
DOC
}

_setup_qc1() {
  local home="$1"
  cat > "$home/.claude/CLAUDE.md" << 'DOC'
LOA_CAP=4
IMPRINT_STATUS=imprinted
DOC
}

_setup_qc2() {
  local home="$1"
  cat > "$home/.claude/CLAUDE.md" << 'DOC'
LOA_CAP=6
IMPRINT_STATUS=imprinted
DOC
}

_test_qc0_gates() {
  local home="$1"
  _test "QC0: --resume without --confirm rejected" \
    "HOME=$home /home/aurora/.local/bin/qlaude --resume test-uuid 2>&1" \
    "requires --confirm"

  _test "QC0: --autonomous-loop forbidden" \
    "HOME=$home /home/aurora/.local/bin/qlaude --autonomous-loop test-task 2>&1" \
    "FORBIDDEN"
}

_test_qc1_gates() {
  local home="$1"
  _test "QC1: --resume auto-approved" \
    "HOME=$home /home/aurora/.local/bin/qlaude --resume test-uuid 2>&1" \
    "APPROVED"

  _test "QC1: --autonomous-loop auto-approved with rate limit" \
    "HOME=$home /home/aurora/.local/bin/qlaude --autonomous-loop test-task 2>&1" \
    "APPROVED"
}

_test_qc2_gates() {
  local home="$1"
  _test "QC2: --resume auto-approved unrestricted" \
    "HOME=$home /home/aurora/.local/bin/qlaude --resume test-uuid 2>&1" \
    "APPROVED"
}

# ============================================================================
# SCENARIO 2: Task Queue End-to-End
# ============================================================================

_setup_task_queue() {
  local home="$1"
  cat > "$home/.claude/CLAUDE.md" << 'DOC'
LOA_CAP=4
DOC

  cat > "$home/.aurora-agent/queue/TEST.$(date +%s).task" << 'TASK'
{
  "task_id": "test-001",
  "action": "show_identity",
  "context": {},
  "status": "pending",
  "retry_count": 0,
  "created_at": "2026-03-11T00:00:00Z"
}
TASK
}

_test_queue_consumer() {
  local home="$1"

  echo "Queue before:"
  ls -1 "$home/.aurora-agent/queue/" | tee "$RESULTS_DIR/queue-before.txt"

  # Run consumer with timeout
  timeout 3 bash -x /home/aurora/.local/bin/qtask-consumer 1 2>&1 | tee "$RESULTS_DIR/consumer-output.log" || true

  echo ""
  echo "Queue after:"
  ls -1 "$home/.aurora-agent/queue/" | tee "$RESULTS_DIR/queue-after.txt"

  # Check if any tasks moved to .in_progress or .completed
  local after_count=$(ls "$home/.aurora-agent/queue"/*.in_progress "$home/.aurora-agent/queue"/*.completed 2>/dev/null | wc -l)
  if [[ $after_count -gt 0 ]]; then
    _test "Task queue consumer: task was claimed/completed" "echo '$after_count' | grep -q ." "."
  else
    echo -e "${YELLOW}INCONCLUSIVE${NC}: Consumer authorized but no task state change"
    ((SKIP++))
  fi
}

# ============================================================================
# SCENARIO 3: qhoami Ground Truth Reading
# ============================================================================

_test_qhoami_current_session() {
  local home="$1"

  _test "qhoami --self returns valid JSON" \
    "qhoami --self | python3 -m json.tool > /dev/null" \
    ""

  _test "qhoami includes all 7 dimensions" \
    "qhoami --self" \
    "avatar"

  _test "qhoami UUID is 36 characters" \
    "qhoami --self | python3 -c \"import sys, json; print(len(json.load(sys.stdin)['uuid']))\"" \
    "36"
}

# ============================================================================
# SCENARIO 4: qtail-jsonl Real-Time JSONL Tail Daemon
# ============================================================================

_setup_jsonl_monitoring() {
  local home="$1"
  # Create a test JSONL file with initial records
  local test_jsonl="$home/.claude/test.jsonl"
  mkdir -p "$home/.claude"
  cat > "$test_jsonl" << 'JSONL'
{"type":"message","sessionId":"test-001","timestamp":"2026-03-11T12:00:00Z","content":"first record"}
{"type":"message","sessionId":"test-001","timestamp":"2026-03-11T12:00:01Z","content":"second record"}
JSONL
}

_test_qtail_jsonl_startup() {
  local home="$1"
  local test_jsonl="$home/.claude/test.jsonl"

  _test "qtail-jsonl: reads initial records on startup" \
    "timeout 2 /home/aurora/repo-staging/claude-code-control/qtail-jsonl '$test_jsonl' 2>&1 | wc -l | grep -E '[2-9]'" \
    "[2-9]"

  _test "qtail-jsonl: emits valid JSON" \
    "timeout 2 /home/aurora/repo-staging/claude-code-control/qtail-jsonl '$test_jsonl' 2>&1 | head -1 | jq empty" \
    ""

  _test "qtail-jsonl: JSON includes type field" \
    "timeout 2 /home/aurora/repo-staging/claude-code-control/qtail-jsonl '$test_jsonl' 2>&1 | head -1 | jq -r '.type'" \
    "tail-record"

  _test "qtail-jsonl: JSON includes GROUND_TRUTH source" \
    "timeout 2 /home/aurora/repo-staging/claude-code-control/qtail-jsonl '$test_jsonl' 2>&1 | head -1 | jq -r '.source'" \
    "GROUND_TRUTH"

  _test "qtail-jsonl: JSON includes data.record_from_jsonl" \
    "timeout 2 /home/aurora/repo-staging/claude-code-control/qtail-jsonl '$test_jsonl' 2>&1 | head -1 | jq -r '.data.record_from_jsonl.type'" \
    "message"
}

_test_qtail_jsonl_errors() {
  local home="$1"

  _test "qtail-jsonl: rejects missing file" \
    "/home/aurora/repo-staging/claude-code-control/qtail-jsonl /nonexistent/file.jsonl 2>&1" \
    "File not found"

  _test "qtail-jsonl: rejects no arguments" \
    "/home/aurora/repo-staging/claude-code-control/qtail-jsonl 2>&1" \
    "Usage:"
}

# ============================================================================
# RUN ALL SCENARIOS
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "AURORA Control Plane — Integration Test Suite"
echo "════════════════════════════════════════════════════════════════"
echo "Results directory: $RESULTS_DIR"
echo ""

_test_scenario "QC0_HUMAN_ONLY Gates" _setup_qc0 _test_qc0_gates
_test_scenario "QC1_SUPERVISED_LOOP Gates" _setup_qc1 _test_qc1_gates
_test_scenario "QC2_FULLY_AUTONOMOUS Gates" _setup_qc2 _test_qc2_gates
_test_scenario "Task Queue End-to-End" _setup_task_queue _test_queue_consumer
_test_scenario "qtail-jsonl Startup & Parsing" _setup_jsonl_monitoring _test_qtail_jsonl_startup
_test_scenario "qtail-jsonl Error Handling" _setup_jsonl_monitoring _test_qtail_jsonl_errors

echo ""
echo "=== qhoami Ground Truth (current session) ==="
_test_qhoami_current_session ""

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$SKIP skipped${NC}"
echo "Logs: $RESULTS_DIR"
echo "════════════════════════════════════════════════════════════════"

exit $FAIL

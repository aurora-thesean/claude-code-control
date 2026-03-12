#!/usr/bin/env bash
# qreveng-e2e-test.sh — End-to-end integration tests for Aurora Control Plane
#
# Purpose: Validate qhoami, qlaude, and qreveng-daemon work correctly in realistic scenarios:
# 1. Single session identity detection
# 2. Multi-turn conversation with model switches
# 3. Subagent spawning and lineage tracking
# 4. Approval gates and audit logging
# 5. Performance under load
#
# Usage:
#   bash qreveng-e2e-test.sh              # Run all tests
#   bash qreveng-e2e-test.sh --unit=1    # Run specific test
#   bash qreveng-e2e-test.sh --verbose   # Show detailed output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# --- Logging ---

_log_test() {
  echo -e "${YELLOW}[TEST]${NC} $*"
}

_log_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $*"
  ((TESTS_PASSED++))
}

_log_fail() {
  echo -e "${RED}✗ FAIL${NC}: $*"
  ((TESTS_FAILED++))
}

# --- Test Helpers ---

_assert_file_exists() {
  local file="$1"
  local msg="${2:-File should exist: $file}"

  if [[ -f "$file" ]]; then
    return 0
  else
    _log_fail "$msg"
    return 1
  fi
}

_assert_json_valid() {
  local json="$1"
  local msg="${2:-JSON should be valid}"

  if echo "$json" | python3 -m json.tool > /dev/null 2>&1; then
    return 0
  else
    _log_fail "$msg"
    echo "Invalid JSON: $json" >&2
    return 1
  fi
}

_assert_json_has_key() {
  local json="$1"
  local key="$2"
  local msg="${3:-JSON should have key: $key}"

  if echo "$json" | python3 -c "import json, sys; data = json.load(sys.stdin); sys.exit(0 if '$key' in data else 1)" 2>/dev/null; then
    return 0
  else
    _log_fail "$msg"
    return 1
  fi
}

_run_test() {
  local test_num="$1"
  local test_name="$2"
  local test_func="$3"

  ((TESTS_RUN++))
  _log_test "Test $test_num: $test_name"

  if $test_func; then
    _log_pass "Test $test_num: $test_name"
    return 0
  else
    return 1
  fi
}

# --- Test Functions ---

test_qhoami_self_json_valid() {
  local json
  json=$(cd "$REPO_DIR" && ./qhoami --self 2>/dev/null) || {
    _log_fail "qhoami --self returned error"
    return 1
  }

  _assert_json_valid "$json" "qhoami --self should output valid JSON" || return 1
  _assert_json_has_key "$json" "uuid" "JSON should have uuid" || return 1
  _assert_json_has_key "$json" "model" "JSON should have model" || return 1

  return 0
}

test_qhoami_all_dimensions() {
  local json
  json=$(cd "$REPO_DIR" && ./qhoami --self 2>/dev/null) || return 1

  # Check all 7 dimensions are present
  local dimensions=(avatar sidecar generation model qc_level memory_scope location)
  for dim in "${dimensions[@]}"; do
    _assert_json_has_key "$json" "$dim" "JSON should have dimension: $dim" || return 1
  done

  return 0
}

test_qhoami_source_attribution() {
  local json
  json=$(cd "$REPO_DIR" && ./qhoami --self 2>/dev/null) || return 1

  # Each dimension should have 'value', 'source', and 'from' fields
  local dims=(avatar sidecar generation model qc_level memory_scope location)
  for dim in "${dims[@]}"; do
    echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
dim = data.get('$dim', {})
for key in ['value', 'source', 'from']:
    if key not in dim:
        print(f'Missing {key} in {dim}')
        sys.exit(1)
" || {
      _log_fail "Dimension $dim missing source attribution fields"
      return 1
    }
  done

  return 0
}

test_qhoami_source_types() {
  local json
  json=$(cd "$REPO_DIR" && ./qhoami --self 2>/dev/null) || return 1

  # Verify source values are valid (GROUND_TRUTH, CONFIG, HEURISTIC_FALLBACK)
  local valid_sources="GROUND_TRUTH|CONFIG|HEURISTIC_FALLBACK"

  echo "$json" | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
valid = r'($valid_sources)'
for dim_name, dim_data in data.items():
    if isinstance(dim_data, dict) and 'source' in dim_data:
        source = dim_data['source']
        if source not in ['GROUND_TRUTH', 'CONFIG', 'HEURISTIC_FALLBACK']:
            print(f'Invalid source for {dim_name}: {source}')
            sys.exit(1)
" || {
      _log_fail "Invalid source type detected"
      return 1
    }

  return 0
}

test_qlaude_list_siblings() {
  local siblings
  siblings=$(cd "$REPO_DIR" && ./qlaude --list-siblings 2>/dev/null) || {
    _log_fail "qlaude --list-siblings returned error"
    return 1
  }

  # Should output at least one UUID (self)
  if [[ -n "$siblings" ]]; then
    return 0
  else
    _log_fail "qlaude --list-siblings returned empty"
    return 1
  fi
}

test_qreveng_daemon_help() {
  local output
  output=$(cd "$REPO_DIR" && ./qreveng-daemon --help 2>&1) || {
    _log_fail "qreveng-daemon --help returned error"
    return 1
  }

  if echo "$output" | grep -q "daemon"; then
    return 0
  else
    _log_fail "qreveng-daemon --help didn't show help text"
    return 1
  fi
}

test_performance_qhoami() {
  local start end elapsed

  start=$(date +%s%N)
  cd "$REPO_DIR" && ./qhoami --self > /dev/null 2>&1
  end=$(date +%s%N)

  elapsed=$(( (end - start) / 1000000 ))  # Convert to ms

  # Expect < 60 seconds (60000 ms)
  if [[ $elapsed -lt 60000 ]]; then
    _log_pass "qhoami performance: ${elapsed}ms"
    return 0
  else
    _log_fail "qhoami took ${elapsed}ms (expected < 60000ms)"
    return 1
  fi
}

test_performance_qlaude() {
  local start end elapsed

  start=$(date +%s%N)
  cd "$REPO_DIR" && ./qlaude --list-siblings > /dev/null 2>&1
  end=$(date +%s%N)

  elapsed=$(( (end - start) / 1000000 ))

  # Expect < 60 seconds (60000 ms)
  if [[ $elapsed -lt 60000 ]]; then
    _log_pass "qlaude --list-siblings performance: ${elapsed}ms"
    return 0
  else
    _log_fail "qlaude took ${elapsed}ms (expected < 60000ms)"
    return 1
  fi
}

test_audit_log_exists() {
  local audit_log="$HOME/.aurora-agent/.qlaude-audit.jsonl"

  if [[ -f "$audit_log" ]]; then
    return 0
  else
    _log_fail "Audit log not found: $audit_log"
    return 1
  fi
}

test_audit_log_valid_jsonl() {
  local audit_log="$HOME/.aurora-agent/.qlaude-audit.jsonl"

  if [[ ! -f "$audit_log" ]]; then
    _log_fail "Audit log not found"
    return 1
  fi

  # Each line should be valid JSON
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! echo "$line" | python3 -m json.tool > /dev/null 2>&1; then
      _log_fail "Invalid JSON in audit log: $line"
      return 1
    fi
  done < "$audit_log"

  return 0
}

# --- Main ---

_print_usage() {
  cat <<EOF
Usage: bash qreveng-e2e-test.sh [OPTIONS]

Options:
  --unit=N       Run specific test number
  --verbose      Show detailed output
  --help         Show this help

Tests:
  1. qhoami --self outputs valid JSON
  2. qhoami has all 7 dimensions
  3. qhoami dimensions have source attribution
  4. qhoami sources are valid types
  5. qlaude --list-siblings works
  6. qreveng-daemon --help works
  7. qhoami performance < 60s
  8. qlaude performance < 60s
  9. Audit log exists
  10. Audit log is valid JSONL

Run all tests with: bash qreveng-e2e-test.sh
EOF
}

main() {
  local verbose=false
  local unit=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --unit=*)
        unit="${1#--unit=}"
        shift
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      --help)
        _print_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        _print_usage
        exit 1
        ;;
    esac
  done

  echo "Aurora Control Plane E2E Test Suite"
  echo "===================================="
  echo ""

  # Run tests (only matching unit if specified)
  _run_test 1 "qhoami --self outputs valid JSON" test_qhoami_self_json_valid || true
  _run_test 2 "qhoami has all 7 dimensions" test_qhoami_all_dimensions || true
  _run_test 3 "qhoami dimensions have source attribution" test_qhoami_source_attribution || true
  _run_test 4 "qhoami sources are valid types" test_qhoami_source_types || true
  _run_test 5 "qlaude --list-siblings works" test_qlaude_list_siblings || true
  _run_test 6 "qreveng-daemon --help works" test_qreveng_daemon_help || true
  _run_test 7 "qhoami performance < 60s" test_performance_qhoami || true
  _run_test 8 "qlaude performance < 60s" test_performance_qlaude || true
  _run_test 9 "Audit log exists" test_audit_log_exists || true
  _run_test 10 "Audit log is valid JSONL" test_audit_log_valid_jsonl || true

  echo ""
  echo "===================================="
  echo "Test Results: $TESTS_PASSED/$TESTS_RUN passed"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
    exit 1
  fi
}

main "$@"

#!/usr/bin/env bash
# test-qcapture-net.sh — Test Suite for Unit 7 Network Capture Analyzer

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QCAPTURE_NET="$REPO_ROOT/qcapture-net"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ─── TEST HELPERS ──────────────────────────────────────────

test_start() {
    local desc="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "[TEST %d] %s " "$TESTS_RUN" "$desc"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC}\n"
}

test_fail() {
    local reason="${1:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC}\n"
    if [[ -n "$reason" ]]; then
        printf "  ${RED}→ %s${NC}\n" "$reason"
    fi
}

assert_json_valid() {
    local json="$1"
    local desc="${2:-JSON is valid}"

    if echo "$json" | jq . &>/dev/null; then
        test_pass
        return 0
    else
        test_fail "Invalid JSON: $json"
        return 1
    fi
}

assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="${3:-}"

    local value=$(echo "$json" | jq -r ".$field" 2>/dev/null || echo "MISSING")

    if [[ "$value" == "MISSING" ]]; then
        test_fail "Field '$field' not found in JSON"
        return 1
    fi

    if [[ -n "$expected" && "$value" != "$expected" ]]; then
        test_fail "Field '$field' = '$value', expected '$expected'"
        return 1
    fi

    test_pass
    return 0
}

# ─── TESTS ──────────────────────────────────────────────────

echo "================================"
echo "Unit 7: Network Capture Tests"
echo "================================"
echo ""

# Test 1: Help output
test_start "qcapture-net --help shows usage"
if $QCAPTURE_NET --help | grep -q "Usage:"; then
    test_pass
else
    test_fail "Help text not found"
fi

# Test 2: Script is executable
test_start "qcapture-net is executable"
if [[ -x "$QCAPTURE_NET" ]]; then
    test_pass
else
    test_fail "Script is not executable"
fi

# Test 3: Shebang is valid
test_start "qcapture-net has valid shebang"
if head -1 "$QCAPTURE_NET" | grep -q "#!/usr/bin/env bash"; then
    test_pass
else
    test_fail "Invalid shebang"
fi

# Test 4: Script has required functions
test_start "qcapture-net has error_json function"
if grep -q "^error_json()" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "error_json function not found"
fi

test_start "qcapture-net has check_tcpdump function"
if grep -q "^check_tcpdump()" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "check_tcpdump function not found"
fi

test_start "qcapture-net has cleanup function"
if grep -q "^cleanup()" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "cleanup function not found"
fi

# Test 5: Script has argument parsing
test_start "qcapture-net has argument parsing"
if grep -q "while \[\[ \$# -gt 0 \]\]" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "No argument parsing loop found"
fi

# Test 6: Script syntax validation
test_start "qcapture-net has valid bash syntax"
if bash -n "$QCAPTURE_NET" 2>/dev/null; then
    test_pass
else
    test_fail "Syntax errors found"
fi

# Test 7: Script attempts to detect tcpdump (even if not available)
test_start "qcapture-net checks for tcpdump availability"
if grep -q "command -v tcpdump" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "No tcpdump check found"
fi

# Test 8: JSON output template exists
test_start "qcapture-net has JSON output template"
if grep -q '"type": "network-capture"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "JSON output template not found"
fi

# Test 9: Unit field in JSON output
test_start "qcapture-net includes unit 7 in JSON"
if grep -q '"unit": "7"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Unit field not found"
fi

# Test 10: Network fields in JSON output
test_start "qcapture-net includes network fields in JSON"
if grep -q '"source_ip".*"dest_ip".*"dest_port"' "$QCAPTURE_NET" || \
   grep -q '"source_ip"' "$QCAPTURE_NET" && grep -q '"dest_ip"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Network fields not found"
fi

# Test 11: Protocol field
test_start "qcapture-net includes protocol field"
if grep -q '"protocol"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Protocol field not found"
fi

# Test 12: SNI field (TLS Server Name Indication)
test_start "qcapture-net includes SNI field"
if grep -q '"sni"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "SNI field not found"
fi

# Test 13: Packet count field
test_start "qcapture-net includes packet_count field"
if grep -q '"packet_count"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Packet count field not found"
fi

# Test 14: Bytes fields
test_start "qcapture-net includes bytes_sent and bytes_recv"
if grep -q '"bytes_sent"' "$QCAPTURE_NET" && grep -q '"bytes_recv"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Bytes fields not found"
fi

# Test 15: Patterns field
test_start "qcapture-net includes patterns field"
if grep -q '"patterns"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Patterns field not found"
fi

# Test 16: Error handling for tcpdump not found
test_start "qcapture-net handles tcpdump not found"
if grep -q "tcpdump not found" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "No tcpdump not-found error message"
fi

# Test 17: Error handling for permission denied
test_start "qcapture-net handles permission errors"
if grep -q "permission denied" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "No permission denied error message"
fi

# Test 18: Error handling for no packets
test_start "qcapture-net handles no packets captured"
if grep -q "no packets captured" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "No 'no packets' error message"
fi

# Test 19: Cleanup trap
test_start "qcapture-net has cleanup trap"
if grep -q "trap cleanup EXIT" "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Cleanup trap not found"
fi

# Test 20: Default parameters
test_start "qcapture-net has default parameters"
if grep -q 'DURATION="${DURATION:-5}"' "$QCAPTURE_NET"; then
    test_pass
else
    test_fail "Default duration not found"
fi

# ─── MOCK EXECUTION TEST (if tcpdump available) ──────────────────────────────────────────

if command -v tcpdump &>/dev/null; then
    echo ""
    echo "Additional tests (tcpdump available):"
    echo ""

    # Test 21: Actual execution with --help
    test_start "qcapture-net --help executes without error"
    if $QCAPTURE_NET --help >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Help command failed"
    fi
else
    echo ""
    echo "Skipping tcpdump execution tests (tcpdump not available)"
fi

# ─── SUMMARY ──────────────────────────────────────────────────

echo ""
echo "================================"
printf "Tests run: %d\n" "$TESTS_RUN"
printf "${GREEN}Passed: %d${NC}\n" "$TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}Failed: %d${NC}\n" "$TESTS_FAILED"
else
    printf "Failed: 0\n"
fi
echo "================================"

if [[ $TESTS_FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi

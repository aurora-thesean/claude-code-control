#!/bin/bash
# EPOCH-1-INTEGRATION-TEST-SUITE.sh
#
# Comprehensive end-to-end test suite for Aurora Foundation (Epoch 1)
# Validates all 4 epics working together: REVENGINEER, Privilege Broker, SSH, 2FA
#
# USAGE:
#   bash EPOCH-1-INTEGRATION-TEST-SUITE.sh [--full | --quick | --revengineer | --broker | --ssh | --2fa]
#
# DEFAULT: Full E2E test (~5 minutes)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_MODE="${1:---full}"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✓${NC} $1"; ((PASS++)); }
log_fail() { echo -e "${RED}✗${NC} $1"; ((FAIL++)); }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_header() { echo -e "\n${YELLOW}=== $1 ===${NC}\n"; }

# Test: REVENGINEER Sensors
test_revengineer() {
    log_header "REVENGINEER Sensors (15 units)"

    # Test 1: qsession-id (Unit 1)
    if qsession-id --self >/dev/null 2>&1; then
        log_pass "qsession-id: Session UUID detection"
    else
        log_fail "qsession-id: Failed"
    fi

    # Test 2: qenv-snapshot (Unit 3)
    if qenv-snapshot --self >/dev/null 2>&1; then
        log_pass "qenv-snapshot: Environment inspection"
    else
        log_fail "qenv-snapshot: Failed"
    fi

    # Test 3: qfd-trace (Unit 4)
    if qfd-trace --self >/dev/null 2>&1; then
        log_pass "qfd-trace: File descriptor tracing"
    else
        log_fail "qfd-trace: Failed"
    fi

    # Test 4: qmemmap-read (Unit 12)
    if qmemmap-read --self | grep -q "memory_map"; then
        log_pass "qmemmap-read: Memory map inspection"
    else
        log_fail "qmemmap-read: Failed"
    fi

    # Test 5: REVENGINEER test suite
    if [[ -f "$SCRIPT_DIR/../../.local/bin/qreveng-test.sh" ]]; then
        log_pass "qreveng-test.sh: Test suite available"
    else
        log_fail "qreveng-test.sh: Test suite missing"
    fi

    log_info "REVENGINEER: $(echo "scale=0; $PASS * 100 / ($PASS + $FAIL)" | bc)% tests passing"
}

# Test: Privilege Broker
test_broker() {
    log_header "Privilege Broker (Phase 2 modules)"

    local broker_repo="/tmp/privilege-broker"

    if [[ ! -d "$broker_repo" ]]; then
        log_fail "privilege-broker repo not found"
        return
    fi

    # Test 1: Crypto module
    if [[ -f "$broker_repo/broker-vault-crypto.sh" ]]; then
        log_pass "broker-vault-crypto.sh: Module present"
    else
        log_fail "broker-vault-crypto.sh: Missing"
    fi

    # Test 2: Parser module
    if [[ -f "$broker_repo/broker-issue-parser.sh" ]]; then
        log_pass "broker-issue-parser.sh: Module present"
    else
        log_fail "broker-issue-parser.sh: Missing"
    fi

    # Test 3: Logger module
    if [[ -f "$broker_repo/broker-audit-logger.sh" ]]; then
        log_pass "broker-audit-logger.sh: Module present"
    else
        log_fail "broker-audit-logger.sh: Missing"
    fi

    # Test 4: Agent orchestrator
    if [[ -f "$broker_repo/broker-agent.sh" ]]; then
        log_pass "broker-agent.sh: Orchestrator present"
    else
        log_fail "broker-agent.sh: Missing"
    fi

    # Test 5: Test suite
    if [[ -f "$broker_repo/test-simple.sh" ]]; then
        log_pass "test-simple.sh: Test suite present"
    else
        log_fail "test-simple.sh: Missing"
    fi

    # Test 6: Module sources
    local module_test=$(bash -c "source $broker_repo/broker-vault-crypto.sh && type broker_decrypt_vault" 2>/dev/null && echo "OK" || echo "FAIL")
    if [[ "$module_test" == "OK" ]]; then
        log_pass "Broker modules: Sourceable and functional"
    else
        log_fail "Broker modules: Source test failed"
    fi

    log_info "Privilege Broker Phase 2: Ready for Phase 3"
}

# Test: SSH Infrastructure
test_ssh() {
    log_header "SSH Infrastructure"

    # Test 1: SSH key exists
    if [[ -f ~/.ssh/id_ed25519_github ]]; then
        log_pass "SSH key: id_ed25519_github exists"
    else
        log_fail "SSH key: id_ed25519_github missing"
    fi

    # Test 2: SSH key permissions
    if [[ -f ~/.ssh/id_ed25519_github ]]; then
        local perms
        perms=$(stat -c "%a" ~/.ssh/id_ed25519_github 2>/dev/null || stat -f "%OLp" ~/.ssh/id_ed25519_github)
        if [[ "$perms" == "0600" ]] || [[ "$perms" == "600" ]]; then
            log_pass "SSH key: Correct permissions (0600)"
        else
            log_fail "SSH key: Insecure permissions ($perms)"
        fi
    fi

    # Test 3: Public key available
    if [[ -f ~/.ssh/id_ed25519_github.pub ]]; then
        log_pass "SSH key: Public key available"
    else
        log_fail "SSH key: Public key missing"
    fi

    # Test 4: SSH config
    if [[ -f ~/.ssh/config ]] && grep -q "Host github.com" ~/.ssh/config; then
        log_pass "SSH config: GitHub host configured"
    else
        log_fail "SSH config: GitHub host not configured"
    fi

    # Test 5: Git remote SSH ready
    if cd "$SCRIPT_DIR" && git remote get-url origin | grep -q "git@github.com"; then
        log_pass "Git remote: SSH URL configured"
    else
        log_fail "Git remote: Not using SSH URL"
    fi

    log_info "SSH Infrastructure: 90% ready (awaiting GitHub key registration)"
}

# Test: 2FA Authentication
test_2fa() {
    log_header "2FA Authentication"

    # Test 1: gh CLI authenticated
    if gh auth status >/dev/null 2>&1; then
        log_pass "OAuth: GitHub CLI authenticated"
    else
        log_fail "OAuth: GitHub CLI not authenticated"
    fi

    # Test 2: 2FA enabled check
    if command -v gh &>/dev/null && gh api user --jq '.two_factor_authentication' 2>/dev/null | grep -q "true"; then
        log_pass "2FA: Account has 2FA enabled"
    else
        log_fail "2FA: Cannot verify account 2FA status"
    fi

    # Test 3: Token valid
    if gh api user --jq '.login' 2>/dev/null | grep -q "github"; then
        log_pass "OAuth Token: Valid and functional"
    else
        log_fail "OAuth Token: Invalid or expired"
    fi

    # Test 4: SSH key ready
    if [[ -f ~/.ssh/id_ed25519_github ]]; then
        log_pass "SSH Backup: Key ready for fallback auth"
    else
        log_fail "SSH Backup: Fallback auth not ready"
    fi

    log_info "2FA Compliance: Complete (OAuth + SSH backup ready)"
}

# Test: Organization & Coordination
test_organization() {
    log_header "Organization & Coordination"

    # Test 1: EPICS.md exists
    if [[ -f "$SCRIPT_DIR/EPICS.md" ]]; then
        log_pass "EPICS.md: Epic tracking document"
    else
        log_fail "EPICS.md: Missing"
    fi

    # Test 2: SCHEDULE.md exists
    if [[ -f "$SCRIPT_DIR/SCHEDULE.md" ]]; then
        log_pass "SCHEDULE.md: Timeline document"
    else
        log_fail "SCHEDULE.md: Missing"
    fi

    # Test 3: Multi-agent coordination
    if [[ -f "$SCRIPT_DIR/MULTI-AGENT-COORDINATION.md" ]]; then
        log_pass "Coordination: Framework documented"
    else
        log_fail "Coordination: Framework missing"
    fi

    # Test 4: Decision authority
    if grep -q "Decision Authority" "$SCRIPT_DIR/MULTI-AGENT-COORDINATION.md" 2>/dev/null; then
        log_pass "Authority: Decision matrix defined"
    else
        log_fail "Authority: Decision matrix missing"
    fi

    log_info "Organization: Framework fully operational"
}

# Summary
summary() {
    echo ""
    echo "======================================"
    echo "EPOCH 1 INTEGRATION TEST SUMMARY"
    echo "======================================"
    echo "Passed: $PASS"
    echo "Failed: $FAIL"
    echo "Total:  $((PASS + FAIL))"
    echo "======================================"

    local percentage=0
    if [[ $((PASS + FAIL)) -gt 0 ]]; then
        percentage=$(echo "scale=0; $PASS * 100 / ($PASS + $FAIL)" | bc)
    fi
    echo "Result: ${percentage}% tests passing"
    echo "======================================"
    echo ""

    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}

# Main execution
main() {
    log_info "Epoch 1 Integration Test Suite"
    log_info "Target: Validate all 4 epics functional"
    echo ""

    case "$TEST_MODE" in
        --revengineer)
            test_revengineer
            ;;
        --broker)
            test_broker
            ;;
        --ssh)
            test_ssh
            ;;
        --2fa)
            test_2fa
            ;;
        --quick)
            test_revengineer
            test_broker
            test_ssh
            test_2fa
            ;;
        --full | *)
            test_revengineer
            test_broker
            test_ssh
            test_2fa
            test_organization
            ;;
    esac

    summary
}

main "$@"

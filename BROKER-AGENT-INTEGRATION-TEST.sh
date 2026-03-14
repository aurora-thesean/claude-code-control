#!/bin/bash
# BROKER-AGENT-INTEGRATION-TEST.sh
#
# Full end-to-end integration test of Broker Agent workflow
# This test simulates the complete flow without requiring real password or GitHub approval
#
# USAGE:
#   bash BROKER-AGENT-INTEGRATION-TEST.sh [--real | --mock]
#
# --mock: Run with simulated vault and GitHub issue (for testing)
# --real: Run with actual vault and real GitHub issue (requires human approval)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROKER_REPO="/tmp/privilege-broker"
TEST_MODE="${1:---mock}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Phase 1: Vault Setup
phase_1_vault() {
    log_info "=== Phase 1: Vault Setup ==="

    if [[ "$TEST_MODE" == "--real" ]]; then
        log_info "Running aurora-password-setup (interactive)"
        log_warn "You will be prompted for sudo password (hidden input)"
        ~/.local/bin/aurora-password-setup
        VAULT_FILE=~/.aurora-agent/sudo.vault
    else
        log_info "Creating mock vault (test mode)"
        # Create test vault with known decryption key
        mkdir -p ~/.aurora-agent

        python3 <<'PYVAULT'
import base64, json, os, datetime
from cryptography.fernet import Fernet

# Generate a test key
fernet_key = Fernet.generate_key()
key_hex = base64.urlsafe_b64decode(fernet_key).hex()

# Encrypt test password
cipher = Fernet(fernet_key)
test_password = "test-sudo-password"  # Mock password
encrypted_bytes = cipher.encrypt(test_password.encode())
encrypted_b64 = base64.b64encode(encrypted_bytes).decode()

# Create vault
vault = {
    "type": "aurora_privilege_vault_v1",
    "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "created_by": "broker-integration-test",
    "encryption_algorithm": "fernet",
    "encryption_key_ephemeral": True,
    "vault_status": "initialized",
    "encrypted_password": encrypted_b64,
    "notes": "Test vault for integration testing"
}

vault_path = os.path.expanduser("~/.aurora-agent/sudo.vault.test")
with open(vault_path, 'w') as f:
    json.dump(vault, f, indent=2)
os.chmod(vault_path, 0o600)

# Save ephemeral key for test
with open("/tmp/broker-test-key.hex", "w") as f:
    f.write(key_hex)

print(f"Test vault: {vault_path}")
print(f"Permissions: {oct(os.stat(vault_path).st_mode)[-3:]}")
print(f"Test key saved to: /tmp/broker-test-key.hex")
PYVAULT
        VAULT_FILE=~/.aurora-agent/sudo.vault.test
    fi

    # Verify vault
    if [[ -f "$VAULT_FILE" ]] && [[ $(stat -c "%a" "$VAULT_FILE") == "600" ]]; then
        log_info "✓ Vault created with correct permissions (0600)"
        return 0
    else
        log_error "Vault creation failed or permissions incorrect"
        return 1
    fi
}

# Phase 2: GitHub Issue Simulation
phase_2_github_issue() {
    log_info "=== Phase 2: GitHub Issue ==="

    if [[ "$TEST_MODE" == "--real" ]]; then
        log_info "Creating real GitHub issue in privilege-broker"
        ISSUE_URL=$(gh issue create \
            --repo aurora-thesean/privilege-broker \
            --title "Request: sudo gcc -shared -fPIC -o ~/.local/lib/libqcapture.so src/libqcapture.c -lpthread -ldl" \
            --body "Unit 6: Build LD_PRELOAD file I/O hook for REVENGINEER sensor layer" \
            --json url --jq '.url')

        log_warn "GitHub issue created: $ISSUE_URL"
        log_warn "Waiting for approval from DarienSirius..."
        echo "Issue URL: $ISSUE_URL"
    else
        log_info "Using mock GitHub issue (test mode)"
        # Create a mock issue response
        ISSUE_URL="https://github.com/aurora-thesean/privilege-broker/issues/999"
        ISSUE_NUM="999"

        # Simulate issue data in JSON
        cat > /tmp/mock-issue.json <<EOF
{
  "title": "Request: sudo gcc -shared -fPIC -o ~/.local/lib/libqcapture.so src/libqcapture.c -lpthread -ldl",
  "body": "Unit 6: Build LD_PRELOAD file I/O hook",
  "number": $ISSUE_NUM,
  "comments": [
    {
      "author": {"login": "DarienSirius"},
      "body": "✓ Approved: necessary for REVENGINEER Unit 6",
      "createdAt": "2026-03-14T20:30:00Z"
    }
  ]
}
EOF
        log_info "Mock issue: $ISSUE_URL (simulated approval included)"
    fi

    echo "$ISSUE_URL"
}

# Phase 3: Broker Agent Execution
phase_3_broker_execution() {
    log_info "=== Phase 3: Broker Agent Execution ==="

    local issue_url="$1"
    local vault_file="$2"

    # Get ephemeral key
    if [[ "$TEST_MODE" == "--mock" ]]; then
        EPHEMERAL_KEY=$(cat /tmp/broker-test-key.hex)
    else
        log_info "Generating ephemeral decryption key..."
        EPHEMERAL_KEY=$(python3 -c "import os; print(os.urandom(32).hex())")
    fi

    log_info "Ephemeral key generated (not stored)"

    # We can't actually execute broker-agent.sh without sudo password
    # But we can simulate the workflow steps
    log_info "Would execute:"
    log_info "  AURORA_BROKER_EPHEMERAL_KEY='$EPHEMERAL_KEY' \\"
    log_info "  AURORA_BROKER_VAULT_PATH='$vault_file' \\"
    log_info "  broker-agent.sh '$issue_url'"

    log_info ""
    log_info "Expected flow:"
    log_info "  1. Parse issue → extract command from title"
    log_info "  2. Verify approval comment exists"
    log_info "  3. Decrypt password from vault using ephemeral key"
    log_info "  4. Execute: echo \$PASSWORD | sudo gcc ..."
    log_info "  5. Log result to audit trail"
    log_info "  6. Post GitHub comment with execution result"
    log_info ""

    # Test the decryption part independently
    if [[ "$TEST_MODE" == "--mock" ]]; then
        log_info "Testing vault decryption..."
        source "$BROKER_REPO/broker-vault-crypto.sh"

        if DECRYPTED=$(broker_decrypt_vault "$EPHEMERAL_KEY" "$vault_file"); then
            log_info "✓ Vault decryption successful"
            log_info "  Password: (hidden for security)"
        else
            log_error "Vault decryption failed"
            return 1
        fi
    fi

    # Simulate command extraction from issue
    COMMAND="gcc -shared -fPIC -o ~/.local/lib/libqcapture.so src/libqcapture.c -lpthread -ldl"
    log_info "Extracted command: $COMMAND"

    return 0
}

# Phase 4: Audit Trail
phase_4_audit_trail() {
    log_info "=== Phase 4: Audit Trail ==="

    # Show audit log entries
    if [[ -f ~/.aurora-agent/privilege-log.jsonl ]]; then
        log_info "Recent audit entries:"
        tail -2 ~/.aurora-agent/privilege-log.jsonl | jq . 2>/dev/null || tail -2 ~/.aurora-agent/privilege-log.jsonl
    else
        log_warn "No audit trail yet (execution not completed)"
    fi
}

# Phase 5: Verification
phase_5_verify() {
    log_info "=== Phase 5: Verification ==="

    if [[ -f ~/.local/lib/libqcapture.so ]]; then
        log_info "✓ libqcapture.so exists"
        file ~/.local/lib/libqcapture.so
        ldd ~/.local/lib/libqcapture.so 2>/dev/null | head -3
    else
        log_warn "libqcapture.so not yet compiled (requires actual sudo execution)"
    fi
}

# Main execution
main() {
    log_info "Starting Broker Agent Integration Test (mode: $TEST_MODE)"
    echo ""

    # Phase 1: Vault
    if ! phase_1_vault; then
        log_error "Vault setup failed"
        return 1
    fi
    echo ""

    # Phase 2: GitHub Issue
    ISSUE_URL=$(phase_2_github_issue)
    VAULT_FILE=~/.aurora-agent/sudo.vault$([ "$TEST_MODE" = "--mock" ] && echo ".test" || echo "")
    echo ""

    # Phase 3: Broker Execution
    if ! phase_3_broker_execution "$ISSUE_URL" "$VAULT_FILE"; then
        log_error "Broker execution simulation failed"
        return 1
    fi
    echo ""

    # Phase 4: Audit Trail
    phase_4_audit_trail
    echo ""

    # Phase 5: Verify
    phase_5_verify
    echo ""

    log_info "Integration test complete"

    if [[ "$TEST_MODE" == "--mock" ]]; then
        # Cleanup test vault
        rm -f ~/.aurora-agent/sudo.vault.test /tmp/broker-test-key.hex /tmp/mock-issue.json
        log_info "Test files cleaned up"
    fi
}

main "$@"

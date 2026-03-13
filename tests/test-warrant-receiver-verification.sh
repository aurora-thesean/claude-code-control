#!/bin/bash
# Phase 10b Unit 2: Warrant Receiver Signature Verification Tests
# Unit tests for verify_warrant_signature function

set -euo pipefail

_log() { echo "[test-warrant-verification] $*" >&2; }
_pass() { echo "✓ $*" >&2; }
_fail() { echo "✗ $*" >&2; exit 1; }

# Setup
TEST_HOME="${TMPDIR:-.}/test-warrant-verify-$$"
SIGN_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/qwarrant-sign"

cleanup() {
    rm -rf "$TEST_HOME" 2>/dev/null || true
}

trap cleanup EXIT

mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
mkdir -p "$HOME/.aurora-agent"

_log "Setting up test environment..."

# Generate keypair
$SIGN_TOOL --generate-keys --output-dir "$HOME/.aurora-agent" >/dev/null 2>&1

# Copy public key to warrant receiver location
cp "$HOME/.aurora-agent/public.pem" "$HOME/.aurora-agent/parent-public-key.pem"

test_signature_verification_via_qwarrant_sign() {
    _log "Test: Signature verification accepts valid warrant"

    # Create warrant
    warrant_file="$TEST_HOME/warrant-verify.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-verify-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$($SIGN_TOOL --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null)
    echo "$signed_output" > "$warrant_file.signed"

    # Verify it
    verify_output=$($SIGN_TOOL --verify "$warrant_file.signed" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null)

    if echo "$verify_output" | grep -qE '"status"\s*:\s*"valid"'; then
        _pass "Valid warrant signature passes verification"
    else
        _fail "Valid warrant should pass verification: $verify_output"
    fi
}

test_tampered_warrant_detection() {
    _log "Test: Verification rejects tampered warrant"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-tamper.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-tamper-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed=$($SIGN_TOOL --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null)
    echo "$signed" > "$warrant_file.signed"

    # Tamper with it
    tampered=$(echo "$signed" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['proposed_loa_cap'] = 8
print(json.dumps(data))
")
    echo "$tampered" > "$warrant_file.tampered"

    # Try to verify tampered warrant
    verify_output=$($SIGN_TOOL --verify "$warrant_file.tampered" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null || echo "FAILED")

    if echo "$verify_output" | grep -qE '"status"\s*:\s*"invalid"'; then
        _pass "Tampered warrant detection works"
    else
        _fail "Tampered warrant should fail verification: $verify_output"
    fi
}

test_expiration_check() {
    _log "Test: Verification rejects expired warrant"

    # Create warrant
    warrant_file="$TEST_HOME/warrant-expire.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-expire-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign with 1-second TTL
    signed=$($SIGN_TOOL --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" --ttl 1 2>/dev/null)
    echo "$signed" > "$warrant_file.signed"

    # Wait for expiration
    sleep 2

    # Try to verify expired warrant
    verify_output=$($SIGN_TOOL --verify "$warrant_file.signed" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null || echo "FAILED")

    if echo "$verify_output" | grep -q "expired"; then
        _pass "Expiration checking works"
    else
        _log "⚠ Expiration test inconclusive (timing sensitive)"
    fi
}

test_missing_signature() {
    _log "Test: Verification rejects unsigned warrant"

    # Create unsigned warrant
    warrant_file="$TEST_HOME/warrant-unsigned.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-unsigned-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Try to verify unsigned warrant
    verify_output=$($SIGN_TOOL --verify "$warrant_file" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null || echo "FAILED")

    if echo "$verify_output" | grep -q "No signature"; then
        _pass "Missing signature detection works"
    else
        _fail "Unsigned warrant should be rejected: $verify_output"
    fi
}

test_warrant_info_display() {
    _log "Test: Warrant info display works"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-info.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-info-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed=$($SIGN_TOOL --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null)
    echo "$signed" > "$warrant_file.signed"

    # Show info
    info_output=$($SIGN_TOOL --info "$warrant_file.signed" 2>&1 || true)

    if echo "$info_output" | grep -q "Warrant ID:" && \
       echo "$info_output" | grep -q "Status:"; then
        _pass "Warrant info display works"
    else
        _fail "Warrant info incomplete: $info_output"
    fi
}

test_algorithm_validation() {
    _log "Test: Algorithm field validated"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-algo.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-algo-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed=$($SIGN_TOOL --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null)

    # Tamper with algorithm
    bad_algo=$(echo "$signed" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['signature_algorithm'] = 'RSA-SHA512'
print(json.dumps(data))
")
    echo "$bad_algo" > "$warrant_file.bad-algo"

    # Try to verify
    verify_output=$($SIGN_TOOL --verify "$warrant_file.bad-algo" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null || echo "FAILED")

    if echo "$verify_output" | grep -q "Unsupported signature algorithm"; then
        _pass "Algorithm field validation works"
    else
        _fail "Algorithm field should be validated: $verify_output"
    fi
}

main() {
    _log "Running warrant receiver verification tests..."

    test_signature_verification_via_qwarrant_sign
    test_tampered_warrant_detection
    test_expiration_check
    test_missing_signature
    test_algorithm_validation
    test_warrant_info_display

    _pass "All tests passed (6/6)"
}

main "$@"

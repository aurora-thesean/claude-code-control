#!/bin/bash
# Phase 10b Unit 1: Warrant Signing Infrastructure Tests
# Tests qwarrant-sign tool for RSA signature generation and verification

set -euo pipefail

_log() { echo "[test-warrant-signing] $*" >&2; }
_pass() { echo "✓ $*" >&2; }
_fail() { echo "✗ $*" >&2; exit 1; }

# Setup
TEST_HOME="${TMPDIR:-.}/test-qwarrant-sign-$$"
TEST_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/qwarrant-sign"

cleanup() {
    rm -rf "$TEST_HOME" 2>/dev/null || true
}

trap cleanup EXIT

mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
mkdir -p "$HOME/.aurora-agent"

test_keygen() {
    _log "Test: generate RSA keypair"

    output=$("$TEST_TOOL" --generate-keys --output-dir "$HOME/.aurora-agent" 2>/dev/null) || true

    # Verify output is valid JSON (last line is JSON)
    json_line=$(echo "$output" | tail -1)
    if echo "$json_line" | python3 -m json.tool >/dev/null 2>&1; then
        _pass "Keypair generation outputs valid JSON"
    else
        _fail "Keypair generation output not JSON: $json_line"
    fi

    # Verify key files exist
    if [[ -f "$HOME/.aurora-agent/private.pem" ]] && [[ -f "$HOME/.aurora-agent/public.pem" ]]; then
        _pass "Keypair files created"
    else
        _fail "Keypair files not created"
    fi

    # Verify private key permissions (600)
    perms=$(stat -c %a "$HOME/.aurora-agent/private.pem" 2>/dev/null || stat -f %OLp "$HOME/.aurora-agent/private.pem" 2>/dev/null | tail -c 4)
    if [[ "$perms" == "600" ]] || [[ "$perms" == "0600" ]]; then
        _pass "Private key has correct permissions (600)"
    else
        _log "⚠ Private key permissions: $perms (expected 600)"
    fi
}

test_sign_warrant() {
    _log "Test: sign warrant"

    # Create test warrant
    warrant_file="$TEST_HOME/warrant.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-1",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "task_id": "task-optimize-db",
  "task_description": "Optimize database queries",
  "proposed_loa_cap": 4
}
EOF

    # Sign warrant (capture stdout only, suppress stderr)
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true

    # Verify output contains signature
    if echo "$signed_output" | grep -q '"signature"'; then
        _pass "Warrant signed with signature field"
    else
        _fail "Signed warrant missing signature field"
    fi

    # Verify output contains timestamp
    if echo "$signed_output" | grep -q '"timestamp"'; then
        _pass "Signed warrant contains timestamp"
    else
        _fail "Signed warrant missing timestamp"
    fi

    # Verify output contains expiration
    if echo "$signed_output" | grep -q '"expires_at"'; then
        _pass "Signed warrant contains expiration"
    else
        _fail "Signed warrant missing expiration"
    fi
}

test_verify_valid_warrant() {
    _log "Test: verify valid signed warrant"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-verify.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-2",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true
    echo "$signed_output" > "$warrant_file.signed"

    # Verify it
    verify_output=$("$TEST_TOOL" --verify "$warrant_file.signed" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null) || true

    # Check verification result (handle both with/without spaces)
    if echo "$verify_output" | grep -qE '"status"\s*:\s*"valid"'; then
        _pass "Valid warrant verifies successfully"
    else
        _fail "Valid warrant verification failed: $verify_output"
    fi
}

test_tampered_warrant() {
    _log "Test: reject tampered warrant"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-tamper.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-3",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true
    echo "$signed_output" > "$warrant_file.signed"

    # Tamper with the warrant (change child_uuid)
    tampered_output=$(echo "$signed_output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['child_uuid'] = 'tampered-uuid-9999-9999-9999-999999999999'
print(json.dumps(data))
")
    echo "$tampered_output" > "$warrant_file.tampered"

    # Try to verify tampered warrant
    verify_output=$("$TEST_TOOL" --verify "$warrant_file.tampered" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null) || true

    # Should fail (handle spaces in JSON)
    if echo "$verify_output" | grep -qE '"status"\s*:\s*"invalid"'; then
        _pass "Tampered warrant rejected"
    else
        _fail "Tampered warrant should be rejected: $verify_output"
    fi
}

test_expired_warrant() {
    _log "Test: reject expired warrant"

    # Create warrant with very short TTL
    warrant_file="$TEST_HOME/warrant-expire.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-4",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign with 1-second TTL, then wait
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" --ttl 1 2>/dev/null) || true
    echo "$signed_output" > "$warrant_file.signed"

    # Wait for expiration
    sleep 2

    # Try to verify expired warrant
    verify_output=$("$TEST_TOOL" --verify "$warrant_file.signed" --key "$HOME/.aurora-agent/public.pem" 2>/dev/null) || true

    # Should fail with expiration message (handle spaces)
    if echo "$verify_output" | grep -qE '"status"\s*:\s*"invalid"' && echo "$verify_output" | grep -q "expired"; then
        _pass "Expired warrant rejected"
    else
        _fail "Expired warrant should be rejected: $verify_output"
    fi
}

test_warrant_info() {
    _log "Test: display warrant information"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-info.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-5",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true
    echo "$signed_output" > "$warrant_file.signed"

    # Show info
    info_output=$("$TEST_TOOL" --info "$warrant_file.signed" 2>&1) || true

    # Verify info contains expected fields
    if echo "$info_output" | grep -q "Warrant ID:" && \
       echo "$info_output" | grep -q "Parent UUID:" && \
       echo "$info_output" | grep -q "Signature Algo:"; then
        _pass "Warrant info displays correctly"
    else
        _fail "Warrant info incomplete"
    fi
}

test_signature_format() {
    _log "Test: signature is valid base64"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-format.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-6",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true

    # Extract signature and verify it's valid base64
    sig=$(echo "$signed_output" | python3 -c "import sys, json; print(json.load(sys.stdin)['signature'])")

    # Try to decode
    if echo "$sig" | base64 -d >/dev/null 2>&1; then
        _pass "Signature is valid base64"
    else
        _fail "Signature is not valid base64"
    fi
}

test_signature_length() {
    _log "Test: RSA-2048 signature has expected length"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-length.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-7",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true

    # Extract signature (base64) and check length
    sig=$(echo "$signed_output" | python3 -c "import sys, json; print(json.load(sys.stdin)['signature'])")
    sig_len=${#sig}

    # RSA-2048 signature (base64) should be around 344 characters
    if [[ $sig_len -gt 300 ]] && [[ $sig_len -lt 400 ]]; then
        _pass "Signature has expected RSA-2048 length ($sig_len chars)"
    else
        _fail "Signature length unexpected: $sig_len chars"
    fi
}

test_algorithm_field() {
    _log "Test: signature_algorithm field set correctly"

    # Create and sign warrant
    warrant_file="$TEST_HOME/warrant-algo.json"
    cat > "$warrant_file" <<'EOF'
{
  "warrant_id": "warrant-test-8",
  "parent_uuid": "parent-1111-2222-3333-444444444444",
  "child_uuid": "child-5555-6666-7777-888888888888",
  "proposed_loa_cap": 4
}
EOF

    # Sign it
    signed_output=$("$TEST_TOOL" --sign "$warrant_file" --key "$HOME/.aurora-agent/private.pem" 2>/dev/null) || true

    # Verify algorithm field (handle spaces)
    if echo "$signed_output" | grep -qE '"signature_algorithm"\s*:\s*"RSA-SHA256"'; then
        _pass "Signature algorithm field set to RSA-SHA256"
    else
        _fail "Signature algorithm field incorrect"
    fi
}

main() {
    _log "Running qwarrant-sign tests..."

    test_keygen
    test_sign_warrant
    test_verify_valid_warrant
    test_tampered_warrant
    test_expired_warrant
    test_warrant_info
    test_signature_format
    test_signature_length
    test_algorithm_field

    _pass "All tests passed (9/9)"
}

main "$@"

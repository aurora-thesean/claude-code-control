# Phase 10b: Warrant Signatures & TLS Validation — Design Phase

**Status:** Planning | **Target:** Production-Ready Distributed NESTED_LOA | **Scope:** 3 units

---

## Motivation

Phase 10a delivered distributed NESTED_LOA with HTTP (unencrypted) warrant transmission and no cryptographic signatures. This is acceptable for LAN testing (192.168.0.0/24) but **insufficient for cloud deployment**.

**Security Risks in Phase 10a:**
1. **No warrant signature** — Malicious agent could forge parent UUID
2. **No TLS encryption** — Warrant contents visible on network
3. **No certificate validation** — MITM attacks possible on HTTPS
4. **No timestamp validation** — Replay attacks possible

**Phase 10b Fixes All Four:**
- RSA-based warrant signatures (prevent forgery)
- HTTPS warrant transmission (encrypt in transit)
- Certificate pinning (prevent MITM)
- Timestamp validation (prevent replay)

---

## Design: Three-Layer Security

### Layer 1: Warrant Signature (RSA-2048)

**Before (Phase 10a):**
```json
{
  "warrant_id": "uuid",
  "parent_uuid": "parent-...",
  "child_uuid": "child-...",
  "proposed_loa_cap": 4
}
```

**After (Phase 10b):**
```json
{
  "warrant_id": "uuid",
  "parent_uuid": "parent-...",
  "child_uuid": "child-...",
  "proposed_loa_cap": 4,
  "signature": "base64-rsa-2048-signature",
  "signature_algorithm": "RSA-SHA256",
  "timestamp": "2026-03-13T14:00:00Z",
  "expires_at": "2026-03-13T15:00:00Z"
}
```

**Signature covers:**
```
Hash(warrant_id || parent_uuid || child_uuid || proposed_loa_cap || timestamp)
Encrypted with parent's private key (RSA-2048)
```

### Layer 2: TLS Encryption

**Before (Phase 10a):**
```
POST http://child:9231/warrant
Content-Type: application/json
{warrant JSON}
```

**After (Phase 10b):**
```
POST https://child:9231/warrant
Content-Type: application/json
TLS 1.2+
Certificate: pinned to child's cert
{warrant JSON with signature}
```

### Layer 3: Certificate Pinning

**Setup (One-time):**
```bash
# Child agent generates self-signed cert
openssl req -x509 -newkey rsa:2048 -keyout child-key.pem -out child-cert.pem

# Parent pins child's certificate SHA-256
openssl x509 -in child-cert.pem -noout -fingerprint -sha256
# Output: SHA256 Fingerprint=AA:BB:CC:DD:EE:FF:...

# Parent stores: ~/.aurora-agent/pinned-certs/{child-uuid}.sha256
```

**Validation (On each warrant send):**
```
1. Establish HTTPS connection to child
2. Extract server certificate
3. Compute SHA256 fingerprint
4. Compare against pinned fingerprint
5. Reject if mismatch (prevents MITM)
```

---

## Work Unit Decomposition

### Unit 1: Warrant Signing Infrastructure (120 lines)

**New tool:** `qwarrant-sign` (Python)

**Functionality:**
```python
sign_warrant(warrant_dict, private_key_path)
  → Serialize warrant (JSON canonical form)
  → Compute SHA256 hash
  → Sign with RSA-2048 private key
  → Return: warrant_dict + signature + timestamp

verify_warrant_signature(warrant_dict, public_key_path)
  → Extract signature, timestamp from warrant
  → Check timestamp not expired (default 1 hour)
  → Recompute SHA256 hash
  → Verify signature with RSA public key
  → Return: True/False + reason if invalid
```

**Testing:**
- Create test warrant
- Sign with private key
- Verify with public key
- Test with tampered warrant (should fail)
- Test with expired warrant (should fail)

### Unit 2: HTTPS Warrant Receiver (Enhanced qlaude-warrant-receiver)

**Modifications to qlaude-warrant-receiver:**

```python
# Old (HTTP):
app.run(host='0.0.0.0', port=9231, debug=False)

# New (HTTPS with cert):
app.run(
    host='0.0.0.0',
    port=9231,
    ssl_context=('child-cert.pem', 'child-key.pem'),
    debug=False
)

# Enhanced POST handler:
@app.route('/warrant', methods=['POST'])
def receive_warrant():
    warrant = request.json

    # NEW: Verify signature
    if not verify_warrant_signature(warrant, parent_public_key):
        return {'error': 'Invalid signature'}, 401

    # NEW: Check expiration
    if warrant['expires_at'] < now():
        return {'error': 'Warrant expired'}, 403

    # Existing: Write to disk
    write_warrant_file(warrant)
    return {'status': 'RECEIVED'}
```

**Testing:**
- HTTPS handshake succeeds
- Valid signed warrant accepted
- Invalid signature rejected (401)
- Expired warrant rejected (403)
- Tampered warrant rejected

### Unit 3: Parent-Side Signing & Verification (120 lines)

**Modifications to qlaude (--send-warrant-remote):**

```bash
# Old (Phase 10a):
qlaude --send-warrant-remote "task" --to child --with-loa 4
  → Creates warrant JSON
  → POST to http://child:9231/warrant
  → Returns status

# New (Phase 10b):
qlaude --send-warrant-remote "task" --to child --with-loa 4
  → Creates warrant JSON
  → Calls qwarrant-sign (signs with parent's private key)
  → POST to https://child:9231/warrant
  → Verifies child's certificate (pinning)
  → Returns status + signature verification
```

**New code paths:**
```python
def send_warrant_remote_secure(warrant, child_host, child_port):
    # 1. Sign warrant
    signed_warrant = sign_warrant(warrant, parent_private_key)

    # 2. Verify child's cert
    cert_fingerprint = get_remote_cert_fingerprint(child_host, child_port)
    pinned_fingerprint = load_pinned_cert(child_uuid)
    if cert_fingerprint != pinned_fingerprint:
        raise CertificatePinningError(f"Cert mismatch for {child_uuid}")

    # 3. Send via HTTPS
    response = requests.post(
        f"https://{child_host}:{child_port}/warrant",
        json=signed_warrant,
        verify=False,  # We're using pinning, not CA
        timeout=30
    )

    return response
```

**Testing:**
- Warrant signed correctly
- Child certificate pinned correctly
- HTTPS connection established
- Signed warrant accepted by child
- Tampered warrant rejected

---

## E2E Test: Complete Signed Workflow

**Test scenario (test-phase-10b-e2e.sh):**

```bash
# Setup
1. Generate RSA key pair (parent)
2. Generate self-signed cert (child)
3. Pin child's certificate
4. Parent creates warrant
5. Parent signs warrant (adds signature + timestamp)
6. Parent sends to child via HTTPS
7. Child receives warrant
8. Child verifies signature
9. Child verifies timestamp (not expired)
10. Child accepts warrant
11. Verify audit trail includes "signature_verified"
```

**Expected result:**
- ✓ Warrant signed with valid RSA signature
- ✓ HTTPS connection established
- ✓ Certificate pinning validated
- ✓ Child accepts only after verification
- ✓ Audit trail shows "signature_verified" status

---

## Implementation Strategy

### Key Decisions

**1. RSA Key Management**
- Parent private key: `~/.aurora-agent/private.pem` (chmod 600)
- Parent public key: `~/.aurora-agent/public.pem`
- Child generates own key pair on first run
- Child public key shared with parent (via secure channel, out of scope)

**2. Certificate Generation**
- Child uses self-signed cert (not CA-signed)
- Cert valid for 1 year
- Parent pins cert SHA256 fingerprint
- Regenerate cert if key compromised

**3. Warrant Expiration**
- Default: 1 hour (warrants not reused)
- Configurable via `--warrant-ttl`
- Prevents replay attacks

**4. Backwards Compatibility**
- Phase 10a agents can't read Phase 10b warrants (signature mismatch)
- Phase 10b agents can reject Phase 10a warrants (no signature)
- Recommend: Upgrade all agents before deployment

---

## Files to Create/Modify

### New Files

```
qwarrant-sign               (120 lines, Python)
  → sign_warrant(warrant_dict, private_key_path)
  → verify_warrant_signature(warrant_dict, public_key_path)
  → timestamp validation

tests/test-warrant-signing.sh (200 lines, Bash)
  → Test warrant signing/verification
  → Test with tampered warrants
  → Test expiration

tests/test-phase-10b-e2e.sh (300 lines, Bash)
  → Complete HTTPS workflow test
  → Certificate pinning test
  → Signature verification in audit trail

PHASE-10B-IMPLEMENTATION.md (500 lines)
  → Detailed implementation guide
  → Key generation instructions
  → Certificate pinning setup
  → Troubleshooting guide
```

### Modified Files

```
qlaude-warrant-receiver     (enhanced with HTTPS + signature verification)
qlaude                      (--send-warrant-remote enhanced with signing)
PHASE-10B-COMPLETION.md     (after implementation)
```

---

## Success Criteria

| Criterion | Target | Verification |
|-----------|--------|--------------|
| Unit 1: Warrant signing | 100 tests passing | `bash test-warrant-signing.sh` |
| Unit 2: HTTPS receiver | 50 tests passing | HTTPS handshake + cert validation |
| Unit 3: Parent signing | 50 tests passing | Warrant sent via HTTPS + verified |
| E2E test | Complete workflow | All steps pass, audit trail includes "signature_verified" |
| Key security | RSA-2048 strength | Keys generated with openssl, not hardcoded |
| Certificate pinning | No MITM possible | Cert mismatch detected + rejected |
| Backwards compatibility | Migration path clear | Phase 10a can coexist during transition |

---

## Timeline Estimate

| Unit | Estimate | Notes |
|------|----------|-------|
| Unit 1: Signing infrastructure | 2-3 hours | Python crypto, test suite |
| Unit 2: HTTPS receiver | 1-2 hours | Modify existing code, test |
| Unit 3: Parent-side signing | 1-2 hours | Integrate with qlaude |
| E2E test | 1-2 hours | Complete workflow validation |
| Documentation | 1-2 hours | Implementation guide, troubleshooting |
| **Total** | **6-11 hours** | Parallelizable units 1-3 |

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Key compromise | Store private keys in `~/.aurora-agent/` with chmod 600, consider future encryption |
| Certificate expiration | Implement auto-renewal mechanism (Phase 11) |
| HTTPS handshake failure | Graceful fallback to HTTP with warning (Phase 10a for backward compat) |
| Signature verification overhead | Negligible (<10ms per warrant) |
| Key rotation complexity | Document process, automate via qreveng-daemon |

---

## Next Steps After Phase 10b

### Phase 11: Wordgarden Mesh Integration
- DNS registration of agents at wordgarden.dev
- Distributed certificate authority
- Federated audit log ledger
- Cross-region trust chains

### Phase 12: Agent Reputation & Learning
- Trust score optimization
- Machine learning for task delegation
- Automated capability discovery

---

## Decision Point

**Ready to proceed with Phase 10b?**

This adds cryptographic security (RSA + HTTPS + certificate pinning) without breaking Phase 10a functionality. Recommended before any cloud deployment.

Approval needed for:
1. ✓ Proceed with implementation
2. ? Adjust scope (e.g., skip certificate pinning for now)
3. ? Defer to Phase 11 (use HTTP in production for now)


# Phase 10b Unit 2: HTTPS Warrant Receiver Enhancement

**Status:** Design Phase | **Scope:** Signature validation + TLS support roadmap | **Priority:** Signature validation (critical)

---

## Overview

Phase 10b Unit 2 enhances the warrant receiver with:
1. **Signature Verification** (Phase 10b.1 - CRITICAL) ← Focus
2. **HTTPS Support** (Phase 10b.2 - Future)
3. **Certificate Pinning** (Phase 10b.3 - Future)

---

## Phase 10b.1: Signature Verification (Critical Security)

### Enhancement to qlaude-warrant-receiver

**Add to POST /warrant handler:**

```python
# In do_POST() after JSON parsing:

# 1. Verify signature
signature_algo = warrant_data.get('signature_algorithm')
if not signature_algo or signature_algo != 'RSA-SHA256':
    self.send_response(401)
    self.send_header('Content-Type', 'application/json')
    self.end_headers()
    self.wfile.write(json.dumps({
        'error': 'No signature or unsupported algorithm'
    }).encode())
    return

# 2. Load parent's public key (from ~/.aurora-agent/parent-{uuid}.pem)
parent_uuid = warrant_data.get('parent_uuid')
parent_pubkey_path = WARRANT_DIR.parent / f'parent-{parent_uuid}.pem'

if not parent_pubkey_path.exists():
    # Fall back to parent-public-key.pem (shared secret setup)
    parent_pubkey_path = WARRANT_DIR.parent / 'parent-public-key.pem'

if not parent_pubkey_path.exists():
    self.send_response(401)
    self.send_header('Content-Type', 'application/json')
    self.end_headers()
    self.wfile.write(json.dumps({
        'error': 'Parent public key not found'
    }).encode())
    return

# 3. Import verify function from qwarrant-sign
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend
import base64

try:
    # Load public key
    with open(parent_pubkey_path, 'rb') as f:
        public_key = serialization.load_pem_public_key(
            f.read(),
            backend=default_backend()
        )

    # Extract signature
    signature_b64 = warrant_data.get('signature')
    signature = base64.b64decode(signature_b64)

    # Create canonical JSON for verification
    canonical_json = json.dumps(
        {k: warrant_data[k] for k in sorted(warrant_data.keys())
         if k not in ['signature', 'signature_algorithm']},
        separators=(',', ':'),
        sort_keys=True
    )

    # Verify signature
    public_key.verify(
        signature,
        canonical_json.encode('utf-8'),
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH
        ),
        hashes.SHA256()
    )

    # Signature valid, continue with warrant acceptance
    logger.info(f'Signature verified for warrant {warrant_id}')

except Exception as e:
    self.send_response(401)
    self.send_header('Content-Type', 'application/json')
    self.end_headers()
    self.wfile.write(json.dumps({
        'error': f'Signature verification failed: {str(e)}'
    }).encode())
    return

# 4. Check expiration
expires_at_str = warrant_data.get('expires_at')
if expires_at_str:
    try:
        from datetime import datetime, timezone
        expires_at = datetime.fromisoformat(expires_at_str)
        if datetime.now(timezone.utc) > expires_at:
            self.send_response(403)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'error': f'Warrant expired at {expires_at_str}'
            }).encode())
            return
    except Exception as e:
        self.send_response(400)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({
            'error': f'Invalid expiration timestamp: {str(e)}'
        }).encode())
        return
```

### Key Decision: Public Key Distribution

**Problem:** Child needs parent's public key to verify signatures, but how does it securely obtain it?

**Solutions (in priority order):**

1. **Pre-shared public key** (Phase 10b.1 - NOW)
   - Parent copies `~/.aurora-agent/public.pem` to child
   - Stored as `~/.aurora-agent/parent-public-key.pem`
   - Works for known parent-child pairs
   - Manual setup required (acceptable for now)

2. **Key exchange protocol** (Phase 11)
   - Parent sends public key with first warrant
   - Child validates key fingerprint against pinned list
   - Requires certificate infrastructure

3. **Shared root CA** (Phase 12)
   - All agents get public key from wordgarden.dev CA
   - Automatic discovery

### Testing Unit 2

```bash
test_signature_verification.sh:

1. Generate parent keypair
2. Copy parent public key to child
3. Create warrant with signature
4. POST signed warrant to receiver
5. Verify receiver accepts (200 OK)

6. Tamper with warrant
7. POST tampered warrant
8. Verify receiver rejects (401 Unauthorized)

9. Create warrant, wait for expiration
10. POST expired warrant
11. Verify receiver rejects (403 Forbidden)
```

---

## Phase 10b.2: HTTPS Support (Future, Design Only)

**Scope:** TLS encryption for warrant transmission

**Implementation (pseudocode):**

```python
# Generate self-signed certificate (once)
# $ openssl req -x509 -newkey rsa:2048 \
#   -keyout ~/.aurora-agent/child-key.pem \
#   -out ~/.aurora-agent/child-cert.pem -days 365

# Enhanced receiver:
if args.tls:
    import ssl
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(
        certfile='~/.aurora-agent/child-cert.pem',
        keyfile='~/.aurora-agent/child-key.pem'
    )

    server = socketserver.TCPServer(
        ('0.0.0.0', port),
        WarrantHandler
    )
    server.socket = context.wrap_socket(
        server.socket,
        server_side=True
    )
```

**Status:** Design only — implementation deferred to Phase 10b.2 (2-3 hours)

---

## Phase 10b.3: Certificate Pinning (Future, Design Only)

**Scope:** MITM prevention via certificate fingerprint validation

**Implementation (pseudocode):**

```bash
# Child computes and stores cert fingerprint
openssl x509 -in child-cert.pem -noout -fingerprint -sha256 \
  > ~/.aurora-agent/child-cert.sha256

# Parent pins it
mkdir -p ~/.aurora-agent/pinned-certs
cp child-cert.sha256 ~/.aurora-agent/pinned-certs/{child-uuid}.sha256

# Parent validates before sending warrant
cert_fingerprint=$(echo | openssl s_client -connect child:9231 2>/dev/null | \
  openssl x509 -noout -fingerprint -sha256)
pinned=$(cat ~/.aurora-agent/pinned-certs/{child-uuid}.sha256)

if [[ "$cert_fingerprint" != "$pinned" ]]; then
  echo "ERROR: Certificate mismatch (MITM?)"
  exit 1
fi
```

**Status:** Design only — implementation deferred to Phase 10b.3 (1-2 hours)

---

## Implementation Path

### Phase 10b.1 (NOW - 2-3 hours)
- ✅ Signature verification in receiver
- ✅ Expiration checking
- ✅ Public key loading
- ✅ Tests for all three scenarios

### Phase 10b.2 (Next - 2-3 hours)
- HTTPS server setup
- Self-signed certificate generation
- TLS handshake
- Tests for encryption

### Phase 10b.3 (Later - 1-2 hours)
- Certificate pinning
- Fingerprint validation
- MITM detection

---

## Success Criteria

**Phase 10b.1 Success:**
- ✓ Receiver rejects unsigned warrants
- ✓ Receiver rejects tampered signatures
- ✓ Receiver rejects expired warrants
- ✓ Receiver accepts valid signed warrants
- ✓ All tests passing (5+ test cases)
- ✓ Audit log shows "signature_verified"

---

## Next: Implementation of Phase 10b.1

Ready to implement signature verification in qlaude-warrant-receiver?


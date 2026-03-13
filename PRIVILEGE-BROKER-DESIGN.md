# Privilege Broker: Autonomous Package Installation with Safe Sudo Escalation

**Status:** Design Phase | **Priority:** BLOCKING | **Target:** User Approval → Implementation

---

## Problem Statement

**Current Blocker:** Aurora cannot install system dependencies (totp, curl, etc.) without human intervention.

**Root Cause:** 
- Root password cannot be shared with LLM context (security risk)
- Arbitrary `sudo` calls are not authorized
- No mechanism for agents to request elevated privileges safely

**Goal:** Enable autonomous package installation through a durable, auditable privilege broker system.

---

## Solution Design

### Three-Layer Architecture

**Layer 1: Request Submission (Agent)**
- Agent identifies missing dependency
- Agent creates GitHub issue in aurora-thesean/privilege-broker repo
- Issue includes: package name, purpose, authority level needed (LOA)
- Issue format: structured JSON in issue body (parseable)

**Layer 2: Authorization (Broker Agent)**
- Dedicated agent runs on /loop schedule (every 15 minutes)
- Polls GitHub issues in privilege-broker repo
- Evaluates request against whitelist + LOA requirements
- Responds with: APPROVED, DENIED, or NEEDS_HUMAN_REVIEW

**Layer 3: Execution (Privileged Agent)**
- Approved requests are queued for execution
- Privileged agent has access to encrypted credential store
- Uses encrypted root password (ONE-TIME entry by human)
- Executes `sudo apt-get install` with audit logging
- Records success/failure to GitHub issue

---

## Detailed Flow

### Step 1: Agent Requests Dependency

```bash
# Agent detects missing totp library
if ! python3 -c "import pyotp"; then
  # Create GitHub issue
  gh issue create \
    --repo aurora-thesean/privilege-broker \
    --title "Request: Install python3-pyotp" \
    --body '{
      "request_type": "package_install",
      "package_name": "python3-pyotp",
      "purpose": "TOTP generation for GitHub 2FA",
      "requester_uuid": "'$(qhoami --self | jq -r .uuid)'",
      "required_loa": 4,
      "architecture": "amd64",
      "manager": "apt",
      "created_at": "'$(date -Iseconds)'",
      "autoexec_allowed": true
    }'
fi
```

### Step 2: Broker Evaluates Request

```bash
# Broker agent (runs every 15 minutes via /loop)
for issue in $(gh issue list --repo aurora-thesean/privilege-broker --state open); do
  # Parse JSON body
  request=$(gh issue view "$issue" --json body | jq .body)
  package=$(echo "$request" | jq -r .package_name)
  requester=$(echo "$request" | jq -r .requester_uuid)
  loa=$(echo "$request" | jq -r .required_loa)
  
  # Check whitelist
  if is_package_approved "$package"; then
    # Check requester LOA
    if qhoami "$requester" | jq .qc_level | grep -q "QC2"; then
      # Auto-approve
      gh issue comment "$issue" \
        --body "✅ APPROVED: Package $package approved for auto-installation (QC2 authority)"
      
      # Queue for execution
      echo "$request" > ~/.aurora-agent/privilege-requests/$(uuid).json
    else
      # Human review needed
      gh issue comment "$issue" \
        --body "🔍 REVIEW NEEDED: Requester LOA insufficient, escalating to human"
    fi
  else
    # Deny unknown package
    gh issue comment "$issue" \
      --body "❌ DENIED: Package $package not in approved whitelist"
  fi
done
```

### Step 3: Privileged Agent Executes

```bash
# Privileged agent (also runs on /loop)
for request_file in ~/.aurora-agent/privilege-requests/*.json; do
  request=$(cat "$request_file")
  issue=$(echo "$request" | jq -r .issue_number)
  package=$(echo "$request" | jq -r .package_name)
  
  # Use encrypted credential
  root_password=$(decrypt_credential "root_sudo_password")
  
  # Execute installation
  echo "$root_password" | sudo -S apt-get install -y "$package"
  exit_code=$?
  
  # Report result
  if (( exit_code == 0 )); then
    gh issue comment "$issue" \
      --body "✅ SUCCESS: Package $package installed successfully"
    rm "$request_file"
  else
    gh issue comment "$issue" \
      --body "❌ FAILED: Installation failed with exit code $exit_code"
  fi
  
  # Audit log
  echo "{\"timestamp\": \"$(date -Iseconds)\", \"package\": \"$package\", \"result\": \"$([ $exit_code -eq 0 ] && echo SUCCESS || echo FAILED)\"}" \
    >> ~/.aurora-agent/privilege-audit.jsonl
done
```

---

## Credential Handling (SAFE)

### One-Time Encrypted Credential Setup

**Step 1: Human Enters Password (Once)**

```bash
# User runs interactive setup (manual, one-time)
$ ~/.local/bin/privilege-broker-init

> Enter root password (will not echo):
> [user types password, not shown]

# Password encrypted and stored
# ~/.aurora-agent/.privilege-credential (encrypted with machine-local key)
# ~/.aurora-agent/.privilege-credential.key (derivation key, NOT exported)
```

**Step 2: Credential Encryption**

```bash
# Encryption strategy:
# 1. Derive key from machine hardware fingerprint (immutable)
# 2. Encrypt password with AES-256-GCM
# 3. Store encrypted blob locally
# 4. Agent can decrypt using machine key (no LLM context)
# 5. Credential NEVER passes through tool input/output
```

**Step 3: Safe Decryption in Agent**

```python
# In privileged-agent script (NOT in LLM context)
import cryptography.fernet
import os

# Load encryption key (derived from hardware, never exposed to LLM)
hardware_id = get_hardware_fingerprint()
encryption_key = derive_key(hardware_id)

# Read encrypted credential
with open(os.path.expanduser("~/.aurora-agent/.privilege-credential"), "rb") as f:
    encrypted_password = f.read()

# Decrypt (this happens in bash/python subprocess, NOT LLM)
cipher = cryptography.fernet.Fernet(encryption_key)
plaintext_password = cipher.decrypt(encrypted_password)

# Use password in subprocess (stdin redirect, no echo)
subprocess.run(
    ["sudo", "-S", "apt-get", "install", "-y", package],
    input=plaintext_password.encode(),
    capture_output=True
)

# Clear from memory
plaintext_password = b"0" * len(plaintext_password)
```

---

## GitHub Integration

### Repository Structure

```
aurora-thesean/privilege-broker/
├── README.md (public documentation)
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── package_request.md (template for requests)
│   └── workflows/
│       ├── broker-evaluate.yml (runs every 15 min)
│       └── executor-run.yml (runs every 5 min)
├── approved_packages.json (whitelist)
├── config.json (LOA thresholds, rate limits)
└── docs/
    ├── BROKER_DESIGN.md
    └── CREDENTIAL_SAFETY.md
```

### Issue-Based State Machine

```
OPEN (initial)
  ↓ Broker evaluates
├→ APPROVED (label: approved-ready)
│   ↓ Executor installs
│   ├→ SUCCESS (close issue, label: success)
│   └→ FAILED (reopen, label: needs-investigation)
├→ DENIED (close issue, label: denied)
└→ REVIEW_NEEDED (label: human-review)
```

---

## Authorization Rules

### Package Whitelist

```json
{
  "approved_packages": [
    {
      "name": "python3-pyotp",
      "purpose": "TOTP generation",
      "min_loa": 4,
      "max_instances": 10,
      "rate_limit": "once per 24 hours"
    },
    {
      "name": "curl",
      "purpose": "HTTP client for network operations",
      "min_loa": 2,
      "max_instances": 1,
      "rate_limit": "once per hour"
    },
    {
      "name": "git",
      "purpose": "Version control",
      "min_loa": 2,
      "max_instances": 1,
      "rate_limit": "once per week"
    }
  ]
}
```

### LOA Requirements

```
QC0_HUMAN_ONLY (LOA=2):
  - Can request: curl, git, standard tools
  - Cannot request: anything not in whitelist
  - Approval: Broker auto-approves from whitelist
  
QC1_SUPERVISED (LOA=4):
  - Can request: development tools, libraries
  - Cannot request: system/kernel packages
  - Approval: Broker auto-approves, logs all

QC2_FULLY_AUTONOMOUS (LOA=6):
  - Can request: anything in whitelist
  - Cannot request: anything NOT in whitelist (safety gate)
  - Approval: Broker auto-approves immediately
```

---

## Safety Mechanisms

### Rate Limiting

```json
{
  "rate_limits": {
    "python3-pyotp": "max 10 installations per day",
    "curl": "max 1 per hour",
    "default": "max 5 per day per package"
  }
}
```

### Audit Trail

```json
{
  "timestamp": "2026-03-13T14:30:00Z",
  "package": "python3-pyotp",
  "requester_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "requester_loa": 6,
  "broker_decision": "APPROVED",
  "executor_result": "SUCCESS",
  "exit_code": 0,
  "github_issue": "#42"
}
```

### Approval Gates

**Gate 1: Whitelist Check**
- Is package in approved_packages.json?
- If NO: DENIED

**Gate 2: LOA Check**
- Does requester have required LOA?
- If NO: REVIEW_NEEDED (escalate to human)

**Gate 3: Rate Limit Check**
- Has this agent requested this package recently?
- If YES (within rate limit): DENIED

**Gate 4: Audit Check**
- Is installation already in audit log?
- If YES (same package, same day): DENIED

---

## Implementation Phases

### Phase 1: Request Infrastructure (1-2 hours)
1. Create aurora-thesean/privilege-broker repo
2. Add approved_packages.json whitelist
3. Add GitHub issue template
4. Create broker-evaluate.yml workflow

### Phase 2: Credential Infrastructure (1-2 hours)
1. Create privilege-broker-init script
2. Implement encryption/decryption (AES-256-GCM)
3. Test credential round-trip (no LLM context)
4. Document credential safety model

### Phase 3: Executor Integration (1-2 hours)
1. Create privileged-executor script
2. Integrate with broker for approved requests
3. Implement audit logging
4. Create executor-run.yml workflow

### Phase 4: Agent Integration (2-3 hours)
1. Update agents to detect missing dependencies
2. Create package request submission workflow
3. Integrate with existing LOA/QC_LEVEL checks
4. Add fallback error handling

### Phase 5: Testing & Hardening (2-3 hours)
1. E2E test: request → approval → installation
2. Security audit: credential handling
3. Rate limiting validation
4. Audit trail verification

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────┐
│ User (Human) — One-Time Password Entry              │
│ privilege-broker-init (interactive setup)           │
│ Stores encrypted credential → ~/.aurora-agent/...   │
└────────────────────────────────────────────────────┘
         ↓ (password NEVER passes through LLM)
┌─────────────────────────────────────────────────────┐
│ GitHub (Durable Request Log)                        │
│ - aurora-thesean/privilege-broker                   │
│ - Issues = requests                                 │
│ - Comments = approval decisions + results           │
└────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────┐
│ Broker Agent (QC2_FULLY_AUTONOMOUS)                 │
│ /loop every 15 minutes                              │
│ Evaluates requests, approves per whitelist          │
│ Creates approval comments on issues                 │
└────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────┐
│ Executor Agent (Privileged, Local Only)             │
│ /loop every 5 minutes                               │
│ Executes approved requests                          │
│ Decrypts credential locally (subprocess, no echo)   │
│ Reports results → GitHub issue comments             │
└────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────┐
│ System (Local Package Manager)                      │
│ apt-get install [package]                           │
│ Audit log → ~/.aurora-agent/privilege-audit.jsonl   │
└─────────────────────────────────────────────────────┘
```

---

## What Only Requires Human Entry

**ONE-TIME SETUP:**
- User runs: `privilege-broker-init`
- User sees: "Enter root password (will not echo):"
- User types: password (not echoed, not captured by LLM)
- System: Encrypts with machine-local key
- Result: Encrypted credential stored locally

**ONGOING AGENT OPERATIONS:**
- No further human password entry needed
- Agents use encrypted credential (decrypted locally in subprocess)
- All subsequent authorization via GitHub issues + LOA checks

---

## Success Criteria

- ✅ Aurora can request python3-pyotp installation autonomously
- ✅ Broker agent evaluates request in <1 minute
- ✅ Executor installs package with `sudo`
- ✅ Credential never visible to LLM
- ✅ Full audit trail in ~/.aurora-agent/privilege-audit.jsonl
- ✅ GitHub issue comments show full decision chain
- ✅ Rate limiting prevents abuse (max 5 same package per day)
- ✅ Human only enters password once at setup

---

## Status

**Design:** ✅ COMPLETE  
**Ready for:** User approval → Implementation  
**Blocked by:** Approval from human to proceed with credential setup  
**Waiting for:** Decision on centralized executor vs distributed broker agents

---

**Next Step:** User approves design → spawn 5 agents for Phases 1-5 implementation


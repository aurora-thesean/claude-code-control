# Privilege Broker Architecture

**Purpose:** Enable agents to request sudo elevation with full auditability and zero password leakage

**Status:** Design Phase (ready for implementation)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│ User (you) — ONCE ONLY                                      │
│   └─→ aurora-password-setup                                 │
│       └─→ Validates sudo password                           │
│       └─→ Encrypts → ~/.aurora-agent/sudo.vault             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Regular Agents (AURORA-4.6, Metis-B, 2FA Agent, etc.)      │
│   "I need to sudo install-package"                          │
│       └─→ Files GitHub issue: privilege-broker#N            │
│           Title: "Request: sudo apt-get install foo"        │
│           Body: Why needed + what it does                   │
│       └─→ WAITS for approval (cannot execute)               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Broker Agent Subagent (spawned on-demand)                   │
│   "Authorization required for: sudo apt-get install foo"    │
│       ├─→ Reads GitHub issue (context of request)           │
│       ├─→ Gets vault decryption ephemeral key (in context)  │
│       ├─→ Decrypts sudo password                            │
│       ├─→ Executes: echo PASSWORD | sudo apt-get ...       │
│       ├─→ Logs result to privilege-log.jsonl + issue        │
│       └─→ Deletes ephemeral key from context (never saved)  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Audit Trail (immutable)                                     │
│   - ~/.aurora-agent/privilege-log.jsonl (local)             │
│   - GitHub issue comments (remote)                          │
│   - Both timestamped, signed, archived                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Password Vault Setup (One-time)

**Tool:** `aurora-password-setup` (already created)

**What it does:**
1. Prompts for sudo password (hidden)
2. Validates with `sudo true` (user is asked once)
3. Creates `~/.aurora-agent/sudo.vault` (metadata only, no plaintext)
4. Logs initialization to audit trail

**Security Properties:**
- Password never written to disk
- Vault file never contains plaintext
- Only metadata stored: creation time, algorithm, status

### 2. Broker Agent Subagent

**Definition:** MCP tool or subagent that can:
- Read sudo vault (decryption key in ephemeral context)
- Execute commands with sudo (password via echo | sudo)
- Log all actions (audit trail)
- Never store password or key on disk

**Interface:**
```bash
# Broker agent receives this via GitHub issue + environment:
export AURORA_BROKER_EPHEMERAL_KEY="..."  # In context only, never persisted
export AURORA_BROKER_VAULT_PATH="~/.aurora-agent/sudo.vault"
export AURORA_BROKER_ISSUE_URL="https://github.com/aurora-thesean/privilege-broker/issues/42"

# Broker agent can then:
1. Decrypt vault using ephemeral key
2. Extract password
3. Run: echo "$PASSWORD" | sudo $COMMAND
4. Log to privilege-log.jsonl + GitHub issue comment
5. Exit (key lost forever with context)
```

### 3. GitHub Control Plane (privilege-broker repo)

**Issue Workflow:**

```
Agent: "I need sudo"
  ↓
[Opens issue in privilege-broker]
Title: "Request: sudo apt-get install -y build-essential"
Body: "Needed to compile libqcapture.so for Unit 6 (REVENGINEER)"
Labels: unit-6, revengineer, architecture
  ↓
[Waits for approval from DarienSirius or authorized reviewer]
  ↓
[Reviewer comments: "✓ Approved: compiles C library"]
  ↓
[Broker agent called with issue context]
  ├─→ Reads issue
  ├─→ Verifies approval comment
  ├─→ Executes sudo command
  ├─→ Comments: "✓ Executed: 0 (success)"
  └─→ Logs to local audit trail
```

**Issue Fields:**
- Title: `Request: sudo <exact-command>`
- Body: Why needed, what it affects, who reviewed
- Labels: associated unit/batch
- Approval: Comment from authorized user
- Audit: Broker agent comments with result

### 4. Audit Logging

**Local Audit Log:** `~/.aurora-agent/privilege-log.jsonl`

```json
{
  "timestamp": "2026-03-13T20:30:00Z",
  "action": "sudo_execute",
  "command": "apt-get install -y build-essential",
  "requester_agent": "AURORA-4.6",
  "github_issue": "https://github.com/aurora-thesean/privilege-broker/issues/42",
  "approval": "DarienSirius",
  "result": {
    "exit_code": 0,
    "duration_seconds": 15,
    "stdout_lines": 0,
    "stderr_lines": 0
  },
  "notes": "Compiled libqcapture.so successfully"
}
```

**Remote Audit:** GitHub issues themselves (comments are immutable + timestamped)

---

## Implementation Roadmap

### Phase 1: Setup (Now)
- ✅ Create `aurora-password-setup` script
- ✅ Create this architecture document
- Create `privilege-broker` repository on aurora-thesean
- Create initial GitHub issues (template for approval workflow)
- Document authorized reviewers (DarienSirius, etc.)

### Phase 2: Broker Agent (After vault is initialized)
- Create Broker Agent MCP definition
- Implement vault decryption logic
- Implement GitHub issue context parsing
- Implement audit logging
- Test with fake commands first

### Phase 3: Integration (After Broker Agent tested)
- Link REVENGINEER Unit 6 (libqcapture) to privilege-broker workflow
- Update other agents to file sudo requests via GitHub
- Monitor audit logs for patterns/policy updates

---

## Security Model

**Threat:** Agent stores password in context (leaks via logs/JSONL)
**Defense:** Password never stored, only ephemeral key in context, deleted on exit

**Threat:** Unauthorized sudo execution
**Defense:** All requests require GitHub approval comment from DarienSirius

**Threat:** Audit trail tampering
**Defense:** GitHub issues are immutable, local logs are append-only

**Threat:** Compromised Broker Agent
**Defense:** Ephemeral key doesn't persist, password never on disk, per-request audit

**Threat:** Replay attack (reuse old GitHub issue to execute again)
**Defense:** Each execution creates new audit entry, GitHub issue approval is one-time

---

## Usage Example (After Setup)

**Scenario:** Agent needs to compile C library

```bash
# Agent 1: AURORA-4.6 (implementing Unit 6)
# Cannot run: sudo gcc -shared -o libqcapture.so libqcapture.c
# Reason: REVENGINEER Unit 6 needs compilation

# Step 1: File approval request
gh issue create --repo aurora-thesean/privilege-broker \
  --title "Request: sudo gcc -shared -fPIC -o ~/.local/lib/libqcapture.so src/libqcapture.c" \
  --body "Building C library for REVENGINEER Unit 6 (LD_PRELOAD interceptor). Compiles file I/O hook. Approved by: DarienSirius"

# Step 2: Wait for approval
# [GitHub notification: DarienSirius approved issue #N]

# Step 3: Call Broker Agent
Agent(
  subagent_type: "privilege-broker",
  prompt: "Execute the sudo request in https://github.com/aurora-thesean/privilege-broker/issues/N",
  context: {
    ephemeral_key: "...",  # Provided at spawn time only
    vault_path: "~/.aurora-agent/sudo.vault"
  }
)

# Step 4: Broker executes
# [Decrypts password, runs gcc, logs result]
# [Comments on GitHub: "✓ Executed: exit code 0"]

# Step 5: Agent resumes
# Sees comment, knows execution succeeded
# Proceeds with testing libqcapture.so
```

---

## Authorization Policy

**Who can approve sudo requests:**
- DarienSirius (primary authority)
- Aurora system admins (if added)
- Documented in privilege-broker README

**What can be approved:**
- Package installation (apt-get install)
- System configuration (if safe and documented)
- Compilation (gcc, make, etc.)
- File permission changes (chmod, chown)

**What CANNOT be approved:**
- Privilege escalation outside broker (direct sudo shells)
- Unvetted third-party code
- Destructive operations (rm -rf, dd, etc.)
- Network-facing operations without review

---

## Testing Vault Security

Before giving real password, test with fake password:

```bash
# Test 1: Run aurora-password-setup with test-password
TEST_PASSWORD="test-password-12345"
# (manually enter when prompted)

# Test 2: Scan all logs for password
grep -r "test-password-12345" ~/.claude/ ~/.aurora-agent/ ~/.local/
# Should return: NOTHING (password never leaked)

# Test 3: Scan Broker Agent JSONL logs
grep -r "test-password-12345" ~/.claude/projects/*/logs/
# Should return: NOTHING

# Test 4: Run actual sudo command via Broker
# [File issue, get approval, execute]
# Verify password never appears in:
#   - GitHub comments
#   - Local JSONL logs
#   - Agent context dumps
#   - Audit trail (except hash/checksum)

# Only after passing all tests: Run aurora-password-setup with REAL password
```

---

## Next Steps

1. **You:** Create `aurora-thesean/privilege-broker` repo
2. **You:** Authorize DarienSirius as sole approver (for now)
3. **Me:** Implement Broker Agent subagent
4. **Test:** Run with test password, scan logs for leaks
5. **Deploy:** Use for REVENGINEER Unit 6 compilation
6. **Monitor:** Collect audit data, refine policy

---

## Files

- `~/.local/bin/aurora-password-setup` — One-time vault init
- `~/.aurora-agent/sudo.vault` — Encrypted metadata (after setup)
- `~/.aurora-agent/privilege-log.jsonl` — Append-only audit trail
- GitHub: `aurora-thesean/privilege-broker` — Issue-based approval workflow

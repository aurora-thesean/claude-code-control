# Privilege Broker: Phase 2 Implementation

**Status:** INITIATING  
**Target:** 2026-03-13 → 2026-03-14  
**Phase:** Broker Agent implementation + testing

---

## Broker Agent Specification

### Purpose
Subagent that safely executes sudo commands on behalf of agents, with:
- Vault decryption (ephemeral key in context only)
- GitHub approval verification
- Audit logging (JSONL + GitHub comments)
- Password never persisted

### Architecture

```
Input: GitHub issue URL + ephemeral decryption key (in context)
  ↓
1. Read issue from privilege-broker repo
  ↓
2. Verify approval comment from authorized user
  ↓
3. Extract sudo command from issue title
  ↓
4. Decrypt vault.json using ephemeral key
  ↓
5. Extract password from decrypted data
  ↓
6. Execute: echo "$PASSWORD" | sudo $COMMAND
  ↓
7. Log result to ~/.aurora-agent/privilege-log.jsonl
  ↓
8. Comment on GitHub issue with exit code
  ↓
9. Clear password, exit (key lost with context)
Output: { success: bool, exit_code: int, duration: float }
```

### Files to Create

1. **~/.local/bin/broker-agent.sh** (100-150 lines)
   - Main orchestrator for vault + GitHub + sudo workflow
   - Interfaces with gh CLI for GitHub issue access

2. **src/broker-vault-crypto.sh** (60-80 lines)
   - AES-256-CBC decryption using ephemeral key
   - Parses vault JSON structure
   - Extracts password field

3. **src/broker-issue-parser.sh** (40-60 lines)
   - Reads GitHub issue via gh CLI
   - Extracts sudo command from title (format: "Request: sudo <command>")
   - Verifies approval comment

4. **src/broker-audit-logger.sh** (40-50 lines)
   - Logs execution to ~/.aurora-agent/privilege-log.jsonl
   - Comments on GitHub issue with result
   - Formats JSON with timestamp + metadata

5. **tests/test-broker-agent.sh** (100+ lines)
   - Unit tests for each component
   - Mock GitHub issue + vault for testing
   - Security test: verify password not in logs

### Security Model

**Threat: Password stored in context logs**
- Defense: Password extracted from vault, used immediately, cleared on exit
- Verification: Grep logs for test password (should find 0 matches)

**Threat: Unauthorized sudo execution**
- Defense: GitHub approval comment required (must be from authorized user)
- Verification: Approval comment checked before execution

**Threat: Sudo command tampering**
- Defense: Command extracted from GitHub issue (immutable once created)
- Verification: Log entry includes exact command executed

**Threat: Lost audit trail**
- Defense: Dual logging (local JSONL + GitHub comment)
- Verification: Both sources have matching entry

### Implementation Notes

1. **Vault Decryption:**
   - Ephemeral key passed in context: `AURORA_BROKER_EPHEMERAL_KEY`
   - Vault path: `~/.aurora-agent/sudo.vault`
   - Extract password from vault.json (need to determine structure)

2. **GitHub Integration:**
   - Use `gh issue view <number>` to read issue
   - Parse title for command: `Request: sudo <command>`
   - Verify approval comment: "@DarienSirius approved" or similar
   - Post result comment: `✓ Executed: exit code 0`

3. **Sudo Execution:**
   - Command: `echo "$PASSWORD" | sudo -S <actual_command>`
   - Capture exit code, stdout, stderr
   - Duration calculation: `time` command

4. **Audit Entry Format:**
   ```json
   {
     "timestamp": "2026-03-13T20:30:00Z",
     "action": "sudo_execute",
     "command": "apt-get install -y build-essential",
     "requester": "AURORA-4.6",
     "github_issue": "https://github.com/aurora-thesean/privilege-broker/issues/42",
     "approval_by": "DarienSirius",
     "exit_code": 0,
     "duration_seconds": 15,
     "result": "SUCCESS"
   }
   ```

### Testing Strategy

**Unit Tests:**
1. Vault decryption (with test key + fake vault)
2. GitHub issue parsing (mock gh output)
3. Sudo execution (with mock commands)
4. Audit logging (verify JSON format)
5. Security: password leakage check

**Integration Test:**
1. Create test GitHub issue in privilege-broker
2. Run broker-agent with test vault + ephemeral key
3. Verify issue comment has result
4. Verify audit log entry
5. Grep for password (should not appear)

**E2E Test (Phase 3):**
1. Initialize real vault with test password
2. Create real GitHub issue
3. Execute broker-agent
4. Verify real sudo command executed
5. Confirm audit trail

### Dependencies

- `gh` CLI (GitHub authentication)
- `openssl` (AES-256-CBC decryption)
- `jq` (JSON parsing for vault)
- `sudo` (password-based elevation)

### Timeline

**Phase 2 (This session):**
- [ ] Design finalized (this doc)
- [ ] broker-agent.sh implemented
- [ ] Crypto functions implemented
- [ ] GitHub parsing implemented
- [ ] Audit logging implemented
- [ ] Unit tests written
- [ ] Security verification

**Phase 3 (Next session):**
- [ ] Real password vault initialization
- [ ] Real GitHub issue testing
- [ ] Unit 6 sudo compilation
- [ ] Full audit trail review

---

## Questions Before Implementation

1. **Vault Structure:** What JSON format does aurora-password-setup create? (need to know password field name)
2. **GitHub Approval:** Should approval comment be required? Who are authorized approvers?
3. **Sudoers Policy:** Do we have a sudoers file with NOPASSWD for any commands? (for testing)
4. **Execution Method:** Use `echo $PASSWORD | sudo -S` or `sudo -S -p prompt` approach?
5. **Timeout:** Should broker-agent have timeout on sudo execution?

---

## Success Criteria

✅ Broker agent compiles/runs without errors  
✅ Unit tests all passing  
✅ Password never appears in any log  
✅ Audit trail captures all execution details  
✅ GitHub integration working (can read issues, post comments)  
✅ Security test (grep for test password) returns 0 matches  


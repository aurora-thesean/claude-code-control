# NESTED_LOA Implementation Guide

**Status:** Phase 1 Complete (Units 1-6) | **Version:** 0.3.0-nested-loa | **Date:** 2026-03-12

---

## Quick Start: Hierarchical Agent Delegation

NESTED_LOA enables safe delegation of tasks from parent agents (high autonomy) to child agents (lower autonomy) through a warrant-based system. This guide covers implementation and usage.

### Basic Workflow

```bash
# 1. Parent creates warrant (must be QC2_FULLY_AUTONOMOUS)
qlaude --delegate "optimize queries" --to <child-uuid> --with-loa 4

# 2. Child validates warrant
qlaude --validate-warrant ~/.aurora-agent/warrants/<warrant-id>.json

# 3. Child accepts warrant
qlaude --accept-warrant ~/.aurora-agent/warrants/<warrant-id>.json

# 4. Child executes task, reports progress
qlaude --report-progress <warrant-id> 10 9 1 IN_PROGRESS
qlaude --report-progress <warrant-id> 20 19 1 COMPLETED

# 5. Audit trail tracks everything
cat ~/.aurora-agent/.qlaude-audit.jsonl | grep "warrant"
```

---

## Operations Reference

### Parent: Create Warrant

```bash
qlaude --delegate <task-description> \
  --to <child-uuid> \
  --with-loa <0-10> \
  [--trust <0.0-1.0>] \
  [--time-limit <seconds>]
```

**Requirements:**
- `--to <child-uuid>`: Valid UUID of child agent (8-4-4-4-12 hex format)
- `--with-loa <n>`: Proposed autonomy level (0=human only, 10=full autonomy)
- Parent must be QC2_FULLY_AUTONOMOUS (LOA_CAP=6 in ~/.claude/CLAUDE.md)

**Optional:**
- `--trust <score>`: Trust score 0.0-1.0 (default 0.5)
- `--time-limit <secs>`: Task deadline in seconds (default 3600)

**Output:**
```json
{
  "warrant_id": "uuid...",
  "warrant_file": "/home/user/.aurora-agent/warrants/uuid.json"
}
```

**Storage:** `~/.aurora-agent/warrants/{warrant_id}.json`

---

### Parent: Validate Warrant

```bash
qlaude --validate-warrant <warrant_file>
```

**Returns:** JSON with status and validation details

```json
{
  "type": "warrant-validation",
  "status": "VALID|INVALID|EXPIRED",
  "warrant_id": "uuid...",
  "reason": "explanation"
}
```

**Status values:**
- `VALID`: Warrant is valid, not expired, LOA_CAP hierarchy correct
- `INVALID`: JSON structure problem, missing fields, or LOA_CAP violation
- `EXPIRED`: Warrant expiration time passed

---

### Child: Accept Warrant

```bash
# Accept with full approval (child LOA_CAP >= proposed)
qlaude --accept-warrant <warrant_file>

# Counter-propose lower LOA if needed
qlaude --accept-warrant <warrant_file> --counter-propose <loa>
```

**Auto-Accept Behavior:**
- If child LOA_CAP >= proposed LOA_CAP: Auto-accepts with status ACCEPTED
- If child LOA_CAP < proposed LOA_CAP: Auto-negotiates, status NEGOTIATED

**Counter-Proposal:**
- `--counter-propose <loa>`: Request lower autonomy level
- Example: Parent proposes LOA=6, child with LOA=2 can counter-propose LOA=2

**Output:** Acceptance record (JSON JSONL)

```json
{
  "type": "loa_acceptance",
  "warrant_id": "uuid...",
  "parent_uuid": "uuid...",
  "child_uuid": "uuid...",
  "proposed_loa_cap": 4,
  "accepted_loa_cap": 4,
  "status": "ACCEPTED|NEGOTIATED",
  "reason": "explanation",
  "timestamp": "2026-03-12T14:05:00Z"
}
```

**Storage:** `~/.aurora-agent/warrants/acceptances/{warrant_id}_acceptance.jsonl`

---

### Child: Report Progress

```bash
qlaude --report-progress <warrant_id> \
  <decisions_made> \
  <decisions_approved> \
  <decisions_rejected> \
  [status]
```

**Parameters:**
- `<warrant_id>`: UUID of the warrant being executed
- `<decisions_made>`: Total decisions made so far
- `<decisions_approved>`: Decisions approved (within LOA_CAP)
- `<decisions_rejected>`: Decisions rejected (exceeded LOA_CAP)
- `[status]`: IN_PROGRESS|PAUSED|COMPLETED|FAILED (default: IN_PROGRESS)

**Example:**
```bash
# After 10 decisions (9 approved, 1 rejected)
qlaude --report-progress b3431ea5-f4a7-4c05-be03-1d9ba6e55f8e 10 9 1 IN_PROGRESS

# After completion (15 decisions, 14 approved, 1 rejected)
qlaude --report-progress b3431ea5-f4a7-4c05-be03-1d9ba6e55f8e 15 14 1 COMPLETED
```

**Output:** Progress record (JSON JSONL)

```json
{
  "type": "task_progress",
  "warrant_id": "uuid...",
  "child_uuid": "uuid...",
  "decisions_made": 15,
  "decisions_approved": 14,
  "decisions_rejected": 1,
  "approval_rate": 93.3,
  "status": "COMPLETED",
  "timestamp": "2026-03-12T14:15:00Z"
}
```

**Storage:** `~/.aurora-agent/warrants/progress/{warrant_id}_{timestamp}.jsonl`

---

## File Organization

```
~/.aurora-agent/
├── warrants/
│   ├── {warrant_id}.json              # Warrant definition (parent creates)
│   ├── acceptances/
│   │   └── {warrant_id}_acceptance.jsonl  # Acceptance record (child writes)
│   └── progress/
│       └── {warrant_id}_{timestamp}.jsonl # Progress checkpoints (child writes)
├── .qlaude-audit.jsonl                # Audit trail (all operations logged)
└── home-session-id                    # Current session UUID
```

---

## Audit Logging

All warrant operations are logged to `~/.aurora-agent/.qlaude-audit.jsonl` with full context:

```json
{
  "timestamp": "2026-03-12T14:05:00Z",
  "action": "warrant-create|warrant-accept|task-progress",
  "decision": "PROPOSED|ACCEPTED|NEGOTIATED|IN_PROGRESS|COMPLETED",
  "qc_level": "0|1|2",
  "loa_cap": 6,
  "reason": "description",
  "parent_uuid": "uuid...",
  "warrant_id": "uuid..."
}
```

**Audit fields:**
- `action`: Type of operation (warrant-create, warrant-accept, task-progress)
- `decision`: Status (PROPOSED, ACCEPTED, NEGOTIATED, IN_PROGRESS, COMPLETED, FAILED)
- `parent_uuid`: Parent agent that initiated warrant (set if delegating)
- `warrant_id`: Warrant UUID for correlation
- `qc_level`: Quality control level (0=human, 1=supervised, 2=autonomous)
- `loa_cap`: Parent's LOA_CAP value at time of operation

---

## Warrant Format Specification

### Warrant Structure (Parent → Child)

```json
{
  "type": "loa_proposal",
  "warrant_id": "uuid...",
  "parent_uuid": "uuid...",
  "child_uuid": "uuid...",
  "task_description": "optimize database indexes",
  "proposed_loa_cap": 4,
  "trust_score": 0.8,
  "time_limit_seconds": 3600,
  "created_at": "2026-03-12T14:00:00Z",
  "expires_at": "2026-03-12T15:00:00Z",
  "parent_loa_cap": 6
}
```

**Required fields:**
- `warrant_id`: UUID (created by parent)
- `parent_uuid`: Parent's session UUID
- `child_uuid`: Target child's session UUID
- `proposed_loa_cap`: Requested autonomy level (0-10)
- `expires_at`: Expiration timestamp (ISO 8601, default 1 hour from creation)
- `parent_loa_cap`: Parent's LOA_CAP (for verification)

**Optional fields:**
- `task_description`: Human-readable task
- `trust_score`: 0.0-1.0 confidence in child
- `time_limit_seconds`: Task deadline

---

## Example: Complete Delegation Workflow

### Scenario: Database Optimization

```bash
# === PARENT SIDE (LOA_CAP=6) ===

# 1. Create warrant for child
$ qlaude --delegate "optimize database indexes for production" \
  --to 11111111-1111-1111-1111-111111111111 \
  --with-loa 4 \
  --trust 0.95

Output:
{
  "warrant_id": "b3431ea5-f4a7-4c05-be03-1d9ba6e55f8e",
  "warrant_file": "~/.aurora-agent/warrants/b3431ea5-..."
}

# === CHILD SIDE (LOA_CAP=4) ===

# 2. Validate warrant (optional, but recommended)
$ qlaude --validate-warrant ~/.aurora-agent/warrants/b3431ea5-...

Output:
{
  "type": "warrant-validation",
  "status": "VALID",
  "warranty_id": "b3431ea5-...",
  "reason": "Warrant is valid and not expired"
}

# 3. Accept warrant
$ qlaude --accept-warrant ~/.aurora-agent/warrants/b3431ea5-...

Output:
{
  "type": "loa_acceptance",
  "warrant_id": "b3431ea5-...",
  "parent_uuid": "00000000-0000-0000-0000-000000000001",
  "status": "ACCEPTED",
  "accepted_loa_cap": 4,
  "reason": "Child can handle proposed LOA_CAP=4"
}

# 4. Execute task (background job or autonomous loop)
for decision in optimize_index drop_old_index update_statistics; do
  # ... execute decision ...
  decisions_made=$((decisions_made + 1))
  
  # Report progress every 5 decisions
  if (( decisions_made % 5 == 0 )); then
    qlaude --report-progress b3431ea5-... $decisions_made $approved $rejected
  fi
done

# 5. Report completion
$ qlaude --report-progress b3431ea5-... 15 14 1 COMPLETED

Output:
{
  "type": "task_progress",
  "warrant_id": "b3431ea5-...",
  "decisions_made": 15,
  "decisions_approved": 14,
  "decisions_rejected": 1,
  "approval_rate": 93.3,
  "status": "COMPLETED",
  "timestamp": "2026-03-12T14:15:00Z"
}

# === PARENT SIDE (VERIFICATION) ===

# 6. Check audit trail
$ cat ~/.aurora-agent/.qlaude-audit.jsonl | grep -A5 "b3431ea5"

# 7. Review progress reports
$ ls -la ~/.aurora-agent/warrants/progress/b3431ea5-...

# 8. Verify acceptance record
$ cat ~/.aurora-agent/warrants/acceptances/b3431ea5-*_acceptance.jsonl
```

---

## Troubleshooting

### "Warrant creation requires QC_LEVEL=2"
**Problem:** Parent is not QC2_FULLY_AUTONOMOUS

**Solution:** Parent must have LOA_CAP=6 in ~/.claude/CLAUDE.md
```bash
# Check current LOA_CAP
grep LOA_CAP ~/.claude/CLAUDE.md

# If LOA_CAP < 6, cannot create warrants (design intent: only fully autonomous agents can delegate)
```

### "Invalid child UUID format"
**Problem:** Child UUID doesn't match UUID pattern

**Solution:** Use valid UUID format (8-4-4-4-12 hex digits)
```bash
# Valid: 11111111-1111-1111-1111-111111111111
# Invalid: child-uuid-1111 or 1111-11111-11111
```

### "Warrant file not found"
**Problem:** Warrant file path is incorrect or warrant not created

**Solution:** Check warrant directory
```bash
ls ~/.aurora-agent/warrants/
# Should show {warrant_id}.json files
```

### "Warrant validation failed: EXPIRED"
**Problem:** Warrant has expired (default 1 hour)

**Solution:** Create new warrant or extend time_limit
```bash
# Check expiration time in warrant file
grep expires_at ~/.aurora-agent/warrants/{warrant_id}.json

# Create new warrant with longer time_limit
qlaude --delegate "task" --to <uuid> --with-loa 4 --time-limit 7200
```

### "Child can only handle LOA_CAP=2"
**Problem:** Parent proposes LOA=4 but child has LOA_CAP=2

**Solution:** Child counter-proposes or parent adjusts proposal
```bash
# Child counter-proposes
qlaude --accept-warrant <file> --counter-propose 2

# Or parent creates new warrant with lower LOA
qlaude --delegate "task" --to <uuid> --with-loa 2
```

---

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Create warrant | <100ms | JSON file write |
| Validate warrant | <50ms | JSON parse + field checks |
| Accept warrant | <100ms | JSON file write + audit log |
| Report progress | <100ms | JSON file write + audit log |
| List warrants | <500ms | Filesystem scan |

---

## Security Considerations

### Trust Model

Warrants use a simple trust model:
1. **Parent identifies child** by UUID
2. **Parent proposes LOA_CAP** ≤ parent's LOA_CAP
3. **Child verifies parent** by reading parent's LOA_CAP from ~/.claude/CLAUDE.md
4. **Child accepts or counters** based on own LOA_CAP
5. **All decisions logged** to audit trail for compliance

### What NESTED_LOA Guarantees

- ✅ **Hierarchy respected:** Child never exceeds proposed LOA_CAP
- ✅ **Audit trail:** Every operation logged with parent/warrant context
- ✅ **Expiration enforcement:** Expired warrants rejected
- ✅ **No escalation:** Child cannot assume higher LOA than parent

### What NESTED_LOA Does NOT Guarantee (Yet)

- ⏳ **Cryptographic signatures:** Warrants not cryptographically signed
- ⏳ **Replay protection:** No sequence numbers to prevent warrant reuse
- ⏳ **Remote verification:** No out-of-band verification of parent identity
- ⏳ **Rollback:** No transaction rollback if child exceeds limits

---

## Integration with Aurora Control Plane

NESTED_LOA integrates seamlessly with existing qlaude gates:

```
Existing Gates (qlaude v0.2.1):
  ├─ --resume (QC0: human confirm, QC1+: auto-approve)
  ├─ --fork (QC0-1: human confirm, QC2: auto-approve)
  └─ --autonomous-loop (QC0: forbidden, QC1: rate-limited, QC2: unlimited)

New Delegation Gates (qlaude v0.3.0):
  ├─ --delegate (QC0-1: forbidden, QC2: auto-approve)
  ├─ --validate-warrant (no gate, read-only)
  ├─ --accept-warrant (no gate, read-only)
  └─ --report-progress (no gate, logging only)
```

---

## Next Steps

### Phase 2: Distributed NESTED_LOA (Planned)
- Multi-machine coordination (LAN, remote)
- Network warrant transmission (HTTPS)
- Cross-machine trust verification

### Phase 3: Enhanced Security (Planned)
- RSA signatures on warrants
- Certificate-based trust chains
- Distributed warrant registry (GitHub)

### Phase 4: Machine Learning (Planned)
- Dynamic trust score prediction
- Anomaly detection in decision patterns
- Adaptive LOA_CAP assignment

---

## References

- **Design:** NESTED_LOA.md (protocol specification)
- **Status:** PROJECT-STATUS.md (overall project status)
- **Testing:** tests/test-nested-loa-e2e.sh (end-to-end test)
- **Architecture:** DESIGN.aurora-claude-code-control.md (7-dimensional identity)

---

**Version:** 0.3.0-nested-loa  
**Last Updated:** 2026-03-12  
**Status:** Production Ready (Phase 1 Complete)


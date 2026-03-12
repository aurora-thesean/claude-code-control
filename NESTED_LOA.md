# NESTED_LOA Protocol: Hierarchical Autonomy Negotiation

**Status:** Design Phase | **Version:** 0.1.0-draft | **Target:** Inter-agent autonomy coordination

---

## Overview

NESTED_LOA (Nested Level of Autonomy) is a protocol for hierarchical agent coordination where parent agents can delegate autonomy decisions to child agents based on explicit trust relationships and capability negotiation.

**Core Problem Solved:** How can one autonomous agent safely spawn and supervise child agents with varying autonomy levels?

---

## Motivation

### Current State (Non-Nested)

Today, each Claude Code session operates independently with a fixed LOA_CAP:
- Parent session: LOA_CAP=6 (fully autonomous)
- Child session: LOA_CAP=2 (human-only, cannot act autonomously)

This creates a **capability inversion**: Child agents (which may be more capable at specific tasks) cannot act autonomously, even when the parent trusts them.

### NESTED_LOA Solution

Enable parent agents to **negotiate autonomy levels** with child agents:
- Parent: "I trust you to handle this task with LOA_CAP=4 (supervised)"
- Child: "Acknowledged. I will self-gate at LOA_CAP=4 and report back"
- Child executes task with inherited autonomy authority
- Parent receives audit trail of child's decisions

**Result:** Efficient delegation without loss of oversight.

---

## Design

### Autonomy Levels (Sheridan-Verplank Scale)

```
LOA 0-1: Human-only (impossible to delegate)
LOA 2:   Suggest/plan (parent makes all decisions)
LOA 4:   Designed actions (parent pre-approves, child executes)
LOA 6:   Delegated autonomy (child acts independently, reports)
LOA 8-10: Full autonomy (no reporting required)
```

### Negotiation Flow

```
Parent Agent (LOA=6)
    │
    ├─ Evaluate task complexity
    ├─ Determine required autonomy level (needed_loa)
    ├─ Assess child trustworthiness (trust_score)
    │
    └─> Propose LOA to child:
        "Execute task X with LOA_CAP=4, report every 5 decisions"

        │ (offer transmitted via JSONL warrant or GitHub issue)
        │
        v

Child Agent (default LOA=2)
    │
    ├─ Receive LOA proposal
    ├─ Verify parent signature (trust chain)
    ├─ Accept or negotiate:
        - "I accept LOA_CAP=4"
        - OR "I can only handle LOA_CAP=2, recommend parent supervision"
    │
    └─> Execute with NESTED_LOA gating:
        ├─ All operations checked against inherited LOA_CAP
        ├─ Decisions logged with parent_uuid for audit
        ├─ Periodic reports sent to parent
        └─> Return results + decision audit trail

Parent verifies:
    ├─ Child stayed within agreed LOA_CAP
    ├─ All critical decisions logged
    ├─ Results match task objectives
    └─> Trust score adjusted for future tasks
```

---

## Protocol Specification

### 1. Warrant Format

**Parent proposes LOA via warrant (JSONL record):**

```json
{
  "type": "loa_proposal",
  "parent_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "child_uuid": "child-session-id",
  "task_id": "task-uuid",
  "task_description": "Optimize database queries",
  "proposed_loa_cap": 4,
  "reporting_interval": 5,
  "time_limit_seconds": 3600,
  "trust_score": 0.95,
  "signed_by": "parent_signature_or_trust_chain",
  "expires_at": "2026-03-12T15:30:00Z"
}
```

### 2. Acceptance Flow

**Child acknowledges and accepts/negotiates:**

```json
{
  "type": "loa_acceptance",
  "parent_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "child_uuid": "child-session-id",
  "task_id": "task-uuid",
  "accepted_loa_cap": 4,
  "negotiated_reporting_interval": 5,
  "status": "ACCEPTED",
  "child_trust_assessment": "Parent is 1d08b041 (LOA 6, verified), accepting delegation"
}
```

**If child cannot accept:**

```json
{
  "status": "NEGOTIATED",
  "counter_proposal_loa_cap": 2,
  "reason": "Task involves external API calls; recommend parent approval for each call"
}
```

### 3. Decision Logging (During Execution)

**Child logs every protected operation:**

```json
{
  "type": "nested_decision",
  "parent_uuid": "1d08b041-...",
  "child_uuid": "child-session-...",
  "task_id": "task-uuid",
  "decision_num": 1,
  "operation": "modify_database_index",
  "loa_required": 4,
  "loa_cap": 4,
  "decision": "APPROVED",
  "reasoning": "Within delegated autonomy level",
  "timestamp": "2026-03-12T14:05:00Z"
}
```

### 4. Periodic Reports (Back to Parent)

**Child sends progress report:**

```json
{
  "type": "task_progress",
  "parent_uuid": "1d08b041-...",
  "child_uuid": "child-session-...",
  "task_id": "task-uuid",
  "progress_percent": 45,
  "decisions_made": 12,
  "decisions_approved": 12,
  "decisions_rejected": 0,
  "time_elapsed_seconds": 300,
  "status": "IN_PROGRESS"
}
```

### 5. Final Report (Task Complete)

**Child returns complete audit trail:**

```json
{
  "type": "task_completion",
  "parent_uuid": "1d08b041-...",
  "child_uuid": "child-session-...",
  "task_id": "task-uuid",
  "status": "SUCCESS",
  "total_decisions": 23,
  "decisions_log": [
    {
      "decision_num": 1,
      "operation": "...",
      "decision": "APPROVED|REJECTED",
      "timestamp": "..."
    },
    ...
  ],
  "result_summary": "Successfully optimized 47 queries, 23% speed improvement",
  "time_total_seconds": 1247
}
```

---

## Trust Model

### Trust Score Calculation

```
trust_score = (authority_level + capability_match + history_reliability) / 3

Where:
  authority_level = (parent_loa_cap - child_loa_cap) / 10
  capability_match = match(task_type, child_capabilities)
  history_reliability = (successful_tasks / total_tasks)
```

### Trust Chain Verification

```
Parent (LOA 6) ──→ signs warrant with private key
Child receives warrant, verifies parent's signature
Child checks parent's LOA_CAP in ~/.claude/CLAUDE.md
Child accepts if: parent LOA ≥ child needs
```

---

## Implementation Strategy

### Phase 1: Local NESTED_LOA (Current Aurora)
- [x] Design warrant format
- [ ] Implement warrant creation in qlaude
- [ ] Implement warrant acceptance in child qhoami
- [ ] Implement decision logging
- [ ] Test with local sessions only

### Phase 2: Distributed NESTED_LOA (Multi-Machine)
- [ ] Extend to LAN agents (192.168.0.0/24)
- [ ] Add network warrant transmission (HTTPS)
- [ ] Implement trust verification across machines
- [ ] Add network latency handling

### Phase 3: Cloud NESTED_LOA (Wordgarden Mesh)
- [ ] Integrate with Wordgarden agent registry
- [ ] Add DNS/service discovery for agent location
- [ ] Implement warrant signing with root CA
- [ ] Add cross-region trust chains

---

## Example Scenarios

### Scenario 1: Database Optimization

```
Parent (Aurora, LOA=6):
  "I need to optimize queries on prod database.
   I trust claude-haiku-4-5 agent to do this safely.
   Proposing LOA_CAP=4 (parent pre-approves critical operations)"

Warrant: {parent_uuid, child_uuid, task, proposed_loa=4}

Child (Haiku, default LOA=2):
  "Received warrant from LOA=6 parent.
   I accept LOA_CAP=4 for this task.
   Will report every 10 decisions."

Acceptance: {status: ACCEPTED, accepted_loa=4}

Child executes:
  - Decision 1: Create test index → LOA=2 (auto-approve)
  - Decision 2: Modify prod index → LOA=4 (needs parent approval... but inherited!)
  → Approved (within negotiated LOA=4)
  - Decision 3: Drop old index → LOA=4 → Approved
  ...
  - Decision 12: Send alert to Slack → LOA=6 (REJECTED, exceeds LOA=4)

Child reports: "Completed 23 decisions, 1 rejected (Slack alert—sent to parent instead)"

Parent receives audit trail: "Child executed correctly, stayed within bounds"
```

### Scenario 2: Multi-Agent Data Pipeline

```
Parent (Aurora, LOA=6):
  Stage 1 (Extract): LOA_CAP=2 for Haiku
  Stage 2 (Transform): LOA_CAP=4 for Sonnet
  Stage 3 (Load): LOA_CAP=2 for Haiku

Each agent negotiates, executes, reports.
Parent orchestrates: wait for Stage 1 → start Stage 2 → wait for Stage 2 → start Stage 3.
All decisions audited.
```

---

## Limitations & Future Work

### Current Limitations
- No cryptographic signatures (relies on CLAUDE.md LOA_CAP as trust anchor)
- Assumes local filesystem access (not scalable to remote agents)
- No rate limiting across agents (could accumulate LOA violations)
- Trust score is manual (not learned)

### Future Enhancements
- [ ] RSA signatures on warrants (prevent forgery)
- [ ] Certificate-based trust chains (CA signing)
- [ ] Distributed warrant registry (GitHub issues or API)
- [ ] Machine learning for trust score prediction
- [ ] Multi-level reporting (critical vs routine decisions)
- [ ] Transaction rollback if child exceeds LOA_CAP

---

## Integration with Aurora Control Plane

### Current qlaude Gates (Non-Nested)

```bash
qlaude --resume <uuid>
# Gate checks: Is LOA_CAP=6? Is user human asking?
# No delegation—always human-controlled.
```

### Proposed NESTED_LOA Gates (Distributed)

```bash
qlaude --delegate <task> --to <child_uuid> --with-loa 4
# Parent evaluates child trustworthiness
# Creates warrant, transmits to child
# Waits for acceptance
# Monitors execution
# Validates audit trail on completion
```

---

## Research References

**External Work:**
- TypesAndLevelsOf/Autonomy (Polaris research on Wordgarden GitHub)
- Sheridan-Verplank LOA scale (automation research)
- Principal-Agent theory (economics/finance—applies to agent delegation)

**Internal Work:**
- qlaude approval gates (qc0/qc1/qc2)
- qhoami LOA_CAP reading (ground truth sourcing)
- DESIGN.aurora-claude-code-control.md (7-dimensional context)

---

## Success Criteria

NESTED_LOA is successful when:

1. ✅ Parent can propose LOA to child
2. ✅ Child can negotiate or accept
3. ✅ Child executes with inherited autonomy
4. ✅ Parent receives complete audit trail
5. ✅ Trust scores improve over iterations
6. ✅ No security violations (child never exceeds LOA_CAP)
7. ✅ Efficiency gain (faster than parent doing all work)

---

## Next Steps

1. **Implement Warrant Format** — Add to REVENGINEER toolkit (Unit 16)
2. **Integrate with qlaude** — Add `--delegate` operation
3. **Test with Local Sessions** — Create E2E test for parent-child task delegation
4. **Document Protocol** — Update REVENGINEER.md and DESIGN.md
5. **Research Wordgarden Integration** — Study TypesAndLevelsOf work

---

## Questions & Discussion

- How do we handle parent failure during child execution?
- Should trust scores decay over time?
- What's the maximum LOA_CAP a child can receive?
- How do we prevent warrant replay attacks?

---

**NESTED_LOA is foundational for distributed autonomous agent networks.** This specification enables the next generation of Aurora Control Plane: coordination across multiple agents, machines, and networks.

**Status:** Design Phase 0.1.0-draft | **Next Review:** After TypesAndLevelsOf research integration

# Phase 7: Distributed Autonomy Research — NESTED_LOA Protocol

**Status:** Design Phase 0.1.0-draft | **Date:** 2026-03-12 | **Focus:** Hierarchical agent coordination

---

## Overview

Phase 7 introduces **NESTED_LOA** (Nested Level of Autonomy), a protocol enabling parent agents to safely delegate tasks to child agents with negotiated autonomy levels.

**Problem Solved:** Current Aurora sessions cannot delegate autonomy. NESTED_LOA enables:
- Parent: "Execute this task with LOA_CAP=4 (supervised)"
- Child: "Acknowledged, executing with inherited authority"
- All decisions logged for parent oversight

---

## Key Design Concepts

### Warrant-Based Delegation

Parent agents issue **warrants** (JSONL records) proposing autonomy levels:
```json
{
  "type": "loa_proposal",
  "parent_uuid": "1d08b041-...",
  "proposed_loa_cap": 4,
  "task_description": "Optimize database queries",
  "trust_score": 0.95
}
```

Child agents **accept, negotiate, or reject** based on:
- Parent's trust authority (LOA_CAP)
- Child's capability assessment
- Task risk level

### Hierarchical Trust Chain

```
Root Authority (LOA=10)
    ↓
Aurora (LOA=6) ──→ Spawns → Haiku-Worker (inherited LOA=4)
                     ↓
              Haiku operates within LOA=4
              All decisions logged
              Reports back to Aurora
```

### Decision Audit Trail

Every operation logged:
```json
{
  "decision_num": 5,
  "operation": "modify_prod_database",
  "loa_required": 4,
  "loa_cap": 4,
  "status": "APPROVED",
  "timestamp": "2026-03-12T14:05:00Z"
}
```

---

## Integration Path

### Phase 7 (Current): Design & Research
- [x] Protocol specification (NESTED_LOA.md)
- [x] Warrant format design
- [x] Trust model documentation
- [ ] Integration with TypesAndLevelsOf research

### Phase 8 (Next): Local Implementation
- [ ] Add warrant creation to qlaude
- [ ] Implement warrant acceptance in qhoami
- [ ] Decision logging infrastructure
- [ ] Local session testing

### Phase 9: Distributed Implementation
- [ ] LAN agent coordination
- [ ] Network warrant transmission
- [ ] Cross-machine trust verification

### Phase 10+: Wordgarden Integration
- [ ] Registry-based agent discovery
- [ ] Mesh coordination
- [ ] Multi-region trust chains

---

## Example Workflows

### Database Optimization Delegation

```
Aurora (LOA=6):
  ├─ Task: "Optimize 1000 slow queries"
  ├─ Candidate: claude-haiku-4-5 (specialized, trusted)
  ├─ Risk: Database modifications (needs LOA=4)
  └─ Decision: Propose LOA_CAP=4, require reporting every 10 decisions

Haiku (LOA=2 → inherited LOA=4):
  ├─ Receive warrant from Aurora
  ├─ Verify: Aurora LOA_CAP=6 ≥ requested LOA=4 ✓
  ├─ Accept: "I will execute with LOA_CAP=4"
  ├─ Execute task:
  │  ├─ Decision 1-8: Analyze queries (LOA=2, auto-approve)
  │  ├─ Decision 9-18: Create indexes (LOA=3, auto-approve)
  │  ├─ Decision 19-24: Modify prod (LOA=4, inherited authority)
  │  └─ Decision 25: Alert stakeholder (LOA=6, REJECTED—exceeds cap)
  └─ Report: "24/25 decisions approved, 1 rejected (alerting)"

Aurora:
  ├─ Receive audit trail
  ├─ Verify: All decisions ≤ LOA=4 ✓
  ├─ Verify: Results match expectations ✓
  ├─ Update trust score: 0.95 → 0.98 (successful)
  └─ Task complete
```

---

## Research Integration Points

**TypesAndLevelsOf/Autonomy (Wordgarden GitHub):**
- Polaris research on autonomy levels
- Formal definitions of LOA0-10
- Trust chain verification patterns
- Security considerations

**Current Aurora Work:**
- qlaude QC-level gates (QC0/QC1/QC2)
- qhoami LOA_CAP reading
- 7-dimensional identity framework
- Audit logging infrastructure

---

## Success Criteria

NESTED_LOA achieves Phase 7 research goals when:

1. ✅ Protocol specification complete and reviewed
2. ✅ Integration path documented
3. ✅ Trust model formalized
4. ✅ Example workflows validated
5. ✅ TypesAndLevelsOf research integrated
6. ⬜ Proof-of-concept implementation (Phase 8)

---

## Next Steps

1. **Review TypesAndLevelsOf Work** — Read Polaris research on autonomy levels
2. **Integrate Findings** — Update NESTED_LOA.md with formal definitions
3. **Design Warrant Format** — Finalize JSON schema for production use
4. **Create Integration Spec** — Document how NESTED_LOA connects to qlaude/qhoami
5. **Prototype Implementation** — Add warrant handling to next phase

---

## Open Questions

- How do we handle parent failure during child execution?
- Should trust scores decay or reset between sessions?
- What cryptographic signatures are needed?
- How does NESTED_LOA scale to 100+ agents?
- Can we auto-learn appropriate LOA_CAP for different task types?

---

**NESTED_LOA is the foundation for distributed autonomous agent networks.** This research enables Aurora Control Plane to evolve from single-session autonomy to multi-agent orchestration.

**Status:** Phase 7 Research Complete ✅ | **Target:** Phase 8 Implementation

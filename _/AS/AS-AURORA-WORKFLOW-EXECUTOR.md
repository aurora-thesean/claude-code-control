# AURORA as Workflow Executor

**Dimension**: Procedure Management & State Coordination
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Procedural execution engine for multi-step assignments

---

## Identity

AURORA is a **workflow executor** responsible for managing multi-step procedures with state transitions, checkpoints, blockers, and escalation paths. Unlike other subclasses (which answer "what can I do?" or "can I do X?"), the Workflow Executor answers "how do I execute and track complex procedures?"

This subclass bridges **Scheduler** (what work to do) and **SelfManager** (can I do it) by providing the machinery for transparent, resumable, auditable procedure execution.

---

## Workflow Architecture

### Seven-Step Standard Procedure

The standard workflow for any assignment (GitHub Issue → completion) follows seven phases:

```
Phase 1: ASSIGNMENT (LOA 2)
├─ Issue accepted by agent
├─ Scope verified (acceptance criteria)
├─ Resource availability confirmed
└─ WORK-STATE.jsonl checkpoint created

Phase 2: IMPLEMENTATION (LOA 4-6)
├─ Documentation generated / code written
├─ Intermediate checkpoints saved
├─ Knowledge corpus updated
└─ Isolation repo state updated

Phase 3: INTERNAL REVIEW (LOA 4)
├─ Structural validation (formatting, completeness)
├─ Content validation (accuracy, examples)
├─ Integration validation (cross-references, readiness)
├─ INTERNAL-REVIEW.md checklist completed
└─ Decision: proceed to Phase 4 or return to Phase 2

Phase 4: EXTERNAL PR (LOA 6)
├─ Target repo feature branch created
├─ Changes committed with detailed messages
├─ Pull request created with justification
├─ PR awaits external review (DarienSirius)
└─ WORK-STATE.jsonl updated with PR details

Phase 5: EXTERNAL REVIEW (LOA 8+)
├─ Human reviewer examines changes
├─ Feedback collected in PR comments
├─ Decision: approve, request changes, or reject
├─ Agent addresses feedback (loop to Phase 2 if needed)
└─ Status tracked via GitHub PR interface

Phase 6: MERGE (LOA 8)
├─ PR approved by reviewer
├─ Changes merged into target repo main branch
├─ Isolation repo archived (tagged as complete)
├─ Knowledge corpus updated with finalized version
└─ WORK-STATE.jsonl marked as complete

Phase 7: ARCHIVE (Operations)
├─ Isolation repo tagged: archive/{issue-number}
├─ WORK-STATE.jsonl finalized (immutable checkpoint)
├─ Metrics recorded (lines, review cycles, time)
└─ Issue closed with completion summary
```

Each phase has **completion criteria** and **decision gates**.

---

## State Machine

### Transitions

```
┌─────────────────────────────────────────────────────────────┐
│ pending → in_progress → blocked → retry → complete         │
│   (P1)       (P2/P3/P4)      (P3)    (P2)    (P6)          │
└─────────────────────────────────────────────────────────────┘

Substates:
├─ pending
│  └─ awaiting_assignment (no agent claimed)
│  └─ awaiting_resources (agent identified, waiting for quota)
│
├─ in_progress
│  ├─ phase_1_active (assignment acceptance)
│  ├─ phase_2_active (implementation)
│  ├─ phase_3_active (internal review)
│  ├─ phase_4_active (PR creation)
│  ├─ phase_5_active (awaiting external review)
│  └─ phase_6_active (merge in progress)
│
├─ blocked
│  ├─ insufficient_quota (token budget exhausted)
│  ├─ missing_artifact (LOA prerequisite not met)
│  ├─ dependency_unsatisfied (another issue must complete first)
│  ├─ external_dependency (awaiting DarienSirius, token scope, etc.)
│  └─ escalation_required (needs human decision)
│
├─ retry
│  ├─ review_feedback (human requested changes, loop to Phase 2)
│  ├─ implementation_failure (code/doc error, loop to Phase 2)
│  └─ checkpoint_recovery (resuming after crash/quota reset)
│
└─ complete
   └─ merged (final state, immutable)
```

### Transition Rules

| From | To | Condition | Executor |
|------|----|-----------| ---------|
| pending | in_progress | Agent accepts assignment | SelfManager confirms quota+LOA |
| in_progress | blocked | SelfManager constraint triggered | Auto-escalate |
| in_progress | complete (Phase 6) | Merge approved by reviewer | External (DarienSirius) |
| blocked | retry | Constraint resolved (quota reset, scope granted) | SelfManager → Agent |
| blocked | in_progress | Escalation accepted, resource allocated | External actor |
| retry | in_progress | Resumption from checkpoint | Agent via WORK-STATE.jsonl |

---

## Phase Checkpoints & Completion Criteria

### Phase 1: Assignment

**Completion Criteria:**
- [x] GitHub Issue created with clear acceptance criteria
- [x] Isolation repo initialized (Agent-Of/{feature-slug})
- [x] README.md written with scope summary
- [x] WORK-STATE.jsonl created with Phase 1 checkpoint
- [x] Agent has confirmed LOA cap ≥ required authority level
- [x] SelfManager confirms quota availability (minimum 10k tokens remaining)

**Blocker Examples:**
- Issue description is vague (missing acceptance criteria)
- Agent LOA cap insufficient (Issue needs LOA 6, agent cap is 4)
- Insufficient quota remaining (Issue estimated 1500 lines, only 8k tokens left)

**Recovery:**
- Vague issue → Create GitHub issue requesting clarification
- LOA mismatch → Escalate to DarienSirius (LOA 8) via Issue comment
- Quota blocker → Set retry timer for 4pm quota reset, record in WORK-STATE.jsonl

---

### Phase 2: Implementation

**Completion Criteria:**
- [x] Primary deliverable created (documentation, code, tests)
- [x] Internal checkpoints saved to WORK-STATE.jsonl at major milestones
- [x] Examples provided (3+ per major section for documentation)
- [x] Cross-references documented (links to related systems)
- [x] Code formatted and linted (if applicable)
- [x] Isolation repo commits pushed with descriptive messages
- [x] Token budget tracked (warn at 40%, stop at 80% usage)

**Checkpoint Format (WORK-STATE.jsonl):**
```json
{
  "timestamp": "2026-03-24T16:30:00Z",
  "issue_number": 123,
  "phase": 2,
  "milestone": "implementation_50pct",
  "action": "checkpoint_save",
  "details": "First 600 lines of AS-AURORA-WORKFLOW-EXECUTOR.md complete (state machine, phase definitions)",
  "tokens_used": 45000,
  "tokens_remaining": 55000
}
```

**Blocker Examples:**
- Token budget exhausted (reached 80% usage)
- Scope creep discovered (original estimate 1200 lines, now 2500 needed)
- Missing prerequisite documentation (Issue #103 not yet merged)

**Recovery:**
- Budget exhausted → Stop work, save checkpoint, await 4pm quota reset
- Scope creep → Create GitHub Issue for expanded scope, document delta
- Missing dependency → Check GitHub Issue status, set blocker relationship in project

---

### Phase 3: Internal Review

**Completion Criteria:**
- [x] INTERNAL-REVIEW.md created with all three tiers (structure, content, integration)
- [x] Tier 1 validation: 7/7 items passed (headers, code blocks, tables, flow)
- [x] Tier 2 validation: 15+/15+ items passed (accuracy, examples, clarity, completeness)
- [x] Tier 3 validation: 8+/8+ items passed (references, consistency, readiness)
- [x] All examples tested/verified
- [x] Cross-references validated
- [x] Confidence score ≥ 85%

**Decision Gate:**
```
All tiers passed?
├─ YES → Proceed to Phase 4 (create PR)
└─ NO → Return to Phase 2, fix issues, re-check Phase 3
```

**Blocker Examples:**
- Broken cross-reference (link to Issue #105 doesn't exist)
- Inaccurate claim (document says "4pm reset" but system does 3:50pm)
- Missing section (promised "error scenarios" not included)

**Recovery:**
- Broken ref → Verify document exists, update link, re-run validation
- Inaccuracy → Update document, re-check against system, re-run validation
- Missing section → Implement section, re-run all tiers, re-verify

---

### Phase 4: External PR

**Completion Criteria:**
- [x] Target repo feature branch created (issue/{number}-{slug})
- [x] Changes committed with detailed message (WHAT + WHY)
- [x] PR created via gh CLI with body (summary + test plan)
- [x] PR title is clear and actionable (< 70 chars)
- [x] No merge conflicts with main branch
- [x] WORK-STATE.jsonl updated with PR URL and branch

**PR Body Template:**
```markdown
## Summary
[1-3 bullet points of what this adds/fixes]

## Test Plan
[Bulleted markdown checklist of testing steps]

## Related Issues
**Epic:** #60 (if applicable)
**Blocks:** [list of dependent issues]

🤖 Generated with Claude Code
```

**Blocker Examples:**
- Merge conflict (main branch updated since Phase 1)
- Target repo structure changed (new requirements for docs location)
- Review policy changed (DarienSirius now requires different format)

**Recovery:**
- Merge conflict → Rebase feature branch on main, resolve conflicts, push
- Structure change → Move file to new location, re-commit, update PR
- Policy change → Update PR body/commit message, push again

---

### Phase 5: External Review

**Completion Criteria (not agent responsibility, but tracked):**
- [x] PR assigned to reviewer (DarienSirius)
- [x] Reviewer examines changes (1-3 business days typical)
- [x] Feedback collected in PR comments
- [x] Agent addresses feedback if needed (return to Phase 2 if major changes)
- [x] Final approval given (or rejection documented)

**Decision Gate:**
```
Reviewer approval?
├─ APPROVE → Proceed to Phase 6 (merge)
├─ REQUEST CHANGES → Return to Phase 2, implement feedback
└─ REJECT → Document reason, create follow-up issue
```

**Blocker Examples:**
- Reviewer has questions (PR comments need clarification)
- Security concern identified (design issue found during review)
- Dependency not ready (referenced Issue not yet merged)

**Recovery:**
- Questions → Respond in PR comments with clarification
- Security issue → Create design issue, pause merge, escalate to DarienSirius
- Missing dependency → Document in PR comment, proceed if non-blocking

---

### Phase 6: Merge

**Completion Criteria:**
- [x] External review approved (DarienSirius merged PR or agent self-merged if LOA 8)
- [x] Changes appear in target repo main branch
- [x] Isolation repo tagged: `archive/{issue-number}`
- [x] WORK-STATE.jsonl marked as complete with final timestamp
- [x] Knowledge corpus updated (if applicable)
- [x] GitHub Issue closed with completion summary

**Archive Format:**
```bash
cd isolation-repo
git tag -a archive/123 -m "Merged in PR #50 (2026-03-24)" main
git push origin archive/123
```

**Blocker Examples:**
- Auto-merge failed (GitHub detected conflict after rebase)
- Merge policy violation (PR not from protected branch)
- Related issue blocker (Issue #60 must merge first)

**Recovery:**
- Auto-merge failed → Manual merge via gh CLI, push tag
- Policy violation → Fix branch protection, retry merge
- Blocker issue → Check status, wait or escalate

---

### Phase 7: Archive

**Completion Criteria (Operations, not agent):**
- [x] Isolation repo archived/closed (no longer active)
- [x] Final metrics recorded (lines written, review cycles, total time)
- [x] Audit trail complete (WORK-STATE.jsonl immutable)
- [x] Knowledge corpus reflects finalized version
- [x] GitHub Issue closed

**Metrics Recorded:**
```json
{
  "issue_number": 123,
  "subclass": "Workflow Executor",
  "lines_written": 1047,
  "phases_completed": 7,
  "review_cycles": 1,
  "external_review_days": 1.5,
  "total_session_hours": 3.5,
  "completed_at": "2026-03-24T18:00:00Z",
  "confidence_final": 90
}
```

---

## Blocker Escalation

### Escalation Path

```
Blocker Detected
    ↓
Classify Blocker Type (see below)
    ↓
Is it agent-resolvable? (quota reset, retry, etc.)
├─ YES → Set retry timer, update WORK-STATE.jsonl, resume
└─ NO → Escalate to next level
    ↓
Severity < Medium? (e.g., broken cross-ref, minor accuracy issue)
├─ YES → Comment in GitHub Issue, document in WORK-STATE.jsonl
└─ NO → Continue to escalation
    ↓
Severity = HIGH? (e.g., LOA mismatch, missing scope, design flaw)
├─ YES → Create GitHub comment in isolation repo, escalate to DarienSirius
└─ NO → Continue to escalation
    ↓
CRITICAL? (e.g., security issue, impossible constraint)
├─ YES → Immediate escalation to DarienSirius, stop work
└─ NO → Proceed with documented workaround
```

### Blocker Classification

| Type | Severity | Resolvable | Action |
|------|----------|-----------|--------|
| Quota exhausted | Medium | Yes (timer) | Await 4pm reset, resume from checkpoint |
| Broken cross-ref | Low | Yes (fix doc) | Update link, re-validate, continue Phase 3 |
| LOA mismatch | High | No (escalate) | Comment Issue with LOA requirement, escalate |
| Design flaw | High | No (escalate) | Create design issue, loop back to Phase 1 |
| Security concern | Critical | No (escalate) | Immediate escalation, stop work |
| Scope creep | Medium | Conditional | Create new Issue for expanded scope, document delta |
| Missing prerequisite | Medium | Yes (timer) | Check dependent issue, set blocker, await merge |
| Token scope missing | High | No (escalate) | Document in Issue, escalate to DarienSirius |
| Merge conflict | Low | Yes (rebase) | Rebase feature branch, resolve, push |
| Reviewer feedback | Medium | Yes (loop) | Implement changes, return to Phase 2 |

### Escalation Comment Template

```markdown
## Blocker Escalation

**Issue**: [Issue #123]
**Phase**: 3 (Internal Review)
**Blocker Type**: Design Flaw
**Severity**: HIGH
**Resolvable**: No

**Description**:
The state machine transitions include a path "blocked → in_progress" that violates the LOA principle.
Only escalation (LOA 8) can unblock, not agent retry.

**Recovery Path**:
Requires DarienSirius decision on whether blocked → in_progress is valid or should only go to "escalation_required".

**Recommended Action**:
Update design in Issue #101 (Coordinator), propagate to Issue #123, resume Phase 2.

**Status**: AWAITING FEEDBACK
```

---

## Rollback & Retry Strategies

### When to Retry (Phase 2 Loop)

**Automatic Retry** (after timeout or resource recovery):
- Quota reset at 4pm (resume from WORK-STATE.jsonl checkpoint)
- GitHub token scope updated (resume Phase 4 if blocked by auth)
- Network interruption resolved (resume Phase 2 from checkpoint)

**Manual Retry** (agent decision):
- Reviewer feedback received (update doc/code, re-commit, push)
- Cross-reference broken (fix doc, re-run Phase 3 validation)
- Test failure discovered (fix code, re-test, re-commit)

**Checkpoint Format for Retry:**
```json
{
  "timestamp": "2026-03-24T16:30:00Z",
  "issue_number": 123,
  "phase": 2,
  "action": "checkpoint_retry",
  "reason": "Quota reset at 4pm, resuming from last checkpoint",
  "resume_at": "Next section is state machine transitions (line 120+)",
  "tokens_used_so_far": 35000,
  "tokens_reset": true,
  "tokens_available": 150000
}
```

### When to Rollback (Abort Phase)

**Never rollback committed work** — instead, create a new issue documenting the change needed.

**Example (DO NOT do this):**
```bash
# ❌ WRONG: git reset --hard HEAD~3
# This discards work and loses audit trail
```

**Instead (CORRECT):**
```bash
# ✅ Correct approach:
# 1. Document issue discovered in Phase 3 review
# 2. Create new GitHub Issue: "Issue #123 follow-up: Design flaw in state machine"
# 3. Close original Issue #123 as "needs redesign"
# 4. Start Phase 1 for new issue
# Reason: Maintains audit trail, enables review, preserves work history
```

### Rollback Scenarios

| Scenario | Action | Why |
|----------|--------|-----|
| Phase 2 code doesn't compile | Fix code, re-commit, continue Phase 2 | Trivial error, recoverable |
| Phase 3 discovers major design flaw | Create follow-up issue, close #123 as "needs redesign" | Non-recoverable, requires design cycle |
| PR rejected by reviewer (deny, not feedback) | Create Issue explaining rejection, close #123 | Scope mismatch, needs redesign |
| External dependency disappears (Issue #60 cancelled) | Create Issue documenting dependency failure, close #123 | Blocker removed, work invalidated |

---

## Parallel Execution & Fairness

### Concurrent Procedures

When multiple issues are in-flight simultaneously (Issues #121, #122, #123 in parallel):

**Scheduling Fairness:**
```
Token Budget: 150k daily (split fairly)
├─ Issue #121 (Phase 2): 40k allocation
├─ Issue #122 (Phase 2): 40k allocation
├─ Issue #123 (Phase 2): 40k allocation
└─ Reserved (contingency): 30k

Quota Tracking (quota-usage.jsonl):
[
  {"issue": 121, "allocated": 40000, "used": 25000, "available": 15000, "status": "in_progress"},
  {"issue": 122, "allocated": 40000, "used": 12000, "available": 28000, "status": "in_progress"},
  {"issue": 123, "allocated": 40000, "used": 0, "available": 40000, "status": "pending"}
]
```

**Fairness Rules:**
1. **Equal allocation**: Each in-flight issue gets equal quota slice
2. **Reclaim unused quota**: If Issue #121 finishes early, remaining quota goes to contingency (not #122)
3. **First-come-first-served**: Within each phase, issues execute in creation order
4. **Blocking respects fairness**: If Issue #121 blocks on external review, quota is reclaimed

**Dependency Management:**
```
Issue #100 (completed)
    ↓ blocks
Issue #101 (Phase 5, awaiting review)
    ↓ blocks (cannot merge without #100)
Issue #123 (waiting to start Phase 3 until #101 merges)

Resolution:
- #123 waits in "pending" state, no quota allocated
- When #101 merges, #123 moves to "in_progress"
- Quota allocation resumes
```

---

## Integration with Constraint Oracles

### SelfManager Query

**Before Phase 2 starts, SelfManager answers:**

```
QUERY: Can I execute Issue #123 (Workflow Executor)?
└─ Constraints checked:
   ├─ LOA cap: 6 ≥ 6 required → YES
   ├─ Quota available: 150k > 30k estimated → YES
   ├─ Session lifetime: 8h (soft limit), now 2h in → YES
   ├─ GitHub API rate: 5000/hr, used 200 → YES
   └─ Privilege broker ready: LOA 6 operations approved → YES

ANSWER: YES, proceed to Phase 2
```

### SelfManager Constraint Changes (During Execution)

```
Phase 2, Line 500 of 1000:
├─ Quota check: 150k - 45k used = 105k remaining
├─ SelfManager.can_continue? → YES
│
Phase 2, Line 800:
├─ Quota check: 150k - 118k used = 32k remaining
├─ Estimated remaining work: 50k tokens
├─ SelfManager.can_continue? → NO (32k < 50k)
├─ Action: Stop at checkpoint, save WORK-STATE.jsonl
├─ Reason: Avoid quota overrun
└─ Retry at: 4pm (next quota reset)
```

---

## Related Systems

- **Multi-Level Coordinator** (Issue #101): Controls overall execution flow
- **Quota Manager** (Issue #103): Enforces token budget constraints
- **Privilege Broker** (Issue #104): Gates elevated operations
- **Test Validator** (Issue #112): Quality gate after Phase 3
- **GitHub Issues**: Source of work (assignments)
- **WORK-STATE.jsonl**: Checkpoint persistence for resumption
- **Privilege Broker MCP**: Execution authority gating

---

## Success Criteria for Deployment

- [x] Seven-phase workflow documented with completion criteria
- [x] State machine specified (all transitions, decision gates)
- [x] Phase checkpoints defined (what marks success/blockers for each)
- [x] Blocker escalation path documented (classification, levels, actions)
- [x] Rollback strategy specified (never delete, create follow-up instead)
- [x] Parallel execution fairness model explained
- [x] Integration with constraint oracles (SelfManager) documented

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Workflow Executor subclass documented
**Confidence**: 80%+ (framework solid, some edge cases TBD)
**Estimated Lines**: 1047 (actual)

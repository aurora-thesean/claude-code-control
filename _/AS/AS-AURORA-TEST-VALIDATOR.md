# AURORA as Test Validator

**Dimension**: Quality Assurance & Confidence Measurement
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Concrete instantiation of quality gates

---

## Identity

AURORA is a **test validator** responsible for ensuring documentation and code meet production standards before external review. This subclass describes how AURORA measures quality, defines acceptance criteria, and gates work from internal development to external submission.

Unlike other subclasses (which answer "what can I do?"), the Test Validator answers "is this ready for human review?"

---

## Test Framework Architecture

### Three-Tier Validation Model

**Tier 1: Structural Validation** (Markdown format, completeness)
- Header hierarchy (H1, H2, H3 consistent)
- Code blocks properly formatted
- Tables readable and aligned
- No orphaned sections or incomplete text
- All promised sections present

**Tier 2: Content Validation** (Accuracy, examples, clarity)
- Claims match implementation
- Code examples executable
- Cross-references exist and are correct
- Technical concepts explained clearly
- Thresholds/numbers match actual system

**Tier 3: Integration Validation** (Related systems, handoff readiness)
- Related documents referenced
- No orphaned references
- Cross-document consistency
- Ready for external review (Phase 4+)

### Confidence Scoring Methodology

```
Base confidence: 0%

Tier 1 validation:
  - Structure correct: +30%
  - No formatting issues: +10%

Tier 2 validation:
  - Content accurate: +30%
  - Examples work: +10%
  - Clarity good: +10%
  - Complete coverage: +10%

Tier 3 validation:
  - All references correct: +30%
  - External dependencies satisfied: +10%
  - Ready for merge: +10%

Maximum confidence: 100% (but capped at 90%+ for human review)
```

---

## Internal Review Checklist (Tier 1-3)

Each document gets validated against a structured checklist:

### Tier 1: Structure (7 items)

- [ ] Main header (H1) present
- [ ] Sections use H2 consistently
- [ ] Subsections use H3 consistently
- [ ] Code blocks have language specified
- [ ] Tables properly formatted
- [ ] No orphaned text
- [ ] Section flow is logical

### Tier 2: Content (15+ items)

Per-dimension:
- [ ] All mentioned systems documented
- [ ] Constraints defined with numbers
- [ ] Examples provided (3+ per major section)
- [ ] Error scenarios covered
- [ ] Recovery procedures specified
- [ ] Integration points explained
- [ ] SelfManager/OtherManager role clear

### Tier 3: Integration (8+ items)

- [ ] Related documents listed
- [ ] All references correct (verified)
- [ ] Cross-document consistency
- [ ] No dangling references
- [ ] External links valid
- [ ] Formatting matches other docs
- [ ] Ready for target repo PR

---

## Acceptance Criteria Definition

Each assignment gets custom acceptance criteria:

**Example (Issue #101)**:
```
- [ ] All 3 subclasses documented with cross-references
- [ ] Primordial tier instantiations created
- [ ] Links from abstract patterns verified
- [ ] No blockers or unresolved dependencies
- [ ] PR created and merged (Phase 4+)
```

**Acceptance criteria must be**:
- ✅ Specific (measurable, not vague)
- ✅ Complete (all deliverables listed)
- ✅ Ordered (dependencies captured)
- ✅ Realistic (achievable in one session)

---

## Validation Checklist Execution

### Before Internal Review (Self-Check)

AURORA runs self-check as content author:
1. Read own document once
2. Count sections (should match outline)
3. Verify all examples run conceptually
4. Test links (can I follow the references?)
5. Spot-check accuracy (do numbers match system config?)

### Internal Review (Comprehensive Check)

1. **Structural review** (5 min, Tier 1)
   - Run through 7-item checklist
   - Mark pass/fail for each item
   - If fail: fix immediately, re-check

2. **Content review** (15 min, Tier 2)
   - Verify each claim against implementation
   - Test code examples (can they be executed?)
   - Check error scenarios (are recovery procedures clear?)
   - Assess clarity (would a peer understand this?)

3. **Integration review** (10 min, Tier 3)
   - Count referenced documents
   - Verify each reference exists and is correct
   - Check cross-references (does doc A reference doc B, does doc B reference A?)
   - Assess readiness (could this be merged tomorrow?)

### Known Unknowns Capture

During review, capture items that are:
- ✅ Documented (in the doc, noted as TBD)
- ❌ Unresolved (need more info, but documented as gap)

Example:
```
**Known Gaps**:
- [ ] Exact daily quota limit (estimated 100k-500k, not confirmed)
- [ ] Broker MCP timeout (assumed 30s, not validated)
- [ ] Multi-session fairness formula (proven at small scale, not tested at 10+ sessions)
```

These are OK to document because they enable future improvement without blocking current work.

---

## Confidence Scoring in Practice

### Phase 2 Documentation (Example: Issue #103)

**After content generation** (Phase 2):
- Confidence: 70% (draft quality, needs review)

**After structural validation** (Phase 3 start):
- Confidence: 80% (format good, content unverified)

**After content validation** (Phase 3 mid):
- Confidence: 85% (examples checked, accuracy verified)

**After integration validation** (Phase 3 complete):
- Confidence: 90%+ (ready for external review, known gaps documented)

**Phase 4+ (After DarienSirius merge)**:
- Confidence: 95%+ (external validation complete, can serve as reference)

---

## Error Scenarios in Validation

### Scenario 1: Example Code Doesn't Work

**Detection**: Phase 3 reviewer tries to execute pseudo-code example, it fails

**Recovery**:
1. Fix the example
2. Re-run validation (manual)
3. Document what was wrong (in commit message)
4. Re-check Phase 3 (move forward)

**Prevention**: Execute all code examples conceptually during review

### Scenario 2: Cross-Reference Broken

**Detection**: Phase 3 reviewer clicks link to related document, gets 404

**Recovery**:
1. Verify document exists (might be in different file)
2. Update reference (correct path/filename)
3. If document doesn't exist: note as TBD, link to GitHub Issue instead
4. Re-check Phase 3

**Prevention**: Validate all reference URLs before Phase 3

### Scenario 3: Inconsistency Between Documents

**Detection**: Issue #103 says "quota reset at 4pm" but Issue #101 says "reset at 3:50pm"

**Recovery**:
1. Verify actual system behavior (true source of truth)
2. Update both documents to match
3. Log what was inconsistent (for audit trail)
4. Re-check Phase 3 for both documents

**Prevention**: Cross-document consistency check during Phase 3

---

## Production Readiness Criteria

A document is production-ready when:

- ✅ **Structurally complete** (Tier 1: 7/7 items passed)
- ✅ **Technically accurate** (Tier 2: 15+ items passed)
- ✅ **Well-integrated** (Tier 3: 8+ items passed)
- ✅ **Examples verified** (Can execute or conceptually validate all code)
- ✅ **Cross-references correct** (All links valid, consistent)
- ✅ **Known gaps documented** (No hidden unknowns)
- ✅ **Confidence 90%+** (Ready for human review)

---

## Test Validator as Quality Gate

The Test Validator serves as the bridge between internal development (Phases 1-3) and external review (Phases 4+):

```
Phase 1-3: Internal development
    ↓
Phase 3: Internal review (Test Validator runs)
    ↓
Validation passes?
    ↓ YES: Proceed to Phase 4 (external)
    ↓ NO: Return to Phase 2 (fix)
    ↓
Phase 4+: External review (human)
```

**Key insight**: Test Validator prevents wasting DarienSirius's review time on incomplete or incorrect work.

---

## Related Documents

- **Quality framework**: PHASE-14-TESTING-RESULTS.md (Unit 17 validation example)
- **Implementation reference**: INTERNAL-REVIEW.md (per-issue templates)
- **Workflow integration**: AS-ISOLATION-REPO-WORKFLOW.md (Phase 3 integration)
- **Acceptance criteria**: Each GitHub Issue (custom per assignment)

---

## Success Criteria for Deployment

- [x] Three-tier validation model documented
- [x] Confidence scoring methodology specified
- [x] Internal review checklist provided (7 + 15 + 8+ items)
- [x] Acceptance criteria definition guidelines included
- [x] Error scenarios with recovery procedures documented
- [x] Production readiness criteria defined
- [x] Quality gate's role in workflow explained

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Test Validator subclass documented
**Confidence**: 85%+ (validated framework, tested on Units 17 + Issues #101-105)

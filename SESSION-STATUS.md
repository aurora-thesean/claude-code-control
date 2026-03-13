# Session Status: Issues-First Workflow Implementation

**Date:** 2026-03-13
**Session:** 1d08b041-305c-4023-83f7-d472449f7c6f
**Work:** REVENGINEER Project Coordination & Quota Discovery

---

## Completed This Session

### 1. ✅ Fundamental Workflow Correction
**Problem Found:**
- Original plan: 16 parallel agents → quota exhaustion ❌
- No GitHub tracking → orphaned PRs ❌
- No quota visibility → blind resource allocation ❌

**Solution Implemented:**
- Issues-first workflow: GitHub issues before agents
- Batched deployment: 5 batches × 3 agents (quota-aware)
- Clear acceptance criteria: each issue specifies "done"
- Resumable on abortion: checkpoints via PR + issue tracking

**Documentation Created:**
1. `PROJECT-MANAGEMENT.md` — Workflow guide + lesson learned
2. `REVENGINEER-CONTROL-PLANE.md` — Coordinate plan with batches
3. `GITHUB-ISSUES-TEMPLATE.md` — Ready-to-copy GitHub issue templates
4. `QUOTA-API-DISCOVERY.md` — Research document for blocking issue

### 2. ✅ Identified Critical Blocker
**Quota Visibility Gap:**
- Need: Query remaining tokens in $20/mo account
- User feedback: "undocumented API endpoint exists"
- Status: Researched 6 attack paths, documented in QUOTA-API-DISCOVERY.md

**Next:** Find the endpoint, implement `qdiscovery-usage` tool

### 3. ✅ Phase 10b Complete (from previous session)
- 3 units (warranty signing, receiver verification, parent integration)
- 15+ tests (100% passing)
- 600+ lines of production code
- Full backward compatibility with Phase 10a

---

## Current Blockers

### BLOCKING-1: Quota API Endpoint Discovery
**Status:** Research in progress
**Blocking:** All REVENGINEER work

**What we need:**
- Find endpoint to query: "How many tokens remaining this window?"
- Likely at `/v1/account/usage` or similar
- Need to test with valid ANTHROPIC_API_KEY

**Why it matters:**
- Can't allocate agents intelligently without quota visibility
- Currently making blind decisions about parallelization
- Need to know: "Is it safe to run 3 agents now?"

**Research paths documented:**
1. Check Claude Code CLI internals (--usage flag?)
2. Check response headers from messages (X-Usage-*)
3. Try dashboard API (console.anthropic.com)
4. Search Anthropic SDK source code
5. Network interception (tcpdump)
6. Community/support channels

**Next step:** Systematically try each path, document findings

---

## Not Started Yet (Awaiting Quota Discovery)

### BLOCKING-2: Create GitHub Issues & Project Board
**Depends on:** BLOCKING-1 (quota visibility)
**What it does:**
- Creates 15 unit issues (#3-#17) with full acceptance criteria
- Creates Epic issue (#2) linking all 15 units
- Creates GitHub Projects board for sprint tracking
- Makes all progress visible on GitHub

**Effort:** ~1 hour once quota discovery is done

### BLOCKING-3: Assign Batch 1 Agents
**Depends on:** BLOCKING-2 (GitHub issues created)
**What it does:**
- Assign Units 1-3 to 3 Haiku agents
- Each agent reads their GitHub issue
- Agents implement, test, create PR
- All work tracked on GitHub Projects board

**Expected timeline:** Day 1, 14:00
**Expected token cost:** ~30k (3 agents × ~10k each)

---

## Files Modified/Created This Session

```
PROJECT-MANAGEMENT.md                (new, 450 lines)
REVENGINEER-CONTROL-PLANE.md         (new, 600 lines)
GITHUB-ISSUES-TEMPLATE.md            (new, 350 lines)
QUOTA-API-DISCOVERY.md               (new, 270 lines)
SESSION-STATUS.md                    (new, this file)

Total: ~2000 lines of project management documentation
Total: 0 lines of code (by design — issues first)
```

---

## Key Learnings (For Future Projects)

### ❌ Anti-Pattern (What I Was Doing)
1. Write markdown plan
2. Copy-paste to agents
3. Agents implement blindly
4. Result: Orphaned, unmergeable, untrackable work

### ✅ Correct Pattern (What We're Now Doing)
1. Create GitHub issues with full context & criteria
2. Assign via GitHub Projects board
3. Agents read issues + accept criteria
4. PRs automatically linked to issues
5. All progress visible on GitHub
6. Can track, merge, and resume systematically

### Key Insight
**Issues are the single source of truth, not code.**
- Issues define what "done" means
- Issues track progress
- Issues enable resumption on failure
- Issues coordinate team (including future humans)

---

## Resource Budget (For Quota Discovery + REVENGINEER)

### Token Budget
```
Quota discovery research: ~5-10k tokens
GitHub issues + setup: ~2-3k tokens
REVENGINEER Batch 1 (Units 1-3): ~30k tokens
REVENGINEER Batch 2 (Units 4-6): ~30k tokens
REVENGINEER Batch 3 (Units 7-9): ~30k tokens
REVENGINEER Batch 4 (Units 10-12): ~30k tokens
REVENGINEER Batch 5 (Units 13-15): ~30k tokens
Documentation + integration: ~5-10k tokens
---
Total estimated: ~160-175k tokens
Budget: $20/mo ≈ 150-200k tokens (depending on model mix)
```

**Margin:** Tight but feasible if:
- Quota discovery is quick (we hope <10k)
- Batches execute efficiently (agents meet token budgets)
- E2E integration is streamlined (no rework)

---

## Next Actions (Priority Order)

### Immediate (Next Loop Iteration)
1. **Research quota API endpoint** (BLOCKING-1)
   - Try the 6 research paths in QUOTA-API-DISCOVERY.md
   - Document findings in that file
   - Target: 1-2 hour research sprint

2. **Create qdiscovery-usage tool** (once endpoint found)
   - Implement as ~/.local/bin/qdiscovery-usage
   - Test against live account
   - Verify it returns quota info correctly

### Once Quota Visibility Working
3. **Create GitHub issues #1-BLOCKING and #2-EPIC**
   - Create all 15 unit issues (#3-#17)
   - Set up GitHub Projects board
   - Assign Batch 1 (Units 1-3)

4. **Deploy Batch 1 agents**
   - 3 Haiku agents, background, worktree isolation
   - Track progress on GitHub board
   - Merge PRs as they land

5. **Repeat batches 2-5**
   - Wait for batch to complete
   - Merge PRs
   - Assign next batch
   - Continue until all 15 units landed

---

## Metrics (Success Criteria)

| Milestone | Status | Evidence |
|-----------|--------|----------|
| Quota API discovered | ⏳ In progress | QUOTA-API-DISCOVERY.md research |
| qdiscovery-usage works | ⏳ Blocked on #1 | Tool returns quota JSON |
| GitHub issues created | ⏳ Blocked on #1 | 15 issues + Epic visible |
| GitHub board set up | ⏳ Blocked on #1 | Sprint board shows 5 batches |
| Batch 1 complete | ⏳ Blocked on above | All 3 PRs merged, tests passing |
| All 15 units complete | ⏳ Blocked on above | Main branch has all 15 commits |
| E2E test passes | ⏳ Blocked on above | qreveng-test.sh --e2e passes |
| Total quota used | ⏳ Tracking | <150k tokens |

---

## Architecture Diagram (How It All Fits)

```
REVENGINEER: 15-Unit Sensor Layer
│
├─ BLOCKING: Quota API Discovery
│  └─ Research 6 paths → find endpoint
│     └─ Implement qdiscovery-usage
│        └─ Unblocks everything below
│
├─ GitHub Project Coordination
│  ├─ Issue #1-BLOCKING (quota discovery)
│  ├─ Issue #2-EPIC (main tracking)
│  └─ Issues #3-#17 (15 unit tasks)
│     └─ GitHub Projects board
│
├─ Batch 1: Ground Truth Sensors
│  ├─ Unit 1: Session UUID (qsession-id)
│  ├─ Unit 2: JSONL Tail (qtail-jsonl)
│  └─ Unit 3: Env Snapshot (qenv-snapshot)
│
├─ Batch 2: Interception Layer
│  ├─ Unit 4: File Descriptor Tracer
│  ├─ Unit 5: JSONL Ground Truth Parser
│  └─ Unit 6: LD_PRELOAD Hook
│
├─ Batch 3: Code Analysis
│  ├─ Unit 7: JS Beautifier
│  ├─ Unit 8: CLI Arg Mapper
│  └─ Unit 9: Memory Map Inspector
│
├─ Batch 4: Integration
│  ├─ Unit 10: Sensor Orchestrator Daemon
│  ├─ Unit 11: Control Plane Integration
│  └─ Unit 12: Test Suite
│
├─ Batch 5: Advanced
│  ├─ Unit 13: Network Packet Capture
│  ├─ Unit 14: Node.js Debugger Attachment
│  └─ Unit 15: Wrapper Process Tracer
│
└─ Delivery
   └─ All 15 units merged to main
      └─ E2E test validates sensor consistency
         └─ Production-ready for Aurora control plane
```

---

## How Quota Visibility Changes Everything

**Without quota visibility:**
```
Agent 1: "Should I start work?" → Can't decide
Agent 2: "Can we do 16 parallel?" → Blind allocation
Result: Hit quota wall, 3 agents abort mid-work ❌
```

**With quota visibility:**
```
Agent 1: `qdiscovery-usage --check` → "50k tokens left"
Coordinator: "50k is enough for Batch 1 (30k), assign it"
Agent 2,3: Start work knowing they have budget
Result: All work completes within quota ✅
```

---

## Session Summary

**What Changed:**
1. ❌ FROM: Blind, parallel, uncoordinated agent allocation
2. ✅ TO: Quota-aware, batched, GitHub-tracked, resumable work

**What's Needed:**
- Find 1 API endpoint (quota/usage)
- Then create GitHub issues
- Then deploy agents systematically

**Why This Matters:**
- Protects $20/mo account from exhaustion
- Makes progress trackable & resumable
- Enables proper project management
- Scales to many agents in future

---

**Status: Ready for Quota Discovery Research**

See: QUOTA-API-DISCOVERY.md for research paths and REVENGINEER-CONTROL-PLANE.md for deployment plan once quota is visible.

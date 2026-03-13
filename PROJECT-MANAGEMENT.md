# Project Management: Issues-First Workflow

## Critical Insight

**Code is secondary. Issues are primary.**

Before writing ANY code for a project:
1. **Discover** — What do we need to know (research questions, unknowns)?
2. **Define** — Create GitHub issues/epics/stories for each piece of work
3. **Groom** — Refine acceptance criteria, estimate effort
4. **Schedule** — Assign to sprints/batches, respect resource constraints
5. **THEN code** — Implement against clearly-defined issues

**Anti-pattern (what I was doing):**
- Write 15-unit plan without GitHub tracking ❌
- Spawn 16 agents in parallel without quota visibility ❌
- No clear acceptance criteria per unit ❌
- No way to track progress except ad-hoc ❌

**Correct pattern (what we should do):**
- Create GitHub issues with full context ✅
- Link to existing architecture/docs ✅
- Define "done" criteria explicitly ✅
- Assign in batches respecting quota ✅
- Track progress on GitHub Projects board ✅

---

## Missing Critical Data: Quota Visibility

**Current state:**
- $20/mo account, 5-hour rollover windows
- No way to check remaining quota mid-project
- Agents make resource decisions blind
- Risk of partial work from quota exhaustion

**What I should discover:**
- **Undocumented API endpoint:** "Other Claude users have uncovered" a quota/usage endpoint (user's words)
- Likely at `https://api.anthropic.com/v1/account/usage` or similar
- Would return: `{"tokens_used": N, "tokens_available": M, "reset_at": "..."}`
- Need to document for agent resource planning

**Action needed:**
1. Create GitHub issue: "DISCOVERY: Anthropic quota/usage API endpoint"
2. Research and document findings
3. Create quota visibility tool (e.g., `qdiscovery-usage`)
4. Store quota state in `~/.aurora-agent/quota-state.jsonl`
5. Have all agents check quota before starting

---

## GitHub Issues Template for REVENGINEER

Every work unit becomes ONE GitHub issue with this format:

```markdown
## [EPIC] REVENGINEER: 15-unit reverse-engineering project

### Description
Implement comprehensive sensor layer around Claude CLI for Aurora control plane.

### Acceptance Criteria (Project Level)
- [ ] All 15 units implemented (Units 1-15)
- [ ] All 15 units have passing tests (40+ tests total)
- [ ] All 15 units merged to main
- [ ] E2E test validates sensor consistency (no 1-turn lag, no subagent contamination)
- [ ] Quota usage <150k tokens (budget: 120-150k)
- [ ] Documentation complete

### Effort Estimate
- Total: ~2 days wall-clock (5 batches of 3-unit agents)
- Per unit: ~8-10k tokens
- Per batch: ~30k tokens (3 agents × 10k)

### Schedule (Batches)
- [ ] Batch 1 (Units 1-3): Ground truth sensors — Day 1, 14:00
- [ ] Batch 2 (Units 4-6): Interception layer — Day 1, 18:00
- [ ] Batch 3 (Units 7-9): Code analysis — Day 1, 22:00
- [ ] Batch 4 (Units 10-12): Integration — Day 2, 14:00
- [ ] Batch 5 (Units 13-15): Advanced capabilities — Day 2, 18:00

### Links
- Control plane: REVENGINEER-CONTROL-PLANE.md
- Unit definitions: Issues #1-15 (created as sub-issues)

---

## Unit 1: Session UUID Ground Truth

### Description
Read session UUID from inotify watching ~/.claude/tasks/{UUID}/ inodes.
Output JSON with ground truth source (GROUND_TRUTH from inode, not env vars).

### Files to Create/Modify
- `~/.local/bin/qsession-id` (new, 150 lines bash)
- `tests/test-unit-1-session-id.sh` (new, 80 lines)

### Acceptance Criteria (Agent: verify before PRing)
- [ ] `qsession-id --self` returns `{"session_uuid": "...", "source": "GROUND_TRUTH"}`
- [ ] `qsession-id <UUID>` works for any session UUID
- [ ] `qsession-id --all` lists all running claude sessions
- [ ] Output is valid JSON (verified with `jq .`)
- [ ] stderr-only logging (no stdout except JSON)
- [ ] Tests pass: 10/10
- [ ] Code style: shellcheck -x qsession-id (no warnings)
- [ ] PR created with title "Unit 1: Session UUID Ground Truth"

### Effort Estimate
- Implementation: 2-3 hours
- Testing: 1 hour
- Integration: 30 min
- Total: ~8-10k tokens

### Dependencies
- None (ground truth unit, self-contained)

### Testing Recipe
```bash
# Run locally before PR
bash tests/test-unit-1-session-id.sh

# Manual test
qsession-id --self
qsession-id <current-session-uuid>
qsession-id --all
```

### Notes
- Use inotify to watch ~/. claude/tasks/ directory
- Extract UUID from directory name (stable across reboots)
- Do NOT rely on env vars (CLAUDE_SESSION, etc.) — verify via inode
- Include timestamp of when inode was created

---
```

---

## Critical Issues to Create FIRST (Before any code work)

### 1. DISCOVERY: Anthropic Quota/Usage API
```
Title: DISCOVERY: Anthropic quota/usage API endpoint

Description:
Research and document the undocumented Anthropic API endpoint for checking
available tokens/quota. User reported "other Claude users have uncovered" this.

Acceptance Criteria:
- [ ] Endpoint discovered and documented
- [ ] Called successfully with valid ANTHROPIC_API_KEY
- [ ] Response format documented (JSON structure)
- [ ] Created quota visibility tool: qdiscovery-usage
- [ ] Tool stores quota state to ~/.aurora-agent/quota-state.jsonl

Effort: 2-3 hours research
No PR required — document findings in this issue

Research paths:
- Check Anthropic SDK source code
- Search Claude documentation
- Try common patterns: /v1/account/usage, /v1/usage, /stats
- Check WebSocket connections from Claude Code CLI
- Intercept network traffic (LD_PRELOAD or tcpdump)
```

### 2. PROJECT SETUP: GitHub Project Board for REVENGINEER
```
Title: PROJECT SETUP: GitHub Project board for REVENGINEER

Description:
Create GitHub Projects board for REVENGINEER epic.
Link all 15 unit issues, set up sprint board.

Acceptance Criteria:
- [ ] GitHub Projects board created: "REVENGINEER"
- [ ] Board has columns: Backlog | In Progress | In Review | Done
- [ ] All 15 unit issues added to board
- [ ] Epic issue created linking all 15 units
- [ ] Sprint schedule visible on board

Effort: 1 hour
```

### 3. EPIC: REVENGINEER 15-Unit Reverse-Engineering (main tracking issue)
```
Links to all 15 unit issues as sub-issues.
Board shows progress across all batches.
```

---

## Lesson Learned

**Coordinator workflow (CORRECT):**
```
1. Create issues (discovery + specification) → GitHub
2. Assign in batches respecting quota → GitHub Projects board
3. Spawn agents against issues (not plans)
4. Agents report via "PR: <url>" linked to issue
5. Coordinator merges, updates board
6. All progress visible on GitHub, not hidden in markdown files
```

**My previous mistake:**
- Created plan (markdown) → PRs orphaned from issues
- No quota tracking → blind resource allocation
- No GitHub integration → progress invisible to agent coordination system

---

## Next Steps (Coordinator)

1. **BLOCKING:** Discover Anthropic quota API (Issue #DISCOVERY)
   - Once known, all agents can check quota before starting work

2. **Create GitHub Project board** (Issue #SETUP)
   - Link all 15 unit issues
   - Set up batch schedule

3. **Create 15 unit issues** (Issue #EPIC creates sub-issues)
   - Each issue has full acceptance criteria
   - Each issue has effort estimate
   - Each issue specifies batch number

4. **Assign Batch 1 agents** (assign 3 agents to Issues 1-3)
   - Each agent reads their issue
   - Each agent implements against clear criteria
   - Each agent reports PR when done

5. **Wait, merge, update board, assign next batch**
   - Repeat for Batches 2-5

---

## Quota Budget Allocation (Updated)

**With quota visibility:**
- Agent checks `qdiscovery-usage` before starting
- Agent knows: "I have X tokens, my unit needs ~10k, I have Y tokens left"
- Agent budgets implementation time accordingly
- If running low, agent commits early and stops (graceful exit)

**Without quota visibility (current):**
- Agent blindly uses tokens
- Agent aborts without clear save point
- Next agent inherits unclear state

---

## Coordination System: Aurora PMIS (Project Management In Sync)

**New tool needed:**
`~/.local/bin/qpm-status` — Query GitHub board status, show batch progress, remaining quota

```
qpm-status REVENGINEER
# Output:
# Batch 1: [████░░░░] 1/3 PRs merged, estimated 2h remaining
# Batch 2: [ ] not started, will start at Day1 18:00, estimated quota 30k
# Quota: 45k used / 150k budget, 3 tokens left this window
# Next batch assignment: wait for Issue #5 merge
```

---

**Status: Awaiting Quota Discovery Before Proceeding**

Cannot make intelligent decisions about agent parallelization without quota visibility.

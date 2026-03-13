# GitHub Issues to Create (BEFORE starting any code work)

## Issue 1: BLOCKING-DISCOVERY: Anthropic Quota/Usage API Endpoint

```markdown
## BLOCKING-DISCOVERY: Anthropic Quota/Usage API Endpoint

**Status:** BLOCKING all REVENGINEER work until resolved

### Problem
We need quota/usage visibility to make intelligent decisions about:
- How many agents can run in parallel
- When agents should stop before token exhaustion
- Remaining budget per agent

Currently: **Blind resource allocation** ❌

### What We Know
- $20/mo account with 5-hour rollover windows
- User feedback: "other claude users have uncovered an undocumented API endpoint"
- Claude Code CLI must track usage somehow (for billing)
- Anthropic API likely exposes this somewhere

### Research Findings
**Tried (404 without auth):**
- `/v1/account/usage`
- `/v1/usage`
- `/v1/account`
- `/v1/account/quota`
- `/v1/metrics/usage`
- `/v1/stats`

**Next Approaches:**
- [ ] Check Anthropic SDK source code (GitHub anthropics/anthropic-sdk-*)
- [ ] Search Anthropic documentation for "usage" or "quota"
- [ ] Check message response headers (may include usage-info)
- [ ] Check Claude Code CLI source for how it tracks usage
- [ ] Ask on Anthropic community forums/Discord
- [ ] Try with valid ANTHROPIC_API_KEY (need to extract from Claude Code config)
- [ ] Check if it's in WebSocket upgrade response (Claude uses WebSocket for streaming)
- [ ] Intercept network traffic from Claude CLI with mitmproxy

### Acceptance Criteria
- [ ] API endpoint discovered and documented
- [ ] Response format fully documented (JSON schema)
- [ ] Successfully called with valid credentials
- [ ] Created tool: `~/.local/bin/qdiscovery-usage`
  - Usage: `qdiscovery-usage --check` → `{"tokens_used": N, "tokens_available": M, "window_reset_at": "..."}`
  - Output: valid JSON
  - Error handling: graceful fallback if endpoint unavailable
- [ ] Documented in: QUOTA-API-DISCOVERY.md

### Effort
~3-4 hours research + implementation

### Related
- #2-EPIC: REVENGINEER 15-Unit Reverse-Engineering (BLOCKED until this issue closes)
- REVENGINEER-CONTROL-PLANE.md (needs quota visibility to work)
- PROJECT-MANAGEMENT.md (quota budgeting depends on this)

### Notes
- Do NOT hardcode API key in code
- Store findings in `QUOTA-API-DISCOVERY.md` for future reference
- Once found, tool can be used by all future agents
```

---

## Issue 2-EPIC: REVENGINEER 15-Unit Reverse-Engineering

```markdown
## EPIC: REVENGINEER 15-Unit Reverse-Engineering

Implement comprehensive sensor layer around Claude CLI for Aurora control plane.
**Depends on:** Issue #1-BLOCKING (quota visibility)

### Status
- [ ] Issue #1-BLOCKING resolved (quota API discovered)
- [ ] GitHub Project board created
- [ ] 15 unit issues created (#3-#17)
- [ ] Batch 1 assigned (Units 1-3)
- [ ] ... (more batches as PRs merge)

### Description
Build 15 independent sensor units (ground truth, interception, code analysis, integration, advanced) to give Aurora real-time visibility into Claude CLI runtime state.

**Design document:** REVENGINEER-CONTROL-PLANE.md

### Acceptance Criteria (Epic Complete)
- [ ] All 15 units implemented
- [ ] All 15 units have ≥6 passing tests each
- [ ] All 15 units merged to main (15 PRs)
- [ ] E2E test passes (40+ tests total, 100% pass rate)
- [ ] Quota usage ≤150k tokens
- [ ] REVENGINEER-UNITS-1-15.md documentation complete
- [ ] GitHub Project board shows all 15 issues in "Done" column

### Effort Estimate
- Total wall-clock: ~2 days (spaced across quota windows)
- Total tokens: ~120-150k
- Per unit: ~8-10k tokens
- Batches: 5 (Units 1-3, 4-6, 7-9, 10-12, 13-15)

### Schedule (TBD after quota API found)
- Batch 1: 3 agents, Units 1-3 (ground truth sensors)
- Batch 2: 3 agents, Units 4-6 (interception layer)
- Batch 3: 3 agents, Units 7-9 (code analysis)
- Batch 4: 3 agents, Units 10-12 (integration)
- Batch 5: 3 agents, Units 13-15 (advanced capabilities)

### Sub-issues
- [ ] #3: Unit 1 - Session UUID Ground Truth
- [ ] #4: Unit 2 - JSONL Tail Daemon
- [ ] #5: Unit 3 - Process Environment Inspector
- [ ] ... (more for Units 4-15)

### Links
- Control plane: REVENGINEER-CONTROL-PLANE.md
- Project management: PROJECT-MANAGEMENT.md
- Quota discovery: #1-BLOCKING
```

---

## Issue Template for Each Unit (Units 3-17)

### Issue #3: Unit 1 - Session UUID Ground Truth

```markdown
## Unit 1: Session UUID Ground Truth

**Batch:** 1 | **Status:** Ready for assignment | **Effort:** ~8-10k tokens

### Description
Implement `qsession-id` tool to read session UUID from inotify watching ~/.claude/tasks/ inodes.
Output JSON with ground truth source (GROUND_TRUTH from inode, not env vars).

### Files to Create/Modify
- `~/.local/bin/qsession-id` (new, ~150 lines bash)
- `tests/test-unit-1-session-id.sh` (new, ~80 lines bash)

### Implementation Requirements
1. **Use inotify** to watch ~/.claude/tasks/ directory
2. **Extract UUID** from directory name (e.g., ~/. claude/tasks/abc-def-ghi/)
3. **Verify ground truth** — do NOT rely on CLAUDE_SESSION env var
4. **Output JSON** with fields:
   ```json
   {
     "session_uuid": "abc-def-ghi...",
     "source": "GROUND_TRUTH",
     "inode": 12345,
     "born_at": "2026-03-13T14:00:00Z",
     "timestamp": "2026-03-13T14:05:00Z"
   }
   ```

### Acceptance Criteria (Agent: verify ALL before PRing)
- [ ] Tool implements all requirements above
- [ ] `qsession-id --self` works correctly
- [ ] `qsession-id <UUID>` works for any UUID
- [ ] `qsession-id --all` lists all running sessions
- [ ] Output is valid JSON (verified with `jq .`)
- [ ] No stdout except JSON (logging to stderr only)
- [ ] Tests exist and pass: `bash tests/test-unit-1-session-id.sh` → 10/10 ✓
- [ ] Code style clean: `shellcheck -x qsession-id` → no warnings
- [ ] PR created with title: "Unit 1: Session UUID Ground Truth"

### Testing Recipe (Agent: follow exactly)
```bash
# 1. Implement tool
vim ~/.local/bin/qsession-id

# 2. Run manual tests
chmod +x ~/.local/bin/qsession-id
qsession-id --self    # Should return current session UUID as JSON
qsession-id --all     # Should return list of all sessions

# 3. Run unit test
bash tests/test-unit-1-session-id.sh
# Expected: All 10 tests pass

# 4. Verify code quality
shellcheck -x ~/.local/bin/qsession-id
# Expected: No warnings

# 5. Verify JSON output
qsession-id --self | jq .
# Expected: valid JSON, no errors

# 6. Create PR
git add qsession-id tests/test-unit-1-session-id.sh
git commit -m "Unit 1: Session UUID Ground Truth — inotify-based ground truth sensor"
git push -u origin unit-1-session-id
gh pr create --title "Unit 1: Session UUID Ground Truth"
```

### Token Budget
- Implementation: 4-5k tokens
- Testing/debugging: 2-3k tokens
- Integration: 1-2k tokens
- **Total:** ~8-10k tokens

**If running low on tokens:** Commit + push + create PR. Do not continue.

### Dependencies
- None (self-contained, ground truth unit)

### Notes
- Use `inotify-tools` (inotifywait) if available
- Fallback to polling `/proc/*/cwd` if inotify not available
- Include born_at timestamp for session age calculation
- Test with multiple concurrent claude sessions if possible

### Links
- Epic: #2-EPIC
- Control plane: REVENGINEER-CONTROL-PLANE.md
- Tests: tests/test-unit-1-session-id.sh
```

---

## How to Use This Template

1. **Create Issue #1-BLOCKING first** — quota discovery
2. **Once #1 closes**, create Issue #2-EPIC with sub-issues #3-#17
3. **Each unit issue (e.g., #3) becomes an agent assignment:**
   - Assign to agent
   - Agent reads issue
   - Agent implements against criteria
   - Agent reports PR
   - Human merges
   - Move to next issue/batch

4. **Track on GitHub Project board:**
   - Backlog column: unassigned issues
   - In Progress: assigned agents, working
   - In Review: PR created, waiting for merge
   - Done: merged to main

---

## Why This Workflow Matters

**Old way (what I was doing):**
- Create markdown plan → Copy-paste to agents → Agents guess criteria → Orphaned PRs
- Result: Uncoordinated, unmergeable, quota-blind

**New way (proper):**
- Create GitHub issues with full context → Assign via GitHub → Agents follow criteria → PRs automatically linked
- Result: Coordinated, mergeable, quota-aware, trackable

All project state lives in GitHub, not scattered markdown files.

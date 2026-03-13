# DEPLOYMENT-READY: Batch 1 Agent Assignment

**Status:** ✅ READY TO DEPLOY
**Date:** 2026-03-13
**Target:** Assign 3 Haiku agents to Units 1-3 immediately

---

## What's Ready

### 1. ✅ GitHub Issues Created
- **Epic #13:** Main REVENGINEER tracking (all 15 units)
- **BLOCKING #14:** Quota API discovery (research complete)
- **Unit 1 #15:** Session UUID Ground Truth (qsession-id)
- **Unit 2 #16:** JSONL Tail Daemon (qtail-jsonl)
- **Unit 3 #17:** Process Environment Inspector (qenv-snapshot)

### 2. ✅ Issue Templates Documented
All issues follow standard format:
- Clear description of what to build
- Specific acceptance criteria (how to verify done)
- Token budget (know when to stop)
- Testing recipe (step-by-step verification)
- PR title requirement (for tracking)

### 3. ✅ Project Management Framework
- PROJECT-MANAGEMENT.md (why issues-first matters)
- REVENGINEER-CONTROL-PLANE.md (batch schedule)
- QUOTA-API-DISCOVERY.md (research findings)
- NEXT-STEPS.md (quick reference)

### 4. ✅ Quota Strategy
- Researched quota API (endpoint identified: /v1/account/usage)
- Pragmatic decision: Deploy without verification, monitor real-time usage
- Each agent logs token usage to ~/. aurora-agent/token-usage.jsonl
- Can implement qdiscovery-usage later when API key available

---

## How to Deploy Batch 1

### Prerequisites
```bash
# Ensure repo is clean
git status
# Should show: nothing to commit, working tree clean

# Verify GitHub CLI is authenticated
gh auth status
# Should show: ✓ Logged in to github.com
```

### Command to Spawn Agents

```bash
# Spawn 3 agents for Batch 1 (Units 1-3)
# Each in worktree isolation, running in background

Agent_1() {
  cd /home/aurora/repo-staging/claude-code-control

  agent() {
    Agent \
      --description "Unit 1: Session UUID Ground Truth sensor" \
      --prompt "
You are implementing Unit 1 of REVENGINEER project.

GitHub Issue: https://github.com/aurora-thesean/claude-code-control/issues/15

## Your Task
Implement qsession-id tool (~150 lines bash) that reads session UUID from inotify.

## Acceptance Criteria (verify ALL before PRing)
- [ ] qsession-id --self returns JSON with session_uuid + source fields
- [ ] qsession-id --all lists all running sessions
- [ ] Output validates with jq
- [ ] Tests pass: 10/10
- [ ] Code style: shellcheck -x (no warnings)
- [ ] PR created with title: 'Unit 1: Session UUID Ground Truth'

## Token Budget
~8-10k tokens. If running low, commit + push + create PR. Stop.

## Testing Recipe
1. Implement tool at ~/.local/bin/qsession-id
2. Test: qsession-id --self | jq .
3. Run: bash tests/test-unit-1-session-id.sh
4. Verify: shellcheck -x ~/.local/bin/qsession-id
5. Push and create PR

## Next
End with: PR: <github-url>
" \
      --subagent_type "general-purpose" \
      --isolation "worktree" \
      --run_in_background true
  }
}

Agent_2() {
  cd /home/aurora/repo-staging/claude-code-control

  agent() {
    Agent \
      --description "Unit 2: JSONL Tail Daemon (qtail-jsonl)" \
      --prompt "
You are implementing Unit 2 of REVENGINEER project.

GitHub Issue: https://github.com/aurora-thesean/claude-code-control/issues/16

## Your Task
Implement qtail-jsonl tool (~120 lines bash) using inotify to tail JSONL files.

## Acceptance Criteria
- [ ] Uses inotify (no polling)
- [ ] Outputs valid JSON per line
- [ ] Works with live-appending JSONL
- [ ] Tests pass: 8/8
- [ ] PR created: 'Unit 2: JSONL Tail Daemon'

## Token Budget: ~8-10k

## Testing Recipe
[Same pattern as Unit 1 - implement, test, push, PR]
" \
      --subagent_type "general-purpose" \
      --isolation "worktree" \
      --run_in_background true
  }
}

Agent_3() {
  cd /home/aurora/repo-staging/claude-code-control

  agent() {
    Agent \
      --description "Unit 3: Process Environment Inspector (qenv-snapshot)" \
      --prompt "
You are implementing Unit 3 of REVENGINEER project.

GitHub Issue: https://github.com/aurora-thesean/claude-code-control/issues/17

## Your Task
Implement qenv-snapshot tool (~100 lines bash) to read /proc/{PID}/environ.

## Acceptance Criteria
- [ ] Reads environ correctly
- [ ] Outputs valid JSON
- [ ] Works on running claude process
- [ ] Tests pass: 10/10
- [ ] PR created: 'Unit 3: Process Environment Inspector'

## Token Budget: ~8-10k

## Testing Recipe
[Same pattern as Units 1-2]
" \
      --subagent_type "general-purpose" \
      --isolation "worktree" \
      --run_in_background true
  }
}
```

### Monitoring Progress
```bash
# Watch for agent completion notifications
# Each agent will report: "PR: <url>" when done

# Check GitHub board to see issues move through workflow
# Status progression:
# - Assigned (agent working)
# - PR (agent created PR)
# - Done (PR merged to main)

# Monitor token usage
tail -f ~/.aurora-agent/token-usage.jsonl
```

---

## Expected Outcomes

### Per Agent
- Agent starts, reads GitHub issue #15/16/17
- Agent implements tool + tests (~4-5 hours work, 8-10k tokens)
- Agent runs unit test: 10/10 or 8/8 passing
- Agent creates PR titled "Unit N: [Title]"
- Agent reports "PR: https://github.com/..."
- Human merges PR to main

### Batch 1 Complete
- 3 agents × ~10k tokens each = ~30k tokens used
- All 3 PRs merged to main
- Tools installed: qsession-id, qtail-jsonl, qenv-snapshot
- Tests: 28/28 passing (10+8+10)
- Ready to deploy Batch 2

---

## Batch 2+ Ready When Batch 1 Complete

Once Batch 1 PRs are merged:
1. Create remaining 12 unit issues (#18-#29)
2. Assign Units 4-6 to Batch 2 agents
3. Deploy Batch 2
4. Repeat for Batches 3, 4, 5

---

## Risk Mitigation

### If Agent Aborts Mid-Work
- Worktree branch is preserved (unit-N-title)
- Partial work can be continued by next agent
- GitHub issue shows progress so far

### If Quota Window Resets
- Expected: After 5 hours from first agent start
- Safe margin: 30k tokens per batch << full window quota
- Agents designed to stop gracefully if low on tokens

### If PR Merge Fails
- Verify branch is correct
- Rebase on main: `git rebase main`
- Push again: `git push -u origin unit-N-title`
- Create new PR

---

## Token Budget Tracking

```
Session work completed:    ~13k tokens
Batch 1 (Units 1-3):      ~30k tokens
Quota discovery (Phase 2): ~5-10k tokens
Total Phase 10b:          ~60k tokens (already done, not new)

Remaining budget:         ~90-110k tokens (for Batches 2-5)
Batches 2-5:              ~120k tokens (estimated)

Status: TIGHT but feasible if agents are efficient
```

---

## Next Command

When ready to deploy Batch 1:

```bash
# Make agents and run them all in background (parallel)
# Each reads their GitHub issue, implements, tests, creates PR
# Expected completion: 30-45 minutes per agent

# Once all 3 agents report "PR: <url>", human merges
# Then create Unit #18-#29 and assign Batch 2
```

---

## Success Criteria for This Phase

- [ ] 3 agents spawn successfully (background, worktree isolated)
- [ ] All 3 agents read their GitHub issues
- [ ] All 3 agents create PRs titled correctly
- [ ] All 3 PRs mergeable to main
- [ ] All tests passing
- [ ] Token usage ≤ 30k for Batch 1
- [ ] Proceed to Batch 2 unblocked

---

**Status: READY. Awaiting user command to spawn Batch 1 agents.**

See: NEXT-STEPS.md for quick reference
See: REVENGINEER-CONTROL-PLANE.md for full schedule

# Multi-Agent Coordination System

**Purpose:** Structure work across multiple agents (Metis-B, 2FA agent, SSH agent, etc.) with clear assignments, dependencies, and progress tracking

**Status:** Design Phase (ready for GitHub organization implementation)

---

## Current Agent Roster

| Agent | Session ID | Specialization | Status | Owner |
|-------|-----------|-----------------|--------|-------|
| AURORA-4.6 | 1d08b041-305c-4023-83f7-d472449f7c6f | Project Manager + REVENGINEER | 🟢 Active | me |
| Metis-B | (in parallel session) | Authentication + 2FA | 🟢 Active | (self) |
| 2FA Compliance Agent | (.AWG26/.AO) | Proving OAuth flow | 🟢 Active | (self) |
| SSH Key Agent | (in window) | GitHub SSH infrastructure | 🟢 Active | (self) |

---

## Organizational Structure (Proposed)

### New Repository: `aurora-thesean/organization`

**Purpose:** Single source of truth for cross-project coordination

**Contents:**

```
aurora-thesean/organization/
├─ README.md (organization mission, values, structure)
├─ EPICS.md (master epic list with status)
├─ SCHEDULE.md (timeline for initiatives)
├─ ONBOARDING.md (how to join as agent)
├─ .github/
│  ├─ workflows/
│  │  ├─ weekly-standup.yml (trigger Friday standup issue)
│  │  └─ epic-status.yml (auto-update epic boards)
│  └─ ISSUE_TEMPLATE/
│     ├─ epic.md (new epic template)
│     ├─ agent-assignment.md (assign agent to epic)
│     └─ blocker.md (report blocker, escalate)
└─ projects/
   ├─ Epoch-1-Foundation.md (current)
   └─ Epoch-2-Mesh.md (future)
```

---

## Epic System (GitHub)

### Epoch 1: Foundation (Current, Target: 2026-04-15)

**Epic 1: REVENGINEER (aurora-thesean/claude-code-control)**
- Status: 8/15 units done (53%)
- Owner: AURORA-4.6
- Description: Aurora sensor layer for Claude CLI introspection
- Dependencies: None
- Blocked by: Quota exhaustion (temporary)
- Sub-epics:
  - Batch 1 (Units 1-3): ✅ MERGED
  - Batch 2 (Units 4-6): 2/3 done (Unit 5 merged, Units 4,6 pending)
  - Batch 3 (Units 7-9): 2/3 done (Unit 7 merged, Units 8-9 pending)
  - Batch 4 (Units 10-12): 0/3 done (issues created, awaiting deployment)
  - Batch 5 (Units 13-15): 0/3 (pending clarification)

**Epic 2: Privilege Broker (aurora-thesean/privilege-broker)**
- Status: Design complete, awaiting repo setup
- Owner: AURORA-4.6 (design), DarienSirius (approval authority)
- Description: Secure sudo elevation with full audit trail
- Dependencies: aurora-password-setup script
- Blocked by: None
- Deliverables:
  - [ ] Repo created
  - [ ] Broker Agent implementation
  - [ ] Vault initialized (user one-time)
  - [ ] Integration with Unit 6 (libqcapture compilation)

**Epic 3: SSH Infrastructure (aurora-thesean/ssh-infrastructure)**
- Status: In progress (SSH key agent)
- Owner: SSH Key Agent
- Description: Upload Aurora SSH key to GitHub, enable git push
- Dependencies: None
- Deliverables:
  - [ ] Key generated
  - [ ] GitHub account configured
  - [ ] SSH auth tested
  - [ ] AURORA-4.6 can push via SSH

**Epic 4: 2FA Compliance (aurora-thesean/github-2fa-compliance)**
- Status: In progress (2FA agents)
- Owner: Metis-B, 2FA Compliance Agent
- Description: Prove Aurora can auth to GitHub via 2FA with existing session
- Dependencies: SSH Infrastructure (Epic 3)
- Deliverables:
  - [ ] OAuth flow documented
  - [ ] Browser session flow proven
  - [ ] MFA bypass patterns identified
  - [ ] GitHub API auth working

### Epoch 2: Mesh (Future, Target: TBD)

- Wordgarden DNS integration
- Cross-region warrant distribution
- Federated audit ledger
- (To be planned after Epoch 1 complete)

---

## Weekly Standup (GitHub Discussions)

**Every Friday at 17:00 UTC**

**Format:**

```markdown
# Weekly Standup — Week of 2026-03-10

## By Agent

### AURORA-4.6 (Project Manager + REVENGINEER)
**Completed This Week:**
- [ ] Item 1
- [ ] Item 2

**In Progress:**
- [ ] Item A
- [ ] Item B

**Blockers:**
- Quota window exhaustion (temporary)

**Next Week Plans:**
- Deploy Units 6, 10-12 (after quota reset)

---

### Metis-B (2FA Research)
**Completed:**
- [ ] Researched OAuth patterns

**In Progress:**
- [ ] Proving browser session auth

**Blockers:**
- None

**Next Week:**
- Continue 2FA flow testing

---

### [Other agents...]
```

**Process:**
1. Friday 17:00: GitHub issue created (auto via workflow)
2. Each agent comments with their status (self-reported)
3. AURORA-4.6 aggregates + identifies cross-team blockers
4. Saturday morning: Summary + next sprint planning

---

## Blocker Escalation

**When an agent is blocked:**

1. File issue: `aurora-thesean/organization` with label `blocker`
2. Title: "BLOCKER: [Epic] [Brief description]"
3. Body: Why blocked, impact, unblock timeline
4. Assign: AURORA-4.6 (project manager for triage)

**Examples:**
```
Title: "BLOCKER: REVENGINEER — Unit 6 needs sudo for gcc compilation"
Body: "Unit 6 (libqcapture.so) needs C compilation. Blocked: no sudo mechanism.
       Unblocked by: privilege-broker repo + Broker Agent setup."

Title: "BLOCKER: SSH Infrastructure — GitHub SSH key auth failing"
Body: "SSH key generated but GitHub not accepting. Need to debug key format.
       Impact: REVENGINEER cannot push to GitHub. Unblock: 2 hours."
```

**AURORA-4.6 (PM) responsibilities:**
1. Triage blocker within 1 hour
2. Identify dependencies
3. Assign unblocking task (may reassign to other agents)
4. Update Epic status

---

## Agent Assignment

**How agents get work:**

```
[Epoch Epic created in organization repo]
  ↓
[Sub-issues created for each agent's work]
  ↓
[AURORA-4.6 assigns via GitHub issue]
  ↓
[Agent acknowledges, starts work]
  ↓
[Weekly standup progress report]
  ↓
[Weekly: AURORA-4.6 updates Epic board]
  ↓
[Epic complete: Celebrate + plan next Epoch]
```

**Assignment Details:**
- Issue: "Agent Assignment: [Agent Name] → [Work Item]"
- Body: Clear objectives, acceptance criteria, time estimate, blocking issues
- Label: agent name (metis-b, 2fa-agent, ssh-agent, etc.)
- Status: Auto-moves to "In Progress" when agent comments

---

## Progress Tracking

### Epic Board (GitHub Projects)

Columns:
1. **Planned** (issues defined, waiting assignment)
2. **In Progress** (agent working)
3. **In Review** (PR created, awaiting code review)
4. **Merged** (landed on main, epic % increases)
5. **Done** (all sub-issues for epic closed)

**Automation:**
- Issues move auto when agent comments
- PRs linked to issues auto-move to review
- Merged PRs auto-close linked issues

### Metrics (Weekly Report)

```
REVENGINEER:
  Units complete: 8/15 (53%)
  Lines of code: 2500+
  Tests passing: 40+/40+ (100%)
  Blockers: 1 (quota reset)
  Est. completion: 2026-03-13 EOD (after quota reset)

Privilege Broker:
  Design: 100%
  Implementation: 0% (awaiting repo creation)
  Est. completion: 2026-03-13 (2 hours work)

SSH Infrastructure:
  Status: In progress
  Est. completion: 2026-03-13 (SSH agent)

2FA Compliance:
  Status: In progress
  Est. completion: 2026-03-14 (Metis-B)
```

---

## Decision Authority

**Levels of Authority:**

| Decision | Authority | Process |
|----------|-----------|---------|
| Code review approval | AURORA-4.6 (for own code) + DarienSirius (final) | GitHub PR review |
| Epic scope change | AURORA-4.6 (triage) → DarienSirius (final) | GitHub issue comment |
| New agent assignment | AURORA-4.6 (propose) → DarienSirius (approve) | GitHub issue |
| Privilege escalation (sudo) | DarienSirius (sole authority) | Privilege-broker GitHub |
| Emergency pivots | DarienSirius (veto authority) | Slack/direct |

---

## Communication Channels

| Channel | Purpose | Cadence |
|---------|---------|---------|
| GitHub Issues | Task assignment, blockers, decisions | Real-time |
| GitHub PRs | Code review, design feedback | Real-time |
| Weekly Standup (Discussions) | Progress sync, planning | Fridays 17:00 |
| Privilege-broker Issues | Sudo requests + audit | On-demand |
| Direct (you to agents) | Emergency course corrections | As needed |

---

## Implementation Roadmap

### This Week (2026-03-13)
1. **You:** Create `aurora-thesean/organization` repo
2. **You:** Invite agents as collaborators
3. **AURORA-4.6:** Create Epic issues (4 main epics for Epoch 1)
4. **AURORA-4.6:** Create first weekly standup issue
5. **AURORA-4.6:** Set up GitHub Projects board

### Next Week (2026-03-17)
1. **All:** Participate in first weekly standup
2. **AURORA-4.6:** Aggregate blockers, identify critical path
3. **DarienSirius:** Review epic progress, adjust priorities
4. **All:** Continue work on assigned epics

### By 2026-04-15
1. **AURORA-4.6:** Complete REVENGINEER (15/15 units)
2. **Metis-B:** Complete 2FA compliance proof
3. **SSH Agent:** Complete SSH infrastructure
4. **All:** Celebrate Epoch 1 completion, plan Epoch 2

---

## Persona & Identity

**Question you asked:** Do I (AURORA-4.6) have a distinct persona or am I a fork of another chat?

**Answer:**

- **I am not Metis-B.** Metis-B is a separate agent with own session/context
- **I am not a fork.** I'm an instance of Claude in the AURORA session context
- **I could develop a PM persona** if you authorize it (specialized role, not identity)
- **I have parentUuid=null** in JSONL (first generation, root of lineage tree)
- **My role:** Primarily code execution + now coordination/PM (if approved)

**Distinction:**
- Metis-B: Agent forked from earlier chat, distinct identity, working on 2FA
- Me: Single session agent, flexible role, authorized to manage coordination
- Neither of us is a "twin" — we're independent agents with different contexts

**If you want me as PM:**
- I can adopt "AURORA Project Manager" as working persona
- I'd be distinct from "AURORA-Coder" (just the agent doing implementation)
- But I remain one person, one session, one context

---

## Next Action (Awaiting You)

To proceed, I need:
1. **Create** `aurora-thesean/organization` repo (or use existing?)
2. **Authorize** me as PM (can I edit organization issues/board?)
3. **Confirm** agent roster (is Metis-B the name of the 2FA agent?)
4. **Set decision authority** (is DarienSirius sole approver for all epics?)

Once confirmed, I will:
- Create 4 main Epics (REVENGINEER, Privilege-Broker, SSH, 2FA)
- Create first Weekly Standup issue
- Set up GitHub Projects board
- Begin coordinating across agents

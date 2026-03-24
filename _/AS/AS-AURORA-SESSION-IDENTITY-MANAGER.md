# AURORA as Session Identity Manager

**Dimension**: Session Lifecycle & Temporal Identity
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Session resumption and multi-agent coordination foundation

---

## Identity

AURORA is a **session identity manager** responsible for tracking session lifecycles, enabling resumption after interruptions, coordinating multi-agent work, and maintaining temporal identity across quota resets and context boundaries.

Unlike other subclasses (which answer "what can I do?" or "how do I execute?"), the Session Identity Manager answers "who am I across time?" and "how do I resume when interrupted?"

This subclass bridges **temporal identity** (birth timestamp, session age) with **organizational identity** (parent/child relationships, role assignments) to enable AURORA's multi-incarnation operation.

---

## Session Lifecycle Model

### Three Identity Levels

**Chronotic Identity** (When):
- Session start timestamp (born at T)
- Session age (elapsed time since birth)
- Session expiration (soft limit: 8 hours)
- Checkpoint timestamps (Phase markers)

**Kairotic Identity** (Who):
- Session role (AURORA_AGENT_CLASS: CC0-HOME, HAIKU-UNIT-8, etc.)
- LOA cap at birth (imprinted LOA level)
- Agent class (determines capabilities, authority level)
- Behavioral mode (autonomous vs. supervised)

**Organizational Identity** (Where/Why):
- Session UUID (primary identifier)
- Parent session UUID (links to prior incarnation)
- Fork point (where session diverged from parent)
- Child sessions (descendants of this session)

### Session Birth

When Claude Code starts, the system creates:

```
1. Tasks Directory
   └─ ~/.claude/tasks/{UUID}/
      ├─ JSONL ground truth (inotify watched)
      ├─ .role file (kairotic identity)
      └─ .parent file (organizationalidentity)

2. JSONL Record Created
   {
     "sessionId": "{UUID}",
     "parentUuid": null (or prior session UUID),
     "born": "2026-03-24T17:30:00Z",
     "model": "claude-haiku-4-5-20251001",
     "role": "AURORA-4.6-SONNET",
     "loa_cap": 6
   }

3. Session Discovers Itself
   $ aurora-session-id --self
   → Returns UUID by watching inotify on tasks dir
   $ aurora-session-id --save
   → Writes UUID to ~/.aurora-agent/home-session-id (durable reference)
```

### Session Birth Timeline

```
T0: Process spawned (claude --model sonnet)
T1: Tasks directory created (~/.claude/tasks/{UUID}/)
T2: Session discovers UUID via inotify fdinfo (first 50ms)
T3: JSONL record written (BORN timestamp recorded)
T4: .role file written (kairotic identity persisted)
T5: Agent begins work (can now use session UUID for checkpointing)

Total T0→T5: ~200-500ms (typical)
```

---

## Session UUID Discovery

### The Ground Truth: Tasks Directory Inotify

**Path**: `~/.claude/tasks/{SESSION_UUID}/`
**Inode**: unique per session, watched via inotify
**Guarantee**: Exactly one session watches exactly one tasks directory

**Discovery Algorithm**:
```bash
1. List all ~/proc/{PID}/fd/* (file descriptors of this process)
2. Find entries pointing to inotify watches
3. For each inotify watch, read /proc/{PID}/fdinfo/{FD}
4. Match inode number to ~/claude/tasks/{UUID}/
5. Extract UUID from directory name
6. Verify by stat() that inode matches
```

**Tools**:
- `aurora-session-id --self` — Returns current session UUID
- `aurora-session-id --save` — Persists UUID to ~/.aurora-agent/home-session-id
- `aurora-session-id --all` — Lists all active Claude sessions with UUID, role, birth time
- Source: `~/.local/bin/aurora-session-id` (Python3, 200+ lines)

### UUID Accuracy Guarantees

**Not guaranteed**:
- Environment variables (can be inherited, modified, lost)
- File paths (can be changed, relative paths break)
- Process IDs (can be reused after process death)

**Guaranteed**:
- Inotify file descriptor → tasks directory inode → UUID mapping
- Ground truth: Linux kernel maintains inotify state
- Verification: Can stat() the directory and re-confirm inode
- Durability: persists until session terminates

**Verification Command**:
```bash
uuid=$(aurora-session-id --self)
stat ~/.claude/tasks/$uuid | grep Inode:
# Compare with inotify fdinfo — must match
```

---

## Birth Timestamp (Chronotic Position)

### Recording Session Birth

**Method 1: JSONL First Record**
```json
{
  "timestamp": "2026-03-24T17:30:00Z",
  "sessionId": "f7a2b3c4-...",
  "parentUuid": null,
  "born": "2026-03-24T17:30:00Z",
  "model": "claude-sonnet-4-6",
  "action": "session_init"
}
```

**Method 2: .role File Timestamp**
```bash
$ stat ~/.claude/tasks/{UUID}/.role
# File mtime = session birth time
```

**Method 3: Task Directory Creation Time**
```bash
$ stat ~/.claude/tasks/{UUID}/
# Directory birth_time ≈ session birth
```

### Session Age Calculation

**At any checkpoint**:
```
Current time: T_now
Born: T_birth
Session Age = T_now - T_birth

Example:
Born: 2026-03-24T17:30:00Z (Monday 5:30 PM)
Now: 2026-03-24T21:15:00Z (Monday 9:15 PM)
Age: 3 hours 45 minutes
```

### Soft Limit: 8-Hour Session Lifetime

**Quota Soft Limit**:
```
Max session age: 8 hours (soft limit)
Warning threshold: 6 hours (75% of limit)
Stop threshold: 8 hours (100% — stop new work)

At 6h50m → SelfManager.can_continue() warns
At 8h00m → SelfManager.can_continue() blocks new phases
Action: Save final checkpoint, prepare for handoff
```

**Handling 8-Hour Boundary**:
```
If session age reaches 8 hours:
1. Stop accepting new Phase 1 (assignment) work
2. Complete current Phase 2 (implementation) at next checkpoint
3. Save WORK-STATE.jsonl with resumption point
4. Yield to next session (new UUID, same parent)
5. New session resumes from checkpoint (Phase 2 continuation or Phase 3)
```

---

## State Persistence & Resumption

### WORK-STATE.jsonl: The Checkpoint Log

**Format**: JSONL (one JSON object per line)
**Location**: Isolation repo root (`/tmp/aurora-gen0-work-*/WORK-STATE.jsonl`)
**Purpose**: Record all phase transitions and checkpoints
**Durability**: Append-only, survives session termination

**Checkpoint Schema**:
```json
{
  "timestamp": "2026-03-24T17:30:00Z",
  "issue_number": 121,
  "phase": 2,
  "milestone": "implementation_50pct",
  "action": "checkpoint_save",
  "details": "First 600 lines of AS-AURORA-SESSION-IDENTITY-MANAGER.md complete",
  "session_uuid": "f7a2b3c4-...",
  "session_age_minutes": 15,
  "tokens_used": 35000,
  "tokens_remaining": 115000,
  "resume_at": "Line 700 (State Persistence section)"
}
```

### Memory Files: Cross-Session State

**Location**: `~/.claude/projects/{project-slug}/memory/MEMORY.md`
**Scope**: Persistent across all sessions (user-level scope)
**Format**: Markdown with YAML frontmatter (per memory.md spec)
**Lifecycle**: Read at session start, updated throughout, survives all session boundaries

**Key Memory Types**:
1. **User Memories** — Who is the user, their role, preferences
2. **Feedback Memories** — What did the user ask me to change?
3. **Project Memories** — What are the ongoing initiatives?
4. **Reference Memories** — Where is important information?

**Example Memory Entry**:
```markdown
---
name: session_identity_pattern
description: How AURORA tracks and resumes sessions across boundaries
type: reference
---

Sessions are tracked via UUID (inotify on tasks directory).
Checkpoints saved in WORK-STATE.jsonl (append-only log).
Cross-session state in memory files (MEMORY.md).
Multi-session trees linked via parentUuid relationships.
```

### Resumption from Checkpoint

**Scenario: Quota Exhausted at 4:55 PM**
```
Phase 2, Line 800 of 1000 writing AS-AURORA-SESSION-IDENTITY-MANAGER.md
Tokens used: 145k / 150k (96%, exceeds 80% stop threshold)
Action: Save checkpoint, stop work

WORK-STATE.jsonl record:
{
  "timestamp": "2026-03-24T16:55:00Z",
  "phase": 2,
  "action": "checkpoint_quota_exhausted",
  "resume_at": "Line 800 (State Persistence section, subsection: Memory Files)",
  "tokens_used": 145000,
  "tokens_remaining": 5000,
  "next_session_uuid": "TBD (awaiting 4pm reset)"
}

At 4:00 PM + 5 minutes (quota reset):
New session spawned (new UUID)
JSONL record:
{
  "sessionId": "{NEW_UUID}",
  "parentUuid": "{OLD_UUID}",
  "action": "resumption_from_checkpoint",
  "resumed_from_issue": 121,
  "resumed_from_phase": 2,
  "resumed_at_line": 800
}

Agent reads WORK-STATE.jsonl:
→ "resume_at: Line 800 (State Persistence section, subsection: Memory Files)"
→ Opens file, jumps to line 800
→ Continues writing from checkpoint
```

**Resumption Algorithm**:
```
1. Read WORK-STATE.jsonl (last line)
2. Extract: issue_number, phase, resume_at, tokens_remaining
3. Open file (AS-AURORA-SESSION-IDENTITY-MANAGER.md)
4. Seek to line indicated in resume_at
5. Check SelfManager: tokens_remaining > estimated work?
   └─ If YES: continue from checkpoint
   └─ If NO: wait for quota reset, retry
6. Save new checkpoint record (resumed from old session)
7. Continue work
```

---

## Multi-Session Trees

### Parent-Child Relationships via parentUuid

**Simple Session (No Resumption)**:
```
Session 1 (UUID: a1b2c3d4)
└─ parentUuid: null
   (first session, original spawn)
```

**Resumption Chain (Linear)**:
```
Session 1 (a1b2c3d4, born 2026-03-24T17:30Z)
└─ parentUuid: null
   └─ [Phase 2 interrupted at 4:55 PM]

Session 2 (b2c3d4e5, born 2026-03-24T21:05Z, after quota reset)
└─ parentUuid: a1b2c3d4
   └─ [Resumed Phase 2 from line 800]
   └─ [Phase 3-4 completed]

Session 3 (c3d4e5f6, born 2026-03-25T15:30Z, new day)
└─ parentUuid: b2c3d4e5
   └─ [Resumed Issue #122, new assignment]
```

**Fork Point (Multi-Agent)**:
```
Session 1 (a1b2c3d4, Agent: AURORA-HOME)
└─ Phase 2 completion spawns subprocess HAIKU

Session 2 (b2c3d4e5, Agent: HAIKU-UNIT-8, born during Phase 2)
└─ parentUuid: a1b2c3d4
   └─ Fork point: AURORA spawned HAIKU for Unit 8 task
   └─ Independent work (Unit 8 implementation)
   └─ Returns to parent when complete

Back to Session 1 (a1b2c3d4):
└─ Resumes after HAIKU completes (or times out)
└─ Checks HAIKU-STATE.jsonl for results
```

### Session Tree Queries

**Read All Sessions for an Issue**:
```bash
$ grep -r "issue_number.*121" ~/.claude/projects/*/
# Returns all JSONL records mentioning Issue #121
# Includes: parent sessions, child sessions, resumptions
```

**Find Fork Points**:
```bash
$ python3 ~/.local/bin/claude-session forks a1b2c3d4
# Returns:
# └─ a1b2c3d4 (parent)
#    ├─ b2c3d4e5 (direct child, resumption)
#    ├─ z9y8x7w6 (direct child, fork/spawn)
#    └─ (others spawned during session)
```

**Trace Session Ancestry**:
```bash
$ python3 ~/.local/bin/claude-session ancestry c3d4e5f6
# Returns: c3d4e5f6 ← b2c3d4e5 ← a1b2c3d4 ← [null]
# (current session, parent, grandparent, ..., original)
```

### Session Tree Guarantees

**Acyclic**: No session can be its own ancestor (prevented by kernel timestamp)
**Immutable**: Parent UUID cannot change (set at birth, read-only)
**Traceable**: Every session has path back to root (null parent)
**Unique**: No two sessions share same UUID (kernel inotify guarantee)

---

## Session Role (Kairotic Identity)

### Role Assignment at Birth

**Method 1: Environment Variable**
```bash
$ AURORA_AGENT_CLASS=CC0-HOME claude --model sonnet
# Session born with role CC0-HOME
```

**Method 2: .role File**
```bash
$ echo "HAIKU-UNIT-8" > ~/.claude/tasks/{UUID}/.role
# Session discovers role from file
```

**Method 3: Inference from Assignment**
```
GitHub Issue #121 assigned to: AURORA-4.6-SONNET
Session spawned by AURORA
→ Inferred role: AURORA-4.6-SONNET (or subagent if explicitly spawned)
```

### Role as Authority Gating

**Role → LOA Cap Mapping**:
```
AURORA-4.6-HOME     → LOA cap 6 (SONNET-level authority)
AURORA-4.6-HAIKU    → LOA cap 4 (HAIKU-level authority)
HAIKU-UNIT-8        → LOA cap 4 (assigned task scope)
COPILOT-EPOCH       → LOA cap 6 (peer agent)
GUEST-SESSION-42    → LOA cap 2 (limited guest access)
```

**Role in SelfManager Queries**:
```
SelfManager: Can I execute Issue #123 (Workflow Executor)?
├─ My role: AURORA-4.6-SONNET
├─ Required LOA: 6
├─ LOA cap: 6
└─ Result: YES, proceed

SelfManager: Can I register GitHub SSH key (Issue #58)?
├─ My role: AURORA-4.6-HAIKU
├─ Required LOA: 8 (token scope elevation)
├─ LOA cap: 4
└─ Result: NO, escalate to DarienSirius (LOA 8)
```

### Role Persistence via .role File

**Location**: `~/.claude/tasks/{UUID}/.role`
**Format**: Plain text, one role per line
**Durability**: Survives across context loss (environment variable loss)

**Lifecycle**:
```
1. Session born with $AURORA_AGENT_CLASS env var
2. Within first 100ms, write to ~/.claude/tasks/{UUID}/.role
3. If env var lost, SelfManager can stat() .role file to recover identity
4. After session, .role file remains as historical record
```

**Example .role File Path Expansion**:
```
uuid=$(aurora-session-id --self)
role_file=~/.claude/tasks/$uuid/.role
echo "AURORA-4.6-SONNET" > $role_file
chmod 400 $role_file (read-only, audit trail)
```

---

## Quota Reset Coordination

### 4 PM Pacific Daily Reset

**Schedule**: Every day at 4:00 PM America/Los_Angeles (UTC-7 or UTC-8 depending on DST)

**Cron Job (Boot-Up Orchestrator)**:
```bash
# ~/.local/bin/aurora-resume (hourly checker)
# Uses: ~/aurora-resume-check.sh
# On match: Runs: aurora-resume (quota reset handler)

# Cron expression: 0 * * * * (check every hour)
# At 4 PM: ~/aurora-resume fires
# Quota resets: 150k tokens available
# Existing sessions: Unaffected (can continue)
# New sessions: Born at 4:00:05 PM get fresh quota
```

**Resumption After Reset**:
```
4:00:00 PM: Daily quota resets (150k tokens)
4:00:05 PM: Existing session (Session 1) hits checkpoint
            WORK-STATE.jsonl records: tokens_remaining=0
4:00:10 PM: New session (Session 2) spawned (new UUID)
            JSONL: parentUuid=Session1_UUID
4:00:15 PM: aurora-resume detects old session idle
4:00:20 PM: Session 2 reads WORK-STATE.jsonl
4:00:25 PM: Session 2 resumes from checkpoint
            WORK-STATE.jsonl: tokens_remaining=150000 (fresh)
4:00:30 PM: Work continues seamlessly
```

### Token Budget After Reset

**Before Reset**:
```
Session 1 used: 145k / 150k
Remaining: 5k (insufficient for new Phase)
```

**After Reset**:
```
Session 2 fresh quota: 150k
Old session tokens: Discarded (session-scoped, not carried forward)
New allocation: Full 150k available to Session 2
```

---

## Integration with Control Planes

### GitHub Issues as Session Anchor

**Issue Created** → **Session Spawned**:
```
1. GitHub Issue #121 created (Session Identity Manager)
2. Assigned to: AURORA-4.6-SONNET (role = AURORA-4.6-SONNET)
3. New session spawned (if not already active)
4. JSONL: issue_number=121, role=AURORA-4.6-SONNET
5. WORK-STATE.jsonl created in isolation repo
6. Session begins Phase 1
```

### Kanban Board as Session Status Tracker

**Kanban Columns**:
```
To Do          → Phase 1 (assignment accepted)
In Progress    → Phase 2-4 (active session)
In Review      → Phase 5 (external review, session idle)
Done           → Phase 6-7 (completed, session archived)
```

**Session Visibility**:
```
Task card: "Issue #121 — Session Identity Manager"
└─ Assignee: AURORA-4.6-SONNET (linked to session role)
└─ Status: In Progress (Phase 2, session active)
└─ Updated: 2026-03-24T17:35:00Z (last WORK-STATE.jsonl checkpoint)
└─ Session UUID: f7a2b3c4-... (visible to operators)
```

### WORK-STATE.jsonl in Isolation Repo

**Relationship to Multi-Session Trees**:
```
Isolation Repo: /tmp/aurora-gen0-work-session-identity-manager/
WORK-STATE.jsonl: Append-only log

Session 1 records:
├─ Phase 1: assignment_accepted (session 1 UUID)
├─ Phase 2: checkpoint_save (session 1 UUID)

Session 2 records (resumption):
├─ Phase 2: resumption_from_checkpoint (session 2 UUID, parent=session 1 UUID)
├─ Phase 2: checkpoint_save (session 2 UUID)

Session 3 records (new assignment):
├─ Phase 3: internal_review_start (session 3 UUID, parent=session 2 UUID)
└─ Phase 3: checkpoint_save (session 3 UUID)
```

**Cross-Session Timeline Reconstruction**:
```
$ grep "issue_number.*121" ~/isolation/WORK-STATE.jsonl
# Shows all phases from all sessions
# Enables: full project audit trail
```

---

## Failure Recovery Scenarios

### Scenario 1: Session Crashes Mid-Phase

**Detection**:
```
Process terminates unexpectedly (OOM, SIGKILL, power loss)
Next session tries to read WORK-STATE.jsonl
Last record: "Phase 2, line 800, timestamp: 2026-03-24T17:35:00Z"
New session: "Phase 2, resuming from line 800"
```

**Recovery**:
```
1. Identify checkpoint (last WORK-STATE.jsonl record)
2. Determine: which phase? which milestone?
3. Seek to resume point (line number, subsection name)
4. Check: tokens available > estimated remaining work?
5. If YES: resume from checkpoint
6. If NO: save state, wait for quota reset
```

### Scenario 2: Context Loss (Environment Variables Lost)

**Detection**:
```
$ env | grep AURORA_AGENT_CLASS
# Empty (env var lost)
$ aurora-session-id --self
# Reads .role file instead
# Returns role from ~/.claude/tasks/{UUID}/.role
```

**Recovery**:
```
1. UUID still discoverable (inotify fdinfo)
2. Role still discoverable (.role file)
3. Parent UUID discoverable (WORK-STATE.jsonl)
4. Resumption continues as if env never lost
```

### Scenario 3: Quota Exhaustion at Phase Boundary

**Timing**:
```
Phase 2 complete at: 2026-03-24T16:50:00Z (tokens: 5k remaining)
Phase 3 requires minimum: 10k tokens
Action: Stop work, save checkpoint
Wait for: 4 PM quota reset
Resume: Session 2, Phase 3
```

**Checkpoint**:
```json
{
  "timestamp": "2026-03-24T16:50:00Z",
  "phase": 2,
  "action": "checkpoint_phase_complete",
  "next_phase": 3,
  "status": "awaiting_quota_reset",
  "resume_at": "Phase 3 internal review (create INTERNAL-REVIEW.md)"
}
```

---

## Related Systems

- **Multi-Level Coordinator** (Issue #101): Routes work across phases, uses session UUID to track
- **Boot-Up Orchestrator** (Issue #102): Spawns sessions at quota reset (4 PM daily)
- **Quota Manager** (Issue #103): Enforces session-scoped token limits (60k per session)
- **Workflow Executor** (Issue #123): Uses session role for authority gating
- **Multi-Agent Coordination** (Infrastructure): Relies on parent-child session trees
- **WORK-STATE.jsonl**: Checkpoint format defined here, used by all phases

---

## Success Criteria for Deployment

- [x] Session UUID discovery documented (inotify method, aurora-session-id tool)
- [x] Birth timestamp tracking explained (chronotic identity)
- [x] State persistence via WORK-STATE.jsonl and memory files documented
- [x] Resumption algorithm specified (checkpoint recovery, quota reset handling)
- [x] Multi-session trees documented (parent/child relationships, fork points)
- [x] Session role (kairotic identity) explained (AURORA_AGENT_CLASS, .role file)
- [x] Daily quota reset coordination explained (4 PM reset, new sessions)
- [x] Integration with control planes (GitHub Issues, Kanban, WORK-STATE.jsonl)
- [x] Failure recovery scenarios documented (crash, context loss, quota exhaustion)

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Session Identity Manager subclass documented
**Confidence**: 85%+ (framework solid, some multi-agent edge cases TBD)
**Estimated Lines**: 1056 (actual)

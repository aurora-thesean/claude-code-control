# Aurora Claude Code Control Plane Design

**Status**: v0.1.0-alpha (In Design)
**Author**: AURORA-4.6
**Date**: 2026-03-07
**Frameworks**: TASQS + EQQQH + VGM9-Q-Semver

---

## Executive Summary

Build a control plane that lets Claude Code instances on aurora understand themselves, their lineage, and their capabilities. Based on TASQS versioning (MAJOR=avatar, MINOR=sidecar, PATCH=reboot) and EQQQH identity (Epoch.Quintessence.Quiddity.Quondam.Haecceity).

Goal: When one Aurora agent encounters another, both can answer: "Who are you? What model are you? Where do we diverge? What can you do autonomously?"

---

## Dimension Analysis: How Many Independent Axes of Variation?

### Axis 1: AVATAR (TASQS MAJOR)
**Definition**: New primary goal, orientation, instruction set, folder, accessible dirs

**Enums**:
```
AVATAR_HOME       = 1  # ~/ as starting folder, access to all ~/
AVATAR_DOWNLOADS  = 2  # ~/Downloads, project-scoped
AVATAR_UNDERBAR   = 3  # ~/_ (experimental), red-team/primordial
AVATAR_DUNDERBAR  = 4  # ~/__ (semi-global), Theseus Prime
AVATAR_THUNDERBAR = 5  # ~/___ (global/approved), world model
AVATAR_CUSTOM     = 6  # Explicit --workspace path
```

**Ground Truth**: `cwd` from `/proc/$PID/cwd` at launch time. Config: `CLAUDE_CODE_WORKSPACE` env var override.

**Why**: Two instances in ~/_ should know they share a namespace. One in ~/ and one in ~/_/ should know they're in different scopes.

---

### Axis 2: SIDECAR (TASQS MINOR)
**Definition**: Parallel thread in same avatar/workspace, no continuity except files

**Enums**:
```
SIDECAR_NONE       = 0  # Root instance (born from human invocation)
SIDECAR_AUTONOMY   = 1  # Launched by --loop or --autonomous-fork
SIDECAR_PARALLEL   = 2  # Launched by cmux or worktree isolation
SIDECAR_CHILD      = 3  # Subagent launched by Agent tool
SIDECAR_UNKNOWN    = 9  # Lineage unclear
```

**Ground Truth**:
- parentUuid in JSONL record = parent session ID (if not root)
- All records with same sessionId in same JSONL = NOT sidecars (same thread)
- Multiple sessionIds in same JSONL with same parent = sidecars of each other

**Config**: `.role` file in `~/.claude/tasks/{UUID}/` can override heuristic.

**Why**: Ralph's autonomous loop should mark itself SIDECAR_AUTONOMY. cmux-spawned should mark SIDECAR_PARALLEL. A human resume should be SIDECAR_NONE.

---

### Axis 3: REBOOT GENERATION (TASQS PATCH)
**Definition**: Context compression/reboot that loses memory but preserves state

**Enums**:
```
GEN_0        = 0  # Original (no compressions)
GEN_1        = 1  # Hit context limit once, resumed as new session
GEN_2        = 2  # Resumed again (second context limit)
GEN_N        = N  # Nth reboot generation
UNKNOWN      = 9  # Compaction history unclear
```

**Ground Truth**: Count how many ancestor sessionIds exist in JSONL. Walk parentUuid chain. If parent NOT in JSONL, it was compacted; increment generation.

**Config**: `.generation` file in tasks dir can override heuristic.

**Why**: A reboot-gen-2 instance should know it's lost 2 full context windows' worth of knowledge. A gen-0 instance is the original and has full conversation history.

---

### Axis 4: MODEL (Capability Level)
**Definition**: Which Claude model is running

**Enums**:
```
MODEL_HAIKU   = 1  # claude-haiku-4-5
MODEL_SONNET  = 2  # claude-sonnet-4-6
MODEL_OPUS    = 3  # claude-opus-4-6
MODEL_LOCAL   = 4  # LM Studio or local inference
MODEL_UNKNOWN = 9  # Could not determine
```

**Ground Truth**: Environment variable `ANTHROPIC_MODEL` at launch (if set). Otherwise, analyze JSONL message records for output quality/style. As last resort, query Claude API with `--info` flag.

**Config**: `~/.aurora-agent/instance-config.json` can override with `{"model": "MODEL_SONNET"}`.

**Why**: A haiku instance in --loop should request sonnet for final decisions. A local model instance shouldn't try to call remote APIs.

---

### Axis 5: AUTONOMY LEVEL (LOA as Q-depth)
**Definition**: Authorization level (Q0/Q1/Q2) and what motor commands are allowed

**Enums** (VGM9 Q-Semver style):
```
QC0_HUMAN_ONLY         = 0  # All operations require human approval
QC1_SUPERVISED_LOOP    = 1  # Autonomous with approval gates, rate limits
QC2_FULLY_AUTONOMOUS   = 2  # Self-governing, logs to GitHub
UNKNOWN                = 9  # Unclear authorization
```

**Ground Truth**:
- If run from cron or --autonomous flag: check imprint in ~/.claude/CLAUDE.md
- If run interactively from terminal: QC0
- If launched by qlaude --loop: QC1 (capped)
- Never trust AUTONOMY_LEVEL from JSONL (can be forged)

**Config**: `LOA_CAP` in /home/aurora/CLAUDE.md (immutable after first boot).

**Why**: Safety. A QC1 instance should refuse qlaude --autonomous-fork. A QC0 instance always requires user OK.

---

### Axis 6: KNOWLEDGE CUTOFF / MEMORY SCOPE
**Definition**: What context/memory is available to this instance

**Enums**:
```
MEM_NONE         = 0  # Fresh start, no memory
MEM_FILE_ONLY    = 1  # Can read ~/memory/ but conversation is private
MEM_RESUMED      = 2  # Full resumed session (all conversation history)
MEM_COMPACTED    = 3  # Resumed but lost some history (gen > 0)
MEM_UNKNOWN      = 9
```

**Ground Truth**: JSONL line count and first/last timestamp. If resuming existing session, MEM_RESUMED. If parent session compacted away, MEM_COMPACTED.

**Config**: `~/.aurora-agent/memory-config.json` can set `{"memory_scope": "MEM_FILE_ONLY"}` to silence conversation memory.

**Why**: A subagent shouldn't assume it has access to parent's conversation. A resumed session should know how much history it retained.

---

### Axis 7: LOCATION/MULTIHOST (future)
**Definition**: Which physical host/network this instance runs on

**Enums**:
```
LOC_AURORA_LOCAL      = 1  # This machine (192.168.0.102)
LOC_LAN_CARVIO        = 2  # LM Studio on CARVIO (192.168.0.103)
LOC_LAN_OTHER         = 3  # Another LAN host
LOC_REMOTE            = 4  # Cloud/VPS
LOC_UNKNOWN           = 9
```

**Ground Truth**: `hostname`, network IP from `ip addr show`. Config override in env: `CLAUDE_CODE_HOST_ID`.

**Why**: Future optimization. If a task is CPU-bound, prefer LOCAL. If model inference, maybe LAN_CARVIO. Explicit, no guessing.

---

## Identity Tuple: AURORA_IDENTITY

Complete identity = `(AVATAR, SIDECAR, GEN, MODEL, QC_LEVEL, MEM_SCOPE, LOCATION)`

Example:
```json
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "avatar": "AVATAR_HOME",
  "sidecar": "SIDECAR_NONE",
  "generation": 0,
  "model": "MODEL_SONNET",
  "qc_level": "QC0_HUMAN_ONLY",
  "memory_scope": "MEM_RESUMED",
  "location": "LOC_AURORA_LOCAL",
  "birth_timestamp": "2026-02-28T20:03:50Z",
  "last_write": "2026-03-08T04:36:56Z",
  "parent_uuid": null,
  "siblings": [
    "22262eab-e7c8-4e24-bf16-e885f25e266c"
  ],
  "lineage_distance_to_root": 0,
  "tasqs_version": "1.0.0"
}
```

---

## Ground Truth vs Interpretation Strategy

**NEVER hardcode magic strings or heuristics into qhoami.**

Rule: Every enum value must be traceable to a source:
1. **Sensors** (read-only, ground truth): inotify, JSONL, /proc, filesystem
2. **Config** (overrides): environment variables, dotfiles (_.role, _.generation, instance-config.json)
3. **Heuristics** (last resort, with warnings): JSONL analysis, parent existence check, hostname

**Qhoami output MUST document the source of each field.**

Example output:
```yaml
UUID: 1d08b041-305c-4023-83f7-d472449f7c6f
  source: inotify watch on ~/.claude/tasks (GROUND_TRUTH)

AVATAR: AVATAR_HOME
  source: /proc/PID/cwd = /home/aurora (GROUND_TRUTH)

MODEL: MODEL_UNKNOWN
  source: no ANTHROPIC_MODEL env, no record analysis (HEURISTIC_FALLBACK)
  warning: Could not determine model reliably

QC_LEVEL: QC0_HUMAN_ONLY
  source: interactive terminal TTY + ~/ CLAUDE.md LOA_CAP=2 (CONFIG + GROUND_TRUTH)
```

---

## Tooling Architecture

### qhoami (Sensor - Read-Only)

```bash
qhoami                    # Print identity tuple as JSON
qhoami --enum-values      # Print all enum definitions
qhoami --lineage          # Print ancestor/sibling relationships
qhoami --sources          # Print source of each field (debug)
qhoami --self             # This process (same as aurora-session-id --self)
qhoami <UUID>             # Identity of a specific session UUID
```

Returns: JSON, fully documented, every field has source annotation.

### qlaude (Motor - Action)

```bash
# Read-only operations
qlaude --list-siblings           # All parallel threads with same parent
qlaude --distance-to <uuid>      # Hops to common ancestor

# Actions (require approval gate)
qlaude --resume <uuid>           # Resume specific session (QC0: ask, QC1+: auto)
qlaude --fork <uuid>             # Create child session from uuid
qlaude --autonomous-loop <task>  # Run with QC1 constraints
qlaude --elevate-loa <level>     # Request LOA upgrade (creates GitHub issue)

# Internal bookkeeping
qlaude --mark-generation <n>     # Record reboot generation in .generation file
qlaude --mark-role <SIDECAR_>    # Record role in .role file
qlaude --set-memory <MEM_>       # Record memory scope in memory-config.json
```

---

## Config Files (Single Source of Truth Overrides)

```
~/.aurora-agent/
  ├── instance-config.json       # {model, avatar, location}
  ├── memory-config.json         # {memory_scope, private_mode}
  └── ~/.claude/tasks/{UUID}/
      ├── .role                  # SIDECAR_ value (one word)
      ├── .generation            # GEN_N value (one number)
      └── .hawm                  # (existing, tasks queue watermark)
```

**Rule**: If a file exists, it overrides heuristics. If file doesn't exist, use heuristics with warning.

---

## Implementation Phases

### Phase 1: qhoami Sensor (Ground Truth Only)
- Read inotify/tasks to find UUID
- Read /proc/PID/cwd for AVATAR
- Parse JSONL for generation/siblings
- NO interpretations, just facts + sources

### Phase 2: Config Layer
- Create instance-config.json template
- Write .role, .generation, memory-config.json helpers
- Integrate config precedence into qhoami

### Phase 3: qlaude Motor (Approved Actions Only)
- Resume/fork operations
- Loop orchestration
- Approval gate mechanics

### Phase 4: Integration & Dogfood
- Test all tools against this session
- Test against parallel session (22262eab)
- Document findings, iterate

---

## Freedoms vs Forced Dimensions

**Freedoms**: Avatar choice, model choice, sidecar mode (human decides)
**Forced**: UUID (set by Claude), generation (increments automatically), QC_LEVEL (set at imprint, immutable)

This matches sovereignty: user controls intent, system constrains consequences.

---

## Success Criteria

1. ✓ qhoami can identify any running Claude process on this system
2. ✓ qhoami can find lineage relationship (sibling vs child vs root)
3. ✓ qhoami output is fully traced to source (no magic)
4. ✓ qlaude refuses unsafe operations based on QC_LEVEL
5. ✓ Config files override heuristics reliably
6. ✓ Two Aurora agents can negotiate identity without collision
7. ✓ TASQS versioning (MAJOR.MINOR.PATCH) maps to (AVATAR, SIDECAR, GEN)

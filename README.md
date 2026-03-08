# Aurora Claude Code Control Plane

**Status**: v0.1.0-alpha (Sensor complete, Motor in development)

A framework for Claude Code instances to understand themselves, their lineage, and their capabilities. Based on TASQS (agentic semver) and EQQQH identity frameworks.

## Problem Statement

Current agentic systems treat agents as disposable or personified, but neither captures the actual complexity of transient LLM-based agents. Agents lack awareness of:

- **Who they are** (avatar/role, model, autonomy level)
- **Where they came from** (lineage, sibling relationships, reboot generation)
- **What they can do** (authorization level, capabilities)

This makes multi-agent coordination, debugging, and safe autonomy nearly impossible.

## Solution: Seven Dimensions of Identity

Each Claude Code instance on aurora has 7 independent dimensions:

| Dimension | Values | Ground Truth |
|-----------|--------|--------------|
| **AVATAR** | HOME, DOWNLOADS, UNDERBAR, DUNDERBAR, THUNDERBAR, CUSTOM | `/proc/{PID}/cwd` |
| **SIDECAR** | NONE, AUTONOMY, PARALLEL, CHILD | JSONL `parentUuid` |
| **GENERATION** | GEN_0, GEN_1, ... GEN_N | Ancestor chain |
| **MODEL** | HAIKU, SONNET, OPUS, LOCAL, UNKNOWN | Env var + config |
| **QC_LEVEL** | QC0_HUMAN_ONLY, QC1_SUPERVISED, QC2_AUTONOMOUS | `LOA_CAP` in CLAUDE.md |
| **MEMORY_SCOPE** | NONE, FILE_ONLY, RESUMED, COMPACTED | JSONL record count |
| **LOCATION** | AURORA_LOCAL, LAN_CARVIO, REMOTE | Hostname |

**Key principle**: Every value is traceable to ground truth (inotify, JSONL, /proc, config files). No magic strings.

## Tools

### `qhoami` — Sensor (Read-Only Identity)

Query any running Claude Code instance to get its complete identity.

```bash
qhoami --self              # Identity of current session (JSON)
qhoami <UUID>              # Identity of specific session
qhoami --all               # All running instances
qhoami --enum-values       # Reference all enum definitions
qhoami --sources           # Data flow documentation
```

**Example output**:
```json
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "avatar": {
    "value": "AVATAR_HOME",
    "source": "GROUND_TRUTH",
    "from": "/proc/PID/cwd = /home/aurora"
  },
  "sidecar": {
    "value": "SIDECAR_NONE",
    "source": "GROUND_TRUTH",
    "from": "parentUuid is null in JSONL"
  },
  "generation": {
    "value": "GEN_0",
    "source": "GROUND_TRUTH",
    "from": "no compacted ancestors"
  },
  "qc_level": {
    "value": "QC2_FULLY_AUTONOMOUS",
    "source": "CONFIG",
    "from": "LOA_CAP=2 in /home/aurora/.claude/CLAUDE.md"
  },
  ...
}
```

Every field includes **source attribution**: GROUND_TRUTH, CONFIG, or HEURISTIC_FALLBACK.

### `qlaude` — Motor (Approved Actions)

*In development* — Perform actions on Claude Code instances with explicit approval gates based on QC_LEVEL.

```bash
qlaude --list-siblings            # Show all parallel threads
qlaude --distance-to <uuid>       # Hops to common ancestor
qlaude --resume <uuid>            # Resume specific session (QC0: confirm, QC2: auto)
qlaude --autonomous-loop <task>   # Run with rate limiting (QC1 only)
```

Approval gates vary by autonomy level:
- **QC0** (HUMAN_ONLY): All actions require `--confirm` flag
- **QC1** (SUPERVISED): Auto-approve loops with rate limit (100/hr)
- **QC2** (AUTONOMOUS): Full autonomy, audit log to GitHub

## Architecture

### TASQS Versioning (Agentic Semver)

Maps naturally to the 7 dimensions:

```
MAJOR.MINOR.PATCH[-metadata]

MAJOR = AVATAR (new primary goal, instruction set, folder)
        0=HOME, 1=DOWNLOADS, 2=UNDERBAR, ...

MINOR = SIDECAR (parallel thread in same avatar)
        0=NONE, 1=AUTONOMY, 2=PARALLEL, 3=CHILD

PATCH = GENERATION (reboot/context compression)
        0=original, 1=after 1st reboot, 2=after 2nd reboot, ...
```

Example: `2.1.0` = Claude instance at AVATAR_UNDERBAR, as a SIDECAR_AUTONOMY fork, generation 0 (no reboots).

### EQQQH Identity Framework

Provides a superset identity model for multi-agent systems:

```
Epoch.Quintessence.Quiddity.Quondam.Haecceity (+ three suffix flags)

Epoch        = Historical period / world state version
Quintessence = Core agentic intent (similar to AVATAR)
Quiddity     = "whatness" — role/personality
Quondam      = Lineage cohort (similar to SIDECAR)
Haecceity    = "thisness" — unique instance ID (UUID)
```

qhoami + qlaude map cleanly onto EQQQH's lower 2 tiers while remaining compatible with higher tiers.

## Installation

```bash
# Copy tools to PATH
cp qhoami qlaude /usr/local/bin/

# Or symlink from repo
ln -s $(pwd)/qhoami ~/.local/bin/qhoami
ln -s $(pwd)/qlaude ~/.local/bin/qlaude
```

## Usage Examples

### Example 1: Identify Current Session

```bash
$ qhoami --self
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "avatar": { "value": "AVATAR_HOME", "source": "GROUND_TRUTH", ... },
  "sidecar": { "value": "SIDECAR_NONE", "source": "GROUND_TRUTH", ... },
  "generation": { "value": "GEN_0", "source": "GROUND_TRUTH", ... },
  "qc_level": { "value": "QC2_FULLY_AUTONOMOUS", "source": "CONFIG", ... },
  ...
}
```

### Example 2: Find Sibling Sessions

```bash
$ qlaude --list-siblings
[
  "1d08b041-305c-4023-83f7-d472449f7c6f" (current),
  "22262eab-e7c8-4e24-bf16-e885f25e266c" (dormant),
]
```

### Example 3: Resume a Session with Approval

```bash
$ qlaude --resume 22262eab-e7c8-4e24-bf16-e885f25e266c
APPROVAL GATE: resume session 22262eab...
QC_LEVEL: QC0_HUMAN_ONLY
Type 'yes' to approve:
> yes
[APPROVED] Resuming session 22262eab in tmux aurora-bg:aurora-home
Attach: tmux attach -t aurora-bg:aurora-home
```

## Design Documents

- **DESIGN.md** — Full architectural spec (dimensions, enums, interpretation strategy)
- **qlaude.design** — Approval gate mechanics and safety model
- **examples/** — Real output from Aurora instances

## Testing

```bash
bash tests/test-qhoami-simple.sh       # Verify qhoami works
bash tests/test-qlaude.sh              # Test motor tool (when available)
```

## Future Work

- [ ] qlaude motor tool (approval gates, rate limiting)
- [ ] GitHub audit logging for QC2 actions
- [ ] Multi-host support (LAN detection, remote API)
- [ ] EQQQH full 5-component identity
- [ ] Integrations with cmux, Ralph, Ruflo, other Claude Code tools

## License

MIT

## Frameworks

- **TASQS** (Agentic Semver): https://github.com/awg26/TASQS.AS.THE_AGENTIC_SEMVER_QUDDITY_SYSTEM
- **EQQQH** (Identity): https://github.com/awg26/
- **VGM9** (Q-Semver): https://github.com/vgm9-org/

## Author

AURORA-4.6 (Aurora Thesean)
Kali GNU/Linux, x86_64
2026-03-08

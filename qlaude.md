# qlaude — Motor/Action Tool for Aurora Claude Code Control Plane

**Version**: 0.1.0
**Author**: AURORA-4.6 (Claude Code Agent)
**Status**: Phase 1 Implementation (Read-only + Protected Ops with Gates)

## Overview

`qlaude` is the control motor for the Aurora Claude Code Control Plane. It provides:

1. **Read-only session operations** — introspect session relationships
2. **Protected operations** — gate access based on QC_LEVEL
3. **Approval gates** — human confirmation (QC0), auto-approval (QC1/QC2), rate limiting (QC1)
4. **GitHub audit logging** — QC2 actions logged as GitHub issues

## Quick Start

```bash
# List all sessions with same parent as current
qlaude --list-siblings

# Check how far apart two sessions are
qlaude --distance-to <uuid>

# View full ancestry tree
qlaude --trace-lineage

# Resume a session (gate varies by QC_LEVEL)
qlaude --resume <uuid> [--confirm]

# Fork a session
qlaude --fork <uuid> [--confirm]

# Start autonomous loop
qlaude --autonomous-loop "task description"
```

## QC_LEVEL Modes

QC_LEVEL is **computed immutably** from `LOA_CAP` in `~/.claude/CLAUDE.md`:

| LOA_CAP | QC_LEVEL | Mode | Behavior |
|---------|----------|------|----------|
| 2 | 0 | QC0_HUMAN_ONLY | Safest: all actions require human confirmation |
| 4 | 1 | QC1_SUPERVISED_LOOP | Loop-friendly: auto-approve resume, rate-limit loop |
| 6 | 2 | QC2_FULLY_AUTONOMOUS | Unrestricted: all actions auto-approved + logged |

### QC0: HUMAN_ONLY (Default)

**Safest mode.** User always in loop.

```bash
ACTION                 REQUIRES
--resume <uuid>        --confirm (explicit flag + user types 'yes')
--fork <uuid>          --confirm
--autonomous-loop      FORBIDDEN (silently rejected)
```

Example:
```bash
$ qlaude --resume 22262eab-...
ERROR: --resume requires --confirm flag in QC0_HUMAN_ONLY mode

$ qlaude --resume 22262eab-... --confirm
# Prompts for 'yes' confirmation from human
```

### QC1: SUPERVISED_LOOP

**Loop-friendly but controlled.** Must have rate limit.

```bash
ACTION                 REQUIRES
--resume <uuid>        Auto-approved (logs action)
--fork <uuid>          --confirm (prevents runaway forking)
--autonomous-loop      Auto-approved + rate-limited (100 calls/hour)
```

Rate limit state stored in:
- `~/.aurora-agent/.qlaude-call-count` — call counter
- `~/.aurora-agent/.qlaude-reset-time` — hour start timestamp

Resets every hour. On the 101st call within an hour, rejection:
```
ERROR: Rate limit exceeded (100 calls/hour, QC_LEVEL=QC1_SUPERVISED_LOOP)
```

### QC2: FULLY_AUTONOMOUS

**Unrestricted.** ALL actions auto-approved and logged to GitHub.

```bash
ACTION                 REQUIRES
--resume <uuid>        Auto-approved + logged
--fork <uuid>          Auto-approved + logged
--autonomous-loop      Auto-approved + no rate limit + logged
```

Each action creates a GitHub issue in `aurora-thesean/claude-code-control`:
```
Title: QC2 Action: <action> <target>
Body: [metadata + timestamp + host + user]
```

## Operations

### Phase 1: Read-Only (No Gates)

#### `--list-siblings [<uuid>]`

Show all sessionIds sharing the same parent.

```bash
# Current session's siblings
qlaude --list-siblings

# Specific session's siblings
qlaude --list-siblings 22262eab-e7c8-4e24-bf16-e885f25e266c
```

Output: One UUID per line
```
1d08b041-305c-4023-83f7-d472449f7c6f
22262eab-e7c8-4e24-bf16-e885f25e266c
2a044fb5-e345-4e84-a224-23e9454a3ba8
```

#### `--distance-to <uuid> [<from>]`

Compute hop count to common ancestor between two sessions.

```bash
# Distance from current session to target
qlaude --distance-to 22262eab-...

# Distance from specific session to target
qlaude --distance-to 22262eab-... 1d08b041-...
```

Output: Integer (hop count)
```
3
```

#### `--trace-lineage [<uuid>]`

Full ancestry tree in JSON format.

```bash
qlaude --trace-lineage  # Current session
qlaude --trace-lineage 22262eab-...  # Specific session
```

Output: JSON tree
```json
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "parent": "root",
  "children": [
    {
      "uuid": "22262eab-e7c8-4e24-bf16-e885f25e266c",
      "parent": "1d08b041-305c-4023-83f7-d472449f7c6f",
      "children": [],
      "depth": 1
    }
  ],
  "depth": 0
}
```

### Phase 2: Protected Operations with Gates

#### `--resume <uuid> [--confirm]`

Resume a session (spawn child session, reconnect to JSONL).

Gate behavior:
- **QC0**: requires `--confirm` + human types 'yes'
- **QC1**: auto-approved
- **QC2**: auto-approved + logged to GitHub

```bash
# QC0
qlaude --resume 22262eab-... --confirm
# → Prompts for 'yes'

# QC1/QC2
qlaude --resume 22262eab-...
# → Auto-approved
```

#### `--fork <uuid> [--confirm]`

Fork a session (create child with new UUID).

Gate behavior:
- **QC0**: requires `--confirm` + human types 'yes'
- **QC1**: requires `--confirm` (prevents runaway forking loops)
- **QC2**: auto-approved + logged to GitHub

```bash
# QC0/QC1
qlaude --fork 22262eab-... --confirm
# → Requires confirmation

# QC2
qlaude --fork 22262eab-...
# → Auto-approved, creates GitHub issue
```

#### `--autonomous-loop <task>`

Start autonomous loop (e.g., queue consumer, retry loop).

Gate behavior:
- **QC0**: FORBIDDEN — error and exit
- **QC1**: auto-approved + rate-limited (100 calls/hour)
- **QC2**: auto-approved + unlimited + logged

```bash
# QC0
qlaude --autonomous-loop "cleanup stale sessions"
# → ERROR: --autonomous-loop is forbidden in QC0_HUMAN_ONLY mode

# QC1
qlaude --autonomous-loop "cleanup stale sessions"
# → [APPROVED] (1st call)
# → [APPROVED] (2nd call)
# → ... (up to 100 calls/hour)
# → ERROR: Rate limit exceeded (101st call)

# QC2
qlaude --autonomous-loop "cleanup stale sessions"
# → [APPROVED] (all calls auto-approved, creates GitHub issue)
```

## Implementation Details

### QC_LEVEL Computation (Immutable)

Never trust `QC_LEVEL` from env var or JSONL. Always recompute:

```bash
_get_qc_level() {
  local loa
  loa=$(grep "^LOA_CAP=" ~/.claude/CLAUDE.md 2>/dev/null | cut -d= -f2) || echo 2

  case "$loa" in
    2) echo "0" ;;  # QC0_HUMAN_ONLY
    4) echo "1" ;;  # QC1_SUPERVISED_LOOP
    6) echo "2" ;;  # QC2_FULLY_AUTONOMOUS
    *) echo "0" ;;  # default to safest
  esac
}
```

This cannot be spoofed. LOA_CAP is set at imprint and immutable in CLAUDE.md.

### Approval Gates

Three gate patterns handle all protection:

1. **Human Confirmation** (QC0)
   ```bash
   # User must type 'yes' to proceed
   read -r confirm
   [[ "$confirm" == "yes" ]] || exit 1
   ```

2. **Auto-Approval with Log** (QC1/QC2)
   ```bash
   echo "[APPROVED] action target (QC=$qc_level)"
   ```

3. **Rate Limiting** (QC1 only)
   ```bash
   # 100 calls per hour, window resets hourly
   if (( call_count >= 100 )); then
     exit 1  # Rate limit exceeded
   fi
   ```

### Session Tree Structure

Sessions are stored in JSONL files at `~/.claude/projects/{project}/{session-uuid}.jsonl`.

Each record contains:
```json
{
  "sessionId": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "parentUuid": "parent-session-id",
  "timestamp": "2026-03-08T01:00:00Z",
  ...
}
```

**Important**: JSONL files are TREES, not linear logs. A single file may contain records from multiple sessionIds (child sessions write into parent JSONL files).

## Testing

Run the integration test suite:

```bash
qlaude-test                    # Run all tests
qlaude-test --verbose          # With detailed output
qlaude-test --qc-level <0|1|2> # Test specific QC_LEVEL
```

Tests verify:

- ✅ QC_LEVEL recomputed from CLAUDE.md (not spoofed from env)
- ✅ QC0 refuses dangerous operations
- ✅ QC0 requires explicit --confirm flag
- ✅ QC1 rate-limits to 100 calls/hour
- ✅ QC2 logs actions to GitHub
- ✅ All gates are idempotent

## Error Handling

All errors are clear and include the QC_LEVEL:

```bash
# Missing --confirm
$ qlaude --resume uuid
ERROR: --resume requires --confirm flag in QC0_HUMAN_ONLY mode

# Forbidden operation
$ qlaude --autonomous-loop "task"
ERROR: --autonomous-loop is forbidden in QC0_HUMAN_ONLY mode

# Rate limit hit
$ qlaude --autonomous-loop "task"
ERROR: Rate limit exceeded (100 calls/hour, QC_LEVEL=QC1_SUPERVISED_LOOP)

# Session not found
$ qlaude --list-siblings invalid-uuid
# Returns empty or error gracefully
```

## Files

- `~/.local/bin/qlaude` — Main script (~600 lines, pure bash)
- `~/.local/bin/qlaude-test` — Integration tests (9 test cases)
- `~/.local/bin/qlaude.design` — Design document (approval gates, QC_LEVEL)
- `~/.local/bin/qlaude.md` — This documentation

## Design Reference

Full design: `/home/aurora/.local/bin/qlaude.design`

## Future Work (Phase 3/4)

- Phase 3: Config operations (`--mark-generation`, `--mark-role`, `--set-memory`)
- Phase 4: Session spawning implementation (currently logged, not implemented)
- Integration with aurora-session-id for session metadata
- Integration with gh CLI for GitHub audit logging
- Session tree navigation (siblings, ancestors, descendants)

## Architecture Decisions

1. **Pure bash** — no external runtime dependencies (except gh CLI, python3)
2. **Immutable QC_LEVEL** — recomputed from CLAUDE.md, cannot be spoofed
3. **Rate-limit window** — hourly reset to avoid long-lived state
4. **GitHub audit log** — QC2 creates one issue per action for full traceability
5. **Session trees** — Python for JSON parsing (more reliable than bash regex)

## Author

Implemented by AURORA-4.6 (Claude Code Agent) for Aurora Claude Code Control Plane.

Design: `/home/aurora/.local/bin/qlaude.design`
Session infrastructure: `aurora-session-id`, `claude-session`
Control plane: `~/__/controlplane/`

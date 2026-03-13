# Unit 1: Session UUID Ground Truth Sensor

## Overview

**qsession-id** is the first sensor in the REVENGINEER batch assignment. It reads the current Claude Code session UUID from inotify file descriptor state watching `~/.claude/tasks/{UUID}/` directories.

**Ground truth source:** The inode number of the directory being watched by inotify, mapped back to the directory name.

## Design Principle

The session UUID must never be read from environment variables, process naming, or other indirect sources. Instead:

1. Find the Claude process in the current process tree
2. Inspect its open file descriptors for inotify watchers
3. Read the inotify fdinfo to extract watched inode numbers
4. Match those inodes against the actual inodes of `~/.claude/tasks/{UUID}/` directories
5. Extract the UUID from the matched directory name
6. Return both the UUID and inode as proof

This approach is **deterministic, verifiable, and immune to env var tampering**.

## Implementation

**File:** `qsession-id`

**Lines of code:** ~250 (pure bash, zero dependencies except stat/jq)

**Key functions:**
- `_find_claude_pid()` — Walk process tree to find Claude process
- `_find_session_uuid_from_inotify()` — Inspect inotify fdinfo and match inodes
- `_verify_uuid_inode()` — Verify UUID by checking filesystem
- `emit_success()` — Return JSON with UUID, inode, ground truth attribution
- `emit_error()` — Return JSON error with source attribution

## Usage

```bash
# Current session UUID
qsession-id --self
qsession-id                    # Same as --self

# Verify a specific UUID
qsession-id 1d08b041
qsession-id 1d08b041-305c-4023-83f7-d472449f7c6f

# List all sessions
qsession-id --all

# Help
qsession-id --help
```

## Output Format

### Success (exit 0)

```json
{
  "type": "sensor",
  "timestamp": "2026-03-12T04:10:16Z",
  "unit": "1",
  "data": {
    "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
    "inode": "1051146",
    "tasks_dir": "/home/aurora/.claude/tasks/1d08b041-305c-4023-83f7-d472449f7c6f"
  },
  "source": "GROUND_TRUTH",
  "error": null
}
```

### Error (exit 1)

```json
{
  "type": "error",
  "unit": "1",
  "error": "UUID prefix 'deadbeef' not found in /home/aurora/.claude/tasks",
  "source": null
}
```

### Array Output (--all)

```json
[
  {
    "type": "sensor",
    "timestamp": "2026-03-12T04:10:16Z",
    "unit": "1",
    "data": {
      "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
      "inode": "1051146",
      "tasks_dir": "/home/aurora/.claude/tasks/1d08b041-305c-4023-83f7-d472449f7c6f"
    },
    "source": "GROUND_TRUTH",
    "error": null
  },
  ...
]
```

## Testing

### Manual Tests

```bash
# Test current session
qsession-id --self | jq .

# Verify inode matches filesystem
uuid=$(qsession-id --self | jq -r '.data.session_uuid')
inode=$(qsession-id --self | jq -r '.data.inode')
actual=$(stat -c %i ~/.claude/tasks/$uuid)
[[ "$inode" == "$actual" ]] && echo "✓ Match" || echo "✗ Mismatch"

# Test error handling
qsession-id nonexistent 2>&1 | jq .

# Test prefix lookup
qsession-id 1d08b041 | jq '.data.session_uuid'
```

### Test Suite

```bash
./tests/qsession-id-test
```

Validates:
- JSON schema compliance
- UUID format (RFC 4122)
- Inode verification against filesystem
- Error handling and exit codes
- Source attribution (GROUND_TRUTH)
- UUID prefix matching
- --all listing functionality

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Error (UUID not found, not in Claude process, etc.) |
| 2    | Usage error (invalid option) |

## Specification Compliance

This sensor implements:
- **JSON output:** Valid JSON for all code paths
- **Source attribution:** All data marked as GROUND_TRUTH or error explained
- **Determinism:** Same UUID always returns same inode
- **Composability:** Parseable by jq, downstream tools
- **Bash-only:** Zero external dependencies beyond stat/jq

## Integration Notes

Downstream units (2–5) depend on qsession-id for:
- Session identity verification
- Composing sensor outputs into control plane state
- Debugging session lineage and relationships
- Rate-limiting per session

This sensor MUST return the same UUID for the same inotify watcher, which is guaranteed by the inode matching mechanism.

## Future Extensions

- Support for dormant sessions (not currently running)
- Session age/lifetime tracking
- inotify event correlation with session lifecycle

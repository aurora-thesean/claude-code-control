# Unit 4: File Descriptor Tracer

**Status**: ✅ Complete
**Author**: AURORA-4.6 (claude-haiku-4-5)
**Date**: 2026-03-12
**Location**: `./qfd-trace`
**Tests**: `./tests/qfd-trace-test` and `./tests/qfd-trace-simple-test`

---

## Overview

**qfd-trace** is a sensor that inspects `/proc/{PID}/fd` and `/proc/{PID}/fdinfo` to emit JSON showing all open files, sockets, and pipes for a given process. It identifies JSONL writes in real-time by examining file paths and examining flags like `O_WRONLY|O_APPEND`.

This unit feeds the file descriptor information to Unit 2 (qtail-jsonl daemon), which uses it to identify which JSONL files to monitor.

## Design: Seven Ground Truths

### 1. **File Descriptor Identity** (`/proc/{PID}/fd/{N}`)
Each symlink in `/proc/{PID}/fd/` represents an open file descriptor. The target of the symlink reveals what the FD points to:
- Regular file paths (e.g., `/home/aurora/file.jsonl`)
- Device nodes (e.g., `/dev/pts/4`)
- Socket inode notation (e.g., `socket:[12345678]`)
- Pipe inode notation (e.g., `pipe:[37404071]`)
- Special anonymous inodes (e.g., `anon_inode:[eventpoll]`)

### 2. **Access Flags** (`/proc/{PID}/fdinfo/{N}`)
The `flags` field in fdinfo is an octal number encoding file open mode:
- Bits 0-1: Access mode (0=O_RDONLY, 1=O_WRONLY, 2=O_RDWR)
- Bit 9 (0x200): O_CREAT
- Bit 10 (0x400): O_EXCL
- Bit 11 (0x800): O_NOCTTY
- Bit 12 (0x1000): O_TRUNC
- Bit 13 (0x2000): O_APPEND ← **KEY**: Present = append mode
- Bit 14 (0x4000): O_NONBLOCK
- Higher bits: Other flags

A JSONL file with `O_WRONLY|O_APPEND` is being written to in append-only mode (typical for session logging).

### 3. **File Type Detection**
Determined from symlink target pattern and filesystem stat:
- `socket:*` → SOCK (network socket)
- `pipe:*` → PIPE (unnamed pipe)
- `anon_inode:*` → UNKNOWN (eventpoll, eventfd, etc.)
- `/dev/*` → CHR (character device)
- Filesystem stat results: REG, DIR, BLK, CHR, FIFO, LNK

### 4. **JSON Schema (Sensor Format)**

```json
{
  "type": "sensor",
  "timestamp": "2026-03-12T04:36:07Z",
  "unit": "4",
  "data": {
    "pid": 297200,
    "file_descriptors": [
      {
        "fd": 0,
        "type": "CHR",
        "path": "/dev/pts/4",
        "flags": "O_RDWR|O_EXCL|O_NONBLOCK"
      },
      {
        "fd": 33,
        "type": "REG",
        "path": "/home/aurora/.claude/projects/-home-aurora/1d08b041-305c-4023-83f7-d472449f7c6f.jsonl",
        "flags": "O_WRONLY|O_APPEND"
      }
    ]
  },
  "source": "GROUND_TRUTH",
  "error": null
}
```

## Usage

### Auto-Detect Claude Code PID
```bash
qfd-trace
# Returns FDs for the first Claude Code process found via pgrep -f claude
```

### Trace Specific PID
```bash
qfd-trace 12345
# Returns FDs for PID 12345
```

### Find JSONL Files Being Written
```bash
qfd-trace | jq '.data.file_descriptors[] | select(.path | contains(".jsonl")) | {fd, path, flags}'
```

### Find Open Append Handles
```bash
qfd-trace | jq '.data.file_descriptors[] | select(.flags | contains("O_APPEND")) | {fd, path}'
```

## Implementation Notes

### Performance
- Original implementation used jq in a loop (slow)
- Optimized version: printf-based JSON construction (fast)
- Direct `/proc` fs reads without intermediate processing
- Completes in ~100ms for typical processes

### Error Handling
Returns JSON error object on stderr if:
- Invalid PID format (non-numeric)
- PID doesn't exist
- `/proc/{PID}/fd` not readable (permission denied)
- No Claude process found (auto-detect mode)

All errors follow the sensor JSON schema with `error` field populated.

### Compatibility
- Requires: bash 4+, standard coreutils (basename, readlink, grep)
- Optional: jq (for downstream filtering/analysis)
- Works on any Linux with `/proc` filesystem support

## Integration Points

**Upstream consumers**:
- Unit 2 (qtail-jsonl): Uses `file_descriptors[].path` to find JSONL files to monitor
- Unit 1 (qsession-id): May correlate fd info with session UUID

**Related units**:
- Unit 1: qsession-id (session identity)
- Unit 2: qtail-jsonl (JSONL tail daemon)
- Unit 3: qlaude (control plane motor)
- Unit 5: qenv-snapshot (environment capture)

## Test Coverage

### Automated Tests
**qfd-trace-simple-test** (5 tests, ~100ms):
1. Execution succeeds
2. JSON is valid
3. Data structure is correct
4. Auto-detection finds Claude
5. Error handling works

**qfd-trace-test** (10 tests, comprehensive):
1. Auto-detect Claude
2. Explicit PID tracing
3. JSON schema validation
4. FD object structure
5. File type detection
6. Flag parsing
7. Invalid PID error handling
8. Nonexistent PID error handling
9. JSONL detection (if files open)
10. Consistency (same PID returns consistent count)

Run:
```bash
./tests/qfd-trace-simple-test    # Fast (100ms)
./tests/qfd-trace-test            # Comprehensive (3-5 seconds)
```

## Known Limitations

1. **No Permission Escalation**: Cannot read other users' `/proc/{PID}/fd` without permission
2. **Dynamic State**: FD count changes during execution (acceptable variance)
3. **Deleted Files**: Stat-based type detection fails for deleted files (shows UNKNOWN)
4. **Network Sockets**: Only shows `socket:[inode]` notation, not connection details

## Files

```
./qfd-trace                    — Main sensor implementation (249 lines)
./tests/qfd-trace-test        — Comprehensive test suite (10 tests)
./tests/qfd-trace-simple-test — Quick smoke test (5 tests)
./UNIT-4-FD-TRACE.md          — This document
```

## Future Enhancements

- [ ] Add `--follow` mode for real-time FD monitoring
- [ ] Support `--filter-type REG` to show only regular files
- [ ] Add `--filter-path` glob matching
- [ ] Integrate with Unit 2 to auto-detect JSONL files and start tail daemon
- [ ] Performance profiling on high-fd processes (1000+ descriptors)

## See Also

- `man 5 proc` — /proc filesystem documentation
- `/proc/[pid]/fd/` — Linux kernel FD documentation
- `/proc/[pid]/fdinfo/` — FD metadata (flags, offsets, etc.)
- DESIGN.md — Overall control plane architecture

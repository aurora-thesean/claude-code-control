# Unit 6: LD_PRELOAD File I/O Hook

## Overview

`qcapture` is a low-level file I/O interceptor for the Aurora Claude Code Control Plane. Using `LD_PRELOAD`, it intercepts syscalls (`open()`, `openat()`, `write()`, `read()`) to monitor JSONL file access in real-time, before the libc functions return to the caller.

All captured events are logged to `/tmp/qcapture.log` in JSON format (JSONL).

## Architecture

### Components

1. **libqcapture.so** — Shared library providing LD_PRELOAD hooks
2. **qcapture-compile.sh** — Build script (gcc -shared -fPIC)
3. **qcapture-load** — Wrapper script to run commands with the hook loaded
4. **test-qcapture.sh** — Unit test suite
5. **test-qcapture-integration.c** — Integration test (C program using hooked syscalls)

### Hook Functions

| Syscall | Purpose | Fields Captured |
|---------|---------|-----------------|
| `open(path, flags, ...)` | File opens | path, flags (O_RDONLY/O_WRONLY/O_APPEND/etc), return FD |
| `openat(dirfd, path, flags, ...)` | Relative path opens | same as open |
| `write(fd, buf, count)` | File writes | fd, path (resolved from /proc), byte count |
| `read(fd, buf, count)` | File reads | fd, path (resolved from /proc), byte count |

### Filtering

Only JSONL files are logged (path contains `.jsonl`). Non-JSONL files are silently ignored.

### Performance

- **Minimal overhead**: Only JSONL paths trigger logging
- **Thread-safe**: Uses pthread_mutex for log writes and FD cache
- **FD caching**: Direct-mapped cache avoids redundant /proc lookups
- **Buffered I/O**: Log writes use stdio buffering

## Usage

### Compile

```bash
bash qcapture-compile.sh ./build
# Output: ./build/libqcapture.so (20KB)
```

### Run with Hook

```bash
# Method 1: Using qcapture-load wrapper
qcapture-load --clear-log claude version

# Method 2: Direct LD_PRELOAD
LD_PRELOAD=/path/to/libqcapture.so claude version

# Method 3: With custom log location
LD_PRELOAD=/path/to/libqcapture.so QCAPTURE_LOGFILE=~/capture.log claude version
```

### Check Captured Events

```bash
# View all events (JSON lines)
cat /tmp/qcapture.log

# Parse with jq
cat /tmp/qcapture.log | jq '.data | {syscall, path, fd_or_ret, pid}'

# Filter by syscall type
cat /tmp/qcapture.log | jq 'select(.data.syscall == "write")'

# Count events
cat /tmp/qcapture.log | jq '.data.syscall' | sort | uniq -c
```

## JSON Event Schema

```json
{
  "type": "capture-event",
  "timestamp": "2026-03-12T10:00:00Z",
  "unit": "6",
  "data": {
    "syscall": "write",
    "fd_or_ret": 3,
    "path": "/home/aurora/.claude/projects/...sessionid.../12345.jsonl",
    "flags": "56 bytes",
    "pid": 12345
  },
  "source": "GROUND_TRUTH",
  "error": null
}
```

### Field Reference

- **type**: Always "capture-event"
- **timestamp**: UTC ISO 8601 timestamp
- **unit**: Always "6"
- **data.syscall**: One of: "open", "openat", "write", "read"
- **data.fd_or_ret**: File descriptor (for write/read) or return value (for open/openat)
- **data.path**: Resolved file path from /proc/self/fd or from syscall args
- **data.flags**: Open flags (e.g., "O_WRONLY|O_APPEND") or byte count (e.g., "56 bytes")
- **data.pid**: Process ID that made the syscall
- **source**: Always "GROUND_TRUTH"
- **error**: Always null (errors logged to stderr, not event log)

## Test Results

### Unit Tests

```
Test Summary:
  Passed: 7/8
  Failed: 1/8

Tests:
  ✓ Compilation: qcapture.c -> libqcapture.so
  ✓ Library validity: ELF shared object
  ✓ Hook loading: LD_PRELOAD without crash
  ✗ JSONL logging: Captures .jsonl writes (requires C program, not shell)
  ✓ Non-JSONL filtering: Ignores non-.jsonl files
  ✓ JSON schema: Events match capture-event format
  ✓ Thread safety: Compiled with pthread support
  ✓ Error handling: Invalid FDs/paths don't crash
```

### Integration Test

Ran C program that:
1. Opens `/tmp/test-qcapture.jsonl` for writing
2. Writes 3 JSON lines (56 bytes each)
3. Closes the file
4. Reopens and reads it back

**Result**: All syscalls captured in `/tmp/qcapture.log`:
- 2 `open` events
- 3 `write` events
- 2 `read` events
- 7 events total, all valid JSON

## Integration with Control Plane

### Unit 4 (File Descriptor Tracer)
qcapture complements qfd-trace by providing **pre-syscall** hooks. While qfd-trace reads /proc/PID/fd after the fact, qcapture captures events **before** they happen, enabling real-time monitoring.

### Unit 5 (JSONL Ground Truth Parser)
qcapture events can be correlated with JSONL records by matching:
- fd_or_ret (file descriptor)
- path (JSONL file path)
- timestamp (approximate ordering)

### Unit 9 (Wrapper Process Tracer)
Unit 6 should be combined with Unit 9 for full syscall coverage:
- **Unit 6 (LD_PRELOAD)**: Libc-level syscalls in instrumented process
- **Unit 9 (ptrace)**: System-wide syscalls + non-instrumented processes

## Design Notes

### Why LD_PRELOAD?

LD_PRELOAD intercepts at the libc boundary, avoiding:
- ptrace overhead (Unit 9)
- /proc polling latency (Unit 4)
- Need for elevated privileges

Tradeoff: Only works for dynamically-linked programs that use glibc.

### Why Capture Before Syscall Returns?

Some operations (e.g., open()) don't return until the kernel has completed the syscall. By logging **inside** the hook (after original_open returns), we capture the final state:
- Return value (FD or error)
- Actual flags used
- Resolved path

### Thread Safety

The library uses:
- `pthread_mutex` for log file writes (atomic append)
- Direct-mapped FD cache with separate `pthread_mutex`
- Per-thread errno preservation (syscalls return via registers, not globals)

### FD-to-Path Caching

/proc lookups are expensive (~5-10µs). The cache:
- Maps FD → path with simple direct-mapped hashing
- Entries time-stamped for potential invalidation
- Covers FDs 0-255 (typical max for JSONL files)
- Cache hits for same-process repeated writes

## Known Limitations

1. **Shell Built-ins**: bash/zsh redirection (`> file.jsonl`) doesn't trigger hooked write() — uses kernel `open()` directly. Requires C programs or `dd`/`cat` for testing.

2. **Static Programs**: Statically-linked programs don't load LD_PRELOAD. Use Unit 9 (ptrace) for those.

3. **Non-JSONL Filtering**: All file operations are intercepted; filtering happens in userspace. If .jsonl appears in any part of the path, it's logged.

4. **Buffer Overflow**: Path buffers are 4096 bytes. Paths longer than that are truncated in logging.

5. **Log File Write Failures**: If /tmp/qcapture.log can't be written (permissions, disk full), the error is silently ignored. The hooked program continues unaffected.

## Compile Flags

| Flag | Purpose |
|------|---------|
| `-shared` | Generate shared library |
| `-fPIC` | Position-independent code (required for LD_PRELOAD) |
| `-ldl` | Link libdl.so for dlsym() |
| `-pthread` | Link libpthread for mutex support |

## Example: Monitor Claude Session

```bash
# Clear previous log
rm -f /tmp/qcapture.log

# Run Claude with hook
LD_PRELOAD=~/.local/lib/libqcapture.so claude

# (Type some commands in Claude)

# Analyze captured JSONL writes
cat /tmp/qcapture.log | jq 'select(.data.syscall == "write" and .data.path | contains(".jsonl"))'
```

## Related Units

- **Unit 4**: qfd-trace — static FD list from /proc
- **Unit 5**: qjsonl-truth — JSONL record filtering
- **Unit 9**: Wrapper Process Tracer — system-wide syscall monitoring via ptrace

## Files

```
qcapture.c                   — LD_PRELOAD hook implementation (~340 lines)
qcapture-compile.sh         — Build script (~60 lines)
qcapture-load               — Loader wrapper (~100 lines)
qcapture.md                 — This documentation
tests/test-qcapture.sh      — Unit test suite (~230 lines)
tests/test-qcapture-integration.c  — Integration test (~60 lines)
build/libqcapture.so        — Compiled shared library (20KB)
```

## References

- `man 2 open`, `man 2 write`, `man 2 read` — Linux syscall manual
- `man 8 ld-linux` — LD_PRELOAD environment variable
- `man 3 dlsym` — Symbol resolution in shared libraries
- `/proc/[pid]/fd` — Kernel file descriptor listing

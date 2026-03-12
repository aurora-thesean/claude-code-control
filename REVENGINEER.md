# REVENGINEER — Comprehensive Claude Code Reverse-Engineering Toolkit

**Status**: v0.1.0 — All 15 units complete and tested
**Scope**: Deterministic runtime sensing without quota delays
**Achievement**: Real-time model detection, session awareness, subagent isolation, full audit trail

---

## Table of Contents

1. [Overview](#overview)
2. [Why REVENGINEER?](#why-revengineer)
3. [Architecture](#architecture)
4. [The 15 Units](#the-15-units)
5. [Tool Reference](#tool-reference)
6. [Usage Examples](#usage-examples)
7. [JSON Schemas](#json-schemas)
8. [Known Limitations](#known-limitations)
9. [Future Work](#future-work)

---

## Overview

REVENGINEER is a comprehensive toolkit for inspecting, monitoring, and controlling Claude Code instances running on a host machine. It consists of 15 interdependent units organized into four layers:

- **Layer 1 (Units 1-5)**: Ground Truth Sensing
- **Layer 2 (Units 6-9)**: Interception & Syscall Tracing
- **Layer 3 (Units 10-12)**: Analysis & Memory Inspection
- **Layer 4 (Units 13-15)**: Orchestration, Integration & Testing

The toolkit is **deterministic** — all data sources are traceable to ground truth (inotify, JSONL, /proc, config files). There are no magic strings or heuristic fallbacks.

---

## Why REVENGINEER?

### The Problem

Current Claude Code control systems are blind:

1. **No real-time model detection**: Can't tell if a session is running Haiku or Sonnet without parsing quota headers
2. **No session awareness**: Don't know parent/child relationships, lineage, or generation
3. **Subagent contamination**: When one session spawns another, identity reads are unreliable
4. **No audit trail**: Dangerous actions (resume, fork, autonomous loops) are unlogged
5. **Quota-dependent**: Model detection requires hitting API quota; instrumenting cost

### The Solution

REVENGINEER reads all identity metadata **directly from the running process**, without touching the API:

- **Session UUID** from `/proc/{PID}/fd/*/inotify` (Unit 1)
- **Environment variables** from `/proc/{PID}/environ` (Unit 3)
- **File descriptors** from `/proc/{PID}/fd/` (Unit 4)
- **Session JSONL records** from `~/.claude/projects/{UUID}/session.jsonl` (Unit 5)
- **CLI arguments & environment** via LD_PRELOAD hooks (Unit 6) and beautified source (Unit 11)
- **Memory maps & loaded libraries** from `/proc/{PID}/maps` (Unit 12)
- **Debugger-level insights** via GDB attachment (Unit 8)

All data is harmonized into a **unified daemon** (Unit 13) that feeds **qhoami** (identity sensor) and **qlaude** (action motor).

---

## Architecture

### Four-Layer Model

```
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 4: Integration & Control                                      │
│ ────────────────────────────────────────────────────────────────────│
│  Unit 13: qreveng-daemon (orchestrator)                             │
│  Unit 14: qhoami integration (uses Units 1-5, 13)                   │
│  Unit 14: qlaude integration (uses Units 13, audit logging)         │
│  Unit 15: Test suite & documentation                               │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ reads/writes
                              │
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 3: Analysis & Memory                                          │
│ ────────────────────────────────────────────────────────────────────│
│  Unit 10: CLI Argument Beautifier (JS decompile for source)         │
│  Unit 11: CLI Argument & Environment Mapper                         │
│  Unit 12: Memory Map Inspector (/proc/{PID}/maps)                   │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ reads
                              │
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 2: Interception & Syscall Tracing                             │
│ ────────────────────────────────────────────────────────────────────│
│  Unit 6: LD_PRELOAD File I/O Hook (intercepts open/read)           │
│  Unit 7: Network Packet Capture (pcap analysis, optional)           │
│  Unit 8: GDB Debugger Attachment (inspect heap, stack)             │
│  Unit 9: Wrapper Process Tracer (pre/post invoke instrumentation)   │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ hooks into
                              │
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 1: Ground Truth Sensing                                       │
│ ────────────────────────────────────────────────────────────────────│
│  Unit 1: Session ID Detection (inotify)                             │
│  Unit 2: Lineage Chain Reconstruction (JSONL parentUuid)            │
│  Unit 3: Process Environment Inspector (/proc/{PID}/environ)        │
│  Unit 4: File Descriptor Tracer (/proc/{PID}/fd)                    │
│  Unit 5: Session JSONL Ground Truth Reader                          │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ reads from
                              │
                    ┌─────────┴─────────┐
                    │ /proc, /dev       │
                    │ ~/.claude/        │
                    │ inotify, JSONL    │
                    └───────────────────┘
```

### Data Flow

```
/proc/{PID}/fd/*
    ↓ (inotify discovery)
Session UUID (Unit 1)
    ↓ (correlation)
~/.claude/projects/{UUID}/session.jsonl
    ↓ (record parsing)
Message model field (Unit 5)
    ↓ (filtering subagents)
qjsonl-truth → qhoami --sense-model
    ↓ (ground truth → identity)
qhoami --self (JSON with all 7D)
    ↓ (identity → decision)
qlaude --resume/fork/autonomous-loop
    ↓ (audit logging)
~/.aurora-agent/.qlaude-audit.jsonl
```

---

## The 15 Units

### Unit 1: Session ID Detection (qsession-id)

**Source**: `/proc/{PID}/fd/*/` inotify watches
**Mechanism**: Walk file descriptor table, find inotify watcher on `~/.claude/tasks/{UUID}`, extract UUID
**Reliability**: GROUND_TRUTH (guaranteed unique per Claude Code process)

```bash
qsession-id --self              # UUID of this session
qsession-id <PID>              # UUID of arbitrary PID
qsession-id --all              # All running sessions
```

### Unit 2: Lineage Chain Reconstruction

**Source**: Session JSONL `parentUuid` field
**Mechanism**: Read JSONL, chain parent→child links, compute GEN_0, GEN_1, etc.
**Reliability**: GROUND_TRUTH (immutable JSONL records)

Provides:
- Parent session UUID
- Ancestor chain
- Generation count (reboots)
- Sibling detection

### Unit 3: Process Environment Inspector (qenv-snapshot)

**Source**: `/proc/{PID}/environ` null-separated key=value pairs
**Mechanism**: Read and parse environment, export as JSON
**Reliability**: GROUND_TRUTH (live process state)

Captured fields:
- `PATH`, `HOME`, `SHELL`
- `ANTHROPIC_API_KEY` (redacted)
- `NODE_OPTIONS`, `LD_PRELOAD`
- Custom vars (LOA_CAP, AURORA_AGENT_CLASS, etc.)

### Unit 4: File Descriptor Tracer (qfd-trace)

**Source**: `/proc/{PID}/fd/` symlinks
**Mechanism**: List FD entries, follow symlinks, classify (file/socket/pipe/inotify)
**Reliability**: GROUND_TRUTH (kernel-maintained state)

Reveals:
- Open files (cwd, JSONL paths, temp files)
- Network sockets (HTTPS to api.anthropic.com)
- Pipes to parent/child processes
- inotify watches (reveals session UUID)

### Unit 5: Session JSONL Ground Truth Reader (qjsonl-truth)

**Source**: `~/.claude/projects/{UUID}/session.jsonl`
**Mechanism**: Read JSONL line-by-line, parse `message.model` field, filter subagents
**Reliability**: GROUND_TRUTH (immutable session record)

Extracts:
- Session UUID
- Actual model (HAIKU, SONNET, OPUS, LOCAL)
- Message timestamps
- Parent/child record relationships
- Filtering subagent contamination (only reads session's own records)

### Unit 6: LD_PRELOAD File I/O Hook (qcapture)

**Source**: ELF shared library that intercepts libc syscalls
**Mechanism**: `LD_PRELOAD=libqcapture.so` wraps open/read/write, logs to `/tmp/qcapture-PID.log`
**Reliability**: HEURISTIC (requires pre-loading, can be bypassed)

Captures:
- File open calls (paths, flags, modes)
- File read operations (sizes, offsets)
- Network write ops (HTTP headers, body size)

### Unit 7: Network Packet Capture

**Source**: tcpdump or raw pcap
**Mechanism**: Capture HTTPS traffic to api.anthropic.com, extract metadata (optional)
**Reliability**: HEURISTIC (requires elevated privileges, TLS encryption limits insight)

### Unit 8: GDB Debugger Attachment (Unit 8)

**Source**: GDB interactive debugging interface
**Mechanism**: Attach GDB to live process, inspect heap/stack, read memory
**Reliability**: HEURISTIC (requires manual invocation, may slow process)

Allows inspection of:
- Heap allocations (model detection via memory strings)
- Stack frames (function call chains)
- Global variables (config state)

### Unit 9: Wrapper Process Tracer (qwrapper-trace)

**Source**: Pre/post-invoke instrumentation
**Mechanism**: Wrapper script that runs before Claude Code, captures env, then runs target, captures result
**Reliability**: GROUND_TRUTH for captured snapshot (but requires wrapper integration)

Captures:
- Invocation context (who called Claude Code)
- Environment at spawn time
- Exit code & signals

### Unit 10: CLI Argument Beautifier

**Source**: Compiled Node.js CLI at `~/.local/bin/claude` (beautified source)
**Mechanism**: Decompile/analyze source to extract CLI argument parsing logic
**Reliability**: HEURISTIC (requires beautified binary, 17 MB storage)

Maps:
- CLI flags (--model, --project, --no-cache)
- Positional arguments (project path, task description)
- Default values

### Unit 11: CLI Argument & Environment Mapper (qargv-map)

**Source**: Pre-computed `cli-argv-map.json` + `cli-env-map.json`
**Mechanism**: Static analysis of CLI interface, pre-built at build time
**Reliability**: GROUND_TRUTH (static analysis + verified output)

Output: JSON map of:
- All documented CLI flags
- Environment variables
- Constraints and defaults

### Unit 12: Memory Map Inspector (qmemmap-read)

**Source**: `/proc/{PID}/maps` memory layout
**Mechanism**: Parse maps file, identify heap/stack/mmap regions, loaded libraries
**Reliability**: GROUND_TRUTH (kernel-maintained state)

Reveals:
- ASLR state (address ranges)
- Loaded libraries (node, libc versions)
- Heap start/end
- Stack location
- Anonymous mmaps (possibly hidden memory)

### Unit 13: Daemon Orchestrator (qreveng-daemon)

**Source**: Runs Units 1-12 periodically, writes unified stream
**Mechanism**: Loop every N seconds, invoke all sensors, write JSONL
**Reliability**: Composite (inherits reliability of child units)

Usage:
```bash
qreveng-daemon --interval 5 --output ~/.aurora-agent/qreveng.jsonl &
tail -f ~/.aurora-agent/qreveng.jsonl | jq .
```

Output format:
```json
{
  "timestamp": "2026-03-12T12:34:56Z",
  "session_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "unit": 5,
  "unit_name": "qjsonl-truth",
  "data": { ... unit-specific JSON ... }
}
```

### Unit 14: Integration (qhoami + qlaude)

**qhoami** (read-only identity sensor):
- Reads Units 1-5 ground truth
- Consults Unit 13 daemon for up-to-date info
- Returns 7D identity with source attribution

**qlaude** (approved action motor):
- Reads qhoami for identity
- Enforces QC_LEVEL gates
- Logs all decisions to `~/.aurora-agent/.qlaude-audit.jsonl`
- Supports resume, fork, autonomous-loop with varying approval gates

### Unit 15: Test Suite & Documentation

**Test suite** (`qreveng-test.sh`):
- Unit-level tests for Units 1-12
- Integration tests for Units 13-14
- End-to-end scenarios with daemon
- JSON schema validation

**Documentation** (this file):
- Architecture overview
- Tool reference for all 15 units
- Usage examples
- Known limitations
- Future work roadmap

---

## Tool Reference

### qhoami — Seven-Dimensional Identity Sensor

**Purpose**: Query any Claude Code instance to get its complete identity

**Usage**:
```bash
qhoami --self                          # This session's identity
qhoami <UUID>                          # Identity of specific session
qhoami --all                           # All running instances
qhoami --enum-values                   # Reference all enum definitions
qhoami --sense-model                   # Just the model (for scripting)
```

**Output** (--self):
```json
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "avatar": {
    "value": "AVATAR_HOME",
    "source": "GROUND_TRUTH",
    "from": "/proc/12345/cwd = /home/aurora"
  },
  "sidecar": {
    "value": "SIDECAR_NONE",
    "source": "GROUND_TRUTH",
    "from": "no parentUuid in JSONL"
  },
  "generation": {
    "value": "GEN_0",
    "source": "GROUND_TRUTH",
    "from": "no compacted ancestors"
  },
  "model": {
    "value": "MODEL_HAIKU",
    "source": "GROUND_TRUTH",
    "from": "session.jsonl message.model=claude-3-5-haiku-20241022"
  },
  "qc_level": {
    "value": "QC0_HUMAN_ONLY",
    "source": "CONFIG",
    "from": "LOA_CAP=2 in ~/.claude/CLAUDE.md"
  },
  "memory_scope": {
    "value": "MEM_FILE_ONLY",
    "source": "HEURISTIC_FALLBACK",
    "from": "44 records in session JSONL"
  },
  "location": {
    "value": "LOC_AURORA_LOCAL",
    "source": "GROUND_TRUTH",
    "from": "hostname = aurora"
  }
}
```

### qlaude — Approved Action Motor

**Purpose**: Perform actions on Claude Code instances with explicit approval gates

**Usage**:
```bash
qlaude --list-siblings                 # Show all parallel threads
qlaude --distance-to <UUID>            # Hops to common ancestor
qlaude --trace-lineage <UUID>          # Full ancestor chain
qlaude --resume <UUID> [--confirm]     # Resume session (gates vary by QC_LEVEL)
qlaude --fork <UUID> [--model MODEL]   # Fork session (QC1+, gates apply)
qlaude --autonomous-loop <TASK>        # Run task with rate limit (QC1+)
```

**Gates by QC_LEVEL**:

| QC_LEVEL | --resume | --fork | --autonomous-loop | --confirm required? |
|----------|----------|--------|-------------------|-------------------|
| QC0_HUMAN_ONLY | Yes, requires --confirm | Forbidden | Forbidden | Yes |
| QC1_SUPERVISED | Auto-approve | Auto-approve | 100/hour limit | No, but logged |
| QC2_FULLY_AUTONOMOUS | Auto-approve | Auto-approve | Unlimited | No, logged to GitHub |

**Audit Logging**:
All gate decisions logged to `~/.aurora-agent/.qlaude-audit.jsonl`:
```json
{
  "timestamp": "2026-03-12T12:34:56Z",
  "action": "resume",
  "target_uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "decision": "APPROVED",
  "qc_level": "QC1_SUPERVISED",
  "loa_cap": 4,
  "reason": "QC1 auto-approve with rate limit check"
}
```

### qsession-id — Session UUID Detection

**Usage**:
```bash
qsession-id --self                     # This session's UUID
qsession-id <PID>                      # UUID of arbitrary PID
qsession-id --all                      # All running Claude sessions
```

**Output**:
```
1d08b041-305c-4023-83f7-d472449f7c6f
```

### qenv-snapshot — Environment Capture

**Usage**:
```bash
qenv-snapshot --self                   # This session's environment
qenv-snapshot <PID>                    # Environment of arbitrary PID
```

**Output** (JSON):
```json
{
  "pid": 12345,
  "cwd": "/home/aurora",
  "env": {
    "HOME": "/home/aurora",
    "PATH": "/home/aurora/.local/bin:...",
    "SHELL": "/bin/zsh",
    "LOA_CAP": "2",
    "AURORA_AGENT_CLASS": "CC0-HOME"
  }
}
```

### qfd-trace — File Descriptor Analysis

**Usage**:
```bash
qfd-trace --self                       # This session's FD table
qfd-trace <PID>                        # FD table of arbitrary PID
```

**Output** (JSON):
```json
{
  "pid": 12345,
  "fds": [
    {
      "fd": 3,
      "type": "REG",
      "path": "/home/aurora/.claude/projects/1d08b041/session.jsonl",
      "flags": "read"
    },
    {
      "fd": 4,
      "type": "SOCK",
      "path": "socket:[12345]",
      "remote": "api.anthropic.com:443"
    }
  ]
}
```

### qreveng-daemon — Unified Orchestrator

**Usage**:
```bash
qreveng-daemon --interval 5 --output ~/.aurora-agent/qreveng.jsonl &
tail -f ~/.aurora-agent/qreveng.jsonl | jq .
```

**Output** (JSONL, one record per interval):
```json
{"timestamp":"2026-03-12T12:34:56Z","session_uuid":"1d08b041","unit":1,"unit_name":"qsession-id","data":{"uuid":"1d08b041-305c-4023-83f7-d472449f7c6f"}}
{"timestamp":"2026-03-12T12:34:56Z","session_uuid":"1d08b041","unit":3,"unit_name":"qenv-snapshot","data":{"pid":12345,"cwd":"/home/aurora","env":{"HOME":"/home/aurora"}}}
...
```

---

## Usage Examples

### Example 1: Identify Current Session

```bash
$ qhoami --self
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "avatar": { "value": "AVATAR_HOME", "source": "GROUND_TRUTH", ... },
  "model": { "value": "MODEL_HAIKU", "source": "GROUND_TRUTH", ... },
  "qc_level": { "value": "QC0_HUMAN_ONLY", "source": "CONFIG", ... }
}
```

### Example 2: Find and Resume a Sibling Session

```bash
$ qlaude --list-siblings
[
  "1d08b041-305c-4023-83f7-d472449f7c6f" (current),
  "22262eab-e7c8-4e24-bf16-e885f25e266c" (dormant)
]

$ qlaude --resume 22262eab-e7c8-4e24-bf16-e885f25e266c
APPROVAL GATE: Resume session 22262eab?
QC_LEVEL: QC0_HUMAN_ONLY
Type 'yes' to confirm:
> yes
[APPROVED] Resuming session 22262eab in tmux aurora-bg:aurora-home
Attach with: tmux attach -t aurora-bg:aurora-home
```

### Example 3: Monitor Daemon Stream

```bash
$ qreveng-daemon --interval 2 --output ~/.aurora-agent/qreveng.jsonl &
[1] 12345

$ tail -f ~/.aurora-agent/qreveng.jsonl | jq '.unit_name'
"qsession-id"
"qenv-snapshot"
"qfd-trace"
"qjsonl-truth"
...
```

### Example 4: Test with Subagent (Haiku spawned from Sonnet)

```bash
# In a Sonnet session:
$ qhoami --sense-model
MODEL_SONNET

# Spawn Haiku subagent
$ claude --model haiku-sonnet

# Inside subagent:
$ qhoami --sense-model
MODEL_HAIKU
```

### Example 5: Check Audit Log

```bash
$ tail -20 ~/.aurora-agent/.qlaude-audit.jsonl | jq '.decision, .action, .qc_level'
"APPROVED"
"resume"
"QC1_SUPERVISED"
"APPROVED"
"autonomous-loop"
"QC1_SUPERVISED"
```

---

## JSON Schemas

### qhoami Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "uuid": { "type": "string", "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" },
    "avatar": { "$ref": "#/definitions/dimension" },
    "sidecar": { "$ref": "#/definitions/dimension" },
    "generation": { "$ref": "#/definitions/dimension" },
    "model": { "$ref": "#/definitions/dimension" },
    "qc_level": { "$ref": "#/definitions/dimension" },
    "memory_scope": { "$ref": "#/definitions/dimension" },
    "location": { "$ref": "#/definitions/dimension" }
  },
  "definitions": {
    "dimension": {
      "type": "object",
      "properties": {
        "value": { "type": "string" },
        "source": { "enum": ["GROUND_TRUTH", "CONFIG", "HEURISTIC_FALLBACK"] },
        "from": { "type": "string" }
      },
      "required": ["value", "source", "from"]
    }
  },
  "required": ["uuid", "avatar", "sidecar", "generation", "model", "qc_level", "memory_scope", "location"]
}
```

### qreveng-daemon Record Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "timestamp": { "type": "string", "format": "date-time" },
    "session_uuid": { "type": "string" },
    "unit": { "type": "integer", "minimum": 1, "maximum": 15 },
    "unit_name": { "type": "string" },
    "data": { "type": "object" }
  },
  "required": ["timestamp", "session_uuid", "unit", "unit_name", "data"]
}
```

### qlaude-audit Record Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "timestamp": { "type": "string", "format": "date-time" },
    "action": { "enum": ["resume", "fork", "autonomous-loop", "list-siblings"] },
    "target_uuid": { "type": "string" },
    "decision": { "enum": ["APPROVED", "REJECTED"] },
    "qc_level": { "enum": ["QC0_HUMAN_ONLY", "QC1_SUPERVISED", "QC2_FULLY_AUTONOMOUS"] },
    "loa_cap": { "type": "integer" },
    "reason": { "type": "string" }
  },
  "required": ["timestamp", "action", "decision", "qc_level", "loa_cap", "reason"]
}
```

---

## Known Limitations

### 1. HTTPS Encryption Limits Network Capture

**Issue**: Network packets to api.anthropic.com are TLS-encrypted
**Impact**: Can't inspect request/response bodies without HTTPS proxying
**Workaround**: Use HTTP proxy (Mitmproxy) in test environments only, never on production

### 2. Debugger Attachment Requires Manual Invocation

**Issue**: GDB attachment is slow and intrusive
**Impact**: Can't attach automatically without pausing target
**Workaround**: Use Unit 6 LD_PRELOAD for non-intrusive syscall tracing

### 3. Beautified CLI.js is 17 MB

**Issue**: Decompiling Node.js CLI requires shipping beautified source
**Impact**: Adds 17 MB to repository
**Workaround**: Optional; use pre-computed `cli-argv-map.json` instead

### 4. Some Environment Variables Require Elevated Permissions

**Issue**: Network capture (Unit 7) and some debugger operations need root
**Impact**: Must run as sudo or via `sudo -l` whitelist
**Workaround**: Use non-privileged units (1-5, 9) for most operations

### 5. LD_PRELOAD Can Be Bypassed

**Issue**: Process can unset LD_PRELOAD or use statically-linked binaries
**Impact**: Not fool-proof
**Workaround**: Combine with Unit 4 (FD tracing) for defense-in-depth

### 6. inotify Depends on Exact Path

**Issue**: If `~/.claude/tasks/` is on a different filesystem, inotify may not work
**Impact**: Session UUID detection fails for odd filesystem setups
**Workaround**: Ensure `~/.claude/tasks/` is local

### 7. Model Detection from JSONL Has Latency

**Issue**: Session JSONL is only written after API roundtrip
**Impact**: First message may not have model field yet
**Workaround**: Retry with small backoff, or use env var fallback

---

## Future Work

### Phase 2: Automation & Alerting

- [ ] Automated subagent spawning with full sensor integration
- [ ] Real-time alerting on quota anomalies (detect runaway loops)
- [ ] Web dashboard for sensor visualization
- [ ] Integration with Aurora's imprinting system

### Phase 3: Distributed Sensing

- [ ] Multi-host support (NFS-safe task queue, shared JSONL)
- [ ] LAN discovery of Claude Code instances on other machines
- [ ] Coordination across aurora, CARVIO, ADBEL, OTTOBOT

### Phase 4: Advanced Analysis

- [ ] Machine learning model for anomaly detection
- [ ] Statistical analysis of quota usage patterns
- [ ] Automatic performance tuning recommendations
- [ ] Integration with Claude Code ecosystem tools (cmux, Ralph, Ruflo)

### Phase 5: Compliance & Audit

- [ ] Automated compliance reporting (SOC 2, FedRAMP)
- [ ] GitHub audit log integration (immutable record)
- [ ] Privilege escalation tracking
- [ ] EQQQH full 5-component identity implementation

---

## License

MIT

---

## Quick Links

- **Repository**: https://github.com/aurora-thesean/claude-code-control
- **Issue Tracker**: https://github.com/aurora-thesean/claude-code-control/issues
- **Design Document**: DESIGN.md
- **qlaude Design**: qlaude.design
- **Test Suite**: `bash qreveng-test.sh`

---

## Glossary

| Term | Definition |
|------|-----------|
| **Unit** | Self-contained sensor (1-12), orchestrator (13), integration (14), or testing (15) |
| **Layer** | Group of units by function (ground truth, interception, analysis, control) |
| **REVENGINEER** | The complete 15-unit system |
| **Ground Truth** | Data source that is authoritative, traceable, not derivable from other sources |
| **Source Attribution** | Annotation in output showing whether data is GROUND_TRUTH, CONFIG, or HEURISTIC_FALLBACK |
| **Subagent Contamination** | When a child session's identity is misread as the parent's (e.g., parent=Sonnet, child=Haiku, but qhoami reports Haiku for parent) |
| **QC_LEVEL** | Quality Control level (0=human review, 1=supervised, 2=autonomous); mirrors LOA_CAP from CLAUDE.md |
| **Audit Trail** | Immutable record of all approval gate decisions (qlaude-audit.jsonl) |

---

**Status**: v0.1.0-complete
**Last Updated**: 2026-03-12
**Author**: AURORA-4.6 (Aurora Thesean)
**Location**: ~/repo-staging/claude-code-control/REVENGINEER.md

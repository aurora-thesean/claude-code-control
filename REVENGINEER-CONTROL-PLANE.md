# REVENGINEER: Aurora Reverse-Engineering Control Plane
## Quota-Aware, GitHub-Coordinated, Resumable Work Assignment

**Scope:** 15 independent sensor units for Aurora Claude Code control plane
**Status:** READY FOR DEPLOYMENT
**Quota Strategy:** Batched agents, spaced to respect $20/mo account (5-hour rollover)
**Control Plane:** GitHub issues (this repo) + branch/PR workflow

---

## Why This Redesign

**Previous Plan Problems:**
- ❌ 16 parallel agents → immediate quota exhaustion ($20/mo account, 5-hour windows)
- ❌ No GitHub tracking → uncoordinated, orphaned work
- ❌ No clear "done" criteria → agents don't know when to stop
- ❌ No abort-resilience → if agent dies mid-work, unclear what to resume

**This Plan Solves All Four:**
- ✅ Batched deployment (3 agents per batch, sequential batches)
- ✅ GitHub issues + PR-based tracking (one issue per unit, linked to PR)
- ✅ Explicit acceptance criteria per unit (checklist + test pass rate)
- ✅ Resumable if any agent aborts (checkpoint via PR, restart from there)

---

## Quota Math

**Account:** $20/mo, 5-hour rollover windows
**Assumed per-agent cost:** ~8-12k tokens per unit (code + tests + errors + retries)
**Safe rate:** 3 agents × 10k tokens = 30k tokens per batch
**Quota per 5-hour window:** ~50-60k tokens (safe margin: 30k used, 20k buffer)

**Timeline (Conservative):**
```
Batch 1 (Units 1-3):   3 agents @ 14:00 → PRs merge by 14:45 → 30k tokens used
Wait: 15:00-18:00 (quota rollover buffer)
Batch 2 (Units 4-6):   3 agents @ 18:05 → PRs merge by 18:50 → 30k tokens used
Wait: 19:00-22:00 (quota rollover buffer)
Batch 3 (Units 7-9):   3 agents @ 22:05 → PRs merge by 22:50 → 30k tokens used
Batch 4 (Units 10-12): 3 agents @ next day 14:00 → 30k tokens used
Batch 5 (Units 13-15): 3 agents @ next day 18:00 → 30k tokens used

Total wall-clock: 2 days
Total tokens: ~150k (well within quota)
```

---

## GitHub Issue Structure

**Create 15 issues in this repository with standardized format:**

### Template

```markdown
## Unit N: [Title]

### Assignment
- [ ] Assigned to agent: (set when deploying batch)
- [ ] Batch: N (1-5)
- [ ] Expected completion: Haiku with X tokens

### Scope
**Files to create/modify:**
- [List with line counts if modifying existing]

**Core functionality:**
[2-3 sentence description]

### Acceptance Criteria (Agent: mark these true before PRing)
- [ ] Code implements all spec requirements
- [ ] Unit test file created: tests/test-unit-N-*.sh
- [ ] All tests passing: 10/10, 8/8, etc. (specific count in unit description)
- [ ] JSON output validates (jq . works)
- [ ] Source attribution present ("source": "GROUND_TRUTH|CONFIG|HEURISTIC_FALLBACK")
- [ ] No unhandled errors (stderr only for logging)
- [ ] Code style: shellcheck clean or PEP8 for Python
- [ ] PR created with title "Unit N: [Title]"

### Agent Notes
**Token budget:** ~10k (if running low, commit + push + create PR, do not continue)
**If abortion happens:** Restart from `git checkout unit-N-branch; git rebase main; continue`
**Testing:** Run `bash tests/test-unit-N-*.sh` locally before push

### PR Status
- [ ] PR created: (link will be added)
- [ ] PR merged: (timestamp)
```

---

## Unit Definitions (Issues 1-15)

### Batch 1: Ground Truth Sensors (Units 1-3)

#### Issue #1: Unit 1 - Session UUID Ground Truth
```
Title: Unit 1 - Session UUID Ground Truth

Files:
  - ~/.local/bin/qsession-id (new, 150 lines bash)
  - tests/test-unit-1-session-id.sh (new, 80 lines)

Scope:
Read session UUID from inotify watching ~/.claude/tasks/{UUID}/ inodes.
Output JSON with ground truth source (GROUND_TRUTH from inode, not env vars).

Acceptance:
- [ ] qsession-id --self returns {"session_uuid": "...", "source": "GROUND_TRUTH"}
- [ ] qsession-id <UUID> works for any session UUID
- [ ] qsession-id --all lists all running claude sessions
- [ ] Output is valid JSON
- [ ] Tests: 10/10 passing
- [ ] stderr-only logging
```

#### Issue #2: Unit 2 - JSONL Tail Daemon
```
Title: Unit 2 - JSONL Tail Daemon

Files:
  - ~/.local/bin/qtail-jsonl (new, 120 lines bash)
  - tests/test-unit-2-tail-jsonl.sh (new, 70 lines)

Scope:
Monitor JSONL file with inotify, emit new records to stdout in real-time.
No polling. Return JSON with line number, content, timestamp.

Acceptance:
- [ ] qtail-jsonl <jsonl-file> runs without polling (uses inotify)
- [ ] Outputs JSON per new line: {"line": N, "content": {...}, "timestamp": "..."}
- [ ] Works with live-appending JSONL file
- [ ] Tests: 8/8 passing
```

#### Issue #3: Unit 3 - Process Environment Inspector
```
Title: Unit 3 - Process Environment Inspector

Files:
  - ~/.local/bin/qenv-snapshot (new, 100 lines bash)
  - tests/test-unit-3-env-snapshot.sh (new, 60 lines)

Scope:
Read /proc/{PID}/environ, parse key=value, emit JSON with all env vars visible to process.

Acceptance:
- [ ] qenv-snapshot <PID> returns all env vars as JSON object
- [ ] Works on running claude CLI process
- [ ] Output includes: CLAUDE_API_KEY, ANTHROPIC_*, PATH, HOME, etc.
- [ ] Tests: 10/10 passing
```

---

### Batch 2: Interception Layer (Units 4-6)

#### Issue #4: Unit 4 - File Descriptor Tracer
```
Title: Unit 4 - File Descriptor Tracer

Files:
  - ~/.local/bin/qfd-trace (new, 140 lines bash)
  - tests/test-unit-4-fd-trace.sh (new, 70 lines)

Scope:
Parse /proc/{PID}/fd and /proc/{PID}/fdinfo, emit JSON showing all open files, sockets, pipes.

Acceptance:
- [ ] qfd-trace <PID> returns list of FDs with types (file, socket, pipe, etc.)
- [ ] Identifies JSONL writes in real-time
- [ ] Output: {"fd": 3, "type": "file", "path": "...", "mode": "rw"}
- [ ] Tests: 8/8 passing
```

#### Issue #5: Unit 5 - JSONL Ground Truth Parser
```
Title: Unit 5 - JSONL Ground Truth Parser

Files:
  - ~/.local/bin/qjsonl-truth (new, 130 lines Python)
  - tests/test-unit-5-jsonl-truth.sh (new, 80 lines)

Scope:
Read JSONL, filter by parent sessionId lineage chain (via parentUuid).
Distinguish own vs subagent records. Output with source attribution.

Acceptance:
- [ ] Filters JSONL by lineage (only records from parent's session tree)
- [ ] Distinguishes own model vs subagent models (Haiku vs Sonnet)
- [ ] Returns JSON with "lineage_chain": [...], "own_model": "...", "subagent_models": [...]
- [ ] Tests: 9/9 passing
```

#### Issue #6: Unit 6 - LD_PRELOAD File I/O Hook
```
Title: Unit 6 - LD_PRELOAD File I/O Hook

Files:
  - ~/.local/lib/libqcapture.so (new, C, 200 lines)
  - ~/.local/bin/qcapture-compile.sh (new, 50 lines build script)
  - tests/test-unit-6-ldpreload.sh (new, 100 lines)

Scope:
Intercept open(), write(), read() calls via LD_PRELOAD. Log JSONL writes to /tmp/qcapture.log.

Acceptance:
- [ ] libqcapture.so compiles with gcc -shared -fPIC, no warnings
- [ ] LD_PRELOAD=libqcapture.so claude ... logs file ops to /tmp/qcapture.log
- [ ] Captures JSONL writes before cli.js processes them
- [ ] Tests: 6/6 passing (no segfault, clean interception)
```

---

### Batch 3: Code Analysis (Units 7-9)

#### Issue #7: Unit 7 - JavaScript Beautifier & Decompile
```
Title: Unit 7 - JavaScript Beautifier & Decompile

Files:
  - ~/.local/bin/qdecompile-js (new, 80 lines bash)
  - cli.js.beautified (generated, ~20k lines)
  - tests/test-unit-7-decompile.sh (new, 50 lines)

Scope:
Use js-beautify (or node built-in) to expand minified cli.js.
Extract all string literals, function signatures, API call sites.

Acceptance:
- [ ] Generates cli.js.beautified with proper indentation
- [ ] All string literals extracted and annotated with line numbers
- [ ] No syntax errors in beautified output
- [ ] Tests: 5/5 passing
```

#### Issue #8: Unit 8 - CLI Argument & Environment Mapper
```
Title: Unit 8 - CLI Argument & Environment Mapper

Files:
  - ~/.local/bin/qargv-map (new, 120 lines bash/Python)
  - argv-map.json (output schema, ~100 lines)
  - tests/test-unit-8-argv-map.sh (new, 60 lines)

Scope:
Parse beautified cli.js for process.argv, process.env, process.stdin handling.
Build map: which env vars influence behavior, which argv patterns trigger code paths.

Acceptance:
- [ ] Outputs argv-map.json with schema of recognized arguments
- [ ] Identifies all env var references in cli.js
- [ ] Maps: arg -> code path (line number in cli.js)
- [ ] Tests: 8/8 passing
```

#### Issue #9: Unit 9 - Memory Map Inspector
```
Title: Unit 9 - Memory Map Inspector

Files:
  - ~/.local/bin/qmemmap-read (new, 100 lines bash)
  - tests/test-unit-9-memmap.sh (new, 60 lines)

Scope:
Parse /proc/{PID}/maps, show memory layout (heap, stack, mmap regions).
Correlate with symbols from cli.js binary.

Acceptance:
- [ ] Parses /proc/{PID}/maps for running claude process
- [ ] Output: [{"region": "heap", "start": "0x...", "end": "0x...", "perms": "rw-"}]
- [ ] Identifies main binary, libraries, heap vs stack
- [ ] Tests: 7/7 passing
```

---

### Batch 4: Integration & Verification Part 1 (Units 10-12)

#### Issue #10: Unit 10 - Integrated Sensor Orchestrator
```
Title: Unit 10 - Integrated Sensor Orchestrator

Files:
  - ~/.local/bin/qreveng-daemon (new, 200 lines bash)
  - tests/test-unit-10-daemon.sh (new, 100 lines)

Scope:
Co-run qsession-id + qtail-jsonl + qenv-snapshot in parallel.
Emit unified JSON stream to ~/.aurora-agent/qreveng.jsonl.

Acceptance:
- [ ] qreveng-daemon starts without errors
- [ ] Emits unified JSON records to ~/.aurora-agent/qreveng.jsonl
- [ ] Each record includes: timestamp, unit (1-9), data, source
- [ ] Tests: 8/8 passing
- [ ] Can be backgrounded: `qreveng-daemon & DAEMON_PID=$!`
```

#### Issue #11: Unit 11 - Control Plane Integration (qhoami/qlaude updates)
```
Title: Unit 11 - Control Plane Integration

Files:
  - qhoami (modify, +50 lines to integrate qjsonl-truth)
  - qlaude (modify, +30 lines to log to qreveng.jsonl)
  - tests/test-unit-11-integration.sh (new, 80 lines)

Scope:
Update qhoami --sense-model to use qjsonl-truth (Unit 5) instead of unfiltered JSONL.
Update qlaude to log actions to qreveng.jsonl.

Acceptance:
- [ ] qhoami --sense-model uses Unit 5 filtering
- [ ] qlaude logs to ~/.aurora-agent/qreveng.jsonl on each action
- [ ] No breaking changes to existing qhoami/qlaude CLI
- [ ] Tests: 10/10 passing (existing tests still pass + new integration tests)
```

#### Issue #12: Unit 12 - Test Suite & Documentation
```
Title: Unit 12 - Test Suite & Documentation

Files:
  - tests/qreveng-test.sh (new master test, 300 lines)
  - REVENGINEER-UNITS-1-12.md (new documentation, 500 lines)

Scope:
Comprehensive bash test suite exercising Units 1-11 in concert.
Document tool chain, usage, troubleshooting.

Acceptance:
- [ ] bash tests/qreveng-test.sh --unit=N works for all N=1-11
- [ ] bash tests/qreveng-test.sh --batch=1 tests Units 1-3 together
- [ ] bash tests/qreveng-test.sh --e2e runs full end-to-end
- [ ] E2E test passes: spawn Claude Code, capture with qreveng-daemon, verify consistency
- [ ] All tests: 40+/40+ passing
- [ ] Documentation complete, no TODOs
```

---

### Batch 5: Advanced Capabilities (Units 13-15)

#### Issue #13: Unit 13 - Network Packet Capture Analyzer
```
Title: Unit 13 - Network Packet Capture Analyzer

Files:
  - ~/.local/bin/qcapture-net (new, 150 lines bash)
  - tests/test-unit-13-packet-capture.sh (new, 80 lines)

Scope:
Use tcpdump to sniff HTTPS traffic from claude CLI to api.anthropic.com.
Parse TLS metadata (SNI, cert, packet size patterns).

Acceptance:
- [ ] qcapture-net <duration-seconds> captures packets to /tmp/qcapture.pcap
- [ ] Extracts SNI from TLS handshake
- [ ] Outputs JSON: {"sni": "api.anthropic.com", "cert_subject": "...", "packet_count": N}
- [ ] Tests: 6/6 passing
- [ ] No sudo required (uses standard tcpdump if available, or warns gracefully)
```

#### Issue #14: Unit 14 - Node.js Debugger Attachment
```
Title: Unit 14 - Node.js Debugger Attachment

Files:
  - ~/.local/bin/qdebug-attach (new, 100 lines bash/node)
  - tests/test-unit-14-debugger.sh (new, 60 lines)

Scope:
Connect to Node.js debugger on port 9229 (claude --inspect).
Set breakpoint in message creation, emit context variables.

Acceptance:
- [ ] Script to launch claude with --inspect: `claude --inspect`
- [ ] qdebug-attach <PID> connects to debugger port
- [ ] Sets breakpoint, resumes, captures context
- [ ] Output: {"breakpoint_hit": "message_creation", "context": {...}}
- [ ] Tests: 5/5 passing (mocked debugger if real debugger unavailable)
```

#### Issue #15: Unit 15 - Wrapper Process Tracer
```
Title: Unit 15 - Wrapper Process Tracer

Files:
  - ~/.local/bin/qwrapper-trace (new, 120 lines bash)
  - tests/test-unit-15-wrapper.sh (new, 70 lines)

Scope:
Bash wrapper around cli.js invocation. Pre-hook: capture argv, environ, stdin.
Post-hook: capture stdout, stderr, exit code, /proc state changes.

Acceptance:
- [ ] qwrapper-trace claude --version works identically to claude --version
- [ ] Logs all captures to /tmp/qwrapper-trace.jsonl
- [ ] Output format: {"event": "pre|post", "argv": [...], "stdout": "...", "exit_code": 0}
- [ ] Tests: 8/8 passing
```

---

## Deployment Sequence

### Pre-Deployment Checklist
- [ ] All 15 GitHub issues created with full acceptance criteria
- [ ] Batch 1 agents assigned (Units 1-3)
- [ ] This document in place
- [ ] Agent prompt templates ready with token budgets

### Batch 1: Deploy at T+0:00
```bash
# Create 3 agents with isolation: worktree
Agent 1: Unit 1 (qsession-id)
Agent 2: Unit 2 (qtail-jsonl)
Agent 3: Unit 3 (qenv-snapshot)

# Each agent:
# 1. Reads Unit N issue from GitHub
# 2. Implements tool + tests
# 3. Runs: bash tests/test-unit-N-*.sh
# 4. Creates PR titled "Unit N: [Title]"
# 5. Reports: "PR: <url>" or "PR: none — <reason>"
```

**Expected completion:** T+0:30 to T+0:45
**Manual step:** Merge PRs into main
**Quota used:** ~30k tokens

### Wait: T+0:45 to T+2:00 (Quota buffer, merge PRs)

### Batch 2: Deploy at T+2:05
```bash
# Assign Units 4-6 (File descriptors, JSONL parser, LD_PRELOAD)
# Same workflow as Batch 1
```

**Expected completion:** T+2:30 to T+2:45
**Quota used:** ~30k tokens

### Wait: T+2:45 to T+4:00 (Quota buffer, merge PRs)

### Batch 3: Deploy at T+4:05
```bash
# Assign Units 7-9 (Decompile, argv-map, memmap)
# Same workflow
```

**Expected completion:** T+4:30 to T+4:45
**Quota used:** ~30k tokens

### Wait: Next day (Quota window reset)

### Batch 4: Deploy at Day2 T+0:00
```bash
# Assign Units 10-12 (Daemon, integration, test suite)
# Same workflow
```

### Batch 5: Deploy at Day2 T+4:00
```bash
# Assign Units 13-15 (Packet capture, debugger, wrapper)
# Same workflow
```

---

## Resilience to Agent Abortion

**Scenario:** Agent 3 (Unit 3) runs out of tokens mid-implementation.

**What happens:**
1. Agent stops, notes "token exhausted" in PR draft
2. Work is in worktree branch `unit-3-env-snapshot`
3. PR is either draft or not created

**Recovery:**
1. Human checks Unit 3 issue for completion status
2. If >80% done: human merges partial work, opens follow-up issue for remainder
3. If <80% done: human closes draft PR, reassigns Unit 3 to next available agent
4. Next agent inherits `unit-3-env-snapshot` branch, rebases on main, continues

**Design principle:** Every unit is small enough (~100-150 lines) that even 50% completion is useful, and next agent can finish.

---

## Success Metrics

| Metric | Target | Evidence |
|--------|--------|----------|
| All units compile/run without errors | 15/15 ✓ | qreveng-test.sh passes all units |
| All unit tests pass | 15/15 ✓ | test-unit-N output shows 100% pass rate |
| E2E test validates sensor consistency | Pass ✓ | E2E test: spawn claude, qreveng-daemon, verify model detection |
| All PRs merged to main | 15/15 ✓ | Main branch has all 15 commits |
| Quota not exceeded | <100k tokens ✓ | Token counter shows <100k per 24hrs |
| Deployment time | ~2 days ✓ | Batches complete on schedule |

---

## Token Budget Allocation

**Per agent (conservative estimate):**
- Implementation: 4-6k tokens (code + tests)
- Debugging/errors: 2-3k tokens (typos, test failures)
- Integration: 1-2k tokens (linking with other units)
- **Total per unit:** ~8-10k tokens

**Total for all 15 units:** ~120-150k tokens (well within monthly quota with buffer)

---

## Next Steps

1. **Coordinator creates all 15 GitHub issues** (this document)
2. **Assign Batch 1 agents** (Units 1-3) with full issue details + this doc linked
3. **Deploy Batch 1** (3 agents, background, isolation: worktree)
4. **Wait for PRs** → verify + merge
5. **Repeat for Batches 2-5**

---

**Status: READY FOR BATCH 1 DEPLOYMENT**

See `/home/aurora/repo-staging/claude-code-control/REVENGINEER-CONTROL-PLANE.md` for full details.

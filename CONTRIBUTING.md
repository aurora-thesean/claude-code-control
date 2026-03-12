# Contributing to Aurora Control Plane

Thank you for your interest in contributing! This guide explains how to extend, improve, and maintain the Aurora Control Plane toolkit.

---

## Getting Started

### Setup Development Environment
```bash
# Clone the repository
git clone https://github.com/aurora-thesean/claude-code-control.git
cd claude-code-control

# Verify prerequisites
bash --version  # 4.0+
python3 --version  # 3.7+
grep --version
awk --version

# Optional: install shellcheck for linting
# apt-get install shellcheck (Ubuntu/Debian)
# brew install shellcheck (macOS)
```

### Understand the Architecture

Read these documents **in order**:
1. **DESIGN.aurora-claude-code-control.md** — Core concepts (7 dimensions, ground truth sources)
2. **REVENGINEER.md** — Toolkit overview (15 units, all responsibilities)
3. **DEPLOYMENT.md** — How tools are used by end users
4. **PROJECT-STATUS.md** — Current state, limitations, roadmap

### Explore the Codebase

```bash
# Main tools (in order of complexity)
qreveng-daemon      # 260 lines - orchestrator, simplest entry point
qlaude              # 839 lines - motor/action tool with gating logic
qhoami              # 700 lines - identity sensor, most complex

# Test suite
qreveng-test.sh     # Original test suite (Units 1-15)
qreveng-e2e-test.sh # Integration tests (10 tests)

# Documentation
REVENGINEER.md      # Complete toolkit guide
PHASE-3-BENCHMARK.md # Performance analysis (understand limitations)
PHASE-4-FINDINGS.md # Bash optimization research
```

---

## Common Contribution Patterns

### 1. Add a New Sensor (like qhoami dimensions)

**Pattern:** Extract ground truth from a new source, add to qhoami output.

**Steps:**
1. Read the ground truth from filesystem/inotify/proc/config
2. Tag the source: GROUND_TRUTH, CONFIG, or HEURISTIC_FALLBACK
3. Add a `_sense_<dimension>()` function to qhoami
4. Integrate into `_build_identity()` and output JSON
5. Add test to qreveng-e2e-test.sh
6. Document in REVENGINEER.md

**Example:** Adding a new dimension
```bash
_sense_new_dimension() {
  local uuid="$1"
  # Ground truth extraction
  local value=$(...)
  local source_type="GROUND_TRUTH"
  local source_note="..."
  echo "$value|$source_type|$source_note"
}

# In _build_identity():
IFS='|' read -r new_val new_src new_note < <(_sense_new_dimension "$uuid")

# Add to JSON output
```

### 2. Enhance qlaude Gates

**Pattern:** Add new gate types or approval logic.

**Steps:**
1. Review current gates in qlaude (--resume, --fork, --autonomous-loop)
2. Add new `_gate_<operation>()` function
3. Implement approval logic (--confirm, rate-limit check, AGENTS.md check)
4. Log decision to audit trail
5. Test with different LOA_CAP values
6. Document in qlaude.md

**Gate Types:**
- QC0_HUMAN_ONLY: Always require confirmation
- QC1_SUPERVISED: Auto-approve with rate limiting
- QC2_FULLY_AUTONOMOUS: Auto-approve, log to GitHub

### 3. Add a REVENGINEER Unit

**Pattern:** Implement a new reverse-engineering sensor (like Units 1-15).

**Steps:**
1. Choose your unit from REVENGINEER.md decomposition
2. Create `q<unit-name>.sh` or compiled binary
3. Implement ground truth extraction
4. Output JSON with source attribution
5. Create unit test: `bash qreveng-test.sh --unit=N`
6. Document in REVENGINEER.md
7. Integrate with qreveng-daemon if applicable

**Conventions:**
- All tools output JSON (not plain text)
- Include `"source": "GROUND_TRUTH|CONFIG|HEURISTIC_FALLBACK"` for every fact
- Log errors to stderr, exit code 1 on failure
- No external dependencies except bash, python3, standard Unix tools

### 4. Improve Performance

**Pattern:** Optimize existing tools while maintaining correctness.

**Read First:**
- PHASE-3-BENCHMARK.md — Current performance and bottlenecks
- PHASE-4-FINDINGS.md — Why certain optimizations didn't work

**Approach:**
1. Profile with time/strace to identify bottleneck
2. Propose optimization with expected % improvement
3. Implement and measure (3 runs, report avg)
4. Ensure 100% backward compatibility (no API changes)
5. Test with qreveng-e2e-test.sh
6. Document findings in PHASE-5-FINDINGS.md

**Success Criteria:**
- Measurable improvement (>10% preferred)
- Zero breaking changes
- All tests pass
- Documentation updated

### 5. Expand Test Coverage

**Pattern:** Add new tests to qreveng-e2e-test.sh.

**Current Tests:**
1. qhoami JSON validity
2. qhoami has all 7 dimensions
3. qhoami source attribution
4. qhoami source types valid
5. qlaude --list-siblings works
6. qreveng-daemon --help works
7-8. Performance benchmarks
9-10. Audit log tests

**New Test Ideas:**
- Multi-turn session tracking
- Model switch detection
- Subagent lineage validation
- Gate rejection scenarios
- Rate limiting enforcement
- Audit log completeness

---

## Code Style & Best Practices

### Bash Style

**Do:**
- Use `set -euo pipefail` at the top
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Check exit codes explicitly
- Log important decisions
- Document non-obvious code

**Don't:**
- Use bashisms (test portability)
- Ignore errors (fail early)
- Mix stdout/stderr (parse one, log other)
- Create temp files without cleanup
- Hardcode paths (use `$HOME`, not `/home/user`)

**Example Pattern:**
```bash
#!/usr/bin/env bash
set -euo pipefail

_log() { echo "[tool] $*" >&2; }
_error() { echo "ERROR: $*" >&2; exit 1; }

_do_thing() {
  local input="$1"
  [[ -n "$input" ]] || _error "input required"

  local result
  result=$(grep "pattern" "$input" 2>/dev/null) || _error "grep failed"

  echo "$result"
}

main() {
  _do_thing "$@"
}

main "$@"
```

### JSON Output

**Standard format:**
```bash
echo '{
  "type": "sensor|data|error",
  "timestamp": "2026-03-12T14:00:00Z",
  "unit": "N",
  "data": {
    "field": "value"
  },
  "source": "GROUND_TRUTH|CONFIG|HEURISTIC_FALLBACK",
  "error": null
}'
```

### Error Handling

**Pattern:**
```bash
# Good: Explicit error handling
local result
result=$(command 2>/dev/null) || {
  _error "command failed"
  return 1
}

# Bad: Silent failure
result=$(command)  # If command fails, result is empty and silently proceeds
```

### Testing

**Unit Test:**
```bash
test_my_function() {
  local result
  result=$(_my_function "input")

  if [[ "$result" == "expected" ]]; then
    echo "✓ test passed"
    return 0
  else
    echo "✗ test failed: got $result, expected expected"
    return 1
  fi
}
```

---

## Git Workflow

### Before Committing

```bash
# Check syntax
bash -n qhoami qlaude qreveng-daemon

# Run tests
bash qreveng-e2e-test.sh

# Check with shellcheck (optional)
shellcheck qhoami qlaude qreveng-daemon || true
```

### Commit Messages

**Format:**
```
<scope>: <summary>

<detailed explanation if needed>
```

**Examples:**
- `qhoami: add new dimension for X tracking`
- `qlaude: optimize gate logic for performance`
- `tests: add E2E test for multi-turn sessions`
- `docs: clarify ground truth sourcing strategy`

### Creating a PR

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make changes, commit with clear messages
3. Run full test suite: `bash qreveng-e2e-test.sh`
4. Push and create PR with:
   - Clear title (what changed)
   - Description (why changed)
   - Testing notes (how you verified)
   - Links to issues (if applicable)

---

## Adding Documentation

### When to Document

- New tools or features
- Complex logic that isn't self-evident
- Ground truth sourcing (always explain WHERE the value comes from)
- Performance characteristics
- Known limitations

### Where to Document

- **README.md** — Project overview
- **DEPLOYMENT.md** — User-facing installation/usage
- **REVENGINEER.md** — Toolkit details
- **qlaude.md** — Motor tool guide
- **DESIGN.md** — Architecture decisions
- **Code comments** — Non-obvious logic

---

## Performance Considerations

### Know the Bottlenecks

From PHASE-3-BENCHMARK.md and PHASE-4-FINDINGS.md:
- qhoami: **I/O-bound** (JSONL parsing, 8353+ lines)
- qlaude: Process-bound (Python subprocess spawning)
- qreveng-daemon: Already optimal

### Before Optimizing

1. **Measure first** — Use `/usr/bin/time -v` or `time` builtin
2. **Identify bottleneck** — Is it I/O, CPU, subprocess creation?
3. **Propose change** — What's expected % improvement?
4. **Implement** — Keep code simple, optimize judiciously
5. **Verify** — Run 3 times, report average
6. **Document** — Update PHASE-3 or PHASE-4 findings

### Optimization Lessons (Hard-Won)

- ✅ Fast path lookups work (try direct UUID match before search)
- ✅ Parallel independent sensors help (+15%)
- ✅ grep+awk pipelines > single-pass awk
- ❌ Module-based caching added overhead (too slow)
- ❌ Single-pass awk parsing slower than pipeline
- ❌ Regex-based JSON parsing too brittle (use Python)

**Conclusion:** Bash optimization ceiling is ~46s for I/O-bound workloads. Compile if faster needed.

---

## Reporting Issues

### Include

- Exact command you ran
- Full error output
- Operating system & bash version
- Relevant session UUID (from `qhoami --self`)
- What you expected vs. what happened

### Example Issue

```
Title: qhoami --self returns incorrect model

Steps:
1. Run `claude`
2. Inside session: `qhoami --self | jq .model`

Expected: `{"value":"claude-sonnet-4-6", ...}`
Got: `{"value":"claude-haiku-4-5", ...}`

Environment: Ubuntu 22.04, bash 5.1.16, python3 3.10
```

---

## Code Review Checklist

Before submitting a PR, verify:

- [ ] Syntax is correct (`bash -n`)
- [ ] All tests pass (`bash qreveng-e2e-test.sh`)
- [ ] No hardcoded paths (use `$HOME`, `$SCRIPT_DIR`, etc.)
- [ ] Errors logged to stderr, success to stdout
- [ ] JSON output is valid and has source attribution
- [ ] Backward compatible (no API changes)
- [ ] Commit messages are clear
- [ ] Documentation is updated
- [ ] No external dependencies added
- [ ] Performance impact measured (if relevant)

---

## Questions?

- Check **PROJECT-STATUS.md** for project roadmap
- Read **DESIGN.md** for architectural decisions
- Look at existing code for patterns
- Open an issue on GitHub

---

## Thank You!

Your contributions make Aurora Control Plane better for everyone. Whether it's bug fixes, new features, better tests, or clearer docs — we appreciate it! 🙏

---

**Happy coding!**

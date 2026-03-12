# Aurora Control Plane Deployment Guide
**Version:** v0.2.0 | **Target:** Aurora Linux machines | **Effort:** ~15 minutes

---

## Quick Start (5 minutes)

### 1. Clone Repository
```bash
cd ~
git clone https://github.com/aurora-thesean/claude-code-control.git
cd claude-code-control
```

### 2. Install Tools
```bash
# Create symlinks in ~/.local/bin
mkdir -p ~/.local/bin
ln -sf "$(pwd)/qhoami" ~/.local/bin/qhoami
ln -sf "$(pwd)/qlaude" ~/.local/bin/qlaude
ln -sf "$(pwd)/qreveng-daemon" ~/.local/bin/qreveng-daemon

# Make executable
chmod +x qhoami qlaude qreveng-daemon
```

### 3. Test Installation
```bash
# From inside a Claude Code session:
~/.local/bin/qhoami --self

# Should output JSON with 7 dimensions (avatar, sidecar, generation, model, qc_level, memory_scope, location)
```

---

## Full Installation (15 minutes)

### Prerequisites
```bash
# Verify you have:
bash --version      # ≥4.0
grep --version      # Any version
awk --version       # Any version (gawk/mawk/nawk)
python3 --version   # ≥3.7
stat --version      # Part of coreutils
readlink --version  # Part of coreutils
ps --version        # Part of procps
```

### Installation Steps

#### Step 1: Repository Setup
```bash
git clone https://github.com/aurora-thesean/claude-code-control.git
cd claude-code-control

# Verify version
git tag -l | tail -3  # Should show v0.1.0-alpha, v0.1.0, v0.2.0
```

#### Step 2: Dependencies
All dependencies are POSIX standard tools. No external package installation needed.

```bash
# Verify dependencies are available
which bash grep awk python3 stat readlink ps
```

#### Step 3: Installation Paths

**Option A: User-local installation (recommended)**
```bash
mkdir -p ~/.local/bin
cp qhoami qlaude qreveng-daemon ~/.local/bin/
chmod +x ~/.local/bin/qhoami ~/.local/bin/qlaude ~/.local/bin/qreveng-daemon

# Add to PATH if not already there
grep -q '~/.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Option B: System-wide installation (requires sudo)**
```bash
sudo cp qhoami qlaude qreveng-daemon /usr/local/bin/
sudo chmod +x /usr/local/bin/qhoami /usr/local/bin/qlaude /usr/local/bin/qreveng-daemon
```

#### Step 4: Configuration

**Optional: Set LOA_CAP in CLAUDE.md**
```bash
# ~/.claude/CLAUDE.md should contain:
LOA_CAP=2     # or 4 or 6, depending on your autonomy level

# qlaude uses this to gate operations:
# LOA 2 = QC0_HUMAN_ONLY (requires manual confirmation)
# LOA 4 = QC1_SUPERVISED (auto-approve, rate-limited to 100/hour)
# LOA 6 = QC2_FULLY_AUTONOMOUS (no confirmation needed)
```

**Optional: Create ~/.aurora-agent directory**
```bash
mkdir -p ~/.aurora-agent
# This is where qlaude stores audit logs and state
```

#### Step 5: Verification
```bash
# Inside a Claude Code session:
qhoami --self

# Expected output: JSON with 7 dimensions, including your current session UUID, model, and authority level

# Test list-siblings
qlaude --list-siblings

# Expected: List of session IDs that share your parent UUID (or error if none exist)
```

---

## Usage

### qhoami — Identity Sensor

**Learn your Claude Code session's 7-dimensional identity:**
```bash
qhoami --self
```

Output: JSON with dimensions:
- **avatar** — Your workspace (HOME, DOWNLOADS, UNDERBAR, etc.)
- **sidecar** — Your lineage relationship (NONE, CHILD, AUTONOMY, etc.)
- **generation** — How many reboots back your lineage extends
- **model** — Which Claude version (HAIKU, SONNET, OPUS, LOCAL)
- **qc_level** — Your autonomy authority (QC0_HUMAN_ONLY, QC1_SUPERVISED, QC2_FULLY_AUTONOMOUS)
- **memory_scope** — Your context persistence (NONE, FILE_ONLY, RESUMED, COMPACTED)
- **location** — Where you're running (AURORA_LOCAL, LAN_CARVIO, REMOTE, etc.)

**Other operations:**
```bash
qhoami <uuid>          # Query a specific session UUID
qhoami --all           # Show all running Claude sessions
qhoami --enum-values   # Print enum definitions
```

### qlaude — Motor/Action Tool

**List sessions with the same parent (siblings):**
```bash
qlaude --list-siblings
```

**Resume a session (under gate protection):**
```bash
qlaude --resume <uuid>
# Behavior depends on your LOA_CAP:
# - LOA 2: Requires human confirmation
# - LOA 4: Auto-approved, rate-limited
# - LOA 6: Auto-approved, unlimited
```

**Check gate authorization:**
```bash
qlaude --distance-to <uuid>     # Hops to common ancestor
qlaude --trace-lineage [<uuid>] # Full ancestry tree
```

### qreveng-daemon — Orchestrator

**Run the integrated reverse-engineering daemon:**
```bash
qreveng-daemon &
# Runs in background, collecting sensor data to ~/.aurora-agent/qreveng.jsonl
```

---

## REVENGINEER Toolkit (Advanced)

If you want the full 15-unit reverse-engineering toolkit:

```bash
# Units 1-5: Ground truth sensors
qsession-id            # Session UUID via inotify
qtail-jsonl            # Real-time JSONL monitoring
qenv-snapshot <PID>    # Process environment inspection
qfd-trace <PID>        # File descriptor analysis
qjsonl-truth <UUID>    # JSONL filtering by sessionId

# Units 6-12: Interception & analysis
qcapture-net           # Network packet analysis
qwrapper-trace         # Process pre/post-invoke tracing
qdecompile-js          # CLI.js beautification
qargv-map              # Argument mapper
qmemmap-read <PID>     # Memory layout inspection

# Unit 13: Integrated orchestrator
qreveng-daemon         # Unified sensor stream

# Unit 15: Test suite
bash qreveng-test.sh   # Comprehensive test suite
```

See `REVENGINEER.md` for detailed documentation.

---

## Troubleshooting

### qhoami Returns "ERROR: not inside a claude process tree"
**Cause:** You're not running from within a Claude Code session.
**Fix:** Run `qhoami --self` from inside a Claude Code interactive session (e.g., `claude`).

### qhoami --self Takes 45+ Seconds
**Cause:** This is normal. qhoami scans JSONL files for your session metadata.
**Fix:** If you need faster response, see PHASE-4-FINDINGS.md for performance analysis.

### qlaude --list-siblings Returns "Could not find siblings"
**Cause:** Your session is a root session (no parent UUID), or JSONL file not found.
**Fix:** Check that `~/.claude/projects/{uuid}.jsonl` exists.

### "Python 3 not found"
**Cause:** qlaude and some REVENGINEER units require Python 3.
**Fix:** Install Python 3: `apt-get install python3` (Ubuntu/Debian) or `brew install python3` (macOS).

### Audit Log Not Created
**Cause:** `~/.aurora-agent/` directory doesn't exist, or insufficient permissions.
**Fix:** Run `mkdir -p ~/.aurora-agent && chmod 700 ~/.aurora-agent`

---

## Performance Expectations

| Tool | Operation | Time | Notes |
|------|-----------|------|-------|
| qhoami | --self | 40-60s | I/O-bound on JSONL parsing (first run may be slower) |
| qlaude | --list-siblings | 30-45s | Depends on JSONL file size |
| qreveng-daemon | startup | <1s | Fast, lightweight orchestrator |

**Why so slow?** qhoami scans 8353+ records in your session JSONL file. This is unavoidable in bash—see PHASE-4-FINDINGS.md for optimization analysis.

---

## Integration with Claude Code

### Shell Integration (Optional)
```bash
# Add to ~/.zshrc or ~/.bashrc:
alias qhoami='~/.local/bin/qhoami'
alias qlaude='~/.local/bin/qlaude'

# Run qhoami at session start to verify identity
~/.local/bin/qhoami --self | jq .uuid  # Print your session UUID
```

### Autonomous Loops (Advanced)
```bash
# Schedule qreveng-daemon to run every 30 minutes
# See /loop command documentation in Claude Code
/loop 30m qreveng-daemon

# View scheduled tasks
CronList
```

---

## Uninstallation

```bash
# Remove symlinks
rm ~/.local/bin/qhoami ~/.local/bin/qlaude ~/.local/bin/qreveng-daemon

# Remove REVENGINEER units (if installed)
rm ~/.local/bin/q{session-id,tail-jsonl,env-snapshot,fd-trace,jsonl-truth,capture-net,wrapper-trace,decompile-js,argv-map,memmap-read,reveng-daemon}

# Remove audit logs (optional)
rm -rf ~/.aurora-agent/

# Remove repository (optional)
rm -rf ~/claude-code-control/
```

---

## Support & Feedback

- **GitHub Issues:** https://github.com/aurora-thesean/claude-code-control/issues
- **Documentation:** See REVENGINEER.md, qlaude.md, PHASE-3-BENCHMARK.md
- **Architecture:** Read DESIGN.aurora-claude-code-control.md

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v0.1.0-alpha | 2026-03-08 | Initial implementation (15 REVENGINEER units) |
| v0.1.0 | 2026-03-08 | Refactored with DRY modules |
| v0.2.0 | 2026-03-12 | Performance optimizations (+35-74%) |

---

**Deployment guide v0.2.0 | Last updated 2026-03-12**

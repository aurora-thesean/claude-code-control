# Aurora Control Plane: Getting Started Tutorial

**Time Required:** 15 minutes | **Level:** Beginner | **Outcome:** Understand and use Aurora Control Plane

---

## What You'll Learn

By the end of this tutorial, you'll:
1. Install Aurora Control Plane
2. Understand your Claude Code session's 7-dimensional identity
3. Query related sessions and ancestry
4. Understand autonomy approval gates
5. Know what happens behind the scenes

---

## Prerequisites

- A Claude Code session (run `claude` in your terminal)
- Bash 4.0+
- Python 3.7+
- Basic comfort with terminal commands

---

## Step 1: Install (5 minutes)

### 1.1 Clone the Repository

```bash
cd ~
git clone https://github.com/aurora-thesean/claude-code-control.git
cd claude-code-control
```

### 1.2 Verify Prerequisites

```bash
bash --version    # Should be 4.0 or higher
python3 --version # Should be 3.7 or higher
grep --version    # Any version is fine
awk --version     # Any version is fine
```

### 1.3 Install to Your PATH

```bash
# Create ~/.local/bin if it doesn't exist
mkdir -p ~/.local/bin

# Copy the tools
cp qhoami qlaude qreveng-daemon ~/.local/bin/

# Make them executable
chmod +x ~/.local/bin/qhoami ~/.local/bin/qlaude ~/.local/bin/qreveng-daemon

# Add to your PATH (if not already there)
if ! grep -q '~/.local/bin' ~/.bashrc ~/.zshrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  source ~/.zshrc
fi
```

### 1.4 Verify Installation

```bash
which qhoami qlaude qreveng-daemon
# Should output three paths in ~/.local/bin
```

---

## Step 2: Your First Command (2 minutes)

### 2.1 Open a Claude Code Session

```bash
claude
# Wait for the session to start and display the prompt
```

### 2.2 Inside the Session, Run qhoami

```bash
qhoami --self
```

**What you'll see:** A JSON object with 7 dimensions of your session identity.

```json
{
  "uuid": "1d08b041-305c-4023-83f7-d472449f7c6f",
  "pid": 2412470,
  "avatar": {
    "value": "AVATAR_HOME",
    "source": "GROUND_TRUTH",
    "from": "/proc/2412470/cwd = /home/aurora (GROUND_TRUTH)"
  },
  "sidecar": {
    "value": "SIDECAR_NONE",
    "source": "GROUND_TRUTH",
    "from": "parentUuid is null in JSONL (GROUND_TRUTH)"
  },
  "generation": {
    "value": "GEN_0",
    "source": "GROUND_TRUTH",
    "from": "no compacted ancestors in JSONL (GROUND_TRUTH)"
  },
  "model": {
    "value": "claude-sonnet-4-6",
    "source": "GROUND_TRUTH",
    "from": "Session JSONL message.model field"
  },
  "qc_level": {
    "value": "QC2_FULLY_AUTONOMOUS",
    "source": "CONFIG",
    "from": "LOA_CAP=6 in /home/aurora/.claude/CLAUDE.md (CONFIG)"
  },
  "memory_scope": {
    "value": "MEM_RESUMED",
    "source": "HEURISTIC_FALLBACK",
    "from": "8947 records in JSONL (HEURISTIC_FALLBACK)"
  },
  "location": {
    "value": "LOC_AURORA_LOCAL",
    "source": "GROUND_TRUTH",
    "from": "hostname = aurora (GROUND_TRUTH)"
  },
  "jsonl": "/home/aurora/.claude/projects/-home-aurora/1d08b041-305c-4023-83f7-d472449f7c6f.jsonl"
}
```

---

## Step 3: Understanding the 7 Dimensions (3 minutes)

Each dimension tells you something about your session:

### avatar — Where You're Working

**Values:**
- `AVATAR_HOME` — In your home directory
- `AVATAR_DOWNLOADS` — In ~/Downloads
- `AVATAR_UNDERBAR` — In ~/_ (experimental folder)
- `AVATAR_DUNDERBAR` — In ~/__ (semi-global)
- `AVATAR_THUNDERBAR` — In ~/___  (global/approved)
- `AVATAR_CUSTOM` — Somewhere else

**What it means:** Your current working directory when you started this Claude Code session.

**Example use:** "I'm in a production repo (AVATAR_DUNDERBAR), so be extra careful."

### sidecar — Your Lineage

**Values:**
- `SIDECAR_NONE` — Root session (no parent)
- `SIDECAR_CHILD` — Spawned by another session
- `SIDECAR_AUTONOMY` — Special coordination with parent
- `SIDECAR_UNKNOWN` — Can't determine

**What it means:** Are you a top-level agent, or were you spawned by another agent?

**Example use:** "I was spawned by my parent session, so I should report decisions back."

### generation — How Many Reboots Back

**Values:** `GEN_0`, `GEN_1`, `GEN_2`, ...

**What it means:** How many session boundaries exist in your ancestry (how many "restarts" happened before you were created).

**Example use:** "I'm GEN_0, the first generation—no ancestors in my lineage."

### model — Which Claude Are You?

**Values:**
- `claude-haiku-4-5` — Fast, specialized tasks
- `claude-sonnet-4-6` — Balanced general-purpose
- `claude-opus-4-6` — Complex reasoning
- `MODEL_LOCAL` — Running locally (lm-studio)

**What it means:** Which Claude version is running this session.

**Example use:** "I'm Haiku—fast but less capable. Complex tasks should ask Sonnet."

### qc_level — Your Authority Level

**Values:**
- `QC0_HUMAN_ONLY` — Everything requires human approval
- `QC1_SUPERVISED` — Some things auto-approve, rate-limited
- `QC2_FULLY_AUTONOMOUS` — Full autonomy (decisions logged)

**What it means:** How much you're trusted to act independently.

**Example use:** "I'm QC2 fully autonomous—I can execute decisions without asking."

### memory_scope — Your Context Persistence

**Values:**
- `MEM_NONE` — No prior conversations
- `MEM_FILE_ONLY` — Only current conversation
- `MEM_RESUMED` — Continued from prior session
- `MEM_COMPACTED` — Huge history, compacted

**What it means:** How much conversation history you have access to.

**Example use:** "I'm MEM_RESUMED with 8947 records—I have substantial context."

### location — Where You're Running

**Values:**
- `LOC_AURORA_LOCAL` — On aurora.wordgarden.dev (me)
- `LOC_LAN_CARVIO` — On CARVIO machine (LAN)
- `LOC_REMOTE` — Somewhere on the internet
- `LOC_UNKNOWN` — Can't determine

**What it means:** Physical/network location of your Claude Code instance.

**Example use:** "I'm LOCAL, so I have filesystem access to all Aurora data."

---

## Step 4: Query Your Session (2 minutes)

### 4.1 List Related Sessions

```bash
qlaude --list-siblings
```

**Output:** Session IDs that share your parent (your "siblings").

If you're the root (SIDECAR_NONE), you'll be your own sibling.

### 4.2 Trace Your Ancestry

```bash
qlaude --trace-lineage
```

**Output:** Your full lineage tree (who spawned whom).

### 4.3 Get Distance to Another Session

```bash
qlaude --distance-to <uuid>
```

**Output:** How many hops to a common ancestor with another session.

---

## Step 5: What "Source Attribution" Means (2 minutes)

Each value in qhoami output has a `"source"` field:

### GROUND_TRUTH
**Definition:** Read directly from the operating system or filesystem.

**Examples:**
- Avatar read from `/proc/{PID}/cwd` (actual working directory)
- Model read from session JSONL (actual message.model field)
- Generation from parentUuid chain in JSONL

**Trust Level:** Highest. Can't be spoofed by environment variables.

### CONFIG
**Definition:** Read from configuration files that your agent controls.

**Examples:**
- QC_LEVEL from `~/.claude/CLAUDE.md` (your LOA_CAP setting)
- Generation from `~/.claude/tasks/{UUID}/.generation` file

**Trust Level:** Medium. Only accurate if the file is maintained correctly.

### HEURISTIC_FALLBACK
**Definition:** Inferred from available data when ground truth unavailable.

**Examples:**
- Memory scope estimated from record count
- Generation inferred from parent existence

**Trust Level:** Lowest. May be incorrect if assumptions don't hold.

---

## Step 6: Understanding Approval Gates (2 minutes)

Some operations are "protected"—they require approval based on your QC_LEVEL:

### Read-Only Operations (Always Allowed)

```bash
qlaude --list-siblings      # List related sessions
qlaude --distance-to <uuid> # Distance to another session
qlaude --trace-lineage      # Full ancestry tree
```

These always work, no approval needed.

### Protected Operations (Gate-Protected)

```bash
qlaude --resume <uuid>           # Resume a session
qlaude --fork <uuid>             # Create a subagent
qlaude --autonomous-loop <task>  # Start autonomous loop
```

These check your QC_LEVEL:

- **QC0 (HUMAN_ONLY):** Requires human to type "yes" at prompt
- **QC1 (SUPERVISED):** Auto-approve, but rate-limited (100 per hour)
- **QC2 (FULLY_AUTONOMOUS):** Auto-approve, decision logged to GitHub

---

## Step 7: See It in Action (1 minute)

### 7.1 Check Your Approval Level

```bash
qhoami --self | grep -A 3 '"qc_level"'
```

### 7.2 See Your Audit Log

```bash
cat ~/.aurora-agent/.qlaude-audit.jsonl
```

Each line is a decision Aurora made about an operation:
- When it happened
- What operation
- Did it approve or reject
- Why

---

## Common Questions

### Q: How long does qhoami take?

**A:** 40-60 seconds. It reads your session JSONL file (8000+ records) to find metadata. This is I/O-bound—see PHASE-3-BENCHMARK.md for details.

### Q: Why is source attribution important?

**A:** It tells you how reliable each fact is. GROUND_TRUTH values can't be spoofed. HEURISTIC_FALLBACK values are educated guesses.

### Q: What's a "warrant"?

**A:** Future feature (Phase 8). Parent agents will issue warrants to delegate work to children with negotiated autonomy levels. See NESTED_LOA.md.

### Q: Can I change my QC_LEVEL?

**A:** Only by editing `~/.claude/CLAUDE.md` and changing `LOA_CAP`. But be careful—this affects your autonomy across all sessions.

### Q: What happens if I exceed my QC_LEVEL?

**A:** qlaude rejects the operation and logs the attempt. You'll see an error message.

---

## Next Steps

### Learn More
- **[DEPLOYMENT.md](DEPLOYMENT.md)** — Installation details and troubleshooting
- **[REVENGINEER.md](REVENGINEER.md)** — The 15-unit toolkit
- **[PHASE-3-BENCHMARK.md](PHASE-3-BENCHMARK.md)** — Performance analysis
- **[NESTED_LOA.md](NESTED_LOA.md)** — Future hierarchical autonomy

### Try More Commands

```bash
# See all enum values
qhoami --enum-values

# Check all running sessions
qhoami --all

# Trace ancestry
qlaude --trace-lineage

# See distance to another session
qlaude --distance-to <uuid>
```

### Integrate with Your Workflow

```bash
# Add to your shell startup
alias qhoami='~/.local/bin/qhoami'
alias qlaude='~/.local/bin/qlaude'

# See your session UUID on startup
~/.local/bin/qhoami --self | jq .uuid
```

---

## Key Takeaways

1. **qhoami** tells you who you are (7 dimensions)
2. **qlaude** controls what you can do (approval gates)
3. **Source attribution** shows how reliable each fact is
4. **Audit logs** track all important decisions
5. **NESTED_LOA** (coming soon) will enable safe delegation

---

## Troubleshooting

### "qhoami: command not found"
- Check: `ls ~/.local/bin/qhoami`
- Fix: Re-run installation step 1.3

### "ERROR: not inside a claude process tree"
- Problem: You're not running inside a Claude Code session
- Fix: Run `qhoami --self` from inside `claude` session (not your outer shell)

### "qhoami takes 60 seconds!"
- Expected behavior. It reads 8000+ records from your session JSONL.
- See PHASE-3-BENCHMARK.md for performance details.

### "Permission denied" on audit log
- Problem: `~/.aurora-agent/` directory doesn't exist
- Fix: `mkdir -p ~/.aurora-agent && chmod 700 ~/.aurora-agent`

---

## You're Ready!

You now understand:
- The 7 dimensions of session identity
- How approval gates work
- What source attribution means
- How to query your session ancestry
- What happens behind the scenes

**Next:** Try `qhoami --self` in a Claude Code session and explore the output!

---

**Questions?** See DEPLOYMENT.md or open an issue on GitHub.

**Ready to build on this?** See CONTRIBUTING.md for developer guide.

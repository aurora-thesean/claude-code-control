# Aurora Claude Code Control Plane

**Deterministic identity sensing and autonomy-aware execution for Claude Code sessions.**

[![Tests](https://github.com/aurora-thesean/claude-code-control/actions/workflows/test.yml/badge.svg)](https://github.com/aurora-thesean/claude-code-control/actions)
[![GitHub Release](https://img.shields.io/github/v/release/aurora-thesean/claude-code-control)](https://github.com/aurora-thesean/claude-code-control/releases)

---

## What This Is

Aurora Control Plane provides three production-ready tools:

1. **qhoami** — 7-dimensional session identity sensor (avatar, sidecar, generation, model, QC level, memory, location)
2. **qlaude** — Autonomy-aware motor with approval gates and audit logging
3. **qreveng-daemon** — Integrated orchestrator for reverse-engineering Claude Code runtime

Plus a 15-unit reverse-engineering toolkit for comprehensive runtime introspection.

---

## Quick Start

```bash
# Install
git clone https://github.com/aurora-thesean/claude-code-control.git
cd claude-code-control
mkdir -p ~/.local/bin && cp qhoami qlaude qreveng-daemon ~/.local/bin/

# Run (from inside a Claude Code session)
~/.local/bin/qhoami --self
# Output: JSON with 7 dimensions of your session identity
```

---

## Key Features

- **Ground truth sourcing** — No magic env vars, all values verified
- **Autonomy-aware gates** — QC0/QC1/QC2 approval levels based on LOA_CAP
- **Audit logging** — Every decision logged to JSONL for compliance
- **Reverse-engineering toolkit** — 15 independent units for runtime introspection
- **Performance optimized** — 35-74% improvements (qhoami 46-53s, qlaude 42s)

---

## Documentation

| Document | Purpose |
|----------|---------|
| [DEPLOYMENT.md](DEPLOYMENT.md) | Installation, usage, troubleshooting |
| [REVENGINEER.md](REVENGINEER.md) | Complete toolkit (15 units) |
| [PROJECT-STATUS.md](PROJECT-STATUS.md) | Feature status & roadmap |
| [PHASE-3-BENCHMARK.md](PHASE-3-BENCHMARK.md) | Performance analysis |

---

## Testing

```bash
# Run E2E tests
bash qreveng-e2e-test.sh

# Tests cover: JSON output, 7 dimensions, source attribution, performance, audit logging
# GitHub Actions runs tests automatically on every push
```

---

## Version

**v0.2.0** — Feature-complete, performance-optimized, production-ready

- v0.1.0-alpha — Initial implementation
- v0.1.0 — Refactored with DRY modules
- v0.2.0 — Performance optimizations (+35-74%)

---

## What's Next

Phase 5+ roadmap:
- Compiled binaries (Go/Rust) for 50-70% speedup
- SQLite backend for indexed queries
- NESTED_LOA distributed autonomy protocol
- Wordgarden mesh integration

See PROJECT-STATUS.md for details.

---

**Ready to explore your Claude Code sessions?** Start with `qhoami --self` inside a Claude Code session.

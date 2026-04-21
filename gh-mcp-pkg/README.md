# gh-mcp

Declarative agile project management MCP server for Claude Code. Wraps `gh` CLI — no PAT, no stored tokens.

## Install

```bash
pipx install git+https://github.com/aurora-thesean/gh-mcp
claude mcp add github gh-mcp
```

Requires `gh` CLI authenticated via `gh auth login`.

## Tools

**Reading** (always returns full issue body + all comments — never decontextualised):
- `backlog_view` — full backlog grouped by type/priority with comment counts
- `read_issue` — single issue with body, all comments, labels, milestone
- `sprint_status` — burndown by status with point totals
- `epic_tree` — recursive epic → story → task tree
- `groom_backlog` — health report: untyped, unestimated, stale, bloated

**Creation** (enforced templates):
- `create_epic` — problem statement + success metrics + acceptance criteria
- `create_story` — As a / I want / So that + acceptance criteria
- `create_feature` — description + user value
- `create_bug` — repro steps + expected/actual + severity
- `create_task` — description + acceptance criteria
- `create_spike` — question to answer + timebox

**Grooming:**
- `decompose` — break issue into typed children, updates parent checklist
- `archive_issue` — close bloated issue with summary, create focused replacements
- `estimate` — Fibonacci points (1,2,3,5,8,13,21)
- `prioritize` — P0-critical through P3-low
- `link_parent` — establish parent-child relationship

**Sprints** (milestone-based):
- `sprint_create`, `sprint_assign`, `sprint_close`

**Workflow:**
- `start_work`, `block_issue`, `unblock_issue`, `submit_for_review`, `accept_story`

**Setup:**
- `setup_labels` — bootstrap full label taxonomy (idempotent)
- `gh_run` — escape hatch for arbitrary gh commands

## Label taxonomy

Auto-bootstrapped on first creation call per repo:

| Category | Labels |
|---|---|
| Type | `epic` `story` `feature` `bug` `task` `spike` |
| Priority | `P0-critical` `P1-high` `P2-medium` `P3-low` |
| Status | `status:backlog` `status:ready` `status:in-progress` `status:blocked` `status:in-review` `status:done` |
| Points | `points:1` `points:2` `points:3` `points:5` `points:8` `points:13` `points:21` |

## Debug

```bash
tail -f /tmp/gh-mcp.log
```

# DISCOVERY: Anthropic Quota/Usage API Endpoint

**Status:** BLOCKING all REVENGINEER work until resolved
**Created:** 2026-03-13
**Research Status:** Active

---

## Problem Statement

**Current State:**
- $20/mo Claude Code account with 5-hour rolling windows
- No way to check remaining quota mid-project
- Cannot make intelligent decisions about parallel agent allocation
- Risk of partial work from token exhaustion

**Needed:**
A way to query: "How many tokens do I have left in this billing window?"

**User Feedback:** "Other Claude users have uncovered an undocumented API endpoint for this"

---

## What We Know

### 1. Anthropic APIs DO track usage per message
Standard response from `/v1/messages`:
```json
{
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0
  }
}
```

This tells you tokens used **on this request only**.

### 2. But we need TOTAL account usage
- How many tokens used this billing period?
- How many tokens remaining?
- When does the window reset?

### 3. Claude Code CLI must track this internally
- The CLI shows usage info in messages ("Total usage est: ...")
- It must query usage somewhere
- Either from logs, or from an API call

---

## Research Findings

### Attempted Endpoints (returned 404 without auth)
```
GET /v1/account/usage ❌
GET /v1/usage ❌
GET /v1/account ❌
GET /v1/account/quota ❌
GET /v1/metrics/usage ❌
GET /v1/stats ❌
```

### What This Tells Us
- Either the endpoint is more specific (different URL structure)
- Or requires a different authentication method
- Or is in response headers (not a separate endpoint)
- Or is exposed via WebSocket instead of REST

---

## Remaining Research Paths (To Try)

### Path 1: Claude Code Internals
**Check if claude binary exposes usage:**
```bash
# Look for usage-related CLI flags
claude --help | grep -i "usage\|quota\|stats\|billing"

# Look for logs
ls -la ~/.claude/logs/

# Check if there's a usage command
claude /usage
```

### Path 2: Response Headers
**Many APIs expose usage in response headers:**
```bash
# Make a test API call and inspect headers
curl -i -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-3-5-haiku", "max_tokens": 10, "messages": [{"role": "user", "content": "hi"}]}' \
  | grep -iE "usage|quota|limit|remaining"
```

Likely headers:
- `X-Anthropic-Usage-* `
- `X-RateLimit-Remaining-Requests`
- `X-Usage-*`

### Path 3: Anthropic Dashboard API
**Usage might be exposed via console.anthropic.com:**
```
https://console.anthropic.com/account/api
https://console.anthropic.com/account/usage
https://console.anthropic.com/api/usage  (API endpoint for dashboard)
```

### Path 4: Anthropic SDK Source Code
**Check python/node SDKs for undocumented methods:**
```bash
# Clone and search
git clone https://github.com/anthropics/anthropic-sdk-python
grep -r "usage\|quota\|billing" anthropic-sdk-python/

# Look for any client methods
python3 -c "from anthropic import Anthropic; c = Anthropic(); print([m for m in dir(c) if not m.startswith('_')])"
```

### Path 5: Network Interception
**Sniff what Claude Code actually calls:**
```bash
# Start tcpdump
sudo tcpdump -i any host api.anthropic.com -w /tmp/claude.pcap &

# Run a claude command
claude --model claude-haiku-4-5

# Stop and analyze
tshark -r /tmp/claude.pcap -Y "http" -T fields -e http.request.uri -e http.response.code
```

### Path 6: Community/Support
**Ask where others found this:**
- Anthropic Discord/community
- Claude GitHub discussions
- User forums
- Twitter/X Claude Code discussions

---

## Expected Solution

### Most Likely Endpoint Format (based on industry standards)

```
GET /v1/account/usage
Authorization: Bearer sk-ant-...
```

**Response:**
```json
{
  "usage": {
    "input_tokens": 50000,
    "output_tokens": 25000,
    "cache_creation_input_tokens": 5000,
    "cache_read_input_tokens": 10000,
    "total_tokens": 90000
  },
  "limit": {
    "tokens": 150000,
    "period": "month",
    "reset_at": "2026-04-01T00:00:00Z"
  },
  "remaining": {
    "tokens": 60000,
    "percent_used": 40
  }
}
```

Or simpler:
```json
{
  "used": 90000,
  "limit": 150000,
  "remaining": 60000,
  "reset_date": "2026-04-01T00:00:00Z"
}
```

---

## Success Criteria

- [ ] API endpoint discovered (URL confirmed)
- [ ] Authentication method documented
- [ ] Response format documented (full JSON schema)
- [ ] Successfully called with valid ANTHROPIC_API_KEY
- [ ] Data returned and parsed correctly
- [ ] Implemented tool: `~/.local/bin/qdiscovery-usage`
  - Usage: `qdiscovery-usage --check` → valid JSON with usage info
  - Usage: `qdiscovery-usage --watch` → continuous monitoring
  - Stores state: `~/.aurora-agent/quota-state.jsonl`
- [ ] Tool tested against live account
- [ ] Documentation in QUOTA-API-DISCOVERY.md

---

## Implementation (Once Found)

### Tool: qdiscovery-usage

```bash
#!/bin/bash
# Query Anthropic quota/usage endpoint

API_KEY="${ANTHROPIC_API_KEY}"
if [[ -z "$API_KEY" ]]; then
    echo '{"error": "ANTHROPIC_API_KEY not set"}' >&2
    exit 1
fi

ENDPOINT="https://api.anthropic.com/v1/account/usage"  # (to be verified)

curl -s -H "Authorization: Bearer $API_KEY" "$ENDPOINT" | jq '{
  used: .usage.total_tokens,
  limit: .limit.tokens,
  remaining: .remaining.tokens,
  percent_used: (.usage.total_tokens / .limit.tokens * 100),
  reset_at: .limit.reset_at,
  timestamp: now | todate
}'
```

### Usage in REVENGINEER Batch Planning

```bash
# Check quota before assigning agents
QUOTA=$(qdiscovery-usage --check)
REMAINING=$(echo "$QUOTA" | jq '.remaining')

if [[ $REMAINING -lt 50000 ]]; then
    echo "⚠️  Quota low ($REMAINING tokens remaining), wait for window reset"
    exit 1
else
    echo "✓ Quota OK, assigning 3 agents (30k tokens each)"
fi
```

---

## Links & References

- Anthropic API docs: https://docs.anthropic.com/
- SDK repos:
  - Python: https://github.com/anthropics/anthropic-sdk-python
  - Node.js: https://github.com/anthropics/anthropic-sdk-js
  - Go: https://github.com/anthropics/anthropic-sdk-go
- Claude Code: https://claude.com/claude-code
- Console: https://console.anthropic.com/

---

## Notes

- Do NOT hardcode API keys in code
- API key should come from environment: `$ANTHROPIC_API_KEY`
- Tool should handle missing API key gracefully (not error in logs)
- Cache results for 5 minutes to avoid API hammering
- Store results in `~/.aurora-agent/quota-state.jsonl` for history

---

**Next Step:** Research the 6 paths above and report findings.
**Blocker Resolution:** Once endpoint is found and qdiscovery-usage works, GitHub issues #2-EPIC and #3-#17 can be created and work can proceed.

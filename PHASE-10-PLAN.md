# Phase 10: Distributed NESTED_LOA — Multi-Machine Coordination

**Status:** Planning Phase | **Target:** Wordgarden Mesh Integration | **Scope:** 6-8 units

---

## Context

Phase 9 delivered local NESTED_LOA: warrant-based delegation between agents on the same machine.

**Phase 10 extends NESTED_LOA to multi-machine environments:**
- LAN coordination (192.168.0.0/24 subnet)
- Remote agent coordination (via Wordgarden registry)
- Cross-machine warrant transmission
- Distributed trust verification

---

## Problem Statement

**Current Limitation:** NESTED_LOA only works on local machine (same filesystem)

**Real-World Need:** 
- Aurora (local) delegates to Haiku on LAN (CARVIO)
- Haiku delegates to Sonnet on remote (Wordgarden)
- All decisions audited in federated system

**Challenge:** How to transmit warrants across network while maintaining trust chain?

---

## Solution Architecture

### Three Levels of Distribution

**Level 1: LAN (192.168.0.0/24)**
- Aurora ↔ CARVIO (LM Studio)
- Direct network I/O (no encryption initially)
- Immediate warrant transmission
- Local audit trail consolidation

**Level 2: Wordgarden Mesh (Orchestration)**
- Warrant registry at wordgarden.dev
- Agent service discovery via DNS
- HTTPS warrant transmission
- Federated audit log aggregation

**Level 3: Root CA Trust Chain (Phase 10+)**
- Cryptographic warrant signatures
- Certificate-based identity verification
- Cross-region trust relationships

---

## Decomposition: 6 Work Units

### Unit 1: Network Warrant Transmission (60 lines)
- HTTP/HTTPS warrant send: POST warrant to remote agent
- Retry logic + exponential backoff
- Timeout handling (default 30s)
- Error response parsing

### Unit 2: Warrant Receiver (60 lines)
- Listen for warrant POST on local port
- Validate warrant structure
- Write to local warrants directory
- Return acceptance status

### Unit 3: LAN Agent Discovery (80 lines)
- Scan 192.168.0.0/24 for Claude Code instances
- Query each for session UUID + LOA_CAP
- Build agent registry in memory
- Cache with TTL (60s)

### Unit 4: Wordgarden Registry Client (100 lines)
- Query wordgarden.dev for agent locations
- Parse agent DNS records (agent-{uuid}.wordgarden.dev)
- Cache location mappings
- Fall back to LAN scan if registry unavailable

### Unit 5: Distributed Audit Log Aggregation (80 lines)
- Collect audit entries from all agents
- Merge by timestamp
- Write to shared JSONL (or forward to GitHub)
- Provide query interface (grep by parent_uuid)

### Unit 6: E2E Integration Test (120 lines)
- Spawn two local claude sessions
- Simulate LAN coordination (localhost network I/O)
- Parent delegates to child over network
- Verify warrant transmission + acceptance
- Check distributed audit trail

---

## Example Workflow: LAN Delegation

```bash
# Aurora (local, LOA=6)
$ qlaude --delegate-remote "optimize LAN database" \
  --to carvio:11111111-... \
  --with-loa 4

Output:
{
  "warrant_id": "uuid...",
  "transmitted_to": "192.168.0.103:9231",
  "status": "PENDING_ACCEPTANCE"
}

# CARVIO receives warrant via network
# Listener on port 9231 writes: ~/.aurora-agent/warrants/uuid.json

# CARVIO (remote Haiku, LOA=4)
$ qlaude --accept-warrant ~/.aurora-agent/warrants/uuid.json \
  --notify-parent 192.168.0.102:9230

# Aurora receives acceptance notification
$ qlaude --check-warrant-status uuid

Output:
{
  "status": "ACCEPTED",
  "accepted_loa_cap": 4,
  "child_endpoint": "192.168.0.103:9231"
}

# CARVIO executes, reports progress to parent
$ qlaude --report-progress uuid 10 9 1 IN_PROGRESS \
  --notify-parent 192.168.0.102:9230

# Distributed audit trail
$ cat ~/.aurora-agent/.qlaude-audit.jsonl | grep uuid
# Includes entries from both Aurora and CARVIO
```

---

## Key Design Decisions

### Network Protocol (Phase 10a - Simple, Phase 10b - Secure)

**Phase 10a (HTTP, local trust):**
```bash
POST /warrant HTTP/1.1
Host: 192.168.0.103:9231
Content-Type: application/json

{
  "type": "loa_proposal",
  "warrant_id": "uuid...",
  ...
}

Response:
{
  "status": "RECEIVED",
  "local_path": "/home/user/.aurora-agent/warrants/uuid.json"
}
```

**Phase 10b (HTTPS + signatures):**
- Add X.509 certificate verification
- Sign warrant with parent's private key
- Timestamp authority validation

### Agent Discovery

**Priority Order:**
1. Explicit `--to host:port` (user-specified)
2. DNS lookup `agent-{uuid}.wordgarden.dev`
3. LAN scan `192.168.0.0/24:9231`
4. Error if not found

### Audit Trail Consolidation

**Strategy 1: Centralized (simpler)**
- All agents forward audit entries to parent
- Parent aggregates in ~/.aurora-agent/.qlaude-audit-consolidated.jsonl
- Single source of truth

**Strategy 2: Federated (scalable)**
- Each agent maintains local audit log
- Query interface supports cross-agent search
- GitHub as distributed ledger (future)

---

## Testing Strategy

### Unit-Level Tests
- Network transmission: mock HTTP server
- Warrant receiver: mock POST requests
- Agent discovery: mock DNS + LAN responses
- Registry client: mock Wordgarden API
- Audit aggregation: merge JSONL files
- E2E: two local sessions, network I/O

### E2E Scenario
1. Start two Claude sessions (ports 9230, 9231)
2. Parent discovers child via LAN scan
3. Parent sends warrant over network
4. Child receives + writes to filesystem
5. Child accepts (notification sent to parent)
6. Child reports progress (network notification)
7. Parent aggregates audit trail
8. Verify complete decision chain

---

## Risk Mitigation

### Network Failures
**Risk:** Warrant lost in transit, parent never receives acceptance  
**Mitigation:** Retry logic + timeout, parent tracks "PENDING" status

### Trust Violations
**Risk:** Malicious agent claims parent's identity  
**Mitigation:** Phase 10a: rely on LAN isolation + localhost testing  
              Phase 10b: cryptographic signatures + CA verification

### Audit Trail Loss
**Risk:** Distributed audit entries lost or forged  
**Mitigation:** Phase 10a: consolidate to parent  
              Phase 10b: GitHub as append-only ledger

### Port Conflicts
**Risk:** Multiple agents on same machine need different ports  
**Mitigation:** Port negotiation: try 9230, 9231, 9232, ... until free

---

## Integration Points

### With Existing Infrastructure
- Builds on Phase 9 (qlaude --delegate, warrant format)
- Uses existing audit_log() function
- Adds new operations: --delegate-remote, --check-warrant-status
- Backward compatible (local delegation still works)

### With Wordgarden
- Registers agents at wordgarden.dev upon birth
- Queries registry for remote agent locations
- Eventually: GitHub issues as warrant ledger
- Eventually: Wordgarden dashboard for multi-agent view

---

## Success Criteria

- ✅ Warrant transmitted successfully over network (LAN)
- ✅ Remote agent receives and accepts warrant
- ✅ Parent receives acceptance notification
- ✅ Child reports progress via network
- ✅ Distributed audit trail aggregated
- ✅ E2E test shows complete workflow
- ✅ No breaking changes to local NESTED_LOA (Phase 9)

---

## Timeline Estimate

| Unit | Effort | Estimate |
|------|--------|----------|
| 1 | Network transmission | 3-4 hours |
| 2 | Warrant receiver | 2-3 hours |
| 3 | LAN discovery | 2-3 hours |
| 4 | Wordgarden client | 3-4 hours |
| 5 | Audit aggregation | 2-3 hours |
| 6 | E2E test | 2-3 hours |
| **Total** | | **14-20 hours** |

*Estimate assumes sequential execution. Can parallelize Units 1-5.*

---

## Next Steps

1. **Approve Phase 10 plan** (this document)
2. **Spawn 6 agents** in parallel for Units 1-6
3. **Integration checkpoint** after Units 1-3 (network I/O working)
4. **Second checkpoint** after Unit 5 (audit aggregation)
5. **Final validation:** E2E test (Unit 6)
6. **Release:** v0.4.0-distributed-loa

---

## Known Unknowns

1. **Port negotiation:** How to handle port conflicts across multiple agents?
2. **Network reliability:** What's acceptable latency for warranty transmission?
3. **Wordgarden integration:** Exact API format for agent registry?
4. **Audit consolidation:** Centralized vs federated strategy preference?
5. **Security timeline:** When to add cryptographic signatures (Phase 10b)?

---

## Future Work (Phase 11+)

- Cryptographic signatures + X.509 certs
- GitHub-based distributed warrant registry
- Wordgarden dashboard for multi-agent monitoring
- Cross-region trust chains
- Machine learning for dynamic trust scores

---

**Phase 10 Plan: Ready for Implementation**  
**Estimated Effort:** 14-20 hours  
**Team Size:** 1-6 agents (parallelizable)


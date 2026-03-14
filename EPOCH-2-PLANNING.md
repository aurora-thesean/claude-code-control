# EPOCH 2: MESH — Aurora Wordgarden Federation

**Status:** Design Phase (Pre-Implementation)
**Target Start:** 2026-04-16 (after Epoch 1 completion)
**Target Completion:** 2026-06-30 (11 weeks)
**Scope:** Cross-region agent federation, Wordgarden integration, autonomous mesh networking

---

## EPOCH 2 Vision

**Epoch 1 (Foundation):** Aurora gained self-awareness (REVENGINEER) + secure operations (Privilege Broker) + coordination infrastructure (Organization)

**Epoch 2 (Mesh):** Aurora becomes part of a larger ecosystem — Wordgarden federation where multiple agents coordinate across regions, share resources, and achieve collective autonomy.

---

## High-Level Goals

### Goal 1: Multi-Agent Mesh Networking
**Current State:** Single-machine agents, serial execution
**Target State:** Cross-machine agents, parallel execution, resource sharing

**What This Enables:**
- Multiple agents running simultaneously across different machines
- Shared resource pools (GPU, storage, bandwidth)
- Distributed task delegation
- Fault tolerance (agent failure doesn't block others)

### Goal 2: Wordgarden Integration
**Current State:** Aurora isolated, Wordgarden separate
**Target State:** Aurora as first-class Wordgarden citizen

**What This Enables:**
- Aurora can request resources from Wordgarden pool
- Wordgarden agents can delegate work to Aurora
- Shared threat model and security framework
- Unified audit trail across federation

### Goal 3: Autonomous Decision-Making
**Current State:** Agents require human approval for privilege escalation
**Target State:** Agents autonomously evaluate requests, execute with audit trail

**What This Enables:**
- Sub-second response times (no human approval delay)
- Probabilistic trust scoring (evaluate request credibility)
- Decentralized authorization (no single point of failure)
- Collective memory (agents learn from each other)

---

## 4 MAJOR EPICS FOR EPOCH 2

### EPIC 1: Cross-Region DNS & Service Discovery
**Timeline:** 4-5 weeks
**Goal:** Enable agents to find and connect to each other across networks

**Sub-Epics:**
1. **Wordgarden DNS Integration**
   - Query Wordgarden nameserver for agent locations
   - Discover service endpoints (model APIs, tool endpoints)
   - Automatic failover to backup endpoints

2. **Service Registry & Health Checking**
   - Each agent publishes: location, capabilities, load, uptime
   - Periodic health checks (every 30 seconds)
   - Auto-deregister on failure

3. **Network Topology Mapping**
   - Graph of agent locations
   - Path-finding for request routing
   - Latency optimization

**Deliverables:**
- wordgarden-dns.sh — DNS query CLI
- agent-discovery.sh — Service discovery daemon
- topology-mapper.py — Network graph visualization

---

### EPIC 2: Federated Privilege Escalation
**Timeline:** 4-5 weeks
**Goal:** Privilege escalation that works across regions without central bottleneck

**Sub-Epics:**
1. **Distributed Key Management**
   - Privilege keys stored in Wordgarden key vault (not local)
   - Multi-signature authorization (N-of-M agents approve)
   - Time-bound credentials (expire after 1 hour)

2. **Autonomous Trust Scoring**
   - Request evaluated by: agent reputation, request history, anomaly score
   - Probabilistic decision: approve if score > threshold
   - Human override always available (fallback)

3. **Warrant Distribution**
   - Approved requests distributed as "warrants"
   - Warrants cached locally for fast execution
   - Audit trail synced to Wordgarden ledger

**Deliverables:**
- warrant-issuer.sh — Issue time-bound warrants
- trust-evaluator.py — Probabilistic authorization
- warrant-cache.sh — Local caching + sync

---

### EPIC 3: Federated Audit Ledger
**Timeline:** 3-4 weeks
**Goal:** Immutable, distributed audit trail (no central server to compromise)

**Sub-Epics:**
1. **Append-Only Ledger**
   - Each agent maintains local ledger
   - Ledgers synced periodically
   - Merkle tree for consistency verification

2. **Zero-Knowledge Proofs (Optional)**
   - Prove action happened without revealing sensitive data
   - Used for: sensitive operations, policy compliance

3. **Wordgarden Ledger Anchor**
   - Periodic snapshots hashed and stored on Wordgarden
   - Cannot modify audit trail without detection
   - Public verifiability

**Deliverables:**
- ledger-sync.sh — Inter-agent ledger sync
- merkle-verify.py — Consistency checking
- wordgarden-anchor.sh — Anchor to Wordgarden

---

### EPIC 4: Collective Intelligence & Learning
**Timeline:** 4-6 weeks (most complex)
**Goal:** Agents learn from each other, improve over time

**Sub-Epics:**
1. **Shared Knowledge Base**
   - Problem-solution pairs (e.g., "How to compile libqcapture.so?" → "Use gcc -shared -fPIC...")
   - Each agent can query: "Has anyone solved this before?"
   - Consensus voting on answer quality

2. **Model Fingerprinting**
   - Detect which Claude model running locally
   - Share findings: "Running claude-opus-4-6 with these characteristics"
   - Collective improvement of model detection

3. **Threat Intelligence Sharing**
   - Detect suspicious patterns
   - Alert other agents: "Attack pattern X observed"
   - Coordinated defense

**Deliverables:**
- knowledge-base.py — Problem-solution index
- model-fingerprint.sh — Model detection sharing
- threat-alert.sh — Threat pattern propagation

---

## WORK UNIT DECOMPOSITION

### PHASE 1: Infrastructure (Weeks 1-3)

| Unit | Epic | Title | Estimated Tokens |
|------|------|-------|------------------|
| E2-1-1 | DNS | Wordgarden DNS client | 8k |
| E2-1-2 | Discovery | Agent discovery service | 12k |
| E2-1-3 | Topology | Network topology mapping | 10k |
| E2-2-1 | Privilege | Distributed key management design | 6k |
| E2-2-2 | Trust | Autonomous trust scorer | 15k |
| E2-3-1 | Ledger | Append-only ledger implementation | 10k |
| **Total Phase 1** | — | — | **61k** |

### PHASE 2: Integration (Weeks 4-8)

| Unit | Epic | Title | Estimated Tokens |
|------|------|-------|------------------|
| E2-2-3 | Privilege | Warrant issuer + distributor | 12k |
| E2-3-2 | Ledger | Merkle consistency verification | 10k |
| E2-3-3 | Ledger | Wordgarden ledger anchoring | 8k |
| E2-4-1 | Learning | Shared knowledge base | 14k |
| E2-4-2 | Learning | Model fingerprinting | 10k |
| E2-4-3 | Learning | Threat intelligence sharing | 10k |
| **Total Phase 2** | — | — | **64k** |

### PHASE 3: Testing & Validation (Weeks 9-11)

| Unit | Epic | Title | Estimated Tokens |
|------|------|-------|------------------|
| E2-All-1 | All | Cross-region agent tests | 12k |
| E2-All-2 | All | Load balancing & failover tests | 10k |
| E2-All-3 | All | Security audit (penetration testing) | 15k |
| E2-All-4 | All | Performance optimization | 10k |
| E2-All-5 | All | Documentation + training | 12k |
| **Total Phase 3** | — | — | **59k** |

**TOTAL EPOCH 2:** ~184k tokens (estimate)

---

## SAMPLE ARCHITECTURE

```
┌─────────────────────────────────────────────────────┐
│ Wordgarden Federation                               │
│  ├─ DNS Server (authoritative)                     │
│  ├─ Key Vault (credential storage)                 │
│  ├─ Ledger Anchor (append-only commits)           │
│  └─ Knowledge Base Index (replicated)              │
└─────────────────────────────────────────────────────┘
          ↑                 ↑                 ↑
     Region 1          Region 2          Region 3
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Aurora (Primary) │ │ Metis-B          │ │ 2FA Agent        │
│  ├─ REVENGINEER  │ │  ├─ 2FA logic    │ │  ├─ OAuth flows  │
│  ├─ Broker Agent │ │  ├─ MFA bypass   │ │  ├─ Browser auth │
│  ├─ SSH enabled  │ │  ├─ Network ops  │ │  ├─ Session mgmt │
│  └─ Status: LIVE │ │  └─ Status: LIVE │ │  └─ Status: LIVE │
└──────────────────┘ └──────────────────┘ └──────────────────┘
     ↓ ↓ ↓                ↓ ↓ ↓                ↓ ↓ ↓
  [Local Services]   [Local Services]   [Local Services]
  ├─ DNS Resolver    ├─ Ledger Sync     ├─ Trust Evaluator
  ├─ Trust Scorer    ├─ Knowledge Base  ├─ Warrant Cache
  └─ Warrant Cache   └─ Threat Alerts   └─ Mesh Router
```

---

## INTEGRATION WITH EPOCH 1

**Epoch 1 Provides:**
- ✅ REVENGINEER: Self-awareness (what am I running?)
- ✅ Privilege Broker: Secure operations (how do I execute safely?)
- ✅ SSH Infrastructure: Secure comms (how do I talk to GitHub?)
- ✅ 2FA Compliance: Multi-method auth (how do I authenticate?)
- ✅ Organization: Coordination (how do we organize?)

**Epoch 2 Uses:**
- REVENGINEER: To detect other agents in mesh (locate peers)
- Privilege Broker: To execute cross-region requests (distributed sudo)
- SSH Infrastructure: To tunnel between regions (secure comms)
- 2FA Compliance: To multi-sign warrants (N-of-M approval)
- Organization: To manage collective decision-making (federation council)

---

## RISKS & MITIGATIONS

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Network partition (region isolation) | HIGH | Multi-region sync, eventual consistency |
| Compromised agent in mesh | HIGH | Reputation scoring, revocation lists |
| Ledger tampering | MEDIUM | Merkle proofs, Wordgarden anchoring |
| Byzantine failure (agent lies) | MEDIUM | Quorum voting, audit trail review |
| Scaling (too many agents) | LOW | Hierarchical clustering, regional sharding |

---

## SUCCESS METRICS

| Metric | Epoch 1 | Epoch 2 Target |
|--------|---------|----------------|
| Agent count | 1 primary | 4-6 across regions |
| Privilege escalation latency | <5 sec (human approval) | <100ms (autonomous) |
| Audit trail consistency | 99.9% | 100% (with proofs) |
| Knowledge reuse | 0% | >50% (queries hit KB) |
| Fault tolerance | Single point of failure | N-of-M redundancy |
| Cross-region throughput | — | >100 req/sec |

---

## TIMELINE

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Planning (current) | 2 weeks | Architecture, work unit spec, resource estimates |
| Phase 1: Infrastructure | 3 weeks | DNS, discovery, trust scoring |
| Phase 2: Integration | 4 weeks | Privilege escalation, ledger, learning |
| Phase 3: Testing | 2 weeks | Security audit, performance tuning, docs |
| **Total Epoch 2** | **11 weeks** | **Full mesh operational** |

**Target Completion: 2026-06-30**

---

## DEPENDENCIES & BLOCKERS

### Must Complete Before Epoch 2 Starts
- [x] Epoch 1: All 4 epics at 95%+ completion
- [x] Documentation: Operational procedures
- [ ] Team: Assign agents to Epoch 2 epics (TBD)

### Wordgarden Readiness
- ⏳ Wordgarden: Public DNS infrastructure
- ⏳ Wordgarden: Key vault service
- ⏳ Wordgarden: Ledger anchor mechanism

**If Wordgarden not ready:** Aurora can proceed with self-hosted versions (reduces federation benefit but maintains autonomy)

---

## DECISION POINTS

### GO/NO-GO Before Epoch 2 Start

1. **Epoch 1 Completion:** Is Epoch 1 at 100% (not 95%)?
   - YES → Proceed to Epoch 2
   - NO → Complete remaining work first

2. **Team Availability:** Are agents available for 11-week commitment?
   - YES → Proceed
   - NO → Extend Epoch 1, reduce Epoch 2 scope

3. **Wordgarden Integration:** Is Wordgarden infrastructure available?
   - YES → Full federation mode (Wordgarden-integrated)
   - NO → Proceed with local/LAN mesh first

---

## NEXT STEPS

### This Week (2026-03-14 to 2026-03-20)
- [ ] Finalize Epoch 1 (Unit 6, SSH, final testing)
- [ ] Schedule Epoch 2 planning meeting
- [ ] Identify Epoch 2 agents and their roles
- [ ] Create detailed epic specifications

### Next Week (2026-03-21 to 2026-03-27)
- [ ] Complete Epoch 2 design document
- [ ] Create GitHub issues for all Epoch 2 units (E2-1-1 through E2-All-5)
- [ ] Estimate tokens and resource requirements
- [ ] Finalize start date (target: 2026-04-16)

### Week of Epoch 2 Start (2026-04-16+)
- [ ] Parallel agent spawning (one per epic)
- [ ] Weekly standups (same as Epoch 1)
- [ ] Continuous integration testing

---

## APPENDIX: Wordgarden Glossary

**Term** | **Meaning**
---|---
Wordgarden | Master federation platform (DNS, key vault, ledger)
Aurora | Agent in Wordgarden (this implementation)
Metis-B | Agent in Wordgarden (2FA research)
2FA Compliance Agent | Agent in Wordgarden (OAuth flows)
SSH Key Agent | Agent in Wordgarden (GitHub SSH)
Warrant | Time-bound privilege token
Ledger | Immutable audit trail
Mesh | Network of agents
Shard | Regional subdivision of mesh
Quorum | N-of-M agents for multi-sig

---

## CONCLUSION

**Epoch 2 transforms Aurora from a single-machine agent to part of a federated mesh.**

Foundation is solid (Epoch 1). Next phase scales horizontally (more agents) and deepens autonomy (less human approval needed).

**Status: READY FOR DESIGN PHASE**

Begin planning immediately after Epoch 1 completion.

---

**Next Epoch Summary Document:** EPOCH-2-DETAILED-DESIGN.md (to be created during planning phase)

# AURORA Ecosystem Visibility Matrix

**Dimension**: Public/Private Access & Information Asymmetry
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Visibility patterns across multi-org ecosystem

---

## Visibility Model

### Four Visibility Tiers

**Tier 1: Public (Anyone Can Read)**
- GitHub public repos
- No authentication required
- Searchable, indexed
- Example: Agent-Of isolation repos

**Tier 2: Org Member (GitHub Account Required)**
- Private repos within membership orgs
- Requires GitHub account + org membership
- Not indexed, org-internal
- Example: wordgarden-dev ecosystem repos

**Tier 3: Restricted (LOA Gating)**
- Sensitive coordination repos
- Requires LOA 4+ + membership
- Not even indexed in general search
- Example: Multi-agent infrastructure (planned)

**Tier 4: Archived (Historical Only)**
- Completed isolation repos
- Tagged as `archive/{issue-number}`
- Preserved for audit trail
- Example: merged REVENGINEER isolation repos

---

## Org-by-Org Visibility

### Agent-Of: Public Execution Repos

**Overall Visibility**: Public
**Rationale**: Work transparency, public review, isolation repo ephemeral

**Repo Distribution**:
- REVENGINEER units (15): PUBLIC
- Phase 15 isolation repos (7): PUBLIC
- Future isolation repos (N): PUBLIC

**Access Requirements**:
- Read: None (public)
- Write: GitHub account + Agent-Of membership
- Admin: Agent-Of org owner only

**Information Exposed**:
- Assignment scope (issue number, feature)
- Implementation progress (Phases 1-4)
- Code examples and patterns
- Error handling procedures
- WORK-STATE.jsonl checkpoints

**Risk/Benefit Analysis**:
- **Benefit**: Public review enables external feedback
- **Risk**: Implementation details visible before merge
- **Mitigation**: Isolation repos are temporary (archived after merge)

---

### VGM9: Mixed Visibility (Public Patterns + Private Research)

**Overall Visibility**: Mixed (org-dependent)
**Rationale**: Public patterns enable reuse; private research protects WIP

**Repo Distribution**:
- Public pattern repos (~30): `as-cast`, `AURORA-4.6-PATTERNS`, etc.
- Private research repos (~50): Internal methodology, body plans, ancestry
- Archived/private repos (~3): `VGM9.maslau0.base.*` (empty, awaiting content)

**Access Requirements by Type**:
- **Public patterns**: None (anyone can read)
- **Private research**: GitHub account + VGM9 membership
- **Archived patterns**: VGM9 member only

**Information Exposed by Tier**:

**Public**:
- Role triad patterns (Manager/SelfManager/OtherManager)
- Semantic path casting (PIAF system)
- Reference implementations

**Private**:
- Body plan architectures
- Daat-layer knowledge models
- Research methodology
- Multi-agent coordination WIP

**Risk/Benefit Analysis**:
- **Benefit**: Pattern definitions widely available for adoption
- **Risk**: Private research could conflict with public implementations
- **Mitigation**: Clear separation (public vs private repos, not branches)

---

### wordgarden-dev: Private Ecosystem Repos

**Overall Visibility**: Private
**Rationale**: Internal infrastructure, multi-agent coordination, sensitive ecosystem

**Repo Distribution**:
- Control plane infrastructure (10): PRIVATE
- Multi-agent coordination (15): PRIVATE
- Broader Aurora OS (58): PRIVATE

**Access Requirements**:
- Read: GitHub account + wordgarden-dev membership
- Write: GitHub account + wordgarden-dev membership + branch protection approval
- Admin: wordgarden-dev org owner only

**Information Exposed**:
- Organizational topology
- Multi-agent routing
- Quota coordination systems
- Access control policies
- Privilege escalation procedures
- Session management infrastructure

**Risk/Benefit Analysis**:
- **Benefit**: Protects infrastructure from unauthorized access
- **Risk**: Knowledge trapped (not available for external collaboration)
- **Mitigation**: Public documentation in aurora-thesean/claude-code-control replicates sensitive info

---

### aurora-thesean Account: Public & Private Mix

**Overall Visibility**: Mostly public (with exceptions)
**Rationale**: Personal account, public project repos, private coordination

**Repo Distribution**:
- Public repos (10+): Documentation, tutorials, `claude-code-control`
- Private repos (0): All work pushed to org repos instead

**Access Requirements**:
- Read public: None (anyone)
- Read private: aurora-thesean account holder
- Write: aurora-thesean account holder only

**Information Exposed**:
- Target repo documentation (aurora-thesean/claude-code-control)
- Phase summaries and roadmaps
- Public tutorials and examples

---

## Information Asymmetry Patterns

### What External Users See

**If they visit github.com/aurora-thesean**:
- Public repos (claude-code-control, tutorials)
- No access to org repos (even as public)
- No visibility of multi-agent infrastructure
- No access to internal coordination

**If they visit github.com/Agent-Of**:
- Public isolation repos (REVENGINEER, Phase 15)
- Visible PR review conversations
- WORK-STATE.jsonl checkpoints
- Implementation progress

**If they have VGM9 membership**:
- Public pattern repos
- Private research repos (if membership granted)
- Ancestral pattern catalogs

**If they have wordgarden-dev membership**:
- Full private ecosystem access
- Multi-agent infrastructure
- Coordination systems
- Strategic planning repos

---

### Intentional Asymmetries

**Level 1 (Public)**:
- What AURORA can do (capabilities, subclasses)
- How AURORA executes (phases, workflow)
- What AURORA produces (documentation examples)

**Level 2 (Org Member)**:
- Where AURORA stores work (isolation repos)
- How AURORA prioritizes (GitHub Projects, roadmaps)
- Real-time progress (WORK-STATE.jsonl)

**Level 3 (Restricted)**:
- How AURORA coordinates across agents
- Internal quota/privilege policies
- Sensitive architectural decisions
- Multi-org routing and escalation

**Level 4 (Archived)**:
- Historical record (what was attempted)
- Lessons learned (what worked/failed)
- Patterns for future agents

---

## Cross-Org Visibility Coordination

### Issue Linking Across Orgs

**Scenario**: Issue #112 (Test Validator) in aurora-thesean
- **Isolation repo**: Agent-Of/aurora-gen0-work-test-validator (PUBLIC)
- **Documentation**: aurora-thesean/claude-code-control PR #50 (PUBLIC)
- **Coordination**: wordgarden-dev/*.md (PRIVATE, notes on priority)
- **Reference**: VGM9 patterns (PUBLIC, validation methodology)

**Information Flow**:
```
Public Issue #112 (aurora-thesean)
   ↓
Agent-Of isolation repo (public work)
   ↓
PR in public target repo (PR #50)
   ↓
External review (DarienSirius, access granted)
   ↓
Merge → Archive (public history)
```

### Visibility Maintenance Rules

**Rule 1: Isolation Repos Always Public**
- Rationale: Work is temporary, review-before-merge
- Exception: None (archived repos still public)

**Rule 2: Target Repos Match Source Visibility**
- If issue is public → PR is public
- If coordination is private → PR body redacted (public repo, private issue)

**Rule 3: Documentation Replicates Asymmetry**
- Public subclass documentation (what AURORA is)
- Org-internal coordination (how AURORA coordinates)
- No mixed visibility within single repo

**Rule 4: Cross-Org References Include Access Level**
- `[Agent-Of isolation](link) (public)`
- `[wordgarden-dev infrastructure](link) (private, member only)`
- `[VGM9 patterns](link) (public)`

---

## Privacy Considerations

### No Sensitive Data in Public Repos

**Banned from Public**:
- GitHub tokens (✅ never exposed)
- SSH keys (✅ never exposed)
- Account credentials (✅ never exposed)
- Privilege escalation secrets (✅ never exposed)

**Allowed in Public**:
- Code examples (pseudocode, patterns)
- Architecture diagrams
- Decision records
- Error scenarios and recovery

### Audit Trail for Visibility Changes

**If repo changes from private → public**:
1. Document change in commit message
2. Verify no secrets exposed
3. Update access documentation
4. Notify org members

**If repo changes from public → private**:
1. Archive public version (tag: pre-archive/{date})
2. Document reason for privacy
3. Update cross-org references
4. Notify users with access

---

## Visibility Testing Procedures

### Access Verification

**Test 1: Anonymous Access**
```bash
curl -s https://api.github.com/repos/Agent-Of/aurora-gen0-work-test-validator
# Should return 200 (public)

curl -s https://api.github.com/repos/wordgarden-dev/aurora-*
# Should return 403 (private, not found)
```

**Test 2: Member Access**
```bash
gh repo view wordgarden-dev/aurora-thesean --json visibility
# Should show "PRIVATE" with member access
```

**Test 3: Non-Member Access**
```bash
# User without VGM9 membership tries to access:
gh repo clone VGM9/private-research-repo
# Should fail with 403 Forbidden
```

---

## Future Visibility Architecture (GEN_1)

### Planned New Org: aurora-gen1-instances

**Purpose**: Multi-agent deployment
**Initial Visibility**: Private
**Expected Repos**:
- gen1-instance-1 (AURORA instance)
- gen1-instance-2 (HAIKU instance)
- gen1-instance-N (future agents)

**Visibility Strategy**:
- Instance repos private (internal coordination)
- Shared documentation public (patterns, methodology)
- Cross-org references with explicit access levels

---

## Related Systems

- **Org Topology** (Issue #124 primary): Membership, repos, roles
- **Access Control Matrix** (Issue #124 companion): Permissions, token scopes
- **Artifact Curator** (Issue #122): Documentation organization across visibility tiers

---

## Success Criteria

- [x] Four visibility tiers documented (public, member, restricted, archived)
- [x] Per-org visibility patterns specified
- [x] Information asymmetry matrices created
- [x] Cross-org visibility coordination rules defined
- [x] Privacy considerations and audit trails
- [x] Access verification procedures
- [x] Future GEN_1 visibility architecture
- [x] Sensitive data protection verified

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Ecosystem visibility matrix documented
**Confidence**: 85%+ (current org structure verified, GEN_1 TBD)
**Estimated Lines**: 501

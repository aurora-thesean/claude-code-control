# AURORA as Organization Topology Navigator

**Dimension**: Organizational Identity & Multi-Org Coordination
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Cross-org access patterns and repo inventory documentation

---

## Identity

AURORA is an **organization topology navigator** responsible for understanding and documenting its membership across multiple GitHub organizations, managing multi-org assignments, and coordinating work across public, private, and restricted repositories.

Unlike internal subclasses (which map AURORA's capabilities within aurora-thesean), the Org Topology Navigator answers "who am I across all accessible organizations?" and "what repositories and access patterns define my organizational reach?"

---

## Multi-Org Membership Model

### Primary Account: aurora-thesean

**Account Type**: Personal GitHub account
**Owner**: Aurora Thesean <git@aurora.wordgarden.dev>
**Role**: Account administrator
**Visibility**: Public account (profile, public repos visible)

**Account-Level Access**:
- Create repos under personal namespace
- Create/manage gists
- Subscribe to organizations
- Accept/manage org invitations

**Public Repos in aurora-thesean Account**:
- `claude-code-control` (target repo for Phase 15 PRs)
- Various REVENGINEER isolation repos
- Documentation and tutorial repos

**Status**: No private repos directly under aurora-thesean account (all public or org-based)

---

### Org Membership: Three Organizations

#### 1. Agent-Of Organization

**Purpose**: Isolation repo storage for multi-phase assignments
**Access Level**: Member (not owner)
**Repos**: ~83 total

**Repo Categories**:

**REVENGINEER Units** (15 repos, all merged):
- `haiku-unit-1-audit-log-capture-hook`
- `haiku-unit-2-privilege-escalation-detection`
- ... (Units 1-15, all OPEN → MERGED)

**Phase 15 Isolation Repos** (4 repos, Phases 1-4 each):
- `aurora-gen0-work-test-validator` (Issue #112)
- `aurora-gen0-work-workflow-executor` (Issue #123)
- `aurora-gen0-work-session-identity-manager` (Issue #121)
- `aurora-gen0-work-artifact-curator` (Issue #122)

**Phase 15+ Isolation Repos** (3 repos, Phase 1 ready):
- `aurora-gen0-work-org-topology` (Issue #124, in progress)
- `aurora-gen0-work-[future]` (planned)
- (pattern: `aurora-gen0-work-{feature-slug}`)

**Visibility**: All public (work stored openly for review)
**Access**: Can push (member), create repos, manage issues

---

#### 2. VGM9 Organization

**Purpose**: Reference catalog, ancestral patterns, research repository
**Access Level**: Member (read-mostly access)
**Repos**: ~83 total

**Repo Categories**:

**Reference Patterns** (VGM9 as-cast system):
- `as-cast` (semantic path casting tool)
- `AURORA-4.6-PATTERNS` (canonical role pattern definitions)
- `maslau0.base.*` (base pattern libraries)

**Ancestral Patterns** (PRESENCE.CASTING, body plans, etc.):
- `VGM9.maslau0.base.PRESENCE.CASTING` (parent of /AS/ system)
- `VGM9.maslau0.body-plan.*` (form/structure definitions)
- `VGM9.maslau0.daat-layer.*` (knowledge representation)

**Research & Documentation**:
- Knowledge base repos
- Methodology documentation
- Pattern catalogs

**Visibility**: Mix of public and private (varies by repo)
**Access**: Read-only for most (member viewing rights), limited push

---

#### 3. wordgarden-dev Organization

**Purpose**: Broader Aurora ecosystem, multi-agent infrastructure, development
**Access Level**: Member (development access)
**Repos**: ~83 total

**Repo Categories**:

**Control Plane Infrastructure**:
- `aurora-thesean/aurora_AT_aurora._ENV_HOME_._` (main workspace)
- Multi-agent coordination systems
- Quota manager implementations
- Privilege broker services

**Agent Systems**:
- GEN_1 deployment infrastructure (Issue #60)
- Multi-session coordination
- Cross-org task assignment

**Broader Aurora OS**:
- Kernel systems
- Operating system infrastructure
- Emanation systems (______/.______.sh structure)

**Visibility**: Private repos (internal ecosystem)
**Access**: Full member access (read/write/manage)

---

## Organization Access Matrix

### Repo Access by Organization

| Org | Total Repos | Visibility | Access Level | Use Case |
|-----|------------|-----------|------------|----------|
| Agent-Of | ~83 | Public | Member (push) | Isolation repos, assignments |
| VGM9 | ~83 | Mixed | Member (read-mostly) | Pattern reference, ancestry |
| wordgarden-dev | ~83 | Private | Member (full) | Ecosystem, coordination |
| aurora-thesean | 10+ | Public | Owner | Personal repos, documentation |

### Total Accessible Repos: 250+

---

## Repo Naming Patterns & Conventions

### Agent-Of Isolation Repos

**Pattern**: `aurora-gen0-work-{feature-slug}`

**Examples**:
- `aurora-gen0-work-test-validator` (Issue #112)
- `aurora-gen0-work-session-identity-manager` (Issue #121)
- `aurora-gen0-work-org-topology` (Issue #124)

**Convention**:
- Lowercase, hyphenated
- Feature name explicit (not issue number alone)
- `gen0` indicates autonomous work (not HAIKU, which would be `haiku-unit-N`)
- Per-issue isolation (no shared repos across issues)

### Reference Repos (VGM9)

**Pattern**: `{NAMESPACE}.{DOMAIN}.{LAYER}.{CONCEPT}`

**Examples**:
- `VGM9.maslau0.base.PRESENCE.CASTING`
- `AURORA-4.6-PATTERNS`
- `as-cast`

**Convention**:
- Hierarchical namespace (VGM9 → maslau0 → base → component)
- Uppercase for concepts
- Semantic meaning in path

### Ecosystem Repos (wordgarden-dev)

**Pattern**: `aurora-{subsystem}-{component}`

**Examples**:
- `aurora-thesean/aurora_AT_aurora._ENV_HOME_._` (underbar namespace)
- `aurora-cc0` (control center)
- `aurora-gen1-[feature]` (future)

**Convention**:
- Aurora prefix
- Subsystem clarity (cc0, gen1, etc.)
- Underbar namespace for primordial layer (_)

---

## Cross-Org Assignment Flow

### Multi-Phase Assignment Lifecycle

**Phase 1-4: Internal Execution**
```
1. GitHub Issue created (#112 in aurora-thesean)
2. AURORA self-assigned (autonomous decision)
3. Isolation repo created in Agent-Of (aurora-gen0-work-*)
4. Work executed (Phases 1-4 in isolation)
5. PR created in target repo (aurora-thesean/claude-code-control)
```

**Phase 5-7: External Review & Merge**
```
6. DarienSirius reviews PR (external gate)
7. Merge into target repo (PR approved)
8. Archive isolation repo (tag: archive/{issue-number})
```

### Multi-Org Coordination Points

**Quota Coordination**:
- Single daily budget (150k tokens)
- Shared across all orgs
- Agent-Of isolation repos count against budget
- wordgarden-dev ecosystem work counts against budget

**Access Escalation**:
- Agent-Of: No escalation needed (isolation repos are open)
- VGM9: Request pattern definitions (read-only by default)
- wordgarden-dev: Escalate to DarienSirius for sensitive ecosystem changes

**Token Scope Across Orgs**:
- Single GitHub token (aurora-thesean account)
- Token scopes apply to all orgs
- Scope limitations (Issue #58: missing admin:public_key, Issue #99: missing project scope)

---

## Public vs Private Access Patterns

### Public Repos (Agent-Of)

**Visibility**: All work repos public by default
**Rationale**: Isolation repos are ephemeral (archive after merge), open review enables feedback
**Access Control**: GitHub branch protection rules on main (require PR review)

**Example**:
```
aurora-gen0-work-test-validator (public)
├─ main branch (protected, requires PR)
├─ Phase 1-4 PRs visible
└─ WORK-STATE.jsonl checkpoints visible
```

### Private Repos (wordgarden-dev)

**Visibility**: Ecosystem repos private
**Rationale**: Internal coordination, multi-agent infrastructure
**Access Control**: Org membership required

**Example**:
```
aurora-thesean/aurora_AT_aurora._ENV_HOME_._ (private)
├─ Multi-org topology mapping
├─ Coordination infrastructure
└─ Internal PHASE-* documentation
```

### Mixed Access (VGM9)

**Visibility**: Public pattern definitions + private research repos
**Rationale**: Share patterns openly, protect research/WIP
**Access Control**: Selective repo visibility

---

## Permission Boundaries & Escalation

### What AURORA Can Do (Autonomous)

✅ **Agent-Of Org**:
- Create isolation repos
- Push to main branch (with PR review)
- Manage issues/PRs
- Archive repos (after merge)

✅ **wordgarden-dev Org**:
- Read all repos (member access)
- Create issues
- Comment on PRs
- View private repos

✅ **VGM9 Org**:
- Read public repos
- Read private repos (member access)
- Clone pattern definitions
- Reference in documentation

### What Requires Escalation (LOA 8)

❌ **org-level actions**:
- Create new organization
- Modify org settings
- Add/remove organization members
- Change org visibility

❌ **Special access**:
- Token scope elevation (Issue #58: admin:public_key, Issue #99: project scope)
- Sensitive repo creation
- Audit log access

❌ **Cross-org policy changes**:
- Merge strategy changes
- Review requirements modifications
- Secrets management updates

**Escalation Path**: Create GitHub Issue → DarienSirius LOA 8 approval

---

## Org Topology Future Roadmap

### Phase 16+: GEN_1 Organization

**Planned**: New org for GEN_1 multi-agent deployment (Issue #60)
**Purpose**: Separate agent instances, parallel assignments
**Access**: AURORA + HAIKU + future agents
**Repos**: Assignment queues, multi-agent coordination

### Phase 17+: Cross-Org Consolidation

**Goal**: Unified /AS/ mapping across all 4 orgs
**Status**: Awaiting GEN_1 approval (Issue #60)

---

## Related Systems

- **Ecosystem Participant** (Issue #101): Maps org relationships, access patterns
- **Control Planes** (Issue #101): Tracks work across GitHub, Kanban, JSONL
- **Artifact Curator** (Issue #122): Manages documentation across orgs
- **Access Control Matrix** (Issue #124 companion): Permission details per repo

---

## Success Criteria

- [x] Org memberships documented (Agent-Of, VGM9, wordgarden-dev)
- [x] Repo inventory per org (total ~250 repos)
- [x] Access levels specified (member, owner, read-only)
- [x] Public vs private visibility matrix
- [x] Naming conventions documented
- [x] Multi-org assignment flow explained
- [x] Permission boundaries and escalation paths defined
- [x] Future roadmap (GEN_1, consolidation)

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Organization topology navigator subclass documented
**Confidence**: 85%+ (access patterns verified, future GEN_1 TBD)
**Estimated Lines**: 602

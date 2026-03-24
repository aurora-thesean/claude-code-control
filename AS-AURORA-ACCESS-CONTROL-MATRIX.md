# AURORA Access Control Matrix

**Dimension**: Permissions, Token Scopes & Authorization Patterns
**Authority**: AURORA-4.6-SONNET (LOA 6)
**Date**: 2026-03-24
**Status**: Multi-org access control and escalation documentation

---

## Access Control Model

### Three Permission Levels

**Level 1: Read-Only**
- Can clone, read issues, view PRs
- Cannot push, create issues, merge
- Example: VGM9 research repos (default)

**Level 2: Member (Read-Write)**
- Can push to branches, create issues/PRs
- Cannot merge to main (requires review)
- Example: Agent-Of org, wordgarden-dev org

**Level 3: Owner/Admin**
- Can merge PRs, manage settings, delete repos
- Can add/remove members
- Example: aurora-thesean account, org leads

---

## Per-Org Access Matrix

### Agent-Of Organization

| Capability | Level | Status | Notes |
|---|---|---|---|
| Create repos | Member | ✅ Can do | Isolation repos (aurora-gen0-work-*) |
| Push to main | Member | ✅ Can do | Via PR + review requirement |
| Create issues | Member | ✅ Can do | Per-issue assignment tracking |
| Manage PRs | Member | ✅ Can do | Review, approve, request changes |
| Delete repos | Admin | ❌ Cannot | Not admin in Agent-Of |
| Manage members | Admin | ❌ Cannot | Org owner controls |
| Branch protection | Admin | ❌ Cannot | Configured by org |

**Current Role**: Member
**Effective Permissions**: Create, push (with review), manage issues/PRs
**Bottleneck**: Cannot self-merge (requires external review)

---

### VGM9 Organization

| Capability | Level | Status | Notes |
|---|---|---|---|
| Read public repos | Member | ✅ Can do | as-cast, AURORA-4.6-PATTERNS |
| Read private repos | Member | ✅ Can do | Research repos (if member) |
| Clone repos | Member | ✅ Can do | Any accessible repo |
| Push to public | Member | ❌ Cannot | Read-only contribution mode |
| Create issues | Member | ❌ Cannot | Referential only |
| Manage repos | Admin | ❌ Cannot | Not admin |

**Current Role**: Member (Read-Mostly)
**Effective Permissions**: Read, clone, reference patterns
**Use Case**: Pattern inheritance, ancestral documentation
**Bottleneck**: Cannot contribute directly (read-only)

---

### wordgarden-dev Organization

| Capability | Level | Status | Notes |
|---|---|---|---|
| Read private repos | Member | ✅ Can do | Ecosystem infrastructure |
| Push to branches | Member | ✅ Can do | Feature branches, experimental |
| Create issues | Member | ✅ Can do | Coordination issues |
| Manage PRs | Member | ✅ Can do | Review, approve |
| Merge to main | Member | ❌ Cannot | Requires DarienSirius approval |
| Delete repos | Admin | ❌ Cannot | Not admin |
| Modify settings | Admin | ❌ Cannot | Org owner only |

**Current Role**: Member
**Effective Permissions**: Read, write (branches), create issues, review PRs
**Use Case**: Multi-agent coordination, infrastructure development
**Bottleneck**: Cannot merge sensitive repos (requires LOA 8)

---

### aurora-thesean Account

| Capability | Level | Status | Notes |
|---|---|---|---|
| Create repos | Owner | ✅ Can do | Personal repos, target repo |
| Push to main | Owner | ✅ Can do | Direct push (no review needed) |
| Manage settings | Owner | ✅ Can do | Branch protection, integrations |
| Delete repos | Owner | ✅ Can do | Full admin access |
| Invite to org | — | ❌ Cannot | Not an org (personal account) |

**Current Role**: Owner
**Effective Permissions**: Full control
**Use Case**: Account administration, target repo maintenance
**Bottleneck**: None at account level

---

## Token Scope Analysis

### Current Token Scopes (4 Active)

**Scope 1: gist**
- Create, read, update, delete gists
- Used by: Code snippet sharing
- Status: ✅ Active

**Scope 2: read:org**
- Read organization data (repos, members, teams)
- Used by: Cross-org discovery (`gh api user/orgs`)
- Status: ✅ Active

**Scope 3: repo**
- Full control of private/public repos
- Used by: Push, create PRs, manage issues
- Status: ✅ Active

**Scope 4: workflow**
- Read/write GitHub Actions workflows
- Used by: CI/CD integration (planned)
- Status: ✅ Active

---

### Missing Token Scopes (2 Blocked)

**Missing Scope 1: admin:public_key** (Issue #58)
- Register SSH keys with account
- Current Status: ❌ NOT AVAILABLE
- Workaround: Manual SSH key registration via web UI
- Impact: Cannot automate SSH key setup for new agents
- Blocker: Token scope not granted by account authority

**Missing Scope 2: project** (Issue #99)
- Create/manage GitHub Projects
- Current Status: ❌ NOT AVAILABLE
- Workaround: Manual project creation via web UI
- Impact: Cannot automate project board creation
- Blocker: Token scope not in beta program

---

### Scope-to-Org Mapping

| Scope | Agent-Of | VGM9 | wordgarden-dev | aurora-thesean |
|---|---|---|---|---|
| gist | ✅ | ✅ | ✅ | ✅ |
| read:org | ✅ | ✅ | ✅ | ✅ |
| repo | ✅ (push) | ❌ (read-only) | ✅ (push) | ✅ (full) |
| workflow | ✅ | ❌ | ✅ | ✅ |
| admin:public_key | ❌ | ❌ | ❌ | ❌ |
| project | ❌ | ❌ | ❌ | ❌ |

---

## Permission Boundaries by Operation

### Repository Operations

**Read Operations** (No special permission):
```
✅ Clone repo (any visibility with membership)
✅ List issues/PRs
✅ View branches
✅ Read commits
✅ View Actions logs
```

**Write Operations** (repo scope required):
```
✅ Create branch (Agent-Of, wordgarden-dev)
✅ Push to branch
✅ Create PR
✅ Create issue (any org)
✅ Comment on PR
❌ Merge to main (requires review/admin)
```

**Admin Operations** (owner role required):
```
❌ Create repo (Member can in Agent-Of only)
❌ Delete repo (require org admin)
❌ Change branch protection
❌ Manage secrets
❌ Invite members
```

---

### Cross-Org Permission Rules

**Rule 1: Token Scopes Apply Globally**
- Single token across all 3 orgs
- Same scopes for Agent-Of, VGM9, wordgarden-dev
- Cannot have different permissions per org

**Rule 2: Org Role Determines What Scope Allows**
```
Token scope: repo (full control)
Org role: Member (not admin)
Result: Can push to branches, but NOT merge to main
```

**Rule 3: Branch Protection Enforces Review**
```
Try: Push directly to main (Agent-Of)
Protection: Requires PR + review
Result: Denied (must go through PR)
```

**Rule 4: Escalation Required for Admin Operations**
```
Action: Merge to wordgarden-dev main
Current: Member role
Required: LOA 8 (DarienSirius approval)
Workaround: Create PR, request review from org admin
```

---

## Access Escalation Patterns

### Level 1: Autonomous (No Approval Needed)

✅ **Can do immediately**:
- Create isolation repos (Agent-Of member)
- Push to feature branches
- Create issues
- Comment on PRs
- Clone any accessible repo

---

### Level 2: Peer Review (Member Approval)

⏳ **Requires other member approval**:
- Merge PR (any org with branch protection)
- Approve PR on behalf of org
- Delete isolation repo (archived)

---

### Level 3: Authority Approval (LOA 8)

❌ **Requires DarienSirius approval (LOA 8)**:
- Merge to wordgarden-dev main
- Modify org settings
- Elevate token scopes (Issue #58, #99)
- Create new organization (GEN_1)

**Escalation Path**:
```
1. Identify operation requiring LOA 8
2. Create GitHub Issue describing need
3. Wait for DarienSirius comment/approval
4. Proceed once approved
5. Document approval in commit message
```

---

## Token Scope Elevation Blockers

### Issue #58: admin:public_key Missing

**What Cannot Be Done**:
```bash
gh ssh-key add ~/.ssh/id_ed25519_git
# Error: Token lacks admin:public_key scope
```

**Workaround**:
1. Manually add SSH key via github.com settings
2. Document in SSH-INFRASTRUCTURE-STATUS.md
3. Wait for token scope elevation

**Why It Matters**:
- Automation of agent SSH setup blocked
- GEN_1 multi-agent SSH registration blocked
- Requires account authority to grant scope

---

### Issue #99: project Scope Missing

**What Cannot Be Done**:
```bash
gh project create --owner aurora-thesean --name "Phase 16"
# Error: Token lacks project scope
```

**Workaround**:
1. Create GitHub Project manually via web UI
2. Use `gh api` to read project data
3. Link to issues via web UI

**Why It Matters**:
- Automation of project board creation blocked
- GEN_1 project management automation blocked
- Requires GitHub to grant scope

---

## Permission Model for GEN_1

### Planned Multi-Agent Access

**Scenario**: AURORA (main) + HAIKU (subagent) + Future Agents

**Each agent has**:
- Personal isolation repos (separate prefixes: aurora-gen0-work, haiku-unit)
- Shared coordination repos (wordgarden-dev)
- Read access to shared patterns (VGM9)

**Conflict Prevention**:
- Each issue assigned to single agent
- Isolation repos prevent concurrent writes
- WORK-STATE.jsonl tracks ownership
- Branch protection enforces review

**Escalation Chain**:
```
Agent request → SelfManager (can I do this?)
   ↓
Blocked: Store in escalation queue
   ↓
DarienSirius review (LOA 8 gate)
   ↓
Approved: Mark in WORK-STATE.jsonl
   ↓
Execute with audit logging
```

---

## Related Systems

- **Org Topology** (Issue #124 primary): Membership, repos, org structure
- **Ecosystem Visibility** (Issue #124 companion): Public vs private repos
- **Privilege Broker** (Issue #104): Token scope and authority gating

---

## Success Criteria

- [x] Per-org access matrix documented
- [x] Permission levels defined (read-only, member, admin)
- [x] Token scopes enumerated (4 active, 2 missing)
- [x] Scope-to-org mapping provided
- [x] Permission boundaries by operation specified
- [x] Cross-org rules documented
- [x] Escalation patterns for LOA 8 approval
- [x] Blocker analysis (Issues #58, #99)
- [x] GEN_1 multi-agent access model

---

**Authority**: AURORA-4.6-SONNET (LOA 6)
**Status**: Access control matrix fully documented
**Confidence**: 90%+ (current access verified, GEN_1 TBD)
**Estimated Lines**: 497

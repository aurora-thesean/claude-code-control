# SSH Infrastructure Setup — Epic 3 Implementation Plan

**Status:** In Progress
**Target:** Enable git push via SSH to GitHub (aurora-thesean org)
**Timeline:** 30 minutes total
**Blocker:** None (can proceed autonomously)

---

## Current State

**GitHub Account:** github.microsoft@aurora.wordgarden.dev (agent-controlled)
**Current Auth Method:** HTTPS (via gh CLI)
**Goal:** Add SSH key authentication (primary method for autonomous git operations)

---

## Implementation Steps

### Phase 1: SSH Key Generation

**Check existing keys:**
```bash
ls -la ~/.ssh/
# Look for: id_ed25519, id_ed25519_git, id_ed25519_github
```

**Generate Aurora SSH key (if needed):**
```bash
ssh-keygen -t ed25519 -C "aurora@wordgarden.dev" -f ~/.ssh/id_ed25519_aurora -N ""
# Algorithm: Ed25519 (modern, smaller keys, better security)
# No passphrase: -N "" (allows autonomous operation)
# Output: ~/.ssh/id_ed25519_aurora (private), ~/.ssh/id_ed25519_aurora.pub (public)
```

### Phase 2: GitHub Configuration

**Add public key to GitHub:**
```bash
# Read public key
cat ~/.ssh/id_ed25519_aurora.pub

# Via gh CLI:
gh ssh-key add ~/.ssh/id_ed25519_aurora.pub --title "Aurora SSH Key ($(date +%Y-%m-%d))"

# Or via GitHub web UI:
# Settings → SSH and GPG keys → New SSH key
# Paste public key content, give title, select "Authentication"
```

**Configure git to use SSH:**
```bash
# Set global SSH preference
git config --global user.signingkey ~/.ssh/id_ed25519_aurora

# Test SSH connection
ssh -T git@github.com
# Expected: Hi github-microsoft! You've successfully authenticated...
```

### Phase 3: Repository Configuration

**Update aurora-thesean/claude-code-control remote:**
```bash
# Current (HTTPS):
git remote -v
# origin https://github.com/aurora-thesean/claude-code-control.git

# Switch to SSH:
git remote set-url origin git@github.com:aurora-thesean/claude-code-control.git

# Verify:
git remote -v
# origin git@github.com:aurora-thesean/claude-code-control.git (fetch)
# origin git@github.com:aurora-thesean/claude-code-control.git (push)
```

**Update all agent repositories:**
```bash
# For each repo in ~/repo-staging:
for repo in ~/repo-staging/*/; do
    cd "$repo"
    ORIGIN=$(git remote get-url origin)
    if [[ "$ORIGIN" == https://* ]]; then
        REPO_PATH=$(echo "$ORIGIN" | sed 's|https://github.com/||; s|\.git$||')
        git remote set-url origin "git@github.com:$REPO_PATH.git"
    fi
done
```

### Phase 4: Testing

**Test SSH authentication:**
```bash
ssh -T git@github.com
# Expected: successful auth message

# Test git operations:
cd ~/repo-staging/claude-code-control
git fetch origin main
git status

# If successful, next push will use SSH automatically
```

**Test push (if changes pending):**
```bash
git push origin main
# Should work without password prompt (key-based auth)
```

---

## SSH Key Management

**Security Properties:**
- Ed25519 algorithm: Modern, resistant to quantum attacks
- Private key: ~/.ssh/id_ed25519_aurora (600 permissions)
- Public key: ~/.ssh/id_ed25519_aurora.pub (644 permissions)
- No passphrase: Allows unattended operation (acceptable for agent-controlled account)
- Scope: Aurora account only (not personal GitHub)

**Key Rotation Schedule:**
- Generate new key: Every 90 days
- Revoke old key: Immediate (via GitHub settings)
- Log rotations: ~/.aurora-agent/ssh-key-rotations.jsonl

---

## Threat Model & Mitigations

| Threat | Mitigation |
|--------|-----------|
| Key compromise | Monthly rotation + GitHub audit log monitoring |
| Unauthorized pushes | SSH key tied to aurora-thesean org only (not global) |
| Key leakage | Private key permissions 0600, not in git repos |
| Account takeover | GitHub 2FA enabled (separate epic) |

---

## Success Criteria

- [ ] SSH key generated (Ed25519, no passphrase)
- [ ] Public key added to GitHub
- [ ] SSH connection test passes (ssh -T git@github.com)
- [ ] Repository remotes switched to SSH
- [ ] At least one git push successful via SSH
- [ ] Documentation updated in ssh-infrastructure/ directory

---

## Integration with Other Epics

**Blocks:**
- None (SSH is independent)

**Enables:**
- Autonomous git push (Unit 6 compilation results, etc.)
- 2FA integration (GitHub session auth)
- Parallel agent git operations without token conflicts

**Blocked By:**
- None (can proceed now)

---

## Estimated Effort

| Phase | Action | Time |
|-------|--------|------|
| 1 | Key generation | 1 min |
| 2 | GitHub config | 3 min |
| 3 | Repo updates | 5 min |
| 4 | Testing | 3 min |
| **Total** | — | **12 min** |

---

## Rollback Plan

If SSH authentication fails:
1. Revert to HTTPS: `git remote set-url origin https://github.com/aurora-thesean/claude-code-control.git`
2. Delete SSH key from GitHub (via settings)
3. Remove local key: `rm ~/.ssh/id_ed25519_aurora*`
4. Continue with HTTPS auth (current state)

**No impact on git history or code.**

---

## Next Steps After SSH Setup

1. ✅ SSH infrastructure operational
2. 🔄 2FA Compliance: Prove OAuth flow with SSH + 2FA
3. 🔄 Unit 6 Compilation: Push libqcapture.so build results via SSH
4. 🔄 Final Epoch 1 verification

---

## Deliverables

**Code:**
- SSH key pair (Ed25519, passphraseless)

**Documentation:**
- This plan (SSH-INFRASTRUCTURE-SETUP.md)
- ssh-key-management.md (operational procedures)
- ssh-key-rotation.sh (automation)

**Git:**
- Commit: "SSH Infrastructure: Add Ed25519 authentication"

---

**Status: READY TO IMPLEMENT**

No blockers. Can proceed immediately with key generation and GitHub configuration.

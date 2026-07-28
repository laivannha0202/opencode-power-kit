# Upstream Risks Analysis

> Version: 1.0.0
> Generated: 2026-07-03

## Risk Matrix

### 1. Permission Risk

**Risk Level:** MEDIUM (mitigated)

**Description:** `templates/opencode.json` uses a permission object with deny-list. Default mode grants broad access but denies destructive commands.

**Impact:**
- Agent can execute most bash commands without user confirmation
- Destructive commands (rm -rf, git reset --hard, etc.) are denied
- Safe mode available with granular `"ask"` fallback

**Mitigation:**
- Permission object with deny-list in all templates (default, power, safe)
- Destructive commands denied: `rm -rf`, `git reset --hard`, `git clean -fd`, `git push --force`, `DROP TABLE`, `TRUNCATE TABLE`, `curl|sh`, `wget|sh`
- Safety rules enforced via instruction rules (AGENTS.md)
- Safety plugin guard available (`opk safety-plugin install`)
- Safe mode (`opencode.safe.json`) uses `"ask"` fallback for write/edit/bash

**Recommendation:** Use safe mode in shared environments. Default mode suitable for trusted-local use only.

### 2. Auto-Install Risk

**Risk Level:** MEDIUM

**Description:** Some integrations auto-install during `opk global`/`opk one`/`opk go`.

**Impact:**
- Taste Skill was auto-installed without verification — **now mitigated** (verify-gated)
- BMAD Method installed without user consent check
- Network dependency during install

**Mitigation:**
- Taste Skill auto-install completely removed from `install-global.sh` (v2.0.0)
- User runs `opk taste install` explicitly (verify-gated)
- Safe removal: `opk taste off` moves to `.opk-trash/` (never `rm -rf`)
- All remaining auto-installs use official installers (npx/pipx)
- Never vendor upstream source
- Dry-run mode available for most installers
- Opt-out available via flags

**Recommendation:** ✅ Taste Skill auto-install fully removed (v2.0.0). Consider verify-gating BMAD as well.

### 3. Stale Package Risk

**Risk Level:** MEDIUM

**Description:** Deprecated packages may still be referenced in scripts.

**Impact:**
- Deprecated package names in comments may confuse contributors
- Old package references in migration docs need context

**Mitigation:**
- Migration notes in CHANGELOG.md
- THIRD_PARTY.md documents correct packages
- Validator checks for deprecated references outside migration sections
- Install scripts migrated to `supermemory` (from `@supermemory/ai`)

**Recommendation:** Keep deprecated package names only in DEPRECATED comments for reference.

### 4. License/Copy Risk

**Risk Level:** LOW

**Description:** Upstream dependencies have various licenses.

**Impact:**
- Some upstream licenses restrict commercial use
- Redistribution requirements may apply
- License changes could affect kit

**Mitigation:**
- Kit never vendors full upstream source
- All integrations are thin wrappers or references
- THIRD_PARTY.md documents all licenses
- No code copying without attribution

**Recommendation:** Regular license review for all upstream dependencies.

### 5. Linux Platform Boundary Risk

**Risk Level:** LOW

**Description:** v2.1.0 intentionally supports Linux only.

**Impact:**
- Users on unsupported platforms cannot use OPK entrypoints
- Platform-specific behavior stays out of the release gate
- Linux dependencies still need to be present on PATH

**Mitigation:**
- Shared `scripts/require-linux.sh` guard
- No PowerShell, CMD, or BAT runtime artifacts
- Local Linux release gate is authoritative

**Recommendation:** Keep the platform statement explicit and reject unsupported kernels early.

### 6. Node/Python/uv Version Risk

**Risk Level:** MEDIUM

**Description:** Different upstream tools require different runtime versions.

**Impact:**
- BMAD Method requires Node >= 20.12
- Some workflows may need Python >= 3.10
- uv required for some BMAD workflows
- Version conflicts between tools

**Mitigation:**
- Doctor scripts check for required tools
- Graceful degradation when tools missing
- Warnings instead of hard failures
- Version requirements documented

**Recommendation:** Add version detection to tooling-doctor.

### 7. Optional Tooling Absent Risk

**Risk Level:** LOW

**Description:** Detect-only tools may not be installed.

**Impact:**
- rtk, repomix, ast-grep, etc. not available
- Some commands may fail or degrade
- User confusion about missing features

**Mitigation:**
- Doctor scripts detect installed tools
- Install hints provided but not auto-installed
- Commands fail gracefully with clear messages
- Documentation explains which tools are optional

**Recommendation:** Add version display to all tool detection.

### 8. Network Dependency Risk

**Risk Level:** MEDIUM

**Description:** Installers require network access to npm/pip registries.

**Impact:**
- Install fails without network
- Offline environments cannot install
- Registry outages affect installation

**Mitigation:**
- Dry-run mode for planning
- Clear error messages for network failures
- Some tools cached by npm/pip
- Local fallback options documented

**Recommendation:** Document offline installation procedures.

## Risk Summary

| Risk | Level | Mitigation Status | Action Required |
|------|-------|-------------------|-----------------|
| Permission | HIGH | Mitigated | ✅ Deny-list in all templates (v2.0.0) |
| Auto-Install | MEDIUM | Mitigated | ✅ Taste auto-install removed (v2.0.0) |
| Stale Package | MEDIUM | In Progress | Update scripts |
| License/Copy | LOW | Good | Regular review |
| Linux Boundary | LOW | Good | Keep guard and docs aligned |
| Version Risk | MEDIUM | Partial | Add detection |
| Tooling Absent | LOW | Good | Add version display |
| Network | MEDIUM | Good | Document offline |
| Skill Discovery | LOW | Good | Document in UPSTREAM_AUDIT |

# Upstream Update Policy

> Version: 1.0.0
> Effective: 2026-07-03

## Overview

This document defines when and how opencode-power-kit updates references to external upstream dependencies.

## Update Categories

### 1. Pin Version Updates (Scripts/Config)

**When:** Upstream releases new stable version that doesn't break compatibility.

**Process:**
1. Verify new version works with existing integration
2. Update default pin in all relevant scripts:
   - `install.sh` / `install.ps1`
   - `update-bmad.sh` / `update-bmad.ps1`
   - Any other scripts with hardcoded versions
3. Add migration note in CHANGELOG.md
4. Update THIRD_PARTY.md if integration type changes
5. Run validation: `python3 scripts/validate-opencode-pack.py`

**Example:**
```bash
# BMAD Method 6.8.0 → 6.9.0
sed -i 's/6\.8\.0/6.9.0/g' install.sh install.ps1 update-bmad.sh update-bmad.ps1
```

### 2. Documentation Updates Only

**When:** Upstream changes docs/examples but not core behavior.

**Process:**
1. Update README.md references
2. Update THIRD_PARTY.md URLs/descriptions
3. No script changes needed

### 3. Package Migration

**When:** Upstream deprecates package or changes package name.

**Process:**
1. Update install scripts to use new package name
2. Add DEPRECATED comment in old package references
3. Update validator to expect new package
4. Add migration note in CHANGELOG.md
5. Update THIRD_PARTY.md

**Example:**
```bash
# @supermemory/ai → supermemory
SUPERMEMORY_PACKAGE="supermemory"  # Changed from @supermemory/ai
```

### 4. Integration Type Changes

**When:** Upstream behavior changes how kit integrates.

**Process:**
1. Update integration type in THIRD_PARTY.md
2. Update UPSTREAM_AUDIT.md
3. Update any scripts that depend on integration type
4. Update validator if needed

## Breaking Changes Handling

### Upstream Breaking Changes

1. **Pin to last working version** temporarily
2. **Document the issue** in CHANGELOG.md
3. **Test compatibility** before updating pin
4. **Never auto-update** to untested versions

### Kit Breaking Changes from Upstream

1. **Add version constraints** in install scripts
2. **Add compatibility checks** in doctor.sh
3. **Document workarounds** in README.md

## License Changes

1. **Never vendor** upstream source
2. **Always attribute** in THIRD_PARTY.md
3. **Check license compatibility** before integrating
4. **Document license** for each upstream

## Taste Skill Updates (v1/v2)

**When:** Upstream Taste Skill releases new version or user wants v1 legacy.

**Process:**
1. User runs `opk taste install` (default: v2) or `opk taste install --v1` (legacy)
2. Script verifies node/npx availability before install
3. Script uses `--dry-run` to preview, `--yes` to confirm
4. No auto-update — user explicitly requests update via `opk update-taste`

**Version differences:**
- **v2 (default):** `npx skills add Leonxlnx/taste-skill` — latest, recommended
- **v1 (legacy):** `npx skills add https://github.com/Leonxlnx/taste-skill --skill "design-taste-frontend-v1"` — specific skill name

**Safety:**
- Never auto-installed during global setup
- `OPK_SKIP_TASTE=1` bypasses any auto-install in scripts
- `opk taste off` moves to `.opk-trash/` (no `rm -rf`)

## Security Advisories

1. **Monitor** upstream security releases
2. **Update pins** if security fix required
3. **Document** security-relevant updates in CHANGELOG.md
4. **Never auto-apply** security patches without testing

## MCP/Plugin Changes

1. **Never auto-enable** MCP in default templates
2. **Always use opt-in** for MCP integrations
3. **Document** MCP requirements clearly
4. **Test** MCP integration before shipping

## Update Schedule

| Category | Frequency | Trigger |
|----------|-----------|---------|
| Pin versions | Monthly | Upstream release |
| Documentation | As needed | Upstream doc changes |
| Package migration | As needed | Deprecation notice |
| Security patches | Immediately | CVE announcement |
| License review | Quarterly | Upstream license change |

## Validation Checklist

Before merging any upstream update:

- [ ] `python3 scripts/validate-opencode-pack.py` passes
- [ ] `bash verify.sh` passes
- [ ] No new `@supermemory/ai` references outside migration section
- [ ] No `get-shit-done` package references
- [ ] No `use_skill` or `find_skills` as main workflow
- [ ] Permission templates have deny-list for destructive commands
- [ ] THIRD_PARTY.md updated with new version/integration info
- [ ] CHANGELOG.md entry added
- [ ] No secrets or API keys exposed

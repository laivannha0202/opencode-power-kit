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
2. Update the single reviewed pin in `scripts/upstream-versions.sh`.
3. If the pin is embedded in a runtime reference, update generated/template references and keep the drift validator green.
4. Add migration note in CHANGELOG.md
5. Update THIRD_PARTY.md if integration type changes
6. Run `python3 scripts/audit-upstreams.py --check` and `python3 scripts/validate-opencode-pack.py`.

**Example:**
```bash
# Edit OPK_BMAD_VERSION once, then run the validators.
$EDITOR scripts/upstream-versions.sh
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

## Taste Skill Updates

**When:** Upstream Taste Skill releases a new version or the user wants to refresh the installation.

**Process:**
1. User runs `opk taste install` for a first install or `opk taste update` to refresh
2. Script checks `npx` availability before install or update
3. Script uses `--dry-run` to preview, `--yes` to confirm
4. No auto-update — refreshes happen only after an explicit `opk taste update` request
5. Install, network, or post-install verification failures return nonzero

The supported contract installs the current Taste Skill through the official
`npx` flow; OPK does not expose version-selection flags. During refresh, an
existing installation is moved to kit `.opk-trash/` before reinstalling. If
reinstall fails, recovery may require moving it back manually.

**Safety:**
- Never auto-installed during global setup
- `OPK_SKIP_TASTE=1` is a legacy variable and is no longer needed
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
- [ ] `bash scripts/release-gate.sh` passes on Linux
- [ ] No new `@supermemory/ai` references outside migration section
- [ ] No `get-shit-done` package references
- [ ] No `use_skill` or `find_skills` as main workflow
- [ ] Permission templates have deny-list for destructive commands
- [ ] Template/plugin pins match `scripts/upstream-versions.sh`
- [ ] THIRD_PARTY.md updated with new version/integration info
- [ ] CHANGELOG.md entry added
- [ ] No secrets or API keys exposed

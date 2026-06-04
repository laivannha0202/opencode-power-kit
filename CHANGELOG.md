# Changelog

All notable changes to OpenCode Power Kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-04

First production-grade release. Bumped from 9.4/10 → 10/10.

### Added

- **Global pack** (`opencode-global/`): 4 agents, 15 commands, 12 skills
  - Lifecycle commands: `spec-lite`, `plan-work`, `build-slice`, `test-proof`, `ship-check`
  - Review commands: `security-review`, `api-contract-review`, `migration-safe`, `review-diff`
  - Token commands: `rtk-gain`, `token-pack`
  - Utility commands: `smart-scan`, `bugfix-safe`, `repo-map`, `db-readonly`
- **Per-project install** (`install.sh`): seeds `AGENTS.md`, `OPENCODE.md`,
  `.opencode/opencode.json`, `.gitignore` (merged), `knip.json`, `lefthook.yml`
- **Global install** (`install-global.sh`): sets `OPENCODE_CONFIG_DIR` in
  `~/.bashrc` and adds `~/.local/bin` to `PATH`. Backs up existing files
  before touching them
- **BMAD integration**: `install.sh` and `update-bmad.sh` install BMAD Method
  via `npx bmad-method install --modules bmm --tools opencode`
- **Superpowers**: enabled through `.opencode/opencode.json` template
- **Token tools** (`scripts/install-token-tools.sh`): detects `rtk` and
  `tokscale`; never auto-runs `curl|sh`, never uses `sudo`
- **Verify** (`verify.sh`): checks global config, pack structure, MCP
  absence, secret-pattern absence, project files
- **Pack validator** (`scripts/validate-opencode-pack.py`): checks
  `commands/*.md` frontmatter + `description`, `agents/*.md` frontmatter +
  `description` + `mode`, `skills/*/SKILL.md` heading + body
- **Integration test** (`scripts/integration-test.sh`): builds a temp
  project, runs `install.sh` + `verify.sh`, asserts expected files exist
- **Doctor** (`doctor.sh`): read-only diagnostic for `OPENCODE_CONFIG_DIR`,
  pack structure, scripts, MCP, secrets
- **Uninstall** (`uninstall.sh`): restores from backup if present;
  requires confirmation (or `--yes`)
- **CI** (`.github/workflows/ci.yml`): 12 jobs — `bash -n`, `shellcheck`
  (best effort), `shfmt -d` (best effort), JSON templates, YAML templates,
  `git diff --check`, no-MCP guard, no-secrets scan, line-count guard,
  pack validation, integration test
- **Safety**:
  - No MCP config in `opencode-global/` (verified by CI)
  - No `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
    patterns in source (verified by CI)
  - No `curl|sh`, no `sudo` in install scripts
  - Backup before overwrite (`.opencode-power-kit-backup-<timestamp>`)
- **Release metadata**: `VERSION` (1.0.0), `CHANGELOG.md` (this file)
- **Badges** in `README.md`: CI status, version, no-MCP policy,
  safe/no-secrets policy

[1.0.0]: https://github.com/nguoikhongten02022005-cell/opencode-power-kit/releases/tag/v1.0.0

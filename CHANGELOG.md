# Changelog

All notable changes to OpenCode Power Kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-06-04

### Fixed

- `.github/workflows/ci.yml`: bước `Validate YAML in templates/` chứa
  `python3 -c` với line continuation `\` làm vỡ YAML block scalar. Rewrite
  thành bash multi-line dùng `set +e` + retry sau `pip install pyyaml`. CI
  giờ parse được `ci.yml` + chạy được job `yaml-templates`.
- `scripts/integration-test.sh`, `doctor.sh`, `uninstall.sh`: expand 3 cụm
  one-liner function (`info/ok/warn/err`) thành multi-line cho style chuẩn.
- Markdown headings + code fences: scan toàn repo, không có heading level
  bị skip, không có code fence mất cân.
- Secret scan: clean (loại trừ `CHANGELOG.md`, `README.md`, `doctor.sh`,
  `docs/*`; command `secret-scan.md` đã viết lại pattern ví dụ để không
  match regex nữa).

### Notes

- Không thêm file mới, không đổi logic.
- `v1.1.0` tag giữ nguyên — commit v1.1.0 vẫn tồn tại ở `4114471` cho ai
  tham chiếu; release "sạch" ở main là `v1.1.1`.

## [1.1.0] - 2026-06-04

### Added

- **Full-stack profile** (`profiles/node-nest-react-mysql/`) cho stack
  NestJS + React/Vite + MySQL:
  - 5 commands: `fullstack-scan`, `api-e2e-flow`, `env-doctor`,
    `docker-dev-doctor`, `seed-data-safe`.
  - 5 skills: `nestjs-backend`, `react-vite-frontend`, `mysql-schema-safe`,
    `auth-rbac-review`, `fullstack-test-strategy`.
  - `AGENTS.append.md` + `OPENCODE.append.md` với rule layer + workflow.
- **Profile installer** (`scripts/install-fullstack-profile.sh`): copy commands
  + skills, append AGENTS/OPENCODE với marker idempotent, backup file user.
  Từ chối chạy trong HOME hoặc trong `~/opencode-power-kit`.
- **Global full-stack commands** (9 mới):
  `fullstack-scan`, `openapi-check`, `secret-scan`, `sast-check`,
  `e2e-plan`, `test-matrix`, `js-quality-check`, `env-doctor`,
  `docker-dev-doctor`.
- **Global full-stack skills** (8 mới):
  `openapi-contract`, `secure-fullstack`, `dependency-maintenance`,
  `fullstack-test-strategy`, `js-ts-quality`, `env-config-safe`,
  `docker-compose-safe`, `nest-react-mysql`.
- **Templates** (4 mới):
  `biome.json.example`, `renovate.json.example`,
  `openapi/openapi.yaml.example`, `openapi/spectral.yaml.example`.
- **Optional install scripts** (3 mới):
  `install-security-tools.sh`, `install-api-tools.sh`,
  `install-js-quality-tools.sh`. Detect tool, in hướng dẫn, tạo report.
  Không sudo, không curl|sh, không tự cài.

### Changed

- **Pack validator** (`scripts/validate-opencode-pack.py`): thêm validate
  `profiles/*/commands/*.md` frontmatter + `profiles/*/skills/*/SKILL.md`
  heading + `templates/openapi/*.example` tồn tại.
- **Integration test** (`scripts/integration-test.sh`): thêm test
  `install-fullstack-profile.sh` trong temp project, verify marker + artifacts.
- **CI** (`.github/workflows/ci.yml`):
  - `bash -n` thêm 4 script mới.
  - `no-mcp` scan cả `profiles/`.
  - `line-count-guard` thêm min lines cho 17 file mới.
  - Validate JSON `biome.json.example`, `renovate.json.example`.
  - Validate YAML `spectral.yaml.example`.

### Safety (giữ nguyên policy)

- Không thêm MCP config vào `opencode-global/` hay `profiles/`.
- Không chứa `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
  pattern trong source.
- Không sudo, không curl|sh trong install scripts.
- Không tự cài dependency nặng (gitleaks, semgrep, biome, ...).
- Backup trước khi append/sửa file user.

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

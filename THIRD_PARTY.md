# Third-Party Components & Credits

> **Version:** opencode-power-kit v1.6.7
>
> This project packages, configures, and documents workflows around
> [OpenCode](https://github.com/opencode-ai). It credits upstream authors
> clearly and does **not** claim ownership of upstream projects.

---

## Tooling Policy

1. **No bundled third-party source** unless explicitly documented as such.
2. **No hidden auto-update.** No shell-startup auto installer.
3. **No silent package manager install.**
4. **No vendored source** of any tool or library.
5. **Bundled snapshots** (if any) are release-coupled — they ship with the kit
   release and are never pulled behind the user's back.
6. **Opt-in wrappers** require explicit user command.
7. **Detect-only tools** are never installed or updated automatically.
8. **Licenses** remain with upstream authors. This file documents what we know;
   verify upstream licenses yourself before redistributing.

---

## Integration Modes

| Mode | Meaning | Auto-update? | Vendor source? | Example |
|------|---------|:---:|:---:|---------|
| **Target platform** | Nền tảng mà kit cấu hình / đóng gói workflow | No | No | OpenCode |
| **Plugin reference** | Plugin được load runtime từ GitHub/npm | Via OpenCode | No | Superpowers |
| **Install-time dependency** | Cài vào project user qua official installer | Via npx | No | BMAD Method |
| **Config-only reference** | Kit chỉ ship template config trỏ đến upstream | No | No | Biome config |
| **Opt-in wrapper** | Chỉ gọi installer chính thức khi user yêu cầu | No | No | GSD Core, MarkItDown |
| **Detect-only** | Chỉ phát hiện tool đã cài sẵn trên PATH | No | No | rg, fd, semgrep |
| **Recommended ecosystem** | Stack mục tiêu / tài liệu hướng dẫn | No | No | NestJS, React, MySQL |

---

## Full Component Table

| Upstream / Tool | Author / Org | Link | Role | Integration | Update path | License note |
|-----------------|-------------|------|------|:-----------:|:-----------:|:-----------:|
| OpenCode | OpenCode / SST | https://github.com/opencode-ai | AI coding agent platform | Target platform | User updates via official channel | MIT |
| Superpowers | obra | https://github.com/obra/superpowers | Agent skill library / plugin | Plugin reference | Loaded at runtime by OpenCode plugin system | MIT |
| BMAD Method | bmad-code-org | https://github.com/bmad-code-org/BMAD-METHOD | Workflow modules, agents, slash commands | Install-time dependency | `install.sh` / `update-bmad.sh` calls `npx bmad-method` | MIT |
| GSD Core | open-gsd | https://github.com/open-gsd/gsd-core | Optional companion workflow engine | Opt-in wrapper | `opk gsd` / `opk update-gsd` | See npm |
| MarkItDown | Microsoft | https://github.com/microsoft/markitdown | Document-to-Markdown conversion (PDF/DOCX/PPTX/XLSX/HTML) | Opt-in wrapper | `opk markitdown install` (pipx/pip) | MIT |
| Supermemory | sudomateo / community | https://github.com/supermemory/supermemory | Memory persistence across AI coding sessions | Opt-in wrapper | `opk supermemory install` (npm) | Apache-2.0 |
| rtk | rtk-ai | https://github.com/rtk-ai/rtk | Token-saving shell wrapper | Detect-only | User installs separately | MIT |
| tokscale | — | https://github.com/tokscale/tokscale | Token cost visualization | Detect-only | User installs separately | — |
| repomix | yamadashy | https://github.com/yamadashy/repomix | Context pack generator | Detect-only | User installs separately | MIT |
| ast-grep | ast-grep | https://github.com/ast-grep/ast-grep | Structural code search | Detect-only | User installs separately | MIT |
| ripgrep (rg) | BurntSushi | https://github.com/BurntSushi/ripgrep | Fast regex text search | Detect-only | User installs separately | MIT / Unlicense |
| fd | sharkdp | https://github.com/sharkdp/fd | Fast file finder | Detect-only | User installs separately | Apache-2.0 / MIT |
| knip | webpro-nl | https://github.com/webpro-nl/knip | Dead file/dependency detection for JS/TS | Detect-only | User installs separately | MIT |
| gitleaks | gitleaks | https://github.com/gitleaks/gitleaks | Git secret scanning | Detect-only | User installs separately | MIT |
| trufflehog | trufflesecurity | https://github.com/trufflesecurity/trufflehog | Secret scanning | Detect-only | User installs separately | AGPL-3.0 |
| semgrep | semgrep | https://github.com/semgrep/semgrep | SAST / static analysis | Detect-only | User installs separately | LGPL-2.1 |
| spectral | stoplightio | https://github.com/stoplightio/spectral | OpenAPI lint | Detect-only | User installs separately | Apache-2.0 |
| oasdiff | tufin | https://github.com/tufin/oasdiff | OpenAPI diff / breaking change detection | Detect-only | User installs separately | Apache-2.0 |
| Playwright | Microsoft | https://github.com/microsoft/playwright | E2E browser testing | Detect + CLI call | User installs; kit may call `npx playwright` | Apache-2.0 |
| Biome | biomejs | https://github.com/biomejs/biome | JS/TS lint + format | Config-only reference + detect | User installs separately | Apache-2.0 / MIT |

---

## 1. OpenCode — Target Platform

| Field | Value |
|-------|-------|
| Role | AI coding agent platform — the target environment this kit configures |
| Integration | **Target platform** — kit ships workflow configs, agents, commands, skills for OpenCode |
| Source | https://github.com/opencode-ai |
| Kit scope | Configures OpenCode via `templates/opencode.json`, `templates/AGENTS.md`, `templates/OPENCODE.md` |
| License | MIT (per upstream) |

opencode-power-kit is **not** a fork or reimplementation of OpenCode. It is a
configuration pack / workflow kit that makes OpenCode more productive for
full-stack development. OpenCode itself must be installed separately.

---

## 2. Superpowers — Plugin Reference

| Field | Value |
|-------|-------|
| Role | Agent skill library — loaded as an OpenCode plugin at runtime |
| Integration | **Plugin reference** — `templates/opencode.json` contains `"plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]` |
| Source | https://github.com/obra/superpowers |
| Kit ships | Only a JSON reference; no source files from Superpowers are vendored |
| License | MIT (per upstream) |

At OpenCode startup, the `opencode.json` plugin directive tells OpenCode to
fetch Superpowers from GitHub. The kit does **not** bundle Superpowers skills
in-tree — the `opencode-global/skills/` directory contains the kit's own
curated skills, separate from Superpowers.

---

## 3. BMAD Method — Install-time Dependency

| Field | Value |
|-------|-------|
| Role | Workflow modules, agents, slash commands for OpenCode |
| Integration | **Install-time dependency** — `install.sh` runs `npx bmad-method@VERSION install` into the target project |
| Source | https://github.com/bmad-code-org/BMAD-METHOD |
| npm | `bmad-method` (published to npm registry) |
| Version pin | `BMAD_METHOD_VERSION` env (default: 6.8.0) in `install.sh`, `install.ps1`, `update-bmad.sh`, `update-bmad.ps1` |
| Kit ships | Wrapper scripts that call the official npm installer |
| Update path | `bash update-bmad.sh` / `opk update-bmad` — re-runs `npx bmad-method@... install` |
| License | MIT (per upstream) |

BMAD Method is installed into the **user's project** at install time, not
bundled in the kit repo. There is no `_bmad/` directory in the kit source.
The kit's `install.sh` and `update-bmad.sh` are thin wrappers that:

1. Resolve `BMAD_METHOD_VERSION` (env override or default).
2. Verify `node`, `npm`, `npx` are on PATH.
3. Forward to `npx bmad-method@<version> install --modules bmm --tools opencode --user-name <user>`.
4. Capture full log to `.opencode-power-bmad-install.log` for debugging.

---

## 4. GSD Core — Opt-in Wrapper

| Field | Value |
|-------|-------|
| Role | Optional companion workflow/context-engineering system |
| Integration | **Opt-in wrapper** — never vendored, calls official installer only on user request |
| Source | https://github.com/open-gsd/gsd-core |
| npm | `@opengsd/gsd-core` |
| Installer | `npx @opengsd/gsd-core@latest` |
| Kit ships | `scripts/install-gsd-core.sh` + `scripts/install-gsd-core.ps1` — thin wrappers |
| Update path | `opk gsd` / `opk update-gsd` / `opk update-all --with-gsd` |
| License | See npm package page |

The kit does **not** bundle GSD Core. The wrapper scripts:

1. Verify `node`, `npm`, and `npx` are on PATH.
2. Print the planned `npx @opengsd/gsd-core@latest` command.
3. Ask for confirmation (or accept `--yes` / `-Y`).
4. Forward to the official installer.

There is no shell-startup hook, no auto-update, and no silent background
refresh.

---

## 5. MarkItDown — Opt-in Wrapper

| Field | Value |
|-------|-------|
| Role | Document-to-Markdown conversion (PDF, DOCX, PPTX, XLSX, HTML, CSV, JSON, XML, ZIP) |
| Integration | **Opt-in wrapper** — never vendored, never auto-installed |
| Source | https://github.com/microsoft/markitdown |
| PyPI | `markitdown[all]` |
| Installer | `pipx install "markitdown[all]"` (preferred) or `pip install --user "markitdown[all]"` |
| Kit ships | `scripts/install-markitdown.sh` + `scripts/install-markitdown.ps1` — thin wrappers |
| Update path | `opk markitdown install` (re-runs pipx/pip) |
| License | MIT (per upstream) |

The kit does **not** bundle MarkItDown. The wrapper scripts:

1. Verify `python3` is on PATH.
2. Detect available install tool (`pipx` preferred, `pip --user` fallback).
3. Print the planned `pipx install "markitdown[all]"` command.
4. Ask for confirmation (or accept `--yes` / `-Y`).
5. Forward to the official PyPI installer.
6. Run `markitdown --help` to verify installation.

### Safety guarantees

- **Never vendors** any MarkItDown source code.
- **Never installs** automatically — always requires explicit `opk markitdown install`.
- **Never runs** `sudo` or `curl|sh`.
- **Never installs** during `opk up`, bootstrap, or shell startup.
- **Never reads** `.env`, secrets, or sensitive files.
- **Never overwrites** output files without `--force`.

### Convert commands

| CLI | Description |
|-----|-------------|
| `opk md-convert <input> <output>` | Convert file to Markdown |
| `opk md-convert <input> <output> --force` | Convert and overwrite existing output |
| `opk doc-to-md <input> <output>` | Alias for `md-convert` |

### Agent command

`opencode-global/commands/doc-to-md.md` guides agents to use the `opk` wrapper.
Agents never install packages directly.

---

## 6. Supermemory — Opt-in Wrapper

| Field | Value |
|-------|-------|
| Role | Memory persistence across AI coding sessions |
| Integration | **Opt-in wrapper** — never vendored, never auto-installed |
| Source | https://github.com/supermemory/supermemory |
| Kit label | `opencode-supermemory` (internal integration name) |
| npm | `@supermemory/ai` |
| Installer | `npm install -g @supermemory/ai` |
| Kit ships | `scripts/install-supermemory.sh` + `scripts/install-supermemory.ps1` — thin wrappers |
| Update path | `opk supermemory install` (re-runs npm global install) |
| License | Apache-2.0 (per upstream) |

The kit does **not** bundle Supermemory. The wrapper scripts:

1. Verify `node` and `npm` are on PATH.
2. Print the planned `npm install -g @supermemory/ai` command.
3. Ask for confirmation (or accept `--yes` / `-Y`).
4. Forward to the official npm installer.
5. Run `supermemory --help` to verify installation.

### Safety guarantees

- **Never vendors** any Supermemory source code.
- **Never installs** automatically — always requires explicit `opk supermemory install`.
- **Never runs** `sudo` or `curl|sh`.
- **Never installs** during `opk up`, bootstrap, or shell startup.
- **Never reads** `.env`, secrets, or sensitive files.

### Supermemory commands

| CLI | Description |
|-----|-------------|
| `opk supermemory install` | Install Supermemory CLI via npm |
| `opk supermemory status` | Check installation status |
| `opk supermemory init` | Initialize Supermemory in current project |

### Agent command

`opencode-global/commands/supermemory-init.md` guides agents to use the `opk` wrapper.
Agents never install packages directly.

---

## 7. Detect-only Tools

The following tools are **never vendored, never auto-installed, and never
auto-updated**. The `/tooling-doctor` command detects whether they are
present on PATH and prints install hints if missing. The kit never runs
`cargo install`, `npm i -g`, `pip install`, `brew install`, `go install`,
or any package manager on the user's behalf.

| Tool | Purpose | Detection via | Kit action |
|------|---------|:------------:|:----------:|
| rtk | Token-saving shell wrapper | `/tooling-doctor` | detect, suggest install command |
| tokscale | Token cost visualization | `/tooling-doctor` | detect, suggest install command |
| repomix | Context pack generator | `/tooling-doctor`, `/token-pack` | detect, call if installed |
| ast-grep | Structural code search | `/tooling-doctor` | detect, suggest install command |
| ripgrep (rg) | Fast regex text search | `/tooling-doctor` | detect, suggest install command |
| fd | Fast file finder | `/tooling-doctor` | detect, suggest install command |
| knip | Dead file/dependency detection | `/tooling-doctor`, `/js-quality-check` | detect, call if installed |
| gitleaks | Git secret scanning | `/tooling-doctor`, `/secret-scan` | detect, call if installed |
| trufflehog | Secret scanning | `/tooling-doctor`, `/secret-scan` | detect, call if installed |
| semgrep | SAST / static analysis | `/tooling-doctor`, `/sast-check` | detect, call if installed |
| spectral | OpenAPI lint | `/tooling-doctor`, `/openapi-check` | detect, call if installed |
| oasdiff | OpenAPI diff | `/tooling-doctor`, `/openapi-check` | detect, call if installed |
| Playwright | E2E browser testing | `/tooling-doctor`, `/e2e-flow` | detect, call `npx playwright` if installed |
| Biome | JS/TS lint + format | `/tooling-doctor`, `/js-quality-check` | detect, call if installed; config reference in templates |

The `/e2e-flow` command may call `npx playwright test` if Playwright is
present, but it never installs Playwright itself. Similarly,
`/js-quality-check` may call `knip` / `biome` / `eslint` / `prettier` /
`vitest` / `tsc` if those tools are installed.

---

## 8. Recommended Ecosystem (Target Stack)

The full-stack profile recommends the following stack. These are **not**
bundled or vendored — they are the target technologies that the profile's
scaffolding, agents, and commands are designed for.

| Technology | Role | Kit scope |
|-----------|------|-----------|
| Node.js | JavaScript runtime | Scripts verify `node` is on PATH |
| npm / npx | Package manager | Installers require `npx` for BMAD / GSD |
| NestJS | Backend framework | Profile commands, agents, skills |
| React + Vite | Frontend framework | Profile commands, agents, skills |
| MySQL | Database | Profile commands, schema patterns |
| Docker / Docker Compose | Containerization | `/docker-dev-doctor`, templates |
| JWT + RBAC | Auth pattern | Skill: `auth-rbac-review` |

---

## 9. Update Policy

### Install-time dependencies (BMAD Method)

- `bash update-bmad.sh` / `opk update-bmad` — re-runs `npx bmad-method@<version> install`.
- `BMAD_METHOD_VERSION` env overrides the default version pin.
- Full log captured to `.opencode-power-bmad-install.log`.

### Opt-in tools (GSD Core, MarkItDown, Supermemory)

- `opk gsd` / `opk update-gsd` — calls `npx @opengsd/gsd-core@latest`.
- `opk update-all --with-gsd` — pulls kit + updates GSD.
- `opk markitdown install` — re-runs `pipx install "markitdown[all]"`.
- `opk supermemory install` — re-runs `npm install -g @supermemory/ai`.
- No auto-update, no background refresh.

### Plugin references (Superpowers)

- Superpowers is loaded by OpenCode at startup via the plugin directive.
- To update Superpowers, update OpenCode or follow Superpowers' own docs.
- The kit does not manage Superpowers updates.

### Detect-only tools

- User updates each tool with their own package manager.
- `/tooling-doctor` only reports present/missing status.
- Kit never installs or updates detect-only tools.

### Kit itself

- `git pull --ff-only` (or re-clone) to get latest kit release.
- Each release may update version pins for BMAD and bundled templates.
- See `CHANGELOG.md` for what changed.

---

## 10. License Notes

- **opencode-power-kit**: [MIT](./LICENSE)
- **OpenCode**: MIT
- **BMAD Method**: MIT
- **Superpowers**: MIT
- **GSD Core**: See npm package page
- **MarkItDown**: MIT
- **Supermemory**: Apache-2.0
- **rtk**: MIT
- **repomix**: MIT
- **ast-grep**: MIT
- **ripgrep**: MIT / Unlicense
- **fd**: Apache-2.0 / MIT
- **knip**: MIT
- **gitleaks**: MIT
- **trufflehog**: AGPL-3.0
- **semgrep**: LGPL-2.1
- **spectral**: Apache-2.0
- **oasdiff**: Apache-2.0
- **Playwright**: Apache-2.0
- **Biome**: Apache-2.0 / MIT

> **Note:** License information is based on what we could verify at release
> time. Always check the upstream project's license file before
> redistributing. Some detect-only tools may change their license — verify
> independently.

---

*This file is maintained as part of opencode-power-kit and should be updated
whenever a new third-party integration is added or an existing one changes
its integration mode.*

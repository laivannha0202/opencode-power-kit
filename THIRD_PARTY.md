# Third-Party Components & Credits

> **Version:** opencode-power-kit v2.0.0
>
> This project packages, configures, and documents workflows around
> [OpenCode](https://github.com/opencode-ai). It credits upstream authors
> clearly and does **not** claim ownership of upstream projects.
>
> **Upstream audit:** See `docs/UPSTREAM_AUDIT.md` for the full dependency
> matrix, risk levels, and update policy. See `docs/UPSTREAM_RISKS.md` for
> risk analysis. See `docs/UPSTREAM_UPDATE_POLICY.md` for update procedures.

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
| **Verify-gated dependency** | Cài khi user yêu cầu explicit, dùng official installer | Via npx | Via opk update-* | Taste Skill |
| **Config-only reference** | Kit chỉ ship template config trỏ đến upstream | No | No | Biome config |
| **Opt-in wrapper** | Chỉ gọi installer chính thức khi user yêu cầu | No | No | GSD Core, MarkItDown, ECC-lite |
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
| Taste Skill | Leonxlnx | https://github.com/Leonxlnx/taste-skill | AI-augmented UI/UX design (image-to-code, redesign, polish, brand kit) | Verify-gated dependency | `opk taste install` (user-initiated, npx) | MIT |
| ECC | affaan-m | https://github.com/affaan-m/ECC | Engineering Code Commandments — coding standards, security, engineering rigor | Opt-in wrapper | `opk ecc lite` (kit-native); `opk ecc audit` (read-only clone) | MIT |
| Hermes Agent | NousResearch | https://github.com/NousResearch/hermes-agent | Meta-cognitive self-improvement — learning loop, skill improvement, memory review, kanban, tool audit | Inspiration-only | `opk hermes status` (local); `git pull` refreshes OPK source | Apache-2.0 |
| NirDiamant/RAG_Techniques | NirDiamant | https://github.com/NirDiamant/RAG_Techniques | Comprehensive RAG tutorial collection — reference for conceptual guidance only | Reference / Learning resource | N/A — no code, no auto-update | Custom (non-commercial) |
| chopratejas/headroom | chopratejas | https://github.com/chopratejas/headroom | Context/token compression Linux daemon — reference for context window economics, compression strategies, token budget optimization | Inspiration-only / Reference | N/A — no code, no auto-update | Apache-2.0 |
| rohitg00/agentmemory | rohitg00 | https://github.com/rohitg00/agentmemory | Serverless memory layer for AI agents — reference for memory strategies, context handoff, state persistence, TTL-based memory management | Inspiration-only / Reference | N/A — no code, no auto-update | Apache-2.0 |
| oh-my-openagent | code-yeongyu | https://github.com/code-yeongyu/oh-my-openagent | Multi-agent orchestration — IntentGate, ultrawork, Prometheus/Atlas, evidence trail | Inspiration-only (concepts) | N/A — no code, no vendor, no dependency | MIT |
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
| Version pin | `BMAD_METHOD_VERSION` env (default: 6.9.0) in `install.sh`, `install.ps1`, `update-bmad.sh`, `update-bmad.ps1` |
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
| Installer | `npx @opengsd/gsd-core@1.6.1` |
| Kit ships | `scripts/install-gsd-core.sh` + `scripts/install-gsd-core.ps1` — thin wrappers |
| Update path | `opk gsd` / `opk update-gsd` / `opk update-all --with-gsd` |
| License | See npm package page |

The kit does **not** bundle GSD Core. The wrapper scripts:

1. Verify `node`, `npm`, and `npx` are on PATH.
2. Print the planned `npx @opengsd/gsd-core@1.6.1` command.
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
| npm | `supermemory` (migrated from `@supermemory/ai` which is deprecated) |
| Installer | `npm install -g supermemory` |
| Kit ships | `scripts/install-supermemory.sh` + `scripts/install-supermemory.ps1` — thin wrappers |
| Update path | `opk supermemory install` (re-runs npm global install) |
| License | Apache-2.0 (per upstream) |
| Migration | `@supermemory/ai` → `supermemory` (2026-07-03). Deprecated package reference only in migration comments. |

The kit does **not** bundle Supermemory. The wrapper scripts:

1. Verify `node` and `npm` are on PATH.
2. Print the planned `npm install -g supermemory` command.
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

## 7. Taste Skill — Verify-gated Dependency

| Field | Value |
|-------|-------|
| Role | AI-augmented UI/UX design — image-to-code, redesign, polish, brand kit, landing page, mobile UI optimization |
| Integration | **Verify-gated dependency** — user-installed via `opk taste install`. No auto-install. Optional. |
| Source | https://github.com/Leonxlnx/taste-skill |
| Installer | `npx taste-skill` (official npx package) |
| Kit ships | `scripts/install-taste-skill.sh` + `scripts/install-taste-skill.ps1` — installers |
| | `scripts/check-taste-skill.sh` + `scripts/check-taste-skill.ps1` — read-only detection |
| Update path | `opk update-taste` (re-runs npx) |
| License | MIT (per upstream) |

The kit integrates Taste Skill as a **verify-gated** optional dependency. Unlike
auto-enabled tools (legacy v1.7.0), Taste Skill is only installed when the user
explicitly runs `opk taste install`. This ensures no unexpected network calls or
package installations during global setup.

### Install behavior

| Trigger | Install? | Skip if missing? |
|---------|:--------:|:----------------:|
| `opk global` / `opk one` / `opk go` | ❌ No (user runs `opk taste install` separately) | N/A |
| `opk taste install` | ✅ Yes | Verify node/npx before install |
| `opk taste install --v1` | ✅ Yes (legacy) | Verify node/npx before install |
| `opk taste install --v2` | ✅ Yes (default) | Verify node/npx before install |
| `opk up` (update) | ❌ No | N/A |
| Shell startup | ❌ No | N/A |

### Safety guarantees

- **Never vendors** any Taste Skill source code.
- **No sudo** — prefers `npx`, never uses `sudo npm`.
- **No curl|sh** — installer is a bash/PowerShell script in the kit.
- **No .env/secrets modification** — Taste Skill reads no sensitive files.
- **No core install failure** — missing deps produce a warning only.
- **`OPK_SKIP_TASTE=1`** — legacy escape hatch (no longer needed since global scripts no longer auto-install Taste).
- **Fail soft** — if `npx` fails, install continues without error.

### Taste Skill commands

| CLI | Description |
|-----|-------------|
| `opk taste install` | Install Taste Skill via npx |
| `opk taste status` / `opk taste-status` | Check installation status |
| `opk taste off` / `opk taste-off` | Remove Taste Skill |
| `opk update-taste` | Refresh Taste Skill installation |
| `OPK_SKIP_TASTE=1` | Legacy env var (no longer needed for global setup) |

### Slash commands

| Slash command | Description |
|:-------------:|-------------|
| `/taste-polish` | UI polish & refinement |
| `/redesign-ui` | Redesign existing UI |
| `/image-to-code` | Convert design image to code |
| `/brandkit` | Brand kit generation |
| `/mobile-ui` | Mobile UI optimization |
| `/landing-ui` | Landing page UI |
| `/ui-final-pass` | Final UI quality pass |

### Agent routing

- `opencode-global/agents/taste-ui-strong.md` — AI-augmented UI/UX designer agent
- `opencode-global/agents/build-strong.md` — Agent Delegation table routes to taste-ui-strong
- `opencode-global/commands/agent-router.md` — Routing table routes UI design tasks

Agents never install packages directly. All installs go through `opk` wrappers.

---

## 8. ECC (Engineering Code Commandments) — Opt-in Wrapper

| Field | Value |
|-------|-------|
| Role | Engineering discipline framework — coding standards, security, engineering rigor |
| Integration | **Opt-in wrapper** — never vendored, never auto-installed, never enabled by default |
| Source | https://github.com/affaan-m/ECC |
| License | MIT (per upstream) |
| Kit ships | `scripts/audit-ecc.sh`, `scripts/install-ecc-lite.sh`, `scripts/check-ecc-lite.sh` — OPK-native scripts |
| | `opencode-global/agents/ecc-lite-strong.md` — ECC-lite agent (6 core principles) |
| | `opencode-global/commands/ecc-audit.md`, `quality-gate.md`, `research-first.md`, `verify-loop.md`, `backend-route-review.md`, `harness-audit.md` — 6 commands |
| | `bin/opk` / `bin/opk.ps1` — CLI subcommands: `ec`, `e`, `ecc`, `update-ecc` |
| Update path | `opk update-ecc` (re-sources from OPK repo, not from ECC upstream) |

ECC-lite is **not** full ECC. It ships only OPK-native components:

- **6 core principles** embedded in `ecc-lite-strong.md` agent
- **6 slash commands** for key workflows (audit, quality gate, research-first,
  verify loop, model route review, harness audit)
- **3 helper scripts** for audit, install, and status check

Full ECC (260+ skills, 80+ commands, hooks, MCP, memory) is never installed
by the kit. The `audit-ecc.sh` script performs a read-only audit by cloning
ECC to `.tmp/`, analyzing the codebase, generating `docs/ECC_AUDIT.md`, and
cleaning up — no global config changes, no full asset copy.

### ECC-lite commands

| CLI | Description |
|-----|-------------|
| `opk ecc audit` | Audit codebase against ECC principles (read-only) |
| `opk ecc lite` | Install ECC-lite agent + commands |
| `opk ecc status` | Check ECC-lite installation status |
| `opk ecc off` | Remove ECC-lite |
| `opk update-ecc` | Refresh ECC-lite installation |

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, `bootstrap`, `setup`,
  or `opk up`.
- **No vendor source** — ECC source never copied into OPK repo.
- **No hooks** — no git hooks, OpenCode hooks, or commit hooks.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — ECC-lite never reads sensitive files.
- **No network in status check** — `check-ecc-lite.sh` only checks local files.
- **No sudo** — all operations user-scoped (`~/.config/opencode/`).
- **Read-only audit** — `audit-ecc.sh` clones to `.tmp/`, audits, then cleans up.

### Agent routing

- `opencode-global/agents/ecc-lite-strong.md` — dedicated subagent for ECC-lite
- 6 slash commands route to ecc-lite-strong for execution
- Agents never install packages directly

---

## 8.5. Hermes Agent — Inspiration-only (Meta-Cognitive Self-Improvement)

| Field | Value |
|-------|-------|
| Role | Meta-cognitive self-improvement framework — learning loop, skill improvement, memory policy review, context/budget pressure, lightweight kanban, tool surface audit, remote backend review |
| Integration | **Inspiration-only** — never vendored, never auto-installed, never enabled by default. Hermes concepts are adapted to OPK-native components, not copied from upstream |
| Source | https://github.com/NousResearch/hermes-agent |
| Documentation | https://docs.hermes-agent.nousresearch.com (Self-Evolution section) |
| License | Apache-2.0 (per upstream) |
| Kit ships | `scripts/audit-hermes.sh`, `scripts/check-hermes-lite.sh`, `scripts/hermes-learning-capsule.sh` — OPK-native scripts |
| | `opencode-global/agents/hermes-lite-strong.md` — Hermes-lite agent |
| | `opencode-global/commands/hermes-reflect.md`, `hermes-skill.md`, `hermes-kanban.md`, `hermes-memory.md`, `hermes-budget.md`, `hermes-audit.md`, `hermes-learn.md`, `hermes-research.md` — 8 commands |
| | `bin/opk` / `bin/opk.ps1` — CLI subcommands: `hermes` |
| | `docs/HERMES_INTEGRATION.md`, `docs/HERMES_AUDIT.md`, `docs/LEARNING_LOOP.md`, `docs/AGENT_KANBAN.md` — 4 docs |
| Update path | `opk hermes status` checks local files; `git pull` refreshes from OPK repo |

Hermes-lite is **not** full Hermes Agent. It ships only OPK-native components:

- **8 concepts** from Hermes Agent adapted to OPK: reflection, skill improvement,
  lightweight kanban, memory policy review, context/budget pressure, tool
  surface audit, learning capture, remote backend research.
- **1 agent** (`hermes-lite-strong.md`) with mode: all for meta-cognitive workflows.
- **8 slash commands** for key workflows.
- **3 scripts** for audit, status, and learning capsule.
- **4 documentation files** covering architecture, audit, learning loop, kanban.

Full Hermes Agent (gateway, Telegram/Discord/Slack, cron, scheduler, memory
system, self-evolution engine) is never installed by the kit.

### Hermes-lite commands

| CLI | Description |
|-----|-------------|
| `opk hermes audit` | Self-audit Hermes-lite components (read-only) |
| `opk hermes status` | Check Hermes-lite installation status (no network) |
| `opk hermes capsule` | Package learnings into `.hermes/learnings/*.md` capsule |
| `opk hermes off` | Remove Hermes-lite from `~/.config/opencode/` |

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, `bootstrap`, `setup`,
  or `opk up`.
- **No vendor source** — Hermes Agent source never copied into OPK repo.
- **No gateway** — no Telegram, Discord, Slack, or webhook integrations.
- **No scheduler/cron** — no background processes, no daemons, no periodic jobs.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — Hermes-lite never reads sensitive files.
- **No network in status check** — `check-hermes-lite.sh` only checks local files.
- **No sudo** — all operations user-scoped (`~/.config/opencode/`).
- **Read-only audit** — `audit-hermes.sh` only reads local files.
- **No memory system** — no persistent memory store, no vector DB, no embedding.

### Agent routing

- `opencode-global/agents/hermes-lite-strong.md` — dedicated subagent for
  meta-cognitive self-improvement workflows
- 8 slash commands route to hermes-lite-strong for execution
- Agents never install packages directly

---

## 8.8. NirDiamant/RAG_Techniques — Reference / Learning Resource

| Field | Value |
|-------|-------|
| Role | Comprehensive RAG tutorial collection — conceptual reference for RAG patterns, techniques, and best practices |
| Integration | **Reference / Learning resource** — never vendored, never auto-installed, never enabled by default. OPK ships only conceptual docs, skill, and slash commands — no source, no notebooks, no significant text from upstream |
| Source | https://github.com/NirDiamant/RAG_Techniques |
| License | Custom (non-commercial) — upstream restricts commercial use, redistribution, and derivative works |
| Kit ships | `docs/RAG_LITE_INTEGRATION.md` — conceptual reference, architecture, component table, workflow, checklist, license-safe design rationale |
| | `opencode-global/skills/rag-lite/SKILL.md` — agent skill for RAG workflow |
| | `opencode-global/commands/rag-plan.md`, `rag-audit.md`, `rag-eval.md` — 3 slash commands |
| Update path | `git pull` refreshes from OPK repo. No upstream update mechanism — all content is OPK-original conceptual guidance. |

### License-safe design

RAG-lite is designed to avoid license conflict with upstream:

1. **No source code** from NirDiamant/RAG_Techniques is shipped.
2. **No notebook files** (`.ipynb`) are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general RAG
   knowledge, not derived from any single upstream.
5. **Credit is given** in this document and `docs/RAG_LITE_INTEGRATION.md`.
6. **Links to upstream** are provided for users who want full details.

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, `bootstrap`,
  `setup`, or `opk up`.
- **No vendor source** — upstream source never copied into OPK repo.
- **No runtime code** — all content is markdown docs + skill + commands.
- **No dependency** — no npm, pip, cargo, or any package manager.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — RAG-lite never reads sensitive files.
- **No network** — all checks are local.
- **No sudo** — all operations are user-scoped.

### Agent routing

- `opencode-global/skills/rag-lite/SKILL.md` — skill loaded when task
  involves RAG, retrieval, vector search, embedding, chunking
- `/rag-plan`, `/rag-audit`, `/rag-eval` — 3 slash commands
- `opencode-global/agents/build-strong.md` — Agent Delegation table
  routes RAG tasks to rag-lite skill
- `opencode-global/commands/agent-router.md` — Routing table includes
  RAG entries
- Agents never install packages directly

---

## 8.9. chopratejas/headroom — Inspiration-only / Reference (Context/Token Compression)

| Field | Value |
|-------|-------|
| Role | Context/token compression Linux daemon — reference for context window economics, compression strategies, token budget optimization |
| Integration | **Inspiration-only / Reference** — never vendored, never auto-installed, never enabled by default. OPK ships only conceptual docs, skill, and slash commands — no source code, no binaries, no significant text from upstream |
| Source | https://github.com/chopratejas/headroom |
| License | Apache-2.0 (per upstream) |
| Kit ships | `docs/HEADROOM_LITE_INTEGRATION.md` — conceptual reference, compression strategies, workflow, agent guidance, license-safe design rationale |
| | `opencode-global/skills/headroom-lite/SKILL.md` — agent skill for context compression workflow |
| | `opencode-global/commands/headroom-plan.md`, `headroom-audit.md`, `headroom-status.md` — 3 slash commands |
| Update path | `git pull` refreshes from OPK repo. No upstream update mechanism — all content is OPK-original conceptual guidance. |

### License-safe design

Headroom-lite is designed to avoid license conflict with upstream:

1. **No source code** from chopratejas/headroom is shipped.
2. **No binaries or daemon config** are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general
   context window / token budget knowledge, not derived from any single
   upstream.
5. **Credit is given** in this document and `docs/HEADROOM_LITE_INTEGRATION.md`.
6. **Links to upstream** are provided for users who want full details.

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, `bootstrap`,
  `setup`, or `opk up`.
- **No vendor source** — upstream source never copied into OPK repo.
- **No runtime code** — all content is markdown docs + skill + commands.
- **No dependency** — no npm, pip, cargo, or any package manager.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — Headroom-lite never reads sensitive files.
- **No network** — all checks are local.
- **No sudo** — all operations are user-scoped.
- **No proxy/daemon** — Headroom-lite is a reference workflow, not a
  runtime service.

### Agent routing

- `opencode-global/skills/headroom-lite/SKILL.md` — skill loaded when
  task involves context compression, token budget, output truncation,
  RAG chunk compression, tool output reduction
- `/headroom-plan`, `/headroom-audit`, `/headroom-status` — 3 slash commands
- `opencode-global/agents/build-strong.md` — Agent Delegation table
  routes context/token compression tasks to headroom-lite skill
- `opencode-global/commands/agent-router.md` — Routing table includes
  Headroom-lite entries
- Agents never install packages or vendored code directly

---

## 8.10. rohitg00/agentmemory — Inspiration-only / Reference (Serverless Memory)

| Field | Value |
|-------|-------|
| Role | Serverless memory layer for AI agents — reference for memory strategies, context handoff, state persistence, TTL-based memory management |
| Integration | **Inspiration-only / Reference** — never vendored, never auto-installed, never enabled by default. OPK ships only conceptual docs, skill, and slash commands — no source code, no binaries, no significant text from upstream |
| Source | https://github.com/rohitg00/agentmemory |
| License | Apache-2.0 (per upstream) |
| Kit ships | `docs/AGENTMEMORY_LITE_INTEGRATION.md` — conceptual reference, memory strategies, safe handoff protocol, checklist, license-safe design rationale |
| | `opencode-global/skills/agentmemory-lite/SKILL.md` — agent skill for memory planning, audit, handoff workflows |
| | `opencode-global/commands/memory-plan.md`, `memory-audit.md`, `memory-handoff.md` — 3 slash commands |
| Update path | `git pull` refreshes from OPK repo. No upstream update mechanism — all content is OPK-original conceptual guidance. |

### License-safe design

AgentMemory-lite is designed to avoid license conflict with upstream:

1. **No source code** from rohitg00/agentmemory is shipped.
2. **No plugins, MCP servers, or hooks** from upstream are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general
   memory layer / state persistence / handoff knowledge, not derived from
   any single upstream.
5. **Credit is given** in this document and `docs/AGENTMEMORY_LITE_INTEGRATION.md`.
6. **Links to upstream** are provided for users who want full details.

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, `bootstrap`,
  `setup`, or `opk up`.
- **No vendor source** — upstream source never copied into OPK repo.
- **No runtime code** — all content is markdown docs + skill + commands.
- **No dependency** — no npm, pip, cargo, or any package manager.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — AgentMemory-lite never reads sensitive files.
- **No network** — all checks are local.
- **No sudo** — all operations are user-scoped.
- **No proxy/daemon** — AgentMemory-lite is a reference workflow, not a
  runtime service.

### Agent routing

- `opencode-global/skills/agentmemory-lite/SKILL.md` — skill loaded when
  task involves memory planning, state persistence, multi-session handoff,
  context checkpoint
- `/memory-plan`, `/memory-audit`, `/memory-handoff` — 3 slash commands
- `opencode-global/agents/build-strong.md` — Agent Delegation table
  routes memory tasks to agentmemory-lite skill
- `opencode-global/commands/agent-router.md` — Routing table includes
  AgentMemory-lite entries
- Agents never install packages or vendored code directly

---

## 8.11. code-yeongyu/oh-my-openagent — Inspiration-only (Orchestration Concepts)

| Field | Value |
|-------|-------|
| Role | Multi-agent orchestration framework — reference for orchestration concepts: IntentGate, ultrawork/ulw-loop, Prometheus/Atlas planning/execution split, evidence trail, deep doctor |
| Integration | **Inspiration-only (concepts)** — never vendored, never auto-installed, never enabled by default. OPK ships only conceptual docs and OPK-native commands inspired by orchestration patterns — no source code, no binaries, no plugins, no MCP from upstream |
| Source | https://github.com/code-yeongyu/oh-my-openagent |
| License | MIT (per upstream) |
| Kit ships | `docs/OPK_ORCHESTRATION_LITE.md` — OPK Orchestration Lite architecture, comparison table, safety guarantees |
| | `docs/INSPIRATION_OH_MY_OPENAGENT.md` — detailed inspiration notes, what OPK tham khảo vs KHÔNG tham khảo |
| | `opencode-global/commands/intent-router.md` — intent classification (inspired by IntentGate) |
| | `opencode-global/commands/power-work-lite.md` — long work workflow (inspired by ultrawork) |
| | `opencode-global/commands/continue-work.md` — work continuation (inspired by evidence trail) |
| | `opencode-global/commands/evidence-report.md` — evidence reporting |
| | `opencode-global/commands/init-deep-lite.md` — project context initialization |
| Update path | `git pull` refreshes from OPK repo. No upstream update mechanism — all content is OPK-original. |

### What OPK tham khảo (inspired by)

1. **Intent routing** — classify request before dispatch (from IntentGate)
2. **Long work loop** — iterate until verify passes (from ultrawork)
3. **Planning vs execution split** — plan first, then build (from Prometheus/Atlas)
4. **Evidence trail** — persist state across sessions (from work continuation)
5. **Deep doctor** — extended system checks (from doctor system)

### What OPK KHÔNG tham khảo

1. Multi-model routing — OPK uses single model
2. MCP integration — OPK keeps no MCP by default
3. Gateway/server — OPK is local-first
4. Team Mode/background agents — OPK uses single agent
5. Telegram/Discord/Slack — no external integrations
6. Telemetry — OPK has no usage tracking

### License-safe design

oh-my-openagent-lite is designed to avoid license conflict with upstream:

1. **No source code** from code-yeongyu/oh-my-openagent is shipped.
2. **No plugins, MCP servers, or hooks** from upstream are shipped.
3. **No significant text** is copied from upstream documentation.
4. **All content** is OPK-original — written from general orchestration knowledge.
5. **Credit is given** in this document and `docs/INSPIRATION_OH_MY_OPENAGENT.md`.

### Safety guarantees

- **No auto-enable** — never installed during any OPK command.
- **No vendor source** — upstream source never copied into OPK repo.
- **No runtime code** — all content is markdown docs + OPK-native commands.
- **No dependency** — no npm, pip, cargo, or any package manager.
- **No MCP** — no MCP servers or configs.
- **No telemetry** — no usage tracking or analytics.
- **No env/secrets** — orchestration commands never read sensitive files.
- **No network** — all operations are local.
- **No sudo** — all operations are user-scoped.

---

## 9. Detect-only Tools

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

## 10. Recommended Ecosystem (Target Stack)

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

## 11. Update Policy

### Install-time dependencies (BMAD Method)

- `bash update-bmad.sh` / `opk update-bmad` — re-runs `npx bmad-method@<version> install`.
- `BMAD_METHOD_VERSION` env overrides the default version pin.
- Full log captured to `.opencode-power-bmad-install.log`.

### Reference / Learning resources (RAG-lite, Headroom-lite)

- RAG-lite and Headroom-lite are entirely OPK-native — no upstream code,
  no install, no update.
- `git pull` refreshes docs, skills, and commands from OPK repo.
- Upstream (NirDiamant/RAG_Techniques, chopratejas/headroom) is referenced
  only; never vendored.

### Opt-in tools (GSD Core, MarkItDown, Supermemory, ECC-lite, Hermes-lite)

- `opk gsd` / `opk update-gsd` — calls `npx @opengsd/gsd-core@1.6.1`.
- `opk update-all --with-gsd` — pulls kit + updates GSD.
- `opk markitdown install` — re-runs `pipx install "markitdown[all]"`.
- `opk supermemory install` — re-runs `npm install -g supermemory`.
- `opk ecc lite` — installs ECC-lite agent + commands (OPK-native, not full ECC).
- `opk update-ecc` — refreshes ECC-lite from OPK repo.
- `opk ecc audit` — read-only audit against ECC principles (clone to .tmp/).
- `opk hermes status` — checks Hermes-lite installation (local files only).
- `opk hermes audit` — read-only self-audit of Hermes-lite components.
- `opk hermes capsule` — package learnings into capsule file.
- No auto-update, no background refresh.

### Verify-gated dependencies (Taste Skill)

- `opk taste install` — user-installed, not auto-installed.
- `opk taste install --v1` — install v1 (legacy).
- `opk taste install --v2` — install v2 (default).
- `opk taste doctor` — check runtime dependencies.
- `opk taste off` — safe removal (moves to `.opk-trash/`).
- `OPK_SKIP_TASTE=1` — legacy env var (no longer needed since global scripts no longer auto-install Taste).
- Graceful degradation if node/npx/network missing.

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

## 12. License Notes

- **opencode-power-kit**: [MIT](./LICENSE)
- **OpenCode**: MIT
- **BMAD Method**: MIT
- **Superpowers**: MIT
- **GSD Core**: See npm package page
- **MarkItDown**: MIT
- **Supermemory**: Apache-2.0
- **Taste Skill**: MIT
- **ECC**: MIT
- **Hermes Agent**: Apache-2.0
- **NirDiamant/RAG_Techniques**: Custom (non-commercial) — OPK references only, no source/notebook/text copied
- **chopratejas/headroom**: Apache-2.0 — OPK references only, no source/binary/text copied
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

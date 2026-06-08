# OpenCode Power Kit

[![CI](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.5.0-blue.svg)](./VERSION)
[![BMAD Method](https://img.shields.io/badge/BMAD%20Method-v6.8.0-blue.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![No MCP](https://img.shields.io/badge/policy-no%20MCP-orange.svg)](#safety-model)
[![Safe / No secrets](https://img.shields.io/badge/policy-safe%20%2F%20no--secrets-success.svg)](#safety-model)
[![Cross-platform](https://img.shields.io/badge/cross--platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](#quick-start)

> Reusable OpenCode full-stack power kit: agents, commands, skills, safety workflows, full-stack profile, release tooling.

> **Note:** Các section bên dưới ghi lại lịch sử phiên bản (version history) của kit. GitHub Releases thật được publish riêng trên tab [Releases](https://github.com/laivannha0202/opencode-power-kit/releases) của repository — mỗi release bao gồm Git tag + release notes + tarball.

---

## Quick Start

### Linux / macOS / Git Bash / WSL

```bash
bash -c 'PROJECT="$PWD"; KIT="$HOME/opencode-power-kit"; if [ -d "$KIT/.git" ]; then git -C "$KIT" pull --ff-only; else git clone https://github.com/laivannha0202/opencode-power-kit.git "$KIT"; fi; bash "$KIT/bootstrap.sh" --all --project-dir "$PROJECT"; cd "$PROJECT"; bash "$KIT/verify.sh"; echo "Done. Run: opencode"'
```

Then reload and verify:
```bash
source ~/.bashrc    # or source ~/.zshrc
opk one             # re-run all-in-one anytime
opk doctor          # check everything
opencode
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -Command "$Project=(Get-Location).Path; $KIT=Join-Path $HOME 'opencode-power-kit'; if (Test-Path (Join-Path $KIT '.git')) { & git -C $KIT pull --ff-only } else { & git clone https://github.com/laivannha0202/opencode-power-kit.git $KIT }; & (Join-Path $KIT 'bootstrap.ps1') -All -ProjectDir $Project -Yes; & (Join-Path $KIT 'verify.ps1'); Write-Host 'Done. Run: opencode'"
```

Open a **new PowerShell** window, then:
```powershell
opk one
opk.cmd path
opencode
```

### After installation

| Command | Purpose |
|---------|---------|
| `opk one` / `opk go` | All-in-one: global + project + fullstack + verify |
| `opk help` | Show full help |
| `opk version` | Show version |
| `opk doctor` | Read-only diagnostic |
| `opk verify` | Verify current project is ready |
| `opk global` | Install global (agents/commands/skills) |
| `opk install` | Install into current project |
| `opk fullstack` | Install full-stack profile (Node/Nest/React/MySQL) |

---

## What's Included

| Component | Count | Location |
|-----------|-------|----------|
| Core agents | 13 | `opencode-global/agents/` |
| Slash commands | 34 | `opencode-global/commands/` |
| Skills | 20 | `opencode-global/skills/` |
| Scripts | 12 | `scripts/` |
| Full-stack profile | 1 | `profiles/node-nest-react-mysql/` |
| Safety scripts | 4 | `verify.sh`, `doctor.sh`, `cleanup-agent-artifacts.sh`, `opk-command-guard.sh` |
| Install/Boostrap | 8+ | `bootstrap.*`, `setup.*`, `install*.*` |
| CLI wrappers | 3 | `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1` |

---

## Power Mode v1.5.0

- **13 core agents** — each specialized for one domain (architecture, debug, QA, security, DB, API, UI/UX, DevOps, release, plus fullstack autopilot, 3 lite agents)
- **34 commands** — organized into power workflow, safety, build lifecycle, review, DB/API, QA/E2E, DevOps, quality/security, token/tooling
- **`scripts/opk-command-guard.sh`** — safety guard: warns/blocks dangerous shell commands (`rm -rf`, `git reset --hard`, force push, `DROP TABLE`, ...)
- **`build-strong` Agent Delegation** — automatically spawns specialized subagents based on context
- **`/power-build`** — end-to-end workflow: spec → architecture → implementation → QA → security → release
- **`/agent-router`** — natural language task routing to the right agent
- **`/tooling-doctor`** — detect third-party tooling (rtk, repomix, semgrep, gitleaks, ...)
- **100% backward compatible** — everything from previous versions works unchanged

---

## Agent Reference

### Core Power Agents

| Agent | Type | Purpose | Use when |
|-------|------|---------|----------|
| `build-strong` | Fullstack | Full-stack autopilot: spec → plan → build slice → verify | Main full-stack feature work |
| `architect-strong` | Architecture | System design, ADR, cross-module decisions | Task > 5 files, cross-module changes |
| `debug-strong` | Debug | Scientific method debugging with checkpoint | Complex bugs, elusive root causes |
| `qa-strong` | QA/Testing | Coverage analysis, regression testing, test suite design | Pre-ship, need solid test suite |
| `security-strong` | Security | SAST, secret scan, threat model, dependency audit | Pre-release, code with auth/input |
| `db-strong` | Database | Schema design, migration safety, query optimization | Schema changes, migrations |
| `api-strong` | API | OpenAPI contract, FE/BE sync, type generation | Endpoint changes, API contract sync |
| `ui-ux-strong` | UI/UX | Accessibility, responsive design, visual review | Interface review, responsive fixes |
| `devops-strong` | DevOps | Docker, CI/CD, deploy, infrastructure | Setup/review infrastructure |
| `release-strong` | Release | Version bump, CHANGELOG, tag, publish | Before release cut |
| `plan-lite` | Planning | Token-efficient planning | Small tasks needing quick plan |
| `review-lite` | Review | Token-efficient code/diff review | Quick code review |
| `debug-lite` | Debug | Token-efficient debugging | Simple bugs |

**Recommended workflow:**
```
/agent-router "add Google login feature"
# Or manually: @architect-strong → @db-strong → @build-strong → @qa-strong → @security-strong → @release-strong
```

---

## Command Reference

### Power Workflow

| Command | Purpose |
|---------|---------|
| `/agent-router` | Route task to the right specialized agent |
| `/power-build` | End-to-end build: spec → architecture → build → QA → security → release |
| `/tooling-doctor` | Detect third-party tooling availability |

### Safety

| Command | Purpose |
|---------|---------|
| `/cleanup-safe` | Safely move temp artifacts to `.opk-trash/` (default dry-run) |
| `/checkpoint` | Snapshot working tree before large changes |
| `/handoff-save` | Update `AI_HANDOFF.md` for context continuity |

### Build Lifecycle

| Command | Purpose |
|---------|---------|
| `/spec-lite` | Quick spec (goal, scope, AC, out-of-scope) |
| `/plan-work` | Break task into ≤ 7 steps with files + tests |
| `/build-slice` | Implement one slice, ≤ 2 files, ≤ 100 lines diff |
| `/ci-fix` | Read CI/test/build errors and fix safely |
| `/ship-check` | Pre-commit/pre-push checklist |

### Review

| Command | Purpose |
|---------|---------|
| `/review-diff` | Review git diff |
| `/security-review` | Security review (secrets, auth, input validation) |
| `/api-contract-review` | Check FE/BE API contract alignment |
| `/migration-safe` | Verify migration safety before running |
| `/release-check` | Check VERSION/README/CHANGELOG/tag before release |

### DB / API

| Command | Purpose |
|---------|---------|
| `/db-readonly` | Read-only DB checks |
| `/migration-safe` | Migration safety check |
| `/openapi-check` | OpenAPI spec validation (spectral/oasdiff) |
| `/secret-scan` | Secret pattern scan (gitleaks/trufflehog) |
| `/sast-check` | Static analysis (semgrep) |

### QA / E2E

| Command | Purpose |
|---------|---------|
| `/test-proof` | Run/propose tests as proof |
| `/test-matrix` | Generate test matrix (unit/integration/e2e/smoke) |
| `/e2e-flow` | Plan and run E2E proof with Playwright |
| `/e2e-plan` | Propose Playwright E2E flows |

### DevOps / Environment

| Command | Purpose |
|---------|---------|
| `/env-doctor` | Check env safety (no secret values printed) |
| `/docker-dev-doctor` | Check docker-compose dev setup |
| `/fullstack-scan` | Full-stack project scan (FE/BE/DB/scripts/env/docker) |

### Quality / Security

| Command | Purpose |
|---------|---------|
| `/js-quality-check` | Detect eslint/prettier/biome/knip/vitest/tsc |
| `/smart-scan` | Quick project health scan |
| `/kit-audit` | Audit opencode-power-kit structure |
| `/repo-map` | Generate project map |
| `/bugfix-safe` | Safe bug fix workflow |

### Token / Tooling

| Command | Purpose |
|---------|---------|
| `/rtk-gain` | Run `rtk gain` or guide installation |
| `/token-pack` | Pack context via Repomix |

---

## Skills Summary

| Category | Skills |
|----------|--------|
| Architecture / ADR | `adr-architecture-decision` |
| API Contract / OpenAPI | `api-contract`, `openapi-contract` |
| DB Migration | `database-migration-safe` |
| Docker / Environment | `docker-compose-safe`, `env-config-safe` |
| Frontend UI Review | `frontend-ui-review` |
| Full-stack Testing | `fullstack-test-strategy`, `test-strategy` |
| JS/TS Quality | `js-ts-project`, `js-ts-quality` |
| Security | `security-review`, `secure-fullstack` |
| Token / Repo Map | `rtk-token-optimizer`, `repo-map` |
| Safe Edit | `safe-edit` |
| Serena First | `serena-first` |
| Dependency | `dependency-maintenance` |
| Nest/React/MySQL | `nest-react-mysql` |

---

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**

```bash
# Linux / macOS / Git Bash / WSL
cd /path/to/your/project
opk one            # = opk go  = bootstrap.sh --all --project-dir "$(pwd)" --yes
# = [1/4] global + [2/4] project + [3/4] fullstack + [4/4] verify
```

```powershell
# Windows PowerShell
cd C:\path\to\your\project
opk one            # = opk go
```

> Bootstrap tự động: không sudo, không `curl|sh`, backup mọi file cũ, idempotent.

## Manual Install / Advanced

### Linux / macOS / Git Bash / WSL

```bash
git clone https://github.com/laivannha0202/opencode-power-kit.git ~/opencode-power-kit
bash ~/opencode-power-kit/setup.sh --global
source ~/.bashrc
opk help
opencode
```

### Windows PowerShell

```powershell
git clone https://github.com/laivannha0202/opencode-power-kit.git $HOME\opencode-power-kit
powershell -ExecutionPolicy Bypass -File "$HOME\opencode-power-kit\setup.ps1" -Global -Yes
# Open new PowerShell, then:
opk.cmd path
opencode
```

### After global install — use with any project

```bash
cd /path/to/your/project
opk install
opk fullstack   # optional
opk verify
```

## Project Structure

```
~/opencode-power-kit/
├── README.md
├── setup.sh / setup.ps1          # interactive + flags
├── bin/opk, opk.cmd, opk.ps1     # CLI wrappers
├── install.sh / install.ps1       # per-project
├── bootstrap.sh / bootstrap.ps1   # one-command installer
├── install-global.sh / .ps1       # global install
├── verify.sh / verify.ps1         # verification
├── doctor.sh / doctor.ps1         # diagnostics
├── uninstall.sh / uninstall.ps1   # removal
├── update-bmad.sh / .ps1          # BMAD update
├── scripts/                       # install helpers
├── opencode-global/               # agents, commands, skills
├── templates/                     # AGENTS.md, OPENCODE.md, configs
└── docs/                          # workflow, prompts, safety
```

## Commands

```bash
bash ~/opencode-power-kit/verify.sh
bash ~/opencode-power-kit/update-bmad.sh
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**

### Install

```bash
# After global install, from project directory:
opk fullstack
# Or:
bash ~/opencode-power-kit/scripts/install-fullstack-profile.sh
bash ~/opencode-power-kit/scripts/install-fullstack-profile.sh
```

Includes:
- 5 profile-specific commands: `api-e2e-flow`, `docker-dev-doctor`, `env-doctor`, `fullstack-scan`, `seed-data-safe`
- 5 profile-specific skills: `nestjs-backend`, `react-vite-frontend`, `mysql-schema-safe`, `auth-rbac-review`, `fullstack-test-strategy`
- 9 global full-stack commands: `fullstack-scan`, `openapi-check`, `secret-scan`, `sast-check`, `e2e-plan`, `test-matrix`, `js-quality-check`, `env-doctor`, `docker-dev-doctor`
- 8 global full-stack skills: `openapi-contract`, `secure-fullstack`, `dependency-maintenance`, `fullstack-test-strategy`, `js-ts-quality`, `env-config-safe`, `docker-compose-safe`, `nest-react-mysql`

Best for projects using: NestJS backend, React/Vite frontend, MySQL database, JWT + RBAC auth.

---

## Safety Model

| Rule | Description |
|------|-------------|
| No `rm -rf` | Never runs destructive file removal |
| No `git reset --hard` | Never destroys working tree |
| No `git clean -fd` | Never force-cleans untracked files |
| No force push | Never rewrites remote history |
| No .env/secrets | Never reads or exposes secret values |
| DB destructive ops require confirmation | `DROP TABLE`, `TRUNCATE`, `DELETE` without WHERE are blocked |
| Cleanup moves to `.opk-trash/` | Never deletes, always moves with timestamp |
| Checkpoint creates patch | `git diff` saved as `.patch` before large changes |
| No MCP bundled | All commands are local, no MCP servers shipped |
| No auto-update on shell start | All updates are explicit user commands |
| Backup before overwrite | Existing files are backed up before modification |

---

## Releases

| Version | Tag | Theme | Highlights |
|---------|-----|-------|------------|
| v1.5.0 | `v1.5.0` | Power Mode | 13 agents, 34 commands, safety guard, agent delegation, power-build |
| v1.4.0 | `v1.4.0` | Fullstack Autopilot | build-strong fullstack-autopilot, 12 hard rules |
| v1.3.4 | — | GSD Core Opt-in | GSD integration, update-all, verify.yml |
| v1.3.3 | `v1.3.3` | Safety Workflows | cleanup-safe, checkpoint, handoff-save, auto-router |
| v1.3.2 | `v1.3.2` | One-command All-in-one | opk one/go, 4-step flow, batch bootstrap |
| v1.3.1 | — | Hardening + CI | BMAD pin, full log capture, CI strict, shfmt |
| v1.3.0 | `v1.3.0` | Cross-platform | Windows PowerShell, bootstrap.ps1, opk.cmd |
| v1.2.0 | `v1.2.0` | opk CLI / Setup | setup.sh, opk CLI, install-global.sh |
| v1.1.0 | `v1.1.0` | Full-stack Profile | Node/Nest/React/MySQL profile |
| v1.0.0 | `v1.0.0` | Production Release | Initial production release |

Full release notes: [docs/RELEASES.md](./docs/RELEASES.md)

---

## Troubleshooting

- **GitHub Actions failing?** Verify your GitHub billing is active. The Actions runner may fail due to billing/policy issues unrelated to code quality.
- **Local verify passes but Actions fail?** Check billing status, rerun failed jobs. If the issue persists, open an issue.
- **Need help?** Run `opk doctor` for a read-only diagnostic, or check [docs/](./docs/) for detailed references.

---

## License

MIT

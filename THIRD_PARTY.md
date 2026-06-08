# Third-Party Components

> opencode-power-kit v1.3.4 optionally integrates with several
> third-party projects. This file lists each one, how the kit
> integrates with it, and which license it ships under.
>
> **Key rule:** opencode-power-kit NEVER vendors or copies the
> source of any third-party project. We either bundle only the
> metadata / configuration needed to call their official
> installer, or we only DETECT their presence.

---

## 1. BMAD Method

| Field        | Value                                                              |
| ------------ | ------------------------------------------------------------------ |
| Role         | Bundled module pack (workflows, agents, slash commands)            |
| Integration  | **Bundled in-tree** under `_bmad/` (read-only mirror)              |
| Source       | https://github.com/bmad-code-org/BMAD-METHOD                       |
| Installer    | None inside the kit — BMAD ships with the kit releases             |
| Update path  | `opk update-bmad` (detects; refreshes via kit release)             |
| License      | MIT (per upstream)                                                 |

opencode-power-kit bundles the BMAD Method's module pack inside
`_bmad/` and exposes the relevant slash commands under
`.opencode/commands/`. We do NOT reimplement BMAD — we ship the
canonical files as they appear in the upstream release, so the
team gets the same workflows the BMAD community has reviewed.

`opk update-bmad` does NOT call an external installer. It
introspects the bundled `_bmad/` directory and only reports its
state. To pull a newer BMAD release, upgrade opencode-power-kit
itself (each release re-bundles the latest audited BMAD snapshot).

## 2. Superpowers

| Field        | Value                                                              |
| ------------ | ------------------------------------------------------------------ |
| Role         | Agent skills library (`.agents/skills/`)                           |
| Integration  | **Bundled in-tree** under `.agents/skills/`                       |
| Source       | https://github.com/obra/superpowers                                |
| Installer    | None inside the kit — Superpowers ships with kit releases          |
| Update path  | Upgrade opencode-power-kit (kit re-bundles the latest snapshot)   |
| License      | MIT (per upstream)                                                 |

opencode-power-kit bundles a curated subset of the Superpowers
skill library in `.agents/skills/`. The bundled files are an
**audited mirror** of upstream at release time. The kit does not
ship an "update superpowers" subcommand — fresh skills ship with
new kit releases. If you need the bleeding edge, clone the
upstream repository directly.

## 3. GSD Core

| Field        | Value                                                              |
| ------------ | ------------------------------------------------------------------ |
| Role         | Optional companion workflow engine                                 |
| Integration  | **Opt-in, calls official installer only** — never vendored        |
| Source       | https://www.npmjs.com/package/@opengsd/gsd-core                    |
| Installer    | `npx @opengsd/gsd-core@latest`                                     |
| Update path  | `opk gsd` or `opk update-gsd`                                      |
| License      | (see npm package page for current license)                         |

opencode-power-kit does NOT bundle GSD Core. The kit only ships a
**thin wrapper** (`scripts/install-gsd-core.sh` /
`scripts/install-gsd-core.ps1`) that:

1. Verifies that `node`, `npm`, and `npx` are on PATH.
2. Prints the planned `npx @opengsd/gsd-core@latest ...` command.
3. Asks for confirmation (or accepts `--yes`).
4. Forwards to the official installer.

The wrapper is **opt-in** — it never runs automatically. It is
exposed via `opk gsd`, `opk update-gsd`, and `opk update-all
--with-gsd`. There is no shell-startup hook, no auto-update, and
no silent background refresh.

## 4. rtk / tokscale (optional, NOT integrated)

| Field        | Value                                                              |
| ------------ | ------------------------------------------------------------------ |
| Role         | Optional token-saver / cost-tracker tooling                       |
| Integration  | **Detection only** — no installer, no vendoring                    |
| Source       | rtk: https://github.com/rtk-ai/rtk ; tokscale: https://github.com/... |
| Installer    | Not provided by this kit                                           |
| Update path  | User installs separately if desired                                |
| License      | (per upstream projects)                                            |

opencode-power-kit is **token-budget aware** (`templates/AGENTS.md`
and `templates/OPENCODE.md` both contain a *Token discipline*
section) but it does not ship rtk or tokscale. If you have rtk or
tokscale installed on PATH, the agent will benefit from them
transparently; if not, the kit still works correctly. We may add
explicit integration in a future release.

---

## Summary table

| Project      | Bundled?    | Auto-update? | Kit ships installer? | Safe by default |
| ------------ | ----------- | ------------ | -------------------- | --------------- |
| BMAD Method  | in-tree     | no           | no (release-coupled) | yes             |
| Superpowers  | in-tree     | no           | no (release-coupled) | yes             |
| GSD Core     | NO          | no           | yes (calls upstream) | yes (opt-in)    |
| rtk/tokscale | NO          | no           | no                   | yes (optional)  |

---

## 5. Third-Party Tooling Policy (v1.5.0)

**The kit detects or documents the following tools but NEVER vendors
their source, NEVER auto-updates on shell start, and NEVER runs their
installer without explicit user command.**

| Tool | Purpose | Detection | Policy |
|------|---------|-----------|--------|
| rtk | Token-saving shell wrapper | `/tooling-doctor` | detect-only |
| repomix | Context pack generator | `/tooling-doctor` | detect-only |
| ast-grep | Code search / structural | `/tooling-doctor` | detect-only |
| rg (ripgrep) | Fast regex search | `/tooling-doctor` | detect-only |
| fd | Fast file find | `/tooling-doctor` | detect-only |
| knip | Dead code detection | `/tooling-doctor` | detect-only |
| gitleaks | Git secret scanning | `/tooling-doctor` | detect-only |
| trufflehog | Secret scanning | `/tooling-doctor` | detect-only |
| semgrep | SAST / static analysis | `/tooling-doctor` | detect-only |
| spectral | OpenAPI lint | `/tooling-doctor` | detect-only |
| oasdiff | OpenAPI diff | `/tooling-doctor` | detect-only |
| Playwright | E2E browser testing | `/tooling-doctor`, `/e2e-flow` | detect + call CLI |
| Biome | Lint / format | `/tooling-doctor` | detect-only |
| tokscale | Token cost visualization | `/tooling-doctor` | detect-only |

The `/tooling-doctor` command detects which tools are installed and
prints install hints for missing ones. The kit NEVER runs `cargo install`,
`npm i -g`, `pip install`, `brew install`, `go install`, or any package
manager on behalf of the user — it only prints the command the user
can run themselves.

The `/e2e-flow` command may call `npx playwright test` if Playwright is
present, but it never installs Playwright itself.

_If you add a new optional integration, follow the same shape:_
_add a row to this table, prefer forwarding to the official_
_installer, and never auto-update on shell start._

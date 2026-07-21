# ECC-lite Integration — Engineering Code Commandments

> **Version:** opencode-power-kit v1.8.0
>
> ECC-lite is an **optional, lightweight** integration of [Engineering Code
> Commandments (ECC)](https://github.com/affaan-m/ECC) by affaan.m. It ships
> only OPK-native components — no full ECC install, no hooks, no MCP configs,
> no memory system, no auto-enable.

---

## What is ECC?

[ECC (Engineering Code Commandments)](https://github.com/affaan-m/ECC) is a
comprehensive engineering discipline framework with **260+ skills, 80+ commands,
full hooks system, MCP integration, and memory persistence**. It enforces
coding standards, security practices, and engineering rigor across the
development lifecycle.

## What is ECC-lite?

ECC-lite distills ECC's core principles into a lightweight, OPK-native
integration:

| Aspect | Full ECC | ECC-lite (OPK) |
|--------|:--------:|:--------------:|
| Skills | 260+ | 6 principles (embedded in agent) |
| Commands | 80+ | 6 slash commands |
| Install | Full installer with hooks | `opk ecc lite` — copies agent + commands |
| Hooks system | Full | Not included |
| MCP integration | Full | Not included |
| Memory system | Full | Not included |
| Auto-enable | Yes | No — opt-in only |
| Audit | Full ECC audit | `opk ecc audit` (read-only, clone to .tmp) |
| Source copy | Cloned to project | Never vendored in repo |

## Architecture

```
User → opk ecc {audit|lite|status|off}
               │
               ├── audit       → scripts/audit-ecc.sh
               │                 (clone ECC → readonly audit → cleanup)
               │
               ├── lite        → scripts/install-ecc-lite.sh
               │                 (copy agent + 6 commands → ~/.config/opencode)
               │
               ├── status      → scripts/check-ecc-lite.sh
               │                 (check files exist, no network)
               │
               └── off         → inline removal
                                (remove agent + 6 commands)
```

### Components

| Component | Location | Role |
|-----------|----------|------|
| `scripts/audit-ecc.sh` | Script | Read-only audit: clone ECC → analyze → create ECC_AUDIT.md → cleanup |
| `scripts/install-ecc-lite.sh` | Script | Install ECC-lite agent + commands to `~/.config/opencode/` |
| `scripts/check-ecc-lite.sh` | Script | Check ECC-lite installation status (no network) |
| `opencode-global/agents/ecc-lite-strong.md` | Agent | ECC-lite agent: research-first, quality gate, verification loop |
| `opencode-global/commands/ecc-audit.md` | Command | Audit codebase against ECC principles |
| `opencode-global/commands/quality-gate.md` | Command | Quality gate before merge/release |
| `opencode-global/commands/research-first.md` | Command | Research-first approach |
| `opencode-global/commands/verify-loop.md` | Command | Verification loop (test-before-done) |
| `opencode-global/commands/backend-route-review.md` | Command | Backend HTTP/API route review |
| `opencode-global/commands/harness-audit.md` | Command | Constraints/edge-cases/invariants audit |

### ECC-lite Principles (embedded in ecc-lite-strong agent)

1. **Research First** — Explore before implementing. Understand existing
   patterns, APIs, and dependencies before writing new code.
2. **Quality Gate** — Verify code meets defined standards before merging.
   No bypassing review.
3. **Verification Loop** — Test-before-done. Iterate until all tests pass.
   No "works on my machine".
4. **Assumption Checking** — Surface and verify assumptions before committing
   to a design.
5. **Test-Before-Done** — Write tests alongside implementation. Coverage is
   not optional.
6. **Security & Reliability Review** — Audit for vulnerabilities, edge cases,
   and invariants before shipping.

## Safety Guarantees

- **No auto-enable** — ECC-lite is never installed by `opk global`, `opk one`,
  `opk go`, `bootstrap.sh`, or any kit setup command.
- **No vendor source** — ECC source is never copied into the OPK repo.
- **No hooks** — No git hooks, OpenCode hooks, or commit hooks.
- **No MCP** — No MCP servers or configs.
- **No env/secrets** — ECC-lite never reads sensitive files.
- **No network in status check** — `check-ecc-lite.sh` only checks local files.
- **No sudo** — All operations are user-scoped (`~/.config/opencode/`).
- **Read-only audit** — `audit-ecc.sh` clones to `.tmp/`, audits, then cleans up.

## Usage

```bash
# Check status
opk ecc status

# Install ECC-lite (agent + commands)
opk ecc lite

# Audit codebase against ECC principles
opk ecc audit

# Remove ECC-lite
opk ecc off

# Update ECC-lite
opk update-ecc

# Short aliases
opk ec status
opk e lite
```

### Slash commands (after install)

| Slash command | Purpose |
|:-------------:|---------|
| `/ecc-audit` | Audit codebase against ECC principles (read-only) |
| `/quality-gate` | Quality gate: verify code meets ECC standards before merge |
| `/research-first` | Research-first approach: explore before implementing |
| `/verify-loop` | Verification loop: test-before-done, iterate until passing |
| `/backend-route-review` | Backend HTTP/API route review: routing, auth, middleware, error handling |
| `/harness-audit` | Harness audit: verify constraints, edge cases, invariants |

## Why not full ECC?

Full ECC is a **comprehensive engineering discipline framework** with 260+
skills, 80+ commands, hooks, MCP, and memory. While powerful, it is:

1. **Heavy** — 260+ skills add significant context overhead.
2. **Complex** — Hooks, MCP, and memory require careful configuration.
3. **Opinionated** — Full auto-enable may not suit all workflows.
4. **Overkill for many projects** — Many teams need only the core principles.

ECC-lite gives you the **essence** of ECC — the 6 core principles — without
the full framework weight. It follows OPK's philosophy: **opt-in, lightweight,
no hidden side effects**.

## Files

| File | Role |
|------|------|
| `scripts/audit-ecc.sh` | Linux/macOS audit script |
| `scripts/install-ecc-lite.sh` | Linux/macOS installer |
| `scripts/check-ecc-lite.sh` | Linux/macOS status check |
| `opencode-global/agents/ecc-lite-strong.md` | ECC-lite agent definition |
| `opencode-global/commands/ecc-audit.md` | ECC audit command |
| `opencode-global/commands/quality-gate.md` | Quality gate command |
| `opencode-global/commands/research-first.md` | Research-first command |
| `opencode-global/commands/verify-loop.md` | Verification loop command |
| `opencode-global/commands/backend-route-review.md` | Backend HTTP/API route review command |
| `opencode-global/commands/harness-audit.md` | Harness audit command |
| `bin/opk` / `bin/opk.ps1` | CLI subcommands: `ecc`, `ec`, `e`, `update-ecc` |

See [`THIRD_PARTY.md`](./THIRD_PARTY.md) for license and update path.

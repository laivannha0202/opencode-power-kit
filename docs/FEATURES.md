# Features

## Power Mode v1.5.0

- **13 core agents** — each specialized for one domain
- **34 commands** — organized into power workflow, safety, build lifecycle, review, DB/API, QA/E2E, DevOps, quality/security, token/tooling
- **Safety guard** — `opk-command-guard.sh` warns/blocks dangerous shell commands (`rm -rf`, `git reset --hard`, force push, `DROP TABLE`, ...)
- **Agent delegation** — `build-strong` automatically spawns specialized subagents
- **`/power-build`** — end-to-end: spec → architecture → build → QA → security → release
- **`/agent-router`** — natural language routing to the right agent
- **`/tooling-doctor`** — detect third-party tooling (rtk, repomix, semgrep, gitleaks, ...)
- **100% backward compatible**

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**  
5 profile commands, 5 profile skills, 9 global full-stack commands, 8 global full-stack skills.

## Cross-platform

Linux, macOS (Git Bash/WSL), Windows (PowerShell).

## Safety-first

No `rm -rf`, no `git reset --hard`, no force push, no secrets exposure, DB destructive ops require confirmation, checkpoint before large changes.

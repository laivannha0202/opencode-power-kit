# Commands Reference

## Power Workflow

| Command | File | Purpose |
|---------|------|---------|
| `/agent-router` | `any.md` | Route task to the right specialized agent |
| `/power-build` | `power-build.md` | End-to-end build: spec → architecture → build → QA → security → release |
| `/tooling-doctor` | `tooling-doctor.md` | Detect third-party tooling availability |

## Safety

| Command | File | Purpose |
|---------|------|---------|
| `/cleanup-safe` | `cleanup-safe.md` | Safely move temp artifacts to `.opk-trash/` |
| `/checkpoint` | `checkpoint.md` | Snapshot working tree before large changes |
| `/handoff-save` | `handoff-save.md` | Update `AI_HANDOFF.md` for context continuity |

## Build Lifecycle

| Command | File | Purpose |
|---------|------|---------|
| `/spec-lite` | `spec-lite.md` | Quick spec (goal, scope, AC, out-of-scope) |
| `/plan-work` | `plan-work.md` | Break task into ≤ 7 steps with files + tests |
| `/build-slice` | `build-slice.md` | Implement one slice, ≤ 2 files, ≤ 100 lines diff |
| `/ci-fix` | `ci-fix.md` | Read CI/test/build errors and fix safely |
| `/ship-check` | `ship-check.md` | Pre-commit/pre-push checklist |

## Review

| Command | File | Purpose |
|---------|------|---------|
| `/review-diff` | `review-diff.md` | Review git diff |
| `/security-review` | `security-review.md` | Security review (secrets, auth, input validation) |
| `/api-contract-review` | `api-contract-review.md` | Check FE/BE API contract alignment |
| `/migration-safe` | `migration-safe.md` | Verify migration safety before running |
| `/release-check` | `release-check.md` | Check VERSION/README/CHANGELOG/tag before release |

## DB / API

| Command | File | Purpose |
|---------|------|---------|
| `/db-readonly` | `db-readonly.md` | Read-only DB checks |
| `/migration-safe` | `migration-safe.md` | Migration safety check |
| `/openapi-check` | `openapi-check.md` | OpenAPI spec validation (spectral/oasdiff) |
| `/secret-scan` | `secret-scan.md` | Secret pattern scan (gitleaks/trufflehog) |
| `/sast-check` | `sast-check.md` | Static analysis (semgrep) |

## QA / E2E

| Command | File | Purpose |
|---------|------|---------|
| `/test-proof` | `test-proof.md` | Run/propose tests as proof |
| `/test-matrix` | `test-matrix.md` | Generate test matrix (unit/integration/e2e/smoke) |
| `/e2e-flow` | `e2e-flow.md` | Plan and run E2E proof with Playwright |
| `/e2e-plan` | `e2e-plan.md` | Propose Playwright E2E flows |

## DevOps / Environment

| Command | File | Purpose |
|---------|------|---------|
| `/env-doctor` | `env-doctor.md` | Check env safety (no secret values printed) |
| `/docker-dev-doctor` | `docker-dev-doctor.md` | Check docker-compose dev setup |
| `/fullstack-scan` | `fullstack-scan.md` | Full-stack project scan (FE/BE/DB/scripts/env/docker) |

## Quality / Security

| Command | File | Purpose |
|---------|------|---------|
| `/js-quality-check` | `js-quality-check.md` | Detect eslint/prettier/biome/knip/vitest/tsc |
| `/smart-scan` | `smart-scan.md` | Quick project health scan |
| `/kit-audit` | `kit-audit.md` | Audit opencode-power-kit structure |
| `/repo-map` | `repo-map.md` | Generate project map |
| `/bugfix-safe` | `bugfix-safe.md` | Safe bug fix workflow |

## Token / Tooling

| Command | File | Purpose |
|---------|------|---------|
| `/rtk-gain` | `rtk-gain.md` | Run `rtk gain` or guide installation |
| `/token-pack` | `token-pack.md` | Pack context via Repomix |

## CLI Commands

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
| `opk path` | Show kit path |
| `opk update` | Update kit from git origin |

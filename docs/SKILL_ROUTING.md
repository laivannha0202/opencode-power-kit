# Skill Routing — Model-Agnostic

OPK skills route by **task context**, never by model.

## Routing Rules

| Task Context | Skill | Agent | Trigger | Verification |
|-------------|-------|-------|---------|-------------|
| ADR, architecture decision | `adr-architecture-decision` | `architect-strong` | Architecture choice needed | Manual review |
| Agent memory, state persistence | `agentmemory-lite` | `build-strong` | Multi-session, context handoff | Manual review |
| API contract, OpenAPI | `api-contract` | `api-strong` | API endpoint design/review | Manual review |
| Database schema, migration | `database-migration-safe` | `db-strong` | Schema change, migration | Manual review |
| Dependency update | `dependency-maintenance` | `build-strong` | Package version bump | `npm audit` / manual |
| Docker compose | `docker-compose-safe` | `devops-strong` | Container config | `docker compose config` |
| Env config | `env-config-safe` | `build-strong` | Environment variable setup | Manual review |
| Frontend UI review | `frontend-ui-review` | `ui-ux-strong` | UI/UX audit | Manual review |
| Fullstack test strategy | `fullstack-test-strategy` | `qa-strong` | Cross-layer testing | Manual review |
| Context compression | `headroom-lite` | `build-strong` | Token budget, output truncation | Manual review |
| JS/TS project setup | `js-ts-project` | `build-strong` | New JS/TS project | Manual review |
| JS/TS quality | `js-ts-quality` | `qa-strong` | Code quality audit | Lint/test pass |
| NestJS + React + MySQL | `nest-react-mysql` | `build-strong` | Fullstack NestJS/React | Build + test pass |
| OpenAPI contract | `openapi-contract` | `api-strong` | OpenAPI spec | Manual review |
| RAG planning | `rag-lite` | `build-strong` | RAG, vector search, chunking | Manual review |
| Repo map | `repo-map` | `build-strong` | Codebase overview | Manual review |
| Token optimization | `rtk-token-optimizer` | `build-strong` | Token usage optimization | Manual review |
| Safe edit | `safe-edit` | `build-strong` | Edit with safety guard | Manual review |
| Security fullstack | `secure-fullstack` | `security-strong` | Security audit (full) | Manual review |
| Security review | `security-review` | `security-strong` | Security review (quick) | Manual review |
| Serena first | `serena-first` | `build-strong` | Semantic code navigation | Manual review |
| Test strategy | `test-strategy` | `qa-strong` | Test planning | Manual review |
| Token-smart code | `token-smart-code` | `build-strong` | Token-efficient codegen | Manual review |

## Policy

- **This is documentation, not runtime enforcement.** Skills are loaded manually by the agent or user, not auto-dispatched.
- **No model routing.** Skills do not select models. Model selection is in OpenCode UI.
- **No per-skill model override.** All skills inherit the user-selected model.
- **No runtime auto-load on-demand** without test evidence. Current skills require explicit invocation.
- **Verification is manual** unless a specific test is listed.

## No Model Override

- Skills do NOT contain `model:` in SKILL.md frontmatter.
- Skills do NOT route based on model name, provider, or cost.
- Model selection happens in OpenCode UI, not in skill routing.
- OPK skills are model-agnostic: they work with any model the user selects.

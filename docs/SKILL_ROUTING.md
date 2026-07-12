# Skill Routing — Model-Agnostic

OPK skills route by **task context**, never by model.

## Routing Rules

| Task Context | Skill | Trigger |
|-------------|-------|---------|
| ADR, architecture decision | `adr-architecture-decision` | Architecture choice needed |
| Agent memory, state persistence | `agentmemory-lite` | Multi-session, context handoff |
| API contract, OpenAPI | `api-contract` | API endpoint design/review |
| Database schema, migration | `database-migration-safe` | Schema change, migration |
| Dependency update | `dependency-maintenance` | Package version bump |
| Docker compose | `docker-compose-safe` | Container config |
| Env config | `env-config-safe` | Environment variable setup |
| Frontend UI review | `frontend-ui-review` | UI/UX audit |
| Fullstack test strategy | `fullstack-test-strategy` | Cross-layer testing |
| Context compression | `headroom-lite` | Token budget, output truncation |
| JS/TS project setup | `js-ts-project` | New JS/TS project |
| JS/TS quality | `js-ts-quality` | Code quality audit |
| NestJS + React + MySQL | `nest-react-mysql` | Fullstack NestJS/React |
| OpenAPI contract | `openapi-contract` | OpenAPI spec |
| RAG planning | `rag-lite` | RAG, vector search, chunking |
| Repo map | `repo-map` | Codebase overview |
| Token optimization | `rtk-token-optimizer` | Token usage optimization |
| Safe edit | `safe-edit` | Edit with safety guard |
| Security fullstack | `secure-fullstack` | Security audit (full) |
| Security review | `security-review` | Security review (quick) |
| Serena first | `serena-first` | Semantic code navigation |
| Test strategy | `test-strategy` | Test planning |
| Token-smart code | `token-smart-code` | Token-efficient codegen |

## No Model Override

- Skills do NOT contain `model:` in SKILL.md frontmatter.
- Skills do NOT route based on model name, provider, or cost.
- Model selection happens in OpenCode UI, not in skill routing.
- OPK skills are model-agnostic: they work with any model the user selects.

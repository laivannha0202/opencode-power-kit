# UPSTREAM_CAPABILITY_MAP.md — OPK vs OpenCode Native

OPK (opencode-power-kit) extends OpenCode with additional capabilities.

## Capability Matrix

| Capability | OpenCode Native | OPK Added |
|-----------|----------------|-----------|
| Agent runtime | ✅ Built-in | ✅ 16 agents |
| Skill system | ✅ Built-in | ✅ 23 skills |
| MCP servers | ✅ Built-in | ✅ 11 servers |
| Model selection | ✅ OpenCode UI | ❌ Not managed by OPK |
| Workflow contracts | ❌ | ✅ Behavioral regression tests |
| Release gate | ❌ | ✅ Version + eval gate |
| Safety plugin | ❌ | ✅ OPK Safety Guard |
| Permission rules | ❌ | ✅ Template with wildcard/deny |
| PowerShell verify | ❌ | ✅ Cross-platform verification |
| Evals (regression) | ❌ | ✅ 12 workflow contracts |

## OPK Does NOT Manage

- **Model selection** — users choose via OpenCode UI
- **Model routing** — no discovery, benchmarking, or routing
- **API keys** — no key management in OPK
- **Model quality scoring** — no eval-based model ranking

## OPK Adds

- **Behavioral contracts** — verify no-model-routing, no-API-keys, no-overrides
- **Release gate** — version bump + eval pass required
- **Safety plugin** — blocks dangerous operations
- **Permission template** — wildcard-first, deny-specific pattern
- **Cross-platform verify** — bash + PowerShell verification
- **Skill routing** — 23 skills for task context
- **Agent delegation** — 16 specialized agents

## Model-Agnostic Policy

OPK is model-agnostic. The kit works with any model the user selects in OpenCode.
- No `model:` override in agent files
- No model discovery/routing/benchmark scripts
- No model quality scoring
- No API key management
- Skills route by task context, not model

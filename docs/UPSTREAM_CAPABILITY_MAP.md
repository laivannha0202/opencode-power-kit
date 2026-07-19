# UPSTREAM_CAPABILITY_MAP.md — OPK vs OpenCode Native

OPK (opencode-power-kit) extends OpenCode with additional capabilities.

## Capability Matrix

| Capability | OpenCode Native | OPK Added |
|-----------|----------------|-----------|
| Agent runtime | ✅ Built-in | ✅ 16 agents |
| Skill system | ✅ Built-in | ✅ 23 skills |
| MCP servers | ✅ Built-in | ❌ OPK does NOT auto-enable MCP |
| Model selection | ✅ OpenCode UI | ❌ Not managed by OPK |
| Workflow contracts | ❌ | ✅ Behavioral regression tests |
| Release gate | ❌ | ✅ Version + eval gate |
| Safety plugin | ❌ | ✅ OPK Safety Guard (CommonJS) |
| Permission rules | ❌ | ✅ Template with wildcard/deny |
| PowerShell verify | ❌ | ✅ Cross-platform verification |
| Evals (regression) | ❌ | ✅ 12 workflow contracts |

## OPK Does NOT Manage

- **Model selection** — users choose via OpenCode UI
- **Model routing** — no discovery, benchmarking, or routing
- **API keys** — no key management in OPK
- **Model quality scoring** — no eval-based model ranking
- **MCP servers** — OPK does not auto-enable MCP; OpenCode supports it natively

## OPK Adds

- **Behavioral contracts** — verify no-model-routing, no-API-keys, no-overrides
- **Release gate** — version bump + eval pass required
- **Safety plugin** — blocks dangerous operations (CommonJS, `module.exports = OPKSafetyGuard`)
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

---

## Upstream Dependencies

| Upstream | Repository | License | Pin/Tag/Commit | Integration Mode | Capability Learned | Agent/Skill Using It | Not Used | Security Risk | Update Policy |
|----------|-----------|---------|----------------|-----------------|-------------------|---------------------|----------|--------------|---------------|
| Superpowers | https://github.com/obra/superpowers.git | MIT | v6.1.1 (template pin) | Plugin reference (loaded at runtime) | Skill system, agent delegation patterns | build-strong, all agents via skill system | N/A | Medium — runtime dependency, pinned tag | Pinned tag, manual update |
| BMAD Method | https://github.com/bmad-code-org/BMAD-METHOD | MIT | 6.9.0 (pinned) | Install-time dependency | Project scaffolding, planning templates | install.sh, bootstrap | N/A | Low — install-time only | Pin version in install script |
| GSD Core | https://github.com/open-gsd/gsd-core | MIT (npm @opengsd/gsd-core) | @1.6.1 (pinned) | Opt-in wrapper (`opk gsd`) | Workflow orchestration, agent patterns | extras/gsd-agent-reference/ (34 files, reference-only) | Active agents: no GSD in agents/ | Medium — npm dependency, pinned | Version pinned, override via env |
| ECC | https://github.com/affaan-m/ECC | UNKNOWN | unpinned (latest) | Opt-in wrapper (`opk ecc lite`) | Error handling, retry patterns | ecc-lite skill | N/A | Low — opt-in only | Manual update |
| Hermes | https://github.com/NousResearch/hermes-agent | UNKNOWN | N/A | Inspiration-only | Meta-cognition, learning loop, reflection | hermes-lite-strong agent | No runtime dependency | Low — no code imported | Reference only |
| AgentMemory | https://github.com/rohitg00/agentmemory | Apache-2.0 | N/A | Inspiration-only | Agent memory, state persistence, session handoff | agentmemory-lite skill | No runtime dependency | Low — no code imported | Reference only |
| RAG Techniques | https://github.com/NirDiamant/RAG_Techniques | UNKNOWN | N/A | Reference | RAG planning, chunking, embedding strategies | rag-lite skill | No runtime dependency | Low — no code imported | Reference only |
| Headroom | https://github.com/chopratejas/headroom | UNKNOWN | N/A | Inspiration-only | Context compression, token budget, output truncation | headroom-lite skill | No runtime dependency | Low — no code imported | Reference only |
| Taste Skill | https://github.com/Leonxlnx/taste-skill | UNKNOWN | unpinned (latest) | Verify-gated dependency (`opk taste install`) | UI/UX design, image-to-code, brand kit | taste-ui-strong agent, design-taste-frontend skill | N/A | Medium — install-time dependency | Verify-gated install |

### Notes

- **Verified pins**: Superpowers v6.1.1 (template pin), BMAD 6.9.0 (install script pin), GSD @1.6.1 (npm pin) — all verified against installed packages and config files. Local cache v5.0.7 is an old install, not source-of-truth.
- **UNKNOWN**: ECC, Taste Skill version pins not verified. Do not claim audited without verification.
- **Integration modes**: "Inspiration-only" = no code imported, pattern reference. "Opt-in wrapper" = user must explicitly install. "Plugin reference" = loaded at runtime by OpenCode.
- **Not Used**: Column indicates what OPK does NOT use from the upstream.
- **Security Risk**: Low = no runtime impact. Medium = dependency that could be exploited. High = critical path (none in current set).
- **Update Policy**: How OPK handles upstream updates. "Manual" = human must decide. "Pinned" = version locked. "Verify-gated" = install blocked until checks pass. All pinned upstreams use explicit version tags, not auto-update.

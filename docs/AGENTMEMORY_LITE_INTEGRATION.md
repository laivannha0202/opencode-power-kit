# AgentMemory-lite — Agent State & Session Memory Reference

> **Version:** opencode-power-kit v1.9.3
>
> **Integration mode:** Reference / Workflow guidance — OPK-native docs, skill,
> and slash commands. **No runtime code, no dependency, no package install,
> no MCP, no proxy/daemon.** All content is conceptual guidance, workflow
> templates, and agent instructions — safe to use under MIT license.

---

## Overview

AgentMemory-lite is an **OPK-native reference module** for agent state and
session memory patterns. It helps agents plan, audit, and hand off memory
across sessions — enabling multi-session workflows, persistent context, and
safe state transfer between agent invocations.

AgentMemory-lite draws inspiration from
[rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) — a
serverless memory layer for AI agents — but is a **reference workflow only**.
No source code, plugin hooks, or runtime configurations from upstream are
shipped.

AgentMemory-lite provides:

- **Documentation** — conceptual overview, memory architecture, when to
  persist vs when to re-derive, safe handoff patterns.
- **Agent skill** — `agentmemory-lite` skill that teaches agents how to plan
  memory usage, audit session memory, and perform safe handoffs.
- **Slash commands** — `/memory-plan`, `/memory-audit`, `/memory-handoff`
  for structured workflows.

### What AgentMemory-lite is NOT

- ❌ **Not a memory runtime** — no database, no vector store, no key-value
  store, no file-based persistence engine.
- ❌ **Not a code library** — no Python/TypeScript/PHP code is shipped.
- ❌ **Not a copy of upstream** — no source, plugin, hook, or significant
  content from [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).
- ❌ **Not an auto-installer** — never installs packages, plugins, or MCP
  servers.
- ❌ **Not a hook/plugin** — never attaches to OpenCode lifecycle events,
  never runs on session start/end automatically.
- ❌ **Not auto-enabled** — never activated by `opk global`, bootstrap, or
  setup.

### What AgentMemory-lite IS

- ✅ **Conceptual reference** — memory architecture patterns, state
  persistence strategies, session context management, handoff protocols.
- ✅ **Workflow templates** — how to plan memory strategy for multi-session
  tasks, audit existing session memory, and perform safe agent handoffs.
- ✅ **Agent guidance** — when to persist state (long-running tasks,
  multi-session workflows, context-heavy debugging), when NOT to persist
  (one-shot tasks, ephemeral queries, sensitive/secret data).
- ✅ **Complementary to Headroom-lite** — use together: Headroom-lite for
  context compression, AgentMemory-lite for state persistence across sessions.
- ✅ **Complementary to RAG-lite** — use together: RAG-lite for retrieval
  quality, AgentMemory-lite for persistent agent memory across sessions.
- ✅ **Safe handoff** — how to transfer context between agent sessions
  without data loss or security issues.

---

## Memory Architecture Concept Reference

### Why Agent Memory Matters

Every complex agent workflow faces these challenges:

- **Context limits** — sessions have finite context windows; long-running
  tasks exceed them.
- **State loss** — agent state (decisions made, files processed, TODOs
  completed) is lost between sessions or tool calls.
- **Handoff fragility** — transferring context between agents or sessions
  is error-prone without a structured handoff protocol.
- **Re-computation cost** — re-deriving state from scratch wastes tokens
  and time.

### Memory Spectrum

| Approach | Persistence | Overhead | Use case |
|----------|:-----------:|:--------:|----------|
| **Ephemeral** (no save) | None | None | One-shot queries, simple Q&A |
| **Decision log** (key choices) | Single session | Low | Audit trail, reasoning capture |
| **Handoff file** (structured JSON) | Cross-session | Low | Agent handoff, state transfer |
| **Working context** (full state) | Cross-session | Medium | Multi-step builds, complex debugging |
| **External storage** (DB/file/RAG) | Permanent | High | Long-lived agents, production systems |

### When to Persist Memory

| Scenario | Persist? | Strategy |
|----------|:--------:|----------|
| Multi-session feature build | ✅ Yes | Handoff file + decision log |
| Complex bug investigation | ✅ Yes | Working context with repro steps |
| Multi-agent orchestration | ✅ Yes | Structured handoff between agents |
| One-shot code review | ❌ No | Keep ephemeral |
| Quick question/answer | ❌ No | Keep ephemeral |
| Secrets / credentials | ❌ NEVER | Never persist |
| Personal user data | ⚠️ Partial | Anonymize, minimize, get consent |
| Long-running data pipeline | ✅ Yes | Checkpoint state at each stage |

### Memory Anatomy

A persisted memory entry typically contains:

```
{
  "session_id": "unique-session-id",
  "timestamp": "2026-06-12T10:00:00Z",
  "type": "handoff | decision | context | checkpoint",
  "scope": "task | session | project",
  "content": {
    "goal": "What this session/agent is trying to achieve",
    "progress": "What has been done so far",
    "decisions": ["Decision 1 with rationale", "Decision 2 with rationale"],
    "blockers": ["Any current blockers"],
    "next_steps": ["What to do next"],
    "artifacts": ["Paths to files/outputs created"],
    "context": {
      "key_variables": {"var": "value"},
      "state_summary": "Brief summary of current state"
    }
  },
  "ttl": "2026-06-19T10:00:00Z",
  "version": "1"
}
```

### Safe Handoff Protocol

When handing off between sessions:

1. **Serialize state** → write structured `AI_HANDOFF.md` or JSON file.
2. **Declare scope** → what's done, what's pending, what's blocked.
3. **Include decisions** → why certain paths were chosen or rejected.
4. **Flag blockers** → what needs human input or external resolution.
5. **Attach artifacts** → paths to files, outputs, logs.
6. **Set TTL** → when this handoff becomes stale (auto-cleanup hint).
7. **Verify integrity** → recipient confirms they can restore state.

---

## License-Safe Design

### Why this matters

[rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) is licensed
under **Apache-2.0**, which permits commercial use, modification, and
distribution with attribution. However, AgentMemory-lite is designed as a
**reference workflow only** to keep opencode-power-kit lightweight, MIT-only,
and free of runtime dependencies.

### AgentMemory-lite rule

1. **No source code** from any upstream repository is shipped in OPK.
2. **No plugin hooks or runtime configs** are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general
   agent memory / state persistence knowledge, not derived from any
   single upstream.
5. **Credit is given** in `THIRD_PARTY.md` for:
   - rohitg00/agentmemory (reference / inspiration)
   - Any other memory projects referenced in this module
6. **Links to upstream** are provided for users who want the full
   implementation details.

### Third-party references

| Project | Link | Purpose |
|---------|------|---------|
| rohitg00/agentmemory | https://github.com/rohitg00/agentmemory | Serverless memory layer for AI agents (reference) |
| Supermemory | https://github.com/supermemory/supermemory | Memory/knowledge persistence (complementary opt-in tool) |

---

## Workflow: Plan → Audit → Handoff

AgentMemory-lite provides three structured workflows for agents:

### 1. Plan (`/memory-plan`)

When a task involves multi-session work or state persistence,
`/memory-plan` guides the agent through:

1. **Problem analysis** — Is memory needed? What state must persist?
   How long should it live?
2. **Scope classification** — Task-level, session-level, or
   project-level memory?
3. **Strategy selection** — Which approach fits? Decision log,
   handoff file, working context, or external storage?
4. **Content planning** — What information to store? Goal, progress,
   decisions, blockers, next steps, artifacts?
5. **TTL planning** — When does this memory become stale? Auto-cleanup
   hints.
6. **Safety check** — No secrets, no personal data, no credentials.

### 2. Audit (`/memory-audit`)

When reviewing session memory quality and completeness,
`/memory-audit` checks:

1. **Memory inventory** — What memories exist? Are they current?
2. **Completeness** — Does each memory entry have goal, progress,
   decisions, blockers, next steps?
3. **Staleness** — Are there old entries past their TTL?
4. **Safety review** — Are secrets or sensitive data stored?
5. **Integrity** — Are decisions justified? Progress verifiable?
6. **Handoff readiness** — If another agent picks this up, can they
   reconstruct state?

### 3. Handoff (`/memory-handoff`)

When transferring state between sessions or agents,
`/memory-handoff` guides:

1. **State collection** — Gather current progress, decisions made,
   blockers, next steps, and artifact references.
2. **Structured output** — Write structured `AI_HANDOFF.md` or
   JSON with all fields.
3. **Integrity check** — Verify all state is captured, nothing omitted.
4. **Safety review** — Ensure secrets/personal data are excluded.
5. **TTL set** — Mark when this handoff becomes stale.
6. **Recipient validation** — Confirm the receiving agent/session
   can restore state.
7. **Cleanup** — Remove stale previous handoffs (if safe).

---

## Agent Integration

### When to activate agentmemory-lite skill

The `agentmemory-lite` skill should be activated when:

- A task spans multiple sessions (feature build, complex debugging)
- State needs to persist between agent invocations
- Handing off context between agents or sessions
- Auditing existing session memory for completeness
- Any task mentioning "memory", "handoff", "state persistence",
  "session context", "long-running task", "multi-session"

### How agents use agentmemory-lite

1. Agent detects memory-related work → loads `agentmemory-lite` skill
2. Uses `/memory-plan`, `/memory-audit`, `/memory-handoff` commands
   for structured workflows
3. Applies checklists from this document to ensure quality
4. Never installs memory packages directly — uses OPK-native patterns
5. Never copies code from upstream — follows OPK-safe patterns
6. Combines with `headroom-lite` when both memory and context
   compression are needed
7. Combines with `rag-lite` when both memory and retrieval are needed

### Safety rules for agents

- **No auto-install** — Never install memory databases, vector stores,
  or packages without explicit user request.
- **No credential handling** — Never read or store API keys, tokens,
  secrets, or personal data in memory.
- **No production changes** — AgentMemory-lite workflows are
  planning/audit/handoff tools only. Production changes require user
  approval.
- **No upstream code copy** — Never copy code from rohitg00/agentmemory
  or other upstreams into the project.
- **Always credit** — When referencing upstream projects, add credit to
  `THIRD_PARTY.md` following OPK conventions.
- **Declare persistence** — Always declare what is being persisted and
  why. Never silently store state.
- **TTL awareness** — Always set a TTL or expiry for persisted memory.
  Stale memory pollutes future sessions.
- **Safe handoff** — Never include secrets in handoff files. Always
  verify handoff integrity.

### Combining with Headroom-lite

When both memory and context compression are needed:

1. Use `/memory-plan` to design what state to persist.
2. Use `/headroom-plan` to fit the memory within the context budget.
3. Use `/memory-audit` + `/headroom-audit` together to verify both
   memory quality and compression integrity.
4. The combined workflow: plan memory → compress for handoff →
   audit → handoff.

### Combining with RAG-lite

When both memory and retrieval are needed:

1. Use `/rag-plan` to design the retrieval pipeline.
2. Use `/memory-plan` to persist retrieved context across sessions.
3. Use `/rag-audit` + `/memory-audit` together to verify both
   retrieval quality and memory completeness.
4. The combined workflow: retrieve → persist → compress → audit.

---

## Memory Checklist

Before persisting memory, verify:

- [ ] **Need confirmed** — Is this memory truly needed across sessions?
- [ ] **Scope classified** — Task, session, or project level?
- [ ] **Strategy matches need** — Decision log, handoff file, or
      working context?
- [ ] **Content complete** — Goal, progress, decisions, blockers,
      next steps, artifacts?
- [ ] **Secrets excluded** — No API keys, tokens, passwords, or
      personal data.
- [ ] **TTL set** — When does this become stale?
- [ ] **Integrity verified** — Can another agent restore this state?
- [ ] **Combined with Headroom-lite** — If context is tight, compress
      before persisting.
- [ ] **Combined with RAG-lite** — If retrieval is involved, verify
      quality before persisting.

---

## Memory Anti-Patterns

- ❌ Persisting ephemeral state (one-shot queries, simple answers)
- ❌ Persisting secrets, credentials, or personal data
- ❌ Persisting without TTL (stale memory pollutes future sessions)
- ❌ Over-persisting: saving every intermediate state
- ❌ Under-persisting: not saving key decisions or progress
- ❌ Silent persistence: storing state without declaring it
- ❌ Handoff without integrity check: passing incomplete or
    incorrect state
- ❌ Mixing scopes: task-level memory used for project-level context
- ❌ Not cleaning up stale handoffs

---

## Comparison: Strategies at a Glance

| Approach | When to use | When to avoid |
|----------|-------------|---------------|
| **Ephemeral** | One-shot tasks, simple Q&A | Multi-step, multi-session work |
| **Decision log** | Complex reasoning, audit trail | When full state is needed |
| **Handoff file** | Agent handoff, session transfer | Ephemeral tasks |
| **Working context** | Multi-session builds, debugging | Simple queries |
| **External storage** | Production agents, long-term memory | One-off experiments |

---

## Files

| File | Role |
|------|------|
| `docs/AGENTMEMORY_LITE_INTEGRATION.md` | This document — conceptual reference, memory strategies, safe handoff protocol, checklist |
| `opencode-global/skills/agentmemory-lite/SKILL.md` | Agent skill — teaches agents memory planning, audit, and handoff workflows |
| `opencode-global/commands/memory-plan.md` | `/memory-plan` — plan a memory strategy for multi-session tasks |
| `opencode-global/commands/memory-audit.md` | `/memory-audit` — audit existing session memory quality |
| `opencode-global/commands/memory-handoff.md` | `/memory-handoff` — safe handoff between sessions/agents |

---

## Upstream References

- **rohitg00/agentmemory** — https://github.com/rohitg00/agentmemory
  Serverless memory layer for AI agents. Apache-2.0 licensed.
  OPK references concepts only — no code or plugin is copied.
- **Supermemory** — https://github.com/supermemory/supermemory
  Memory/knowledge persistence for AI agents (opt-in tool in OPK).

---

## Related Modules

| Module | Integration | Purpose |
|--------|:-----------:|---------|
| **Headroom-lite** | Reference | Context compression — fit memory within token budgets |
| **RAG-lite** | Reference | Retrieval quality — persist useful retrieval results |
| **Hermes-lite** | Inspiration-only | Meta-cognitive self-improvement, memory policy review |

---

*This file is part of opencode-power-kit and is MIT licensed. It references
upstream projects for conceptual guidance only. No upstream source code,
plugins, hooks, or significant text are included.
See `THIRD_PARTY.md` for full attribution.*

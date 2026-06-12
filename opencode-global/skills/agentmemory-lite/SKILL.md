# AgentMemory-lite Skill — Agent State & Session Memory

> **Integration mode:** Reference / Workflow guidance only.
> No runtime code, no package install, no MCP, no proxy/daemon.
> All content is OPK-original workflow guidance — MIT safe.

## Purpose

Teaches agents how to plan memory usage, audit session memory quality, and
perform safe agent handoffs across sessions. Enables multi-session workflows
with persistent context.

## Triggers

Activate this skill when the task involves:

- Multi-session work (feature build, complex debugging)
- State persistence across agent invocations
- Handing off context between agents or sessions
- Auditing existing session memory for completeness
- Keywords: "memory", "handoff", "state persistence", "session context",
  "long-running task", "multi-session"

## Workflow

### Phase 1: Plan (`/memory-plan`)

When starting a multi-session task:

1. **Problem analysis** — Is memory needed? What state must persist?
   How long should it live?
2. **Scope classification** — Task-level, session-level, or project-level
   memory?
3. **Strategy selection** — Decision log, handoff file, working context,
   or external storage?
4. **Content planning** — Goal, progress, decisions, blockers, next steps,
   artifacts?
5. **TTL planning** — When does this memory become stale?
6. **Safety check** — No secrets, no personal data, no credentials.

### Phase 2: Audit (`/memory-audit`)

When reviewing memory quality:

1. **Memory inventory** — What memories exist? Are they current?
2. **Completeness** — Each entry has goal, progress, decisions, blockers,
   next steps?
3. **Staleness** — Old entries past their TTL?
4. **Safety review** — Secrets or sensitive data stored?
5. **Integrity** — Decisions justified? Progress verifiable?
6. **Handoff readiness** — Can another agent reconstruct state?

### Phase 3: Handoff (`/memory-handoff`)

When transferring state:

1. **State collection** — Current progress, decisions, blockers, next steps,
   artifacts.
2. **Structured output** — Write structured `AI_HANDOFF.md` or JSON.
3. **Integrity check** — All state captured, nothing omitted.
4. **Safety review** — Secrets/personal data excluded.
5. **TTL set** — When handoff becomes stale.
6. **Recipient validation** — Confirm receiving agent can restore state.
7. **Cleanup** — Remove stale previous handoffs.

## Combined Workflows

### AgentMemory-lite + Headroom-lite

1. `/memory-plan` → design what to persist
2. `/headroom-plan` → fit memory within context budget
3. `/memory-audit` + `/headroom-audit` → verify both
4. Combined: plan memory → compress for handoff → audit → handoff

### AgentMemory-lite + RAG-lite

1. `/rag-plan` → design retrieval pipeline
2. `/memory-plan` → persist retrieved context across sessions
3. `/rag-audit` + `/memory-audit` → verify both
4. Combined: retrieve → persist → compress → audit

## Safety Rules

- ❌ No auto-install — never install memory packages without explicit request
- ❌ No credential handling — never store API keys, tokens, secrets
- ❌ No production changes — planning/audit/handoff tools only
- ❌ No upstream code copy — never copy from rohitg00/agentmemory
- ✅ Always credit upstream in THIRD_PARTY.md
- ✅ Always declare what is being persisted and why
- ✅ Always set TTL for persisted memory
- ✅ Never include secrets in handoff files

## Files

- `docs/AGENTMEMORY_LITE_INTEGRATION.md` — full reference
- `opencode-global/commands/memory-plan.md` — `/memory-plan`
- `opencode-global/commands/memory-audit.md` — `/memory-audit`
- `opencode-global/commands/memory-handoff.md` — `/memory-handoff`

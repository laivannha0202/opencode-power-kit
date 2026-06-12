---
description: Plan a memory strategy for multi-session tasks — scope classification, strategy selection, TTL, safety check
---

# /memory-plan

> **AgentMemory-lite command** — plan a memory strategy for multi-session
> tasks.

## When to use

- Starting a task that spans multiple sessions
- Need to persist state across agent invocations
- Complex feature build or bug investigation
- Multi-agent orchestration with state transfer
- Context is near token limit and memory compression is needed

## Steps

### 1. Problem Analysis

- [ ] What state must persist across sessions?
- [ ] What is the expected duration of this work?
- [ ] What are the natural breakpoints for session handoffs?
- [ ] Is this a new memory need or continuing from previous work?
- [ ] Are there existing handoff files from prior sessions?

### 2. Scope Classification

Select one:

- **Task-level** — single feature, single bug, ≤1 day
- **Session-level** — multiple related tasks, multiple sessions
- **Project-level** — ongoing work, weeks/months

### 3. Strategy Selection

| Approach | When to use | Output |
|----------|-------------|--------|
| Ephemeral | One-shot, no cross-session need | (nothing) |
| Decision log | Complex reasoning, audit trail | `AI_DECISIONS.md` |
| Handoff file | Agent/session handoff | `AI_HANDOFF.md` |
| Working context | Multi-session builds, debugging | `AI_CONTEXT.md` |
| External storage | Long-lived agents, production | Per user setup |

### 4. Content Planning

Determine what to store in each memory entry:

- [ ] **Goal** — What is this session/agent trying to achieve?
- [ ] **Progress** — What has been done so far?
- [ ] **Decisions** — Key decisions made with rationale
- [ ] **Blockers** — Current blockers and what's needed to unblock
- [ ] **Next steps** — Clear ordered list of what comes next
- [ ] **Artifacts** — Paths to files, outputs, logs created
- [ ] **Context** — Key variables, state summaries

### 5. TTL Planning

- [ ] When will this memory become stale?
- [ ] Set explicit TTL (e.g., "2026-06-19" or "7 days from now")
- [ ] Plan to re-audit before TTL expires if work continues

### 6. Safety Check

- [ ] **No secrets** — No API keys, tokens, passwords
- [ ] **No personal data** — No PII, user credentials
- [ ] **No credentials** — No .env, tokens, auth info
- [ ] **Declare persistence** — Clear what is being persisted

## Output

A structured memory plan (written or appended to `AI_HANDOFF.md` / working
notes) with:

```
## Memory Plan
- Scope: {task | session | project}
- Strategy: {decision log | handoff file | working context | external}
- TTL: {date}
- Content includes: {goal, progress, decisions, blockers, next, artifacts}
- Safety passed: yes
```

## See also

- `/memory-audit` — audit existing memory
- `/memory-handoff` — perform handoff
- `docs/AGENTMEMORY_LITE_INTEGRATION.md` — full reference

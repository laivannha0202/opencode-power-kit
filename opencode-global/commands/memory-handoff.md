---
description: Safe memory handoff — state collection, AI_HANDOFF.md generation, integrity check, safety review, cleanup
---

# /memory-handoff

> **AgentMemory-lite command** — perform a safe state transfer between
> sessions or agents.

## When to use

- Ending a session that has work-in-progress
- Transferring context to another agent
- Multi-session feature build
- Complex debugging spanning multiple sessions
- Before taking a break from long-running work

## Steps

### 1. State Collection

Gather the current state:

- [ ] **Goal** — What is this work trying to achieve?
- [ ] **Progress summary** — What has been done? (quantified)
- [ ] **Completed items** — What is finished and verified?
- [ ] **Pending items** — What is started but not finished?
- [ ] **Decisions made** — Key technical/design decisions with rationale
- [ ] **Options rejected** — What approaches were considered but rejected?
- [ ] **Blockers** — Current blockers and what's needed to unblock
- [ ] **Next steps** — Ordered list of what comes next (most actionable first)
- [ ] **Artifacts** — Files created, outputs generated, logs saved
- [ ] **Context variables** — Branch, env, config, key variables

### 2. Structured Output

Write a handoff file (typically `AI_HANDOFF.md`):

```markdown
# AI Handoff — {session description}

## Goal
{clear statement of what this work aims to achieve}

## Progress
{what has been done, quantified}

## Completed
- [x] {item 1} — {verification detail}
- [x] {item 2}

## Pending
- [ ] {item 1} — {why not done}
- [ ] {item 2}

## Decisions
| # | Decision | Rationale |
|---|----------|-----------|
| 1 | {decision} | {why} |
| 2 | {decision} | {why} |

## Blockers
- {blocker 1} — {what's needed}
- {blocker 2}

## Next Steps
1. {first actionable step}
2. {second step}
3. {third step}

## Artifacts
- `{path/to/file}` — {description}
- `{path/to/output}` — {description}

## Context
- Branch: {git branch}
- Environment: {dev/staging/prod}
- Key variables: {any relevant config}

## TTL
This handoff is valid until: {date}

## Safety
- [ ] No secrets, credentials, or personal data included
- [ ] All file paths verified
- [ ] Integrity checked
```

### 3. Integrity Check

- [ ] All state captured? Nothing omitted?
- [ ] Decisions justified? Can the next agent understand why?
- [ ] Next steps actionable? Clear enough for a fresh agent?
- [ ] Artifact paths exist? Are they accessible?
- [ ] Context complete? Branch, env, variables?

### 4. Safety Review

- [ ] Scan for API keys, tokens, passwords, .env paths
- [ ] No PII or user credentials
- [ ] No secrets revealed in logs or output snippets
- [ ] File permissions match sensitivity

### 5. TTL Setting

- [ ] Set explicit expiry date
- [ ] Consider: when does this work become stale?
- [ ] Consider: what if the next session is days/weeks later?

### 6. Recipient Validation

- [ ] If another agent will read this: can they restore state?
- [ ] Are there implicit assumptions that need to be explicit?
- [ ] Is there enough context to pick up without re-reading everything?

### 7. Cleanup

- [ ] Remove any stale previous handoff files (if safe)
- [ ] Remove any working files that were session-specific
- [ ] Ensure `.gitignore` includes `AI_HANDOFF.md` patterns

## Safety Rules

- ❌ Never include secrets, credentials, or personal data
- ❌ Never persist one-shot/ephemeral state
- ❌ Never skip integrity check
- ✅ Always set TTL
- ✅ Always declare persistence
- ✅ Always verify artifact paths

## After Handoff

The receiving agent should:

1. Read the handoff file
2. Verify the state is restorable
3. Run `/memory-audit` to check completeness
4. Acknowledge receipt
5. Start from the first next step

## See also

- `/memory-plan` — plan memory strategy
- `/memory-audit` — audit existing memory
- `docs/AGENTMEMORY_LITE_INTEGRATION.md` — full reference

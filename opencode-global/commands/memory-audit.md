---
description: Audit memory state — inventory, completeness, staleness, integrity, safety, handoff readiness
---

# /memory-audit

> **AgentMemory-lite command** — audit existing session memory for quality,
> completeness, and safety.

## When to use

- Before a session handoff
- After a multi-session feature build
- When memory quality is in doubt
- When reviewing stale handoff files
- As part of post-task reflection

## Steps

### 1. Memory Inventory

- [ ] List all memory files in the project workspace:
  - `AI_HANDOFF.md`
  - `AI_DECISIONS.md`
  - `AI_CONTEXT.md`
  - Any JSON/other memory files
- [ ] Check `.gitignore` to ensure memory files are not tracked
  (memory files should be ephemeral — not committed)
- [ ] Note creation dates and last modified dates

### 2. Completeness Check

For each memory entry, verify:

- [ ] **Goal** — is there a clear stated goal?
- [ ] **Progress** — is progress quantified?
- [ ] **Decisions** — are key decisions documented with rationale?
- [ ] **Blockers** — are current blockers identified?
- [ ] **Next steps** — are next steps clear and ordered?
- [ ] **Artifacts** — are file paths and outputs referenced?

### 3. Staleness Check

- [ ] Does each entry have a TTL?
- [ ] Are any entries past their TTL?
- [ ] Should stale entries be updated or removed?
- [ ] Are there multiple conflicting memories?

### 4. Safety Review

- [ ] **Secrets scan** — Any API keys, tokens, passwords in memory?
- [ ] **Personal data** — Any PII or user credentials?
- [ ] **Credentials** — Any .env or auth info?
- [ ] **Log levels** — Are verbose logs in memory that should be excluded?

### 5. Integrity Check

- [ ] Are decisions justified? Can you trace the reasoning?
- [ ] Is progress verifiable? Can you check the claimed outputs exist?
- [ ] Are blockers accurate? Have any been resolved since writing?
- [ ] Are next steps actionable? Or are they vague?

### 6. Handoff Readiness

- [ ] If another agent picked up this memory, could they reconstruct state?
- [ ] Are there implicit assumptions that need to be explicit?
- [ ] Is the memory self-contained or does it reference external context?

## Verdict Table

| Dimension | Score (0-10) | Notes |
|-----------|:------------:|-------|
| Completeness | /10 | |
| Staleness | /10 | |
| Safety | /10 | |
| Integrity | /10 | |
| Handoff-ready | /10 | |
| **Overall** | **/10** | |

## See also

- `/memory-plan` — plan new memory strategy
- `/memory-handoff` — perform handoff with clean state
- `docs/AGENTMEMORY_LITE_INTEGRATION.md` — full reference

# Agent Kanban

> Lightweight kanban workflow for Hermes-lite task tracking.

## Overview

Agent Kanban is a minimal kanban system embedded in markdown.
No external tools, no database, no server. Just a file.

```
┌──────────┐    ┌──────────────┐    ┌───────┐    ┌──────┐
│ Backlog  │ →  │ In Progress  │ →  │ Verify│ →  │ Done │
│ (queue)  │    │ (working)    │    │ (QA)  │    │ (✓)  │
└──────────┘    └──────────────┘    └───────┘    └──────┘
                                                   ↑
                                              Blocked
                                              (halted)
```

## Board Format

The kanban board is stored in `.hermes/kanban.md`.

```markdown
# Kanban Board — 2026-06-11

## Backlog
- [P0] OPK-123: Implement login flow → @task
- [P1] OPK-456: Add error handling
- [P2] OPK-789: Refactor utils

## In Progress
- [P1] OPK-012: Build dashboard
  - Started: 2026-06-10
  - ETA: 2026-06-12

## Verify
- [P0] OPK-003: Fix auth bug
  - Assigned: @reviewer
  - Since: 2026-06-10

## Done
- [P0] OPK-001: Setup project ✓
  - Completed: 2026-06-09

## Blocked
- [P1] OPK-456: Payment integration
  - Reason: Waiting for API key
  - Since: 2026-06-08

## Stats
- Total tasks: 6
- In progress: 1
- Done this week: 3
- Blocked: 1
```

## Priority Levels

| Priority | Label | Criteria | Response Time |
|----------|-------|----------|--------------|
| P0 | 🔴 Critical | Blocking progress, security, production issue | Immediate |
| P1 | 🟡 Important | Feature, improvement, non-critical bug | This session |
| P2 | 🟢 Nice-to-have | Polish, refactor, technical debt | When time permits |

## Workflow

### Starting a Task
1. Add to Backlog: `/hermes-kanban add "task" --priority P1`
2. Move to In Progress: `/hermes-kanban start 1`
3. Work on it

### Completing a Task
1. Move to Verify: `/hermes-kanban verify 1`
2. Run tests / code review
3. If pass → `/hermes-kanban done 1`
4. If fail → fix, re-verify

### Blocking
1. When stuck: `/hermes-kanban block 1 --reason "Waiting for X"`
2. When unblocked: `/hermes-kanban unblock 1`

### Retro
1. At end of day/week: `/hermes-kanban retro`
2. Generates summary of what was done, what's pending, what was blocked
3. Use as input to `/hermes-reflect` or `/hermes-learn`

## Best Practices

### Do
- Keep tasks small (≤ 1 session each)
- Update board in real-time (not batch at end)
- Add blockers immediately
- Use retro to improve estimation

### Don't
- Don't add too many P0 items (max 2 at a time)
- Don't let Verify pile up (review quickly)
- Don't skip the retro step
- Don't use kanban for everything — only for complex work

## Integration with Hermes-lite

```
/hermes-kanban init          # Create board
/hermes-kanban add "..."     # Add task
... work ...
/hermes-kanban done 1        # Mark done
/hermes-reflect              # Reflect on what happened
```

The kanban board is one of the data sources for `/hermes-reflect` and
`/hermes-learn`. It provides objective data about what was done,
how long it took, and what was blocked.

## Example: Session Kanban

```markdown
# Kanban Board — OPK v1.9.0 Upgrade Session

## In Progress
- [P0] Create hermes-lite-strong.md agent → @self
  - Started: 2026-06-11

## Backlog
- [P1] Create 8 slash commands for Hermes-lite
- [P1] Create 3 helper scripts
- [P1] Create 4 docs
- [P0] Update VERSION to 1.9.0
- [P1] Update bin/opk with hermes commands
- [P1] Update verify.sh/ps1

## Done
(empty)

## Stats
- Total: 6
- In progress: 1
```

## Tips for Agents

When a human says "track this task" or "what's next":

1. If kanban board exists, check it before asking
2. If no kanban board, offer to create one: "/hermes-kanban init"
3. Update kanban as work progresses
4. Use kanban retro for status reports

This avoids the "what should I do next?" loop and gives both
human and agent a shared source of truth.

---
description: 'Lightweight kanban board: Backlog → In Progress → Verify → Done'
usage: '/hermes-kanban [action] [args]'
aliases: ['/kanban']
---

# /hermes-kanban

Lightweight kanban board cho task tracking.

## When To Use

- Khi bắt đầu complex task (multi-slice, multi-file)
- Khi cần theo dõi progress nhiều task
- Khi daily/weekly planning
- Khi cần visualize blockers

## Commands

### `/hermes-kanban init`
Tạo kanban board mới trong `.hermes/kanban.md`.

### `/hermes-kanban add <title> --priority P0|P1|P2`
Thêm task vào Backlog.

### `/hermes-kanban start <id>`
Move task từ Backlog → In Progress.

### `/hermes-kanban verify <id>`
Move task từ In Progress → Verify.

### `/hermes-kanban done <id>`
Move task từ Verify → Done.

### `/hermes-kanban block <id> --reason "..."`
Mark task as blocked + reason.

### `/hermes-kanban unblock <id>`
Unblock task.

### `/hermes-kanban show`
Show full board.

### `/hermes-kanban retro`
Generate weekly retro từ kanban board.

## Board Format

```markdown
# Kanban Board — [date]

## Backlog (P0/P1/P2)
- [P0] OPK-123: Task description → link-to-issue
- [P1] OPK-456: Another task

## In Progress
- [P1] OPK-789: Current work → @assignee
  - Started: 2026-06-11
  - ETA: 2026-06-12

## Verify
- [P2] OPK-101: Needs review

## Done
- [P0] OPK-001: Completed task ✓
  - Completed: 2026-06-10
  - Learning: [link to reflection]

## Blocked
- [P1] OPK-202: Waiting on dependency
  - Reason: External API down
  - Since: 2026-06-09
```

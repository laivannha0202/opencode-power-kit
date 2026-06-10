---
description: Initialize or check Supermemory for memory persistence across coding sessions.
subtask: admin
agent: any
---

# /supermemory-init — Supermemory Memory Persistence

## Description

Initialize Supermemory in the current project for persistent memory across
AI coding sessions. Supermemory remembers context, decisions, and progress
so you never lose your train of thought.

This command **never** installs packages directly. It uses the `opk supermemory`
CLI wrapper.

## Usage

```
/supermemory-init [--dry-run] [--yes]
```

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be done. Do not modify anything. |
| `--yes` | Skip confirmation prompts. |

## Workflow

1. **Check** if `supermemory` CLI is on PATH:
   - If not found, ask user: `opk supermemory install` first?
   - If user agrees, run `opk supermemory install`.
   - If user refuses, print instruction and stop.
2. If found, run `supermemory init` in the project directory.
3. Verify with `supermemory status`.

## Safety Rules

- **Never** install npm packages directly. Always use `opk supermemory install`.
- **Never** run `npm install -g` without user confirmation.
- **Never** modify `.env`, secrets, tokens, or API keys.
- **Never** run inside system directories (`/`, `/tmp`, `/usr`, `$HOME`).
- **Never** overwrite existing `.supermemory/` directory without confirmation.

## Examples

```
# Check and initialize
/supermemory-init

# Dry-run, see plan
/supermemory-init --dry-run

# Auto-install if missing, then init
/supermemory-init --yes
```

## Error Handling

| Error | Action |
|-------|--------|
| `node` not found | Print install instructions. Stop. |
| `npm` not found | Print install instructions. Stop. |
| `supermemory` not found | Offer to run `opk supermemory install`. |
| `supermemory init` fails | Print error output. Ask user to check docs. |

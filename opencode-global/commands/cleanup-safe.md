---
description: "Safely clean up temporary, debug, scratch, and reproduction files created by an agent. Never deletes tracked files. Default is dry-run; --apply only MOVES files into .opk-trash/, never deletes them. Use when the user says 'dọn rác', 'cleanup', 'xóa file bug tự tạo'."
---

# /cleanup-safe

Safely clean up temporary, debug, scratch, and reproduction files that an
agent (or a developer) may have left behind. Backed by
`scripts/cleanup-agent-artifacts.sh`.

## When to use

- The user asks to clean up temp/debug/repro files.
- The user asks to "dọn rác" / "cleanup" / "xóa file bug tự tạo".
- After long sessions, the repo has many `.tmp`, `.bak`, `repro-*`, etc.

## Hard safety rules (non-negotiable)

1. Run `git status --short` BEFORE and AFTER the cleanup.
2. Only consider **untracked** files (git status `??`).
3. Tracked files are NEVER touched, in any directory.
4. The following directories are PROTECTED — files inside them are NEVER
   touched, even if they match a pattern:
   `src/`, `app/`, `backend/`, `frontend/`, `prisma/`, `migrations/`,
   `public/`, `docs/`, `.git/`, `.opencode/`, `.agents/`, `_bmad/`.
5. NEVER use `git clean -fd`, `git reset --hard`, `rm -rf`, or force push.
6. Default mode is **dry-run**. No file is moved or deleted.
7. With `--apply`, files are only **MOVED** into
   `.opk-trash/YYYYMMDD-HHMMSS/`. They are NOT deleted. Recovery is just
   `mv .opk-trash/<ts>/* .`.

## Allowed patterns

The script only considers files matching one of:

- `.tmp/`
- `.test/`
- `.opk-scratch/`
- `*.tmp`
- `*.bak`
- `*.orig`
- `*.log`
- `repro-*.*`
- `debug-*.*`

## Workflow

1. Run `git status --short` and save the output (call it `BEFORE`).
2. Run the cleanup script in dry-run mode:
   ```bash
   bash scripts/cleanup-agent-artifacts.sh --dry-run
   ```
3. Show the user the list of files that WOULD be moved.
4. Ask the user explicitly: "Apply? This will move files into
   `.opk-trash/<ts>/`. Nothing is deleted."
5. If the user says yes, run:
   ```bash
   bash scripts/cleanup-agent-artifacts.sh --apply
   ```
6. Run `git status --short` again (call it `AFTER`).
7. Write `CLEANUP_REPORT.md` in the repo root with:
   - Timestamp
   - Files discovered (matched patterns)
   - Files moved (with destination)
   - Files skipped (with reason, e.g. protected dir / not in allowlist)
   - Diff summary (BEFORE vs AFTER)
8. Show the report path to the user.

## Report template (`CLEANUP_REPORT.md`)

```markdown
# Cleanup Report

- Timestamp: 2026-06-06T08:19:03Z
- Mode: apply (or dry-run)
- Script: scripts/cleanup-agent-artifacts.sh
- Trash dir: .opk-trash/20260606-081903/

## Files discovered
- .tmp/junk
- a.bak
- debug-test.log
- scratch.tmp

## Files moved
- .tmp/junk -> .opk-trash/20260606-081903/.tmp/junk
- a.bak -> .opk-trash/20260606-081903/a.bak
- debug-test.log -> .opk-trash/20260606-081903/debug-test.log
- scratch.tmp -> .opk-trash/20260606-081903/scratch.tmp

## Files skipped
- src/important.tmp (reason: protected directory)
- AGENTS.md (reason: not in allowlist)

## Git status
- BEFORE: 5 untracked
- AFTER:  0 untracked (1 new trash dir)
```

## What to NEVER do

- Do not delete files directly. Always go through the script.
- Do not invent extra patterns. The allowlist is fixed.
- Do not touch protected directories, even if the user insists.
- Do not commit the trash directory. Add `.opk-trash/` to `.gitignore`
  if it is not already ignored.

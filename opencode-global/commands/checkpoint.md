---
description: "Create a safety checkpoint before large changes. Captures the current working tree as a patch file under .opk-checkpoints/ so it can be restored or reviewed. Never commits, never resets, never force-pushes. Use when the user says 'checkpoint', 'lưu lại trước khi sửa', or before risky refactors."
---

# /checkpoint

Create a safety checkpoint of the current working tree before doing a
large or risky change. Backed by plain `git diff` output, so it does not
require any extra tooling.

## When to use

- Before a large refactor.
- Before editing many files in a sweep.
- Before running unfamiliar build, migration, or codegen steps.
- Whenever the user says "checkpoint", "save before I edit", or wants
  a fall-back point.

## Behavior

1. Run `git status --short` to record the current state.
2. Create the directory `.opk-checkpoints/` if it does not exist.
3. Generate a timestamp `YYYYMMDD-HHMMSS` (UTC, second precision).
4. Write the current diff to:
   `.opk-checkpoints/<ts>.patch`
   using `git diff` (tracked + staged) and a separate section for
   `git status --porcelain`.
5. If a working tree diff is empty, still write the file with a header
   noting "clean working tree at checkpoint time".
6. Also write a short human summary to:
   `.opk-checkpoints/<ts>.summary.md`
   with:
   - Timestamp
   - Branch + HEAD commit
   - Status before / after (same, just recorded)
   - Files that would be affected (if any)
   - Note: "checkpoint only — nothing was committed"
7. Print the paths of the created files to the user.

## Hard rules

- DO NOT commit. The checkpoint is intentionally untracked.
- DO NOT run `git reset`, `git clean`, or `rm -rf`.
- DO NOT force push.
- DO NOT modify tracked files during the checkpoint itself.
- `.opk-checkpoints/` SHOULD be added to `.gitignore` if not already.

## Restore

To restore a checkpoint manually:

```bash
# Inspect first
cat .opk-checkpoints/<ts>.summary.md
cat .opk-checkpoints/<ts>.patch

# Apply the patch on top of the current tree
git apply --check .opk-checkpoints/<ts>.patch   # dry run
git apply .opk-checkpoints/<ts>.patch            # apply
```

## Optional companion

You can also call `/cleanup-safe` or `/handoff-save` in combination:

- `/checkpoint` — snapshot the tree before risky work.
- `/handoff-save` — refresh `AI_HANDOFF.md` for a future session.
- `/cleanup-safe` — clean temp files after the work.

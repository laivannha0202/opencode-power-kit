---
description: "Create or update AI_HANDOFF.md in the project root so work can resume cleanly across sessions. Captures goal, stack, current task, changes, verification, and next steps. Use when the user says 'lưu lại để mai làm tiếp', 'handoff', or before pausing long work."
---

# /handoff-save

Create or update `AI_HANDOFF.md` in the repo root so a future session
(including a different agent) can pick up the work without losing context.

## Behavior

1. Check if `AI_HANDOFF.md` exists at the repo root.
2. If it does NOT exist, copy the template from
   `templates/AI_HANDOFF.md` (shipped with opencode-power-kit) and fill
   it in based on the current state.
3. If it DOES exist, update it conservatively:
   - DO NOT erase sections the user has filled in.
   - Only refresh the dynamic sections: "Current task", "What changed",
     "Files changed", "Commands run", "Tests/verification", "Next
     recommended steps".
   - Keep the user's prose. Just patch in the new evidence.
4. If `git status` shows meaningful uncommitted work, include a short
   note about it (without leaking secrets).

## Template (used when no `AI_HANDOFF.md` exists)

The shipped template is `templates/AI_HANDOFF.md`. It contains these
sections:

- Project goal
- Stack
- Current task
- What changed
- Files changed
- Commands run
- Tests / verification
- Known issues
- Next recommended steps

## Installer behavior

The installer copies `templates/AI_HANDOFF.md` into the target project
ONLY if the project does not already have an `AI_HANDOFF.md`. It must
NEVER overwrite an existing handoff.

## What to write in each section

- **Project goal** — one or two lines. What is this project for?
- **Stack** — language, framework, DB, infra. Keep it short.
- **Current task** — the single next thing being worked on.
- **What changed** — bullet list of meaningful changes since last
  handoff. Link to commit SHAs if available.
- **Files changed** — paths only, with one-line purpose each.
- **Commands run** — exactly the commands that were executed, so they
  can be re-run safely.
- **Tests / verification** — what was tested, what passed, what was
  not.
- **Known issues** — bugs, TODOs, or things the next agent should be
  careful about.
- **Next recommended steps** — short ordered list.

## Safety rules

- Do not include secrets, API keys, tokens, or `.env` content.
- Do not include full file contents. Paths and one-liners only.
- Do not commit `AI_HANDOFF.md` unless the user asks. It is fine to
  keep it untracked or in the repo depending on team preference; the
  default is to NOT auto-commit.

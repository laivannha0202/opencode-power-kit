# OpenCode Power Kit Reference

Runtime instructions live in root `AGENTS.md`, which OpenCode discovers automatically.
This file is intentionally not listed in `opencode.json.instructions`, so the same rules are not loaded twice.

Useful commands:

- `opk mode show`: inspect resolved project permission mode.
- `opk mode power`: merge the Power profile into root `opencode.json`.
- `opk mode safe`: merge the Safe profile without replacing custom keys.
- `opk mode migrate`: migrate legacy `.opencode/opencode.json` safely.
- `opk permissions doctor`: report config paths, environment overrides and agent conflicts.
- `opk auto`: start an unattended OpenCode session only when effective mode is POWER.
- `opk run-auto "prompt"`: run one unattended prompt without shell evaluation.

See `README.md` and `docs/COMMANDS_REFERENCE.md` for installation, migration and rollback details.

# OpenCode Power Kit Reference

Runtime instructions live in root `AGENTS.md`, which OpenCode discovers automatically.
This file is intentionally not listed in `opencode.json.instructions`, so the same rules are not loaded twice.

Useful commands:

- `opk mode show`: inspect resolved permissions in the exact `pwd -P` project, not the Git top-level.
- `opk mode power`: merge the Power profile into root `opencode.json`.
- `opk mode safe`: merge the Safe profile without replacing custom keys.
- `opk mode migrate`: migrate legacy `.opencode/opencode.json`; use `--normalize-jsonc` only to explicitly normalize comments after backup.
- `opk permissions doctor`: report config paths, environment overrides and agent conflicts.
- `opk auto`: start an unattended session only when the full Power contract passes with zero effective ask rules.
- `opk run-auto "prompt"`: run one unattended prompt without shell evaluation.

See `README.md` and `docs/COMMANDS_REFERENCE.md` for installation, migration and rollback details.

# Hermes-lite Integration Guide

> opencode-power-kit v1.9.0
> Inspired by [Hermes Agent](https://github.com/NousResearch/hermes-agent) — NousResearch

## Overview

Hermes-lite is an **optional** meta-cognitive self-improvement component for OPK.
It distills key concepts from Hermes Agent into a lightweight, OPK-native workflow:

- **Learning loop** — Observe → Reflect → Adjust → Verify → Persist
- **Skill improvement** — Structured practice for code, writing, and reflection
- **Memory policy** — Context management, eviction, consolidation
- **Context budget** — Token-aware task planning
- **Lightweight kanban** — Visual task tracking
- **Tool surface audit** — Tool usage analysis
- **Remote backend review** — Pattern research from AI ecosystem

## Installation

Hermes-lite is **bundled** in OPK v1.9.0. No additional installation needed.

```bash
# Check status
opk hermes status

# Verify all components
bash scripts/check-hermes-lite.sh

# Run self-audit
bash scripts/audit-hermes.sh --yes
```

## Components

| Component | Location | Description |
|-----------|----------|-------------|
| Agent | `opencode-global/agents/hermes-lite-strong.md` | Meta-cognitive agent definition |
| 8 commands | `opencode-global/commands/hermes-*.md` | Slash commands for each concept |
| 3 scripts | `scripts/audit-hermes.sh`, `scripts/check-hermes-lite.sh`, `scripts/hermes-learning-capsule.sh` | CLI tools |
| 4 docs | `docs/HERMES_*.md`, `docs/LEARNING_LOOP.md`, `docs/AGENT_KANBAN.md` | Documentation |

## Slash Commands

| Command | Purpose | When To Use |
|---------|---------|-------------|
| `/hermes-reflect` | Post-task reflection | After complex tasks |
| `/hermes-skill` | Skill improvement practice | When improving code/writing |
| `/hermes-kanban` | Lightweight kanban board | Task tracking |
| `/hermes-memory` | Memory policy review | Context full / stale memory |
| `/hermes-budget` | Context/token budget check | Before large tasks |
| `/hermes-audit` | Tool surface audit | When optimizing workflows |
| `/hermes-learn` | Full learning loop cycle | Sprint/milestone ends |
| `/hermes-research` | Backend pattern research | When learning new patterns |

## Concepts from Hermes Agent

### What stays (OPK-native, optional)
- Self-improvement cycle
- Structured reflection
- Memory management
- Context awareness
- Task tracking via kanban
- Tool surface analysis
- Pattern research

### What is removed (not implemented)
- Full Hermes Agent runtime
- MCP server infrastructure
- Gateway (Telegram/Discord/Slack)
- Cron/scheduler system
- Remote LLM auto-calling
- Vector database
- Plugin system
- Auto-install / auto-update

### Why the difference

OPK's Hermes-lite focuses on **meta-cognitive process** — the *thinking* part of
self-improvement. Full Hermes Agent focuses on **infrastructure** — the *execution*
part. Both are valid, but for OPK's use case (AI-assisted development), the
process approach is lighter, safer, and more composable with existing components.

## Usage Patterns

### Solo Developer
```
/hermes-kanban init          # Start tracking tasks
/hermes-kanban add "..." --priority P0
... work ...
/hermes-reflect              # Reflect after completion
```

### Sprint End
```
/hermes-learn                # Full learning cycle
/hermes-kanban retro         # Retro from kanban board
```

### Performance Optimization
```
/hermes-budget check         # Check context pressure
/hermes-memory audit         # Audit memory usage
/hermes-audit session        # Audit tool usage
```

### Quality Improvement
```
/hermes-skill code-quality   # Practice code quality
/hermes-research comparison  # Research best practices
```

## File Structure (when active)

```
.hermes/
├── kanban.md             # Active kanban board (via /hermes-kanban)
├── config.yml            # Hermes-lite config (user-managed)
├── learnings/            # Individual learning records
│   └── YYYY-MM-DD-topic.md
└── retro/                # Retrospective records
    └── YYYY-MM-DD-task-retro.md
```

## Integration with Other OPK Components

| Component | How Hermes-lite Uses It |
|-----------|------------------------|
| `build-strong` | Spawns for implementation after reflection/adjustment |
| `ecc-lite-strong` | Complements: ECC-lite for code quality, Hermes-lite for process quality |
| `agent-router` | Routes `/hermes-*` commands |
| `taste-ui-strong` | Not related — separate domain |
| `verify.sh` | Checks Hermes-lite component integrity |

## Troubleshooting

**Q: Hermes-lite is auto-running / too noisy.**
A: It should not auto-run. It only activates on explicit `/hermes-*` commands.
If it triggers unexpectedly, check `build-strong.md` — Hermes-lite policy there
is for *other agents invoking it*, not self-triggering.

**Q: `.hermes/` directory not creating.**
A: Hermes-lite never creates `.hermes/` without user approval. Run
`/hermes-kanban init` or `/hermes-reflect` and confirm the prompt.

**Q: Conflict with ECC-lite.**
A: They can coexist. ECC-lite focuses on code quality gates and verification.
Hermes-lite focuses on meta-cognition and process improvement. Different domains.

## Related

- [LEARNING_LOOP.md](LEARNING_LOOP.md) — Detailed learning loop guide
- [AGENT_KANBAN.md](AGENT_KANBAN.md) — Kanban workflow guide
- [AGENTS_REFERENCE.md](AGENTS_REFERENCE.md) — Agent reference
- [COMMANDS_REFERENCE.md](COMMANDS_REFERENCE.md) — Command reference
- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) — Script reference

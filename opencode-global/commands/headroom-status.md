---
description: Check Headroom-lite integration status — components, routing, related tools
---

# /headroom-status

Check Headroom-lite integration status in opencode-power-kit.

## Cách dùng

```
/headroom-status
/headroom-status --verbose
```

## Checks performed

### 1. Component presence

| Component | Status |
|-----------|:------:|
| `docs/HEADROOM_LITE_INTEGRATION.md` | ✅ / ❌ |
| `opencode-global/skills/headroom-lite/SKILL.md` | ✅ / ❌ |
| `opencode-global/commands/headroom-plan.md` | ✅ / ❌ |
| `opencode-global/commands/headroom-audit.md` | ✅ / ❌ |
| `opencode-global/commands/headroom-status.md` | ✅ / ❌ |

### 2. Agent routing integration

| Reference | Status |
|-----------|:------:|
| `opencode-global/agents/build-strong.md` contains headroom-lite | ✅ / ❌ |
| `opencode-global/commands/agent-router.md` contains headroom entries | ✅ / ❌ |

### 3. Related tool detection

| Tool | Status | Purpose |
|------|:------:|---------|
| `rtk` | ✅ detected / ❌ not found | Token counting |
| `tokscale` | ✅ detected / ❌ not found | Token cost viz |
| `rag-lite` skill | ✅ present / ❌ missing | RAG retrieval quality |

### 4. THIRD_PARTY / CHANGELOG

| Reference | Status |
|-----------|:------:|
| `THIRD_PARTY.md` contains chopratejas/headroom | ✅ / ❌ |
| `CHANGELOG.md` contains v1.9.2 | ✅ / ❌ |

## Workflow

1. Check each component file exists.
2. Check agent routing references.
3. Detect complementary tools on PATH.
4. Verify THIRD_PARTY.md and CHANGELOG.md references.
5. Report summary with ✅ / ⚠️ / ❌ per check.

## Output

A status report with:
- Component health (all files present / missing)
- Integration health (routing references up to date)
- Related tools available
- Any action items if components are missing

## Related

- `/headroom-plan` — plan a compression strategy
- `/headroom-audit` — audit existing compression quality
- `/rag-eval` — evaluate RAG quality (complementary)
- `opk doctor` — full kit diagnostic

---
description: 'Remote backend review: research patterns từ ecosystem (Hermes Agent, AI best practices) và đề xuất cải tiến OPK'
usage: '/hermes-research [topic]'
aliases: ['/backend-research', '/hermes-patterns']
---

# /hermes-research

Remote backend pattern research và OPK improvement suggestions.

## When To Use

- Khi muốn research best practices từ Hermes Agent ecosystem
- Khi muốn so sánh pattern giữa các AI backends
- Khi cần đề xuất cải tiến OPK dựa trên learning từ research
- Khi muốn audit OPK components against Hermes Agent concepts

## Research Topics

### `/hermes-research learning-loop`
Research learning loop patterns:
- Hermes Agent self-evolution cycle
- Cải tiến learning persistence
- Context management strategies

### `/hermes-research tool-patterns`
Research tool usage patterns:
- Tool surface optimization
- Agent delegation patterns
- Skill composition patterns

### `/hermes-research memory`
Research memory management:
- Eviction strategies
- Consolidation techniques
- Priority-based memory systems

### `/hermes-research quality`
Research quality improvement:
- Code review patterns
- Validation strategies
- Testing methodologies

### `/hermes-research comparison`
Compare OPK vs Hermes Agent concepts:
- What OPK has that Hermes doesn't
- What Hermes has that OPK could learn
- What both do differently

## Output

```markdown
## Research: [topic]

### Key Findings
- [finding 1]
- [finding 2]
- [finding 3]

### Applicable to OPK
| Pattern | OPK Status | Effort | Impact |
|---------|-----------|--------|--------|
| Learning loop | ✅ Has `/hermes-*` | Low | High |
| Memory policy | ⚠️ Basic todo | Medium | Medium |
| Tool auditing | ⚠️ `/hermes-audit` | Low | High |

### Recommendations
1. [action] — [rationale] — [effort]
2. [action] — [rationale] — [effort]

### References
- [link to Hermes Agent concept]
- [link to article/paper]
```

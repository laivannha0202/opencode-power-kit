---
description: 'Tool surface audit: phân tích tool usage pattern, tìm tool gaps, đề xuất tối ưu'
usage: '/hermes-audit [scope]'
aliases: ['/tool-audit']
---

# /hermes-audit

Tool surface audit cho OPK agents.

## When To Use

- Khi muốn tối ưu tool usage
- Khi suspect agent dùng tool không hiệu quả
- Khi muốn review agent configuration
- Khi thêm agent mới cần review tool access

## Scopes

### `/hermes-audit agent <agent-name>`
Audit một agent cụ thể:
- Tools available
- Tools actually used (from session context)
- Frequent errors per tool
- Biases (overused/underused tools)
- Missing tools

### `/hermes-audit session`
Audit session hiện tại:
- Tool call frequency
- Success/error ratio
- Average tokens per tool call
- Redundant patterns
- Tool combinations

### `/hermes-audit skills`
Audit skills registry:
- Which skills are installed
- Which skills are used
- Skill usage frequency
- Skill gaps (missing)
- Skill overlap/conflicts

## Analysis Metrics

```markdown
### Tool Frequency
| Tool | Calls | Success | Errors | Avg Tokens |
|------|-------|---------|--------|-----------|
| Read | 42 | 100% | 0 | 150 |
| Bash | 28 | 85% | 4 | 200 |
| Write | 15 | 100% | 0 | 300 |
| Grep | 8 | 100% | 0 | 50 |
```

### Improvement Suggestions
- Tool X overused → có thể optimize
- Tool Y underusedY → cần train agent dùng
- Tool Z error rate cao → cần review cách dùng
- Missing tool [W] → nên thêm vào agent config

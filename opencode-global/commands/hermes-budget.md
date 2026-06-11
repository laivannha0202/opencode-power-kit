---
description: 'Context/budget pressure: token estimation, context monitoring, compression strategies, checkpoint recommendation'
usage: '/hermes-budget [action]'
aliases: ['/context-check', '/token-budget']
---

# /hermes-budget

Context window và token budget management.

## When To Use

- Khi khởi tạo session mới với task phức tạp
- Khi cảm thấy context đang đầy
- Khi cần quyết định: tiếp tục hay checkpoint + new session
- Khi muốn tối ưu token usage

## Actions

### `/hermes-budget estimate`
Estimate token consumption cho task sắp làm:
- Expected files to read
- Expected code to write
- Conversation length estimate
- Recommended max slices per session

### `/hermes-budget check`
Check current context pressure:
- Messages used vs max
- Estimated token usage (ước lượng)
- Number of files in context
- Recommended actions (continue/checkpoint/split)

### `/hermes-budget compress`
Đề xuất compression strategies:
- Summarize verbose conversation
- Consolidate file references
- Compress error logs
- Use structured format thay vì prose

### `/hermes-budget checkpoint`
Khuyến nghị checkpoint khi:
- Token budget > 70% used
- Task còn > 3 slices
- Cần switch context

## Token Estimation Guide

| Item | Estimated Tokens |
|------|-----------------|
| Per file read (100 lines) | ~300 |
| Per code diff (10 lines) | ~80 |
| Per conversation turn | ~200 |
| Per error message | ~100 |
| Per file write (100 lines) | ~400 |
| Per image/screenshot | ~1000 |

## Output

```markdown
## Budget Report

### Task: [description]
- Estimated: N tokens
- Available: N tokens
- Usage: N%

### Recommendations
- [ ] Compress context nếu > 70%
- [ ] Checkpoint + new session nếu > 85%
- [ ] Split task thành N sub-tasks
- [ ] Archive completed items

### Compression Opportunities
- [area 1] → [estimated savings]
- [area 2] → [estimated savings]
```

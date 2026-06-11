---
description: 'Post-task reflection: Observe → Reflect → Adjust → Verify → Persist cycle cho task vừa hoàn thành'
usage: '/hermes-reflect [task-name]'
aliases: ['/hermes-retro']
---

# /hermes-reflect

Post-task reflection using Hermes-lite learning loop.

## When To Use

- Sau khi hoàn thành task phức tạp (>3 slices, >1 hour)
- Khi task gặp nhiều error/unexpected behavior
- Khi muốn capture learning từ task vừa làm
- Daily/weekly engineering retro

## Workflow

### 1. Collect
Thu thập dữ liệu từ task vừa hoàn thành:

- Task description và goal
- Files changed và diff summary
- Errors encountered và resolutions
- Tool usage pattern
- Time estimate vs actual
- Unexpected discoveries

### 2. Analyze

- What went well? (patterns to keep)
- What went wrong? (patterns to fix)
- What was surprising? (edge cases, assumptions)
- What could be faster? (bottlenecks, tool choice)
- What was unnecessary? (scope creep, over-engineering)

### 3. Adjust

- 1 adjustment cụ thể có thể áp dụng ngay
- 1 pattern để lưu vào learning
- 1 tool/process change đề xuất

### 4. Persist (với user approval)

- Ghi learning vào `$PROJECT/.hermes/learnings/` nếu có
- Cập nhật CLAUDE.md nếu workflow change
- Ghi retro vào `$PROJECT/.hermes/retro/`

## Output Format

```markdown
## Reflection: [task-name]

### Observations
- [what happened]

### What Worked
- [keep these patterns]

### What Didn't
- [fix these patterns]

### Surprises
- [edge cases, assumptions wrong]

### Adjustments
- [immediate action] → [expected impact]

### Learnings
- [learning 1]
- [learning 2]
```

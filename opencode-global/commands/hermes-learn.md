---
description: 'Full learning loop cycle: Observe → Reflect → Adjust → Verify → Persist'
usage: '/hermes-learn [focus]'
aliases: ['/learn-loop', '/learning-cycle']
---

# /hermes-learn

Full Hermes-lite learning loop cycle.

## When To Use

- Khi kết thúc sprint / milestone
- Khi muốn systematic improvement
- Khi user nói "what can we improve?"
- Weekly engineering retro

## Workflow

### Step 1: Observe (thu thập)
```markdown
- Session data: duration, files changed, errors
- Git history: commits, branches, diffs
- Tool usage: what was used, what wasn't
- Context: memory state, decisions made
```

### Step 2: Reflect (phân tích)
```markdown
- Patterns in errors
- Patterns in success
- Bottlenecks
- Edge cases uncovered
- Assumptions validated/invalidated
```

### Step 3: Adjust (cải tiến)
```markdown
- Quick wins (fix ngay, < 2 phút)
- Process improvements (cần plan)
- Tool/skill recommendations
```

### Step 4: Verify (kiểm tra)
```markdown
- Applied adjustments work?
- Test pass? Lint pass?
- No regression?
```

### Step 5: Persist (lưu trữ)
```markdown
- Ghi learning vào `.hermes/learnings/`
- Cập nhật workflow docs
- Share patterns với team
```

## Output

```markdown
## Learning Cycle: [date]

### Observations
- Session: [N tasks, N files, N duration]
- Errors: [N total, top 3]
- Patterns: [N identified]

### Analysis
- What worked: [patterns to keep]
- What didn't: [patterns to fix]
- Surprises: [assumptions wrong]

### Adjustments
Applied:
1. [change] → [result]
2. [change] → [result]

Proposed:
3. [change] — needs planning
4. [change] — needs discussion

### Learnings Captured
- [learning 1]
- [learning 2]

### Next Review
- Recommended: [date/condition]
```

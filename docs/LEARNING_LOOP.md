# Learning Loop

> Hermes-lite meta-cognitive framework for continuous improvement.

## The Cycle

```
   Observe
     ↓
   Reflect
     ↓
   Adjust
     ↓
   Verify
     ↓
   Persist
     ↓
   (repeat)
```

## Phase 1: Observe

**Goal:** Collect objective data about what happened.

### What to collect

| Data Point | Source | Example |
|-----------|--------|---------|
| Task duration | Session start/end | "2h 15m" |
| Files changed | `git diff --stat` | "12 files, +340 -89" |
| Errors encountered | Session history | "3 type errors, 1 build fail" |
| Tool calls | Agent trace | "Read 15x, Bash 8x, Write 5x" |
| Context switches | Tabs / branches | "3 context switches" |
| Decisions made | Conversation | "Chose X over Y because Z" |

### Template

```markdown
## Observation

Task: [description]
Duration: [time]
Files: [N changed, +N -N]
Errors: [N total, top 3]

Patterns noticed:
- [pattern 1]
- [pattern 2]
```

## Phase 2: Reflect

**Goal:** Analyze observations to find patterns, root causes, and opportunities.

### Questions to ask

1. **What went well?**
   - What patterns should I keep?
   - What tools/processes helped most?
   - What did I learn?

2. **What didn't go well?**
   - What patterns should I fix?
   - What was slow, confusing, or error-prone?
   - What assumptions were wrong?

3. **What was surprising?**
   - What edge cases did I discover?
   - What worked differently than expected?
   - What capabilities did I not know I had?

4. **What could be faster?**
   - Where did I spend most time?
   - Where was I waiting (CI, review, thinking)?
   - What can be automated?

### Cognitive Biases to Avoid

| Bias | Mitigation |
|------|-----------|
| **Recency bias** | Look at whole session, not just last 5 minutes |
| **Confirmation bias** | Actively look for evidence against your hypotheses |
| **Hindsight bias** | Record observations BEFORE analyzing |
| **Self-serving bias** | Be honest about mistakes |

## Phase 3: Adjust

**Goal:** Apply 1-3 concrete improvements.

### Types of Adjustments

| Type | Example | Effort |
|------|---------|--------|
| **Quick win** | Fix lint config | < 2 min |
| **Process change** | Start with /hermes-kanban before tasks | < 10 min |
| **Tool change** | Add new agent/skill | < 30 min |
| **Behavior change** | Practice structured reflection | Ongoing |

### Adjustment Template

```markdown
## Adjustment

Problem: [what needs fixing]
Root cause: [why it happens]
Fix: [what to do]
Verification: [how to know it worked]
Effort: [time estimate]
```

## Phase 4: Verify

**Goal:** Confirm the adjustment actually improved things.

### Verification Methods

1. **Direct comparison:** Before/after metrics
2. **A/B test:** Try both ways, compare
3. **Subjective assessment:** "Does this feel better?"
4. **Peer review:** Ask another developer

### Verification Template

```markdown
## Verification

Adjustment: [what was changed]
Before: [metric/value]
After: [metric/value]
Result: ✅ Improved / ⚠️ Neutral / ❌ Worse
Notes: [anything unexpected]
```

## Phase 5: Persist

**Goal:** Save learnings so they're reusable.

### Storage Options

| Location | What to Store | When |
|----------|--------------|------|
| `.hermes/learnings/` | Individual learning record | Each cycle |
| `CLAUDE.md` | Workflow rules | When pattern is confirmed |
| `docs/` | Shared patterns | When relevant to team |
| `serena memory` | Agent-level memory | When pattern is stable |

### Learning Record Template

```markdown
---
date: YYYY-MM-DD
topic: [topic]
type: learning
confidence: high/medium/low
---

# Learning: [title]

## What I Learned
[description]

## Context
[when/why this came up]

## Evidence
[what supports this]

## Action
[what to do differently]

## Related
- [link to related learning]
- [link to relevant code]
```

## Running a Learning Loop

### Quick (5 min)
```
/hermes-reflect "quick retro"
```
Captures: observation + 1 adjustment.

### Standard (15 min)
```
/hermes-reflect "task-name"
/hermes-skill reflection
```
Captures: full reflect cycle + skill practice.

### Deep (30 min)
```
/hermes-learn
/hermes-memory audit
/hermes-audit session
```
Captures: full cycle + memory audit + tool audit.

## Examples

### Example: Learning Loop After Bug Fix

**Observation:** Fixed a race condition in async handler.
Took 45 min. Root cause: missing `await`.
Error happened 3 times in past week.

**Reflection:**
- Went well: Found root cause through systematic debugging
- Didn't go well: Should have caught this in review
- Surprising: Same bug pattern in 2 other files

**Adjustment:** Add `no-floating-promises` ESLint rule.
Verify: Run lint on affected files.
Effort: 5 min.

**Verification:** Rule caught 2 more instances in other files. ✅

**Persist:** Save ESLint config. Add note to coding standards.

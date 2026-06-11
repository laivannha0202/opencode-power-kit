---
description: 'Memory policy review: audit context memory, đề xuất eviction/consolidation/prioritization'
usage: '/hermes-memory [action]'
aliases: ['/memory-audit']
---

# /hermes-memory

Context memory policy review.

## When To Use

- Khi context window đầy / token budget cao
- Khi có nhiều memory/notes không còn relevant
- Khi cần consolidate nhiều small notes thành pattern
- Khi muốn tối ưu prompt efficiency

## Actions

### `/hermes-memory audit`
Scan current context và memory để identify:
- Duplicate information
- Stale/outdated notes
- Contradictory instructions
- Low-value details (noise)

### `/hermes-memory evict`
Đề xuất items cần xoá khỏi context:
- Temporary state (đã xong)
- Debug info (đã fix)
- Old decisions (đã thay thế)
- Irrelevant context

### `/hermes-memory consolidate`
Gộp nhiều items nhỏ thành pattern lớn:
- Similar instructions → unified rule
- Repeated learnings → consolidated pattern
- Multiple constraints → structured policy

### `/hermes-memory prioritize`
Sắp xếp memory items theo importance:
- P0: Critical rules, security policies
- P1: Active project context
- P2: Nice-to-know, references
- P3: Historical, can be evicted

## Output

```markdown
## Memory Audit

### Current State
- Total memory items: N
- Estimated tokens: N
- Critical items: N
- Stale items: N

### Items to Evict
- [item 1] → stale since [date]
- [item 2] → superseded by [item 3]

### Items to Consolidate
- [items A,B,C] → [new consolidated rule]

### Priority Changes
- [item X] P1 → P0 (critical)
- [item Y] P1 → P3 (stale)
```

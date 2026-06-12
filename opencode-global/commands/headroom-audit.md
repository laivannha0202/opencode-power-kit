---
description: Audit existing context/token usage — consumption, compression opportunities, evidence integrity
---

# /headroom-audit

Audit an existing session's context usage and compression quality.

## Cách dùng

```
/headroom-audit <mô tả context cần audit>
/headroom-audit "kiểm tra token consumption của session hiện tại"
```

## Workflow

### 1. Token consumption analysis

- Total tokens used so far
- Breakdown by content type (system prompt, user, tool output, history)
- Biggest token consumers identified
- Trend: is consumption growing linearly or accelerating?

### 2. Compression opportunity scan

For each content type in the session:

| Content type | Current size | Compressible? | Potential savings |
|-------------|:-----------:|:-------------:|:-----------------:|
| Tool stdout/stderr | N tokens | ✅ | ~50-70% |
| RAG chunks | N tokens | ✅ | ~30-60% |
| Chat history | N tokens | ✅ | ~40-60% |
| Log output | N tokens | ✅ | ~60-80% |
| Error messages | N tokens | ❌ | 0% |
| Code blocks | N tokens | ❌ | 0% |

### 3. Evidence integrity check

If compression was already applied:
- Was compression declared? (what, why, what was removed)
- Are key numbers, dates, names, IDs preserved?
- Are error codes and exit statuses preserved?
- Is the compression declaration itself visible?

### 4. Budget compliance

- Current budget: N tokens
- Current usage: M tokens
- Remaining: N - M tokens
- Reserve (≥25%): is there enough room for the model's response?
- If over budget: how much needs to be compressed?

### 5. Compression quality review

- Was the right strategy used for each content type?
- Was evidence preserved appropriately?
- Is the compression level appropriate (not over/under compressed)?
- Are there alternative strategies that would preserve more evidence?

### 6. Recommendations

- What to compress next (if over budget)
- What to avoid compressing (critical content)
- Strategy adjustments for future sessions
- Combine with RAG-lite if retrieval quality needs review too

## Output

An audit report with:
- Token consumption breakdown
- Compression opportunities table
- Evidence integrity verdict (PASS / WARN / FAIL)
- Budget compliance status
- Recommendations for improvement

## Related

- `/headroom-plan` — plan a compression strategy
- `/headroom-status` — check Headroom-lite integration status
- `/rag-audit` — audit RAG retrieval quality (complementary)
- `rtk` / `tokscale` — for actual token measurement (detect-only)

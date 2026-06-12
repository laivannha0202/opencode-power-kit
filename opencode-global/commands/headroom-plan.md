---
description: Plan a context/token compression strategy — content classification, budget calculation
---

# /headroom-plan

Plan a context/token compression strategy for a session.

## Cách dùng

```
/headroom-plan <mô tả context / vấn đề>
/headroom-plan "tool output quá dài, cần compress để fit context"
```

## Workflow

### 1. Problem analysis

- Is compression needed? What happens without it?
- What is the total context window? (model-dependent)
- What is the current token consumption?
- What is the target budget (tokens available for reply)?

### 2. Content classification

Identify each content type in the current context:

| Content type | Compressible? | Strategy |
|-------------|:-------------:|----------|
| Tool stdout/stderr (long) | ✅ Yes | Summarize or structured truncation |
| RAG retrieved chunks | ✅ Yes | Filter low-relevance, summarize verbose |
| Chat history (long) | ✅ Yes | Summarize older turns |
| Log output | ✅ Yes | Deduplicate, then summarize |
| Error messages / stack traces | ❌ No | Keep verbatim |
| Code diffs / code blocks | ❌ No | Keep verbatim |
| Structured data (JSON, YAML) | ⚠️ Partial | Keep schema, truncate arrays |
| User instructions | ❌ No | Keep verbatim |
| API contracts | ❌ No | Keep verbatim |

### 3. Strategy selection

| Approach | Best for | Token savings | Info loss |
|----------|----------|:------------:|:---------:|
| Summarization | Logs, verbose output, chat history | Medium-High | Medium |
| Filtering | RAG chunks below threshold | Medium | Low |
| Structured truncation | Long arrays, repeated output | Medium | Low |
| De-duplication | Repeated errors, log spam | Low-Medium | None |
| Verbatim | Code, errors, contracts | 0% | None |

### 4. Evidence preservation plan

What must survive compression:
- Key numbers, dates, names, IDs
- Error codes and exit statuses
- Last N lines of output (for context)
- Any user-provided values

### 5. Budget calculation

```
Total context window:     N tokens
  - System prompt:        S tokens (fixed)
  - User message:         U tokens (fixed)
  - Conversation history: H tokens → compress target: H'
  - Tool outputs:         T tokens → compress target: T'
  - Retrieved context:    R tokens → compress target: R'
  ----------------------------
  - Available for reply:  N - (S+U) - H' - T' - R'
  - Reserve ≥25%:         ≥ 0.25 × N
```

### 6. Implementation

1. Apply compression strategy per content type.
2. Declare each compression operation.
3. Verify evidence preservation.
4. Verify token budget is met.
5. Fallback: if still over budget, truncate oldest history, then
   reduce retrieval top-k.

## Output

A structured compression plan with:
- Content classification table
- Strategy selection with rationale
- Evidence preservation commitments
- Budget calculation with targets
- Compression declaration format
- Fallback strategy

## Related

- `/headroom-audit` — audit existing compression quality
- `/headroom-status` — check Headroom-lite integration status
- `/rag-plan` — plan RAG retrieval (use together for RAG+compression)
- `rag-lite` skill — for retrieval quality evaluation

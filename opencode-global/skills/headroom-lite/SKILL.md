# Headroom-lite — Context/Token Compression Workflow

**Type:** Flexible (adapt principles to context)

## When to activate

Activate this skill when the task involves:

- Managing long context or token budgets in a session
- Compressing verbose tool output, logs, or RAG chunks
- Planning what content to keep vs compress vs discard
- Auditing current context usage for inefficiencies
- Combining retrieval with compression (use with RAG-lite)
- Any mention of: context compression, token budget, context window,
  output truncation, compression strategy, token savings

## Core principles

1. **Classify before compressing** — Identify which content is compressible
   and which must stay verbatim (code, errors, structured data).
2. **Declare compression** — Always state what was compressed and what was
   removed. Never silently drop content.
3. **Preserve evidence** — Key numbers, dates, names, IDs, and error codes
   must survive compression.
4. **Budget-aware design** — Track token consumption. Reserve ≥25% of
   context window for the model's response.
5. **Combine, don't substitute** — Compression complements retrieval quality
   (RAG-lite), not replaces it. Compress bad retrieval = garbage in,
   compressed garbage out.

## Workflow

When a task involves context/token compression, follow this general flow:

1. **Analyze the context** — What content types are present? What's the
   token budget? What's consuming the most tokens?
2. **Classify content** — Which parts are compressible? Which must stay
   verbatim?
3. **Select strategies** — Use `/headroom-plan` for structured planning.
4. **Audit existing usage** — If reviewing an existing session, use
   `/headroom-audit`.
5. **Check status** — Use `/headroom-status` to verify integration.
6. **Document compression decisions** — What was compressed, what was
   removed, what was preserved, and why.

## Compression checklist

Before applying compression, verify:

- [ ] **Content classified** — Each content type identified.
- [ ] **Strategy matches content** — Right approach for each type.
- [ ] **Evidence preserved** — Key details survive compression.
- [ ] **Compression declared** — What was removed is documented.
- [ ] **Fallback available** — What if compression isn't enough?
- [ ] **Token measurement** — Actual savings verified (via `rtk`/`tokscale`).

## Compression anti-patterns

- ❌ Compressing error messages or stack traces
- ❌ Compressing code diffs or code blocks
- ❌ Silently dropping content without declaration
- ❌ Over-compressing: losing critical evidence for minor savings
- ❌ Same strategy for all content types
- ❌ Substituting compression for proper retrieval quality
- ❌ Not verifying compression output quality

## Safety rules

- **No auto-install** — Never install compression daemons or packages.
- **No credential handling** — Never read or store secrets.
- **No upstream code copy** — Never copy from chopratejas/headroom.
- **Always credit** — Follow OPK conventions (`THIRD_PARTY.md`).
- **Declare compression** — Always state what was removed.
- **Preserve evidence** — Key details survive compression.

## Related skills

- `rag-lite` — For retrieval quality evaluation (use alongside for
  RAG + compression workflows)
- `api-contract` — For API response compression considerations
- `security-review` — For compression security (accidental data loss)
- `hermes-lite-strong` — For context budget review and process
  optimization

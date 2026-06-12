# RAG-lite — Retrieval-Augmented Generation Workflow

**Type:** Flexible (adapt principles to context)

## When to activate

Activate this skill when the task involves:

- Planning or implementing a RAG feature
- Reviewing an existing RAG system
- Evaluating RAG quality (precision, recall, faithfulness)
- Comparing RAG vs fine-tuning vs prompt engineering
- Debugging retrieval issues (low precision, hallucination, latency)
- Any mention of: RAG, retrieval, vector search, embedding, chunking,
  knowledge base, semantic search

## Core principles

1. **RAG-first, but not RAG-only** — Always consider alternatives:
   fine-tuning, prompt engineering, function calling.
2. **Measure before optimizing** — Establish baseline metrics (precision@k,
   recall@k, faithfulness) before changing the pipeline.
3. **Garbage in, garbage out** — Retrieval quality is the bottleneck.
   Invest in chunking, embedding, and re-ranking before generation.
4. **Test with real queries** — Synthetic eval sets miss edge cases.
   Use real user queries for evaluation.
5. **Cost-aware design** — Every retrieval step costs tokens and latency.
   Balance quality vs budget.

## Workflow

When a task involves RAG, follow this general flow:

1. **Analyze the problem** — Is RAG the right approach? What data is
   needed? What are the latency/cost constraints?
2. **Plan the architecture** — Use `/rag-plan` for structured planning.
3. **Audit existing system** — If reviewing an existing RAG, use
   `/rag-audit`.
4. **Evaluate quality** — Use `/rag-eval` for systematic evaluation.
5. **Document assumptions** — What chunking strategy, embedding model,
   top-k, re-ranker are used? Why?

## RAG evaluation checklist

Before shipping any RAG feature, verify:

- [ ] **Retrieval precision** — Are top-k results relevant? ≥80% for
      production.
- [ ] **Retrieval recall** — Are all relevant results captured? ≥70%.
- [ ] **Faithfulness** — Does the answer contradict retrieved context?
      <5% contradiction rate.
- [ ] **Answer relevance** — Does the answer address the user's query?
- [ ] **Latency** — P95 response time within budget (<2s typical).
- [ ] **Empty results handling** — Graceful fallback when no relevant
      context is found.
- [ ] **Ambiguous query handling** — Does the system ask for clarification
      or return multiple possibilities?
- [ ] **Context window fit** — Retrieved chunks fit within LLM context
      window with room for instruction + history.

## RAG anti-patterns

- ❌ Chunking without considering document structure (tables, lists, code)
- ❌ Using a single embedding model without evaluating alternatives
- ❌ Fixed top-k regardless of query complexity
- ❌ No re-ranking for high-precision requirements
- ❌ Ignoring query latency in retrieval design
- ❌ No evaluation beyond "looks good to me"
- ❌ Copying RAG tutorial code without adapting to your data

## Safety rules

- **No auto-install** — Never install vector DB, embedding models, or RAG
  frameworks without explicit user request.
- **No upstream code copy** — Never copy code/notebooks from
  NirDiamant/RAG_Techniques or other upstream RAG repositories.
- **No credential handling** — Never read or store API keys for embedding
  services or vector stores.
- **Always credit** — When referencing upstream RAG projects, add credit
  following OPK conventions (`THIRD_PARTY.md`).

## Related skills

- `api-contract` — For RAG API design
- `database-migration-safe` — For vector store schema changes
- `security-review` — For RAG security (prompt injection via retrieved
  content)
- `frontend-ui-review` — For RAG UI/UX (citation display, source
  attribution)

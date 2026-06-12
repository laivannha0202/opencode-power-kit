# RAG-lite — Retrieval-Augmented Generation Workflow (Reference)

> **Version:** opencode-power-kit v1.9.1
>
> **Integration mode:** Reference / Learning resource — OPK-native docs, skill,
> and slash commands. **No runtime code, no dependency, no package install,
> no MCP.** All content is conceptual guidance, workflow templates, and
> agent instructions — safe to use under MIT license.

---

## Overview

RAG-lite is an **OPK-native reference module** for Retrieval-Augmented
Generation (RAG) patterns. It provides:

- **Documentation** — conceptual overview, workflow stages, components,
  pattern comparison, and practical guidance for building RAG systems.
- **Agent skill** — `rag-lite` skill that teaches agents how to plan,
  audit, and evaluate RAG implementations.
- **Slash commands** — `/rag-plan`, `/rag-audit`, `/rag-eval` for
  structured workflows.

### What RAG-lite is NOT

- ❌ **Not a RAG runtime** — no vector DB, no embedding model, no chunking
  engine, no retrieval pipeline.
- ❌ **Not a code library** — no Python/TypeScript/Node.js code is shipped.
- ❌ **Not a tutorial** — no step-by-step "build your first RAG" notebook.
- ❌ **Not a copy of upstream** — no source, notebook, or significant
  content from [NirDiamant/RAG_Techniques](https://github.com/NirDiamant/RAG_Techniques).

### What RAG-lite IS

- ✅ **Conceptual reference** — RAG terminology, architecture patterns,
  evaluation dimensions, and quality checklist.
- ✅ **Workflow templates** — how to plan a RAG feature, audit an existing
  RAG system, and evaluate retrieval quality.
- ✅ **Agent guidance** — when to recommend RAG vs fine-tuning vs prompt
  engineering, how to validate chunking strategies, how to measure
  retrieval quality.
- ✅ **Learning resource** — curated references to upstream projects and
  research papers (with explicit credit).

---

## RAG Concept Reference

### What is RAG?

Retrieval-Augmented Generation (RAG) is a pattern where an LLM is
augmented with external knowledge retrieved at inference time. Instead of
relying solely on parametric knowledge (what the model learned during
training), RAG fetches relevant documents from a knowledge base and
injects them into the LLM's context window.

### Common RAG Architecture

```
User Query
    │
    ▼
┌─────────────────────┐
│  Query Processing   │  — rewrite, expand, HyDE
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   Retrieval         │  — vector search, keyword, hybrid
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   Context Assembly  │  — chunk ranking, fusion, re-ranking
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   Generation        │  — LLM with context + instruction
└─────────────────────┘
```

### Core Components

| Component | Role | Common approaches |
|-----------|------|-------------------|
| **Chunking** | Split documents into retrievable units | Fixed-size, semantic, sentence-window, recursive |
| **Embedding** | Convert text to dense vectors | OpenAI, Cohere, BGE, Instructor, E5 |
| **Vector Store** | Store & index embeddings | Pinecone, Weaviate, Qdrant, Chroma, pgvector |
| **Retriever** | Fetch relevant chunks | Dense (ANN), Sparse (BM25), Hybrid |
| **Re-ranker** | Re-score retrieved candidates | Cross-encoder, CohereRerank |
| **Generator** | Produce answer from context | GPT-4, Claude, Gemini, local LLMs |

### RAG Patterns

| Pattern | Description | When to use |
|---------|-------------|-------------|
| **Naive RAG** | Basic retrieve-then-generate | Simple Q&A on small corpus |
| **Advanced RAG** | Query rewriting, re-ranking, fusion | Higher accuracy needed |
| **Modular RAG** | Pluggable pipeline components | Complex, multi-step workflows |
| **Agentic RAG** | LLM agent decides when/what to retrieve | Dynamic retrieval needs |
| **Graph RAG** | Knowledge graph + vector retrieval | Multi-hop reasoning |
| **Self-RAG** | LLM self-reflects on retrieval quality | Reducing hallucination |

### Evaluation Dimensions

| Dimension | What it measures | Common metrics |
|-----------|-----------------|----------------|
| **Retrieval Precision** | Are retrieved chunks relevant? | Precision@k, MAP, NDCG |
| **Retrieval Recall** | Are all relevant chunks found? | Recall@k, MRR |
| **Faithfulness** | Does the answer stick to context? | Faithfulness score, contradiction rate |
| **Answer Relevance** | Does the answer address the query? | Relevance score, BLEU, ROUGE |
| **Context Utilization** | How well is context used? | Citation accuracy, context adherence |
| **Latency** | How fast is the pipeline? | P50/P95/P99 response time |
| **Cost** | What does each query cost? | Tokens per query, API calls per query |

---

## License-Safe Design

### Why this matters

[NirDiamant/RAG_Techniques](https://github.com/NirDiamant/RAG_Techniques)
uses a **custom non-commercial license** that restricts commercial use,
redistribution, and derivative works. Copying code, notebooks, or
significant content from that repository into opencode-power-kit (MIT)
would create a **license conflict**.

### RAG-lite rule

1. **No source code** from any upstream RAG repository is shipped in OPK.
2. **No notebook files** (`.ipynb`) are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general
   RAG knowledge, not derived from any single upstream.
5. **Credit is given** in `THIRD_PARTY.md` for:
   - NirDiamant/RAG_Techniques (reference / inspiration)
   - Any other RAG projects referenced in this module
6. **Links to upstream** are provided for users who want the full
   implementation details.

### Third-party references

| Project | Link | Purpose |
|---------|------|---------|
| NirDiamant/RAG_Techniques | https://github.com/NirDiamant/RAG_Techniques | Comprehensive RAG tutorial collection (reference) |
| LangChain | https://github.com/langchain-ai/langchain | RAG orchestration framework |
| LlamaIndex | https://github.com/run-llama/llama_index | Data framework for RAG |
| Chroma | https://github.com/chroma-core/chroma | Open-source embedding database |
| Qdrant | https://github.com/qdrant/qdrant | Vector similarity search engine |

---

## Workflow: Plan → Audit → Evaluate

RAG-lite provides three structured workflows for agents:

### 1. Plan (`/rag-plan`)

When a task involves adding RAG to an existing system, `/rag-plan` guides
the agent through:

1. **Problem analysis** — Is RAG the right solution? (vs fine-tuning,
   prompt engineering, function calling)
2. **Data assessment** — What data needs to be indexed? Format, size,
   update frequency, access control.
3. **Architecture selection** — Which RAG pattern fits? Naive, Advanced,
   Modular, Agentic, Graph?
4. **Component selection** — Chunking strategy, embedding model, vector
   store, retriever, re-ranker.
5. **Evaluation plan** — How will quality be measured? Precision, recall,
   faithfulness, latency budget.
6. **Implementation roadmap** — Phased approach with milestones.

### 2. Audit (`/rag-audit`)

When reviewing an existing RAG system, `/rag-audit` checks:

1. **Chunking quality** — Are chunks too small/large? Do they lose context?
2. **Embedding quality** — Are embeddings capturing semantics?
3. **Retrieval quality** — Precision@k, Recall@k, MRR scores acceptable?
4. **Generation quality** — Faithfulness, hallucination rate, relevance.
5. **Latency & cost** — P95 response time, tokens per query, API costs.
6. **Edge cases** — Empty results, ambiguous queries, multi-lingual,
   adversarial inputs.

### 3. Evaluate (`/rag-eval`)

When a RAG system needs systematic evaluation, `/rag-eval` provides:

1. **Dataset creation** — Generate test queries with golden answers.
2. **Metric computation** — Precision, Recall, F1, Faithfulness, Relevance.
3. **Ablation testing** — Compare chunking strategies, embedding models,
   top-k values.
4. **Regression testing** — Does a change improve or degrade quality?
5. **Report generation** — Structured evaluation report.

---

## Agent Integration

### When to activate rag-lite skill

The `rag-lite` skill should be activated when:

- A task involves planning a new RAG feature
- Reviewing or debugging an existing RAG system
- Evaluating RAG quality before shipping
- Comparing RAG vs alternative approaches
- Any task mentioning "RAG", "retrieval", "vector search", "embedding",
  "chunking", "knowledge base"

### How agents use rag-lite

1. Agent detects RAG-related work → loads `rag-lite` skill
2. Uses `/rag-plan`, `/rag-audit`, `/rag-eval` commands for structured
   workflows
3. Applies checklists from this document to ensure quality
4. Never installs RAG packages directly — guides user to use project's
   package manager
5. Never copies code from upstream tutorials — follows OPK-safe patterns

### Safety rules for agents

- **No auto-install** — Never install vector DB, embedding packages, or RAG
  frameworks without explicit user request.
- **No credential handling** — Never read or store API keys for embedding
  services or vector stores.
- **No production changes** — RAG-lite workflows are planning/evaluation
  tools only. Production changes require user approval.
- **No upstream code copy** — Never copy code from NirDiamant/RAG_Techniques
  or other upstreams into the project.
- **Always credit** — When referencing upstream RAG projects, add credit
  to `THIRD_PARTY.md` following OPK conventions.

---

## Comparison: RAG vs Alternatives

| Approach | Pros | Cons | Best for |
|----------|------|------|----------|
| **RAG** | Up-to-date knowledge, verifiable sources, no training cost | Retrieval latency, chunk quality dependency, context window limits | Knowledge-intensive Q&A, custom data, frequently updated info |
| **Fine-tuning** | Model internalizes knowledge, no retrieval latency | Training cost, knowledge staleness, overfitting risk | Specialized domain style/tone, consistent behavior |
| **Prompt engineering** | Zero cost, fast iteration, no infra | Limited by context window, no real knowledge injection | Simple tasks, small context, rapid prototyping |
| **Function calling** | Real-time data access, deterministic | Requires APIs, more complex orchestration | Structured data queries, action execution |

---

## Files

| File | Role |
|------|------|
| `docs/RAG_LITE_INTEGRATION.md` | This document — conceptual reference, architecture, checklist |
| `opencode-global/skills/rag-lite/SKILL.md` | Agent skill — teaches agents RAG workflow and best practices |
| `opencode-global/commands/rag-plan.md` | `/rag-plan` — plan a RAG feature |
| `opencode-global/commands/rag-audit.md` | `/rag-audit` — audit an existing RAG system |
| `opencode-global/commands/rag-eval.md` | `/rag-eval` — evaluate RAG quality |

---

## Upstream References

- **NirDiamant/RAG_Techniques** — https://github.com/NirDiamant/RAG_Techniques
  Comprehensive collection of RAG tutorials and techniques. Custom
  non-commercial license. OPK references concepts only — no code or
  notebook is copied.
- **LangChain RAG Documentation** — https://python.langchain.com/docs/use_cases/question_answering/
- **LlamaIndex RAG Overview** — https://docs.llamaindex.ai/en/stable/understanding/rag/
- **Chroma Documentation** — https://docs.trychroma.com/
- **Qdrant Documentation** — https://qdrant.tech/documentation/

---

*This file is part of opencode-power-kit and is MIT licensed. It references
upstream projects for conceptual guidance only. No upstream source code,
notebooks, or significant text are included. See `THIRD_PARTY.md` for full
attribution.*

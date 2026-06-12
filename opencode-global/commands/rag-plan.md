---
description: Plan a RAG feature — architecture, components, evaluation
---

# /rag-plan

Plan a Retrieval-Augmented Generation (RAG) feature.

## Cách dùng

```
/rag-plan <mô tả task RAG>
/rag-plan "thêm RAG search cho tài liệu kỹ thuật"
```

## Workflow

### 1. Problem analysis

- What problem are we solving? (Q&A, summarization, code search, ...)
- Is RAG the right approach? Consider alternatives:
  - **Fine-tuning** — when the model needs to internalize knowledge
  - **Prompt engineering** — when context fits in window
  - **Function calling** — when data is structured/API-accessible

### 2. Data assessment

- What data needs to be indexed? Format? Size?
- Update frequency? (static, daily, real-time)
- Access control requirements?
- Language(s) of the data?

### 3. Architecture selection

| Pattern | Use case |
|---------|----------|
| Naive RAG | Simple Q&A, small corpus |
| Advanced RAG | Higher accuracy, query rewriting |
| Modular RAG | Complex multi-step pipelines |
| Agentic RAG | Dynamic retrieval decisions |
| Graph RAG | Multi-hop reasoning |

### 4. Component selection

- **Chunking strategy** — Fixed-size, semantic, sentence-window, recursive
- **Embedding model** — OpenAI, Cohere, BGE, Instructor, E5
- **Vector store** — Pinecone, Weaviate, Qdrant, Chroma, pgvector
- **Retriever** — Dense (ANN), Sparse (BM25), Hybrid
- **Re-ranker** — Cross-encoder, CohereRerank (if needed)
- **Generator** — LLM choice

### 5. Evaluation plan

- **Metrics** — Precision@k, Recall@k, Faithfulness, Relevance, Latency
- **Test dataset** — N query-answer pairs covering edge cases
- **Baseline** — Current performance without RAG
- **Acceptance criteria** — Target scores for each metric

### 6. Implementation roadmap

- Phased approach with milestones
- Dependencies (vector store setup, embedding pipeline, API endpoints)
- Rollout strategy (canary, A/B test)

## Output

A structured RAG plan with:
- Architecture diagram (text-based)
- Component list with rationale
- Evaluation criteria with targets
- Implementation phases with estimates
- Risk assessment (failure modes, fallbacks)

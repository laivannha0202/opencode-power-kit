---
description: Audit an existing RAG system — retrieval quality, faithfulness, latency
---

# /rag-audit

Audit an existing Retrieval-Augmented Generation (RAG) system.

## Cách dùng

```
/rag-audit <mô tả hệ thống RAG cần kiểm tra>
/rag-audit "kiểm tra hệ thống search tài liệu nội bộ"
```

## Audit checklist

### 1. Chunking quality

- [ ] Chunk size appropriate for content type?
- [ ] Document structure preserved (headings, tables, lists)?
- [ ] Overlap between chunks sufficient (typically 10-20%)?
- [ ] No critical information split across chunks?
- [ ] Code blocks preserved intact (if applicable)?

### 2. Embedding quality

- [ ] Embedding model appropriate for domain/language?
- [ ] Embedding dimension balanced with performance needs?
- [ ] Embeddings normalized for cosine similarity?
- [ ] Query embedding matches document embedding space?

### 3. Retrieval quality

| Metric | Acceptable | Good | Excellent |
|--------|-----------|------|-----------|
| Precision@k | ≥60% | ≥75% | ≥90% |
| Recall@k | ≥50% | ≥65% | ≥85% |
| MRR | ≥0.6 | ≥0.75 | ≥0.9 |
| NDCG@k | ≥0.6 | ≥0.75 | ≥0.9 |

### 4. Generation quality

- [ ] Faithfulness — answer supported by retrieved context?
- [ ] Hallucination rate — <5% contradictory responses?
- [ ] Relevance — answer directly addresses query?
- [ ] Citation accuracy — sources correctly attributed?
- [ ] Context utilization — retrieved chunks actually used?

### 5. Latency & cost

| Component | Budget | Notes |
|-----------|--------|-------|
| Embedding | <500ms | Batch if possible |
| Retrieval | <200ms | Index optimization |
| Re-ranking | <300ms | Skip if not needed |
| Generation | <2s | Model size vs speed |
| **Total P95** | **<3s** | |

### 6. Edge cases

- [ ] Empty results — graceful fallback?
- [ ] Ambiguous queries — clarification or disambiguation?
- [ ] Out-of-domain queries — "I don't know" response?
- [ ] Multi-lingual — cross-language retrieval works?
- [ ] Adversarial — prompt injection via retrieved content?
- [ ] Large result sets — pagination / summarization?

## Output

Structured audit report with:
- Score for each dimension (0-10)
- Specific findings with evidence (query → retrieved → generated)
- Priority-ordered improvement recommendations
- Risk assessment for production deployment

---
description: Evaluate RAG quality — metrics, ablation, regression testing
---

# /rag-eval

Evaluate Retrieval-Augmented Generation (RAG) quality.

## Cách dùng

```
/rag-eval <mô tả hệ thống RAG và phạm vi đánh giá>
/rag-eval "đánh giá chất lượng RAG search cho docs kỹ thuật"
```

## Evaluation workflow

### 1. Dataset creation

Create a test dataset of query-answer pairs:

```
query: "How to configure authentication in NestJS?"
golden_context: ["docs/auth-setup.md", "docs/jwt-config.md"]
golden_answer: "Use Passport module with JWT strategy..."
expected_behavior: "Retrieve auth setup docs and summarize JWT config"
```

Requirements:
- **Coverage** — Cover all document categories
- **Edge cases** — Empty, ambiguous, multi-lingual, adversarial
- **Size** — Minimum 20-50 queries for meaningful metrics
- **Ground truth** — Golden context and answer verified by domain expert

### 2. Metric computation

| Metric | Formula | Target |
|--------|---------|--------|
| **Precision@k** | relevant_in_top_k / k | ≥80% |
| **Recall@k** | relevant_retrieved / total_relevant | ≥70% |
| **F1@k** | 2 * P * R / (P + R) | ≥75% |
| **MRR** | Mean Reciprocal Rank | ≥0.75 |
| **NDCG@k** | Normalized Discounted Cumulative Gain | ≥0.75 |
| **Faithfulness** | non_contradictory / total | ≥95% |
| **Relevance** | relevant_answers / total | ≥85% |
| **Latency P50/P95** | Response time percentiles | <1s / <3s |

### 3. Ablation testing

Compare configurations to find the best:

```
Config A: fixed-512-chunks + ada-002 + top-5
Config B: semantic-chunks + bge-large + top-3 + reranker
Config C: recursive-chunks + cohere + top-5 + hyde
```

Measure each config against all metrics. Recommend the best trade-off.

### 4. Regression testing

Before shipping a change, compare against baseline:

```
┌──────────────┬──────────┬──────────┬──────────┐
│ Metric       │ Baseline │ New      │ Δ        │
├──────────────┼──────────┼──────────┼──────────┤
│ Precision@5  │ 82%      │ 85%      │ +3% ✅   │
│ Recall@5     │ 71%      │ 73%      │ +2% ✅   │
│ Faithfulness │ 96%      │ 94%      │ -2% ❌   │
│ Latency P95  │ 1.8s     │ 2.1s     │ +16% ⚠️  │
└──────────────┴──────────┴──────────┴──────────┘
```

### 5. Report generation

Structured evaluation report including:

- **Summary** — Overall quality score, pass/fail for each dimension
- **Dataset** — Queries used, ground truth, coverage analysis
- **Metrics** — All computed metrics with confidence intervals
- **Ablation results** — Comparison table of tested configurations
- **Regression** — Δ from baseline for each metric
- **Recommendations** — Priority-ordered improvements
- **Risks** — Known failure modes, edge cases not covered

## When to evaluate

| Trigger | Scope | Depth |
|---------|-------|-------|
| New RAG feature | Full evaluation | All metrics + ablation |
| Before production deploy | Production readiness | Precision, recall, faithfulness, latency |
| After chunking change | Regression | Precision, recall |
| After embedding change | Regression | All retrieval metrics |
| After model change | Regression | Faithfulness, relevance, latency |
| Routine (weekly) | Monitoring | Precision, latency (sample) |

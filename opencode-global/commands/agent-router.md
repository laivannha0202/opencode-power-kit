---
description: Tự động route task sang agent phù hợp dựa vào nội dung task
---

# /agent-router

Phân tích task và route đến agent chuyên môn phù hợp.

## Cách dùng

```
/agent-router <mô tả task>
/agent-router "thêm API CRUD user với JWT auth"
```

## Routing logic

## ⚠️ Scope Guard — Docs-only / Read-only routing

Nếu task chứa keyword docs-only, read-only, chỉ kiểm tra, không sửa file, audit, review:
→ KHÔNG route sang build-strong, power-build, build-slice, db-strong, api-strong.
→ Chỉ route sang architect-strong (nếu cần design), debug-strong (nếu cần phân tích root cause),
hoặc main agent (nếu cần docs/report).

| Task type | Route to | Ghi chú |
|-----------|----------|---------|
| Architecture, system design, tech decision | `architect-strong` | Nếu task > 5 files hoặc cross-module |
| Bug, error, crash, regression | `debug-strong` | Nếu build-strong không tìm ra root cause |
| Database, migration, schema, query | `db-strong` | Khi có migration hoặc schema thay đổi |
| API contract, OpenAPI, FE/BE type sync | `api-strong` | Khi thay đổi endpoint |
| UI, component, a11y, responsive | `ui-ux-strong` | Review giao diện |
| AI-augmented UI design, image-to-code, redesign, polish, brand kit | `taste-ui-strong` | UI design task cần Taste Skill |
| Docker, CI/CD, deploy, infra | `devops-strong` | Setup/review infrastructure |
| Test, QA, coverage, E2E | `qa-strong` | Trước ship |
| Security audit, SAST, threat model | `security-strong` | Pre-release |
| Version bump, release, CHANGELOG | `release-strong` | Cuối cùng |
| Meta-cognition, self-improvement, reflection | `hermes-lite-strong` | Khi cần learning loop, skill improvement |
| RAG planning, architecture, component selection | `rag-lite` skill + `/rag-plan` | Khi task liên quan RAG mới |
| RAG audit, retrieval quality, faithfulness | `rag-lite` skill + `/rag-audit` | Khi cần review hệ thống RAG hiện có |
| RAG evaluation, metrics, ablation testing | `rag-lite` skill + `/rag-eval` | Khi cần đo chất lượng RAG |
| Context compression planning, token budget | `headroom-lite` skill + `/headroom-plan` | Khi cần lên kế hoạch compress context |
| Context usage audit, compression opportunities | `headroom-lite` skill + `/headroom-audit` | Khi cần audit token consumption |
| Headroom-lite integration status | `headroom-lite` skill + `/headroom-status` | Kiểm tra Headroom-lite sẵn sàng |
| Context/memory audit, kanban, tool audit | `hermes-lite-strong` | Khi cần process optimization |
| Agent memory planning, multi-session strategy | `agentmemory-lite` skill + `/memory-plan` | Khi cần lên kế hoạch memory cho task dài |
| Agent memory audit, state integrity | `agentmemory-lite` skill + `/memory-audit` | Khi cần audit memory state |
| Agent memory handoff, checkpoint | `agentmemory-lite` skill + `/memory-handoff` | Khi cần handoff context an toàn |

## Workflow

1. Parse task description — xác định category chính.
2. Nếu task phức tạp → spawn agent chuyên môn qua `task` tool.
3. Thu thập output, tổng hợp response.
4. Nếu task lớn → spawn nhiều agent tuần tự (architect → db → api → build → qa → security).

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
| Docker, CI/CD, deploy, infra | `devops-strong` | Setup/review infrastructure |
| Test, QA, coverage, E2E | `qa-strong` | Trước ship |
| Security audit, SAST, threat model | `security-strong` | Pre-release |
| Version bump, release, CHANGELOG | `release-strong` | Cuối cùng |

## Workflow

1. Parse task description — xác định category chính.
2. Nếu task phức tạp → spawn agent chuyên môn qua `task` tool.
3. Thu thập output, tổng hợp response.
4. Nếu task lớn → spawn nhiều agent tuần tự (architect → db → api → build → qa → security).

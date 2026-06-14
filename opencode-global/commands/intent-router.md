---
description: "Phân loại request thành intent và đề xuất agent/workflow phù hợp. Vietnamese-first. Inspired by oh-my-openagent IntentGate but simplified."
---

# /intent-router

Phân tích request của user, phân loại thành intent, và đề xuất agent/workflow phù hợp.

## Cách dùng

```
/intent-router <mô tả request>
/intent-router "thêm API CRUD user với JWT auth"
/intent-router "fix lỗi login bị redirect loop"
/intent-router "viết test cho payment service"
```

## Scope Guard — Docs-only / Read-only

Nếu request chứa keyword: "chỉ kiểm tra", "không sửa file", "read-only", "docs-only", "chỉ tài liệu", "không code":
→ KHÔNG route sang build-strong, power-build, build-slice, db-strong, api-strong.
→ Chỉ route sang architect-strong, debug-strong, hoặc main agent.

## Phân loại Intent

| Intent | Keywords (vi/en) | Agent đề xuất | Workflow |
|--------|-----------------|---------------|----------|
| `research` | "tìm hiểu", "phân tích", "research", "explore" | `plan-lite` | Đọc → phân tích → báo cáo |
| `plan` | "lập kế hoạch", "kế hoạch", "plan", "design" | `architect-strong` | Spec → plan → confirm → execute |
| `implement` | "thêm", "tạo", "làm", "code", "build", "implement" | `build-strong` | Plan → build-slice → verify |
| `debug` | "lỗi", "bug", "fix", "broken", "error", "crash" | `debug-strong` | Reproduce → root cause → fix → verify |
| `refactor` | "tối ưu", "refactor", "clean up", "restructure" | `build-strong` | Checkpoint → refactor → verify |
| `test` | "test", "viết test", "coverage", "E2E" | `qa-strong` | Plan test → write → run → report |
| `security` | "bảo mật", "security", "vulnerability", "audit" | `security-strong` | Audit → report → fix → verify |
| `release` | "release", "publish", "version", "bump" | `release-strong` | Version → changelog → tag → publish |
| `docs` | "tài liệu", "docs", "README", "documentation" | `plan-lite` | Đọc → viết → verify |
| `fullstack-feature` | "fullstack", "full-stack", "FE+BE", "API+UI" | `build-strong` | Architecture → DB → API → UI → test |

## Output (tiếng Việt)

```
## Intent Analysis

**Intent chính:** implement
**Confidence:** cao

**Mô tả:** Thêm API CRUD user với JWT authentication

**Rủi ro:**
- Cần thay đổi DB schema (thêm user table)
- Cần JWT middleware
- Cần FE API call sync

**Agent đề xuất:** build-strong

**Workflow đề xuất:**
1. `/checkpoint` — snapshot trước khi sửa
2. Spawn `db-strong` — design user schema
3. Spawn `api-strong` — define API contract
4. Build-slice theo thứ tự: DB → API → FE
5. `/evidence-report` — tổng hợp evidence

**Cần checkpoint:** Có (trước khi sửa DB)

**Cần verify nào:**
- lint/typecheck
- API test
- JWT auth flow test
```

## Agent Pool

| Agent | Khi nào dùng |
|-------|-------------|
| `architect-strong` | System design, ADR, tech decision, > 5 files |
| `build-strong` | Feature implementation, bugfix, refactor |
| `debug-strong` | Bug phức tạp, intermittent, không tìm root cause |
| `qa-strong` | Test suite, coverage, E2E |
| `security-strong` | OWASP, SAST, threat model |
| `db-strong` | Schema, migration, query optimization |
| `api-strong` | API contract, OpenAPI, FE/BE sync |
| `ui-ux-strong` | UI/UX review, accessibility, responsive |
| `devops-strong` | Docker, CI/CD, deploy, infra |
| `release-strong` | Version bump, CHANGELOG, publish |
| `plan-lite` | Research, docs, planning (read-only) |
| `review-lite` | Code review, diff review |

## Workflow

1. Parse request — xác định intent chính.
2. Nếu request phức tạp → có thể có multi-intent (ví dụ: "thêm feature X và viết test" → implement + test).
3. Phân tích rủi ro (số file ảnh hưởng, DB change, API change).
4. Đề xuất agent và workflow.
5. Luôn output bằng tiếng Việt.
6. KHÔNG tự chạy workflow — chỉ đề xuất. User tự quyết định.

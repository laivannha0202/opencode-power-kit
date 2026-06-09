---
description: Workflow tổng hợp spec → architecture → implementation → QA → security → release
---

# /power-build

Workflow full-stack hoàn chỉnh: spec → architecture → implementation → QA → security → release.

## ⚠️ Scope Guard — Chỉ chạy khi task là code/feature rõ ràng

Power-build **CHỈ** áp dụng khi user yêu cầu implement feature / bugfix / refactor / build mới.
**KHÔNG** áp dụng cho docs-only / read-only / chỉ kiểm tra / audit. Nếu task là docs-only → STOP,
báo: "Task docs-only, dùng main agent để kiểm tra/docs."

## Cách dùng

```
/power-build <mô tả task>
/power-build "thêm tính năng đăng ký user với email verification"
```

## Workflow

### Phase 1: Spec & Architecture
1. Chạy `/spec-lite` — tạo spec ngắn + acceptance criteria.
2. Spawn `architect-strong` — thiết kế giải pháp kiến trúc.
3. Output: spec.md + architecture plan.

### Phase 2: Plan & Implement
4. Chạy `/plan-work` — chia task thành slices ≤ 2 files.
5. Nếu có DB change → spawn `db-strong`.
6. Nếu có API change → spawn `api-strong`.
7. Nếu có UI → spawn `ui-ux-strong`.
8. Build từng slice với `/build-slice`.

### Phase 3: Verify
9. Spawn `qa-strong` — viết test, chạy test suite.
10. Chạy `npm test` / `npm run lint` / `npm run typecheck`.
11. Nếu project có Playwright → chạy `/e2e-flow`.

### Phase 4: Security & Release
12. Spawn `security-strong` — audit security.
13. Chạy `/release-check` — verify release readiness.
14. Spawn `release-strong` — bump version, CHANGELOG.

### Phase 5: Report
```
## Power Build Report
- **Phases completed:** 4/4
- **Agents used:** architect → db → api → qa → security → release
- **Files changed:** N
- **Tests:** N (pass: N)
- **Security:** N issues (resolved: N)
- **Version:** v{new} ready
- **Ship confidence:** HIGH / MEDIUM / LOW
```

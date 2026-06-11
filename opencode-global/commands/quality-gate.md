---
description: Quality gate — chạy lint, typecheck, test, build trước khi merge/ship
subtask: true
agent: ecc-lite-strong
---

# /quality-gate

Run quality gate checks before merging or shipping.

## Cách dùng

```
/quality-gate                    # auto-detect và chạy tất cả
/quality-gate --skip-build       # bỏ qua build step
/quality-gate --skip-test        # bỏ qua test step
/quality-gate --strict           # fail nếu có warning
```

## ⚠️ Scope Guard — Read-only check

Quality gate chỉ chạy checks, **KHÔNG** tự động sửa code.

## Checks

### 1. Detect stack
- `package.json` → npm/pnpm/yarn
- `Cargo.toml` → cargo
- `requirements.txt` / `pyproject.toml` → pip/pytest
- `go.mod` → go
- `Makefile` → make

### 2. Run quality gates

| Gate | Command | Auto-detect |
|------|---------|-------------|
| Lint | `npm run lint` / `ruff check .` / `golangci-lint run` | package.json scripts |
| Type check | `tsc --noEmit` / `mypy .` | tsconfig.json / mypy.ini |
| Test | `npm test` / `pytest` / `go test ./...` | package.json / pytest.ini / go.mod |
| Build | `npm run build` / `cargo build` / `go build ./...` | package.json / Cargo.toml / go.mod |

### 3. Report

```
## Quality Gate Report
- **Lint:** pass/fail/warn
- **Typecheck:** pass/fail/skip
- **Test:** pass/fail/skip (N passed, M failed)
- **Build:** pass/fail/skip
- **Overall:** PASS / FAIL
- **Issues:** (details)
```

## When to use

- Trước mỗi commit
- Trước khi tạo PR
- Trước khi ship/deploy
- Sau mỗi slice trong build-strong workflow

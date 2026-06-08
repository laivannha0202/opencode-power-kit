---
description: Đọc lỗi CI/test/build rồi sửa an toàn — phân tích log, tìm nguyên nhân, sửa, verify
---

# /ci-fix

Phân tích lỗi CI / test / build và sửa an toàn.

## Cách dùng

```
/ci-fix [--dry-run] [--last]
/ci-fix --last    # phân tích CI run cuối
/ci-fix --dry-run # chỉ phân tích, không sửa
```

## Workflow

### 1. Collect error
- `git status` — check working tree sạch.
- Nếu `--last` → đọc CI log từ GitHub Actions (gh run view --log).
- Nếu không → detect error từ context (test output, build log, linter).

### 2. Analyze
- Parse error message: file, line, column, error code, stacktrace.
- Phân loại:
  - **Compile/build**: import, type, syntax, missing dep.
  - **Test**: assertion, timeout, setup, fixture, mock.
  - **Lint**: rule violation, format, dead code.
  - **CI infra**: missing tool, env, cache, network.
- Dùng `rg` / Serena tìm code liên quan — không đọc toàn repo.

### 3. Fix (nếu --dry-run thì skip)
- Sửa nhỏ nhất — đúng error, không refactor lân cận.
- Nếu fix > 2 file hoặc nghi ngờ → spawn `debug-strong`.
- Mỗi fix: `git diff` verify, chạy lại lệnh lỗi để confirm.

### 4. Verify
```
npm test  # hoặc lệnh tương ứng
npm run lint
npm run typecheck  # nếu có
```

### 5. Report
```
## CI Fix Report
- **Error:** ...
- **Root cause:** ...
- **Fix:** file:line (what changed)
- **Verify:** test ✓ / lint ✓ / typecheck ✓
- **Residual risk:** ...
```

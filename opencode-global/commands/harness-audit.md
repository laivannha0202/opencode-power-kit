---
description: Harness audit — kiểm tra test coverage, test quality, CI/CD setup
subtask: true
agent: ecc-lite-strong
---

# /harness-audit

Audit test harness: coverage, test quality, and CI/CD configuration.

## Cách dùng

```
/harness-audit                          # audit tất cả test harness
/harness-audit --ci-only                # chỉ audit CI/CD config
/harness-audit --coverage               # chỉ audit test coverage
/harness-audit --quality                # chỉ audit test quality
```

## ⚠️ Scope Guard — Audit only

Harness audit **CHỈ** đọc và phân tích. **KHÔNG** sửa code trừ khi user yêu cầu.

## Checks

### 1. Test framework
- Test framework detect (jest, pytest, vitest, go test, etc.)
- Test config file tồn tại?
- Test script trong package.json?

### 2. Test coverage
- Coverage config tồn tại?
- Coverage thresholds?
- Current coverage % (nếu chạy được)
- Untested critical paths

### 3. Test quality
- Happy path tests?
- Error case tests?
- Edge case tests?
- Integration tests?
- E2E tests?
- Test naming consistent?

### 4. CI/CD
- CI config file detect (.github/workflows, .gitlab-ci.yml, Jenkinsfile)
- Test step trong CI?
- Coverage upload?
- Build step?

### 5. Test commands

| Framework | Command | Config file |
|-----------|---------|-------------|
| Jest | `npx jest --coverage` | jest.config.* |
| Vitest | `npx vitest run --coverage` | vitest.config.* |
| Pytest | `pytest --cov=.` | pytest.ini / pyproject.toml |
| Go test | `go test ./... -cover` | go.mod |

## Output

```
## Harness Audit Report
- **Framework:** {detected}
- **Config:** found/missing
- **Coverage:** {N%} (threshold: {N%})
- **Test count:** N unit, N integration, N e2e
- **CI:** {platform} configured/not configured
- **Issues:** N (details)
- **Overall:** GOOD / NEEDS_IMPROVEMENT / CRITICAL
```

---
description: Lập và chạy proof E2E nếu project có Playwright — detect, plan, run, report
---

# /e2e-flow

Lập kế hoạch và chạy E2E proof cho project có Playwright.

## Cách dùng

```
/e2e-flow [--dry-run]
/e2e-flow --dry-run  # chỉ lập plan, không chạy
```

## Workflow

### 1. Detect Playwright
```bash
ls playwright.config.* 2>/dev/null || ls playwright-*.config.* 2>/dev/null
rg "playwright" package.json 2>/dev/null
npx playwright --version 2>/dev/null
```

### 2. Plan flows
Xác định critical user flows:
```
- Auth: login → protected page → logout
- CRUD: create → read → update → delete
- Search: empty → valid → invalid → pagination
- Error: 404 → 500 → network error → form validation
- Edge: mobile viewport, slow network, empty state
```

### 3. Generate test
Nếu không có E2E test:
- Tạo test file: `e2e/{flow}.spec.ts`
- Cấu trúc: `test.describe` → `test.beforeEach` → `test('...')`
- Dùng page object pattern nếu project > 5 pages.
- Assert: `expect(page).toHaveURL()`, `toHaveText()`, `toBeVisible()`.

### 4. Run
```bash
npx playwright test  # hoặc npm run test:e2e
```

### 5. Report
```
## E2E Flow Report
- **Playwright:** vX.Y.Z (installed)
- **Flows:** N defined
- **Pass:** N / N
- **Fail:** N (details)
- **Duration:** Xs
- **Coverage gaps:** ...
```

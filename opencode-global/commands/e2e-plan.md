---
description: Đề xuất Playwright E2E flow cho các tính năng chính
---

Đề xuất E2E test plan cho dự án (Playwright):

1. Detect app: FE (vite/next/nuxt) + BE (NestJS/Express) từ `package.json`.
2. Liệt kê user flow chính dựa trên routes (`rg "createBrowserRouter|RouterProvider" src/`) và routes backend (`rg "@Get|@Post"`).
3. Đề xuất file `e2e/`:
   - `auth.spec.ts` — register / login / logout / refresh.
   - `<resource>-crud.spec.ts` — list / create / edit / delete.
   - `<flow>.spec.ts` — flow đặc thù (checkout, onboarding, ...).
4. Với mỗi test đề xuất:
   - Pre-condition: state DB cần (user seed, ...).
   - Steps: mỗi step = 1 action + assert.
   - Selector strategy: `getByRole` ưu tiên, `getByTestId` cho element khó.
5. Đề xuất helper:
   - `e2e/fixtures/auth.ts` — login once, reuse storage state.
   - `e2e/helpers/db.ts` — reset DB giữa test.
   - `e2e/pages/*.ts` — Page Object Model.
6. Cảnh báo nếu thiếu `data-testid` ở component.

Output:

| File | Flow | Steps | Notes |
|------|------|-------|-------|

Không tự viết test. Chỉ đề xuất. User tự review rồi implement.

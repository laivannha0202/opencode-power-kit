---
description: Tạo test matrix (unit/integration/e2e/smoke) cho project full-stack
---

Tạo test matrix cho dự án FE + BE + DB.

Cột: `Layer | Tool | Scope | Mô tả | Lệnh đề xuất | Khi nào chạy`.

Hàng mẫu:

- `BE Unit | Jest/Vitest | service / guard / pipe / interceptor | Test logic thuần, mock repo | npm test | Mỗi PR`
- `BE Integration | Jest + Test.createTestingModule | module NestJS + DB sandbox | Test controller + service + DB thật | npm run test:integration | Mỗi PR`
- `BE E2E | supertest / Jest | app boot thật | Test 1 flow backend | npm run test:e2e:be | Mỗi PR / nightly`
- `FE Unit | Vitest + RTL | component / hook / util | Test render + interaction, mock API bằng MSW | npm test | Mỗi PR`
- `FE E2E | Playwright | browser thật | Test user flow | npm run test:e2e | Nightly / pre-release`
- `DB | Migration test | schema + seed | Test up/down + FK | npm run db:test | Mỗi PR`
- `Smoke | curl health | /health endpoint | Boot app + ping | npm run smoke | Sau build / pre-deploy`

Output: in ma trận + checklist action cho project hiện tại (cái nào đã có, cái nào thiếu).

KHÔNG tự thêm script. CHỈ đề xuất. User tự quyết định cấu hình.

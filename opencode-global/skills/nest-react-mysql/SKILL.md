# Nest + React + MySQL

Quy tắc tổng hợp cho stack NestJS + React/Vite + MySQL. Bản global, dùng khi bắt đầu dự án hoặc review toàn diện.

## Stack

- **Backend:** Node.js 20+ LTS, TypeScript, NestJS 10+, TypeORM hoặc Prisma.
- **Frontend:** React 18+, Vite 5+, TypeScript, React Query, Zustand, React Hook Form + Zod.
- **Database:** MySQL 8.x (utf8mb4).
- **Auth:** JWT (access + refresh) hoặc session cookie.
- **Test:** Vitest + Supertest + Playwright.
- **CI:** GitHub Actions.

## Cấu trúc repo

```
myapp/
├── apps/
│   ├── api/                       # NestJS backend
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   ├── common/
│   │   │   ├── config/
│   │   │   ├── app.module.ts
│   │   │   └── main.ts
│   │   ├── test/
│   │   ├── nest-cli.json
│   │   ├── tsconfig.json
│   │   └── package.json
│   └── web/                       # React + Vite frontend
│       ├── src/
│       │   ├── pages/
│       │   ├── components/
│       │   ├── hooks/
│       │   ├── api/
│       │   ├── stores/
│       │   ├── routes/
│       │   ├── App.tsx
│       │   └── main.tsx
│       ├── index.html
│       ├── vite.config.ts
│       └── package.json
├── packages/
│   ├── shared/                    # types / utils share FE-BE
│   │   └── src/
│   └── eslint-config/
├── docker-compose.yml             # MySQL + adminer
├── pnpm-workspace.yaml            # hoặc npm workspaces
├── package.json                   # root
├── .env.example
├── .gitignore
├── AGENTS.md                      # rule cho AI agent
├── OPENCODE.md                    # workflow
└── README.md
```

Dùng monorepo (pnpm workspace / npm workspace) khi FE-BE share type / util. Khi chỉ BE hoặc chỉ FE, repo đơn giản hơn.

## Workflow thay đổi

```
DB → entity → DTO → service → controller → FE types → FE API → FE component
```

- Sửa DB: migration trước. KHÔNG sync schema ở prod.
- Sửa entity → DTO mới → service update → controller expose → FE type import.
- Sửa FE: gọi API qua `api/`, không `fetch` rải rác.
- Test theo layer: unit service, integration controller + DB, E2E flow.

## Contract

- OpenAPI 3.1: `openapi.yaml` ở repo root.
- Generate từ NestJS: `@nestjs/swagger` + CLI `nest start --watch`.
- FE generate client từ OpenAPI: `openapi-typescript` hoặc `orval`.
- Drift detection: spectral lint + oasdiff.

## Auth

- Access JWT 15 phút + refresh 7 ngày (rotation).
- Password: bcrypt cost 10 hoặc argon2id.
- Role: claim `roles` trong JWT. Guard `RolesGuard` ở BE.
- FE: ưu tiên httpOnly cookie. Nếu Bearer, dùng `api` instance có interceptor.
- Public route whitelist: `/api/auth/*`, `/api/health`.

## Database

- TypeORM: `synchronize: false` ở prod. Migration bằng `typeorm migration:generate` / `:run`.
- Prisma: `prisma migrate dev` (dev), `prisma migrate deploy` (prod).
- charset `utf8mb4`, collation `utf8mb4_unicode_ci`.
- Time: lưu UTC `DATETIME(3)`. Convert ở app.
- Soft delete: cột `deleted_at` (không `DELETE` cứng trừ khi yêu cầu rõ).

## API style

- REST. Endpoint noun, số nhiều. `/api/v1/users`, `/api/v1/posts`.
- Status: 200 / 201 / 204 / 400 / 401 / 403 / 404 / 409 / 422 / 500.
- Error: `{ error: { code, message, details? } }`.
- Pagination: cursor (`?cursor=...&limit=20`) hoặc offset (`?page=1&limit=20`).
- Filter: `?status=active&sort=-createdAt`.

## Frontend rules

- React 18+ functional + hooks.
- State: server → React Query. Client → Zustand. Form → React Hook Form + Zod.
- API client: `src/api/client.ts` axios instance. KHÔNG `fetch` rải rác.
- Routing: React Router v6+. Private route wrap `ProtectedRoute`.
- Type: `strict: true`. KHÔNG `any`.
- Env chỉ `VITE_*`.

## Testing

- Unit: Vitest. Service BE + hook FE.
- Integration: NestJS `Test.createTestingModule` + testcontainer MySQL.
- E2E: Playwright. Mỗi file = 1 user flow chính.
- Mock API FE: MSW.
- CI gate mỗi PR: unit + integration + lint + type + build.

## CI/CD

- GitHub Actions matrix: api, web, lint, test.
- Cache: pnpm/npm cache, docker layer cache.
- Deploy: image build → push registry → deploy (Fly.io / Render / k8s).
- Migration chạy tự động trong deploy job, có rollback.
- Healthcheck: `/api/health` + log ship.

## Security checklist

- HTTPS + HSTS ở prod.
- CSP chặt ở FE.
- CORS whitelist origin.
- Input validate ở BE.
- Parameterize SQL.
- Rate limit login + global.
- Secret qua env, không bake vào image.
- Audit log cho admin action.

## Anti-pattern tổng hợp

- ❌ `synchronize: true` ở prod.
- ❌ Hardcode secret trong source.
- ❌ Trả entity ORM trực tiếp ra response.
- ❌ Business logic trong controller.
- ❌ `fetch` rải rác trong component.
- ❌ `any` ở boundary.
- ❌ Lưu token vào `localStorage` khi có httpOnly cookie option.
- ❌ `image: mysql:latest` trong docker-compose.
- ❌ Skip test cho layer "vì tốn thời gian".

## Skill liên quan

- `nestjs-backend` — controller / service / module / DTO / entity / guard / pipe / interceptor.
- `react-vite-frontend` — component / hook / API client / state / form / routing.
- `mysql-schema-safe` — schema / index / FK / migration / backfill / rollback.
- `auth-rbac-review` — auth / role / guard / route / token.
- `fullstack-test-strategy` — pyramid test theo stack.
- `openapi-contract` — API spec.
- `secure-fullstack` — security tổng hợp.
- `docker-compose-safe` — docker dev setup.
- `env-config-safe` — env file + secret.
- `js-ts-quality` — TypeScript / lint / format / dead code.
- `dependency-maintenance` — update dep an toàn.

## Khi nào load skill nào

| Task | Skill |
|------|-------|
| Sửa backend | `nestjs-backend` + `secure-fullstack` |
| Sửa frontend | `react-vite-frontend` + `js-ts-quality` |
| Migration DB | `mysql-schema-safe` |
| Thay đổi auth | `auth-rbac-review` + `secure-fullstack` |
| Đổi API endpoint | `openapi-contract` |
| Setup docker | `docker-compose-safe` |
| Setup env | `env-config-safe` |
| Setup test | `fullstack-test-strategy` |
| Update dep | `dependency-maintenance` |
| Review PR | `secure-fullstack` + `auth-rbac-review` + `openapi-contract` |

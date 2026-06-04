# Full-Stack Profile: Node + NestJS + React/Vite + MySQL

Profile này thêm commands + skills chuyên cho dự án full-stack stack:

- **Backend:** Node.js + TypeScript + NestJS + TypeORM/Prisma
- **Frontend:** React + Vite + TypeScript + React Query / Zustand
- **Database:** MySQL 8.x (sandbox cho dev, prod tách riêng)
- **Auth:** JWT bearer + role-based guard
- **Tooling:** pnpm/npm, vitest/jest, eslint/prettier/biome, lefthook

## Cài vào project

```bash
# Từ thư mục project (KHÔNG chạy trong HOME hay ~/opencode-power-kit)
bash ~/opencode-power-kit/scripts/install-fullstack-profile.sh
```

Script sẽ:
1. Backup `AGENTS.md` / `OPENCODE.md` nếu có.
2. Append `AGENTS.append.md` + `OPENCODE.append.md` (idempotent qua marker).
3. Copy commands vào `.opencode/commands/`.
4. Copy skills vào `.agents/skills/`.
5. Không ghi đè file user nếu chưa backup.

## Bao gồm

### Commands (5)
- `/fullstack-scan` — quét project full-stack
- `/api-e2e-flow` — kiểm tra luồng UI → API → DB → response → UI
- `/env-doctor` — kiểm tra env an toàn, không in secret
- `/docker-dev-doctor` — kiểm tra docker-compose dev
- `/seed-data-safe` — kiểm tra seed/demo data

### Skills (5)
- `nestjs-backend` — controller/service/module/dto/guard/pipe/interceptor
- `react-vite-frontend` — component/hook/API client/state/form/routing
- `mysql-schema-safe` — schema/index/FK/migration/backfill/rollback
- `auth-rbac-review` — auth/role/guard/route protection/token
- `fullstack-test-strategy` — pyramid test theo stack

## An toàn

- Không tự cài dependency nặng.
- Không thêm MCP server.
- Không ghi file ngoài `.opencode/`, `.agents/`, `AGENTS.md`, `OPENCODE.md` (append only).
- Không xóa file user.
- Không in secret value ra log.

## Sau khi cài

- Mở `AGENTS.md` / `OPENCODE.md` xem phần append.
- Chạy `/fullstack-scan` để xem project hiện trạng.
- Dùng `/env-doctor` và `/docker-dev-doctor` trước khi dev.

---
description: Quét project full-stack (NestJS + React/Vite + MySQL) phát hiện backend/frontend/db/scripts/env/docker
---

Quét nhanh project full-stack để biết:

- **Backend:** có `nest-cli.json` / `package.json` chứa `@nestjs/*` không.
- **Frontend:** có `vite.config.*` / `package.json` chứa `react` + `vite` không.
- **Database:** có `ormconfig*`, `prisma/schema.prisma`, `typeorm` config, `docker-compose*` với mysql/postgres không.
- **Scripts:** list `package.json` scripts (dev/build/test/lint/migrate).
- **Env:** có `.env`, `.env.example` không. Cảnh báo `.env` nếu commit.
- **Docker:** có `Dockerfile`, `docker-compose*` không.
- **CI:** có `.github/workflows/*` không.
- **Quality:** có `eslint`, `prettier`, `biome`, `knip`, `vitest`, `jest` config không.

Output dạng bảng:
| Layer | Phát hiện | Gợi ý |
|-------|-----------|--------|

Không chạy tool nặng (npm install, build). Chỉ đọc file và tóm tắt.

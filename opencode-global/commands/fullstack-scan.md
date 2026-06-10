---
description: Quét project full-stack (FE/BE/DB/scripts/env/docker) và in bảng tóm tắt
subtask: true
agent: plan-lite
---

Quét nhanh project full-stack để biết cấu trúc hiện tại.

Detect:

- **Backend:** `nest-cli.json`, `package.json` chứa `@nestjs/*`, `tsconfig.json`, `src/main.ts`.
- **Frontend:** `vite.config.*`, `package.json` chứa `react` + `vite`, `index.html`, `src/main.tsx`.
- **Database:** `prisma/schema.prisma`, `ormconfig*`, `typeorm` config, `docker-compose*` với mysql/postgres.
- **Scripts:** list `package.json` scripts (dev/build/test/lint/migrate/seed).
- **Env:** `.env`, `.env.example`, `.env.local`. Cảnh báo nếu `.env` có track trong git.
- **Docker:** `Dockerfile`, `docker-compose*.yml`, `docker-compose*.yaml`.
- **CI:** `.github/workflows/*` files.
- **Quality:** `eslint`, `prettier`, `biome`, `knip`, `vitest`, `jest`, `tsconfig` config.

Output dạng bảng:

| Layer | Phát hiện | Đề xuất |
|-------|-----------|---------|

Không chạy tool nặng (npm install, build, docker). Chỉ đọc file và tóm tắt.

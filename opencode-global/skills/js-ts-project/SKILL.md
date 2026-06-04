# JS/TS Project

Quy ước khi làm việc với project JavaScript / TypeScript (NestJS, React, Vite, MySQL...).

## Trước khi sửa

- Đọc `package.json` trước — biết scripts (`test`, `build`, `lint`, `dev`).
- Kiểm tra backend và frontend riêng (nếu monorepo).
- Đọc `tsconfig.json` nếu cần hiểu path alias / strict mode.
- Tìm entry point: `src/main.ts`, `src/index.ts`, `src/app.module.ts`...

## Trong khi sửa

- Dùng `knip` để phát hiện dead code / dependency thừa.
- Dùng `lint` (`eslint` / `biome`) và `typecheck` (`tsc --noEmit`) trước khi commit.
- Chạy `test` theo stack: `vitest`, `jest`, `playwright`...
- Không tự sửa migration nguy hiểm — xem skill `database-migration-safe`.

## Không được

- Tự `npm publish` hoặc đổi version.
- Commit `dist/`, `build/`, `node_modules/`.
- Sửa `package-lock.json` / `pnpm-lock.yaml` thủ công.
- Đẩy secret lên repo, kể cả qua file `.env.example`.

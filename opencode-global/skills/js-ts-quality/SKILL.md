# JS/TS Quality

Quy tắc chất lượng code JavaScript / TypeScript.

## TypeScript

### Config tối thiểu (`tsconfig.json`)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  }
}
```

- `strict: true` bắt buộc.
- `noUncheckedIndexedAccess: true` cảnh báo `arr[i]` có thể `undefined`.
- `verbatimModuleSyntax: true` phân biệt rõ `import` và `import type`.

### Code style

- KHÔNG dùng `any`. Dùng `unknown` rồi narrow bằng type guard / Zod parse.
- `enum` của TS có issue (compile sang object). Dùng `as const` object.
- `interface` cho object shape, `type` cho union / intersection.
- Optional field: `field?: string` (không `field: string | undefined` trừ khi cần explicit).
- Function return type: khai báo rõ nếu public / exported.
- Generic: đặt tên `T`, `K`, `V` cho đơn giản, `TItem`, `TResponse` cho phức tạp.

## Lint

- **ESLint** (`eslint.config.*` flat config, hoặc `.eslintrc.*` legacy).
- **Biome** (nhanh, thay thế ESLint + Prettier, single binary).
- **oxlint** (Rust, cực nhanh, dùng cho monorepo lớn).

Rule tối thiểu:

- `no-console` (warn, không error).
- `no-debugger`.
- `eqeqeq`.
- `@typescript-eslint/no-explicit-any` (error).
- `@typescript-eslint/no-unused-vars`.
- `no-floating-promises` (NestJS quan trọng).
- `prefer-const`.

## Format

- **Prettier** (chuẩn, nhiều plugin).
- **Biome** format (nhanh hơn Prettier).
- Config chung: 2 space, single quote, trailing comma all, print width 100.

Config mẫu (`biome.json`):

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "vcs": { "enabled": true, "clientKind": "git" },
  "files": { "ignoreUnknown": true, "ignore": ["dist", "build", "node_modules"] },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": { "formatter": { "quoteStyle": "single", "trailingCommas": "all" } }
}
```

## Dead code

- **Knip** (`knip.json`) — phát hiện unused file, unused export, unused dep.
- Template: `templates/knip.json`.
- Chạy trong CI: `knip --reporter json`.
- Severity HIGH: file / export không dùng → xóa.
- Severity MEDIUM: dep không dùng → bỏ khỏi `package.json`.

## Test

- **Vitest** (ưu tiên — nhanh, ESM native, API giống Jest).
- **Jest** (legacy, dùng khi codebase đã có sẵn).
- Coverage: `vitest --coverage` với `v8` provider.

## Build

- **Vite** (FE).
- **tsc** (BE, NestJS).
- **esbuild / swc** (transform nhanh).
- **Rollup** (library).
- Kiểm tra bundle size: `rollup-plugin-visualizer`, `vite-bundle-visualizer`.
- Cảnh báo nếu bundle chunk > 250KB (gzipped).

## Pre-commit

- **lefthook** (nhanh, Go binary, thay thế husky + lint-staged).
- Hook:
  - `pre-commit`: lint + format (staged file only).
  - `commit-msg`: conventional commit.
  - `pre-push`: typecheck + test (changed packages).

Template: `templates/lefthook.yml`.

## Anti-pattern cần tránn

- ❌ `any` ở boundary.
- ❌ `// @ts-ignore` (dùng `@ts-expect-error` kèm comment nếu bắt buộc).
- ❌ Disable ESLint rule mà không giải thích (`// eslint-disable-next-line` + comment).
- ❌ Format fight giữa Prettier + ESLint (cài `eslint-config-prettier`).
- ❌ Build artifact trong git (`.gitignore` cho `dist`, `build`, `coverage`).
- ❌ Import default + named cùng lúc (`import React, { useState } from 'react'` — sai khi `verbatimModuleSyntax`).

## Reference

- [TypeScript handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [Biome docs](https://biomejs.dev)
- [ESLint](https://eslint.org)
- [Knip](https://knip.dev)
- [Vitest](https://vitest.dev)
- [lefthook](https://lefthook.dev)

---
description: Detect công cụ JS/TS quality (eslint/prettier/biome/knip/vitest/tsc/build)
---

Phát hiện công cụ JS/TS quality trong project, không tự cài:

1. **Lint / format:**
   - `eslint` — `.eslintrc*`, `eslint.config.*`.
   - `prettier` — `.prettierrc*`, `prettier.config.*`.
   - `biome` — `biome.json`.
2. **Type check:**
   - `tsc` — `tsconfig.json`. Đề xuất chạy `tsc --noEmit`.
3. **Dead code:**
   - `knip` — `knip.json` (template có sẵn ở `templates/knip.json`).
4. **Test:**
   - `vitest` — `vitest.config.*`.
   - `jest` — `jest.config.*`.
5. **Build:**
   - `tsc`, `esbuild`, `vite build`, `nest build`, `webpack`, `rollup`.

Output bảng:

| Tool | Config | Version | Đề xuất lệnh |
|------|--------|---------|---------------|

Nếu thiếu tool: in hướng dẫn cài optional (không tự cài).

KHÔNG sudo. KHÔNG tự cài dependency nặng. Chỉ detect.

---
description: SAST scan với semgrep, in hướng dẫn cài nếu thiếu
---

Static analysis security scan với semgrep:

1. Nếu có `semgrep` trong `$PATH`:
   - `semgrep --config=auto --error --json .` (auto-detect ruleset theo stack).
   - Hoặc `semgrep --config=p/javascript --config=p/typescript --config=p/owasp-top-ten .`.
   - In số finding theo severity (INFO / WARNING / ERROR).
2. Nếu project là React/Vite frontend:
   - Thêm `semgrep --config=p/react .`.
3. Nếu project là NestJS backend:
   - Thêm `semgrep --config=p/typescript --config=p/jwt --config=p/expressjs .`.
4. Nếu thiếu semgrep, in hướng dẫn cài:
   ```
   semgrep:  pip install semgrep  /  brew install semgrep
   docs:     https://semgrep.dev/docs/getting-started
   ```
5. KHÔNG sudo. KHÔNG tự cài. Chỉ detect + in hướng dẫn.
6. Scan giới hạn: loại trừ `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`, `vendor/`.

Output:

| Rule | Severity | Count | Top files |
|------|----------|-------|-----------|

Severity: ERROR (block CI) | WARNING | INFO.

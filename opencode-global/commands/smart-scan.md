---
description: Kiểm tra nhanh project hiện tại
---

Kiểm tra nhanh project hiện tại để nắm context tiết kiệm token.

Các lệnh chạy:

- `pwd` — xác định thư mục làm việc.
- `git status --short` — biết có gì đang đổi / untracked.
- `fd -d 3 -t d` — scan cấu trúc thư mục depth 3.
- `fd package.json -d 3` — tìm manifest backend / frontend.
- `fd -e ts -e tsx -e js -d 2 | head -20` — peek file code chính.

KHÔNG đọc toàn repo. KHÔNG mở `node_modules`, `dist`, `build`, `.git`.

Output summary ngắn gồm:

- Stack: ngôn ngữ + framework + DB.
- Entrypoints: backend (NestJS/Express/...), frontend (React/Vue/...).
- Scripts trong `package.json` (test, build, lint, dev).
- Rủi ro: TODO, secrets có thể lộ, migration chưa chạy.
- Gợi ý bước tiếp theo (dùng `/repo-map` nếu cần chi tiết hơn).

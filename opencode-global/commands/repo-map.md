---
description: Tạo bản đồ project tiết kiệm token
subtask: true
---

Tạo bản đồ project tiết kiệm token.

Cách làm:

- Ưu tiên `fd -d 3` để scan cấu trúc nhanh.
- Dùng `rg` thay vì đọc file lớn.
- Dùng `cat package.json` / `cat tsconfig.json` / `cat README.md` cho entrypoint.
- Nếu cần tổng quan code, dùng `repomix --compress`.
- KHÔNG đọc `node_modules`, `dist`, `build`, `.git`, `coverage`.

Output ghi ra `repo-map.md` gồm:

- Cấu trúc thư mục (depth 3).
- Stack: ngôn ngữ, framework, DB.
- Entry points: backend, frontend, scripts.
- Scripts chính trong `package.json` (test, build, lint).
- File quan trọng cần biết trước khi sửa.
- Rủi ro tiềm ẩn (TODO, secrets, migration).

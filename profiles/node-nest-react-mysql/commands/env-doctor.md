---
description: Kiểm tra .env.example, biến thiếu, KHÔNG in secret value
---

Kiểm tra cấu hình môi trường:

- **`.env.example` tồn tại:** có hay không. Có đủ biến cần thiết không.
- **Biến bắt buộc:** liệt kê biến dùng trong code (BE: `process.env.X`, FE: `import.meta.env.VITE_X`). So với `.env.example`.
- **Biến thiếu:** báo cáo biến dùng trong code nhưng không có trong `.env.example`.
- **`.env` thật:** có commit chưa (check `.gitignore`). Cảnh báo nếu có.
- **Frontend leak:** biến nào không prefix `VITE_` mà được dùng trong FE → sẽ undefined.
- **Backend secret:** biến nào dùng làm secret (JWT, DB password, API key) → cảnh báo nếu dùng default.
- **Docker:** `docker-compose.yml` có hardcode secret không.

**QUAN TRỌNG:**
- KHÔNG in giá trị thật của secret ra log.
- Chỉ in TÊN biến và trạng thái `set / unset / missing`.
- Nếu user muốn xem value, hướng dẫn họ tự `echo $VAR`.

Output: bảng Variable | Required | In .env.example | In code | Status.

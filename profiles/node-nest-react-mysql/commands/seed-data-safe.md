---
description: Kiểm tra seed/demo data: an toàn, không xóa dữ liệu thật
---

Kiểm tra script seed / demo data trước khi chạy:

- **File seed:** `prisma/seed.ts`, `src/database/seeds/*`, `scripts/seed*.ts`, ...
- **Hành vi:**
  - Có `DELETE` / `TRUNCATE` không? Nếu có → STOP, yêu cầu xác nhận.
  - Có `INSERT` vào bảng production không? Check `NODE_ENV` / `DATABASE_URL`.
  - Có tạo user admin với password mặc định không? Cảnh báo nếu có.
- **Idempotent:** chạy 2 lần có lỗi unique key không? Tốt nếu upsert.
- **Data:**
  - Có dùng PII thật không (tên thật, email thật)? Cảnh báo.
  - Có hardcode secret trong seed không? Cảnh báo.
- **Transaction:** seed có wrap trong transaction không? Nếu fail giữa chừng có rollback không.
- **Env gate:** seed có chỉ chạy khi `NODE_ENV !== 'production'` không.

Output: bảng Script | Action | Risk | Mitigation.
Nếu có DROP/TRUNCATE/DELETE không guard → báo đỏ, yêu cầu user xác nhận trước khi chạy.

---
description: Kiểm tra database ở chế độ read-only
agent: plan-lite
---

Kiểm tra database theo chế độ read-only:

- Chỉ dùng `SELECT` / `SHOW` / `DESCRIBE` / `EXPLAIN`.
- KHÔNG `DROP TABLE`, `TRUNCATE`, `DELETE`, `UPDATE` hàng loạt.
- KHÔNG chạy migration. KHÔNG đổi schema.

Báo cáo gồm:

- Schema tổng quan (database, danh sách bảng).
- Các bản chính + cột quan trọng + index.
- Quan hệ FK giữa các bảng.
- Dữ liệu nhạy cảm (PII, token, password) nếu phát hiện.
- Rủi ro dữ liệu (bảng to, cột nullable, default nguy hiểm).

Nếu cần thao tác ghi, dừng lại và hỏi user trước khi chạy.

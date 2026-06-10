---
description: Kiểm tra migration và DB an toàn trước khi chạy
agent: plan-lite
---

## ⚠️ Scope Guard — Review an toàn migration, KHÔNG tự thực hiện

Migration-safe chỉ review và kiểm tra an toàn. **KHÔNG** tự chạy migration khi user chỉ yêu cầu
review. Nếu task là docs-only / audit → STOP, dùng main agent.

Kiểm tra migration/DB an toàn trước khi chạy:
- KHÔNG DROP TABLE, KHÔNG TRUNCATE, KHÔNG DELETE hàng loạt không WHERE.
- ADD COLUMN: có default? Có NULL safe? Lock timeout?
- DROP COLUMN: đã backup? có FK reference?
- RENAME: có 2-step (add new, backfill, swap)?
- INDEX: CONCURRENTLY (Postgres), ONLINE (MySQL) — không lock table.
- DATA backfill: batch size, có rollback?
- Down migration: viết ngược, đã test?
- Backup: snapshot DB trước khi chạy nếu > 1GB hoặc prod.

Output: bảng Step | Risk | Mitigation | Rollback.
Nếu thấy DROP/TRUNCATE/DELETE không an toàn → STOP, yêu cầu confirm trước khi chạy.

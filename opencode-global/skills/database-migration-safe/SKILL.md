# Database Migration Safe

Skill review migration trước khi chạy, đặc biệt trên prod có data thật.

## RED FLAGS — STOP ngay

- `DROP TABLE` / `DROP DATABASE` không có backup confirmed.
- `TRUNCATE TABLE` (kể cả có WHERE cũng hiếm khi đúng).
- `DELETE FROM table` không có WHERE, hoặc WHERE quá rộng.
- `UPDATE table SET ...` không có WHERE.
- `ALTER TABLE ... DROP COLUMN` mà column có data thật chưa backup.
- Hardcode `LIMIT 0` hoặc comment out DELETE.
- Chạy migration trực tiếp trên prod từ local mà không qua CI/staging.

## Safe patterns

### Thêm column
```sql
-- Postgres: có default safe với PG 11+
ALTER TABLE users ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active';
-- Lưu ý: default rewrite toàn bộ table nếu column không có default constant.
-- Tốt hơn: ADD nullable → backfill → SET NOT NULL
```

### Xóa column
- 3-step: rename → deprecate code → drop sau 1-2 release.

### Rename
- Tạo column mới, backfill, code đọc cả 2, swap, drop column cũ.

### Index
- Postgres: `CREATE INDEX CONCURRENTLY` (không lock write).
- MySQL: `ALTER TABLE ... ADD INDEX`, có thể lock, chạy off-peak.
- Bảng lớn (>1M rows): cân nhắc online schema tool (pt-online-schema-change, gh-ost, pg_repack).

### Data backfill
- Batch size (1k-10k rows), sleep giữa batch, có resume checkpoint.
- Idempotent: chạy lại được không lỗi.

### Down migration
- Viết trước khi chạy up.
- Test down trên staging giống data prod.
- Có cách chạy 1 phần (ví dụ: chỉ add column, không fill).

## Checklist trước khi chạy

- [ ] Backup DB (snapshot hoặc pg_dump mysqldump).
- [ ] Đã chạy trên staging với data size tương đương.
- [ ] Đo thời gian chạy estimate (lock duration, batch duration).
- [ ] Rollback plan documented + tested.
- [ ] Off-peak window (nếu lock heavy).
- [ ] Monitoring: query duration, replication lag, error rate.

## Output
Bảng:
| Step | Risk | Mitigation | Rollback |

Nếu thấy red flag → STOP, hỏi user xác nhận trước khi chạy. Không tự chạy migration.

# MySQL Schema Safe

Quy tắc thiết kế schema, migration, index, FK, backfill, rollback cho MySQL 8.x.

## Quy tắc chung

- Charset: `utf8mb4`, collation: `utf8mb4_unicode_ci`.
- Engine: `InnoDB` (mặc định từ 5.7+; không dùng MyISAM).
- Time zone: lưu UTC. Server set `time_zone='+00:00'`. Convert ở app layer.
- Boolean: dùng `TINYINT(1)` hoặc `BOOLEAN` (alias). Không dùng `VARCHAR` cho bool.
- Money: `DECIMAL(p, s)` hoặc `BIGINT` (cents). KHÔNG dùng `FLOAT` / `DOUBLE`.
- ID: `BIGINT UNSIGNED AUTO_INCREMENT` cho bảng lớn, hoặc `CHAR(36)` UUID.
- Soft delete: cột `deleted_at DATETIME(3) NULL` + index. Tránh `DELETE` cứng.
- Audit: `created_at`, `updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)`.
- `ON UPDATE CURRENT_TIMESTAMP(3)` cho `updated_at`.

## Naming

- Snake_case cho table + column: `users`, `user_id`, `created_at`.
- Số ít cho table name (`user`) hoặc số nhiều (`users`) — chọn 1 và nhất quán.
- Index: `idx_<table>_<col>` hoặc `uniq_<table>_<col>`.
- FK: `fk_<table>_<reftable>`.
- Không dùng từ khóa MySQL làm tên: `order`, `group`, `key`, `value` → escape hoặc đổi tên.

## Primary key

- Ưu tiên `BIGINT UNSIGNED AUTO_INCREMENT` (rẻ, nhanh, gọn).
- UUID chỉ khi cần merge từ nhiều nguồn hoặc expose ra ngoài.
- Không dùng UUIDv1 (sort tệ, leak MAC). UUIDv4 / UUIDv7 (MySQL 8 chưa có hàm built-in → app gen).
- Composite PK: chỉ khi thật sự cần (bảng quan hệ n-n). Thường thêm surrogate key.

## Foreign key

- Mọi quan hệ phải có FK. KHÔNG để orphan.
- `ON DELETE` / `ON UPDATE`: chọn rõ — `CASCADE`, `RESTRICT`, `SET NULL`.
  - User → Posts: `CASCADE` (xóa user xóa luôn post).
  - Post → User (author): `RESTRICT` (không xóa user còn post).
  - Comment → User: `SET NULL` (giữ comment, tách author).
- Index FK tự động trong MySQL InnoDB (chỉ cần thêm cho non-leading column).

## Index

- Mọi cột dùng trong `WHERE`, `ORDER BY`, `JOIN` thường xuyên → index.
- Composite index: thứ tự = độ chọn lọc giảm dần. `WHERE a=? AND b=?` → `INDEX(a, b)`.
- Không over-index: mỗi index làm chậm INSERT/UPDATE. Đo bằng `EXPLAIN`.
- Covering index: include cột SELECT vào index để tránh lookup.
- Unique index: dùng cho cột unique tự nhiên (email, username, slug).
- Partial index: MySQL không có native → dùng generated column hoặc function index (8.0.13+).

## Migration (TypeORM / Prisma)

- **KHÔNG sync schema** ở production. Migration một chiều, có file version.
- File đặt tên: `2026_06_04_1200-add_user_role.sql` (timestamp + slug).
- Mỗi migration: 1 thay đổi logic. Nhiều bảng → tách migration.
- Test migration 2 chiều: `migrate:up` rồi `migrate:down` phải revert sạch.
- Backup DB trước khi chạy migration lớn ở prod.
- Migration lock: dùng `advisory_lock` hoặc tool hỗ trợ (Flyway, Liquibase) tránh race.

## Backfill

- Khi thêm cột NOT NULL mà bảng đã có data:
  1. Thêm cột NULL.
  2. Backfill data qua batch update (chia nhỏ theo `id` range, tránh lock lâu).
  3. Sau khi backfill xong → set NOT NULL + add constraint.
- KHÔNG add NOT NULL trước khi backfill.
- Log progress: `UPDATE ... WHERE id BETWEEN ? AND ? LIMIT 1000`.
- Test trên dataset lớn (copy prod) trước khi chạy thật.

## Rollback

- Mỗi migration phải có down script rõ ràng.
- Rollback nhanh: đo trước thời gian down → nếu > 30s, có plan B (expand-contract, blue-green).
- Expand-contract pattern:
  1. Add column mới (NULL).
  2. Backfill.
  3. Dual-write app.
  4. Switch read.
  5. Drop column cũ (sau khi ổn định).
- Tránh rollback data lớn: dùng soft delete hoặc archive table.

## DROP / TRUNCATE / DELETE

- `DROP TABLE`: cần review + backup + thông báo team.
- `TRUNCATE TABLE`: reset nhanh, không log. KHÔNG dùng trên prod data.
- `DELETE FROM table` không `WHERE`: review kỹ. Có thể lock toàn bảng.
- Wrap trong transaction + `SELECT ... FOR UPDATE` nếu cần lock row.
- Test trên staging với data size tương đương prod.

## Anti-pattern cần tránn

- ❌ `synchronize: true` trong TypeORM production.
- ❌ `FLOAT` / `DOUBLE` cho money.
- ❌ Thiếu FK, để orphan.
- ❌ Index mọi cột (ghi chậm, tốn disk).
- ❌ `SELECT *` trong production query.
- ❌ `LIKE '%foo%'` không có fulltext index.
- ❌ Migration sửa nhiều bảng không tách.
- ❌ Xóa cột / bảng không thông báo team.
- ❌ Dùng `utf8` cũ (chỉ 3 bytes, lỗi emoji / CJK mở rộng).

## Reference

- [MySQL 8 docs](https://dev.mysql.com/doc/refman/8.0/en/)
- [TypeORM migrations](https://typeorm.io/migrations)
- [Prisma migrate](https://www.prisma.io/docs/orm/prisma-migrate)
- [Use The Index, Luke](https://use-the-index-luke.com)

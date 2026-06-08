# Safety Rules - OpenCode Power Kit

## Nguyên tắc chung

**KHÔNG BAO GIỜ:**
1. Copy token, password, API key, `.env` vào repo.
2. Xóa file ngoài thư mục project hiện tại.
3. `git reset --hard` mà chưa confirm.
4. `git push --force` lên main/master.
5. `DROP TABLE`, `TRUNCATE`, `DELETE` hàng loạt mà chưa confirm.
6. Sửa `.env`, secrets, credentials.
7. Commit secrets hoặc API keys.
8. Chạy `rm -rf` trên thư mục system.
9. Tự push nếu chưa được yêu cầu.

## Khi làm việc với Database

```sql
-- LUÔN chạy trước khi DELETE/UPDATE
SELECT COUNT(*) FROM table_name WHERE condition;

-- LUÔN backup trước migration lớn
-- mysqldump -u user -p database > backup_$(date +%Y%m%d).sql

-- KHÔNG BAO GIỜ
DROP TABLE ...;           -- trừ khi user confirm
TRUNCATE ...;             -- trừ khi user confirm
DELETE FROM ...;          -- luôn cần WHERE clause
```

## Khi làm việc với Git

```bash
# An toàn
git status                  # luôn chạy trước
git diff                    # xem thay đổi
git stash                   # lưu tạm
git checkout -b <branch>    # tạo branch mới

# NGUY HIỂM - cần confirm
git reset --hard            # MẤT dữ liệu
git push --force            # GHI ĐÈ LÊN REMOTE
git clean -fd               # XÓA untracked files
```

## Khi copy file

- Không copy `.env`, `.env.local`, `.env.*.local`.
- Không copy `node_modules/`, `dist/`, `build/`.
- Không copy file chứa token/password/secrets.
- Không copy file có `*.key`, `*.pem`, `*.cert`.

## Cleanup khi hoàn thành

```bash
# Xem file sẽ xóa
git clean -nd

# Xóa an toàn (không dùng -fd nếu chưa confirm)
# Ưu tiên dùng trash-put thay vì rm

# Kiểm tra cuối
git status --short
```

## Escalation

Nếu phát hiện:
- Secrets bị commit → **ngay lập tức** xóa khỏi git history.
- Database bị DROP → **ngay lập tức** restore từ backup.
- File system bị xóa ngoài ý muốn → **ngay lập tức** stop và inform user.

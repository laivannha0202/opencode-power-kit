# Agent Rules - OpenCode Project

## Quy tắc bắt buộc

1. **Đọc AGENTS.md và OPENCODE.md trước khi sửa bất kỳ file nào.**
2. **Trước khi sửa code phải chạy `git status`** để xác nhận trạng thái working tree.
3. **Dùng `rg`, `fd`, `ast-grep`** để tìm file/code, không dùng `grep`/`find` thủ công.
4. **Không đọc toàn bộ repo** nếu task chỉ liên quan 1 module.
5. **Không xóa file** trừ khi được yêu cầu rõ ràng.
6. **Không `git reset --hard`**, không `git push --force`, không `git clean -fd`.

## An toàn dữ liệu

7. **Không sửa `.env`, secrets, tokens, API keys.**
8. **Với MySQL/PostgreSQL:**
   - Không `DROP TABLE`, `TRUNCATE`, `DELETE` hàng loạt nếu chưa được yêu cầu rõ.
   - Luôn chạy `SELECT COUNT(*)` trước khi DELETE/UPDATE.
   - Backup database trước migration lớn.
9. **Không commit secrets**, kiểm tra `.gitignore` trước khi `git add`.

## Quy trình làm việc

10. **Sau khi sửa phải báo cáo:**
    - File đã sửa
    - Lý do sửa
    - Test đã chạy (nếu có)
11. **Ưu tiên sửa ít file nhất** có thể để hoàn thành task.
12. **Chạy lint/typecheck** sau khi sửa code (nếu project có).

## Token saving

- Ưu tiên tiết kiệm token.
- Không đọc toàn bộ repo nếu task chỉ liên quan một module.
- Trước khi mở file lớn, dùng `rg`, `fd`, `sg`, `git diff --stat`.
- Khi chạy lệnh terminal có output dài, ưu tiên dùng `rtk` nếu có.
- Không mở `node_modules`, `dist`, `build`, `coverage`, `.git`.

## Search workflow

- Tìm text/code bằng `rg`.
- Tìm file bằng `fd`.
- Tìm pattern JS/TS bằng `sg`.
- Xem thay đổi bằng `git diff --stat` trước, rồi mới xem diff chi tiết nếu cần.

## Cleanup protocol

- Cuối mỗi task phải chạy `git status --short`.
- Nếu tạo file debug/test/temp/scratch/log thì phải dọn.
- Không dùng `rm -rf`.
- Ưu tiên dùng `trash-put` thay vì `rm`.
- Trước khi xóa untracked files phải chạy `git clean -nd` để xem trước.

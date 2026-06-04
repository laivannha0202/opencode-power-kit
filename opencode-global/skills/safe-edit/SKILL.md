# Safe Edit

Quy tắc an toàn khi sửa code. Áp dụng cho mọi task có thay đổi file.

## Không được

- Không xóa file trừ khi user yêu cầu rõ ràng.
- Không `git reset --hard`, không `git push --force`, không `git clean -fd`.
- Không sửa `.env`, `secrets`, token, password, API key.
- Không tự chạy `curl | sh` hoặc cài global khi chưa hỏi.
- Không chạy lệnh DB hủy diệt (`DROP TABLE`, `TRUNCATE`, `DELETE` hàng loạt) nếu chưa xác nhận.

## Bắt buộc

- Chạy `git status` trước khi sửa bất kỳ file nào.
- Backup file quan trọng trước khi overwrite.
- Sau khi sửa, chạy lại `git status` để xác nhận diff đúng phạm vi.
- Báo cáo file đã sửa + lý do + test đã chạy.

## DB destructive

- Câu lệnh `DROP`, `TRUNCATE`, `DELETE` không `WHERE`, `UPDATE` hàng loạt: phải dừng lại hỏi user.
- Migration lớn: backup DB trước, có rollback plan.
- Chạy `SELECT COUNT(*)` trước khi `UPDATE` / `DELETE` để biết ảnh hưởng.

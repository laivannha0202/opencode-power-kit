---
description: Review thay đổi hiện tại bằng git diff
---

Review thay đổi hiện tại bằng `git diff` và `git diff --stat`.

Quy trình:

- Chạy `git status --short` để biết những file nào đang đổi.
- Chạy `git diff --stat` để thấy quy mô thay đổi.
- Chạy `git diff` (hoặc `git diff -- <file>`) để xem chi tiết.
- KHÔNG sửa file. Chỉ review.

Tập trung vào:

- Bug logic: off-by-one, null check, async/await sai, race condition.
- Security: SQL injection, XSS, command injection, path traversal, secrets.
- DB: thiếu WHERE, migration nguy hiểm, missing transaction.
- API contract: FE gọi khác BE trả, type sai, status code sai.
- Frontend / backend mismatch: tên field, format ngày, encoding.

Output: bảng ngắn `File:Line | Issue | Severity | Fix`.

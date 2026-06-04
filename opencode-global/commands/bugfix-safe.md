---
description: Sửa bug theo quy trình an toàn
---

Sửa bug theo quy trình an toàn:

- Chạy `git status` trước khi sửa bất kỳ file nào.
- Tái hiện lỗi nếu có thể (repro script, log, request mẫu).
- Dùng `rg` / `fd` / `ast-grep` / `Serena` để tìm file liên quan.
- Lập plan ngắn trước khi sửa (mục tiêu, file, rủi ro, test).
- Sửa ít file nhất có thể, đừng refactor lân cận.
- Chạy test / build / typecheck phù hợp stack.
- Báo cáo: file đã sửa, lý do, test đã chạy, kết quả.
- Không tự push. Không reset hard. Không sửa `.env` / secrets.

---
description: Kiểm tra env config an toàn, không in secret value
---

Kiểm tra env config của project, an toàn, không leak secret value.

1. Tìm file env:
   - `.env`, `.env.local`, `.env.production`, `.env.development`.
   - `.env.example`, `.env.sample` (template — OK).
2. Với mỗi file, check:
   - Có trong `.gitignore` không (file thật như `.env` phải ignore, `.env.example` không cần).
   - Có track trong git không: `git ls-files | grep -E '^\.env(\.|$)'` (cảnh báo nếu có).
3. So sánh `.env` (nếu tồn tại) với `.env.example`:
   - Biến trong `.env` mà thiếu trong `.env.example` → cảnh báo (có thể là secret mới chưa document).
   - Biến trong `.env.example` mà thiếu trong `.env` → cảnh báo.
4. Check biến bắt buộc (định nghĩa theo stack, ví dụ NestJS: `DATABASE_URL`, `JWT_SECRET`).
5. In giá trị? **KHÔNG**. Chỉ in tên biến + placeholder (mask).
   - Hiển thị: `DB_HOST=***`.
   - Không bao giờ in value ra log.
6. Nếu phát hiện secret value trong `.env.example` → cảnh báo CRITICAL.

Output:

| File | Tracked | Biến thiếu | Biến thừa | Risk |
|------|---------|------------|-----------|------|

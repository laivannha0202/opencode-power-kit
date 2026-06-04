---
description: Tạo gói context gọn bằng Repomix
---

Tạo gói context gọn bằng Repomix để paste vào LLM hoặc chia sẻ repo.

Lệnh chạy:

```bash
repomix --compress --remove-comments --remove-empty-lines --output repomix-output.xml
```

Tuỳ chọn hữu ích:

- `--include "src/**,docs/**"` — chỉ lấy một số thư mục.
- `--ignore "**/node_modules,**/dist,**/build,**/.git"` — bỏ qua rác.
- `--style xml` — đổi format (mặc định: XML).
- `--top-files-length 20` — top file chiếm nhiều token nhất.

Sau khi chạy, báo cáo:

- Tổng số file, tổng số dòng.
- Số token ước tính (Repomix in ra ở cuối).
- Top 5 file lớn nhất (đường dẫn + % token).
- Rủi ro: phát hiện secrets, file binary, file nhạy cảm.

KHÔNG commit `repomix-output.xml` vào repo. KHÔNG gửi file chứa secrets ra ngoài.

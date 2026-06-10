---
description: Convert tài liệu (PDF/DOCX/HTML/PPTX/XLSX) sang Markdown bằng MarkItDown
---

Convert tài liệu (PDF, DOCX, HTML, PPTX, XLSX, CSV, JSON, XML, ZIP) sang
Markdown bằng Microsoft MarkItDown (opt-in, không built-in).

## Yêu cầu

- `opk markitdown status` — kiểm tra nếu chưa cài.
- Nếu chưa cài: `opk markitdown install` (cần Python 3 + pipx/pip).

## Cách dùng

```bash
# Convert file sang Markdown
opk md-convert input.pdf output.md
opk md-convert input.docx output.md

# Ghi đè output nếu đã tồn tại
opk md-convert input.html output.md --force

# Alias: doc-to-md
opk doc-to-md input.pptx output.md
opk doc-to-md input.xlsx output.md
```

## Hỗ trợ định dạng

| Input | MarkItDown |
|-------|------------|
| PDF   | ✅ |
| DOCX  | ✅ |
| PPTX  | ✅ |
| XLSX  | ✅ |
| HTML  | ✅ |
| CSV   | ✅ |
| JSON  | ✅ |
| XML   | ✅ |
| ZIP (archive) | ✅ |
| Images (via plugin) | ⚠️ cần `markitdown[all]` |

## Giới hạn

- KHÔNG tự cài MarkItDown — chỉ chạy khi user yêu cầu.
- KHÔNG convert file nhạy cảm (`.env`, `.secret`, `*credential*`, `*token*`).
- KHÔNG ghi đè output nếu không có `--force`.
- KHÔNG dùng sudo, curl\|sh, pip không --user.

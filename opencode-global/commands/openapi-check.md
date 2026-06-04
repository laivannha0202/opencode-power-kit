---
description: Kiểm tra OpenAPI spec với spectral/oasdiff, in hướng dẫn cài nếu thiếu
---

Kiểm tra OpenAPI spec nếu project có:

1. Tìm file OpenAPI: `openapi.yaml`, `openapi.yml`, `openapi.json`, `swagger.json`, `swagger.yaml`.
2. Nếu có `spectral` trong `$PATH`:
   - Chạy `spectral lint <openapi-file> --ruleset <rules>` (mặc định dùng `templates/openapi/spectral.yaml.example` nếu tồn tại).
   - In kết quả: số warning / error.
3. Nếu có `oasdiff` trong `$PATH`:
   - So sánh với version cũ (git diff): `oasdiff diff <old> <new>`.
   - In breaking changes.
4. Nếu thiếu tool, in hướng dẫn cài:
   ```
   spectral:  npm i -g @stoplight/spectral-cli
   oasdiff:   brew install oasdiff  /  go install github.com/oasdiff/oasdiff/cmd/oasdiff@latest
   ```
5. Nếu không có OpenAPI file, in:
   "Không tìm thấy OpenAPI spec. Đề xuất: dùng `@nestjs/swagger` (NestJS) hoặc tự viết từ controller."
6. KHÔNG tự cài. KHÔNG sudo. Chỉ detect + in hướng dẫn.

Output:

| File | Spectral | OASDiff | Breaking changes |
|------|----------|---------|------------------|

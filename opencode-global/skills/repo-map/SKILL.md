# Repo Map

Cách tạo repo-map ngắn gọn để nắm nhanh project trước khi sửa.

## Quy trình

- Dùng `fd -d 3` để scan cấu trúc nhanh.
- Dùng `rg` thay vì đọc file lớn.
- Dùng `repomix --compress` nếu cần tổng quan code nhiều file.
- Đọc `package.json` / `tsconfig.json` / `README.md` để biết stack.

## Loại trừ

- `node_modules`
- `dist`
- `build`
- `coverage`
- `.git`
- `.next`, `.nuxt`, `.cache`

## Output

Ghi ra `repo-map.md` gồm:

- Cấu trúc thư mục (depth 3).
- Stack: ngôn ngữ, framework, DB.
- Entry points: backend, frontend, scripts.
- Scripts chính trong `package.json`.
- File quan trọng cần biết trước khi sửa.
- Rủi ro tiềm ẩn (TODO, secrets, migration).

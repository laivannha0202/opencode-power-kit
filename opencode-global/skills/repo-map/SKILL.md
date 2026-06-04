# Repo Map

Cách tạo repo-map ngắn:
- Dùng `fd -d 3` để scan cấu trúc nhanh.
- Dùng `rg` thay vì đọc file lớn.
- Dùng `repomix --compress` nếu cần tổng quan code.
- Loại trừ: node_modules, dist, build, coverage, .git.
- Output ghi ra repo-map.md.

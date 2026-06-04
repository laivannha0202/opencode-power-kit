# Token-Smart Code

Tiết kiệm token khi đọc / sửa code. Đặc biệt quan trọng với repo lớn.

## Nguyên tắc

- Với task lớn, KHÔNG đọc toàn repo.
- Luôn bắt đầu bằng `git status`, `fd`, `rg`.
- Dùng Serena nếu cần hiểu symbol (class, function, interface).
- Dùng `repomix --compress` chỉ khi cần tổng quan nhiều file.
- KHÔNG paste file dài vào context nếu chỉ cần vài function.

## Quy trình gợi ý

1. `git status --short` — biết phạm vi thay đổi.
2. `fd -t f -e ts -e tsx -d 3 | head -30` — peek file chính.
3. `rg <pattern>` — tìm nhanh theo pattern.
4. `serena find_symbol` / `get_symbols_overview` — nếu cần hiểu class.
5. `repomix --compress` — chỉ khi summary toàn repo thực sự cần.

## Không được

- Đọc `node_modules`, `dist`, `build`, `coverage`, `.git`.
- Paste log dài (>100 dòng) không cắt.
- Đọc `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` để "hiểu" project.

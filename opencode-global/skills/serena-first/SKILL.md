# Serena First

Dùng Serena cho semantic code retrieval và editing khi cần hiểu class / function / symbol.

## Nguyên tắc

- Không `grep` mù toàn repo nếu có thể truy vấn symbol qua Serena.
- Sau khi tìm đúng symbol, mới đọc file liên quan (giới hạn scope).
- Ưu tiên `find_symbol` / `find_referencing_symbols` / `get_symbols_overview`.

## Khi nào dùng

- Cần biết class / function nào đang gọi hàm X.
- Cần xem body đầy đủ của method mà không đọc cả file.
- Refactor symbol cần chắc chắn không miss reference.

## Khi KHÔNG dùng

- Tìm string đơn giản → dùng `rg` nhanh hơn.
- Tìm file theo tên → dùng `fd` nhanh hơn.
- Task nhỏ, file đã biết rõ → mở file trực tiếp.

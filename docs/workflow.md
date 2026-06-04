# Workflow - OpenCode Power Kit

## Quy trình làm việc chuẩn

### 1. Nhận task
- Đọc kỹ yêu cầu từ user.
- Nếu mơ hồ → hỏi lại.
- Xác định: bug fix, feature, refactor, hay research.

### 2. Khám phá codebase
```bash
# Tìm file liên quan
fd <tên_file_pattern>
rg "<keyword>" --type ts

# Xem thay đổi gần đây
git log --oneline -10
git diff --stat HEAD~3
```

### 3. Lập plan
- Xác định ít file nhất cần sửa.
- Kiểm tra dependencies giữa các file.
- Chọn tool phù hợp (Superpowers / BMAD).

### 4. Thực hiện
- Tạo branch nếu cần: `git checkout -b fix/<mô_tả>`
- Sửa code theo plan.
- Chạy test: `npm test` hoặc `npx jest`.
- Chạy lint: `npm run lint`.
- Chạy typecheck: `npx tsc --noEmit`.

### 5. Verify
```bash
# Kiểm tra trạng thái
git status
git diff

# Chạy full check
npm run lint && npx tsc --noEmit && npm test
```

### 6. Commit & Report
```bash
git add <files>
git commit -m "type: mô tả ngắn gọn"
```

Báo cáo:
- File đã sửa
- Lý do sửa
- Test đã chạy

## Khi nào dùng Superpowers vs BMAD

| Tình huống | Tool |
|-----------|------|
| Sửa bug đơn giản | Superpowers (debugging) |
| Refactor 1-2 file | Superpowers |
| Code review | Superpowers (review) |
| Tạo project mới | BMAD |
| PRD / Requirements | BMAD |
| Phân tích domain | BMAD |
| Task > 5 file | BMAD |

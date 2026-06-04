Triển khai 1 lát cắt (slice) nhỏ theo plan đã chốt:
- Mỗi slice ≤ 2 file, ≤ 100 dòng diff.
- Trước khi sửa: git status, git diff --stat.
- Sửa ít nhất có thể — không refactor lân cận.
- Sau khi sửa: chạy test/build liên quan (xem plan).
- Commit atomic với message: type(scope): short.
- Báo cáo: file đã sửa, test đã chạy, kết quả.

Không tự push. Không sửa file ngoài slice. Nếu slice phình → dừng, quay lại plan.

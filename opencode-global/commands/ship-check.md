Checklist trước khi commit/push:
- [ ] git status sạch (không file scratch/temp).
- [ ] git diff --stat gọn, không refactor ngoài scope.
- [ ] Không có .env, token, secret, password, api_key trong diff.
- [ ] Đã chạy test/typecheck/lint.
- [ ] Không có console.log / print debug / TODO rác.
- [ ] Commit message dạng: type(scope): short.
- [ ] Branch đúng (main / feature / fix).
- [ ] Push: git push origin <branch>.

Nếu thiếu mục nào: dừng, xử lý xong rồi quay lại. Không push force. Không --no-verify.

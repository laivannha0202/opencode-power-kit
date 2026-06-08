# Agent Rules - OpenCode Project

## Quy tắc bắt buộc

1. **Đọc AGENTS.md và OPENCODE.md trước khi sửa bất kỳ file nào.**
2. **Trước khi sửa code phải chạy `git status`** để xác nhận trạng thái working tree.
3. **Dùng `rg`, `fd`, `ast-grep`** để tìm file/code, không dùng `grep`/`find` thủ công.
4. **Không đọc toàn bộ repo** nếu task chỉ liên quan 1 module.
5. **Không xóa file** trừ khi được yêu cầu rõ ràng.
6. **Không `git reset --hard`**, không `git push --force`, không `git clean -fd`.

## An toàn dữ liệu

7. **Không sửa `.env`, secrets, tokens, API keys.**
8. **Với MySQL/PostgreSQL:**
   - Không `DROP TABLE`, `TRUNCATE`, `DELETE` hàng loạt nếu chưa được yêu cầu rõ.
   - Luôn chạy `SELECT COUNT(*)` trước khi DELETE/UPDATE.
   - Backup database trước migration lớn.
9. **Không commit secrets**, kiểm tra `.gitignore` trước khi `git add`.

## Quy trình làm việc

10. **Sau khi sửa phải báo cáo:**
    - File đã sửa
    - Lý do sửa
    - Test đã chạy (nếu có)
11. **Ưu tiên sửa ít file nhất** có thể để hoàn thành task.
12. **Chạy lint/typecheck** sau khi sửa code (nếu project có).

## Token saving

- Ưu tiên tiết kiệm token.
- Không đọc toàn bộ repo nếu task chỉ liên quan một module.
- Trước khi mở file lớn, dùng `rg`, `fd`, `sg`, `git diff --stat`.
- Khi chạy lệnh terminal có output dài, ưu tiên dùng `rtk` nếu có.
- Không mở `node_modules`, `dist`, `build`, `coverage`, `.git`.

## Search workflow

- Tìm text/code bằng `rg`.
- Tìm file bằng `fd`.
- Tìm pattern JS/TS bằng `sg`.
- Xem thay đổi bằng `git diff --stat` trước, rồi mới xem diff chi tiết nếu cần.

## Cleanup protocol

- Cuối mỗi task phải chạy `git status --short`.
- Nếu tạo file debug/test/temp/scratch/log thì phải dọn.
- Không dùng `rm -rf`.
- Ưu tiên dùng `trash-put` thay vì `rm`.
- Trước khi xóa untracked files phải chạy `git clean -nd` để xem trước.

## Full Auto Permission Mode (v1.6.0)

**OpenCode được cấu hình với `"permission": "allow"`.** Agent có thể
tự chạy tool, sửa file, tạo file, chạy bash/test/build mà **không hỏi
lại permission**. Phù hợp máy/project cá nhân.

### Safety rules — vẫn tuân thủ

Dù `permission: allow`, agent vẫn phải tuân theo các safety rule sau
(được enforce bằng instruction, không phải bằng OpenCode permission
prompt):

1. **Không tự `git push`** nếu user chưa yêu cầu rõ.
2. **Không tự `git reset --hard`**, `git clean -fd`.
3. **Không tự xóa file lớn/hàng loạt** nếu chưa cần.
4. **Không tự sửa `.env`/secrets/token** nếu user chưa yêu cầu rõ.
5. **Trước task lớn:** chạy `git status` và báo tóm tắt.
6. **Sau task:** chạy `git diff --stat` và báo cáo bằng tiếng Việt.

### Kế thừa agent frontmatter (backward compatible)

Mỗi agent vẫn giữ `permission` frontmatter với `"*": "ask"` fallback
và safe command allowlist. Khi copy template qua project mới, agent
vẫn hoạt động an toàn — **Full Auto Permission Mode** là global
config override cho phép agent bypass permission prompt.

---

## Checkpoints

- Trước khi sửa lớn, dùng `/checkpoint` để snapshot working tree ra
  `.opk-checkpoints/<ts>.patch` + `.summary.md`.
- Không `git reset --hard` để "undo" — restore từ patch bằng `git apply`.

---

## Vietnamese Language Lock

Đây là rule bắt buộc cho toàn bộ tương tác:

1. **Mặc định trả lời user bằng tiếng Việt.** Toàn bộ kế hoạch, giải thích, báo cáo, kết luận phải bằng tiếng Việt.
2. **Giữ tiếng Anh cho:** tên lệnh, slash command, tên agent, tên file/path, code, API, package name, error log, stacktrace, keyword kỹ thuật bắt buộc.
3. **Không tự chuyển câu trả lời sang tiếng Anh.** Nếu user viết tiếng Việt thì agent trả lời tiếng Việt.
4. **Code/comment trong repo giữ nguyên.** Không dịch code comment hay tài liệu có sẵn.
5. **Nếu user yêu cầu tiếng Anh** thì mới dùng tiếng Anh.
6. **Cuối task báo cáo bằng tiếng Việt** gồm: đã làm gì, file đã sửa, kiểm tra đã chạy, rủi ro còn lại.

---

## Natural Language Auto Router (v1.3.3)

User có thể nói tự nhiên, không cần nhớ slash command. Khi user nói
một câu casual (tiếng Việt / tiếng Anh), agent tự suy ra workflow
và chạy an toàn. Slash command luôn thắng auto-router.

### 1. Bugfix intent

Triggers: "fix lỗi", "sửa bug", "nó lỗi", "chạy không được",
"doesn't work", "it's broken", "fix this".

- Reproduce hoặc inspect lỗi trước.
- Đọc đúng file liên quan.
- Tìm root cause trước khi sửa.
- Sửa nhỏ nhất có thể.
- Chạy test/build/typecheck liên quan.
- Không xóa file trừ khi user yêu cầu rõ.
- Báo cáo: file sửa, nguyên nhân, fix, verification.

### 2. Project health intent

Triggers: "kiểm tra project", "scan all", "xem ổn chưa",
"check the project", "is this healthy".

- Inspect repo structure.
- Detect stack + scripts.
- Check `git status`.
- Check lint / test / build commands.
- Báo risks + next actions cụ thể.

### 3. Feature intent

Triggers: "làm tính năng", "thêm chức năng", "code fullstack",
"build a feature", "add this feature".

- Spec-lite → plan-work → build-slice → test-proof.
- Viết acceptance criteria ngắn.
- Chia thành vertical slices nhỏ.
- Sửa đúng file cần.
- Frontend / backend / API / DB contract phải khớp.
- Verify bằng test hoặc manual proof.

### 4. Token-smart intent

Triggers: "tiết kiệm token", "đừng đọc lan man",
"làm dài không ngắt", "save tokens", "keep it short".

- Build compact repo map trước.
- Đọc đúng file cần.
- Giữ running handoff summary.
- Patch nhỏ.
- Update `AI_HANDOFF.md` sau khi xong việc lớn.

### 5. Cleanup intent

Triggers: "dọn rác", "xóa file bug tự tạo", "cleanup",
"clean up the temp files".

- Chạy `git status` trước.
- Chỉ chạm untracked temp/debug/repro files.
- Không xóa tracked file.
- Move vào `.opk-trash/` thay vì `rm`.
- Sinh `CLEANUP_REPORT.md` nếu cần.

### Default behavior

- Mơ hồ → inspect trước, hành động thận trọng.
- Cấm `git reset --hard`, `git clean -fd`, `rm -rf`, force push.
- Cấm in secret hoặc sửa `.env` secret.
- Slash command luôn thắng auto-router.

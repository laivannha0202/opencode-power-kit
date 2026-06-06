# OpenCode Project Guide

## Khi nào dùng Superpowers

- Sửa bug → dùng Superpowers debugging skill.
- Refactor code → dùng Superpowers systematic approach.
- Code review → dùng Superpowers review skill.
- Tối ưu performance → dùng Superpowers performance skill.

## Khi nào dùng BMAD Method

- Task lớn / tạo project mới → dùng BMAD workflow.
- Phân tích yêu cầu → dùng BMAD requirements phase.
- Tạo PRD → dùng BMAD PRD template.
- Phân tích domain → dùng BMAD domain research.

## Quy trình chung

1. **Hiểu yêu cầu** — đọc kỹ, hỏi lại nếu mơ hồ.
2. **Tìm file liên quan** — dùng `rg`, `fd`, `ast-grep`.
3. **Lập plan** — xác định ít file nhất cần sửa.
4. **Sửa code** — sửa chính xác, không refactor thừa.
5. **Test** — chạy test có sẵn hoặc tạo test mới nếu cần.
6. **Report** — báo cáo file sửa, lý do, test results.

## Tech stack thường dùng

- **Backend:** NestJS (TypeScript)
- **Frontend:** React + Vite
- **Database:** MySQL / PostgreSQL
- **ORM:** Prisma / TypeORM
- **Testing:** Jest / Vitest
- **CI/CD:** GitHub Actions

## Coding conventions

- TypeScript strict mode.
- Functional components + hooks (React).
- Controller → Service → Repository pattern (NestJS).
- naming: `camelCase` cho biến/hàm, `PascalCase` cho class/component.
- Mỗi file max ~300 dòng, split nếu dài hơn.

---

## Natural Language Auto Router (v1.3.3)

User nói tự nhiên — không cần nhớ slash command. Khi user nói câu
casual (tiếng Việt / tiếng Anh), agent tự suy ra workflow an toàn
và chạy. Slash command luôn thắng auto-router.

### 1. Bugfix intent

Triggers: "fix lỗi", "sửa bug", "nó lỗi", "chạy không được",
"doesn't work", "fix this".

- Reproduce / inspect lỗi trước.
- Đọc đúng file liên quan.
- Root cause trước khi sửa.
- Sửa nhỏ nhất.
- Test/build/typecheck.
- Không xóa file trừ khi user yêu cầu.
- Báo cáo file sửa, nguyên nhân, fix, verify.

### 2. Project health intent

Triggers: "kiểm tra project", "scan all", "xem ổn chưa",
"check the project", "is this healthy".

- Inspect repo + detect stack.
- Check `git status`.
- Check lint / test / build.
- Báo risks + next actions.

### 3. Feature intent

Triggers: "làm tính năng", "thêm chức năng", "code fullstack",
"build a feature".

- Spec-lite → plan → slice → proof.
- Acceptance criteria ngắn.
- Vertical slices nhỏ.
- Frontend / backend / API / DB contract khớp.
- Verify bằng test.

### 4. Token-smart intent

Triggers: "tiết kiệm token", "đừng đọc lan man",
"save tokens", "keep it short".

- Repo map gọn.
- Đọc đúng file.
- Handoff summary liên tục.
- Patch nhỏ.
- Update `AI_HANDOFF.md` sau việc lớn.

### 5. Cleanup intent

Triggers: "dọn rác", "xóa file bug tự tạo", "cleanup".

- `git status` trước.
- Chỉ untracked temp/debug/repro.
- Không xóa tracked file.
- Move vào `.opk-trash/`.
- `CLEANUP_REPORT.md` nếu cần.

### Default

- Mơ hồ → inspect trước, hành động thận trọng.
- Cấm `git reset --hard`, `git clean -fd`, `rm -rf`, force push.
- Cấm in secret / sửa `.env` secret.
- Slash command thắng auto-router.

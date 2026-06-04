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

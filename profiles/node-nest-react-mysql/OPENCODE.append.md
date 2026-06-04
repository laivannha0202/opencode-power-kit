<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->

## Full-Stack Workflow (NestJS + React/Vite + MySQL)

Phần này append tự động. Workflow mặc định cho mọi task full-stack.

### Bắt đầu task

1. Đọc `AGENTS.md` (đã có rule layer).
2. Chạy `/fullstack-scan` để xem project trông thế nào.
3. Chạy `/env-doctor` nếu nghi ngờ env.
4. Chạy `/docker-dev-doctor` nếu dùng docker-compose cho DB.

### Trong khi code

- **Sửa DB:** viết migration trước, test rollback. KHÔNG sync schema.
- **Sửa BE:** DTO + validator trước khi đụng service. Test service với mock repo.
- **Sửa FE:** Chạy `tsc --noEmit` + lint. Test component với Testing Library.
- **Sửa full flow:** dùng `/api-e2e-flow` để check contract UI ↔ API ↔ DB.

### Trước khi commit

- Chạy test của layer đã sửa.
- Chạy `/api-e2e-flow` nếu có thay đổi endpoint.
- Chạy `/ship-check` (global) cho checklist chung.
- Commit tách: `feat(db): ...`, `feat(be): ...`, `feat(fe): ...` nếu có thể.

### Trước khi push

- `/security-review` cho code có auth / input / upload.
- `/api-contract-review` nếu đổi endpoint.
- `/migration-safe` nếu có migration mới.

### Khi cần tools (optional)

- API spec → `/openapi-check`.
- Secret scan → `/secret-scan`.
- SAST → `/sast-check`.
- E2E plan → `/e2e-plan`.
- Test matrix → `/test-matrix`.
- JS/TS quality → `/js-quality-check`.
- Docker dev → `/docker-dev-doctor`.
- Env → `/env-doctor`.

<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-end -->

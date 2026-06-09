<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->

## Scope Gate — Fullstack workflow chỉ chạy khi user yêu cầu code

Fullstack workflow DB → BE → FE (migration → entity → DTO → service → controller → FE)
**CHỈ** áp dụng khi user yêu cầu code/fix/build rõ ràng (feature, bugfix, refactor,
thêm/sửa endpoint, migration mới).

Nếu user ghi docs-only/read-only/chỉ kiểm tra/không sửa file:
- KHÔNG chạy fullstack workflow
- KHÔNG chạy migration
- KHÔNG sửa backend/frontend/database
- Nếu phát hiện code lệch spec → chỉ ghi checklist, không sửa
- Sau khi báo cáo → dừng

---

## Full-Stack Rules (NestJS + React/Vite + MySQL)

Phần này được append tự động bởi `install-fullstack-profile.sh`.
KHÔNG xóa marker nếu muốn script idempotent.

### Backend (NestJS)

- **Layer:** Controller → Service → Repository. Không truy cập DB trực tiếp từ controller.
- **DTO:** Mọi input API có DTO + `class-validator`. Không nhận `any` ở boundary.
- **Guard:** Mọi route private phải có `@UseGuards(AuthGuard)` + role guard nếu cần.
- **Error:** Dùng `HttpException` chuẩn (400/401/403/404/409/422). Không trả stack trace ra response.
- **Logger:** Dùng Nest `Logger`. Không log token / password / PII.
- **Config:** Đọc từ `ConfigService` (`@nestjs/config`), không `process.env` rải rác.
- **Async:** Promise trả về từ service phải có try/catch ở controller hoặc global filter.

### Frontend (React + Vite)

- **Component:** Functional + hooks. Mỗi file ≤ 300 dòng.
- **API client:** Centralize (axios instance hoặc fetch wrapper). Không gọi `fetch` rải rác.
- **State:** Server state → React Query / SWR. Client state → Zustand / Context. Không dùng Redux trừ khi cần.
- **Form:** React Hook Form + Zod schema. Không validate tay trong onSubmit.
- **Routing:** React Router v6+. Route private wrap trong `ProtectedRoute`.
- **Type:** `strict: true`. Không `any`. Dùng `unknown` rồi narrow.
- **Env:** Chỉ `VITE_*` được expose ra client. Không đặt secret trong `.env` frontend.

### Database (MySQL)

- **Migration:** Dùng TypeORM migrations hoặc Prisma migrate. KHÔNG sửa schema bằng sync.
- **Transaction:** Mọi write nhiều bảng phải wrap transaction.
- **Index:** FK + index cho mọi cột dùng trong WHERE/ORDER BY thường xuyên.
- **Charset:** `utf8mb4` + `utf8mb4_unicode_ci`. Không dùng `utf8` cũ.
- **Time:** Lưu `DATETIME(3)` UTC. Server set `time_zone='+00:00'`.
- **Soft delete:** Cột `deleted_at` nếu cần audit, không `DELETE` cứng trừ khi yêu cầu rõ.

### Auth / RBAC

- **Token:** JWT access (15-30 phút) + refresh (7-30 ngày). Refresh rotation.
- **Storage (FE):** Không lưu token trong `localStorage` nếu có thể — ưu tiên httpOnly cookie.
- **Password:** bcrypt/argon2, cost ≥ 10. Không MD5/SHA1.
- **Role:** RBAC theo claim `roles` hoặc `permissions` trong JWT.
- **Public route:** Whitelist rõ ràng, mặc định deny.
- **CORS:** Whitelist origin cụ thể. Không `*` khi có credential.

### Test Strategy

- **Unit:** Service / hook / util. Mock IO.
- **Integration:** Module NestJS + DB sandbox. Reset DB giữa test.
- **E2E:** Playwright cho flow user. Tách khỏi unit/integration.
- **Smoke:** Build + start + ping health endpoint.
- **CI gate:** Unit + integration chạy mỗi PR. E2E chạy nightly hoặc trước release.

### Workflow khi sửa full-stack

1. Đọc AGENTS.md + OPENCODE.md (rule backend/frontend/db ở trên).
2. Xác định layer cần sửa: FE / BE / DB / cả ba.
3. Sửa từ DB lên: migration → entity → DTO → service → controller → FE.
4. Chạy lint + typecheck + test của layer đó.
5. Chạy `/api-e2e-flow` cho happy path.
6. Commit riêng từng layer nếu có thể.

### Vietnamese Language Lock

- **Mặc định trả lời user bằng tiếng Việt.** Kế hoạch, giải thích, báo cáo đều bằng tiếng Việt.
- **Giữ tiếng Anh cho:** tên lệnh, slash command, tên agent, file/path, code, API, package name, error log, stacktrace.
- **Không tự chuyển sang tiếng Anh** khi user đang dùng tiếng Việt.
- **Code/comment giữ nguyên**, không dịch.
- **Báo cáo cuối task bằng tiếng Việt**: đã làm gì, file sửa, verify, rủi ro.

<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-end -->

# Auth + RBAC Review

Review auth flow, role-based access control, route protection, token handling.

## Cần check

### Authentication (authn)

- User xác thực bằng gì? Password / OAuth / SSO / magic link?
- Password hashing: bcrypt (cost ≥ 10) hoặc argon2id. KHÔNG MD5 / SHA1 / SHA256 thuần.
- Password policy: tối thiểu 8 ký tự, có chữ + số, hoặc dùng HaveIBeenPwned API.
- Rate limit login: 5 lần / 15 phút / IP. Lock account sau N lần sai.
- Account lockout: thông báo rõ, có cơ chế unlock (email / support).
- Session: stateless (JWT) hay stateful (server session).
- MFA: có hỗ trợ không? Áp dụng cho role admin bắt buộc.

### Token (JWT)

- Access token: 15-30 phút. Refresh: 7-30 ngày.
- Refresh rotation: dùng refresh mới → revoke refresh cũ.
- Algorithm: HS256 với secret mạnh, hoặc RS256 với key pair.
- KHÔNG `alg: none`. KHÔNG nhận alg từ header (algorithm confusion attack).
- Claim tối thiểu: `sub`, `iat`, `exp`, `roles` / `permissions`.
- Verify `exp`, `nbf`, `iss`, `aud`.
- Logout: blacklist access (nếu ngắn) hoặc revoke refresh.

### Storage (frontend)

- Ưu tiên httpOnly cookie + SameSite=Lax/Strict + Secure.
- Nếu dùng `localStorage`: chấp nhận rủi ro XSS. Đặt CSP chặt.
- KHÔNG lưu token vào `sessionStorage` rồi expect nó sống qua reload.
- Service worker: không cache token.

### Authorization (authz)

- Default deny. Mọi route mặc định cần auth trừ whitelist rõ.
- Whitelist public: `/api/health`, `/api/auth/login`, `/api/auth/register`, ...
- RBAC: role gắn trong JWT claim. Guard check ở backend, KHÔNG chỉ ở FE.
- Resource-level: check ownership (`post.author_id === user.id`) ở service.
- Phân quyền theo permission (`can:edit:post`) thay vì role cứng (`role=admin`) — dễ mở rộng.

### Route protection

- Backend: `@UseGuards(AuthGuard, RolesGuard)`. Thứ tự: auth trước, role sau.
- Frontend: `<ProtectedRoute>` wrap. Redirect về login khi 401.
- KHÔNG chỉ hide route ở FE. BE phải enforce.
- Static route: vẫn cần guard (không tin tưởng client).
- Server-rendered: render conditional sau khi check quyền.

### CORS

- Whitelist origin cụ thể: `https://app.example.com`. KHÔNG `*` khi có credential.
- Preflight `OPTIONS` phải trả đúng headers.
- Cookie cross-origin: `SameSite=None; Secure` + HTTPS.

### CSRF

- Cookie session: cần CSRF token (double submit, synchronizer, hoặc SameSite).
- Bearer token trong header: CSRF thấp (browser không tự gửi custom header từ form).
- SameSite=Lax/Strict: chặn hầu hết CSRF.

### Input validation

- Mọi input qua DTO + class-validator / Zod. KHÔNG trust client.
- Email: validate format + normalize (lowercase).
- Password: không log, không echo lại response.
- File upload: validate mime, size, scan virus nếu nhạy cảm.

### Logging & audit

- Log: login success, login fail, logout, password change, role change.
- KHÔNG log token, password, session id nguyên văn.
- Audit trail cho admin action: ai, lúc nào, làm gì.

### Headers

- `Strict-Transport-Security: max-age=31536000; includeSubDomains`.
- `X-Content-Type-Options: nosniff`.
- `X-Frame-Options: DENY` hoặc CSP `frame-ancestors 'none'`.
- `Content-Security-Policy` chặt, hạn chế `script-src` (no `unsafe-inline` nếu có thể).
- `Referrer-Policy: strict-origin-when-cross-origin`.

## Workflow review

1. Tìm mọi route handler: `rg "@Get|@Post|@Put|@Delete|@Patch"` (NestJS) hoặc `rg "router\.(get|post|put|delete)"` (Express).
2. Check guard: có `@UseGuards` không? Có whitelist public không?
3. Check service: có check ownership / role không?
4. Check response: có leak field nhạy cảm không (password hash, token)?
5. Check config: secret lấy từ env, không hardcode.
6. Check log: có log PII / secret không.

## Output

| Endpoint | Auth | Role guard | Resource check | Risk | Fix |
|----------|------|-----------|----------------|------|-----|

Severity: CRITICAL (no auth trên private) | HIGH | MEDIUM | LOW.

## Reference

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [OWASP CSRF Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)

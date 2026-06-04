# Secure Full-Stack

Quy tắc security áp dụng cho cả frontend + backend + DB.

## Layer defense

```
FE    →  BE    →  DB
 ^       ^       ^
 |       |       |
 CSP     AuthZ   FK
 CORS    Input   Encrypt at rest
 Token   Rate    Audit log
```

Không phụ thuộc 1 layer. Mỗi layer enforce + log.

## Secrets

- KHÔNG hardcode secret trong source. Dùng env var.
- KHÔNG commit `.env`. Dùng `.env.example` với placeholder.
- Secret trong frontend: không có. Tất cả secret ở backend.
- Build-time secret: truyền qua CI/CD env, không bake vào image.
- Rotation: lên lịch xoay secret định kỳ (90 ngày cho access key).
- Storage: HashiCorp Vault / AWS Secrets Manager / Doppler cho prod.

## Auth (xem skill `auth-rbac-review` chi tiết)

- Password hash: bcrypt cost ≥ 10 hoặc argon2id.
- JWT: access 15-30 phút, refresh 7-30 ngày với rotation.
- Token storage: httpOnly cookie ưu tiên `localStorage`.
- MFA cho admin.
- Rate limit login: 5 lần / 15 phút / IP.

## Input validation

- Mọi input qua DTO + `class-validator` / Zod.
- Validate ở BE (single source of truth), FE validate chỉ để UX.
- Email: format + normalize.
- Số: dùng `decimal` cho money, parse bằng `Number.parseInt` với radix.
- File upload: validate mime + size + magic number, scan virus nếu nhạy cảm.
- SQL: luôn parameterize. KHÔNG string concat.
- XSS: escape output. Dùng framework render (React, Vue auto-escape).
- Path traversal: dùng `path.resolve` + check prefix.

## CORS

- Whitelist origin cụ thể. KHÔNG `*` khi có credential.
- Preflight `OPTIONS` trả headers đúng.
- `Access-Control-Allow-Credentials: true` chỉ khi cần.

## Headers (OWASP Secure Headers)

- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`.
- `X-Content-Type-Options: nosniff`.
- `X-Frame-Options: DENY` hoặc CSP `frame-ancestors 'none'`.
- `Content-Security-Policy` chặt:
  - `default-src 'self'`.
  - `script-src 'self' 'nonce-...'` (no `unsafe-inline` nếu có thể).
  - `style-src 'self' 'unsafe-inline'` (CSS-in-JS cần).
  - `img-src 'self' data: https:`.
  - `connect-src 'self' https://api.example.com`.
  - `frame-ancestors 'none'`.
  - `base-uri 'self'`.
  - `form-action 'self'`.
- `Referrer-Policy: strict-origin-when-cross-origin`.
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`.
- Cookie: `Secure; HttpOnly; SameSite=Lax/Strict`.

## HTTPS

- Bắt buộc ở production. HSTS preload.
- Cert: Let's Encrypt / cloud provider.
- Redirect HTTP → HTTPS.

## Rate limiting

- Global: 100 req / phút / IP.
- Login: 5 lần / 15 phút / IP.
- Expensive endpoint (search, upload): 10 req / phút / user.
- Tool: `express-rate-limit` / `@nestjs/throttler` / `nginx limit_req`.

## Logging

- Log: auth event, admin action, payment, data export.
- KHÔNG log: token, password, session id, PII (email, phone, CCCD), credit card.
- Log structure: JSON, có `requestId`, `userId`, `timestamp`, `action`.
- Centralize: ELK / Loki / Datadog.
- Alert: nhiều 401/403 liên tiếp, nhiều 500, login từ IP lạ.

## Dependency

- Lockfile committed (`package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`).
- `npm audit` / `pnpm audit` mỗi PR.
- Renovate / Dependabot tự động PR minor + patch.
- Major version: review kỹ changelog, test integration.

## Uploads

- Validate mime (không tin tên file).
- Max size: set ở nginx + app.
- Scan virus (ClamAV) nếu cho phép user upload executable / document.
- Lưu ngoài webroot, serve qua signed URL.
- CDN với signed URL cho file lớn.

## Database

- Parameterize mọi query.
- Encrypt at rest (MySQL: tablespace encryption hoặc InnoDB keyring).
- Encrypt in transit: TLS cho connection string.
- Backup encrypted, test restore định kỳ.
- Soft delete + audit log cho data nhạy cảm.

## Build / deploy

- Build reproducible: lockfile + Docker multi-stage.
- Image scan: `trivy`, `snyk`, `grype`.
- Run as non-root user trong container.
- Read-only filesystem nếu có thể.
- Drop capabilities (chỉ giữ cần thiết).
- Network policy trong k8s (default deny).

## Checklist review

| Item | Layer | Check |
|------|-------|-------|
| HTTPS + HSTS | infra | `Strict-Transport-Security` |
| CSP | FE | Header chặt, no `unsafe-eval` |
| CORS | BE | Whitelist origin |
| Auth | BE | Bcrypt/argon2, MFA cho admin |
| Input validation | BE | DTO + validator, parameterize SQL |
| Rate limit | BE | Global + per-endpoint |
| Headers | BE | OWASP secure headers |
| Logging | BE | Có requestId, không PII |
| Backup | DB | Encrypted, test restore |
| Dependency | CI | Audit + scan image |
| Secret | build | Env var, không bake |

## Reference

- [OWASP Top 10](https://owasp.org/Top10/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [Mozilla Web Security](https://infosec.mozilla.org/guidelines/web_security)

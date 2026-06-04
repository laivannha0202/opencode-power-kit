# Security Review

Khi review security cho code, check theo thứ tự ưu tiên:

## 1. Secrets (cao nhất)
- Hardcoded token, password, api_key, private key, JWT secret.
- `.env`, `.env.local`, `.env.production` đã gitignore chưa.
- Log có in ra token / session / cookie không.

## 2. Auth & Authz
- Endpoint có check auth không (middleware/guard).
- Phân quyền theo role/permission đúng chưa.
- JWT/session validation đầy đủ chưa (exp, issuer, audience).

## 3. Input Validation
- SQLi: luôn parameter binding, KHÔNG string concat.
- XSS: escape HTML, sanitze rich text, CSP header.
- Command injection: tránh `exec(string)`, dùng API typed.
- Path traversal: normalize, whitelist root.
- SSRF: validate URL host, block internal IP.
- File upload: check MIME, size, virus scan nếu cần.

## 4. Crypto
- Hash: bcrypt/argon2 cho password, KHÔNG md5/sha1.
- Random: `crypto.randomBytes`, KHÔNG `Math.random` cho security.
- TLS: bắt buộc https, cert hợp lệ.

## 5. Dependency
- Lockfile có outdated major không.
- CVE check: `npm audit`, `cargo audit`, `pip-audit`.
- Bỏ package unmaintained.

## 6. Headers & Config
- CORS: whitelist domain, không `*` với credential.
- CSP, HSTS, X-Frame-Options, X-Content-Type-Options.
- Rate limit cho endpoint public.

## Output format
Bảng:
| Severity | Issue | File:Line | Fix |

Severity: CRITICAL (block merge) | HIGH | MEDIUM | LOW.

Không tự sửa — chỉ report. Đợi user quyết.

Review security cho code vừa sửa:
- Secrets: scan .env, hardcoded token, password, api_key, private key.
- Auth: endpoint có check auth? role/permission? token validation?
- Input validation: SQLi, XSS, command injection, path traversal, SSRF.
- Crypto: hash algorithm, salt, random source.
- Dependency: CVE known, outdated major.
- Logging: log có chứa PII / token / password?
- CORS / CSP / headers: có whitelist đúng?
- DB: prepared statement, parameter binding.

Output: bảng Severity | Issue | File:Line | Fix.
Không sửa code ở bước này — chỉ report. Sửa sau khi user chốt.

---
description: Scan secret pattern với gitleaks/trufflehog, in hướng dẫn cài nếu thiếu
agent: plan-lite
---

Quét project tìm secret / token / API key đã lộ:

1. Nếu có `gitleaks` trong `$PATH`:
   - `gitleaks detect --source . --no-banner -v`.
   - In số finding + danh sách file/line.
2. Nếu có `trufflehog` trong `$PATH`:
   - `trufflehog filesystem --directory=. --no-verification --fail`.
   - In verified vs unverified.
3. Nếu thiếu cả hai, dùng grep pattern cơ bản:
   - `sk-[A-Za-z0-9]{20,}` (OpenAI / Anthropic style).
   - `ghp_[A-Za-z0-9]{20,}` (GitHub PAT).
   - `AKIA[0-9A-Z]{16}` (AWS).
   - PEM private key blocks (`-----BEGIN ... -----END ... -----`).
   - `api_key=[A-Za-z0-9_\-]{8,}`, `password=[A-Za-z0-9_\-]{8,}`.
4. Nếu thiếu tool, in hướng dẫn cài:
   ```
   gitleaks:   brew install gitleaks  /  https://github.com/gitleaks/gitleaks/releases
   trufflehog: brew install trufflehog  /  go install github.com/trufflehog/trufflehog/v3/...@latest
   ```
5. KHÔNG sudo. KHÔNG tự cài. Chỉ detect + in hướng dẫn.
6. Scan thư mục: loại trừ `.git/`, `node_modules/`, `dist/`, `coverage/`, `CHANGELOG.md`, `README.md`, `docs/`.

Output:

| Tool | Findings | Verified | Files |
|------|----------|----------|-------|

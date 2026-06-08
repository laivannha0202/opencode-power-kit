---
description: Detect third-party tooling (rtk, repomix, ast-grep, knip, gitleaks, semgrep, spectral, Playwright, Biome)
---

# /tooling-doctor

Detect các công cụ third-party có sẵn trên hệ thống.

## Cách dùng

```
/tooling-doctor           # detect + báo cáo
/tooling-doctor --install # in hướng dẫn cài (không tự cài)
```

## Detect list

| Tool | Purpose | Check command | Install hint |
|------|---------|---------------|--------------|
| `rtk` | Giảm output token | `rtk --version` | `cargo install rtk` |
| `repomix` | Context pack | `repomix --version` | `npm i -g repomix` |
| `ast-grep` | Code search | `ast-grep --version` | `npm i -g @ast-grep/cli` |
| `rg` | Fast grep | `rg --version` | OS package manager |
| `fd` | Fast find | `fd --version` | OS package manager |
| `knip` | Dead code | `knip --version` | `npm i -g knip` |
| `gitleaks` | Secret scan | `gitleaks --version` | `brew` / `go install` |
| `trufflehog` | Secret scan | `trufflehog --version` | `pip` / `brew` |
| `semgrep` | SAST scan | `semgrep --version` | `pip install semgrep` |
| `spectral` | OpenAPI lint | `spectral --version` | `npm i -g @stoplight/spectral-cli` |
| `oasdiff` | OpenAPI diff | `oasdiff --version` | `go install` |
| `Playwright` | E2E testing | `npx playwright --version` | `npm i -D @playwright/test` |
| `Biome` | Lint/format | `biome --version` | `npm i -g @biomejs/biome` |
| `tokscale` | Token cost viz | `tokscale --version` | `cargo install tokscale` |

## Output
```
## Tooling Doctor Report
### Installed
- rtk v1.x ✓
- rg v13.x ✓
- Playwright v1.x ✓

### Missing (install if needed)
- knip → npm i -g knip
- semgrep → pip install semgrep
- gitleaks → brew install gitleaks

### Recommendation
Cài knip để phát hiện dead code. Cài semgrep cho SAST.
```

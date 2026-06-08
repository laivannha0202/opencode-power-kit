# Tính năng

## Power Mode v1.5.0

- **13 core agents** — mỗi agent chuyên sâu một lĩnh vực
- **34 commands** — phân loại theo power workflow, safety, build lifecycle, review, DB/API, QA/E2E, DevOps, quality/security, token/tooling
- **Safety guard** — `opk-command-guard.sh` cảnh báo/chặn lệnh shell nguy hiểm (`rm -rf`, `git reset --hard`, force push, `DROP TABLE`, ...)
- **Agent delegation** — `build-strong` tự động triệu hồi subagent chuyên biệt
- **`/power-build`** — đầu cuối: spec → architecture → build → QA → security → release
- **`/agent-router`** — định tuyến bằng ngôn ngữ tự nhiên tới đúng agent
- **`/tooling-doctor`** — phát hiện công cụ bên thứ ba (rtk, repomix, semgrep, gitleaks, ...)
- **100% backward compatible**

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**  
5 profile commands, 5 profile skills, 9 global full-stack commands, 8 global full-stack skills.

## Đa nền tảng

Linux, macOS (Git Bash/WSL), Windows (PowerShell).

## An toàn là ưu tiên

Không `rm -rf`, không `git reset --hard`, không force push, không lộ secrets, các thao tác DB nguy hiểm cần xác nhận, checkpoint trước thay đổi lớn.

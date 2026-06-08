# Danh sách Agent

## Core Power Agents

| Agent | Loại | Công dụng | Số file | Tools |
|-------|------|---------|-----------|-------|
| `architect-strong` | Architecture | Thiết kế hệ thống, ADR, quyết định cross-module | 1 | build-strong + explore (subagents) |
| `debug-strong` | Debug | Debug theo phương pháp khoa học với checkpoint | 1 | debug-lite (subagent), build-strong (fix) |
| `qa-strong` | QA/Testing | Phân tích coverage, regression testing, thiết kế test suite | 1 | review-lite, debug-lite (subagents) |
| `security-strong` | Security | SAST, secret scan, threat model, dependency audit | 1 | plan-lite, review-lite (subagents) |
| `db-strong` | Database | Thiết kế schema, migration safety, tối ưu query | 1 | plan-lite, review-lite, build-strong (subagents) |
| `api-strong` | API | OpenAPI contract, đồng bộ FE/BE, sinh type | 1 | build-strong, review-lite (subagents) |
| `ui-ux-strong` | UI/UX | Accessibility, responsive design, visual review | 1 | explore (subagent) |
| `devops-strong` | DevOps | Docker, CI/CD, deploy, infrastructure | 1 | plan-lite, build-strong (subagents) |
| `release-strong` | Release | Bump version, CHANGELOG, tag, publish | 1 | plan-lite, review-lite (subagents) |

## Lite Agents (tiết kiệm token)

| Agent | Loại | Công dụng |
|-------|------|---------|
| `plan-lite` | Planning | Lập kế hoạch tiết kiệm token cho tác vụ nhỏ |
| `review-lite` | Review | Review code/diff tiết kiệm token |
| `debug-lite` | Debug | Debug tiết kiệm token cho bug đơn giản |

## Autopilot Agent

| Agent | Loại | Công dụng | Cách hoạt động |
|-------|------|---------|-------------|
| `build-strong` | Fullstack | Full-stack autopilot: spec → plan → build slice → verify | Nhận goal/instructions, tạo spec, lên kế hoạch, build slice-by-slice, verify sau mỗi slice |

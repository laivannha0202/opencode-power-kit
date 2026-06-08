# Danh sách Agent

## Core Power Agents

| Agent | Type | Purpose | # of Files | Tools |
|-------|------|---------|-----------|-------|
| `architect-strong` | Architecture | System design, ADR, cross-module decisions | 1 | build-strong + explore (subagents) |
| `debug-strong` | Debug | Scientific method debugging with checkpoint | 1 | debug-lite (subagent), build-strong (fix) |
| `qa-strong` | QA/Testing | Coverage analysis, regression testing, test suite design | 1 | review-lite, debug-lite (subagents) |
| `security-strong` | Security | SAST, secret scan, threat model, dependency audit | 1 | plan-lite, review-lite (subagents) |
| `db-strong` | Database | Schema design, migration safety, query optimization | 1 | plan-lite, review-lite, build-strong (subagents) |
| `api-strong` | API | OpenAPI contract, FE/BE sync, type generation | 1 | build-strong, review-lite (subagents) |
| `ui-ux-strong` | UI/UX | Accessibility, responsive design, visual review | 1 | explore (subagent) |
| `devops-strong` | DevOps | Docker, CI/CD, deploy, infrastructure | 1 | plan-lite, build-strong (subagents) |
| `release-strong` | Release | Version bump, CHANGELOG, tag, publish | 1 | plan-lite, review-lite (subagents) |

## Lite Agents (tiết kiệm token)

| Agent | Type | Purpose |
|-------|------|---------|
| `plan-lite` | Planning | Lập kế hoạch tiết kiệm token cho tác vụ nhỏ |
| `review-lite` | Review | Review code/diff tiết kiệm token |
| `debug-lite` | Debug | Debug tiết kiệm token cho bug đơn giản |

## Autopilot Agent

| Agent | Type | Purpose | How it works |
|-------|------|---------|-------------|
| `build-strong` | Fullstack | Full-stack autopilot: spec → plan → build slice → verify | Nhận goal/instructions, tạo spec, lên kế hoạch, build slice-by-slice, verify sau mỗi slice |

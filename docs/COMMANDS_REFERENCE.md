# Danh sách Commands

## Power Workflow

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/agent-router` | `any.md` | Định tuyến tác vụ tới agent chuyên biệt phù hợp |
| `/power-build` | `power-build.md` | Build đầu cuối: spec → architecture → build → QA → security → release |
| `/tooling-doctor` | `tooling-doctor.md` | Phát hiện công cụ bên thứ ba có sẵn |

## An toàn

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/cleanup-safe` | `cleanup-safe.md` | Di chuyển artifact tạm vào `.opk-trash/` an toàn |
| `/checkpoint` | `checkpoint.md` | Chụp working tree trước thay đổi lớn |
| `/handoff-save` | `handoff-save.md` | Cập nhật `AI_HANDOFF.md` cho liên tục ngữ cảnh |

## Vòng đời Build

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/spec-lite` | `spec-lite.md` | Spec nhanh (goal, scope, AC, out-of-scope) |
| `/plan-work` | `plan-work.md` | Chia tác vụ thành ≤ 7 bước kèm file + tests |
| `/build-slice` | `build-slice.md` | Implement một slice, ≤ 2 files, ≤ 100 dòng diff |
| `/ci-fix` | `ci-fix.md` | Đọc lỗi CI/test/build và sửa an toàn |
| `/ship-check` | `ship-check.md` | Checklist trước commit/push |

## Review

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/review-diff` | `review-diff.md` | Review git diff |
| `/security-review` | `security-review.md` | Security review (secrets, auth, input validation) |
| `/api-contract-review` | `api-contract-review.md` | Kiểm tra khớp API contract FE/BE |
| `/migration-safe` | `migration-safe.md` | Kiểm tra migration an toàn trước khi chạy |
| `/release-check` | `release-check.md` | Kiểm tra VERSION/README/CHANGELOG/tag trước release |

## DB / API

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/db-readonly` | `db-readonly.md` | Kiểm tra DB chỉ đọc |
| `/migration-safe` | `migration-safe.md` | Kiểm tra an toàn migration |
| `/openapi-check` | `openapi-check.md` | Xác thực OpenAPI spec (spectral/oasdiff) |
| `/secret-scan` | `secret-scan.md` | Quét pattern secret (gitleaks/trufflehog) |
| `/sast-check` | `sast-check.md` | Phân tích tĩnh (semgrep) |

## QA / E2E

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/test-proof` | `test-proof.md` | Chạy/đề xuất tests làm bằng chứng |
| `/test-matrix` | `test-matrix.md` | Tạo test matrix (unit/integration/e2e/smoke) |
| `/e2e-flow` | `e2e-flow.md` | Lên kế hoạch và chạy E2E proof với Playwright |
| `/e2e-plan` | `e2e-plan.md` | Đề xuất luồng Playwright E2E |

## DevOps / Môi trường

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/env-doctor` | `env-doctor.md` | Kiểm tra an toàn env (không in secret values) |
| `/docker-dev-doctor` | `docker-dev-doctor.md` | Kiểm tra docker-compose dev setup |
| `/fullstack-scan` | `fullstack-scan.md` | Quét full-stack project (FE/BE/DB/scripts/env/docker) |

## Chất lượng / Bảo mật

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/js-quality-check` | `js-quality-check.md` | Phát hiện eslint/prettier/biome/knip/vitest/tsc |
| `/smart-scan` | `smart-scan.md` | Quét nhanh sức khỏe project |
| `/kit-audit` | `kit-audit.md` | Kiểm tra cấu trúc opencode-power-kit |
| `/repo-map` | `repo-map.md` | Tạo project map |
| `/bugfix-safe` | `bugfix-safe.md` | Quy trình sửa bug an toàn |

## Token / Công cụ

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/rtk-gain` | `rtk-gain.md` | Chạy `rtk gain` hoặc hướng dẫn cài đặt |
| `/token-pack` | `token-pack.md` | Đóng gói context qua Repomix |

## UI/UX Design (Taste Skill)

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/taste-polish` | `taste-polish.md` | UI polish & refinement |
| `/redesign-ui` | `redesign-ui.md` | Redesign existing UI |
| `/image-to-code` | `image-to-code.md` | Convert design image to code |
| `/brandkit` | `brandkit.md` | Brand kit generation |
| `/mobile-ui` | `mobile-ui.md` | Mobile UI optimization |
| `/landing-ui` | `landing-ui.md` | Landing page UI |
| `/ui-final-pass` | `ui-final-pass.md` | Final UI quality pass |

## ECC-lite (Engineering Code Commandments)

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/ecc-audit` | `ecc-audit.md` | Audit codebase against ECC principles (read-only) |
| `/quality-gate` | `quality-gate.md` | Quality gate: verify code meets ECC standards before merge |
| `/research-first` | `research-first.md` | Research-first approach: explore before implementing |
| `/verify-loop` | `verify-loop.md` | Verification loop: test-before-done, iterate until passing |
| `/backend-route-review` | `backend-route-review.md` | Backend HTTP/API route review: routing, auth, middleware, error handling |
| `/harness-audit` | `harness-audit.md` | Harness audit: verify constraints, edge cases, invariants |

## Hermes-lite (Meta-Cognitive Self-Improvement)

| Lệnh | File | Mục đích |
|---------|------|----------|
| `/hermes-reflect` | `hermes-reflect.md` | Structured reflection on recent work |
| `/hermes-skill` | `hermes-skill.md` | Propose skill improvements from work patterns |
| `/hermes-kanban` | `hermes-kanban.md` | Lightweight kanban board for agent tasks |
| `/hermes-memory` | `hermes-memory.md` | Memory policy review |
| `/hermes-budget` | `hermes-budget.md` | Context/budget pressure analysis |
| `/hermes-audit` | `hermes-audit.md` | Tool surface audit |
| `/hermes-learn` | `hermes-learn.md` | Capture learning from current work |
| `/hermes-research` | `hermes-research.md` | Research remote backend/dependency improvement |

## CLI Commands

| Lệnh | Mục đích |
|---------|----------|
| `opk one` / `opk go` | All-in-one: global + project + fullstack + verify |
| `opk help` | Hiển thị help đầy đủ |
| `opk version` | Hiển thị phiên bản |
| `opk doctor` | Chẩn đoán (read-only) |
| `opk verify` | Kiểm tra project sẵn sàng chưa |
| `opk global` | Cài đặt toàn cục (agents/commands/skills) |
| `opk install` | Cài vào project hiện tại |
| `opk fullstack` | Cài full-stack profile (Node/Nest/React/MySQL) |
| `opk path` | Hiển thị đường dẫn kit |
| `opk update` | Cập nhật kit từ git origin |

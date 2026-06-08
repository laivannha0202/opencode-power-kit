# OpenCode Power Kit

[![CI](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.6.0-blue.svg)](./VERSION)
[![BMAD Method](https://img.shields.io/badge/BMAD%20Method-v6.8.0-blue.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![No MCP](https://img.shields.io/badge/policy-no%20MCP-orange.svg)](#mô-hình-an-toàn)
[![Safe / No secrets](https://img.shields.io/badge/policy-safe%20%2F%20no--secrets-success.svg)](#mô-hình-an-toàn)
[![Cross-platform](https://img.shields.io/badge/cross--platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](#cài-nhanh)

> Bộ công cụ OpenCode full-stack có thể tái sử dụng: agents, commands, skills, quy trình an toàn, full-stack profile, công cụ release.

---

## Cài nhanh

### Linux / macOS / Git Bash / WSL

```bash
bash -c 'PROJECT="$PWD"; KIT="$HOME/opencode-power-kit"; if [ -d "$KIT/.git" ]; then git -C "$KIT" pull --ff-only; else git clone https://github.com/laivannha0202/opencode-power-kit.git "$KIT"; fi; bash "$KIT/bootstrap.sh" --all --project-dir "$PROJECT"; cd "$PROJECT"; bash "$KIT/verify.sh"; echo "Done. Run: opencode"'
```

Sau đó tải lại profile và kiểm tra:
```bash
source ~/.bashrc    # or source ~/.zshrc
opk one             # chạy lại all-in-one bất cứ lúc nào
opk doctor          # kiểm tra mọi thứ
opencode
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -Command "$Project=(Get-Location).Path; $KIT=Join-Path $HOME 'opencode-power-kit'; if (Test-Path (Join-Path $KIT '.git')) { & git -C $KIT pull --ff-only } else { & git clone https://github.com/laivannha0202/opencode-power-kit.git $KIT }; & (Join-Path $KIT 'bootstrap.ps1') -All -ProjectDir $Project -Yes; & (Join-Path $KIT 'verify.ps1'); Write-Host 'Done. Run: opencode'"
```

Mở cửa sổ **PowerShell mới**, sau đó:
```powershell
opk one
opk.cmd path
opencode
```

### Sau khi cài đặt

| Lệnh | Công dụng |
|---------|---------|
| `opk one` / `opk go` | All-in-one: global + project + fullstack + verify |
| `opk help` | Hiển thị help đầy đủ |
| `opk version` | Hiển thị phiên bản |
| `opk doctor` | Chẩn đoán (read-only) |
| `opk verify` | Kiểm tra project sẵn sàng |
| `opk global` | Cài đặt toàn cục (agents/commands/skills) |
| `opk install` | Cài vào project hiện tại |
| `opk fullstack` | Cài full-stack profile (Node/Nest/React/MySQL) |

---

## Bộ này gồm những gì

| Thành phần | Số lượng | Vị trí |
|-----------|-------|----------|
| Core agents | 13 | `opencode-global/agents/` |
| Slash commands | 34 | `opencode-global/commands/` |
| Skills | 20 | `opencode-global/skills/` |
| Scripts | 12 | `scripts/` |
| Full-stack profile | 1 | `profiles/node-nest-react-mysql/` |
| Safety scripts | 4 | `verify.sh`, `doctor.sh`, `cleanup-agent-artifacts.sh`, `opk-command-guard.sh` |
| Install/Bootstrap | 8+ | `bootstrap.*`, `setup.*`, `install*.*` |
| CLI wrappers | 3 | `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1` |

---

## Power Mode v1.5.0

- **13 core agents** — mỗi agent chuyên sâu một lĩnh vực (architecture, debug, QA, security, DB, API, UI/UX, DevOps, release, fullstack autopilot, 3 lite agents)
- **34 commands** — phân loại theo power workflow, safety, build lifecycle, review, DB/API, QA/E2E, DevOps, quality/security, token/tooling
- **`scripts/opk-command-guard.sh`** — lớp bảo vệ: cảnh báo/chặn lệnh shell nguy hiểm (`rm -rf`, `git reset --hard`, force push, `DROP TABLE`, ...)
- **`build-strong` Agent Delegation** — tự động triệu hồi subagent chuyên biệt dựa trên ngữ cảnh
- **`/power-build`** — quy trình đầu cuối: spec → architecture → implementation → QA → security → release
- **`/agent-router`** — định tuyến tác vụ bằng ngôn ngữ tự nhiên tới đúng agent
- **`/tooling-doctor`** — phát hiện công cụ bên thứ ba (rtk, repomix, semgrep, gitleaks, ...)
- **100% backward compatible** — mọi thứ từ phiên bản trước vẫn hoạt động không thay đổi

---

## Full Auto Permission Mode v1.6.0

OpenCode được cấu hình với `"permission": "allow"` — agent tự động
chạy tool, sửa file, tạo file, chạy bash/test/build mà **không hỏi
lại**. Phù hợp máy/project cá nhân, workflow nhanh hơn, ít prompt hơn.

### Cách hoạt động

- **`templates/opencode.json`** dùng `"permission": "allow"` thay vì
  permission object safe-mode.
- Agent không bị OpenCode permission prompt cho edit/bash/file ops.
- Safety rules được enforce bằng **instruction rules** (không phải
  permission prompt):
  - Không tự `git push` nếu user chưa yêu cầu.
  - Không tự `git reset --hard`, `git clean -fd`.
  - Không tự xóa file lớn/hàng loạt.
  - Không tự sửa `.env`/secrets/token.
  - Trước task lớn: `git status` + báo tóm tắt.
  - Sau task: `git diff --stat` + báo cáo tiếng Việt.

### Phù hợp cho

- **Dự án local tin cậy** — máy cá nhân, dev máy thật.
- **Người dùng có kinh nghiệm** — hiểu rủi ro và tự chịu trách nhiệm.

### Vẫn bị hạn chế (bởi agent rules, không phải permission prompt)

- Git ops nguy hiểm (`reset --hard`, `clean -fd`, force push)
- DB destructive ops (`DROP TABLE`, `TRUNCATE`)
- Truy cập secret/env
- Tất cả safety rules trong `templates/AGENTS.md`

---

## Danh sách Agent

### Core Power Agents

| Agent | Loại | Công dụng | Dùng khi |
|-------|------|---------|----------|
| `build-strong` | Fullstack | Full-stack autopilot: spec → plan → build slice → verify | Làm feature full-stack chính |
| `architect-strong` | Architecture | Thiết kế hệ thống, ADR, quyết định cross-module | Task > 5 files, thay đổi cross-module |
| `debug-strong` | Debug | Debug theo phương pháp khoa học với checkpoint | Bug phức tạp, root cause khó tìm |
| `qa-strong` | QA/Testing | Phân tích coverage, regression testing, thiết kế test suite | Trước khi ship, cần test suite chất lượng |
| `security-strong` | Security | SAST, secret scan, threat model, dependency audit | Trước release, code có auth/input |
| `db-strong` | Database | Thiết kế schema, migration safety, tối ưu query | Thay đổi schema, migrations |
| `api-strong` | API | OpenAPI contract, đồng bộ FE/BE, sinh type | Thay đổi endpoint, đồng bộ API contract |
| `ui-ux-strong` | UI/UX | Accessibility, responsive design, visual review | Review giao diện, sửa responsive |
| `devops-strong` | DevOps | Docker, CI/CD, deploy, infrastructure | Thiết lập/review infrastructure |
| `release-strong` | Release | Bump version, CHANGELOG, tag, publish | Trước khi cắt release |
| `plan-lite` | Planning | Lập kế hoạch tiết kiệm token | Tác vụ nhỏ cần plan nhanh |
| `review-lite` | Review | Review code/diff tiết kiệm token | Quick code review |
| `debug-lite` | Debug | Debug tiết kiệm token | Bug đơn giản |

**Quy trình khuyến nghị:**
```
/agent-router "add Google login feature"
# Hoặc thủ công: @architect-strong → @db-strong → @build-strong → @qa-strong → @security-strong → @release-strong
```

---

## Danh sách lệnh

### Power Workflow

| Lệnh | Công dụng |
|---------|---------|
| `/agent-router` | Định tuyến tác vụ tới agent chuyên biệt phù hợp |
| `/power-build` | Build đầu cuối: spec → architecture → build → QA → security → release |
| `/tooling-doctor` | Phát hiện công cụ bên thứ ba có sẵn |

### An toàn

| Lệnh | Công dụng |
|---------|---------|
| `/cleanup-safe` | Di chuyển artifact tạm vào `.opk-trash/` an toàn (mặc định dry-run) |
| `/checkpoint` | Chụp working tree trước thay đổi lớn |
| `/handoff-save` | Cập nhật `AI_HANDOFF.md` cho liên tục ngữ cảnh |

### Vòng đời Build

| Lệnh | Công dụng |
|---------|---------|
| `/spec-lite` | Spec nhanh (goal, scope, AC, out-of-scope) |
| `/plan-work` | Chia tác vụ thành ≤ 7 bước kèm file + tests |
| `/build-slice` | Implement một slice, ≤ 2 files, ≤ 100 dòng diff |
| `/ci-fix` | Đọc lỗi CI/test/build và sửa an toàn |
| `/ship-check` | Checklist trước commit/push |

### Review

| Lệnh | Công dụng |
|---------|---------|
| `/review-diff` | Review git diff |
| `/security-review` | Security review (secrets, auth, input validation) |
| `/api-contract-review` | Kiểm tra khớp API contract FE/BE |
| `/migration-safe` | Kiểm tra migration an toàn trước khi chạy |
| `/release-check` | Kiểm tra VERSION/README/CHANGELOG/tag trước release |

### DB / API

| Lệnh | Công dụng |
|---------|---------|
| `/db-readonly` | Kiểm tra DB chỉ đọc |
| `/migration-safe` | Kiểm tra an toàn migration |
| `/openapi-check` | Xác thực OpenAPI spec (spectral/oasdiff) |
| `/secret-scan` | Quét pattern secret (gitleaks/trufflehog) |
| `/sast-check` | Phân tích tĩnh (semgrep) |

### QA / E2E

| Lệnh | Công dụng |
|---------|---------|
| `/test-proof` | Chạy/đề xuất tests làm bằng chứng |
| `/test-matrix` | Tạo test matrix (unit/integration/e2e/smoke) |
| `/e2e-flow` | Lên kế hoạch và chạy E2E proof với Playwright |
| `/e2e-plan` | Đề xuất luồng Playwright E2E |

### DevOps / Môi trường

| Lệnh | Công dụng |
|---------|---------|
| `/env-doctor` | Kiểm tra an toàn env (không in secret values) |
| `/docker-dev-doctor` | Kiểm tra docker-compose dev setup |
| `/fullstack-scan` | Quét full-stack project (FE/BE/DB/scripts/env/docker) |

### Chất lượng / Bảo mật

| Lệnh | Công dụng |
|---------|---------|
| `/js-quality-check` | Phát hiện eslint/prettier/biome/knip/vitest/tsc |
| `/smart-scan` | Quét nhanh sức khỏe project |
| `/kit-audit` | Kiểm tra cấu trúc opencode-power-kit |
| `/repo-map` | Tạo project map |
| `/bugfix-safe` | Quy trình sửa bug an toàn |

### Token / Công cụ

| Lệnh | Công dụng |
|---------|---------|
| `/rtk-gain` | Chạy `rtk gain` hoặc hướng dẫn cài đặt |
| `/token-pack` | Đóng gói context qua Repomix |

---

## Skills Tổng quan

| Danh mục | Skills |
|----------|--------|
| Architecture / ADR | `adr-architecture-decision` |
| API Contract / OpenAPI | `api-contract`, `openapi-contract` |
| DB Migration | `database-migration-safe` |
| Docker / Environment | `docker-compose-safe`, `env-config-safe` |
| Frontend UI Review | `frontend-ui-review` |
| Full-stack Testing | `fullstack-test-strategy`, `test-strategy` |
| JS/TS Quality | `js-ts-project`, `js-ts-quality` |
| Security | `security-review`, `secure-fullstack` |
| Token / Repo Map | `rtk-token-optimizer`, `repo-map` |
| Safe Edit | `safe-edit` |
| Serena First | `serena-first` |
| Dependency | `dependency-maintenance` |
| Nest/React/MySQL | `nest-react-mysql` |

---

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**

```bash
# Linux / macOS / Git Bash / WSL
cd /path/to/your/project
opk one            # = opk go  = bootstrap.sh --all --project-dir "$(pwd)" --yes
# = [1/4] global + [2/4] project + [3/4] fullstack + [4/4] verify
```

```powershell
# Windows PowerShell
cd C:\path\to\your\project
opk one            # = opk go
```

> Bootstrap tự động: không sudo, không `curl|sh`, backup mọi file cũ, idempotent.

## Cài thủ công / Nâng cao

### Linux / macOS / Git Bash / WSL

```bash
git clone https://github.com/laivannha0202/opencode-power-kit.git ~/opencode-power-kit
bash ~/opencode-power-kit/setup.sh --global
source ~/.bashrc
opk help
opencode
```

### Windows PowerShell

```powershell
git clone https://github.com/laivannha0202/opencode-power-kit.git $HOME\opencode-power-kit
powershell -ExecutionPolicy Bypass -File "$HOME\opencode-power-kit\setup.ps1" -Global -Yes
# Mở PowerShell mới, sau đó:
opk.cmd path
opencode
```

### Sau cài global — dùng với bất kỳ project nào

```bash
cd /path/to/your/project
opk install
opk fullstack   # optional
opk verify
```

## Cấu trúc Project

```
~/opencode-power-kit/
├── README.md
├── setup.sh / setup.ps1          # interactive + flags
├── bin/opk, opk.cmd, opk.ps1     # CLI wrappers
├── install.sh / install.ps1       # per-project
├── bootstrap.sh / bootstrap.ps1   # one-command installer
├── install-global.sh / .ps1       # global install
├── verify.sh / verify.ps1         # verification
├── doctor.sh / doctor.ps1         # diagnostics
├── uninstall.sh / uninstall.ps1   # removal
├── update-bmad.sh / .ps1          # BMAD update
├── scripts/                       # install helpers
├── opencode-global/               # agents, commands, skills
├── templates/                     # AGENTS.md, OPENCODE.md, configs
└── docs/                          # workflow, prompts, safety
```

## Các lệnh

```bash
bash ~/opencode-power-kit/verify.sh
bash ~/opencode-power-kit/update-bmad.sh
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

## Full-stack Profile

Stack: **Node.js + NestJS + React/Vite + MySQL**

### Cài đặt

```bash
# Sau khi cài global, từ thư mục project:
opk fullstack
# Hoặc:
bash ~/opencode-power-kit/scripts/install-fullstack-profile.sh
```

Bao gồm:
- 5 profile-specific commands: `api-e2e-flow`, `docker-dev-doctor`, `env-doctor`, `fullstack-scan`, `seed-data-safe`
- 5 profile-specific skills: `nestjs-backend`, `react-vite-frontend`, `mysql-schema-safe`, `auth-rbac-review`, `fullstack-test-strategy`
- 9 global full-stack commands: `fullstack-scan`, `openapi-check`, `secret-scan`, `sast-check`, `e2e-plan`, `test-matrix`, `js-quality-check`, `env-doctor`, `docker-dev-doctor`
- 8 global full-stack skills: `openapi-contract`, `secure-fullstack`, `dependency-maintenance`, `fullstack-test-strategy`, `js-ts-quality`, `env-config-safe`, `docker-compose-safe`, `nest-react-mysql`

Phù hợp nhất cho project dùng: NestJS backend, React/Vite frontend, MySQL database, JWT + RBAC auth.

---

## Mô hình An toàn

| Quy tắc | Mô tả |
|------|-------------|
| Không `rm -rf` | Không bao giờ chạy xoá file phá hoại |
| Không `git reset --hard` | Không bao giờ phá working tree |
| Không `git clean -fd` | Không bao giờ force-clean untracked files |
| Không force push | Không bao giờ viết lại remote history |
| Không .env/secrets | Không bao giờ đọc hoặc lộ secret values |
| DB destructive ops cần xác nhận | `DROP TABLE`, `TRUNCATE`, `DELETE` thiếu WHERE bị chặn |
| Cleanup chuyển vào `.opk-trash/` | Không bao giờ xoá, luôn move kèm timestamp |
| Checkpoint tạo patch | `git diff` lưu thành `.patch` trước thay đổi lớn |
| Không MCP bundled | Tất cả lệnh đều local, không ship MCP servers |
| Không auto-update khi shell start | Mọi cập nhật đều là lệnh user chủ động |
| Backup trước khi ghi đè | File hiện tại được backup trước khi sửa |

---

## Vietnamese Language Lock

Tất cả tương tác của agent tuân theo chính sách ưu tiên tiếng Việt:

- **Tương tác ưu tiên tiếng Việt:** Agent mặc định trả lời bằng tiếng Việt. Kế hoạch, giải thích, báo cáo và kết luận đều dùng tiếng Việt.
- **Giữ nguyên thuật ngữ kỹ thuật tiếng Anh:** Code, command, slash command, tên agent, file/path, API, package name, error log, stacktrace và keyword kỹ thuật bắt buộc được giữ nguyên.
- **Không tự chuyển sang tiếng Anh:** Khi user viết tiếng Việt, agent không tự chuyển toàn bộ câu trả lời sang tiếng Anh.
- **Không thêm dependency:** Đây chỉ là thay đổi markdown/config, không thêm package hoặc repo ngoài.
- **User có thể override:** Nếu user yêu cầu trả lời bằng tiếng Anh rõ ràng thì agent mới dùng tiếng Anh.

Xem `templates/AGENTS.md` → **Vietnamese Language Lock** để biết đầy đủ rule.

---

## Xử lý sự cố

- **GitHub Actions bị lỗi?** Kiểm tra billing GitHub của bạn còn hoạt động không. Runner có thể fail do vấn đề billing/policy không liên quan đến code.
- **Verify local pass nhưng Actions fail?** Kiểm tra billing status, chạy lại jobs. Nếu vẫn lỗi, hãy tạo issue.
- **Cần giúp đỡ?** Chạy `opk doctor` để chẩn đoán, hoặc xem [docs/](./docs/) để biết thêm chi tiết.

---

## Giấy phép

MIT

# OpenCode Power Kit

[![CI](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/laivannha0202/opencode-power-kit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.9.0-blue.svg)](./VERSION)
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
| `opk up` / `opk update` / `opk upgrade` | Update kit + project (One Command Update) |
| `opk clean` | Cleanup agent artifacts an toàn (mặc định dry-run) |
| `opk up --clean` | Update + cleanup apply trong một lệnh |

---

## Update bằng một lệnh

Từ v1.6.5, OpenCode Power Kit hỗ trợ **One Command Update**:

```bash
# Linux / macOS / Git Bash / WSL
opk up

# Hoặc alias
opk update
opk upgrade

# Update + cleanup artifact apply luon
opk up --clean
```

```powershell
# Windows PowerShell
opk up
```

### `opk up` làm gì?

1. **Kiểm tra working tree** — Nếu dirty, báo danh sách file dirty, yêu cầu commit
   hoặc dùng `opk clean`. Không tự stash/reset.
2. **`git pull --ff-only`** trong thư mục kit (an toàn, không rebase/force).
3. **`install-global.sh --yes`** (Linux/macOS) hoặc **`install-global.ps1 -Yes`**
   (Windows) để cập nhật agents/commands/skills.
4. **Project update** — Nếu pwd là project an toàn (không phải root/system):
   - `opk install --yes` (cập nhật project config)
   - `opk fullstack --yes` (cập nhật full-stack profile)
   - `opk verify` (kiểm tra sau update)
5. **Cleanup** (với `--clean`): gọi `cleanup-agent-artifacts.sh --apply`.

### `opk clean`

Dọn dẹp agent artifacts an toàn:

```bash
opk clean          # dry-run: chỉ liệt kê
opk clean --apply  # apply: move vào .opk-trash/<timestamp>/
```

- **Mặc định dry-run** — Không đụng file trừ khi có `--apply`.
- **Move vào `.opk-trash/`** — Không xóa, không `rm -rf`, không `git clean -fd`.
- **Chỉ đụng untracked files** — Tracked files không bao giờ bị động.
- **Bảo vệ** `src/`, `app/`, `backend/`, `frontend/`, `docs/`, `.git/`, ...
- Có thể recover: `mv .opk-trash/<timestamp>/* ./`.

---

## Bộ này gồm những gì

| Thành phần | Số lượng | Vị trí |
|-----------|-------|----------|
| Core power agents | 14 | `opencode-global/agents/` |
| Total agent files | 49 | `opencode-global/agents/` (14 core + 33 GSD-style + 1 ECC-lite + 1 Hermes-lite) |
| Slash commands | 57 | `opencode-global/commands/` |
| Skills | 20 | `opencode-global/skills/` |
| Helper scripts | 18 | `scripts/` |
| Root-level scripts | 15 | `*.sh` + `*.ps1` (install, bootstrap, verify, doctor, ...) |
| Full-stack profile | 1 | `profiles/node-nest-react-mysql/` |
| Safety scripts | 4 | `verify.sh`, `doctor.sh`, `cleanup-agent-artifacts.sh`, `opk-command-guard.sh` |
| Install/Bootstrap | 8+ | `bootstrap.*`, `setup.*`, `install*.*` |
| CLI wrappers | 3 | `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1` |

---

## Credits / Upstream Projects

opencode-power-kit là bộ **cấu hình, đóng gói workflow, và quy chuẩn hóa**
cho OpenCode. Nó **không phải** fork hay reimplementation của các upstream
projects. Bảng dưới đây ghi rõ từng nguồn, vai trò, và kiểu tích hợp để
người dùng hiểu rõ ranh giới.

### Integration Modes

| Mode | Nghĩa | Auto-update? | Vendor source? | Ví dụ |
|------|-------|:---:|:---:|-------|
| **Target platform** | Nền tảng mà kit cấu hình workflow | No | No | OpenCode |
| **Plugin reference** | Plugin được load runtime từ GitHub/npm | Via OpenCode | No | Superpowers |
| **Install-time dependency** | Cài vào project user qua official installer | Via npx | No | BMAD Method |
| **Auto-enabled dependency** | Cài tự động khi kit install, vẫn dùng official installer | Via opk update-* | No | Taste Skill |
| **Config-only reference** | Kit chỉ ship template config trỏ đến upstream | No | No | Biome config |
| **Opt-in wrapper** | Chỉ gọi installer chính thức khi user yêu cầu | No | No | GSD Core |
| **Detect-only** | Chỉ phát hiện tool đã cài sẵn trên PATH | No | No | rg, fd, semgrep, gitleaks |
| **Recommended ecosystem** | Stack mục tiêu / tài liệu hướng dẫn | No | No | NestJS, React, MySQL |

### Upstream Table

| Upstream / Tool | Author / Org | Vai trò trong kit | Integration | Kit ships |
|----------------|-------------|-------------------|:-----------:|:---------:|
| OpenCode | OpenCode / SST | Nền tảng AI coding agent — kit cấu hình workflow cho nó | Target platform | `templates/opencode.json`, `templates/AGENTS.md` |
| Superpowers | obra | Agent skill library — plugin load runtime | Plugin reference | JSON reference in `opencode.json` |
| BMAD Method | bmad-code-org | Workflow modules, agents, slash commands | Install-time dependency | `install.sh` / `update-bmad.sh` gọi `npx bmad-method` |
| GSD Core | open-gsd | Optional companion workflow engine | Opt-in wrapper | `scripts/install-gsd-core.sh` |
| Supermemory | supermemory.ai | Memory/knowledge layer — store, retrieve, and search agent conversations, notes, and context | Opt-in wrapper | `scripts/install-supermemory.sh`, `scripts/install-supermemory.ps1` |
| MarkItDown | Microsoft | Document-to-Markdown conversion (PDF/DOCX/PPTX/XLSX/HTML) | Opt-in wrapper | `scripts/install-markitdown.sh`, `scripts/install-markitdown.ps1` |
| Taste Skill | Leonxlnx | AI-augmented UI/UX design — image-to-code, redesign, polish, brand kit | Auto-enabled dependency | `scripts/install-taste-skill.sh`, `scripts/install-taste-skill.ps1` |
| Hermes Agent | NousResearch | Meta-cognitive self-improvement framework — learning loop, skill improvement, memory policy review, context/budget pressure, lightweight kanban, tool surface audit, remote backend review | Inspiration (OPK-native) | `opencode-global/agents/hermes-lite-strong.md`, 8 commands, 3 scripts |
| rtk | rtk-ai | Token-saving shell wrapper | Detect-only | `/tooling-doctor` phát hiện |
| repomix | yamadashy | Context pack generator | Detect-only | `/tooling-doctor` + `/token-pack` |
| ast-grep | ast-grep | Structural code search | Detect-only | `/tooling-doctor` |
| ripgrep (rg) | BurntSushi | Fast regex search | Detect-only | `/tooling-doctor` |
| fd | sharkdp | Fast file finder | Detect-only | `/tooling-doctor` |
| knip | webpro-nl | Dead code/dependency detection | Detect-only | `/tooling-doctor`, `/js-quality-check` |
| gitleaks | gitleaks | Secret scanning | Detect-only | `/tooling-doctor`, `/secret-scan` |
| trufflehog | trufflesecurity | Secret scanning | Detect-only | `/tooling-doctor`, `/secret-scan` |
| semgrep | semgrep | SAST / static analysis | Detect-only | `/tooling-doctor`, `/sast-check` |
| spectral | stoplightio | OpenAPI lint | Detect-only | `/tooling-doctor`, `/openapi-check` |
| oasdiff | tufin | OpenAPI diff / breaking change detection | Detect-only | `/tooling-doctor`, `/openapi-check` |
| Playwright | Microsoft | E2E browser testing | Detect + CLI call | `/tooling-doctor`, `/e2e-flow` |
| Biome | biomejs | JS/TS lint + format | Config reference + detect | `templates/biome.json.example`, `/tooling-doctor` |
| tokscale | — | Token cost visualization | Detect-only | `/tooling-doctor` |

> Xem chi tiết từng mục tại [`THIRD_PARTY.md`](./THIRD_PARTY.md) — bao gồm
> update path, license notes, và chính sách tích hợp.

---

## Power Mode v1.5.0

- **14 core power agents** + **33 GSD-style agents** + **1 ECC-lite** + **1 Hermes-lite** = **49 total agent files** — mỗi agent chuyên sâu một lĩnh vực
- **57 commands** — phân loại theo power workflow, safety, build lifecycle, review, DB/API, QA/E2E, DevOps, quality/security, token/tooling
- **`scripts/opk-command-guard.sh`** — lớp bảo vệ: cảnh báo/chặn lệnh shell nguy hiểm (`rm -rf`, `git reset --hard`, force push, `DROP TABLE`, ...)
- **`build-strong` Agent Delegation** — tự động triệu hồi subagent chuyên biệt dựa trên ngữ cảnh
- **`/power-build`** — quy trình đầu cuối: spec → architecture → implementation → QA → security → release
- **`/agent-router`** — định tuyến tác vụ bằng ngôn ngữ tự nhiên tới đúng agent
- **`/tooling-doctor`** — phát hiện công cụ bên thứ ba (rtk, repomix, semgrep, gitleaks, ...)
- **100% backward compatible** — mọi thứ từ phiên bản trước vẫn hoạt động không thay đổi

---

## Power Mode vs Safe Mode Selection v1.6.4

Cho phép chuyển giữa **Power Mode** (agent tự động chạy) và **Safe Mode** (agent hỏi trước khi ghi file/bash).

### Cách dùng

```bash
# Xem mode hiện tại
opk mode show

# Chuyển sang Power Mode (permission: allow — mặc định)
opk mode power

# Chuyển sang Safe Mode (permission object — read/glob/grep/skill=allow, write/edit/bash/task=ask)
opk mode safe
```

### File config

| File | Mode | Mục đích |
|------|------|----------|
| `templates/opencode.json` | Power (`permission: allow`) | Backward compatible — mặc định |
| `templates/opencode.power.json` | Power | Dùng cho `opk mode power` |
| `templates/opencode.safe.json` | Safe (permission object) | Dùng cho `opk mode safe` |

### Safety Plugin Guard

Guard intercepts tool call để chặn:
- **Read file nhạy cảm:** `.env`, `*secret*`, `*private*`, `*key*.*`, `token*`, `*credential*`
- **Command nguy hiểm:** `rm -rf`, `git reset --hard`, `git clean -fd`, force push, SQL `DROP TABLE`/`TRUNCATE`/`DELETE` không WHERE

```bash
# Cài đặt safety plugin guard
opk safety-plugin install

# Kiểm tra trạng thái
opk safety-plugin status
```

Tham khảo: `templates/plugins/opk-safety-guard.js`

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

## Quality Scorecard

| Tiêu chí | Điểm | Vì sao đạt |
|----------|:----:|-----------|
| **Dễ cài** | 10/10 | One-command (`bash -c` / PowerShell) cho Linux/macOS/WSL/Git Bash + Windows. `opk one/go`, `opk doctor`, `opk verify` đều sẵn. |
| **Mạnh full-stack** | 10/10 | Profile Node/NestJS/React/Vite/MySQL. 14 core agents + 33 GSD-style + 1 ECC-lite. 49 commands. 20 skills. 15 root scripts. |
| **Workflow agent** | 10/10 | Agent router (`/agent-router`), `build-strong` fullstack autopilot, `power-build` end-to-end, delegation tới 9+ subagent chuyên biệt. |
| **Safety** | 10/10 cho trusted-local; 8/10 cho power mode mặc định | Guard rules: không `rm -rf`, không `git reset --hard`, không force push, không sửa `.env`/secrets, checkpoint trước thay đổi lớn, `/cleanup-safe` move an toàn, backup trước ghi đè. Tuy nhiên `permission: allow` có nghĩa agent không bị permission prompt — safety dựa vào instruction rules, không phải sandbox tuyệt đối. Khuyến nghị: dùng power mode cho máy/project cá nhân tin cậy. |
| **Tài liệu** | 10/10 | README, `THIRD_PARTY.md`, `CHANGELOG.md`, `docs/`, credits rõ ràng, update path cho từng nhóm upstream. |
| **Third-party packaging** | 10/10 | Phân loại rõ: target platform, plugin reference, install-time dependency, config-only, opt-in wrapper, detect-only, recommended ecosystem. Attribution đầy đủ. |

> **Safety note:** `permission: allow` là "power mode" — agent tự động chạy
> tool/sửa file mà không hỏi lại. Safety được enforce bằng instruction rules
> trong `templates/AGENTS.md`, không phải OpenCode permission prompt. Phù
> hợp cho máy/project cá nhân. Nếu cần safety tuyệt đối, hãy chuyển
> `opencode.json` sang permission object safe-mode (hỏi trước mỗi hành
> động nguy hiểm).

---

## How to Update Upstreams

### Install-time dependencies (BMAD Method)
```bash
bash ~/opencode-power-kit/update-bmad.sh
# Hoặc:
opk update-bmad
```
Cài lại BMAD Method từ npm với version pin hiện tại. Log đầy đủ vào
`.opencode-power-bmad-install.log`.

### Opt-in tools (GSD Core)
```bash
opk gsd              # Cài lần đầu
opk update-gsd       # Cập nhật
opk update-all --with-gsd  # Cập nhật kit + GSD
```

### Plugin references (Superpowers)
Superpowers được OpenCode tự động load từ GitHub qua plugin directive
trong `opencode.json`. Để cập nhật Superpowers, hãy cập nhật OpenCode
hoặc theo dõi upstream docs. Kit không quản lý Superpowers updates.

### Detect-only tools
Kit không tự cài hay cập nhật detect-only tools. User tự cài bằng
package manager riêng:
```bash
# Ví dụ:
cargo install ripgrep fd ast-grep
npm i -g knip
brew install gitleaks trufflehog semgrep
```
`/tooling-doctor` chỉ phát hiện tool nào đã có và gợi ý lệnh cài nếu thiếu.

### Kit itself
```bash
cd ~/opencode-power-kit && git pull --ff-only
```
Mỗi release mới có thể cập nhật version pin BMAD, templates, và bundled
configs. Xem `CHANGELOG.md` để biết chi tiết.

---

## MarkItDown Document Tools v1.6.6

opencode-power-kit ships **optional** integration with [Microsoft MarkItDown](https://github.com/microsoft/markitdown)
— a Python tool that converts PDF, DOCX, PPTX, XLSX, HTML, CSV, JSON, XML, and ZIP
archives to Markdown.

### Integration model: Opt-in wrapper

- Kit **never installs** MarkItDown automatically.
- Kit **never vendors** any MarkItDown source code.
- Kit **never runs** `pip install` during `opk up` or bootstrap.
- User must explicitly run `opk markitdown install` to install the official PyPI package.

### Usage

```bash
# Check status
opk markitdown status

# Install MarkItDown (requires Python 3 + pipx or pip)
opk markitdown install

# Convert a document to Markdown
opk md-convert input.pdf output.md

# Overwrite existing output
opk md-convert input.docx output.md --force

# Alias
opk doc-to-md input.html output.md
```

### Supported formats

| Format | Status |
|--------|--------|
| PDF | ✅ |
| DOCX | ✅ |
| PPTX | ✅ |
| XLSX | ✅ |
| HTML | ✅ |
| CSV | ✅ |
| JSON | ✅ |
| XML | ✅ |
| ZIP (archive) | ✅ |

### Agent command

The `doc-to-md` command in `opencode-global/commands/doc-to-md.md` guides
agents to use the `opk` wrapper — never to install packages directly.

### Files

| File | Role |
|------|------|
| `scripts/install-markitdown.sh` | Linux/macOS installer |
| `scripts/install-markitdown.ps1` | Windows installer |
| `opencode-global/commands/doc-to-md.md` | Agent command documentation |
| `bin/opk` / `bin/opk.ps1` | CLI subcommands: `markitdown`, `md-convert`, `doc-to-md` |

See [`THIRD_PARTY.md`](./THIRD_PARTY.md) for license and update path.

---

## Supermemory Memory API v1.6.7

opencode-power-kit ships **optional** integration with [Supermemory](https://github.com/supermemory/supermemory)
— a memory/knowledge layer for AI agents that provides persistent storage, retrieval, and
semantic search of conversations, notes, and project context.

### Integration model: Opt-in wrapper

- Kit **never installs** Supermemory automatically.
- Kit **never vendors** any Supermemory source code.
- Kit **never runs** `npm install` during `opk up` or bootstrap.
- User must explicitly run `opk supermemory install` to install the official
  [`@supermemory/ai`](https://www.npmjs.com/package/@supermemory/ai) package.

### Usage

```bash
# Check status
opk supermemory status

# Install Supermemory (requires Node.js 18+)
opk supermemory install

# Initialize — set up memory store and API key
opk supermemory init
```

### Agent command

The `supermemory-init` command in `opencode-global/commands/supermemory-init.md`
guides agents to use the `opk` wrapper — never to install packages directly.

### Files

| File | Role |
|------|------|
| `scripts/install-supermemory.sh` | Linux/macOS installer |
| `scripts/install-supermemory.ps1` | Windows installer |
| `opencode-global/commands/supermemory-init.md` | Agent command documentation |
| `bin/opk` / `bin/opk.ps1` | CLI subcommands: `supermemory` |

See [`THIRD_PARTY.md`](./THIRD_PARTY.md) for license and update path.

---

## Taste Skill — AI-Augmented UI/UX Design v1.7.0

opencode-power-kit ships **integrated** support for [Taste Skill](https://github.com/Leonxlnx/taste-skill)
— an AI-augmented UI/UX design tool for image-to-code conversion, UI redesign,
visual polish, brand kit generation, landing page design, and mobile UI optimization.

### Integration model: Auto-enabled (graceful degradation)

Unlike opt-in tools, Taste Skill is **automatically enabled** during kit setup:

| Trigger | Installs? | Skip behavior |
|---------|:---------:|:-------------:|
| `opk global` / `opk one` / `opk go` | ✅ Yes | Warn if node/npx missing, no failure |
| `install-global.sh` / `install-global.ps1` | ✅ Yes | Warn if node/npx missing, no failure |
| `bootstrap.sh --all` / `setup.sh --global` | ✅ Yes | Warn if node/npx missing, no failure |
| `opk up` (update) | ❌ No | N/A |
| Shell startup | ❌ No | N/A |

Set `OPK_SKIP_TASTE=1` to completely bypass auto-install.

### Safety guarantees

- **No sudo** — prefers `npx`, never uses `sudo npm`.
- **No curl|sh** — installer is in-kit bash/PowerShell.
- **No .env/secrets** — Taste Skill reads no sensitive files.
- **No core failure** — missing deps produce a warning only.
- **Fail soft** — if `npx` fails, install continues without error.

### Usage

```bash
# Check status
opk taste status
# or
opk taste-status

# Install manually
opk taste install

# Remove
opk taste off
# or
opk taste-off

# Update
opk update-taste
```

### Slash commands

| Slash command | Description |
|:-------------:|-------------|
| `/taste-polish` | UI polish & refinement on existing components |
| `/redesign-ui` | Redesign existing UI with taste-augmented suggestions |
| `/image-to-code` | Convert a design image/mockup to working code |
| `/brandkit` | Generate a cohesive brand kit (colors, fonts, tokens) |
| `/mobile-ui` | Mobile-responsive UI optimization |
| `/landing-ui` | Landing page structure and visual design |
| `/ui-final-pass` | Final quality pass before shipping UI changes |

### Agent routing

- `opencode-global/agents/taste-ui-strong.md` — dedicated subagent for UI/UX design
- `opencode-global/agents/build-strong.md` — agent delegation table includes taste-ui-strong
- `opencode-global/commands/agent-router.md` — routes UI design tasks to taste-ui-strong

### Files

| File | Role |
|------|------|
| `scripts/install-taste-skill.sh` | Linux/macOS installer |
| `scripts/install-taste-skill.ps1` | Windows installer |
| `scripts/check-taste-skill.sh` | Read-only detection (Linux/macOS) |
| `scripts/check-taste-skill.ps1` | Read-only detection (Windows) |
| `opencode-global/agents/taste-ui-strong.md` | Taste UI/UX agent definition |
| `opencode-global/skills/taste-polish/` | Slash command skills (7 commands) |
| `bin/opk` / `bin/opk.ps1` | CLI subcommands: `taste`, `taste-status`, `taste-off`, `update-taste` |

See [`THIRD_PARTY.md`](./THIRD_PARTY.md) for license and update path.

---

## ECC-lite — Engineering Code Commandments v1.8.0

opencode-power-kit ships **optional, lightweight** integration with
[ECC (Engineering Code Commandments)](https://github.com/affaan-m/ECC) by
affaan.m — an engineering discipline framework enforcing coding standards,
security practices, and engineering rigor.

### Integration model: Opt-in (not auto-enabled)

| Trigger | Installs? | Skip behavior |
|---------|:---------:|:-------------:|
| `opk global` / `opk one` / `opk go` | ❌ No | N/A |
| `install-global.sh` / `install-global.ps1` | ❌ No | N/A |
| `bootstrap.sh --all` / `setup.sh --global` | ❌ No | N/A |
| `opk up` (update) | ❌ No | N/A |
| `opk ecc lite` | ✅ Yes | Explicit user command only |

### What is ECC-lite?

ECC-lite is NOT full ECC. It is a **lightweight, OPK-native** subset:

- **6 core principles** embedded in `ecc-lite-strong.md` agent
- **6 slash commands** for key workflows
- **3 helper scripts** for audit, install, status
- **No full ECC install** — no 260+ skills, no 80+ commands, no hooks,
  no MCP, no memory, no auto-enable

### Usage

```bash
# Check status
opk ecc status

# Install ECC-lite (agent + 6 commands)
opk ecc lite

# Audit codebase against ECC principles (read-only)
opk ecc audit

# Remove ECC-lite
opk ecc off

# Update
opk update-ecc

# Short aliases
opk ec status
opk e lite
```

### Slash commands (after install)

| Slash command | Purpose |
|:-------------:|---------|
| `/ecc-audit` | Audit codebase against ECC principles (read-only) |
| `/quality-gate` | Quality gate: verify code meets ECC standards before merge |
| `/research-first` | Research-first approach: explore before implementing |
| `/verify-loop` | Verification loop: test-before-done, iterate until passing |
| `/model-route-review` | Model-routing review: verify AI model choice for task |
| `/harness-audit` | Harness audit: verify constraints, edge cases, invariants |

### ECC-lite Principles

1. **Research First** — Explore before implementing.
2. **Quality Gate** — Verify code meets standards before merging.
3. **Verification Loop** — Test-before-done. Iterate until passing.
4. **Assumption Checking** — Surface and verify assumptions.
5. **Test-Before-Done** — Tests alongside implementation.
6. **Security & Reliability Review** — Audit before shipping.

### Safety guarantees

- **No auto-enable** — never installed during `opk global`, bootstrap, setup.
- **No vendor source** — ECC source never copied into OPK repo.
- **No hooks** — no git hooks, OpenCode hooks, or commit hooks.
- **No MCP** — no MCP servers or configs.
- **No env/secrets** — ECC-lite never reads sensitive files.
- **No network in status check** — `check-ecc-lite.sh` only checks local files.
- **No sudo** — all operations user-scoped.
- **Read-only audit** — `audit-ecc.sh` clones to `.tmp/`, audits, then cleans up.

### Files

| File | Role |
|------|------|
| `scripts/audit-ecc.sh` | Linux/macOS audit script |
| `scripts/install-ecc-lite.sh` | Linux/macOS installer |
| `scripts/check-ecc-lite.sh` | Linux/macOS status check |
| `opencode-global/agents/ecc-lite-strong.md` | ECC-lite agent definition |
| `opencode-global/commands/ecc-audit.md` | ECC audit command |
| `opencode-global/commands/quality-gate.md` | Quality gate command |
| `opencode-global/commands/research-first.md` | Research-first command |
| `opencode-global/commands/verify-loop.md` | Verification loop command |
| `opencode-global/commands/model-route-review.md` | Model routing review command |
| `opencode-global/commands/harness-audit.md` | Harness audit command |
| `bin/opk` / `bin/opk.ps1` | CLI subcommands: `ec`, `e`, `ecc`, `update-ecc` |

See [`THIRD_PARTY.md`](./THIRD_PARTY.md) and [`docs/ECC_INTEGRATION.md`](./docs/ECC_INTEGRATION.md)
for license, update path, and architecture details.

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

# OpenCode Power Kit

[![CI](https://github.com/nguoikhongten02022005-cell/opencode-power-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/nguoikhongten02022005-cell/opencode-power-kit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.3.4-blue.svg)](./VERSION)
[![BMAD](https://img.shields.io/badge/BMAD%20Method-v6.8.0-blue.svg)](#cấu-hình-bmad)
[![No MCP](https://img.shields.io/badge/policy-no%20MCP-orange.svg)](#ghi-chu-quan-trong)
[![Safe / No secrets](https://img.shields.io/badge/policy-safe%20%2F%20no--secrets-success.svg)](#an-toan)
[![Cross-platform](https://img.shields.io/badge/cross--platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](#cài-1-lệnh)

Toolkit dùng lại cho mọi project OpenCode — cài Superpowers + BMAD Method chỉ với 1 lệnh, hỗ trợ **Linux / macOS / Windows PowerShell** (Git Bash / WSL / native).

## Có gì mới trong v1.4.0

- **`build-strong` → fullstack-autopilot** — agent `build-strong` được nâng
  cấp thành fullstack-autopilot mạnh mẽ hơn nhưng vẫn an toàn. Tự động xử
  lý task full-stack theo flow chuẩn:
  1. `git status` → detect stack/backend/frontend/database → đọc package scripts
  2. Checkpoint trước sửa lớn (`/checkpoint`)
  3. Spec ngắn + acceptance criteria + API contract
  4. Plan-work chia vertical slice nhỏ
  5. Build từng slice — đảm bảo FE/BE/API/DB contract khớp
  6. Chạy lint/typecheck/test/build; nếu không có test → manual proof bảng
  7. Cleanup file tạm (`/cleanup-safe`)
  8. Handoff nếu task lớn (`/handoff-save`)
  9. Báo cáo cuối: file sửa, lý do, verify result, git status
- **Guard an toàn nghiêm ngặt** — hard rules: không `rm -rf`, không
  `git reset --hard`, không `git clean -fd`, không force push, không sửa
  `.env`, không DROP/TRUNCATE/DELETE không hỏi trước.
- **Backward compatible 100%** — agent vẫn tên `build-strong`, mode `all`,
  không thay đổi frontmatter hay permission. Phiên bản cũ vẫn dùng được.
- Xem cách dùng chi tiết ở section [Dùng build-strong cho fullstack-auto](#dùng-build-strong-cho-fullstack-auto).

## Dùng build-strong cho fullstack-auto

Agent `build-strong` (mặc định trong kit) đã được nâng cấp thành
**fullstack-autopilot**. Để dùng:

```bash
# Mở OpenCode, trong project của bạn, nói tự nhiên:
# "làm tính năng X fullstack"
# "thêm API Y"
# "fix lỗi Z"

# Hoặc gọi agent trực tiếp:
# @build-strong làm tính năng đăng nhập
```

Agent sẽ tự động chạy full workflow: spec → plan → build slice → verify.

### Ví dụ

| Bạn nói | Agent làm |
|---------|-----------|
| `@build-strong thêm API CRUD user` | Spec ngắn → plan slice (DB → BE → FE) → build → verify |
| `@build-strong sửa lỗi login không redirect` | git status → detect stack → debug → fix nhỏ → verify |
| `@build-strong thêm validation cho form đăng ký` | Check contract FE/BE → thêm validation 2 phía → test |

### Workflow chi tiết

Agent tuân thủ 8 bước:

```
git status → detect stack → /checkpoint (nếu lớn)
→ spec + AC → plan → build slice → verify → báo cáo
```

- Kiểm soát contract FE/BE/DB ở mỗi slice.
- Không tự push, không tự migration nguy hiểm.
- Dùng `/checkpoint` và `/cleanup-safe` tích hợp sẵn.
- Báo cáo cuối: file sửa, lý do, test result, diff.

### Backward compat

Agent vẫn tên `build-strong`, mode `all`. Mọi script gọi `@build-strong`
trong code cũ vẫn hoạt động. Không cần thay đổi config.

## Có gì mới trong v1.3.4

- **GSD Core opt-in integration** — `opk gsd` / `opk update-gsd` chuyển
  tiếp sang official installer `npx @opengsd/gsd-core@latest`. Kit
  **không vendor / copy** GSD source. Có cả `.sh` và `.ps1`.
  Flags: `--dry-run` để xem plan, `--yes` để skip confirm.
- **`opk update-all`** — `git pull --ff-only` (an toàn), refresh
  bundled `_bmad/`, optional GSD update với `--with-gsd`.
- **`THIRD_PARTY.md`** — bảng liệt kê rõ BMAD, Superpowers, GSD Core,
  rtk/tokscale kèm quy tắc *kit không bao giờ auto-update trên shell start*.
- **`.github/workflows/verify.yml`** — workflow CI mới tập trung cho
  v1.3.4 kit self-check (bash -n, shellcheck, shfmt, pwsh parse,
  verify.sh, verify.ps1, validate, integration test). Chạy song song
  với `ci.yml` hiện có (không thay thế, không xóa job nào).
- **`verify.sh` / `verify.ps1`** — đọc `${KIT_DIR}/VERSION` trực tiếp;
  nếu file thiếu thì WARN (không crash) để các check khác vẫn chạy.
- **Backward compatible 100%** — mọi subcommand / file / folder của
  v1.3.0 → v1.3.3 vẫn hoạt động nguyên xi. Tất cả v1.3.4 đều additive.

## Dùng đơn giản không cần nhớ lệnh (mới từ v1.3.3)

Bạn không cần nhớ slash command. Cứ nói tự nhiên (tiếng Việt / tiếng Anh), agent sẽ auto-route. 5 câu phổ biến nhất:

| Bạn nói…                          | Agent sẽ làm gì                                   |
| --------------------------------- | ------------------------------------------------- |
| **fix lỗi hộ tôi**                | Reproduce lỗi, tìm root cause, sửa nhỏ nhất, verify |
| **kiểm tra project ổn chưa**      | Smart-scan repo, check git/lint/test/build, báo rủi ro |
| **làm tính năng này fullstack**   | Spec nhỏ → plan → slice nhỏ → code → verify        |
| **tối ưu token cho task này**     | Repo map gọn, đọc đúng file, update handoff         |
| **dọn file rác do agent tạo**     | Move untracked `.tmp/.bak/repro-*` vào `.opk-trash/`, không xóa file tracked |

> Mặc định agent **không bao giờ** chạy `rm -rf`, `git reset --hard`,
> `git clean -fd`, hay force push. Mọi thao tác hủy file đều đi qua
> workflow an toàn có xác nhận trước.

**Workflows mới trong v1.3.3** (slash command, cho advanced):

- `/cleanup-safe` — dọn file tạm an toàn (default dry-run).
- `/handoff-save` — cập nhật `AI_HANDOFF.md` để mai làm tiếp.
- `/checkpoint` — snapshot working tree trước khi sửa lớn.

Backing script: `scripts/cleanup-agent-artifacts.sh`. Auto Router chi tiết
xem `templates/AGENTS.md` và `templates/OPENCODE.md`.

## Cài all-in-one bằng 1 lệnh (khuyến nghị)

**`cd` vào project** rồi paste 1 dòng dưới đây — kit tự clone (hoặc `pull` nếu đã có) → cài **global + project + fullstack + verify** xong in `Run: opencode`.

### Linux / macOS / Git Bash / WSL

```bash
bash -c 'PROJECT="$PWD"; KIT="$HOME/opencode-power-kit"; if [ -d "$KIT/.git" ]; then git -C "$KIT" pull --ff-only; else git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git "$KIT"; fi; bash "$KIT/bootstrap.sh" --all --project-dir "$PROJECT"; cd "$PROJECT"; bash "$KIT/verify.sh"; echo "✅ OpenCode Power Kit all-in-one done. Run: opencode"'
```

Sau khi xong:

```bash
source ~/.bashrc    # zsh thì: source ~/.zshrc
opk one             # ← chính là all-in-one, dùng lại bất kỳ lúc nào
opencode
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -Command "$Project=(Get-Location).Path; $KIT=Join-Path $HOME 'opencode-power-kit'; if (Test-Path (Join-Path $KIT '.git')) { & git -C $KIT pull --ff-only } else { & git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git $KIT }; & (Join-Path $KIT 'bootstrap.ps1') -All -ProjectDir $Project -Yes; & (Join-Path $KIT 'verify.ps1'); Write-Host '✅ OpenCode Power Kit all-in-one done. Run: opencode'"
```

Sau khi xong: **mở PowerShell mới** (để load User PATH), rồi:

```powershell
opk one             # ← chính là all-in-one, dùng lại bất kỳ lúc nào
opk.cmd path
opencode
```

### `opk one` / `opk go` — all-in-one shorthand (sau khi đã cài global lần đầu)

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

> Bootstrap tự phát hiện shell: không sudo, không `curl|sh`, backup mọi file cũ, idempotent (chạy lại không duplicate PATH / marker / config). Từ chối cài project trong `$HOME`, kit dir, `/`, `/tmp`, `/var/tmp`, `/usr`, `/etc` (hoặc `C:\`, `C:\Windows`, `C:\Program Files*`, `$env:TEMP` trên Windows). Nếu pwd không an toàn, `--all` vẫn chạy global + in cảnh báo hướng dẫn `cd` sang project.

## Cài thủ công / Advanced

Khuyến nghị: dùng lệnh 1 dòng ở trên. Cách dưới đây dành cho ai muốn kiểm
soát từng bước (review script trước khi chạy, dùng fork nội bộ, CI, v.v.).

### Linux / macOS / Git Bash / WSL

```bash
# 1) Clone kit (một lần)
git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git ~/opencode-power-kit

# 2) Cài global (commands / skills / agents + opk CLI + ~/.bashrc)
bash ~/opencode-power-kit/setup.sh --global

# 3) Kích hoạt + mở OpenCode
source ~/.bashrc    # zsh thì: source ~/.zshrc
opk help
opencode
```

### Windows PowerShell

```powershell
# 1) Clone kit
git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git $HOME\opencode-power-kit

# 2) Cài global
powershell -ExecutionPolicy Bypass -File "$HOME\opencode-power-kit\setup.ps1" -Global -Yes

# 3) Mở PowerShell mới, rồi:
opk.cmd help
opk.cmd path
opencode
```

### Sau khi cài global — dùng với mọi project

```bash
cd /path/to/your/project
opk install           # cài AGENTS.md / OPENCODE.md / .opencode/opencode.json
opk fullstack         # (tùy chọn) cài profile Node/Nest/React/MySQL
opk verify            # kiểm tra project đã sẵn sàng
```

```powershell
# Windows
cd C:\path\to\your\project
opk.cmd install
opk.cmd fullstack
opk.cmd verify
```

Cờ non-interactive đầy đủ (cả bash và PowerShell):

```bash
bash setup.sh --global      # cài global
bash setup.sh --project     # cài vào project hiện tại
bash setup.sh --fullstack   # cài full-stack profile
bash setup.sh --all         # cài tất cả (cần cd vào project)
bash setup.sh --doctor      # chẩn đoán (read-only)
bash setup.sh --dry-run     # in kế hoạch, không sửa gì
bash setup.sh --yes         # skip confirm
bash setup.sh --help        # in hướng dẫn
```

Sau khi cài global, lệnh `opk` có sẵn trong shell (PATH):

| `opk ...`        | Tác dụng                                                                  |
|------------------|----------------------------------------------------------------------------|
| `opk one`        | **All-in-one**: global + project + fullstack + verify (khuyến nghị)        |
| `opk go`         | Alias: `opk one`                                                          |
| `opk help`       | In trợ giúp đầy đủ                                                        |
| `opk version`    | In version kit                                                             |
| `opk path`       | In đường dẫn kit hiện tại                                                  |
| `opk global`     | Cài global (commands / skills / agents + opk CLI)                         |
| `opk install`    | Cài vào project hiện tại (= `opk init`)                                    |
| `opk fullstack`  | Cài full-stack profile                                                     |
| `opk all`        | Cài tất cả: global + project + fullstack + verify                          |
| `opk doctor`     | Chẩn đoán (read-only)                                                      |
| `opk verify`     | Kiểm tra project hiện tại                                                  |
| `opk tools`      | Detect / hướng dẫn cài `rtk`, `tokscale`                                   |
| `opk update-bmad`| Cập nhật BMAD Method cho project hiện tại                                 |

## Có gì mới trong v1.3.2

- **`opk one` / `opk go` — all-in-one shorthand** — chạy 1 lệnh duy nhất
  để cài **global + project + fullstack + verify** trong project hiện tại.
  `opk one` = `bootstrap.sh --all --project-dir "$(pwd)" --yes` (bash) /
  `bootstrap.ps1 -All -ProjectDir (Get-Location).Path -Yes` (PowerShell).
- **4-step `--all` flow** — `bootstrap.sh` / `bootstrap.ps1` / `setup.sh`
  / `setup.ps1` giờ log rõ `[1/4] global` → `[2/4] project` →
  `[3/4] fullstack` → `[4/4] verify`. Idempotent, nếu pwd nguy hiểm thì
  skip `[2/4] + [3/4] + [4/4]` với cảnh báo rõ hướng dẫn `cd` sang
  project.
- **All-in-one one-liner** — top section README trình bày 1 dòng duy
  nhất cho cả bash và PowerShell: tự clone/pull kit → bootstrap --all
  → verify → in `✅ OpenCode Power Kit all-in-one done. Run: opencode`.
- **Final success banner** — `bootstrap.sh` / `bootstrap.ps1` cuối cùng
  in `✅ OpenCode Power Kit all-in-one done. Run: opencode` thay vì
  banner trống.
- **`bin/opk` help text** bổ sung `opk one`, `opk go`, `opk update-bmad`
  + 2 ví dụ all-in-one one-liner (bash + PowerShell).
- **Backward compatible** — `--global`, `--project`, `--fullstack`,
  `--doctor`, `--yes`, `opk global`, `opk install`, `opk fullstack`,
  `opk all`, `opk doctor`, `opk verify`, `opk tools`, `opk bootstrap`,
  `opk quick`, `opk init` không đổi. `opk one` đổi semantics (global
  → all-in-one); ai cần behavior cũ dùng `opk quick`.

## Có gì mới trong v1.3.1

- **`BMAD_METHOD_VERSION` được pin** — mặc định `6.8.0`; override qua env
  `BMAD_METHOD_VERSION=...` trước khi chạy `install.sh` / `install.ps1`
  / `update-bmad.sh`. Lockfile-friendly, CI reproducible.
- **Full log capture cho BMAD** — mọi output của `npx bmad-method ...` đổ
  vào `.opencode-power-bmad-install.log` (install) hoặc
  `.opencode-power-bmad-update.log` (update). Lỗi in `tail -50` + đường
  dẫn log rõ ràng để user mở xem.
- **PowerShell: check exit code** — `install.ps1` / `update-bmad.ps1`
  kiểm tra `$LASTEXITCODE` của `npx`; fail thì in log + hướng dẫn sửa.
- **Safety guard đồng bộ** — `install.sh` / `install.ps1` /
  `update-bmad.sh` dùng chung `is_bad_project_dir` (Unix) /
  `Test-BadProjectDir` (Windows) với `bootstrap.sh` / `bootstrap.ps1`.
  Từ chối: HOME, kit dir, `/`, `/tmp`, `/var/tmp`, `/usr`, `/etc`
  (Unix); HOME, kit, `C:\`, `C:\Windows`, `C:\Program Files*`,
  `$env:TEMP` (Windows).
- **CI strict** — `shellcheck` và `shfmt -d` fail thật (xóa `|| echo
  "skip..."`); `bash -n`; `validate-opencode-pack`; JSON/YAML/secret
  scan. Không còn fail-silent.
- **`LICENSE` (MIT) + `VERSION` bump** — `1.3.0` → `1.3.1`.
- **`shfmt -w` toàn bộ `.sh`** — conform canonical style (tab indent,
  `} >>file` không space). `git diff --check` clean.
- **README restructured** — giữ 1-liner canonical, chuyển
  "Dùng nhanh 30 giây" thành "Manual / Advanced", cập nhật tree với
  `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1`, document `BMAD_METHOD_VERSION`.

## Cấu hình BMAD

| Biến                  | Mặc định | Mô tả                                      |
|-----------------------|----------|--------------------------------------------|
| `BMAD_METHOD_VERSION` | `6.8.0`  | Pin version BMAD Method (bmm module)       |

```bash
# Pin version khác (vd muốn thử 6.9.0-beta)
export BMAD_METHOD_VERSION=6.9.0-beta
bash ~/opencode-power-kit/install.sh
```

```powershell
# Windows
$env:BMAD_METHOD_VERSION = "6.9.0-beta"
powershell -File "$HOME\opencode-power-kit\install.ps1"
```

Log BMAD:

- Install: `<project>/.opencode-power-bmad-install.log`
- Update:  `<project>/.opencode-power-bmad-update.log`

## Có gì mới trong v1.2.0

- **`setup.sh`** — menu tiếng Việt tương tác + 7 cờ non-interactive
  (`--global`, `--project`, `--fullstack`, `--all`, `--doctor`,
  `--dry-run`, `--yes`). Từ chối chạy per-project install trong HOME
  hoặc trong chính kit. Báo lỗi rõ nếu thiếu script con.
- **`opk` CLI** — wrapper mỏng gọi lại các script có sẵn. Không duplicate
  logic. Tự phát hiện đường dẫn kit qua `BASH_SOURCE` hoặc `OPK_KIT_DIR`.
  Lệnh: `help`, `version`, `path`, `global`, `install`, `fullstack`,
  `all`, `doctor`, `verify`, `tools`.
- **`install-global.sh` cải tiến** — tự cài `opk` vào `~/.local/bin/opk`
  (có backup nếu file đã tồn tại). Tạo `GLOBAL_PACK_REPORT.md` động,
  liệt kê đúng agents/commands/skills đang cài, kèm vị trí `opk` và
  trạng thái PATH. Tất cả thao tác đều idempotent.
- **Không thay đổi hành vi v1.1.1** — tất cả script cũ vẫn chạy được,
  flag mới chỉ là lớp tiện ích bên ngoài.

## Cài global toàn bộ OpenCode

```bash
bash ~/opencode-power-kit/install-global.sh
source ~/.bashrc
opencode
```

Sau khi cài global, dùng được:
- `/smart-scan` — quét nhanh project
- `/repo-map` — tạo bản đồ project
- `/bugfix-safe` — sửa bug an toàn
- `/review-diff` — review git diff
- `/token-pack` — tạo gói context Repomix
- `/db-readonly` — kiểm tra DB read-only
- `@plan-lite` hoặc agent `plan-lite` — lập kế hoạch tiết kiệm token

Và các command nâng cấp v2 (lifecycle + review + token):
- `/spec-lite` — đặc tả ngắn (scope, AC, out-of-scope)
- `/plan-work` — chia task nhỏ, có file + test
- `/build-slice` — triển khai 1 slice, ≤ 2 file
- `/test-proof` — chạy/đề xuất test chứng minh
- `/ship-check` — checklist trước commit/push
- `/security-review` — review security (secrets, auth, input)
- `/api-contract-review` — check FE/BE API contract
- `/migration-safe` — kiểm tra migration an toàn
- `/rtk-gain` — chạy `rtk gain` hoặc hướng dẫn cài

## Cài cho 1 project

```bash
# Clone (lần đầu)
git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git ~/opencode-power-kit

# Vào project cần cài
cd /path/to/your/project

# Cài bằng opk (cách khuyến nghị từ v1.2.0)
opk install
# hoặc
bash ~/opencode-power-kit/install.sh
```

## Cấu trúc

```
~/opencode-power-kit/
├── README.md              # Tài liệu này
├── setup.sh               # v1.2.0: menu + flags non-interactive
├── bin/
│   ├── opk                # v1.2.0: CLI wrapper (bash — Linux/macOS/WSL/Git Bash)
│   ├── opk.cmd            # v1.3.0: CLI wrapper (Windows cmd)
│   └── opk.ps1            # v1.3.0: CLI wrapper (Windows PowerShell)
├── install.sh             # v1.3.1: cài per-project (BMAD pin + log + safety)
├── install.ps1            # v1.3.1: cài per-project Windows
├── bootstrap.sh           # v1.3.0: cài global qua curl|bash
├── bootstrap.ps1          # v1.3.0: cài global Windows
├── setup.sh               # v1.2.0: menu + flags non-interactive
├── setup.ps1              # v1.3.0: setup Windows
├── install-global.sh      # v1.2.0: cài global + opk CLI + report động
├── verify.sh              # Script kiểm tra
├── doctor.sh              # Chẩn đoán (read-only)
├── uninstall.sh           # Gỡ cài (có confirm / --yes)
├── uninstall.ps1          # v1.3.0: gỡ cài Windows
├── update-bmad.sh         # v1.3.1: cập nhật BMAD (BMAD pin + log + safety)
├── scripts/
│   └── install-token-tools.sh  # Kiểm tra + hướng dẫn cài rtk/tokscale
├── opencode-global/       # Config global
│   ├── agents/            # Agents tiết kiệm token
│   │   ├── plan-lite.md
│   │   ├── review-lite.md
│   │   ├── debug-lite.md
│   │   └── build-strong.md
│   ├── commands/          # Commands theo nhu cầu
│   │   ├── smart-scan.md
│   │   ├── bugfix-safe.md
│   │   ├── review-diff.md
│   │   ├── repo-map.md
│   │   ├── token-pack.md
│   │   ├── db-readonly.md
│   │   ├── spec-lite.md           # v2: đặc tả ngắn
│   │   ├── plan-work.md           # v2: chia task nhỏ
│   │   ├── build-slice.md         # v2: triển khai slice
│   │   ├── test-proof.md          # v2: chứng minh test
│   │   ├── ship-check.md          # v2: checklist ship
│   │   ├── security-review.md     # v2: review security
│   │   ├── api-contract-review.md # v2: review API contract
│   │   ├── migration-safe.md      # v2: check migration
│   │   └── rtk-gain.md            # v2: tối ưu token với rtk
│   └── skills/            # Skills load theo nhu cầu
│       ├── token-smart-code/
│       ├── serena-first/
│       ├── safe-edit/
│       ├── repo-map/
│       ├── js-ts-project/
│       ├── security-review/         # v2
│       ├── api-contract/            # v2
│       ├── database-migration-safe/ # v2
│       ├── test-strategy/           # v2
│       ├── frontend-ui-review/      # v2
│       ├── adr-architecture-decision/ # v2
│       └── rtk-token-optimizer/     # v2
├── templates/
│   ├── AGENTS.md          # Rules cho AI agent
│   ├── OPENCODE.md        # Guide project
│   ├── opencode.json      # Config OpenCode
│   ├── lefthook.yml       # Git hooks
│   ├── knip.json          # Dead code detector
│   └── gitignore-extra.txt # Gitignore bổ sung
└── docs/
    ├── workflow.md        # Quy trình làm việc
    ├── prompts.md         # Prompt mẫu
    └── safety.md          # Rules an toàn
```

## Sau khi install per-project

`install.sh` sẽ thêm vào project:

| File | Mục đích |
|------|----------|
| `AGENTS.md` | Rules bắt buộc cho AI agent |
| `OPENCODE.md` | Guide tech stack + quy trình |
| `.opencode/opencode.json` | Config Superpowers plugin |
| `.gitignore` | Merge thêm ignores |
| `knip.json` | Dead code detection |
| `lefthook.yml` | Pre-commit hooks |
| `opencode-power-install-report.md` | Báo cáo cài đặt |

## Commands

```bash
# Verify project đã cài đúng
bash ~/opencode-power-kit/verify.sh

# Cập nhật BMAD
bash ~/opencode-power-kit/update-bmad.sh

# Kiểm tra rtk / tokscale (không tự cài)
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

## Nâng cấp mạnh không cần MCP

Bản v2 bổ sung 9 commands + 7 skills tập trung vào **lifecycle** (spec → plan → build → test → ship) và **review chuyên sâu** (security, API contract, migration, UI, ADR). Đặc điểm:

- **Không thêm MCP server nào** vào repo. Tất cả là command + skill chạy local.
- **Không copy token, password, API key, `.env`** vào bất kỳ file nào.
- **Không bulk-copy skill** từ repo khác — mỗi skill viết tay, scoped, có ví dụ cụ thể.
- Tất cả command đều tôn trọng quy tắc `safe-edit`: không xóa file, không push force, không tự chạy curl|sh.

## Full-stack profile: Node + NestJS + React/Vite + MySQL

Bản v1.1.0 thêm 1 profile chuyên cho stack full-stack:

- **Backend:** NestJS + TypeORM/Prisma.
- **Frontend:** React + Vite + React Query / Zustand.
- **Database:** MySQL 8.x.
- **Auth:** JWT + RBAC.
- **Test:** Vitest + supertest + Playwright.

### Cài vào project

```bash
# Từ thư mục project (KHÔNG chạy trong HOME hay ~/opencode-power-kit)
bash ~/opencode-power-kit/scripts/install-fullstack-profile.sh
```

Script sẽ:

1. Backup `AGENTS.md` / `OPENCODE.md` (nếu có) vào `.opencode-power-kit-backup-<timestamp>/`.
2. Append `AGENTS.append.md` + `OPENCODE.append.md` qua marker (idempotent).
3. Copy 5 commands vào `.opencode/commands/fullstack/`.
4. Copy 5 skills vào `.agents/skills/`.
5. Tạo `FULLSTACK_PROFILE_REPORT.md` ở project.

### Commands mới (global full-stack)

| Command | Mục đích |
|---------|----------|
| `/fullstack-scan` | Quét project full-stack (FE/BE/DB/scripts/env/docker) |
| `/openapi-check` | Check OpenAPI spec với spectral/oasdiff (in hướng dẫn cài nếu thiếu) |
| `/secret-scan` | Quét secret pattern với gitleaks/trufflehog |
| `/sast-check` | SAST với semgrep |
| `/e2e-plan` | Đề xuất Playwright E2E flow |
| `/test-matrix` | Tạo test matrix (unit/integration/e2e/smoke) |
| `/js-quality-check` | Detect eslint/prettier/biome/knip/vitest/tsc |
| `/env-doctor` | Kiểm tra env an toàn, không in secret value |
| `/docker-dev-doctor` | Kiểm tra docker-compose dev (ports, volumes, healthcheck) |

### Skills mới (global full-stack)

| Skill | Phạm vi |
|-------|---------|
| `openapi-contract` | OpenAPI 3.1 spec, status code, error format, pagination, auth |
| `secure-fullstack` | Secrets, auth, input validation, CORS, headers, uploads, logging |
| `dependency-maintenance` | Update dep an toàn, lockfile, renovate, audit |
| `fullstack-test-strategy` | Test pyramid cho FE/BE/API/DB |
| `js-ts-quality` | TypeScript, eslint/prettier/biome, knip, vitest, build |
| `env-config-safe` | `.env`/`.env.example`, validation, secret management |
| `docker-compose-safe` | Compose dev: ports, volumes, healthcheck, env |
| `nest-react-mysql` | Tổng hợp rule cho stack NestJS + React/Vite + MySQL |

### Detect-only scripts (optional)

Không tự cài, không sudo, không `curl|sh`. Chỉ detect + in hướng dẫn:

```bash
bash ~/opencode-power-kit/scripts/install-security-tools.sh       # gitleaks, trufflehog, semgrep
bash ~/opencode-power-kit/scripts/install-api-tools.sh            # spectral, oasdiff, openapi-generator
bash ~/opencode-power-kit/scripts/install-js-quality-tools.sh     # eslint, prettier, biome, knip, vitest, tsc
```

Mỗi script tạo report tương ứng (`SECURITY_TOOLS_REPORT.md`,
`API_TOOLS_REPORT.md`, `JS_QUALITY_TOOLS_REPORT.md`).

### Templates mới (optional, copy sang project nếu muốn)

- `templates/biome.json.example` — config Biome (thay ESLint + Prettier).
- `templates/renovate.json.example` — config Renovate (auto-update dep).
- `templates/openapi/openapi.yaml.example` — OpenAPI 3.1 skeleton.
- `templates/openapi/spectral.yaml.example` — Spectral ruleset.

### Commands mới

| Command | Mục đích | Dùng khi |
|---------|----------|----------|
| `/spec-lite` | Đặc tả ngắn (goal, scope, AC, out-of-scope) | Bắt đầu task mới, cần scope rõ trước khi code |
| `/plan-work` | Chia task ≤ 7 bước, mỗi bước có file + test | Sau spec, cần kế hoạch atomic commit được |
| `/build-slice` | Triển khai 1 slice, ≤ 2 file, ≤ 100 dòng diff | Theo plan, mỗi step là 1 slice |
| `/test-proof` | Chạy/đề xuất test chứng minh | Sau khi sửa, cần proof không regress |
| `/ship-check` | Checklist trước commit/push | Trước khi tạo PR / merge |
| `/security-review` | Review security (secrets, auth, input) | Trước merge code có auth/input mới |
| `/api-contract-review` | Check FE/BE API contract | Trước/sau khi thay đổi API |
| `/migration-safe` | Kiểm tra migration an toàn | Trước khi chạy migration DB |
| `/rtk-gain` | Chạy `rtk gain` hoặc hướng dẫn cài | Khi muốn tối ưu token usage |

### Skills mới

| Skill | Phạm vi |
|-------|---------|
| `security-review` | Secrets, auth, input validation, crypto, headers |
| `api-contract` | Endpoint, type, status, error format, auth, pagination |
| `database-migration-safe` | DROP/TRUNCATE/DELETE guard, backfill, rollback |
| `test-strategy` | Pyramid, framework theo stack, minimal infra |
| `frontend-ui-review` | A11y, layout, typography, color, state, performance |
| `adr-architecture-decision` | Format ADR Nygard, khi nào viết |
| `rtk-token-optimizer` | Mapping lệnh thường → rtk, alias gợi ý |

## Cách dùng RTK / tokscale (không bắt buộc)

RTK (Rust Token Killer) wrapper các lệnh shell phổ biến, giảm **40-60% output token**. Tokscale vẽ bar chart token usage để phát hiện request tốn token.

### Kiểm tra nhanh

```bash
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

Script **không sudo**, **không tự chạy `curl|sh`**, **không bắt buộc cài**. Nó:
1. Phát hiện rtk / tokscale trong `$PATH`.
2. In hướng dẫn cài thủ công nếu thiếu.
3. Tạo `TOKEN_TOOLS_REPORT.md` với hướng dẫn chi tiết.

### Cài thủ công (nếu muốn)

```bash
# Cần Rust/cargo trước
cargo install rtk
cargo install tokscale
# Repo: https://github.com/rtk-ai/rtk
#       https://github.com/hasansezertasan/tokscale
```

### Dùng

```bash
# Thay vì:
ls -la
git status
cargo test

# Dùng:
rtk ls
rtk git status
rtk cargo test
```

Hoặc alias trong `~/.bashrc`:
```bash
alias ls='rtk ls'
alias cat='rtk cat'
alias rg='rtk rg'
alias git='rtk git'
```

Trong OpenCode, dùng command `/rtk-gain` để chạy `rtk gain` (auto-suggest alias).

## Ghi chú quan trọng

- Repo này **không copy MCP config** (`opencode.json` mcp section) từ bất kỳ đâu.
- Tất cả command mới **không touch** `~/.config/opencode/opencode.json` global.
- Nếu user muốn MCP, tự thêm vào project `.opencode/opencode.json` của họ.

## An toàn

- Không copy token, password, API key, `.env`.
- Không copy `~/.config/opencode/opencode.json`.
- Không xóa file ngoài `~/opencode-power-kit`.
- Backup trước khi overwrite.
- Không tự push.

## License

MIT

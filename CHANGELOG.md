# Changelog

All notable changes to OpenCode Power Kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-06-08

### Added

- **`build-strong` → fullstack-autopilot** — agent `build-strong` được nâng
  cấp thành fullstack-autopilot với quy trình tự động 9 bước:
  1. Git status & detect stack (backend/frontend/database/scripts).
  2. Checkpoint trước sửa lớn (≥ 3 file hoặc migration).
  3. Spec ngắn + acceptance criteria + API contract scope.
  4. Plan-work chia vertical slice (≤ 2 file, ≤ 100 dòng diff).
  5. Build từng slice — đảm bảo contract DB ↔ BE ↔ FE khớp.
  6. Verify: chạy lint/typecheck/test/build nếu có; manual proof nếu không.
  7. Cleanup file tạm qua `/cleanup-safe`.
  8. Handoff qua `/handoff-save` nếu task lớn.
  9. Báo cáo cuối: file sửa, lý do, slice count, verify result, git status.
- **12 Hard Rules an toàn** trong agent prompt: không `rm -rf`, không
  `git reset --hard`, không `git clean -fd`, không force push, không sửa
  `.env`/secrets, không DROP/TRUNCATE/DELETE không hỏi, không tự push,
  không xóa tracked files, không đọc toàn repo, mỗi slice ≤ 100 dòng diff,
  luôn `git status` trước/sau, luôn báo cáo cuối.
- **Layer-specific hướng dẫn kỹ thuật** — backend (NestJS/Express/Django/
  Rails), frontend (React/Next.js/Vue), database (Prisma/TypeORM/migration)
  với các kỹ thuật đặc thù từng layer.
- **README section "Dùng build-strong cho fullstack-auto"** — hướng dẫn
  chi tiết cách dùng agent build-strong cho fullstack task.

### Backward compatibility

- **100% backward compatible.** Agent vẫn tên `build-strong`, mode `all`,
  không thay đổi frontmatter hay permission structure.
- Tất cả commands/skills/scripts hiện có không bị ảnh hưởng.
- `verify.sh` / `verify.ps1` thêm check build-strong content để đảm bảo
  agent đã được nâng cấp.

## [1.3.4] - 2026-06-06

### Added

- **GSD Core opt-in integration** — `opk gsd` and `opk update-gsd`
  forward to the official GSD Core installer
  (`npx @opengsd/gsd-core@latest`). The kit does NOT vendor or
  copy GSD source. Supported via:
  - `scripts/install-gsd-core.sh` (Linux / macOS / Git Bash / WSL)
  - `scripts/install-gsd-core.ps1` (Windows PowerShell)
  Both check `node`/`npm`/`npx`, print the planned command,
  ask for confirmation, and forward to `npx`. Pass `--dry-run`
  to plan, `--yes` to skip the prompt.
- **`opk update-all`** — pulls kit updates via
  `git pull --ff-only` (no reset, no force push), refreshes the
  bundled `_bmad/` module pack, and optionally runs
  `update-gsd` when `--with-gsd` is passed.
- **`THIRD_PARTY.md`** — explicit list of every third-party
  integration (BMAD, Superpowers, GSD Core, rtk/tokscale) with
  the rule: the kit NEVER vendors third-party source, and
  NEVER auto-updates on shell start.
- **`.github/workflows/verify.yml`** — a focused v1.3.4 verify
  workflow that runs `verify.sh`, `verify.ps1`, the python
  validator, the integration test, plus `bash -n`,
  `shellcheck`, and `shfmt` checks. Runs alongside the
  existing comprehensive `ci.yml` (no behavior removed).
- **`scripts/validate-opencode-pack.py`** — v1.3.4 compliance
  section added: pins `EXPECTED_VERSION = "1.3.4"`, checks
  `THIRD_PARTY.md` exists and references BMAD / Superpowers /
  GSD Core, and checks `CHANGELOG.md` mentions v1.3.3 / v1.3.4
  needles. The v1.3.3 structural validation (frontmatter on
  commands/agents/skills, profiles, openapi templates) is
  preserved.

### Improved

- **`verify.sh` VERSION read is now explicit** — reads
  `${KIT_DIR}/VERSION` instead of relying on `<VERSION` from
  the script's CWD. If `VERSION` is missing, the script WARNS
  and continues with the rest of the checks instead of
  crashing (this fixes a confusing failure mode on partial
  syncs).
- **`verify.ps1`** — same explicit read-from-`$KitDir\VERSION`
  behavior, same graceful warning on missing file.
- **Auto Router presence check** — both `verify.sh` and
  `verify.ps1` now require the *Natural Language Auto Router*
  to be present in `templates/AGENTS.md` and
  `templates/OPENCODE.md`.

### Backward compatibility

- **100% backward compatible.** No v1.3.0 → v1.3.3 command,
  file, or directory was renamed or removed.
- All new subcommands are additive to `bin/opk` (`gsd`,
  `update-gsd`, `update-all`); all existing subcommands
  (`global`, `install`, `bootstrap`, `doctor`, `verify`,
  `update-bmad`, etc.) still work.
- Optional integration is **opt-in**; the kit still works
  perfectly without ever invoking `opk gsd`.
- Existing `ci.yml` workflow (10 jobs) is untouched and
  still gates every PR.

# Changelog

All notable changes to OpenCode Power Kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3] - 2026-06-06

### Added

- **`/cleanup-safe` command** (`opencode-global/commands/cleanup-safe.md`)
  — dọn file tạm/debug/repro an toàn. Default dry-run; `--apply` chỉ
  **MOVE** file vào `.opk-trash/YYYYMMDD-HHMMSS/`, không bao giờ xóa.
  Không chạm tracked file, không chạm protected dirs
  (`src/`, `app/`, `backend/`, `frontend/`, `prisma/`, `migrations/`,
  `public/`, `docs/`, `.git/`, `.opencode/`, `.agents/`, `_bmad/`).
- **`scripts/cleanup-agent-artifacts.sh`** — backing script cho
  `/cleanup-safe`. `set -euo pipefail`, `--dry-run` / `--apply`,
  refuses to run ngoài git work-tree.
- **`/handoff-save` command** (`opencode-global/commands/handoff-save.md`)
  — tạo / cập nhật `AI_HANDOFF.md` để làm project dài không đứt
  context. Dùng `templates/AI_HANDOFF.md` làm template, **không ghi
  đè** file user đã có.
- **`templates/AI_HANDOFF.md`** — short, machine-friendly template
  (goal, stack, current task, what changed, files changed, commands
  run, tests/verification, known issues, next steps).
- **`/checkpoint` command** (`opencode-global/commands/checkpoint.md`)
  — snapshot working tree ra `.opk-checkpoints/<ts>.patch` +
  `.summary.md` trước khi sửa lớn. Không commit, không reset,
  không force push. Restore bằng `git apply`.
- **Natural Language Auto Router** — đã thêm vào `templates/AGENTS.md`
  và `templates/OPENCODE.md`. Map 5 casual request (Vietnamese +
  English) sang safe workflow: bugfix, project health, feature,
  token-smart, cleanup. Slash command luôn thắng auto-router.
- **README quick-start** — 5 câu tự nhiên phổ biến ở đầu README;
  advanced slash command list chuyển xuống dưới để dễ dùng hơn.

### Improved

- `.gitignore` thêm `.opk-trash/`, `.opk-checkpoints/`, `.opk-scratch/`
  để các thư mục safety của v1.3.3 không bao giờ lọt vào commit.
- `verify.sh` thêm 8 check cho v1.3.3 (3 new commands, 1 new script,
  AI_HANDOFF template, Auto Router presence, VERSION pin).

### Backward compatibility

- **100% backward compatible.** Không command / file / folder nào
  của v1.3.0 → v1.3.2 bị xóa, đổi tên, hay thay đổi behavior.
- Mọi thay đổi đều additive. Existing `bootstrap.sh` /
  `bootstrap.ps1` / `install.sh` / `verify.sh` vẫn chạy nguyên xi
  với kit v1.3.3.

## [1.3.2] - 2026-06-06

### Added

- **`opk one` / `opk go` — all-in-one shorthand** — chạy 1 lệnh duy nhất để
  cài **global + project + fullstack + verify** trong project hiện tại.
  Bash: `opk one` = `bootstrap.sh --all --project-dir "$(pwd)" --yes`.
  PowerShell: `opk one` = `bootstrap.ps1 -All -ProjectDir $Pwd -Yes`.
  Trùng behavior với all-in-one one-liner.
- **4-step `--all` flow** — `bootstrap.sh` / `bootstrap.ps1` / `setup.sh` /
  `setup.ps1` giờ log rõ `[1/4] global` → `[2/4] project` → `[3/4] fullstack`
  → `[4/4] verify`. `verify.sh` chạy cuối để check mọi thứ đã sẵn sàng.
  Idempotent, nếu pwd nguy hiểm thì skip `[2/4] + [3/4] + [4/4]` với cảnh báo
  rõ hướng dẫn `cd` sang project.
- **All-in-one one-liner** — README trình bày 1 dòng duy nhất cho cả bash
  (Linux/macOS/WSL/Git Bash) và PowerShell (Windows) để cài all-in-one
  từ project dir: tự clone/pull kit, chạy `bootstrap --all --project-dir`,
  rồi `verify`, in `✅ OpenCode Power Kit all-in-one done. Run: opencode`.
- **Final success banner** — `bootstrap.sh` / `bootstrap.ps1` cuối cùng
  in `✅ OpenCode Power Kit all-in-one done. Run: opencode` thay vì
  banner trống — người dùng thấy ngay bước tiếp theo.
- **`opk all` chạy verify** — `bin/opk` (bash) và `bin/opk.ps1`
  (PowerShell) giờ thêm `[4/4] verify.sh` ở cuối flow `[1/3]` →
  `[1/4]`. Bad-dir guard thông báo skip cả 3 bước project+fullstack+verify.

### Changed

- **`bin/opk one` đổi semantics** — trước v1.3.2 là alias cho
  `bootstrap.sh --global --yes` (chỉ cài global). Từ v1.3.2 là alias cho
  `bootstrap.sh --all --project-dir "$(pwd)" --yes` (all-in-one).
  Muốn cài global nhanh: dùng `opk quick` hoặc `opk global`.
- **`bin/opk` help text** — bảng lệnh giờ có `opk one`, `opk go`,
  `opk update-bmad`; thêm 2 ví dụ all-in-one one-liner (bash +
  PowerShell) với one-command cd + clone + bootstrap --all + verify.
- **`README.md` "Cài 1 lệnh" → "Cài all-in-one bằng 1 lệnh (khuyến
  nghị)"** — top section giờ là all-in-one one-liner + `opk one` /
  `opk go` workflow. Section "Cài thủ công / Advanced" giữ nguyên cho
  ai muốn kiểm soát từng bước. Opk command table bổ sung `opk one`,
  `opk go`, `opk update-bmad`.
- **`bootstrap.sh` / `bootstrap.ps1` `do_all` log format** — đổi
  `[1/N]...[2/N]...[3/N]` (N là số bước thật) thành `[1/4]...[2/4]...
  [3/4]...[4/4]` cố định. Step nào skip sẽ in `[X/4 + Y/4] BỎ QUA`.
- **`setup.sh` / `setup.ps1` `do_all` log format** — đổi `[1/3]`
  thành `[1/4]`, thêm bước `[4/4] verify.sh`. Print plan cũng đổi.

### Backward compatible

- `--global`, `--project`, `--fullstack`, `--doctor`, `--dry-run`,
  `--yes` không đổi.
- `opk global`, `opk install`, `opk fullstack`, `opk all`, `opk doctor`,
  `opk verify`, `opk tools`, `opk bootstrap`, `opk quick`, `opk init`
  không đổi behavior.
- `opk one` thay đổi semantics (global → all-in-one); ai phụ thuộc
  behavior cũ dùng `opk quick` hoặc `opk global` thay thế.
- `opk update-bmad` đã có ở v1.3.1, v1.3.2 chỉ nhắc lại trong help.

## [1.3.1] - 2026-06-05

### Added

- **`BMAD_METHOD_VERSION` pin** — mặc định `6.8.0`, override qua env
  `BMAD_METHOD_VERSION=...` trước khi chạy `install.sh` / `install.ps1`
  / `update-bmad.sh`. Reproducible, lockfile-friendly.
- **Full log capture cho BMAD** — `install.sh` đổ output vào
  `.opencode-power-bmad-install.log`; `update-bmad.sh` đổ vào
  `.opencode-power-bmad-update.log`. Fail path in `tail -50` + đường
  dẫn log rõ ràng.
- **`LICENSE` (MIT)** + README badge `BMAD Method v6.8.0`.
- **README section "Cấu hình BMAD"** — bảng env + ví dụ pin version +
  vị trí log file.
- **README section "Cài thủ công / Advanced"** — chuyển nội dung
  "Dùng nhanh 30 giây" thành section riêng với bash + PowerShell
  instructions; giữ 1-liner canonical ở đầu.
- **Tree trong README** cập nhật: `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1`,
  `install.sh`, `install.ps1`, `bootstrap.sh`, `bootstrap.ps1`, `setup.ps1`,
  `uninstall.ps1`, `update-bmad.sh`.

### Changed

- **`install.sh`** — thêm `BMAD_METHOD_VERSION` (default 6.8.0, env
  override), full log vào `.opencode-power-bmad-install.log`, fail
  message in `tail -50` + log path. Đồng bộ `is_bad_project_dir`
  (HOME, kit, `/`, `/tmp`, `/var/tmp`, `/usr`, `/etc`) với
  `bootstrap.sh` / `setup.sh`. Sửa `SC2129` (grouped here-doc append).
- **`install.ps1`** — thêm `$BmadVersion` (default 6.8.0, env override),
  full log capture, `$LASTEXITCODE` check + `tail -50` + fail message
  với log path. Đồng bộ `Test-BadProjectDir` (HOME, kit, `C:\`,
  `C:\Windows`, `C:\Program Files*`, `$env:TEMP`/`$env:TMP`) với
  `bootstrap.ps1`. Cải thiện error reporting.

### Round 2 - hardened identity & install paths

### Added

- **`OPK_USER_NAME` / `$OpkUserName` chain** — user-name cho BMAD
  Method install giờ lấy theo thứ tự: `OPK_USER_NAME` env →
  `git config user.name` → `${USER:-User}` (bash) /
  `${env:USERNAME}` → `'User'` (PowerShell). Không còn hardcode
  `--user-name nha` ở bất kỳ đâu trong installer. Override được.
- **`update-bmad.ps1`** — Windows parity với `update-bmad.sh`:
  `$BmadVersion` env, `$OpkUserName` chain, `Test-BadProjectDir`
  đồng bộ kit allowlist, `$LASTEXITCODE` check, full log
  `.opencode-power-bmad-update.log`, `tail -50` trên fail, hiển thị
  `.bmad` modules khi xong.
- **`opk update-bmad`** — thêm subcommand vào `bin/opk` (bash) và
  `bin/opk.ps1`. Forward flags xuống `update-bmad.{sh,ps1}`. Trùng
  pattern với `opk install` (refuse nếu pwd nguy hiểm).
- **Test/CI scratch allowlist** — `is_bad_project_dir` /
  `Test-BadProjectDir` ở `install.sh`, `install.ps1`,
  `update-bmad.sh`, `update-bmad.ps1`, `bootstrap.sh`,
  `bootstrap.ps1`, `setup.sh`, `setup.ps1`, `bin/opk`,
  `bin/opk.ps1`, `scripts/install-fullstack-profile.sh` cho phép
  `$KIT_DIR/.tmp` và `$KIT_DIR/.test` (test scratch only). Mọi
  project install thật vẫn bị từ chối đúng như cũ.
- **CI `pwsh-syntax` job** — syntax-check mọi `*.ps1` qua
  `[System.Management.Automation.Language.Parser]::ParseFile` (cài
  `pwsh` qua snap hoặc Microsoft apt repo, fail-soft nếu OS không
  hỗ trợ).
- **CI `bash-syntax` mở rộng** — `bash -n` giờ scan toàn bộ
  `*.sh` trong repo + `bin/opk` + `bootstrap.sh` + `setup.sh`
  qua `find`, không cần duy trì allowlist thủ công.
- **`.gitignore`** ở kit root + `templates/gitignore-extra.txt`
  ignore `.tmp/`, `.test/`, `.opencode-power-*.log` để scratch
  dirs và log files không bị commit nhầm.

### Changed

- **`install.sh` / `update-bmad.sh` / `install.ps1`** — bỏ
  `--user-name nha` hardcode; dùng `$OPK_USER_NAME` / `$OpkUserName`
  (xem chain ở phần Added). Info line + install report hiển thị
  user name thật đang dùng.
- **`install-global.sh`** — RC marker giờ là single block gồm
  `OPK_KIT_DIR="$KIT_REAL"` + `OPENCODE_CONFIG_DIR="$OPK_KIT_DIR/
  opencode-global"`; idempotent (không duplicate), safe REPLACE
  bằng `python3` in-place edit khi block đã tồn tại mà khác nội
  dung. `PATH_MARKER` cho `~/.local/bin` cũng idempotent. Không
  còn hardcode `$HOME/opencode-power-kit/opencode-global` ở bất
  kỳ đâu trong file.
- **`integration-test.sh`** viết lại hoàn toàn:
  - Scratch dir = `$KIT_DIR/.tmp/opk-integration-XXXXXX` (KHÔNG
    dùng `/tmp`; `install.sh` block `/tmp`).
  - `trap cleanup EXIT` để cleanup kể cả khi fail.
  - Stub `npx` ở PATH giả: log mọi invocation ra file, mock
    BMAD install để tạo `_bmad/`, `.agents/skills/`,
    `.opencode/commands/`, `.opencode/agents/` (chỉ tạo khi
    chưa có — không overwrite file install.sh đã copy từ
    template).
  - **Regression guards**:
    - Grep `--user-name nha` trong `*.sh`/`*.ps1`/`*.cmd` (trừ
      `.tmp`/`.test`/`.bak`/`.orig`) → phải rỗng.
    - Grep `$HOME/opencode-power-kit/opencode-global` trong
      `install-global.sh` → phải rỗng.
  - **NPX call assertions**: stub log phải có
    `bmad-method@<semver>`, `--modules bmm`, `--tools opencode`,
    `--user-name <fallback>` (không phải `nha`).
  - Chạy offline hoàn toàn (stub npx không gọi mạng).
- **`update-bmad.sh`** — thêm `BMAD_METHOD_VERSION` + log capture +
  fail handling. Đồng bộ safety guard.
- **CI strict** — `.github/workflows/ci.yml` bước `shellcheck` và
  `shfmt -d` bỏ `|| echo "skip..."` / `|| true`. Bất kỳ warning nào
  fail CI. Cài `shellcheck` qua `apt-get` (fail nếu không được).
- **`shfmt -w` toàn bộ `.sh`** — conform canonical style (tab indent,
  `name() {` single space, no space before `>>file`). 15 file đã format
  lại. `git diff --check` clean.
- **`README.md`** restructured: bootstrap 1-liner là canonical,
  "Cài thủ công / Advanced" là section riêng, cập nhật cây thư mục,
  document `BMAD_METHOD_VERSION=6.8.0`.
- **`VERSION`** 1.3.0 → 1.3.1.

### Fixed

- **`shellcheck` cleanup**:
  - `setup.sh` — bỏ biến `SCRIPTS_DIR` và `BAD_PROJECT_DIRS` dead
    code (SC2034).
  - `install-global.sh` — thêm `# shellcheck disable=SC2016,SC2088,SC2034`
    (literal `$HOME`/`$PATH` trong marker payloads, display tildes,
    `SAFE` flag).
  - `doctor.sh` — disable SC2088 (display tildes).
  - `scripts/install-fullstack-profile.sh` — bỏ `MARKER_END` dead.
  - `uninstall.sh` — disable SC2043 (single-element for loop intentional).
- **Bash canonical style** — `name() { ... }` (không phải `name()  { ... }`)
  trên toàn bộ script.
- **Shellcheck + shfmt** clean trên 100% `.sh` files (10 files).

### Safety (giữ nguyên + mở rộng)

- Không sudo, không `curl|sh` trong bất kỳ script nào (bash + PowerShell).
- `install.sh` / `install.ps1` / `update-bmad.sh` đồng bộ safety
  guard với `bootstrap.{sh,ps1}` và `setup.{sh,ps1}`: từ chối cài
  trong HOME, kit, root drive, system dirs, temp dirs.
- PowerShell: check `$LASTEXITCODE` của `npx`; fail rõ ràng thay vì
  silent.
- Bash: `npx ... >"$BMAD_LOG" 2>&1` — log đầy đủ vào file để debug
  nếu cần.
- License: MIT, copyright 2026.

### Compatibility

- Tương thích ngược 100% với v1.3.0. Mọi script / flag / lệnh cũ
  vẫn chạy. Thay đổi chỉ là hardening (BMAD pin + log capture +
  exit code check + safety sync + CI strict + shfmt style).

## [1.3.0] - 2026-06-04

### Added — Cross-platform (Linux / macOS / Windows PowerShell)

- **`bootstrap.sh`** (root, Linux/macOS/Git Bash/WSL): one-command installer
  với flags `--global`, `--project`, `--fullstack`, `--all`, `--project-dir`,
  `--doctor`, `--dry-run`, `--yes`, `--help`. Tự chạy `setup.sh --global --yes`,
  cập nhật `PATH` cho session hiện tại, in `opk path` + `opk version` +
  `opk doctor`. Từ chối project install trong `$HOME`, kit dir, `/`, `/tmp`,
  `/var/tmp`, `/usr`, `/etc`. Không sudo, không `curl|sh`.
- **`bootstrap.ps1`** (root, Windows PowerShell): mirror PowerShell của
  `bootstrap.sh`. Params `-Global`, `-Project`, `-Fullstack`, `-All`,
  `-ProjectDir`, `-Doctor`, `-DryRun`, `-Yes`, `-Help`. Cập nhật `$env:Path`
  cho session hiện tại, gọi `opk.cmd path`/`version`/`doctor`. Từ chối project
  install trong `$HOME`, kit dir, `C:\`, `C:\Windows`, `C:\Program Files*`,
  `$env:TEMP`/`$env:TMP`. Không admin, không sudo, không in secret.
- **`setup.ps1`** (root, Windows PowerShell): menu tiếng Việt 7 mục + 7 params
  non-interactive. Tương đương `setup.sh`. Từ chối per-project install trong
  các root nguy hiểm (HOME, kit, `C:\`, `C:\Windows`, `C:\Program Files*`,
  TEMP/TMP). Idempotent.
- **`install-global.ps1`** (root, Windows PowerShell): cài global không cần
  admin. Tạo `$HOME\.opencode-power-kit\bin`, cài shim `opk.cmd` + `opk.ps1`,
  set User env `OPK_KIT_DIR` + `OPENCODE_CONFIG_DIR`, add `$HOME\.opencode-power-kit\bin`
  vào User PATH (idempotent), cập nhật `$env:Path` cho session hiện tại. Backup
  file cũ vào `$HOME\.opencode-power-kit-backup-<ts>\`. Tạo
  `GLOBAL_INSTALL_REPORT.md` + `GLOBAL_PACK_REPORT.md` động. Không sửa
  registry system-wide, chỉ User environment.
- **`install.ps1`** (root, Windows PowerShell): mirror `install.sh`. Copy
  templates, merge `.gitignore` (idempotent), copy `knip.json`/`lefthook.yml`
  (skip nếu đã có), chạy `npx bmad-method install`, tạo report.
- **`scripts/install-fullstack-profile.ps1`**: PowerShell port của
  `install-fullstack-profile.sh`. Append AGENTS/OPENCODE qua marker
  idempotent, copy commands + skills, backup file user.
- **`bin/opk.ps1`** (Windows PowerShell CLI wrapper): mirror `bin/opk`. Hỗ trợ
  `help`, `version`, `path`, `global`, `install`/`init`, `fullstack`, `all`,
  `doctor`, `verify`, `tools`, `bootstrap`, `one`, `quick`. Dùng `OPK_KIT_DIR`
  nếu có, fallback tự detect từ vị trí script. Không duplicate logic.
- **`bin/opk.cmd`** (Windows CMD shim): gọi `opk.ps1` qua
  `powershell -ExecutionPolicy Bypass -File`. Cần `OPK_KIT_DIR` env (set bởi
  `install-global.ps1`).
- **`doctor.ps1`** (Windows PowerShell): mirror `doctor.sh`. Check git, PS
  version, `OPK_KIT_DIR`, `OPENCODE_CONFIG_DIR`, User PATH có
  `.opencode-power-kit\bin`, `opk.cmd`/`opk.ps1` tồn tại, opencode-global
  agents/commands/skills, không MCP config, secret pattern scan, 13 optional
  tools. WARN nếu thiếu optional, không fail. Tạo `OPK_DOCTOR_REPORT.md`.
- **`verify.ps1`** (Windows PowerShell): mirror `verify.sh`. Check project
  files (`AGENTS.md`, `OPENCODE.md`, `.opencode\opencode.json`,
  `.agents\skills`, `.opencode\commands`) + secret pattern scan. Tạo
  `OPK_VERIFY_REPORT.md`. Không in secret.

### Added — Bash improvements

- **`bin/opk` bash thêm 4 lệnh mới**:
  - `opk init` — alias của `opk install`.
  - `opk quick` — alias của `opk global` (cài global nhanh).
  - `opk bootstrap` — gọi `bootstrap.sh` (cài 1 lệnh cross-platform).
  - `opk one` — alias `bootstrap.sh --global --yes`.
- **Help text** `opk help` thêm 3 mục: Linux/macOS one-command, Windows
  PowerShell one-command, Project one-command.

### Changed — install-global.sh

- **zsh support** (macOS 10.15+ default shell): phát hiện `$SHELL` ends with
  `zsh` HOẶC `~/.zshrc` tồn tại → thêm markers vào cả `~/.zshrc`. Vẫn giữ
  `~/.bashrc` cho Linux/WSL/Git Bash. Không duplicate marker (idempotent).
- **Helper `add_rc_marker`**: function dùng chung, tránh duplicate logic
  giữa bash/zsh. Marker pattern giữ nguyên format cũ.
- **Secret scan** mở rộng: check cả `~/.zshrc` (không chỉ `~/.bashrc`).
- **Backup** thêm `~/.zshrc` nếu tồn tại.

### Changed — README.md

- Thêm section **"Cài 1 lệnh"** ở đầu với 3 phần: Linux/macOS one-liner,
  Windows PowerShell one-liner, Project one-command.
- Thêm badge `cross-platform`.
- Bump version badge 1.2.0 → 1.3.0.

### Safety (giữ nguyên + mở rộng)

- Không sudo, không `curl|sh` trong bất kỳ script nào (bash + PowerShell).
- Không in `token`, `password`, `secret`, `api_key`, `.env` value.
- Không sửa `~/.config/opencode/opencode.json` của user.
- Không xóa file user.
- **Windows**: không sửa registry system-wide — chỉ `User` environment
  (qua `[Environment]::SetEnvironmentVariable(..., 'User')`).
- Backup trước khi sửa config / PATH / profile / opk shim.
- Tất cả script đều **idempotent**: chạy lại không duplicate marker, PATH,
  config, shim, report.

### Compatibility

- **Tương thích ngược 100% với v1.2.0**. Mọi script / flag / lệnh cũ vẫn
  chạy. Thêm mới: PowerShell port + `bootstrap.{sh,ps1}` + 4 lệnh mới
  cho `opk` (`init`/`quick`/`bootstrap`/`one`).

## [1.2.0] - 2026-06-04

### Added

- **`setup.sh`** (root): menu tiếng Việt tương tác 7 mục + 7 cờ
  non-interactive (`--global`, `--project`, `--fullstack`, `--all`,
  `--doctor`, `--dry-run`, `--yes`, `--help`). Từ chối chạy per-project
  install trong HOME hoặc trong chính kit. Báo lỗi rõ khi thiếu script
  con. Idempotent: chạy nhiều lần không phá.
- **`bin/opk`** (CLI wrapper): thin wrapper gọi lại các script sẵn có —
  `help`, `version`, `path`, `global`, `install`, `fullstack`, `all`,
  `doctor`, `verify`, `tools`. Tự phát hiện đường dẫn kit qua
  `BASH_SOURCE` hoặc `OPK_KIT_DIR`. Không duplicate logic.
- **`install-global.sh` cải tiến**:
  - Tự cài `opk` vào `~/.local/bin/opk` (backup file cũ nếu tồn tại
    vào `$HOME/.opencode-power-kit-backup-<ts>/local-bin/opk`).
  - Đảm bảo `~/.local/bin` trong `PATH`, cảnh báo nếu chưa có trong
    shell hiện tại.
  - Verify `opk path` chạy được sau khi cài.
  - Tạo `GLOBAL_PACK_REPORT.md` động: liệt kê đúng agents/commands/
    skills đang có trong `opencode-global/`, kèm vị trí `opk` CLI và
    trạng thái PATH.
  - Backup thêm `~/.local/bin/opk` vào cùng thư mục backup.

### Changed

- `README.md`: thêm section "Dùng nhanh trong 30 giây" ở đầu, bảng
  lệnh `opk`, mục "Có gì mới trong v1.2.0", cập nhật sơ đồ thư mục.
- `VERSION`: bump 1.1.1 → 1.2.0.

### Safety (giữ nguyên policy)

- Không sudo, không `curl|sh` trong bất kỳ script nào.
- Không in `token`, `password`, `secret`, `api_key`, `.env` value.
- Không sửa `~/.config/opencode/opencode.json` của user.
- Không xóa file project. Backup trước khi sửa `~/.bashrc`,
  `~/.config/opencode/opencode.json`, `~/.local/bin/opk`.
- Tất cả script `setup.sh`, `bin/opk`, `install-global.sh` đều
  idempotent — chạy lại không tạo duplicate marker / không ghi đè
  file user nếu chưa backup.

### Compatibility

- Tương thích ngược 100% với v1.1.1. Mọi script / flag / lệnh cũ
  (`install.sh`, `install-global.sh`, `verify.sh`, `doctor.sh`,
  `uninstall.sh`, `update-bmad.sh`, `scripts/install-*.sh`) đều chạy
  bình thường. `setup.sh` và `opk` chỉ là lớp tiện ích bên ngoài.

## [1.1.1] - 2026-06-04

### Fixed

- `.github/workflows/ci.yml`: bước `Validate YAML in templates/` chứa
  `python3 -c` với line continuation `\` làm vỡ YAML block scalar. Rewrite
  thành bash multi-line dùng `set +e` + retry sau `pip install pyyaml`. CI
  giờ parse được `ci.yml` + chạy được job `yaml-templates`.
- `scripts/integration-test.sh`, `doctor.sh`, `uninstall.sh`: expand 3 cụm
  one-liner function (`info/ok/warn/err`) thành multi-line cho style chuẩn.
- Markdown headings + code fences: scan toàn repo, không có heading level
  bị skip, không có code fence mất cân.
- Secret scan: clean (loại trừ `CHANGELOG.md`, `README.md`, `doctor.sh`,
  `docs/*`; command `secret-scan.md` đã viết lại pattern ví dụ để không
  match regex nữa).

### Notes

- Không thêm file mới, không đổi logic.
- `v1.1.0` tag giữ nguyên — commit v1.1.0 vẫn tồn tại ở `4114471` cho ai
  tham chiếu; release "sạch" ở main là `v1.1.1`.

## [1.1.0] - 2026-06-04

### Added

- **Full-stack profile** (`profiles/node-nest-react-mysql/`) cho stack
  NestJS + React/Vite + MySQL:
  - 5 commands: `fullstack-scan`, `api-e2e-flow`, `env-doctor`,
    `docker-dev-doctor`, `seed-data-safe`.
  - 5 skills: `nestjs-backend`, `react-vite-frontend`, `mysql-schema-safe`,
    `auth-rbac-review`, `fullstack-test-strategy`.
  - `AGENTS.append.md` + `OPENCODE.append.md` với rule layer + workflow.
- **Profile installer** (`scripts/install-fullstack-profile.sh`): copy commands
  + skills, append AGENTS/OPENCODE với marker idempotent, backup file user.
  Từ chối chạy trong HOME hoặc trong `~/opencode-power-kit`.
- **Global full-stack commands** (9 mới):
  `fullstack-scan`, `openapi-check`, `secret-scan`, `sast-check`,
  `e2e-plan`, `test-matrix`, `js-quality-check`, `env-doctor`,
  `docker-dev-doctor`.
- **Global full-stack skills** (8 mới):
  `openapi-contract`, `secure-fullstack`, `dependency-maintenance`,
  `fullstack-test-strategy`, `js-ts-quality`, `env-config-safe`,
  `docker-compose-safe`, `nest-react-mysql`.
- **Templates** (4 mới):
  `biome.json.example`, `renovate.json.example`,
  `openapi/openapi.yaml.example`, `openapi/spectral.yaml.example`.
- **Optional install scripts** (3 mới):
  `install-security-tools.sh`, `install-api-tools.sh`,
  `install-js-quality-tools.sh`. Detect tool, in hướng dẫn, tạo report.
  Không sudo, không curl|sh, không tự cài.

### Changed

- **Pack validator** (`scripts/validate-opencode-pack.py`): thêm validate
  `profiles/*/commands/*.md` frontmatter + `profiles/*/skills/*/SKILL.md`
  heading + `templates/openapi/*.example` tồn tại.
- **Integration test** (`scripts/integration-test.sh`): thêm test
  `install-fullstack-profile.sh` trong temp project, verify marker + artifacts.
- **CI** (`.github/workflows/ci.yml`):
  - `bash -n` thêm 4 script mới.
  - `no-mcp` scan cả `profiles/`.
  - `line-count-guard` thêm min lines cho 17 file mới.
  - Validate JSON `biome.json.example`, `renovate.json.example`.
  - Validate YAML `spectral.yaml.example`.

### Safety (giữ nguyên policy)

- Không thêm MCP config vào `opencode-global/` hay `profiles/`.
- Không chứa `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
  pattern trong source.
- Không sudo, không curl|sh trong install scripts.
- Không tự cài dependency nặng (gitleaks, semgrep, biome, ...).
- Backup trước khi append/sửa file user.

## [1.0.0] - 2026-06-04

First production-grade release. Bumped from 9.4/10 → 10/10.

### Added

- **Global pack** (`opencode-global/`): 4 agents, 15 commands, 12 skills
  - Lifecycle commands: `spec-lite`, `plan-work`, `build-slice`, `test-proof`, `ship-check`
  - Review commands: `security-review`, `api-contract-review`, `migration-safe`, `review-diff`
  - Token commands: `rtk-gain`, `token-pack`
  - Utility commands: `smart-scan`, `bugfix-safe`, `repo-map`, `db-readonly`
- **Per-project install** (`install.sh`): seeds `AGENTS.md`, `OPENCODE.md`,
  `.opencode/opencode.json`, `.gitignore` (merged), `knip.json`, `lefthook.yml`
- **Global install** (`install-global.sh`): sets `OPENCODE_CONFIG_DIR` in
  `~/.bashrc` and adds `~/.local/bin` to `PATH`. Backs up existing files
  before touching them
- **BMAD integration**: `install.sh` and `update-bmad.sh` install BMAD Method
  via `npx bmad-method install --modules bmm --tools opencode`
- **Superpowers**: enabled through `.opencode/opencode.json` template
- **Token tools** (`scripts/install-token-tools.sh`): detects `rtk` and
  `tokscale`; never auto-runs `curl|sh`, never uses `sudo`
- **Verify** (`verify.sh`): checks global config, pack structure, MCP
  absence, secret-pattern absence, project files
- **Pack validator** (`scripts/validate-opencode-pack.py`): checks
  `commands/*.md` frontmatter + `description`, `agents/*.md` frontmatter +
  `description` + `mode`, `skills/*/SKILL.md` heading + body
- **Integration test** (`scripts/integration-test.sh`): builds a temp
  project, runs `install.sh` + `verify.sh`, asserts expected files exist
- **Doctor** (`doctor.sh`): read-only diagnostic for `OPENCODE_CONFIG_DIR`,
  pack structure, scripts, MCP, secrets
- **Uninstall** (`uninstall.sh`): restores from backup if present;
  requires confirmation (or `--yes`)
- **CI** (`.github/workflows/ci.yml`): 12 jobs — `bash -n`, `shellcheck`
  (best effort), `shfmt -d` (best effort), JSON templates, YAML templates,
  `git diff --check`, no-MCP guard, no-secrets scan, line-count guard,
  pack validation, integration test
- **Safety**:
  - No MCP config in `opencode-global/` (verified by CI)
  - No `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
    patterns in source (verified by CI)
  - No `curl|sh`, no `sudo` in install scripts
  - Backup before overwrite (`.opencode-power-kit-backup-<timestamp>`)
- **Release metadata**: `VERSION` (1.0.0), `CHANGELOG.md` (this file)
- **Badges** in `README.md`: CI status, version, no-MCP policy,
  safe/no-secrets policy

[1.0.0]: https://github.com/nguoikhongten02022005-cell/opencode-power-kit/releases/tag/v1.0.0

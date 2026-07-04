# ============================================================================
# OpenCode Power Kit - opk.ps1
# CLI wrapper cho Windows. Goi cac script co san, khong duplicate logic.
# Dung OPK_KIT_DIR neu co, neu khong tu detect tu vi tri script.
#
# Usage:
#   opk help
#   opk version
#   opk path
#   opk global
#   opk install / opk init
#   opk fullstack
#   opk all
#   opk doctor
#   opk verify
#   opk tools
#   opk bootstrap
#   opk one         # alias: bootstrap.ps1 -All -ProjectDir (Get-Location) -Yes (all-in-one)
#   opk go          # alias: opk one
#   opk up          # update kit + project (One Command Update)
#   opk update      # alias: opk up
#   opk upgrade     # alias: opk up
#   opk clean       # cleanup project artifacts (dry-run mặc định)
#   opk up --clean  # update + cleanup apply
#   opk markitdown install   # cai MarkItDown (opt-in)
#   opk markitdown status    # kiem tra trang thai
#   opk md-convert <in> <out> [--force]   # convert file sang Markdown
#   opk doc-to-md <in> <out> [--force]    # alias: md-convert
# ============================================================================
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = 'help',
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir ---
if ($env:OPK_KIT_DIR -and (Test-Path (Join-Path $env:OPK_KIT_DIR 'install-global.ps1'))) {
    $KitDir = (Resolve-Path $env:OPK_KIT_DIR).Path
} else {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $KitDir    = (Resolve-Path $ScriptDir\..).Path
}

# Sanity check
if (-not (Test-Path (Join-Path $KitDir 'install-global.ps1'))) {
    Write-Host "opk: khong tim thay opencode-power-kit tai $KitDir" -ForegroundColor Red
    Write-Host "      Co the ban dang chay tu ngoai kit. Hay 'cd C:\path\to\kit' roi chay lai," -ForegroundColor Red
    Write-Host "      hoac set `$env:OPK_KIT_DIR='C:\path\to\kit'" -ForegroundColor Red
    exit 1
}

$VersionFile = Join-Path $KitDir 'VERSION'
$Version = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { '?' }

# --- Helpers ---
function Require-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "opk: thieu file: $Path" -ForegroundColor Red
        exit 1
    }
}

# --- Bad project-dir detection ---
$PwdNow = (Get-Location).Path
$Home   = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

function Test-BadProjectDir {
    param([string]$Path)
    if (-not $Path) { return $true }
    $p = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path
    if (-not $p) { $p = $Path }
    $p = $p.TrimEnd('\','/')

    $homeTrim = $Home.TrimEnd('\','/')
    if ($p -ieq $homeTrim) { return $true }

    $kitTrim = $KitDir.TrimEnd('\','/')
    if ($p -ieq $kitTrim) { return $true }
    if ($p.StartsWith("$kitTrim\", [System.StringComparison]::OrdinalIgnoreCase)) {
        # Whitelist: .tmp / .test inside kit are scratch dirs (integration-test)
        if ($p -ieq "$kitTrim\.tmp" -or $p.StartsWith("$kitTrim\.tmp\", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($p -ieq "$kitTrim\.test" -or $p.StartsWith("$kitTrim\.test\", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        return $true
    }

    if ($p -ieq 'C:\') { return $true }
    if ($p -ieq 'C:\Windows' -or $p.StartsWith('C:\Windows\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($p -ieq 'C:\Program Files'  -or $p.StartsWith('C:\Program Files\',  [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($p -ieq 'C:\Program Files (x86)' -or $p.StartsWith('C:\Program Files (x86)\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }

    $temp = $env:TEMP
    $tmp  = $env:TMP
    if ($temp) {
        $t = $temp.TrimEnd('\','/')
        if ($p -ieq $t) { return $true }
        if ($p.StartsWith("$t\", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    if ($tmp -and $tmp -ne $temp) {
        $t = $tmp.TrimEnd('\','/')
        if ($p -ieq $t) { return $true }
        if ($p.StartsWith("$t\", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Show-BlockedDir {
    param([string]$Path)
    Write-Host "" -ForegroundColor Red
    Write-Host "opk: TU CHOI cai vao: $Path" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Ly do: project install KHONG chay trong:" -ForegroundColor Red
    Write-Host "  - `$HOME                    ($Home)" -ForegroundColor Red
    Write-Host "  - chinh repo kit           ($KitDir)" -ForegroundColor Red
    Write-Host "  - C:\, C:\Windows, C:\Program Files*" -ForegroundColor Red
    Write-Host "  - `$env:TEMP, `$env:TMP" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Cach lam dung:" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "  cd C:\path\to\your\project" -ForegroundColor Red
    Write-Host "  opk install" -ForegroundColor Red
    Write-Host "  opk fullstack" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
}

function Refuse-If-BadProjectDir {
    if (Test-BadProjectDir $PwdNow) {
        Show-BlockedDir $PwdNow
        Write-Host "opk: tu choi chay trong $PwdNow" -ForegroundColor Red
        exit 1
    }
}

# --- Subcommand dispatch ---
switch ($Command.ToLower()) {
    { @('help','--help','-h') -contains $_ } {
        Write-Host ""
        Write-Host "opk — OpenCode Power Kit CLI (v$Version)"
        Write-Host ""
        Write-Host "Cach dung nhanh:"
        Write-Host "  opk one         Cai ALL-IN-ONE: global + project + fullstack + verify (khuyen nghi) (= opk go)"
        Write-Host "  opk global      Cai global (commands/skills/agents + opk CLI)"
        Write-Host "  opk install     Cai vao project hien tai (can cd vao project) (= opk init)"
        Write-Host "  opk update-bmad Cap nhat BMAD Method cho project hien tai"
        Write-Host "  opk fullstack   Cai full-stack profile (Nest/React/MySQL)"
        Write-Host "  opk all         Cai tat ca: global + project + fullstack (+ verify neu o project an toan)"
        Write-Host "  opk doctor      Chan doan cau hinh (read-only)"
        Write-Host "  opk verify      Kiem tra project hien tai"
        Write-Host "  opk tools       Detect / huong dan cai rtk + tokscale"
        Write-Host "  opk path        In duong dan kit"
        Write-Host "  opk version     In version"
        Write-Host "  opk bootstrap   Chay bootstrap.ps1 (cai 1 lenh)"
        Write-Host "  opk go          Alias: opk one (all-in-one)"
        Write-Host "  opk quick       Alias: opk global"
        Write-Host "  opk init        Alias: opk install"
        Write-Host "  opk up          Update kit + project (One Command Update)"
        Write-Host "  opk update      Alias: opk up"
        Write-Host "  opk upgrade     Alias: opk up"
        Write-Host "  opk clean       Cleanup project artifacts (dry-run mac dinh)"
        Write-Host ""
        Write-Host "v1.6.6 — MarkItDown Document Tools (opt-in):"
        Write-Host "  opk markitdown install Cai Microsoft MarkItDown (pipx/npm)"
        Write-Host "  opk markitdown status   Kiem tra trang thai MarkItDown"
        Write-Host "  opk md-convert <in> <out> [--force]  Convert file sang Markdown"
        Write-Host "  opk doc-to-md <in> <out> [--force]   Alias: md-convert"
        Write-Host ""
        Write-Host "v1.6.7 — Supermemory Memory API (opt-in):"
        Write-Host "  opk supermemory install   Cai Supermemory (npm — dry-run + confirm)"
        Write-Host "  opk supermemory status    Kiem tra Supermemory da cai chua"
        Write-Host "  opk supermemory init      Init Supermemory (yeu cau da cai)"
        Write-Host "  opk supermemory init-help Xem upstream init --help (khong can cai)"
        Write-Host ""
        Write-Host "v1.7.0 — Taste Skill (optional, verify-gated):"
        Write-Host "  opk taste install          Cai Taste Skill (npx — dry-run + confirm)"
        Write-Host "  opk taste install --v1     Cai Taste Skill v1 (legacy)"
        Write-Host "  opk taste install --v2     Cai Taste Skill v2 (default)"
        Write-Host "  opk taste status           Kiem tra Taste Skill da cai chua"
        Write-Host "  opk taste doctor           Kiem tra runtime dependencies"
        Write-Host "  opk taste off              Go Taste Skill (an toan: move to .opk-trash/)"
        Write-Host "  opk update-taste           Refresh Taste Skill"
        Write-Host "  opk taste-status           Kiem tra nhanh (shortcut)"
        Write-Host ""
        Write-Host "v1.8.0 — ECC-lite (optional, based on Engineering Code Commandments):"
        Write-Host "  opk ecc audit     Audit codebase against ECC principles (read-only)"
        Write-Host "  opk ecc lite      Install ECC-lite components (agent + commands)"
        Write-Host "  opk ecc status    Check ECC-lite installation status"
        Write-Host "  opk ecc off       Remove ECC-lite components"
        Write-Host "  opk update-ecc    Refresh ECC-lite installation"
        Write-Host "  opk ec [...]      Alias: opk ecc"
        Write-Host "  opk e [...]       Alias: opk ecc"
        Write-Host ""
        Write-Host "v1.9.0 — Hermes-lite (optional, inspired by NousResearch Hermes Agent):"
        Write-Host "  opk hermes audit     Self-audit Hermes-lite components (read-only)"
        Write-Host "  opk hermes status    Check Hermes-lite installation status"
        Write-Host "  opk hermes capsule   Package learnings into capsule file"
        Write-Host "  opk hermes off       Remove Hermes-lite components"
        Write-Host ""
        Write-Host "v2.0.0 — Upstream Audit & Tooling:"
        Write-Host "  opk upstream audit         Scan repo for upstream refs (audit-upstreams.py)"
        Write-Host "  opk upstream audit --check CI mode (exit 1 if issues found)"
        Write-Host "  opk upstream audit --write Write docs/UPSTREAM_AUDIT.md"
        Write-Host "  opk upstream doctor        Run audit + validator + check docs"
        Write-Host "  opk superpowers status     Check superpowers plugin status"
        Write-Host "  opk superpowers reset-cache Clear superpowers cache (manual instructions)"
        Write-Host "  opk superpowers reset-cache -Yes  Auto-clear (safe: move to .opk-trash/)"
        Write-Host "  opk superpowers doctor     Full superpowers diagnosis + Windows fallback"
        Write-Host "  opk bmad status            Show BMAD version pin + runtime check"
        Write-Host "  opk bmad update -Stable    Update BMAD (pinned: 6.9.0)"
        Write-Host "  opk bmad update -Next      Update BMAD (experimental)"
        Write-Host "  opk bmad update -Version X.Y.Z  Pin BMAD to specific version"
        Write-Host "  opk tooling doctor         Detect + suggest install for dev tools"
        Write-Host ""
        Write-Host "v1.6.4 — Mode & Safety:"
        Write-Host "  opk mode show   Xem che do Power/Safe hien tai"
        Write-Host "  opk mode power  Chuyen sang Power Mode (permission: allow)"
        Write-Host "  opk mode safe   Chuyen sang Safe Mode (permission object)"
        Write-Host "  opk safety-plugin install  Cai safety plugin guard"
        Write-Host "  opk safety-plugin status   Kiem tra trang thai safety plugin"
        Write-Host ""
        Write-Host "Flags chung (forward cho sub-script):"
        Write-Host "  -Yes   skip confirm"
        Write-Host "  -Help  in tro giup cua sub-script"
        Write-Host ""
        Write-Host "Vi du:"
        Write-Host "  opk one                # ← khuyen nghi: cai all-in-one (cd vao project truoc)"
        Write-Host "  opk go                 # tuong tu opk one"
        Write-Host "  opk global             # chi cai global"
        Write-Host "  opk install -Yes       # chi cai vao project hien tai"
        Write-Host "  opk fullstack          # chi cai full-stack profile"
        Write-Host "  opk doctor             # chan doan"
        Write-Host "  opk version"
        Write-Host "  opk bootstrap -All -Yes"
        Write-Host ""
        Write-Host "All-in-one one-command (Windows PowerShell) — tu clone/pull kit roi cai:"
        Write-Host "  powershell -ExecutionPolicy Bypass -Command `"`$Project=(Get-Location).Path; `$KIT=Join-Path `$HOME 'opencode-power-kit'; if (Test-Path (Join-Path `$KIT '.git')) { & git -C `$KIT pull --ff-only } else { & git clone https://github.com/laivannha0202/opencode-power-kit.git `$KIT }; & (Join-Path `$KIT 'bootstrap.ps1') -All -ProjectDir `$Project -Yes; & (Join-Path `$KIT 'verify.ps1')`""
        Write-Host ""
        Write-Host "Project one-command (Windows):"
        Write-Host "  cd C:\path\to\project; opk install"
        Write-Host ""
        Write-Host "Kit hien tai: $KitDir"
        Write-Host ""
    }

    { @('version','--version','-v') -contains $_ } {
        Write-Host "opk $Version"
    }

    'path' {
        Write-Host $KitDir
    }

    'global' {
        Require-File (Join-Path $KitDir 'install-global.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install-global.ps1') @Args
    }

    { @('install','project','init') -contains $_ } {
        Refuse-If-BadProjectDir
        Require-File (Join-Path $KitDir 'install.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install.ps1') @Args
    }

    'update-bmad' {
        Refuse-If-BadProjectDir
        Require-File (Join-Path $KitDir 'update-bmad.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'update-bmad.ps1') @Args
    }

    'fullstack' {
        Refuse-If-BadProjectDir
        Require-File (Join-Path $KitDir 'scripts\install-fullstack-profile.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'scripts\install-fullstack-profile.ps1') @Args
    }

    'all' {
        Require-File (Join-Path $KitDir 'install-global.ps1')
        Require-File (Join-Path $KitDir 'install.ps1')
        Require-File (Join-Path $KitDir 'scripts\install-fullstack-profile.ps1')
        Require-File (Join-Path $KitDir 'verify.ps1')
        Write-Host "opk: [1/4] install-global.ps1"
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install-global.ps1') -Yes
        if (Test-BadProjectDir $PwdNow) {
            Write-Host "opk: BO QUA install.ps1 + fullstack + verify (pwd = $PwdNow la root nguy hiem)." -ForegroundColor Yellow
            Write-Host "opk:   HOME / kit / C:\ / C:\Windows / C:\Program Files* / TEMP / TMP deu bi tu choi." -ForegroundColor Yellow
            Write-Host "opk:   cd vao project that, roi chay: opk install && opk fullstack && opk verify" -ForegroundColor Yellow
        } else {
            Write-Host "opk: [2/4] install.ps1 trong $PwdNow"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install.ps1') -Yes
            Write-Host "opk: [3/4] install-fullstack-profile.ps1 trong $PwdNow"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'scripts\install-fullstack-profile.ps1') -Yes
            Write-Host "opk: [4/4] verify.ps1 trong $PwdNow"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'verify.ps1')
        }
    }

    'doctor' {
        Require-File (Join-Path $KitDir 'doctor.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'doctor.ps1') @Args
    }

    'verify' {
        Require-File (Join-Path $KitDir 'verify.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'verify.ps1') @Args
    }

    'tools' {
        Require-File (Join-Path $KitDir 'scripts\install-token-tools.ps1')
        if (-not (Test-Path (Join-Path $KitDir 'scripts\install-token-tools.ps1'))) {
            Write-Host "opk: tools chua co phien ban PowerShell. Hay chay 'bash $KitDir/scripts/install-token-tools.sh' trong WSL/Git Bash." -ForegroundColor Yellow
            exit 1
        }
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'scripts\install-token-tools.ps1') @Args
    }

    'bootstrap' {
        Require-File (Join-Path $KitDir 'bootstrap.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'bootstrap.ps1') @Args
    }

    'one' {
        Require-File (Join-Path $KitDir 'bootstrap.ps1')
        $oneProjectDir = if ($env:OPK_PROJECT_DIR) { $env:OPK_PROJECT_DIR } else { (Get-Location).Path }
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'bootstrap.ps1') -All -ProjectDir $oneProjectDir -Yes @Args
    }

    'go' {
        Require-File (Join-Path $KitDir 'bootstrap.ps1')
        $oneProjectDir = if ($env:OPK_PROJECT_DIR) { $env:OPK_PROJECT_DIR } else { (Get-Location).Path }
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'bootstrap.ps1') -All -ProjectDir $oneProjectDir -Yes @Args
    }

    'quick' {
        Require-File (Join-Path $KitDir 'install-global.ps1')
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install-global.ps1') -Yes
    }

    # ─── v1.6.5 One Command Update & Cleanup ─────────────────────────
    { @('up','update','upgrade') -contains $_ } {
        $doClean = $false
        $cleanArgs = @()
        foreach ($a in $Args) {
            switch -Wildcard ($a.ToLower()) {
                '--clean'   { $doClean = $true }
                '--yes'     { $cleanArgs += '-Yes' }
                '--help'    { Write-Host "opk up [--clean] [--yes]"; exit 0 }
                default     { Write-Host "opk up: flag khong hop le: $a" -ForegroundColor Red; exit 1 }
            }
        }

        # --- Print diagnostic info ---
        Write-Host "opk: KIT_DIR    = $KitDir"
        Write-Host "opk: opk path   = $(Join-Path $KitDir 'bin\opk.ps1')"
        Write-Host "opk: version    = $Version"
        try {
            $head = git -C $KitDir rev-parse --short HEAD 2>$null
            if ($head) { Write-Host "opk: git HEAD   = $head" }
        } catch {}
        Write-Host ""
        Write-Host "opk: VERSION    = $Version"
        Write-Host ""

        # --- Git pull ---
        $gitDir = Join-Path $KitDir '.git'
        if (Test-Path $gitDir -PathType Container) {
            # Check working tree
            $dirty = git -C $KitDir diff --quiet 2>$null
            if (-not $?) {
                Write-Host "opk: ERROR — working tree dirty, cannot pull --ff-only" -ForegroundColor Red
                Write-Host "opk: Dirty files:" -ForegroundColor Red
                git -C $KitDir status --short
                Write-Host ""
                Write-Host "opk: Hay commit thay doi truoc, hoac dung: opk clean" -ForegroundColor Red
                exit 1
            }
            Write-Host "opk: git pull --ff-only trong $KitDir"
            git -C $KitDir pull --ff-only
            if (-not $?) {
                Write-Host "opk: ERROR — git pull failed" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "opk: $KitDir khong phai git repo, bo qua pull"
        }
        Write-Host ""

        # --- Run install-global.ps1 -Yes ---
        $installGlobalPs1 = Join-Path $KitDir 'install-global.ps1'
        if (Test-Path $installGlobalPs1) {
            Write-Host "opk: install-global.ps1 -Yes"
            & powershell -ExecutionPolicy Bypass -File $installGlobalPs1 -Yes
        }
        Write-Host ""

        # --- Print version after update ---
        $newVersion = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { '?' }
        Write-Host "opk: version sau update = $newVersion"

        # --- Check if current dir is safe project ---
        $PwdNow = (Get-Location).Path
        if (Test-BadProjectDir $PwdNow) {
            Write-Host ""
            Write-Host "opk: pwd = $PwdNow la root nguy hiem — bo qua project install." -ForegroundColor Yellow
            Write-Host "opk:   De update project, cd vao project that roi chay:"
            Write-Host "opk:     opk up"
            Write-Host "opk:   Hoac tu chay tung buoc:"
            Write-Host "opk:     opk install -Yes"
            Write-Host "opk:     opk fullstack -Yes"
            Write-Host "opk:     opk verify"
        } else {
            Write-Host ""
            Write-Host "opk: Project dir: $PwdNow"
            Write-Host "opk: [1/3] opk install -Yes"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install.ps1') -Yes
            Write-Host "opk: [2/3] opk fullstack -Yes"
            $fullstackPs1 = Join-Path $KitDir 'scripts\install-fullstack-profile.ps1'
            if (Test-Path $fullstackPs1) {
                & powershell -ExecutionPolicy Bypass -File $fullstackPs1 -Yes
            } else {
                Write-Host "opk:   skip: scripts\install-fullstack-profile.ps1 khong ton tai"
            }
            Write-Host "opk: [3/3] opk verify"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'verify.ps1')
        }
        Write-Host ""

        # --- Cleanup ---
        $cleanupScript = Join-Path $KitDir 'scripts\cleanup-agent-artifacts.sh'
        if (Test-Path $cleanupScript) {
            if ($doClean) {
                Write-Host "opk: cleanup --apply"
                & bash $cleanupScript --apply
            } else {
                Write-Host "opk: cleanup dry-run (dung --clean de apply)"
                & bash $cleanupScript --dry-run
            }
        } else {
            Write-Host "opk: skip cleanup (scripts\cleanup-agent-artifacts.sh khong ton tai)"
        }
        Write-Host ""
        Write-Host "opk: ✅ Update hoan tat."
    }

    'clean' {
        $cleanupScript = Join-Path $KitDir 'scripts\cleanup-agent-artifacts.sh'
        if (-not (Test-Path $cleanupScript)) {
            Write-Host "opk: scripts\cleanup-agent-artifacts.sh khong ton tai" -ForegroundColor Red
            exit 1
        }
        $mode = '--dry-run'
        foreach ($a in $Args) {
            if ($a.ToLower() -eq '--apply') { $mode = '--apply' }
            if ($a.ToLower() -eq '--help')  { Write-Host "opk clean [--apply]"; exit 0 }
        }
        & bash $cleanupScript $mode
    }

    # ─── v1.6.4 Mode management (Power/Safe) ────────────────────────
    'mode' {
        $modeCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'show' }
        $modeArgs = if ($Args.Count -gt 1) { $Args[1..$($Args.Count-1)] } else { @() }

        switch ($modeCmd) {
            'show' {
                $projConfig = Join-Path $KitDir 'templates\opencode.json'
                if (Test-Path '.opencode\opencode.json') {
                    $projConfig = (Resolve-Path '.opencode\opencode.json').Path
                }
                Write-Host "opk: OpenCode Power Kit mode check"
                Write-Host ""
                Write-Host "Template: $(Join-Path $KitDir 'templates\opencode.json')"
                $projectFile = if (Test-Path '.opencode\opencode.json') { '.opencode\opencode.json' } else { '(none)' }
                Write-Host "Project:  $projectFile"
                Write-Host ""
                $configContent = Get-Content $projConfig -Raw
                if ($configContent -match '"permission":\s*"allow"') {
                    Write-Host "Current mode: POWER (permission: allow)" -ForegroundColor Green
                    Write-Host "  Agent tu dong chay tool, sua file, bash — khong hoi lai."
                } else {
                    Write-Host "Current mode: SAFE (permission object)" -ForegroundColor Yellow
                    Write-Host "  Agent hoi truoc khi write/edit/bash/task."
                }
            }
            'power' {
                $templateFile = Join-Path $KitDir 'templates\opencode.power.json'
                Require-File $templateFile
                $target = if (Test-Path '.opencode\opencode.json') { '.opencode\opencode.json' } else { Join-Path $KitDir 'templates\opencode.json' }
                $backup = "$target.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $target $backup
                Write-Host "opk: Backup -> $backup"
                Copy-Item $templateFile $target
                Write-Host "opk: ✅ Da chuyen sang POWER MODE (permission: allow)" -ForegroundColor Green
                Write-Host "opk:   Agent tu dong chay tool, sua file, bash — khong hoi lai."
                Write-Host "opk:   De quay lai: opk mode safe"
            }
            'safe' {
                $templateFile = Join-Path $KitDir 'templates\opencode.safe.json'
                Require-File $templateFile
                $target = if (Test-Path '.opencode\opencode.json') { '.opencode\opencode.json' } else { Join-Path $KitDir 'templates\opencode.json' }
                $backup = "$target.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $target $backup
                Write-Host "opk: Backup -> $backup"
                Copy-Item $templateFile $target
                Write-Host "opk: ✅ Da chuyen sang SAFE MODE (permission object)" -ForegroundColor Yellow
                Write-Host "opk:   Read/grep/glob/skill=allow, write/edit/bash/task=ask."
                Write-Host "opk:   Agent se hoi truoc khi sua file hoac chay lenh."
                Write-Host "opk:   De quay lai: opk mode power"
            }
            default {
                Write-Host "opk: mode: lenh khong hop le '$modeCmd'. Dung: show, power, safe" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v1.6.4 Safety plugin management ──────────────────────────
    'safety-plugin' {
        $pluginCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $pluginArgs = if ($Args.Count -gt 1) { $Args[1..$($Args.Count-1)] } else { @() }

        switch ($pluginCmd) {
            'install' {
                $installer = Join-Path $KitDir 'scripts\install-safety-plugin.sh'
                Require-File $installer
                Write-Host "opk: Cai safety plugin guard (can WSL/Git Bash hoac Linux/macOS)..."
                & bash $installer @pluginArgs
            }
            'status' {
                $pluginFile = '.opencode\plugins\opk-safety-guard.js'
                if (Test-Path $pluginFile) {
                    Write-Host "opk: ✅ Safety plugin guard da duoc cai dat." -ForegroundColor Green
                    Write-Host "   File: $pluginFile"
                } else {
                    $templateFile = Join-Path $KitDir 'templates\plugins\opk-safety-guard.js'
                    if (Test-Path $templateFile) {
                        Write-Host "opk: ⚠️ Safety plugin guard co san trong template nhung chua cai." -ForegroundColor Yellow
                        Write-Host "   Chay: opk safety-plugin install"
                    } else {
                        Write-Host "opk: ℹ️ Safety plugin guard chua duoc cai dat." -ForegroundColor Gray
                    }
                }
            }
            default {
                Write-Host "opk: safety-plugin: lenh khong hop le '$pluginCmd'. Dung: install, status" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v1.6.6 MarkItDown Document Tools (opt-in) ─────────────────
    'markitdown' {
        $mdCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $mdArgs = if ($Args.Count -gt 1) { $Args[1..$($Args.Count-1)] } else { @() }

        switch ($mdCmd) {
            'install' {
                $installer = Join-Path $KitDir 'scripts\install-markitdown.ps1'
                Require-File $installer
                & powershell -ExecutionPolicy Bypass -File $installer @mdArgs
            }
            'status' {
                $md = Get-Command markitdown -ErrorAction SilentlyContinue
                if ($md) {
                    Write-Host "opk: ✅ MarkItDown installed at $($md.Source)" -ForegroundColor Green
                    & $md.Source --help 2>&1 | Select-Object -First 3
                } else {
                    Write-Host "opk: ❌ MarkItDown not installed. Run: opk markitdown install" -ForegroundColor Yellow
                }
            }
            default {
                Write-Host "opk: markitdown: lenh khong hop le '$mdCmd'. Dung: install, status" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v2.0.0 Upstream Audit & Management ──────────────────────
    'upstream' {
        $upCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'audit' }
        $upArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($upCmd) {
            'audit' {
                $auditPy = Join-Path $KitDir 'scripts\audit-upstreams.py'
                Require-File $auditPy
                if ($upArgs.Count -gt 0 -and $upArgs[0] -eq '--check') {
                    & python3 $auditPy --check
                    exit $LASTEXITCODE
                } elseif ($upArgs.Count -gt 0 -and $upArgs[0] -eq '--write') {
                    $outfile = if ($upArgs.Count -gt 1) { $upArgs[1] } else { 'docs\UPSTREAM_AUDIT.md' }
                    & python3 $auditPy --write $outfile
                } else {
                    & python3 $auditPy
                }
            }
            'doctor' {
                Write-Host "opk: === Upstream Doctor ==="
                Write-Host ""
                $auditPy = Join-Path $KitDir 'scripts\audit-upstreams.py'
                if (Test-Path $auditPy) {
                    Write-Host "opk: [1/2] Running upstream audit..."
                    & python3 $auditPy --check
                    if ($LASTEXITCODE -eq 0) { Write-Host "opk: Audit check passed" -ForegroundColor Green }
                    else { Write-Host "opk: Audit check found issues" -ForegroundColor Yellow }
                    Write-Host ""
                }
                $validator = Join-Path $KitDir 'scripts\validate-opencode-pack.py'
                if (Test-Path $validator) {
                    Write-Host "opk: [2/2] Running pack validator..."
                    & python3 $validator
                    if ($LASTEXITCODE -eq 0) { Write-Host "opk: Validator passed" -ForegroundColor Green }
                    else { Write-Host "opk: Validator found issues" -ForegroundColor Yellow }
                    Write-Host ""
                }
                Write-Host "opk: Upstream docs:"
                foreach ($doc in @('UPSTREAM_AUDIT.md','UPSTREAM_UPDATE_POLICY.md','UPSTREAM_RISKS.md')) {
                    $docPath = Join-Path $KitDir "docs\$doc"
                    if (Test-Path $docPath) { Write-Host "opk:   docs/$doc" -ForegroundColor Green }
                    else { Write-Host "opk:   docs/$doc missing" -ForegroundColor Yellow }
                }
            }
            default {
                Write-Host "opk: upstream: lenh khong hop le '$upCmd'. Dung: audit, audit --check, doctor" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v2.0.0 Superpowers Status & Cache ──────────────────────────
    'superpowers' {
        $spCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $spArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($spCmd) {
            'status' {
                Write-Host "opk: === Superpowers Status ==="
                Write-Host ""
                $templateFile = Join-Path $KitDir 'templates\opencode.json'
                if ((Test-Path $templateFile) -and (Select-String -Path $templateFile -Pattern 'superpowers@git\+https://github.com/obra/superpowers.git' -Quiet)) {
                    Write-Host "opk: Template plugin reference found" -ForegroundColor Green
                } else {
                    Write-Host "opk: Template missing superpowers plugin reference" -ForegroundColor Yellow
                }
                $projConfig = $null
                if (Test-Path '.opencode\opencode.json') { $projConfig = '.opencode\opencode.json' }
                elseif (Test-Path 'opencode.json') { $projConfig = 'opencode.json' }
                if ($projConfig -and (Select-String -Path $projConfig -Pattern 'superpowers@git\+https://github.com/obra/superpowers.git' -Quiet)) {
                    Write-Host "opk: Project config ($projConfig) has superpowers plugin" -ForegroundColor Green
                } elseif ($projConfig) {
                    Write-Host "opk: Project config ($projConfig) missing superpowers plugin" -ForegroundColor Yellow
                } else {
                    Write-Host "opk: No project opencode.json found (using template defaults)" -ForegroundColor Gray
                }
                $oc = Get-Command opencode -ErrorAction SilentlyContinue
                if ($oc) { Write-Host "opk: opencode found: $($oc.Source)" -ForegroundColor Green }
                else { Write-Host "opk: opencode not found on PATH" -ForegroundColor Yellow }
                Write-Host ""
                Write-Host "opk: Superpowers is loaded at runtime by OpenCode plugin system."
            }
            'reset-cache' {
                Write-Host "opk: === Superpowers Cache Reset ==="
                Write-Host ""
                Write-Host "Superpowers cache is managed by OpenCode's plugin system."
                Write-Host "To reset the cache manually:"
                Write-Host ""
                Write-Host "  1. Find the OpenCode cache directory:"
                Write-Host "     ls ~/.cache/opencode/packages/"
                Write-Host ""
                Write-Host "  2. Remove the superpowers package cache:"
                Write-Host "     Remove-Item -Recurse ~/.cache/opencode/packages/superpowers*"
                Write-Host ""
                if ($spArgs.Count -gt 0 -and $spArgs[0] -eq '--yes') {
                    Write-Host "opk: --yes specified, attempting safe cache clear..."
                    $cacheDir = Join-Path $HOME '.cache\opencode\packages'
                    if (Test-Path $cacheDir) {
                        $trashDir = Join-Path $KitDir ".opk-trash\cache-reset-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                        New-Item -ItemType Directory -Path $trashDir -Force | Out-Null
                        Get-ChildItem -Path $cacheDir -Filter 'superpowers*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            Move-Item -Path $_.FullName -Destination $trashDir -Force
                            Write-Host "opk: Moved $($_.Name) -> $trashDir/"
                        }
                        Write-Host "opk: Cache cleared (moved to $trashDir)" -ForegroundColor Green
                    } else {
                        Write-Host "opk: No OpenCode cache directory found" -ForegroundColor Yellow
                    }
                }
            }
            'doctor' {
                Write-Host "opk: === Superpowers Doctor ==="
                Write-Host ""
                & $PSCommandPath superpowers status
                Write-Host ""
                Write-Host "opk: Windows fallback (if git+https fails):"
                Write-Host "  1. Use WSL or Git Bash"
                Write-Host "  2. Or set plugin path manually in opencode.json"
                Write-Host "  3. Or install via npm: npm install -g superpowers"
            }
            default {
                Write-Host "opk: superpowers: lenh khong hop le '$spCmd'. Dung: status, reset-cache, doctor" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v2.0.0 BMAD Method Management ──────────────────────────────
    'bmad' {
        $bmadCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $bmadArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($bmadCmd) {
            'status' {
                Write-Host "opk: === BMAD Method Status ==="
                Write-Host ""
                $bmadVersion = if ($env:BMAD_METHOD_VERSION) { $env:BMAD_METHOD_VERSION } else { '6.9.0' }
                Write-Host "opk: BMAD_METHOD_VERSION = $bmadVersion"
                Write-Host "opk: (override via: `$env:BMAD_METHOD_VERSION='x.y.z')"
                Write-Host ""
                if (Test-Path '.bmad') {
                    Write-Host "opk: .bmad/ directory found in project" -ForegroundColor Green
                    Get-ChildItem '.bmad' | Select-Object -First 5 | ForEach-Object { Write-Host "  $($_.Name)" }
                } else {
                    Write-Host "opk: No .bmad/ directory in current project" -ForegroundColor Gray
                }
                Write-Host ""
                Write-Host "opk: Runtime check:"
                foreach ($tool in @('node','npm','npx')) {
                    $tc = Get-Command $tool -ErrorAction SilentlyContinue
                    if ($tc) { Write-Host "opk:   $tool $($tc.Source)" -ForegroundColor Green }
                    else { Write-Host "opk:   $tool not found" -ForegroundColor Yellow }
                }
                Write-Host ""
                Write-Host "opk: BMAD docs: https://github.com/bmad-code-org/BMAD-METHOD"
            }
            'update' {
                $updateFlag = if ($bmadArgs.Count -gt 0) { $bmadArgs[0] } else { '--stable' }
                $script = Join-Path $KitDir 'update-bmad.ps1'
                Require-File $script
                switch ($updateFlag) {
                    '--stable' {
                        Write-Host "opk: Updating BMAD Method (stable pin: 6.9.0)..."
                        $env:BMAD_METHOD_VERSION = '6.9.0'
                        & powershell -ExecutionPolicy Bypass -File $script
                    }
                    '--next' {
                        Write-Host "opk: Updating BMAD Method (next/experimental)..."
                        $env:BMAD_METHOD_VERSION = 'next'
                        & powershell -ExecutionPolicy Bypass -File $script
                    }
                    '--version' {
                        $ver = if ($bmadArgs.Count -gt 1) { $bmadArgs[1] } else { '' }
                        if (-not $ver) {
                            Write-Host "opk: bmad update --version requires a version" -ForegroundColor Red
                            exit 1
                        }
                        Write-Host "opk: Updating BMAD Method (pinned: $ver)..."
                        $env:BMAD_METHOD_VERSION = $ver
                        & powershell -ExecutionPolicy Bypass -File $script
                    }
                    default {
                        Write-Host "opk: bmad update: flag khong hop le '$updateFlag'. Dung: --stable, --next, --version <x.y.z>" -ForegroundColor Red
                        exit 1
                    }
                }
            }
            default {
                Write-Host "opk: bmad: lenh khong hop le '$bmadCmd'. Dung: status, update --stable/--next/--version <x.y.z>" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v2.0.0 Tooling Doctor ──────────────────────────────────────
    'tooling' {
        $toolCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'doctor' }

        switch ($toolCmd) {
            'doctor' {
                Write-Host "opk: === Tooling Doctor ==="
                Write-Host ""
                Write-Host "opk: Detect-only tools (user-installed, never auto-installed):"
                Write-Host ""
                $tools = @(
                    @{Name='rtk'; Hint='cargo install rtk'},
                    @{Name='repomix'; Hint='npm i -g repomix'},
                    @{Name='ast-grep'; Hint='cargo install ast-grep'},
                    @{Name='rg'; Hint='Install ripgrep'},
                    @{Name='fd'; Hint='Install fd'},
                    @{Name='knip'; Hint='npm i -g knip'},
                    @{Name='gitleaks'; Hint='brew install gitleaks'},
                    @{Name='trufflehog'; Hint='brew install trufflehog'},
                    @{Name='semgrep'; Hint='pip install semgrep'},
                    @{Name='spectral'; Hint='npm i -g @stoplight/spectral-cli'},
                    @{Name='oasdiff'; Hint='brew install oasdiff'},
                    @{Name='playwright'; Hint='npm i -g playwright'},
                    @{Name='biome'; Hint='npm i -g @biomejs/biome'}
                )
                foreach ($tool in $tools) {
                    $tc = Get-Command $tool.Name -ErrorAction SilentlyContinue
                    if ($tc) {
                        Write-Host "opk:   $($tool.Name) $($tc.Source)" -ForegroundColor Green
                    } else {
                        Write-Host "opk:   $($tool.Name) — install: $($tool.Hint)" -ForegroundColor Yellow
                    }
                }
                Write-Host ""
                $doctorScript = Join-Path $KitDir 'doctor.sh'
                if (Test-Path $doctorScript) {
                    Write-Host "opk: Running full doctor.sh..."
                    Write-Host ""
                    & bash $doctorScript
                }
            }
            default {
                Write-Host "opk: tooling: lenh khong hop le '$toolCmd'. Dung: doctor" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v2.0.0 Taste Skill (optional, verify-gated) ────────────────
    { @('taste','taste-status','taste-off','update-taste') -contains $_ } {
        switch ($Command) {
            'taste-off' {
                $tasteDir = Join-Path $HOME '.config\opencode\skills\taste-skill'
                if (Test-Path $tasteDir) {
                    Write-Host "opk: Go Taste Skill tai $tasteDir" -ForegroundColor Yellow
                    $trashDir = Join-Path $KitDir ".opk-trash\taste-skill-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    New-Item -ItemType Directory -Path $trashDir -Force | Out-Null
                    Move-Item -Path $tasteDir -Destination $trashDir -Force
                    Write-Host "opk: Da di chuyen Taste Skill -> $trashDir" -ForegroundColor Green
                } else {
                    Write-Host 'opk: Taste Skill chua duoc cai dat.' -ForegroundColor Gray
                }
                exit 0
            }
            'update-taste' {
                $installer = Join-Path $KitDir 'scripts\install-taste-skill.ps1'
                Require-File $installer
                & powershell -ExecutionPolicy Bypass -File $installer @($Args)
                exit $LASTEXITCODE
            }
            'taste-status' {
                Write-Host "opk: === Taste Skill Status ==="
                $tasteDir = Join-Path $HOME '.config\opencode\skills\taste-skill'
                if (Test-Path $tasteDir) {
                    Write-Host "opk: Taste Skill directory exists: $tasteDir" -ForegroundColor Green
                    $skillMd = Join-Path $tasteDir 'SKILL.md'
                    if (Test-Path $skillMd) {
                        Write-Host "opk: SKILL.md found" -ForegroundColor Green
                    } else {
                        Write-Host "opk: SKILL.md not found in $tasteDir" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "opk: Taste Skill not installed" -ForegroundColor Yellow
                    Write-Host "opk: Run: opk taste install"
                }
                exit 0
            }
            'taste' {
                $tasteCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
                $tasteArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

                switch ($tasteCmd) {
                    'install' {
                        $installer = Join-Path $KitDir 'scripts\install-taste-skill.ps1'
                        Require-File $installer
                        & powershell -ExecutionPolicy Bypass -File $installer @tasteArgs
                    }
                    'status' { & $PSCommandPath taste-status }
                    'off' { & $PSCommandPath taste-off }
                    'doctor' {
                        Write-Host "opk: === Taste Skill Doctor ==="
                        Write-Host ""
                        Write-Host "opk: Runtime check:"
                        foreach ($tool in @('node','npm','npx')) {
                            $tc = Get-Command $tool -ErrorAction SilentlyContinue
                            if ($tc) { Write-Host "opk:   $tool $($tc.Source)" -ForegroundColor Green }
                            else { Write-Host "opk:   $tool not found (required for Taste Skill)" -ForegroundColor Yellow }
                        }
                        Write-Host ""
                        Write-Host "opk: Skill discovery:"
                        $tasteDir = Join-Path $HOME '.config\opencode\skills\taste-skill'
                        if (Test-Path $tasteDir) {
                            Write-Host "opk:   Skill directory exists: $tasteDir" -ForegroundColor Green
                        } else {
                            Write-Host "opk:   Skill directory missing: $tasteDir" -ForegroundColor Yellow
                        }
                        Write-Host ""
                        Write-Host "opk: Install command: opk taste install"
                        Write-Host "opk: OPK_SKIP_TASTE=1 skips auto-install during global setup"
                    }
                    default {
                        Write-Host "opk: taste: lenh khong hop le '$tasteCmd'. Dung: install [--v1|--v2], status, off, doctor" -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    }

    # ─── v1.8.0 ECC-lite (optional) ─────────────────────────────
    { @('ec','e','ecc') -contains $_ } {
        $eccCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $eccArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($eccCmd) {
            'audit' {
                $script = Join-Path $KitDir 'scripts\audit-ecc.sh'
                Require-File $script
                & bash $script @eccArgs
            }
            'lite' {
                $script = Join-Path $KitDir 'scripts\install-ecc-lite.sh'
                Require-File $script
                & bash $script @eccArgs
            }
            'status' {
                $script = Join-Path $KitDir 'scripts\check-ecc-lite.sh'
                Require-File $script
                & bash $script @eccArgs
            }
            'off' {
                $eccAgent = Join-Path $HOME '.config\opencode\agents\ecc-lite-strong.md'
                $eccCommands = @(
                    'ecc-audit.md','quality-gate.md','research-first.md',
                    'verify-loop.md','model-route-review.md','harness-audit.md'
                )
                $removed = $false
                if (Test-Path $eccAgent) {
                    Remove-Item -Force $eccAgent
                    Write-Host "opk: ✅ Đã xoá agent ecc-lite-strong.md" -ForegroundColor Green
                    $removed = $true
                }
                foreach ($cmdFile in $eccCommands) {
                    $cmdPath = Join-Path $HOME '.config\opencode\commands' $cmdFile
                    if (Test-Path $cmdPath) {
                        Remove-Item -Force $cmdPath
                        Write-Host "opk: ✅ Đã xoá command $cmdFile" -ForegroundColor Green
                        $removed = $true
                    }
                }
                if (-not $removed) {
                    Write-Host 'opk: ℹ️ ECC-lite chưa được cài đặt.' -ForegroundColor Gray
                } else {
                    Write-Host 'opk: ✅ Đã gỡ ECC-lite hoàn tất.' -ForegroundColor Green
                }
                exit 0
            }
            default {
                Write-Host "opk: ecc: lenh khong hop le '$eccCmd'. Dung: audit, lite, status, off" -ForegroundColor Red
                exit 1
            }
        }
    }

    'update-ecc' {
        $script = Join-Path $KitDir 'scripts\install-ecc-lite.sh'
        Require-File $script
        & bash $script @Args
    }

    # ─── v1.9.0 Hermes-lite (optional, meta-cognitive self-improvement) ─
    'hermes' {
        $hermesCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $hermesArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($hermesCmd) {
            'audit' {
                $script = Join-Path $KitDir 'scripts\audit-hermes.sh'
                Require-File $script
                & bash $script @hermesArgs
            }
            'status' {
                $script = Join-Path $KitDir 'scripts\check-hermes-lite.sh'
                Require-File $script
                & bash $script @hermesArgs
            }
            'capsule' {
                $script = Join-Path $KitDir 'scripts\hermes-learning-capsule.sh'
                Require-File $script
                & bash $script @hermesArgs
            }
            'off' {
                $hermesAgent = Join-Path $HOME '.config\opencode\agents\hermes-lite-strong.md'
                $hermesCommands = @(
                    'hermes-reflect.md','hermes-skill.md','hermes-kanban.md',
                    'hermes-memory.md','hermes-budget.md','hermes-audit.md',
                    'hermes-learn.md','hermes-research.md'
                )
                $removed = $false
                if (Test-Path $hermesAgent) {
                    Remove-Item -Force $hermesAgent
                    Write-Host "opk: ✅ Đã xoá agent hermes-lite-strong.md" -ForegroundColor Green
                    $removed = $true
                }
                foreach ($cmdFile in $hermesCommands) {
                    $cmdPath = Join-Path $HOME '.config\opencode\commands' $cmdFile
                    if (Test-Path $cmdPath) {
                        Remove-Item -Force $cmdPath
                        Write-Host "opk: ✅ Đã xoá command $cmdFile" -ForegroundColor Green
                        $removed = $true
                    }
                }
                if (-not $removed) {
                    Write-Host 'opk: ℹ️ Hermes-lite chưa được cài đặt.' -ForegroundColor Gray
                } else {
                    Write-Host 'opk: ✅ Đã gỡ Hermes-lite hoàn tất.' -ForegroundColor Green
                }
                exit 0
            }
            default {
                Write-Host "opk: hermes: lenh khong hop le '$hermesCmd'. Dung: audit, status, capsule, off" -ForegroundColor Red
                exit 1
            }
        }
    }

    # ─── v1.6.7 Supermemory Memory API (opt-in) ─────────────────
    'supermemory' {
        $smCmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { 'status' }
        $smArgs = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

        switch ($smCmd) {
            'install' {
                $installer = Join-Path $KitDir 'scripts\install-supermemory.ps1'
                Require-File $installer
                & powershell -ExecutionPolicy Bypass -File $installer @smArgs
            }
            'status' {
                $sm = Get-Command supermemory -ErrorAction SilentlyContinue
                if ($sm) {
                    Write-Host "opk: ✅ Supermemory installed at $($sm.Source)" -ForegroundColor Green
                    & $sm.Source --help 2>&1 | Select-Object -First 3
                } else {
                    Write-Host "opk: ❌ Supermemory not installed. Run: opk supermemory install" -ForegroundColor Yellow
                }
            }
            'init' {
                if (-not (Get-Command supermemory -ErrorAction SilentlyContinue)) {
                    Write-Host "opk: Supermemory chua duoc cai dat. Chay: opk supermemory install" -ForegroundColor Red
                    exit 1
                }
                Write-Host "opk: Initializing Supermemory in $((Get-Location).Path)"
                & supermemory init @smArgs
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            }
            'init-help' {
                if (-not (Get-Command supermemory -ErrorAction SilentlyContinue)) {
                    Write-Host "opk: Supermemory chua duoc cai dat. Chay: opk supermemory install" -ForegroundColor Red
                    exit 1
                }
                & supermemory init --help @smArgs
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            }
            default {
                Write-Host "opk: supermemory: lenh khong hop le '$smCmd'. Dung: install, status, init, init-help" -ForegroundColor Red
                exit 1
            }
        }
    }

    { @('md-convert','doc-to-md') -contains $_ } {
        if (-not (Get-Command markitdown -ErrorAction SilentlyContinue)) {
            Write-Host "opk: MarkItDown chua duoc cai dat. Chay: opk markitdown install" -ForegroundColor Red
            exit 1
        }
        if ($Args.Count -lt 2) {
            Write-Host "Usage: opk $Command <input-file> <output-file> [--force]" -ForegroundColor Yellow
            exit 1
        }
        $inputFile = $Args[0]
        $outputFile = $Args[1]
        $force = $false
        if ($Args.Count -gt 2) {
            foreach ($a in $Args[2..($Args.Count-1)]) {
                if ($a.ToLower() -eq '--force') { $force = $true }
                else {
                    Write-Host "opk: flag khong hop le: $a" -ForegroundColor Red
                    exit 1
                }
            }
        }
        # Validate input exists
        if (-not (Test-Path $inputFile)) {
            Write-Host "opk: input file khong ton tai: $inputFile" -ForegroundColor Red
            exit 1
        }
        # Check output
        if ((Test-Path $outputFile) -and -not $force) {
            Write-Host "opk: output file da ton tai: $outputFile (dung --force de ghi de)" -ForegroundColor Red
            exit 1
        }
        # Don't convert sensitive files
        $sensitive = @('.env','.secret','.key','.pem','.cert','credential','token','private')
        $ext = [System.IO.Path]::GetExtension($inputFile).ToLower()
        if ($sensitive -contains $ext -or $inputFile -match 'secret|private|credential|token') {
            Write-Host "opk: tu choi convert file nhay cam: $inputFile" -ForegroundColor Red
            exit 1
        }
        Write-Host "opk: Converting $inputFile -> $outputFile"
        & markitdown $inputFile | Out-File -FilePath $outputFile -Encoding UTF8
        $bytes = (Get-Item $outputFile).Length
        Write-Host "opk: ✅ Done ($bytes bytes)" -ForegroundColor Green
    }

    default {
        Write-Host "opk: lenh khong hop le: '$Command'. Chay 'opk help'." -ForegroundColor Red
        exit 1
    }
}

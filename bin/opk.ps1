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
        Write-Host "v1.6.5 — One Command Update & Cleanup (moi):"
        Write-Host "  opk up          Update kit + project (git pull + install-global)"
        Write-Host "  opk update      Alias: opk up"
        Write-Host "  opk upgrade     Alias: opk up"
        Write-Host "  opk clean       Cleanup project artifacts (mac dinh dry-run)"
        Write-Host "  opk up --clean  Update + cleanup apply"
        Write-Host ""
        Write-Host "v1.6.4 — Mode & Safety (moi):"
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

    default {
        Write-Host "opk: lenh khong hop le: '$Command'. Chay 'opk help'." -ForegroundColor Red
        exit 1
    }
}

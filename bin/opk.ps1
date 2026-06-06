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
        Write-Host "  powershell -ExecutionPolicy Bypass -Command `"`$Project=(Get-Location).Path; `$KIT=Join-Path `$HOME 'opencode-power-kit'; if (Test-Path (Join-Path `$KIT '.git')) { & git -C `$KIT pull --ff-only } else { & git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git `$KIT }; & (Join-Path `$KIT 'bootstrap.ps1') -All -ProjectDir `$Project -Yes; & (Join-Path `$KIT 'verify.ps1')`""
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

    default {
        Write-Host "opk: lenh khong hop le: '$Command'. Chay 'opk help'." -ForegroundColor Red
        exit 1
    }
}

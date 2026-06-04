# ============================================================================
# OpenCode Power Kit - setup.ps1
# Menu + non-interactive entry point cho Windows PowerShell.
# Goi cac script con co san, khong duplicate logic. Idempotent.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Global
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Project
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Fullstack
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -All
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Doctor
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -DryRun
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Yes
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Help
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Global,
    [switch]$Project,
    [switch]$Fullstack,
    [switch]$All,
    [switch]$Doctor,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path $ScriptDir).Path
$GlobalDir = Join-Path $KitDir 'opencode-global'
$ScriptsDir = Join-Path $KitDir 'scripts'

$PwdNow = (Get-Location).Path
$Home   = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }
function Write-Hdr   { Write-Host "============================================" -ForegroundColor Magenta }

# --- Verify required sub-scripts exist ---
function Require-Script {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Err "Thieu script con: $Path — repo co the bi thieu file. Chay 'git status' de kiem tra."
    }
}

# Verify sub-scripts
if (-not (Test-Path $GlobalDir)) {
    Write-Err "Thieu $GlobalDir — kit chua day du."
}
Require-Script (Join-Path $KitDir 'install-global.ps1')
Require-Script (Join-Path $KitDir 'install.ps1')
Require-Script (Join-Path $KitDir 'doctor.ps1')
Require-Script (Join-Path $KitDir 'verify.ps1')
Require-Script (Join-Path $ScriptsDir 'install-fullstack-profile.ps1')

# --- Bad project-dir detection ---
function Test-BadProjectDir {
    param([string]$Path)
    if (-not $Path) { return $true }
    $p = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path
    if (-not $p) { $p = $Path }
    $p = $p.TrimEnd('\','/')

    # HOME
    $homeTrim = $Home.TrimEnd('\','/')
    if ($p -ieq $homeTrim) { return $true }

    # Kit itself
    $kitTrim = $KitDir.TrimEnd('\','/')
    if ($p -ieq $kitTrim) { return $true }
    if ($p.StartsWith("$kitTrim\", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }

    # Root drive + system + temp
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
    Write-Host ""
    Write-Host "x Tu choi cai vao: $Path" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ly do: project install KHONG chay trong:"
    Write-Host "  - `$HOME                    ($Home)"
    Write-Host "  - chinh repo kit           ($KitDir)"
    Write-Host "  - C:\, C:\Windows, C:\Program Files*"
    Write-Host "  - `$env:TEMP, `$env:TMP"
    Write-Host ""
    Write-Host "Cach lam dung:"
    Write-Host ""
    Write-Host "  cd C:\path\to\your\project" -ForegroundColor Green
    Write-Host "  opk install"               -ForegroundColor Green
    Write-Host "  opk fullstack"             -ForegroundColor Green
    Write-Host ""
}

# --- Next-steps printer ---
function Show-NextSteps {
    param([bool]$DidGlobal)
    Write-Host ""
    Write-Hdr
    Write-Host "  Hoan tat!" -ForegroundColor Green
    Write-Hdr
    Write-Host ""
    if ($DidGlobal) {
        Write-Info "Buoc tiep theo:"
        Write-Info "  1) Mo shell moi (de load PATH)"
        Write-Info "  2) opk help                  # xem lenh opk CLI"
        Write-Info "  3) opencode                  # mo OpenCode, thu /smart-scan"
    } else {
        Write-Info "Buoc tiep theo:"
        Write-Info "  - opk help                   # xem lenh opk CLI"
        Write-Info "  - opk verify                 # kiem tra"
        Write-Info "  - opencode                   # mo OpenCode"
    }
}

# --- Banner ---
function Show-Banner {
    Write-Host ""
    Write-Hdr
    Write-Host "  OpenCode Power Kit — setup" -ForegroundColor Magenta
    Write-Host "  Kit:  $KitDir"
    Write-Host "  PWD:  $PwdNow"
    $verFile = Join-Path $KitDir 'VERSION'
    $ver = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { '?' }
    Write-Host "  Ver:  $ver"
    Write-Hdr
    Write-Host ""
}

# --- Plan printer (dry-run) ---
function Show-Plan {
    param([string]$Mode)
    Write-Host ""
    Write-Info "[DRY-RUN] Se chay:"
    switch ($Mode) {
        'global'    { Write-Host "  - powershell install-global.ps1 -Yes" }
        'project'   { Write-Host "  - powershell install.ps1   (yeu cau project dir)" }
        'fullstack' { Write-Host "  - powershell scripts\install-fullstack-profile.ps1 (yeu cau project dir)" }
        'all' {
            Write-Host "  - powershell install-global.ps1 -Yes"
            if (Test-BadProjectDir $PwdNow) {
                Write-Host "  - SKIP project + fullstack (pwd khong phai project dir an toan)"
            } else {
                Write-Host "  - powershell install.ps1"
                Write-Host "  - powershell scripts\install-fullstack-profile.ps1"
            }
        }
        'doctor' { Write-Host "  - powershell doctor.ps1" }
    }
    Write-Host ""
}

# --- Action runners ---
function Do-Global {
    Write-Info "Chay install-global.ps1..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install-global.ps1') -Yes
    Show-NextSteps $true
}

function Do-Project {
    if (Test-BadProjectDir $PwdNow) {
        Show-BlockedDir $PwdNow
        Write-Err "Khong chay install.ps1 trong $PwdNow."
    }
    Write-Info "Chay install.ps1 trong $PwdNow ..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install.ps1') -Yes
    Write-Ok "Project install xong."
    Show-NextSteps $false
}

function Do-Fullstack {
    if (Test-BadProjectDir $PwdNow) {
        Show-BlockedDir $PwdNow
        Write-Err "Khong chay fullstack profile trong $PwdNow."
    }
    Write-Info "Chay install-fullstack-profile.ps1 trong $PwdNow ..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir 'install-fullstack-profile.ps1') -Yes
    Write-Ok "Full-stack profile xong."
    Show-NextSteps $false
}

function Do-All {
    Write-Info "[1/3] install-global.ps1..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install-global.ps1') -Yes
    if (Test-BadProjectDir $PwdNow) {
        Write-Warn "[2/3 + 3/3] BO QUA: pwd=$PwdNow khong phai project dir an toan (HOME / kit / C:\ / C:\Windows / C:\Program Files* / TEMP / TMP)."
        Write-Warn "Sau khi 'cd' vao project, chay: powershell setup.ps1 -Project -Fullstack"
        Show-NextSteps $true
    } else {
        Write-Info "[2/3] install.ps1 trong $PwdNow ..."
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'install.ps1') -Yes
        Write-Info "[3/3] install-fullstack-profile.ps1 trong $PwdNow ..."
        & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir 'install-fullstack-profile.ps1') -Yes
        Write-Ok "All-in-one xong."
        Show-NextSteps $true
    }
}

function Do-Doctor {
    Write-Info "Chay doctor.ps1 (read-only)..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'doctor.ps1')
}

# --- Menu ---
function Show-Menu {
    Show-Banner
    Write-Host "Chon che do cai (nhap so, Enter = mac dinh):"
    Write-Host ""
    Write-Host "  1) Cai global OpenCode Power Kit"
    Write-Host "  2) Cai vao project hien tai"
    Write-Host "  3) Cai full-stack profile Node/Nest/React/MySQL"
    Write-Host "  4) Cai tat ca an toan: global + project + full-stack profile"
    Write-Host "  5) Doctor/verify (chi doc, khong sua)"
    Write-Host "  6) Huong dan (README + flags)"
    Write-Host "  0) Thoat"
    Write-Host ""
}

function Invoke-Interactive {
    Show-Menu
    $choice = Read-Host "Chon [0-6] (mac dinh 1)"
    if (-not $choice) { $choice = '1' }
    switch ($choice) {
        '1' { Do-Global }
        '2' { Do-Project }
        '3' { Do-Fullstack }
        '4' { Do-All }
        '5' { Do-Doctor }
        '6' { Show-HelpText }
        '0' { Write-Info "Thoat."; exit 0 }
        default { Write-Err "Lua chon khong hop le: $choice" }
    }
}

function Show-HelpText {
    $ver = if (Test-Path (Join-Path $KitDir 'VERSION')) { (Get-Content (Join-Path $KitDir 'VERSION') -Raw).Trim() } else { '?' }
    Write-Host ""
    Write-Host "OpenCode Power Kit v$ver"
    Write-Host ""
    Write-Host "Dung nhanh (30 giay):"
    Write-Host "  git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git C:\opencode-power-kit"
    Write-Host "  cd C:\opencode-power-kit"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Global"
    Write-Host ""
    Write-Host "Flags:"
    Write-Host "  -Global     Cai global (commands/skills/agents + opk CLI + User PATH)"
    Write-Host "  -Project    Cai vao project hien tai"
    Write-Host "  -Fullstack  Cai full-stack profile (Nest/React/MySQL)"
    Write-Host "  -All        Cai tat ca (can cd vao project; neu pwd = HOME/kit/root/system/Temp se skip project+fullstack)"
    Write-Host "  -Doctor     Chay doctor (read-only)"
    Write-Host "  -DryRun     Chi in ke hoach"
    Write-Host "  -Yes        Skip confirm"
    Write-Host "  -Help       In tro giup nay"
    Write-Host ""
    Write-Host "Sau khi cai global:"
    Write-Host "  Mo shell moi (de load PATH)"
    Write-Host "  opk help"
    Write-Host "  opencode"
    Write-Host ""
}

# --- Main ---
if ($Help) { Show-HelpText; exit 0 }
Show-Banner

# Default: no flag -> interactive menu
if (-not ($Global -or $Project -or $Fullstack -or $All -or $Doctor)) {
    if ($Yes) {
        # -Yes without action flag: default to -Global
        $Global = $true
    } else {
        Invoke-Interactive
        exit 0
    }
}

# Dry-run
if ($DryRun) {
    if ($Global)    { Show-Plan 'global' }
    if ($Project)   { Show-Plan 'project' }
    if ($Fullstack) { Show-Plan 'fullstack' }
    if ($All)       { Show-Plan 'all' }
    if ($Doctor)    { Show-Plan 'doctor' }
    exit 0
}

# Execute in order
if ($Global)    { Do-Global }
if ($Project)   { Do-Project }
if ($Fullstack) { Do-Fullstack }
if ($All)       { Do-All }
if ($Doctor)    { Do-Doctor }

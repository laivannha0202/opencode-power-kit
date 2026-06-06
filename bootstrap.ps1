# ============================================================================
# OpenCode Power Kit - bootstrap.ps1
# One-command installer for Windows PowerShell 5.1+ / PowerShell Core 7+.
# Khong can admin, khong sudo, khong in secret. Idempotent.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Global
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -All
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Project -ProjectDir C:\path
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Fullstack
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Doctor
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -Global
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Yes -All
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Help
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Global,
    [switch]$Project,
    [switch]$Fullstack,
    [switch]$All,
    [string]$ProjectDir,
    [switch]$Doctor,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir (nơi chứa bootstrap.ps1) ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path $ScriptDir).Path
$GlobalDir = Join-Path $KitDir 'opencode-global'

if (-not (Test-Path (Join-Path $KitDir 'setup.ps1'))) {
    Write-Host "[ERROR] Khong tim thay setup.ps1 tai $KitDir. Repo kit co the bi thieu file." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $GlobalDir)) {
    Write-Host "[ERROR] Thieu $GlobalDir — kit chua day du." -ForegroundColor Red
    exit 1
}

$PwdNow = (Get-Location).Path
$Home   = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Hdr   { Write-Host "============================================" -ForegroundColor Magenta }

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

    # Kit itself (with explicit allowlist for test/CI scratch)
    $kitTrim = $KitDir.TrimEnd('\','/')
    if ($p -ieq $kitTrim) { return $true }
    if ($p.StartsWith("$kitTrim\", [System.StringComparison]::OrdinalIgnoreCase)) {
        # Whitelist: .tmp / .test inside kit are scratch dirs (integration-test)
        if ($p -ieq "$kitTrim\.tmp" -or $p.StartsWith("$kitTrim\.tmp\", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($p -ieq "$kitTrim\.test" -or $p.StartsWith("$kitTrim\.test\", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        return $true
    }

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

# --- Banner ---
function Show-Banner {
    Write-Host ""
    Write-Hdr
    Write-Host "  OpenCode Power Kit — bootstrap" -ForegroundColor Magenta
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
        'global'    { Write-Host "  - powershell setup.ps1 -Global -Yes" }
        'project'   { Write-Host "  - powershell setup.ps1 -Project -Yes   (cwd: $PwdNow)" }
        'fullstack' { Write-Host "  - powershell setup.ps1 -Fullstack -Yes (cwd: $PwdNow)" }
        'all' {
            Write-Host "  - powershell setup.ps1 -Global -Yes"
            if (Test-BadProjectDir $PwdNow) {
                Write-Host "  - SKIP project + fullstack (cwd khong phai project dir an toan)"
            } else {
                Write-Host "  - powershell setup.ps1 -Project -Fullstack -Yes"
            }
        }
        'doctor' { Write-Host "  - powershell setup.ps1 -Doctor" }
    }
    Write-Host ""
}

# --- Help ---
function Show-Help {
    Write-Host ""
    $ver = if (Test-Path (Join-Path $KitDir 'VERSION')) { (Get-Content (Join-Path $KitDir 'VERSION') -Raw).Trim() } else { '?' }
    Write-Host "OpenCode Power Kit — bootstrap v$ver"
    Write-Host ""
    Write-Host "Dung nhanh (1 lenh cai global):"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Global"
    Write-Host ""
    Write-Host "Flags:"
    Write-Host "  -Global               Cai global (commands/skills/agents + opk CLI)"
    Write-Host "  -Project              Cai vao project hien tai (pwd)"
    Write-Host "  -Fullstack            Cai full-stack profile"
    Write-Host "  -All                  Cai global + project + fullstack (auto-detect project)"
    Write-Host "  -ProjectDir <path>    Override thu muc project (dung voi -Project/-Fullstack/-All)"
    Write-Host "  -Doctor               Chay doctor (read-only)"
    Write-Host "  -DryRun               Chi in ke hoach"
    Write-Host "  -Yes                  Skip confirm"
    Write-Host "  -Help                 In tro giup nay"
    Write-Host ""
    Write-Host "Sau khi cai global:"
    Write-Host "  Moi shell moi (de load PATH)"
    Write-Host "  opk help"
    Write-Host "  opencode"
    Write-Host ""
    Write-Host "Project install TU CHOI chay trong:"
    Write-Host "  `$HOME, kit dir, C:\, C:\Windows, C:\Program Files*, `$env:TEMP, `$env:TMP"
    Write-Host ""
}

# --- Runners ---
function Do-Global {
    Write-Info "Cai global..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Global -Yes
    Write-Ok "Global install xong."
    # Update PATH for current session
    $opkBin = Join-Path $Home '.opencode-power-kit\bin'
    if (Test-Path $opkBin) {
        if (($env:Path -split ';' -notcontains $opkBin) -and ($env:Path -notlike "*$opkBin*")) {
            $env:Path = "$opkBin;$env:Path"
        }
    }
    if (Get-Command opk.cmd -ErrorAction SilentlyContinue) {
        $p = (& opk.cmd path) 2>$null
        if ($p) { Write-Info "opk path: $p" }
        $v = (& opk.cmd version) 2>$null
        if ($v) { Write-Info "opk version: $v" }
        & opk.cmd doctor 2>$null | Out-Null
    } elseif (Get-Command opk -ErrorAction SilentlyContinue) {
        $p = (& opk path) 2>$null
        if ($p) { Write-Info "opk path: $p" }
        $v = (& opk version) 2>$null
        if ($v) { Write-Info "opk version: $v" }
        & opk doctor 2>$null | Out-Null
    } else {
        Write-Warn "opk chua co trong PATH. Mo shell moi de load PATH."
    }
}

function Do-Project {
    param([string]$Target)
    if (Test-BadProjectDir $Target) {
        Show-BlockedDir $Target
        Write-Err "Khong chay project install trong $Target."
        exit 1
    }
    Write-Info "Cai project vao: $Target"
    Push-Location $Target
    try {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Project -Yes
    } finally {
        Pop-Location
    }
    Write-Ok "Project install xong tai $Target."
}

function Do-Fullstack {
    param([string]$Target)
    if (Test-BadProjectDir $Target) {
        Show-BlockedDir $Target
        Write-Err "Khong chay fullstack trong $Target."
        exit 1
    }
    Write-Info "Cai fullstack profile vao: $Target"
    Push-Location $Target
    try {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Fullstack -Yes
    } finally {
        Pop-Location
    }
    Write-Ok "Fullstack profile xong tai $Target."
}

function Do-All {
    Write-Info "[1/N] Cai global..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Global -Yes
    # Update PATH for current session
    $opkBin = Join-Path $Home '.opencode-power-kit\bin'
    if (Test-Path $opkBin) {
        if ($env:Path -notlike "*$opkBin*") {
            $env:Path = "$opkBin;$env:Path"
        }
    }
    $target = if ($ProjectDir) { $ProjectDir } else { $PwdNow }
    if (Test-BadProjectDir $target) {
        Write-Warn "[2/N + 3/N] BO QUA project + fullstack: $target khong phai project dir an toan."
        Write-Warn "         (HOME / kit / C:\ / C:\Windows / C:\Program Files* / TEMP / TMP deu bi tu choi.)"
        Write-Host ""
        Write-Info "Sau khi 'cd' vao project that, chay:"
        Write-Host "  opk install"   -ForegroundColor Green
        Write-Host "  opk fullstack" -ForegroundColor Green
        return
    }
    Write-Info "[2/N] Cai project vao: $target"
    Push-Location $target
    try {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Project -Yes
        Write-Info "[3/N] Cai fullstack profile vao: $target"
        & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Fullstack -Yes
    } finally {
        Pop-Location
    }
    Write-Ok "All-in-one xong tai $target."
}

function Do-Doctor {
    Write-Info "Chay doctor..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $KitDir 'setup.ps1') -Doctor
}

# --- Confirm ---
function Confirm-DefaultYes {
    param([string]$Prompt)
    if ($Yes) { return }
    $ans = Read-Host "$Prompt [Y/n]"
    if ($ans -notin @('','Y','y','yes','YES')) {
        Write-Info "Da huy."
        exit 0
    }
}

# --- Main ---
if ($Help) { Show-Help; exit 0 }
Show-Banner

# No flag: default to -Global
if (-not ($Global -or $Project -or $Fullstack -or $All -or $Doctor)) {
    Show-Help
    Write-Info "Khong co flag nao — mac dinh se chay -Global. Them -Yes de skip confirm."
    $Global = $true
    $Yes    = $true
}

# Validate ProjectDir if set
if ($ProjectDir) {
    if (-not (Test-Path $ProjectDir)) {
        Write-Err "-ProjectDir khong ton tai: $ProjectDir"
        exit 1
    }
    $ProjectDir = (Resolve-Path $ProjectDir).Path
}

# Dry-run mode
if ($DryRun) {
    if ($Global)    { Show-Plan 'global' }
    if ($Project)   { Show-Plan 'project' }
    if ($Fullstack) { Show-Plan 'fullstack' }
    if ($All)       { Show-Plan 'all' }
    if ($Doctor)    { Show-Plan 'doctor' }
    exit 0
}

# Dispatch
if ($Global)    { Confirm-DefaultYes "Cai global?"; Do-Global }
if ($Project)   { $t = if ($ProjectDir) { $ProjectDir } else { $PwdNow }; Confirm-DefaultYes "Cai project tai $t?"; Do-Project $t }
if ($Fullstack) { $t = if ($ProjectDir) { $ProjectDir } else { $PwdNow }; Confirm-DefaultYes "Cai fullstack tai $t?"; Do-Fullstack $t }
if ($All)       { Confirm-DefaultYes "Cai tat ca?"; Do-All }
if ($Doctor)    { Do-Doctor }

Write-Host ""
Write-Hdr
Write-Host "  bootstap hoan tat" -ForegroundColor Green
Write-Hdr
Write-Host ""
Write-Info "Buoc tiep theo:"
if (Get-Command opk.cmd -ErrorAction SilentlyContinue) {
    Write-Info "  1) opk.cmd help"
    Write-Info "  2) opk.cmd path"
    Write-Info "  3) opencode"
} else {
    Write-Info "  1) Mo shell moi (de load PATH)"
    Write-Info "  2) opk help"
    Write-Info "  3) opencode"
}
Write-Host ""

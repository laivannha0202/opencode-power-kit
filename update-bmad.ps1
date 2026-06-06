# ============================================================================
# OpenCode Power Kit - update-bmad.ps1
# Mirror update-bmad.sh: cài lại / cập nhật BMAD Method cho project hiện tại.
#
# Env overrides:
#   $env:BMAD_METHOD_VERSION  Pin version BMAD (mặc định: 6.8.0)
#   $env:OPK_USER_NAME        Tên user cho BMAD output
#                             (fallback: git config user.name -> USERNAME -> 'User')
# ============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- BMAD Method version (env override, default 6.8.0) ---
if (-not $env:BMAD_METHOD_VERSION -or [string]::IsNullOrWhiteSpace($env:BMAD_METHOD_VERSION)) {
    $env:BMAD_METHOD_VERSION = '6.8.0'
}
$BmadVersion = $env:BMAD_METHOD_VERSION

# --- User name (env > git config > USERNAME > "User") ---
$OpkUserName = $env:OPK_USER_NAME
if ([string]::IsNullOrWhiteSpace($OpkUserName)) {
    try {
        $gitName = (& git config user.name 2>$null) | Select-Object -First 1
        if ($gitName) { $OpkUserName = $gitName.Trim() }
    } catch { }
}
if ([string]::IsNullOrWhiteSpace($OpkUserName)) { $OpkUserName = $env:USERNAME }
if ([string]::IsNullOrWhiteSpace($OpkUserName)) { $OpkUserName = 'User' }

# --- Resolve paths ---
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir     = (Resolve-Path $ScriptDir).Path
$TargetDir  = (Get-Location).Path
$BmadLog    = Join-Path $TargetDir '.opencode-power-bmad-update.log'

# --- Helpers ---
function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

# --- Safety: Test-BadProjectDir (sync với bootstrap.ps1 / setup.ps1 / opk.ps1) ---
$Home = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
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
    if ($p -ieq 'C:\Program Files' -or $p.StartsWith('C:\Program Files\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
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
    Write-Host "x Tu choi chay trong: $Path" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ly do: update-bmad.ps1 KHONG chay trong:"
    Write-Host "  - `$HOME                    ($Home)"
    Write-Host "  - chinh repo kit           ($KitDir)"
    Write-Host "  - C:\, C:\Windows, C:\Program Files*"
    Write-Host "  - `$env:TEMP, `$env:TMP"
    Write-Host ""
    Write-Host "Cach lam dung:"
    Write-Host ""
    Write-Host "  cd C:\path\to\your\project" -ForegroundColor Green
    Write-Host "  opk.cmd update-bmad"       -ForegroundColor Green
    Write-Host ""
}

# --- Run safety check ---
if (Test-BadProjectDir $TargetDir) {
    Show-BlockedDir $TargetDir
    Write-Err "Khong chay update-bmad.ps1 trong $TargetDir."
}

if (-not (Test-Path (Join-Path $TargetDir '.opencode\opencode.json'))) {
    Write-Err "Khong tim thay .opencode\opencode.json. Hay chay install.ps1 truoc."
}

Write-Info "Cap nhat BMAD Method v$BmadVersion (user: $OpkUserName)"
Write-Info "Full log: $BmadLog"

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
    Write-Err "npx khong tim thay. Hay cai Node.js truoc."
}

$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$output = & npx --yes "bmad-method@$BmadVersion" install `
    --modules bmm `
    --tools opencode `
    --user-name $OpkUserName `
    --communication-language Vietnamese `
    --document-output-language Vietnamese `
    --directory $TargetDir `
    -y 2>&1 | Out-String
$bmadExit = $LASTEXITCODE
$ErrorActionPreference = $oldEap

# Always capture full log
Set-Content -Path $BmadLog -Value $output -Encoding UTF8

if ($bmadExit -ne 0) {
    Write-Host ""
    Write-Host "x BMAD Method cap nhat THAT BAI (exit code: $bmadExit)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Full log: $BmadLog" -ForegroundColor Red
    Write-Host "----- tail -50 cua log -----" -ForegroundColor Red
    $logLines = $output -split "`n"
    $tail = $logLines | Select-Object -Last 50
    $tail | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host "----------------------------" -ForegroundColor Red
    Write-Err "Sua loi trong log roi chay lai: powershell -File `"$KitDir\update-bmad.ps1`" (hoac opk.cmd update-bmad)."
}

Write-Ok "BMAD Method v$BmadVersion da cap nhat xong"

# Always show tail -50 for visibility
Write-Host ""
Write-Info "----- tail -50 BMAD log ($BmadLog) -----"
$logLines = $output -split "`n"
$tail = $logLines | Select-Object -Last 50
$tail | ForEach-Object { Write-Host $_ }
Write-Host "-----------------------------------------"

Write-Host ""
Write-Info "Cac module hien co:"
if (Test-Path (Join-Path $TargetDir '.bmad')) {
    Get-ChildItem (Join-Path $TargetDir '.bmad') -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host "  - $($_.Name)" }
} else {
    Write-Warn "Khong tim thay .bmad\"
}

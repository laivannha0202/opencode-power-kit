# ============================================================================
# OpenCode Power Kit - install.ps1
# Per-project install cho Windows PowerShell. Mirror install.sh.
# Copy templates, merge gitignore, optional BMAD via npx, generate report.
#
# Env overrides:
#   $env:BMAD_METHOD_VERSION  Pin version BMAD (mặc định: 6.8.0)
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# --- BMAD Method version (env override, default 6.8.0) ---
if (-not $env:BMAD_METHOD_VERSION -or [string]::IsNullOrWhiteSpace($env:BMAD_METHOD_VERSION)) {
    $env:BMAD_METHOD_VERSION = '6.8.0'
}
$BmadVersion = $env:BMAD_METHOD_VERSION

# --- Resolve paths ---
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir     = (Resolve-Path $ScriptDir).Path
$TargetDir  = (Get-Location).Path
$ReportFile = Join-Path $TargetDir 'opencode-power-install-report.md'
$Timestamp  = Get-Date -Format 'yyyyMMddHHmmss'
$BackupDir  = Join-Path $TargetDir ".opencode-power-kit-backup-$Timestamp"
$BmadLog    = Join-Path $TargetDir '.opencode-power-bmad-install.log'

# --- User name (env > git config > USERNAME > "User") ---
# Khong hardcode ten ca nhan trong installer.
$OpkUserName = $env:OPK_USER_NAME
if ([string]::IsNullOrWhiteSpace($OpkUserName)) {
    try {
        $gitName = (& git config user.name 2>$null) | Select-Object -First 1
        if ($gitName) { $OpkUserName = $gitName.Trim() }
    } catch { }
}
if ([string]::IsNullOrWhiteSpace($OpkUserName)) { $OpkUserName = $env:USERNAME }
if ([string]::IsNullOrWhiteSpace($OpkUserName)) { $OpkUserName = 'User' }

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

# --- Safety: Test-BadProjectDir (sync với bootstrap.ps1 / setup.ps1 / opk.ps1) ---
$Home = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
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

# --- Run safety check ---
if (Test-BadProjectDir $TargetDir) {
    Show-BlockedDir $TargetDir
    Write-Err "Khong chay install.ps1 trong $TargetDir."
}

if (-not (Test-Path (Join-Path $KitDir 'templates'))) {
    Write-Err "Khong tim thay thu muc templates/ trong $KitDir"
}

Write-Info "Target project: $TargetDir"
Write-Info "Power Kit source: $KitDir"
Write-Info "BMAD Method version: $BmadVersion"

# --- Backup existing files ---
$BackupNeeded = $false
$filesToBackup = @('AGENTS.md', 'OPENCODE.md', '.opencode\opencode.json')
foreach ($rel in $filesToBackup) {
    if (Test-Path (Join-Path $TargetDir $rel)) { $BackupNeeded = $true; break }
}

if ($BackupNeeded) {
    Write-Info "Backup files cu vao $BackupDir ..."
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    foreach ($rel in $filesToBackup) {
        $src = Join-Path $TargetDir $rel
        if (Test-Path $src) {
            $dst = Join-Path $BackupDir $rel
            $dstDir = Split-Path $dst
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
            Copy-Item -Path $src -Destination $dst -Force
            Write-Ok "Da backup: $rel"
        }
    }
}

# --- Copy templates ---
Write-Info "Copy templates..."

$templates = @{
    'AGENTS.md'     = 'AGENTS.md'
    'OPENCODE.md'   = 'OPENCODE.md'
    'opencode.json' = '.opencode\opencode.json'
}
foreach ($src in $templates.Keys) {
    $dst = $templates[$src]
    $srcPath = Join-Path (Join-Path $KitDir 'templates') $src
    $dstPath = Join-Path $TargetDir $dst
    $dstDir  = Split-Path $dstPath
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $srcPath -Destination $dstPath -Force
    Write-Ok $dst
}

# --- Merge gitignore-extra ---
$gitignore = Join-Path $TargetDir '.gitignore'
$giExtra   = Join-Path (Join-Path $KitDir 'templates') 'gitignore-extra.txt'
$giMarker  = '# >>> opencode-power-kit'
$giEndMark = '# <<< opencode-power-kit'

if (Test-Path $gitignore) {
    $content = Get-Content $gitignore -Raw
    if ($content -notmatch [regex]::Escape($giMarker)) {
        Add-Content -Path $gitignore -Value ""
        Add-Content -Path $gitignore -Value $giMarker
        Get-Content $giExtra | Add-Content -Path $gitignore
        Add-Content -Path $gitignore -Value $giEndMark
        Write-Ok "Da merge gitignore-extra vao .gitignore"
    } else {
        Write-Warn ".gitignore da co noi dung Power Kit, bo qua."
    }
} else {
    Copy-Item -Path $giExtra -Destination $gitignore -Force
    Write-Ok "Tao moi .gitignore"
}

# --- Copy knip.json (chưa có thì copy) ---
$knipDst = Join-Path $TargetDir 'knip.json'
if (-not (Test-Path $knipDst)) {
    Copy-Item -Path (Join-Path (Join-Path $KitDir 'templates') 'knip.json') -Destination $knipDst -Force
    Write-Ok 'knip.json'
}

# --- Copy lefthook.yml (chưa có thì copy) ---
$lefthookDst = Join-Path $TargetDir 'lefthook.yml'
if (-not (Test-Path $lefthookDst)) {
    Copy-Item -Path (Join-Path (Join-Path $KitDir 'templates') 'lefthook.yml') -Destination $lefthookDst -Force
    Write-Ok 'lefthook.yml'
}

# --- Install BMAD Method ---
Write-Info "Cai dat BMAD Method v$BmadVersion (module bmm, user: $OpkUserName)..."
Write-Info "Full log: $BmadLog"
$npx = Get-Command npx -ErrorAction SilentlyContinue
if ($npx) {
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
        Write-Host "x BMAD Method cai THAT BAI (exit code: $bmadExit)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Full log: $BmadLog" -ForegroundColor Red
        Write-Host "----- tail -50 cua log -----" -ForegroundColor Red
        $logLines = $output -split "`n"
        $tail = $logLines | Select-Object -Last 50
        $tail | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host "----------------------------" -ForegroundColor Red
        Write-Err "Sua loi trong log roi chay lai: powershell -File `"$KitDir\update-bmad.ps1`" (hoac opk tools update-bmad)."
    }

    Write-Ok "BMAD Method v$BmadVersion da cai xong"

    # Always show tail -50 for visibility
    Write-Host ""
    Write-Info "----- tail -50 BMAD log ($BmadLog) -----"
    $logLines = $output -split "`n"
    $tail = $logLines | Select-Object -Last 50
    $tail | ForEach-Object { Write-Host $_ }
    Write-Host "-----------------------------------------"
} else {
    Write-Warn "npx khong tim thay, bo qua BMAD install. Hay cai Node.js truoc."
}

# --- Lefthook install ---
$pkgJson = Join-Path $TargetDir 'package.json'
if ((Test-Path $pkgJson) -and (Test-Path $lefthookDst)) {
    Write-Info "Cai dat lefthook..."
    try {
        & npx lefthook install 2>&1 | Out-Null
    } catch {
        Write-Warn "lefthook install that bai, bo qua."
    }
}

# --- Generate report ---
$bkLine = if ($BackupNeeded) { "- Backup tai: $BackupDir" } else { "- Khong co file can backup" }
$knipStatus  = if (Test-Path $knipDst)    { 'OK' } else { 'skip (da co)' }
$leftStatus  = if (Test-Path $lefthookDst) { 'OK' } else { 'skip (da co)' }

$reportBody = @"
# OpenCode Power Kit - Install Report

- **Thoi gian:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Project:** $TargetDir
- **Power Kit:** $KitDir
- **BMAD Method version:** $BmadVersion
- **User name (OPK_USER_NAME):** $OpkUserName

## Files da cai dat

| File | Trang thai |
|------|-----------|
| AGENTS.md | OK |
| OPENCODE.md | OK |
| .opencode\opencode.json | OK |
| .gitignore (merged) | OK |
| knip.json | $knipStatus |
| lefthook.yml | $leftStatus |

## BMAD Method

- Module: bmm
- Tools: opencode
- Language: Vietnamese
- Version: $BmadVersion
- Log: $BmadLog

## Backup

$bkLine

## Buoc tiep theo

1. Kiem tra ``AGENTS.md`` va ``OPENCODE.md`` — chinh sua neu can.
2. Chay ``opk verify`` de kiem tra.
3. Commit: ``git add . && git commit -m "chore: init opencode power kit"``
"@
Set-Content -Path $ReportFile -Value $reportBody -Encoding UTF8
Write-Ok "Tao report: $ReportFile"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  OpenCode Power Kit da cai thanh cong!"     -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Info "Chay verify: opk verify"

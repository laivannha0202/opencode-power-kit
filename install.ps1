# ============================================================================
# OpenCode Power Kit - install.ps1
# Per-project install cho Windows PowerShell. Mirror install.sh.
# Copy templates, merge gitignore, optional BMAD via npx, generate report.
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths ---
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir     = (Resolve-Path $ScriptDir).Path
$TargetDir  = (Get-Location).Path
$ReportFile = Join-Path $TargetDir 'opencode-power-install-report.md'
$Timestamp  = Get-Date -Format 'yyyyMMddHHmmss'
$BackupDir  = Join-Path $TargetDir ".opencode-power-kit-backup-$Timestamp"

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

# --- Safety checks ---
$HomeTrim = $Home.TrimEnd('\','/')
$KitTrim  = $KitDir.TrimEnd('\','/')
$TargetTrim = $TargetDir.TrimEnd('\','/')
if ($TargetTrim -ieq $HomeTrim) {
    Write-Err "Khong duoc chay install.ps1 trong thu muc HOME (~)."
}
if ($TargetTrim -ieq $KitTrim) {
    Write-Err "Khong duoc chay install.ps1 trong thu muc opencode-power-kit."
}
if (-not (Test-Path (Join-Path $KitDir 'templates'))) {
    Write-Err "Khong tim thay thu muc templates/ trong $KitDir"
}

Write-Info "Target project: $TargetDir"
Write-Info "Power Kit source: $KitDir"

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
    'AGENTS.md'              = 'AGENTS.md'
    'OPENCODE.md'            = 'OPENCODE.md'
    'opencode.json'          = '.opencode\opencode.json'
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
Write-Info "Cai dat BMAD Method (module bmm)..."
$npx = Get-Command npx -ErrorAction SilentlyContinue
if ($npx) {
    try {
        & npx --yes bmad-method install `
            --modules bmm `
            --tools opencode `
            --user-name nha `
            --communication-language Vietnamese `
            --document-output-language Vietnamese `
            --directory $TargetDir `
            -y 2>&1 | Select-Object -Last 5
        Write-Ok "BMAD Method da cai xong"
    } catch {
        Write-Warn "BMAD install that bai: $($_.Exception.Message). Bo qua."
    }
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

# ============================================================================
# install-safety-plugin.ps1
#
# Cai safety plugin guard (opk-safety-guard.js) vao project hien tai.
# Plugin duoc copy tu templates/plugins/ vao .opencode/plugins/
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\install-safety-plugin.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\install-safety-plugin.ps1 -Yes
#
# Safety:
#   - Khong admin, khong curl|sh
#   - Chi copy file template, khong xoa file user
#   - Backup neu file da ton tai
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path "$ScriptDir\..").Path

# --- Config ---
$TemplateFile = Join-Path $KitDir 'templates\plugins\opk-safety-guard.js'
$TargetDir    = '.opencode\plugins'
$TargetFile   = '.opencode\plugins\opk-safety-guard.js'

# --- Check template exists ---
if (-not (Test-Path $TemplateFile)) {
    Write-Host "install-safety-plugin: LOI — khong tim thay template: $TemplateFile" -ForegroundColor Red
    exit 1
}

# --- Check if OpenCode project ---
$hasProject = (Test-Path '.opencode\opencode.json') -or (Test-Path 'AGENTS.md') -or (Test-Path 'OPENCODE.md')
if (-not $hasProject) {
    Write-Host "install-safety-plugin: CANH BAO — $(Get-Location) co ve khong phai project OpenCode." -ForegroundColor Yellow
    Write-Host "  (Khong tim thay .opencode\opencode.json, AGENTS.md, hay OPENCODE.md)" -ForegroundColor Yellow
    if (-not $Yes) {
        $reply = Read-Host "  Tiep tuc cai safety plugin? [y/N]"
        if ($reply -notmatch '^[yY]') {
            Write-Host "install-safety-plugin: Da huy." -ForegroundColor Gray
            exit 0
        }
    }
}

# --- Confirm ---
Write-Host "install-safety-plugin: Se cai safety plugin guard vao:"
Write-Host "  Template: $TemplateFile"
Write-Host "  Target:   $(Get-Location)\$TargetFile"
Write-Host ""
Write-Host "  Guard chan:"
Write-Host "    - Doc file nhay cam (.env, secret, private key)"
Write-Host "    - rm -rf, git reset --hard, git clean -fd, force push"
Write-Host "    - SQL DROP TABLE, TRUNCATE, DELETE FROM khong WHERE"
Write-Host ""

if (-not $Yes) {
    $reply = Read-Host "Tiep tuc? [y/N]"
    if ($reply -notmatch '^[yY]') {
        Write-Host "install-safety-plugin: Da huy." -ForegroundColor Gray
        exit 0
    }
}

# --- Create target dir ---
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# --- Backup if exists ---
if (Test-Path $TargetFile) {
    $backup = "$TargetFile.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $TargetFile $backup
    Write-Host "install-safety-plugin: Backup -> $backup"
}

# --- Install ---
Copy-Item $TemplateFile $TargetFile
Write-Host "install-safety-plugin: ✅ Da cai safety plugin guard." -ForegroundColor Green
Write-Host "   File: $(Get-Location)\$TargetFile"
Write-Host ""
Write-Host "   De kiem tra: opk safety-plugin status"
Write-Host "   De go: Remove-Item $TargetFile"

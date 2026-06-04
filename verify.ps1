# ============================================================================
# OpenCode Power Kit - verify.ps1
# Kiem tra project Windows PowerShell da cai dat Power Kit.
# Read-only (chi tao OPK_VERIFY_REPORT.md).
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path $ScriptDir).Path
$ProjectDir = (Get-Location).Path
$ReportFile = Join-Path $ProjectDir 'OPK_VERIFY_REPORT.md'

function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }

if ($Help) {
    Write-Host ""
    Write-Host "OpenCode Power Kit - verify.ps1"
    Write-Host ""
    Write-Host "Kiem tra project da cai dat Power Kit."
    Write-Host "Read-only (chi tao OPK_VERIFY_REPORT.md)."
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  OpenCode Power Kit — verify"             -ForegroundColor Magenta
Write-Host "  Project: $ProjectDir"
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

$ReportChecks = New-Object System.Collections.Generic.List[string]
$Pass = 0; $Warn = 0; $Fail = 0

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $script:ReportChecks.Add("| $Name | $Status | $Detail |") | Out-Null
    switch -Regex ($Status) {
        '^OK'   { $script:Pass++ }
        '^WARN' { $script:Warn++ }
        '^FAIL' { $script:Fail++ }
    }
}

# Required project files
$requiredFiles = @(
    'AGENTS.md',
    'OPENCODE.md',
    '.opencode\opencode.json',
    '.agents\skills',
    '.opencode\commands'
)

foreach ($rel in $requiredFiles) {
    $full = Join-Path $ProjectDir $rel
    if (Test-Path $full) {
        Write-Ok "$rel OK"
        Add-Check $rel 'OK' "ton tai"
    } else {
        Write-Warn "$rel KHONG co. Chay: opk install"
        Add-Check $rel 'WARN' 'khong co'
    }
}

# Secret pattern scan (read-only)
$secretRe = '(?i)(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)\s*[:=]\s*[''"]?[^''"\s]+'
$secretHits = 0
$secretWhere = @()
foreach ($f in @('AGENTS.md', 'OPENCODE.md', '.opencode\opencode.json')) {
    $full = Join-Path $ProjectDir $f
    if (Test-Path $full) {
        $hits = Select-String -Path $full -Pattern $secretRe -ErrorAction SilentlyContinue
        if ($hits) {
            $secretHits += $hits.Count
            $secretWhere += $f
        }
    }
}
if ($secretHits -eq 0) {
    Write-Ok "Khong phat hien secret pattern trong AGENTS.md / OPENCODE.md / .opencode/opencode.json"
    Add-Check 'Secret scan' 'OK' 'khong phat hien'
} else {
    Write-Warn "Phat hien $secretHits secret pattern trong: $($secretWhere -join ', ')"
    Add-Check 'Secret scan' 'WARN' "$secretHits vi tri giong secret"
}

# --- Summary ---
Write-Host ""
Write-Info "Tong ket: $Pass OK / $Warn WARN / $Fail FAIL"

# --- Write report ---
$dateStr = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$reportLines = @()
$reportLines += "# OpenCode Power Kit - Verify Report"
$reportLines += ""
$reportLines += "- **Thoi gian:** $dateStr"
$reportLines += "- **Project:** $ProjectDir"
$reportLines += "- **Power Kit:** $KitDir"
$reportLines += "- **Tong ket:** $Pass OK / $Warn WARN / $Fail FAIL"
$reportLines += ""
$reportLines += "## Checks"
$reportLines += ""
$reportLines += "| File | Status | Detail |"
$reportLines += "|------|--------|--------|"
foreach ($line in $ReportChecks) { $reportLines += $line }
$reportLines += ""
$reportLines += "## Buoc tiep theo"
$reportLines += ""
if ($Fail -gt 0) {
    $reportLines += "- Co loi FAIL — chay ``opk install`` de sua."
} elseif ($Warn -gt 0) {
    $reportLines += "- Co WARN — xem chi tiet ben tren."
} else {
    $reportLines += "- Project san sang. Thu: ``opencode`` + ``/smart-scan``."
}
$reportLines += "- Report: $ReportFile"

Set-Content -Path $ReportFile -Value ($reportLines -join "`n") -Encoding UTF8
Write-Ok "Tao report: $ReportFile"
Write-Host ""

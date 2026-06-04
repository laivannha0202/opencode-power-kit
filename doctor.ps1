# ============================================================================
# OpenCode Power Kit - doctor.ps1
# Chan doan moi truong Windows PowerShell. Read-only (tru report).
# Tao OPK_DOCTOR_REPORT.md.
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path $ScriptDir).Path
$GlobalDir = Join-Path $KitDir 'opencode-global'
$ReportFile = Join-Path $KitDir 'OPK_DOCTOR_REPORT.md'

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Hdr   { Write-Host "============================================" -ForegroundColor Magenta }

if ($Help) {
    Write-Host ""
    Write-Host "OpenCode Power Kit - doctor.ps1"
    Write-Host ""
    Write-Host "Kiem tra moi truong Windows PowerShell."
    Write-Host "Read-only (chi tao OPK_DOCTOR_REPORT.md)."
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Hdr
Write-Host "  OpenCode Power Kit — doctor" -ForegroundColor Magenta
Write-Host "  Kit:  $KitDir"
Write-Host "  Ver:  $((Get-Content (Join-Path $KitDir 'VERSION') -Raw).Trim())"
Write-Hdr
Write-Host ""

# --- Report accumulators ---
$ReportChecks = New-Object System.Collections.Generic.List[string]
$Pass = 0; $Warn = 0; $Fail = 0

function Add-Check {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
    $script:ReportChecks.Add("| $Name | $Status | $Detail |") | Out-Null
    switch -Regex ($Status) {
        '^OK'   { $script:Pass++ }
        '^WARN' { $script:Warn++ }
        '^FAIL' { $script:Fail++ }
    }
}

# 1. Git
try {
    $git = Get-Command git -ErrorAction Stop
    $ver = (& git --version) 2>&1 | Select-Object -First 1
    Write-Ok "git OK: $ver"
    Add-Check 'git' 'OK' $ver
} catch {
    Write-Warn "git KHONG tim thay (can de clone/push)."
    Add-Check 'git' 'WARN' 'khong tim thay'
}

# 2. PowerShell version
$psv = $PSVersionTable.PSVersion
if ($psv.Major -ge 5) {
    Write-Ok "PowerShell $psv OK"
    Add-Check 'PowerShell' 'OK' "v$psv"
} else {
    Write-Warn "PowerShell $psv (nen dung >= 5.1)"
    Add-Check 'PowerShell' 'WARN' "v$psv (nen >= 5.1)"
}

# 3. OPK_KIT_DIR
$opkKit = $env:OPK_KIT_DIR
if ($opkKit -and (Test-Path (Join-Path $opkKit 'install-global.ps1'))) {
    Write-Ok "OPK_KIT_DIR = $opkKit (User env)"
    Add-Check 'OPK_KIT_DIR' 'OK' $opkKit
} else {
    Write-Warn "OPK_KIT_DIR chua set hoac khong hop le. Chay: .\install-global.ps1"
    Add-Check 'OPK_KIT_DIR' 'WARN' 'chua set hoac khong hop le'
}

# 4. OPENCODE_CONFIG_DIR
$opkCfg = $env:OPENCODE_CONFIG_DIR
if ($opkCfg -and (Test-Path $opkCfg)) {
    Write-Ok "OPENCODE_CONFIG_DIR = $opkCfg"
    Add-Check 'OPENCODE_CONFIG_DIR' 'OK' $opkCfg
} else {
    Write-Warn "OPENCODE_CONFIG_DIR chua set hoac khong hop le. Chay: .\install-global.ps1"
    Add-Check 'OPENCODE_CONFIG_DIR' 'WARN' 'chua set hoac khong hop le'
}

# 5. User PATH has .opencode-power-kit\bin
$userOpkBin = Join-Path $Home '.opencode-power-kit\bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$inPath = $false
if ($userPath) {
    foreach ($p in ($userPath -split ';')) {
        if ($p.TrimEnd('\') -ieq $userOpkBin.TrimEnd('\')) { $inPath = $true; break }
    }
}
if ($inPath) {
    Write-Ok "User PATH co $userOpkBin"
    Add-Check 'User PATH' 'OK' "$userOpkBin trong User PATH"
} else {
    Write-Warn "User PATH chua co $userOpkBin. Chay: .\install-global.ps1"
    Add-Check 'User PATH' 'WARN' "$userOpkBin chua co trong User PATH"
}

# 6. opk.cmd + opk.ps1 exist
$opkCmd = Join-Path $userOpkBin 'opk.cmd'
$opkPs1 = Join-Path $userOpkBin 'opk.ps1'
if ((Test-Path $opkCmd) -and (Test-Path $opkPs1)) {
    Write-Ok "opk.cmd + opk.ps1 ton tai"
    Add-Check 'opk shim' 'OK' "$opkCmd"
} else {
    Write-Warn "opk.cmd / opk.ps1 chua co. Chay: .\install-global.ps1"
    Add-Check 'opk shim' 'WARN' 'thieu opk.cmd hoac opk.ps1'
}

# 7. opencode-global structure
$agentsOk = Test-Path (Join-Path $GlobalDir 'agents')
$cmdOk    = Test-Path (Join-Path $GlobalDir 'commands')
$sklOk    = Test-Path (Join-Path $GlobalDir 'skills')
if ($agentsOk -and $cmdOk -and $sklOk) {
    $ac = (Get-ChildItem (Join-Path $GlobalDir 'agents')   -Recurse -File -Filter '*.md' -EA SilentlyContinue | Measure-Object).Count
    $cc = (Get-ChildItem (Join-Path $GlobalDir 'commands') -Recurse -File -Filter '*.md' -EA SilentlyContinue | Measure-Object).Count
    $sc = (Get-ChildItem (Join-Path $GlobalDir 'skills')   -Recurse -Directory -EA SilentlyContinue | Where-Object { $_.FullName -ne (Join-Path $GlobalDir 'skills') } | Measure-Object).Count
    Write-Ok "opencode-global/ OK: $ac agents, $cc commands, $sc skills"
    Add-Check 'opencode-global' 'OK' "$ac agents, $cc commands, $sc skills"
} else {
    Write-Err "opencode-global/ thieu thu muc con."
    Add-Check 'opencode-global' 'FAIL' 'thieu agents/commands/skills'
}

# 8. No MCP config
$mcpCfg = Join-Path $Home '.config\opencode\mcp.json'
if (Test-Path $mcpCfg) {
    Write-Warn "MCP config hien co: $mcpCfg (kit KHONG sua)"
    Add-Check 'MCP config' 'WARN' "$mcpCfg ton tai (kit khong sua)"
} else {
    Write-Ok "Khong co MCP config (kit khong tao/sua)"
    Add-Check 'MCP config' 'OK' 'khong co MCP config'
}

# 9. Secret pattern scan (read-only)
$secretRe = '(?i)(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)\s*[:=]\s*[''"]?[^''"\s]+'
$secretHits = 0
$secretWhere = @()
foreach ($f in @('AGENTS.md', 'OPENCODE.md', 'README.md', 'CHANGELOG.md')) {
    $p = Join-Path $KitDir $f
    if (Test-Path $p) {
        $hits = Select-String -Path $p -Pattern $secretRe -ErrorAction SilentlyContinue
        if ($hits) {
            $secretHits += $hits.Count
            $secretWhere += $f
        }
    }
}
if ($secretHits -eq 0) {
    Write-Ok "Khong phat hien secret pattern trong AGENTS.md / OPENCODE.md / README.md / CHANGELOG.md"
    Add-Check 'Secret scan' 'OK' 'khong phat hien'
} else {
    Write-Warn "Phat hien $secretHits secret pattern trong: $($secretWhere -join ', ')"
    Add-Check 'Secret scan' 'WARN' "$secretHits vi tri giong secret"
}

# 10. Optional tools (WARN only, not fail)
$optionalTools = @('git', 'node', 'npm', 'pnpm', 'docker', 'rg', 'fd', 'jq', 'gitleaks', 'semgrep', 'spectral', 'biome', 'knip')
$toolResults = @()
foreach ($t in $optionalTools) {
    $found = $false
    try {
        $cmd = Get-Command $t -ErrorAction Stop
        if ($cmd) {
            $line = (& $t --version 2>&1 | Select-Object -First 1)
            if (-not $line) { $line = 'co' }
            $toolResults += [PSCustomObject]@{ Tool = $t; Status = 'OK'; Detail = $line }
            $found = $true
        }
    } catch {}
    if (-not $found) {
        $toolResults += [PSCustomObject]@{ Tool = $t; Status = 'WARN'; Detail = 'khong co (optional)' }
    }
}

Write-Host ""
Write-Info "Optional tools (WARN neu thieu, khong fail):"
foreach ($r in $toolResults) {
    if ($r.Status -eq 'OK') {
        Write-Host "  [OK]   $($r.Tool): $($r.Detail)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $($r.Tool): $($r.Detail)" -ForegroundColor Yellow
    }
}

# --- Summary ---
Write-Host ""
Write-Info "Tong ket: $Pass OK / $Warn WARN / $Fail FAIL"
if ($Fail -gt 0) {
    Write-Err "Co $Fail loi can fix truoc khi dung."
}

# --- Write report ---
$dateStr = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$reportLines = @()
$reportLines += "# OpenCode Power Kit - Doctor Report"
$reportLines += ""
$reportLines += "- **Thoi gian:** $dateStr"
$reportLines += "- **Power Kit:** $KitDir"
$reportLines += "- **Ver:** $((Get-Content (Join-Path $KitDir 'VERSION') -Raw).Trim())"
$reportLines += "- **OS:** $($env:OS) / PS $($PSVersionTable.PSVersion)"
$reportLines += "- **Tong ket:** $Pass OK / $Warn WARN / $Fail FAIL"
$reportLines += ""
$reportLines += "## Checks"
$reportLines += ""
$reportLines += "| Check | Status | Detail |"
$reportLines += "|-------|--------|--------|"
foreach ($line in $ReportChecks) { $reportLines += $line }
$reportLines += ""
$reportLines += "## Optional tools"
$reportLines += ""
$reportLines += "| Tool | Status | Detail |"
$reportLines += "|------|--------|--------|"
foreach ($r in $toolResults) {
    $reportLines += "| $($r.Tool) | $($r.Status) | $($r.Detail) |"
}
$reportLines += ""
$reportLines += "## Buoc tiep theo neu co loi"
$reportLines += ""
$reportLines += '1. `powershell -ExecutionPolicy Bypass -File .\install-global.ps1 -Yes` (cai global)'
$reportLines += '2. Mo shell moi (de load User PATH)'
$reportLines += '3. `opk help`'
$reportLines += "4. Xem chi tiet: $ReportFile"

Set-Content -Path $ReportFile -Value ($reportLines -join "`n") -Encoding UTF8
Write-Ok "Tao report: $ReportFile"
Write-Host ""

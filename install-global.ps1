# ============================================================================
# OpenCode Power Kit - install-global.ps1
# Cai dat config global cho Windows PowerShell. Khong can admin, khong sudo.
# Idempotent: chay lai khong duplicate marker / PATH / shim.
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir    = (Resolve-Path $ScriptDir).Path
$GlobalDir = Join-Path $KitDir 'opencode-global'

$ReportFile    = Join-Path $KitDir 'GLOBAL_INSTALL_REPORT.md'
$PackReport    = Join-Path $KitDir 'GLOBAL_PACK_REPORT.md'
$Timestamp     = Get-Date -Format 'yyyyMMddHHmmss'
$BackupRoot    = Join-Path $Home ".opencode-power-kit-backup-$Timestamp"

# User env / paths
$UserOpencodeBin = Join-Path $Home '.opencode-power-kit\bin'
$OpkCmdSrc       = Join-Path $KitDir 'bin\opk.cmd'
$OpkPs1Src       = Join-Path $KitDir 'bin\opk.ps1'
$OpkCmdDst       = Join-Path $UserOpencodeBin 'opk.cmd'
$OpkPs1Dst       = Join-Path $UserOpencodeBin 'opk.ps1'

# --- Helpers ---
function Write-Info  { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }
function Write-Hdr   { Write-Host "============================================" -ForegroundColor Magenta }

# --- Verify opencode-global exists ---
if (-not (Test-Path $GlobalDir)) {
    Write-Err "Khong tim thay $GlobalDir — thu muc opencode-global khong ton tai."
}
if (-not ((Test-Path (Join-Path $GlobalDir 'agents')) -and
          (Test-Path (Join-Path $GlobalDir 'commands')) -and
          (Test-Path (Join-Path $GlobalDir 'skills')))) {
    Write-Err "Thieu thu muc con trong opencode-global/ (agents, commands, skills)."
}
if (-not (Test-Path $OpkCmdSrc)) { Write-Err "Thieu $OpkCmdSrc." }
if (-not (Test-Path $OpkPs1Src)) { Write-Err "Thieu $OpkPs1Src." }

# Resolve kit dir that
$KitReal = (Resolve-Path $KitDir).Path

# --- Help ---
function Show-Help {
    Write-Host ""
    Write-Host "OpenCode Power Kit - install-global.ps1"
    Write-Host ""
    Write-Host "Cai global cho Windows PowerShell."
    Write-Host "Khong can admin. Khong sua registry system-wide."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\install-global.ps1"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\install-global.ps1 -Yes"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\install-global.ps1 -DryRun"
    Write-Host ""
    Write-Host "Flags:"
    Write-Host "  -Yes     Skip confirm"
    Write-Host "  -DryRun  Chi in ke hoach, khong sua"
    Write-Host "  -Help    In tro giup"
    Write-Host ""
}
if ($Help) { Show-Help; exit 0 }

Write-Info "Power Kit source: $KitReal"
Write-Info "Global config dir target: $KitReal\opencode-global"
Write-Info "User opk bin: $UserOpencodeBin"

# --- Confirm ---
if (-not $Yes) {
    $ans = Read-Host "Cai global? (se tao shim, them vao User PATH) [Y/n]"
    if ($ans -notin @('','Y','y','yes','YES')) {
        Write-Info "Da huy."
        exit 0
    }
}

# --- DryRun: in ke hoach, khong sua ---
if ($DryRun) {
    Write-Host ""
    Write-Info "[DRY-RUN] Se chay:"
    Write-Host "  - Backup neu co file cu"
    Write-Host "  - Tao $UserOpencodeBin"
    Write-Host "  - Copy shim opk.cmd + opk.ps1"
    Write-Host "  - Set User env: OPK_KIT_DIR=$KitReal"
    Write-Host "  - Set User env: OPENCODE_CONFIG_DIR=$KitReal\opencode-global"
    Write-Host "  - Add $UserOpencodeBin vao User PATH"
    Write-Host "  - Tao reports"
    exit 0
}

# --- Backup old files ---
$BackedUp = $false
if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

if (Test-Path $OpkCmdDst) {
    $bkCmd = Join-Path $BackupRoot 'opk.cmd'
    Copy-Item -Path $OpkCmdDst -Destination $bkCmd -Force
    Write-Ok "Da backup $OpkCmdDst -> $bkCmd"
    $BackedUp = $true
}
if (Test-Path $OpkPs1Dst) {
    $bkPs1 = Join-Path $BackupRoot 'opk.ps1'
    Copy-Item -Path $OpkPs1Dst -Destination $bkPs1 -Force
    Write-Ok "Da backup $OpkPs1Dst -> $bkPs1"
    $BackedUp = $true
}
if (Test-Path (Join-Path $Home '.config\opencode\opencode.json')) {
    $bkJson = Join-Path $BackupRoot 'opencode.json'
    New-Item -ItemType Directory -Path (Split-Path $bkJson) -Force | Out-Null
    Copy-Item -Path (Join-Path $Home '.config\opencode\opencode.json') -Destination $bkJson -Force
    Write-Ok "Da backup opencode.json"
    $BackedUp = $true
}

# --- Tao $UserOpencodeBin ---
if (-not (Test-Path $UserOpencodeBin)) {
    New-Item -ItemType Directory -Path $UserOpencodeBin -Force | Out-Null
    Write-Ok "Tao $UserOpencodeBin"
} else {
    Write-Info "$UserOpencodeBin da ton tai."
}

# --- Re-generate shim: opk.cmd + opk.ps1 ---
# Ly do: opk.cmd can biet OPK_KIT_DIR de goi opk.ps1. Copy nguyen xi
# bin/opk.cmd + bin/opk.ps1 se KHONG nhan OPK_KIT_DIR, nen tao shim rieng.
Write-Info "Cai opk shim..."

# Regenerate opk.cmd (write OPK_KIT_DIR inline)
@"
@echo off
REM Auto-generated by install-global.ps1 — DO NOT EDIT BY HAND.
REM Re-generate bang: powershell -ExecutionPolicy Bypass -File "$KitReal\install-global.ps1" -Yes
set OPK_KIT_DIR=$KitReal
powershell -ExecutionPolicy Bypass -File "%OPK_KIT_DIR%\bin\opk.ps1" %*
exit /b %ERRORLEVEL%
"@ | Out-File -FilePath $OpkCmdDst -Encoding ASCII -Force

# Copy opk.ps1 as-is (opk.ps1 tu detect OPK_KIT_DIR tu env)
Copy-Item -Path $OpkPs1Src -Destination $OpkPs1Dst -Force
Write-Ok "Da cai shim: $OpkCmdDst"

# --- Set user env: OPK_KIT_DIR + OPENCODE_CONFIG_DIR (idempotent) ---
function Set-UserEnv {
    param([string]$Name, [string]$Value)
    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($existing -eq $Value) {
        Write-Info "User env $Name = $Value (da co, giu nguyen)"
        return
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Write-Ok "Set User env $Name = $Value"
}

Set-UserEnv 'OPK_KIT_DIR'          $KitReal
Set-UserEnv 'OPENCODE_CONFIG_DIR'  (Join-Path $KitReal 'opencode-global')

# --- Add $UserOpencodeBin to User PATH (idempotent) ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
$pathParts = $userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }
$alreadyInPath = $false
foreach ($p in $pathParts) {
    if ($p.TrimEnd('\') -ieq $UserOpencodeBin.TrimEnd('\')) {
        $alreadyInPath = $true
        break
    }
}
if ($alreadyInPath) {
    Write-Info "User PATH da co $UserOpencodeBin"
} else {
    $newPath = if ($userPath) { "$UserOpencodeBin;$userPath" } else { $UserOpencodeBin }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Ok "Add $UserOpencodeBin vao User PATH"
}

# --- Update $env:Path for current session ---
if ($env:Path -notlike "*$UserOpencodeBin*") {
    $env:Path = "$UserOpencodeBin;$env:Path"
    Write-Ok "Cap nhat `$env:Path cho session hien tai"
}

# --- Verify opk.cmd can find kit ---
$verifyOut = & cmd /c "$OpkCmdDst path" 2>&1
if ($LASTEXITCODE -eq 0 -and $verifyOut) {
    Write-Ok "opk.cmd path OK: $verifyOut"
} else {
    Write-Warn "opk.cmd installed nhung 'opk.cmd path' khong hoat dong. Kiem tra thu cong."
}

# --- Safety: no secrets in config (read-only scan) ---
$SecretPattern = '(?i)(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)'
$SafetyIssues = 0

$cfgJson = Join-Path $KitReal 'opencode-global\opencode.json'
if (Test-Path $cfgJson) {
    if (Select-String -Path $cfgJson -Pattern $SecretPattern -ErrorAction SilentlyContinue) {
        Write-Warn "$cfgJson co chua chuoi giong secret. Kiem tra thu cong."
        $SafetyIssues++
    }
}
foreach ($f in @('AGENTS.md', 'OPENCODE.md')) {
    $p = Join-Path $KitReal $f
    if (Test-Path $p) {
        if (Select-String -Path $p -Pattern $SecretPattern -ErrorAction SilentlyContinue) {
            Write-Warn "$p co chua chuoi giong secret. Kiem tra thu cong."
            $SafetyIssues++
        }
    }
}

# --- Count items in pack ---
$CountAgents   = (Get-ChildItem -Path (Join-Path $GlobalDir 'agents')   -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | Measure-Object).Count
$CountCommands = (Get-ChildItem -Path (Join-Path $GlobalDir 'commands') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | Measure-Object).Count
$CountSkills   = (Get-ChildItem -Path (Join-Path $GlobalDir 'skills')   -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne (Join-Path $GlobalDir 'skills') } | Measure-Object).Count

# --- Generate GLOBAL_INSTALL_REPORT.md ---
$bkLine = if ($BackedUp) { "- Backup tai: $BackupRoot" } else { "- Khong co file can backup" }
$reportBody = @"
# OpenCode Power Kit - Global Install Report

- **Thoi gian:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Power Kit:** $KitReal
- **Global config dir:** $KitReal\opencode-global
- **User opk bin:** $UserOpencodeBin
- **OS:** $($env:OS) / PS $($PSVersionTable.PSVersion)

## Files da cai dat

| Muc | Trang thai |
|-----|-----------|
| OPK_KIT_DIR (User env) | OK |
| OPENCODE_CONFIG_DIR (User env) | OK |
| $UserOpencodeBin in User PATH | OK |
| opencode-global/ structure | OK ($CountAgents agents, $CountCommands commands, $CountSkills skills) |
| opk.cmd shim | OK $OpkCmdDst |
| opk.ps1 shim | OK $OpkPs1Dst |

## Backup

$bkLine

## Safety

- $(if ($SafetyIssues -eq 0) { 'OK Khong phat hien secret pattern.' } else { "WARN Phat hien $SafetyIssues vi tri giong secret — kiem tra thu cong." })
- Khong sua registry system-wide, chi User environment.
- Khong sudo, khong curl|sh.
- Khong sua MCP config hien co.
- Khong xoa file user.

## Buoc tiep theo

1. Mo shell moi (de load User PATH)
2. ``opk help``
3. ``opk path``
4. ``opk version``
5. ``opencode``
6. Thu: ``/smart-scan``, ``/repo-map``, ``/bugfix-safe``, ``/review-diff``
"@
Set-Content -Path $ReportFile -Value $reportBody -Encoding UTF8
Write-Ok "Tao report: $ReportFile"

# --- Generate GLOBAL_PACK_REPORT.md (dynamic inventory) ---
$packLines = @()
$packLines += "# OpenCode Power Kit - Global Pack Report"
$packLines += ""
$packLines += "- **Thoi gian cap nhat:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$packLines += "- **Repo:** $KitReal"
$packLines += "- **Ver:** $((Get-Content (Join-Path $KitReal 'VERSION') -Raw).Trim())"
$packLines += ""
$packLines += "## Tong quan"
$packLines += ""
$packLines += "| Muc | So luong | Vi tri |"
$packLines += "|-----|----------|---------|"
$packLines += "| Agents   | $CountAgents | ``opencode-global\agents\`` |"
$packLines += "| Commands | $CountCommands | ``opencode-global\commands\`` |"
$packLines += "| Skills   | $CountSkills | ``opencode-global\skills\`` |"
$packLines += "| opk CLI  | OK | ``$OpkCmdDst`` |"
$packLines += ""
$packLines += "## Agents installed"
$packLines += ""
if ($CountAgents -gt 0) {
    $packLines += "| Agent | File |"
    $packLines += "|-------|------|"
    Get-ChildItem -Path (Join-Path $GlobalDir 'agents') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
        Sort-Object FullName | ForEach-Object {
            $base = $_.Name
            $packLines += "| ``$base`` | ``opencode-global\agents\$base`` |"
        }
} else {
    $packLines += "_Chua co agent nao._"
}
$packLines += ""
$packLines += "## Commands installed"
$packLines += ""
if ($CountCommands -gt 0) {
    $packLines += "| Command | File |"
    $packLines += "|---------|------|"
    Get-ChildItem -Path (Join-Path $GlobalDir 'commands') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
        Sort-Object FullName | ForEach-Object {
            $base = $_.Name
            $stem = $base -replace '\.md$',''
            $packLines += "| ``/$stem`` | ``opencode-global\commands\$base`` |"
        }
} else {
    $packLines += "_Chua co command nao._"
}
$packLines += ""
$packLines += "## Skills installed"
$packLines += ""
if ($CountSkills -gt 0) {
    $packLines += "| Skill | Vi tri |"
    $packLines += "|-------|--------|"
    Get-ChildItem -Path (Join-Path $GlobalDir 'skills') -Directory -ErrorAction SilentlyContinue |
        Sort-Object FullName | ForEach-Object {
            $name = $_.Name
            $packLines += "| ``$name`` | ``opencode-global\skills\$name\`` |"
        }
} else {
    $packLines += "_Chua co skill nao._"
}
$packLines += ""
$packLines += "## opk CLI"
$packLines += ""
$packLines += "- **Path:** ``$OpkCmdDst``"
$userPathNow = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPathNow -like "*$UserOpencodeBin*") {
    $packLines += "- **User PATH:** OK ``$UserOpencodeBin`` da co trong User PATH"
} else {
    $packLines += "- **User PATH:** WARN ``$UserOpencodeBin`` chua co trong User PATH. Mo shell moi."
}
$packLines += ""
$packLines += "Lenh kha dung: ``opk help``, ``opk version``, ``opk path``, ``opk global``, ``opk install``, ``opk fullstack``, ``opk all``, ``opk doctor``, ``opk verify``, ``opk tools``, ``opk bootstrap``, ``opk one``, ``opk quick``, ``opk init``, ``opk taste``."
$packLines += ""
$packLines += "## Buoc tiep theo"
$packLines += ""
$packLines += '1. Mo shell moi (de load User PATH)'
$packLines += '2. `opk help`'
$packLines += '3. `opk path`'
$packLines += '4. `opk version`'
$packLines += '5. `opencode`'
$packLines += '6. Thu: `/taste-polish`, `/smart-scan`, `/repo-map`, `/bugfix-safe`, `/review-diff`'
$packLines += ""
$packLines += "## An toan"
$packLines += ""
$packLines += "- Khong token / password / secrets trong repo."
$packLines += "- Khong sua registry system-wide, chi User environment."
$packLines += "- Khong sudo, khong ``curl|sh``."
$packLines += "- Khong sua MCP config hien co."
$packLines += "- Khong xoa file user."
$packLines += "- Backup file cu vao ``$BackupRoot`` neu co."

$packBody = ($packLines -join "`n")
Set-Content -Path $PackReport -Value $packBody -Encoding UTF8
Write-Ok "Tao report: $PackReport"

# --- Taste Skill: suggest (verify-gated, not auto-installed since v2.0.0) ---
Write-Host ""
Write-Info "Taste Skill (UI/UX design) is optional and NOT auto-installed."
Write-Info "To install:  opk taste install"
Write-Info "To check:    opk taste doctor"

# --- Final summary ---
Write-Host ""
Write-Hdr
Write-Host "  Global Install hoan tat!" -ForegroundColor Green
Write-Hdr
Write-Host ""
Write-Info "Da cai:"
Write-Info "  - opencode-global/: $CountAgents agents, $CountCommands commands, $CountSkills skills"
Write-Info "  - opk.cmd shim:    $OpkCmdDst"
Write-Info "  - opk.ps1 shim:    $OpkPs1Dst"
Write-Info "  - User env:        OPK_KIT_DIR, OPENCODE_CONFIG_DIR"
Write-Info "  - User PATH:       +$UserOpencodeBin"
Write-Info "  - Reports:         $ReportFile"
Write-Info "                     $PackReport"
Write-Host ""
Write-Info "Buoc tiep theo:"
Write-Info "  1) Mo shell moi (de load PATH)"
Write-Info "  2) opk help"
Write-Info "  3) opk path"
Write-Info "  4) opencode"
Write-Info "  5) Thu /taste-polish  hoac  /smart-scan"
Write-Host ""

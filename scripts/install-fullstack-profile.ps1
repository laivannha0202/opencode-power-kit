# ============================================================================
# OpenCode Power Kit - install-fullstack-profile.ps1
# PowerShell port of scripts/install-fullstack-profile.sh
# Append profile rules via marker (idempotent), copy commands + skills.
# ============================================================================
[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# --- Resolve kit dir (this script lives in $KitDir\scripts\) ---
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir     = (Resolve-Path $ScriptDir\..).Path
$ProfileDir = Join-Path $KitDir 'profiles\node-nest-react-mysql'

if (-not (Test-Path $ProfileDir)) {
    Write-Host "[ERROR] Khong tim thay profile tai $ProfileDir" -ForegroundColor Red
    exit 1
}

# --- Resolve project dir (pwd) ---
$ProjectDir = (Get-Location).Path

# --- Helpers ---
function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

# --- Safety: refuse HOME or kit ---
$HomeTrim = $Home.TrimEnd('\','/')
$KitTrim  = $KitDir.TrimEnd('\','/')
$ProjTrim = $ProjectDir.TrimEnd('\','/')
if ($ProjTrim -ieq $HomeTrim) {
    Write-Err "Khong chay script trong HOME ($Home). Vao project roi chay lai."
}
if ($ProjTrim -ieq $KitTrim) {
    Write-Err "Khong chay script trong chinh opencode-power-kit ($KitDir)."
}

# --- Check project has package.json or .git ---
$pkgJson = Join-Path $ProjectDir 'package.json'
$gitDir  = Join-Path $ProjectDir '.git'
if (-not (Test-Path $pkgJson) -and -not (Test-Path $gitDir)) {
    Write-Warn "Project hien tai khong co package.json hoac .git. Co the khong phai project Node."
    if (-not $Yes) {
        $ans = Read-Host "Tiep tuc? [y/N]"
        if ($ans -notin @('y','Y','yes','YES')) {
            Write-Info "Da huy."
            exit 0
        }
    }
}

$ReportFile = Join-Path $ProjectDir 'FULLSTACK_PROFILE_REPORT.md'
$Timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir  = Join-Path $ProjectDir ".opencode-power-kit-backup-$Timestamp"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OpenCode Power Kit - Full-Stack Profile" -ForegroundColor Cyan
Write-Host "  (NestJS + React/Vite + MySQL)"            -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "Project: $ProjectDir"
Write-Info "Kit:     $KitDir"
Write-Info "Profile: $ProfileDir"
Write-Host ""

# --- Backup helper ---
function Backup-IfExists {
    param([string]$Rel)
    $src = Join-Path $ProjectDir $Rel
    if (Test-Path $src) {
        $dst = Join-Path $BackupDir $Rel
        $dstDir = Split-Path $dst
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        Copy-Item -Path $src -Destination $dst -Force
        Write-Ok "backup: $Rel -> $dst"
    }
}

Write-Info "Backup target: $BackupDir"
Backup-IfExists 'AGENTS.md'
Backup-IfExists 'OPENCODE.md'

# --- Append via marker ---
$MarkerBegin = '<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->'
$MarkerEnd   = '<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-end -->'

function Append-MarkerBlock {
    param(
        [string]$KitRel,
        [string]$ProjectRel,
        [string]$Label
    )
    $src = Join-Path $KitDir $KitRel
    $dst = Join-Path $ProjectDir $ProjectRel

    if (-not (Test-Path $src)) {
        Write-Warn "Khong tim thay source $src — skip $Label."
        return
    }

    if (-not (Test-Path $dst)) {
        $dstDir = Split-Path $dst
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        Copy-Item -Path $src -Destination $dst -Force
        Write-Ok "tao moi: $ProjectRel (tu $KitRel)"
        return
    }

    $content = Get-Content $dst -Raw
    if ($content -match [regex]::Escape($MarkerBegin)) {
        Write-Ok "$ProjectRel da co marker. Skip append."
        return
    }

    Add-Content -Path $dst -Value ""
    Add-Content -Path $dst -Value ""
    Get-Content $src | Add-Content -Path $dst
    Write-Ok "append: $ProjectRel (+ $Label)"
}

Write-Info "Append AGENTS rules..."
Append-MarkerBlock "profiles\node-nest-react-mysql\AGENTS.append.md" "AGENTS.md" "fullstack rules"

Write-Info "Append OPENCODE workflow..."
Append-MarkerBlock "profiles\node-nest-react-mysql\OPENCODE.append.md" "OPENCODE.md" "fullstack workflow"

# --- Copy commands ---
$cmdsSrc = Join-Path $ProfileDir 'commands'
$cmdsDst = Join-Path $ProjectDir '.opencode\commands\fullstack'
if (-not (Test-Path $cmdsDst)) { New-Item -ItemType Directory -Path $cmdsDst -Force | Out-Null }

if (Test-Path $cmdsSrc) {
    $cmdCount = 0
    Get-ChildItem -Path $cmdsSrc -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $base = $_.Name
        Copy-Item -Path $_.FullName -Destination (Join-Path $cmdsDst $base) -Force
        Write-Ok "command: .opencode\commands\fullstack\$base"
        $script:cmdCount++
    }
    Write-Info "Copied $cmdCount profile commands."
} else {
    Write-Warn "Khong tim thay $cmdsSrc — skip commands."
}

# --- Copy skills ---
$skillsSrc = Join-Path $ProfileDir 'skills'
$skillsDst = Join-Path $ProjectDir '.agents\skills'
if (-not (Test-Path $skillsDst)) { New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null }

if (Test-Path $skillsSrc) {
    $skillCount = 0
    Get-ChildItem -Path $skillsSrc -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        $dst = Join-Path $skillsDst $name
        if (Test-Path $dst) {
            Write-Warn "skill $name da ton tai — skip (khong overwrite)."
            return
        }
        Copy-Item -Path $_.FullName -Destination $dst -Recurse -Force
        Write-Ok "skill: .agents\skills\$name"
        $script:skillCount++
    }
    Write-Info "Copied $skillCount profile skills."
} else {
    Write-Warn "Khong tim thay $skillsSrc — skip skills."
}

# --- Generate report ---
$bkLine = if (Test-Path $BackupDir) { "- **Location:** $BackupDir`n- AGENTS.md + OPENCODE.md da backup truoc khi append (neu ton tai)." } else { "- Khong co file can backup" }

$reportBody = @"
# Full-Stack Profile Install Report

- **Thoi gian:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Project:** $ProjectDir
- **Kit:** $KitDir
- **Profile:** $ProfileDir

## Files appended

| File | Action | Notes |
|------|--------|-------|
| AGENTS.md | appended | marker idempotent |
| OPENCODE.md | appended | marker idempotent |

## Commands copied

| Source | Dest |
|--------|------|
| profiles\node-nest-react-mysql\commands\*.md | .opencode\commands\fullstack\ |

## Skills copied

| Source | Dest |
|--------|------|
| profiles\node-nest-react-mysql\skills\*\ | .agents\skills\ |

## Backup

$bkLine

## An toan

- KHONG sudo.
- KHONG curl|sh.
- KHONG tu cai dependency nang.
- KHONG ghi de file user (chi append voi marker, hoac skip neu conflict).
- KHONG chay trong HOME hoac trong $KitDir.

## Buoc tiep theo

1. Doc phan append trong AGENTS.md / OPENCODE.md.
2. Chay ``/fullstack-scan`` trong OpenCode de xem project trong the nao.
3. Chay ``/env-doctor`` va ``/docker-dev-doctor`` neu co docker-compose.
4. Neu khong thich, restore tu $BackupDir.
"@
Set-Content -Path $ReportFile -Value $reportBody -Encoding UTF8
Write-Ok "Tao report: $ReportFile"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Cai full-stack profile xong"            -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Info "Report: $ReportFile"
if (Test-Path $BackupDir) {
    Write-Info "Backup: $BackupDir"
}

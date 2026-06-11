# ─────────────────────────────────────────────────────────────────
# install-taste-skill.ps1
# opencode-power-kit v1.7.0
#
# PowerShell mirror of scripts/install-taste-skill.sh.
#
# Optional integration with Leonxlnx/taste-skill.
# Installs the official npm package via npx when the user
# explicitly requests it.
#
# See THIRD_PARTY.md for details.
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$ScriptName = 'install-taste-skill.ps1'
$TastePackage = 'Leonxlnx/taste-skill'
$SkipTaste = [System.Environment]::GetEnvironmentVariable('OPK_SKIP_TASTE')

# ─── Helpers ──────────────────────────────────────────────────────
function Write-Plan($cmdLine) {
    Write-Host '=== install-taste-skill (PowerShell) ==='
    Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
    Write-Host "Package:       $TastePackage"
    Write-Host "Command:       $cmdLine"
    Write-Host ''
}

# ─── Check for skip env var ──────────────────────────────────────
if ($SkipTaste -eq '1') {
    Write-Host '=== install-taste-skill ==='
    Write-Host 'OPK_SKIP_TASTE=1 — bỏ qua cài đặt Taste Skill.'
    exit 0
}

# ─── Pre-flight: node + npx (graceful: only warn, don't fail) ────
$node = Get-Command node -ErrorAction SilentlyContinue
$npx  = Get-Command npx -ErrorAction SilentlyContinue

if ((-not $node) -or (-not $npx)) {
    Write-Host '=== install-taste-skill ===' -ForegroundColor Yellow
    Write-Host '⚠️  node/npx không tìm thấy. Taste Skill yêu cầu Node.js.' -ForegroundColor Yellow
    Write-Host '   Bỏ qua cài đặt. Install Node.js từ https://nodejs.org' -ForegroundColor Yellow
    Write-Host "   rồi chạy lại: npx skills add $TastePackage" -ForegroundColor Yellow
    exit 0
}

$nodeVersion = & $node.Source --version 2>&1
Write-Host '=== install-taste-skill ==='
Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
Write-Host "Node:          $($node.Source) ($nodeVersion)"
Write-Host "npx:           $($npx.Source)"
Write-Host "Package:       $TastePackage"
Write-Host ''

# ─── Detect if already installed ──────────────────────────────────
$alreadyInstalled = $false
$tasteDir = Join-Path $HOME '.config/opencode/skills/taste-skill'
if (Test-Path (Join-Path $tasteDir 'SKILL.md')) {
    $alreadyInstalled = $true
    Write-Host "ℹ️  Taste Skill đã được cài đặt tại: $tasteDir" -ForegroundColor Cyan
}

# ─── Plan ─────────────────────────────────────────────────────────
$installCmd = @($npx.Source, 'skills', 'add', $TastePackage)
$cmdLine = $installCmd -join ' '

Write-Host 'Plan:'
Write-Host "  Command:  $cmdLine"
Write-Host '  Sudo:     NO'
Write-Host '  curl|sh:  NO'
Write-Host ''

# ─── Dry run ──────────────────────────────────────────────────────
if ($DryRun) {
    Write-Plan $cmdLine
    Write-Host 'Dry run complete. Re-run with -Yes to install.'
    exit 0
}

if ($alreadyInstalled) {
    Write-Host '✅ Taste Skill đã được cài đặt.' -ForegroundColor Green
    exit 0
}

# ─── Interactive confirmation ─────────────────────────────────────
if (-not $Yes) {
    $reply = Read-Host "Install '$TastePackage' via npx now? [y/N]"
    if ($reply -notin @('y','Y','yes','YES')) {
        Write-Host 'aborted.'
        exit 0
    }
}

# ─── Install ──────────────────────────────────────────────────────
Write-Host "==> $cmdLine"
try {
    & $installCmd[0] $installCmd[1..($installCmd.Length-1)]
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Taste Skill installation failed (network or npx issue)." -ForegroundColor Yellow
        Write-Host "   Bạn có thể thử lại sau: npx skills add $TastePackage" -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Host "⚠️  Taste Skill installation failed: $_" -ForegroundColor Yellow
    Write-Host "   Bạn có thể thử lại sau: npx skills add $TastePackage" -ForegroundColor Yellow
    exit 0
}
Write-Host ''

# ─── Verify ───────────────────────────────────────────────────────
if (Test-Path (Join-Path $tasteDir 'SKILL.md')) {
    Write-Host '✅ Taste Skill installed at: $tasteDir' -ForegroundColor Green
    Write-Host ''
    Write-Host '🎉 Taste Skill is ready. Các lệnh khả dụng:' -ForegroundColor Green
    Write-Host '    /taste-polish     — UI polish & refinement'
    Write-Host '    /redesign-ui      — Redesign existing UI'
    Write-Host '    /image-to-code    — Convert design image to code'
    Write-Host '    /brandkit         — Brand kit generation'
    Write-Host '    /mobile-ui        — Mobile UI optimization'
    Write-Host '    /landing-ui       — Landing page UI'
    Write-Host '    /ui-final-pass    — Final UI quality pass'
    Write-Host ''
    Write-Host 'Chạy: opk taste-status  — kiểm tra trạng thái'
} else {
    Write-Host "⚠️  Taste Skill installed nhưng không tìm thấy skill file." -ForegroundColor Yellow
    Write-Host "   Kiểm tra lại: ls $tasteDir" -ForegroundColor Yellow
    exit 0
}

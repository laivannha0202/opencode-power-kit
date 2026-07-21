# ─────────────────────────────────────────────────────────────────
# test-timeout.ps1 — Comprehensive timeout.ps1 tests
# opencode-power-kit v2.1.0
#
# Tests timeout.ps1 behaviors: timeout, exit code, argument handling,
# grandchild cleanup.
#
# Usage:
#   pwsh -NoProfile -File scripts/test-timeout.ps1
#
# Cases:
#   A. timeout-returns-124   — timeout.ps1 returns 124 on timeout
#   B. exit-code-preserved   — exit code from child preserved
#   C. argument-with-spaces  — arguments with spaces handled correctly
#   D. grandchild-cleanup    — timeout kills grandchild processes
#   E. timeout-zero          — timeout 0 returns 125
# ─────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TimeoutPs1 = Join-Path $ScriptDir "timeout.ps1"

$passCount = 0
$failCount = 0
$skipCount = 0
$caseCount = 0

function Pass($msg) {
    Write-Host "  ✅ $msg"
    $script:passCount++
}

function Fail($msg) {
    Write-Host "  ❌ $msg"
    $script:failCount++
}

function Skip($msg) {
    Write-Host "  ⏭️  $msg"
    $script:skipCount++
}

function Info($msg) {
    Write-Host "  ℹ️  $msg"
}

# ── Helper: run timeout.ps1 and capture exit code ──
function Run-Timeout {
    param(
        [int]$Seconds,
        [string]$Command,
        [string[]]$Args = @()
    )
    $argList = @("-NoProfile", "-File", $TimeoutPs1, "-Seconds", $Seconds, "-Command", $Command)
    if ($Args.Count -gt 0) {
        $argList += "-Args"
        $argList += $Args
    }
    $proc = Start-Process -FilePath "pwsh" -ArgumentList $argList -PassThru -NoNewWindow -Wait
    return $proc.ExitCode
}

# ─────────────────────────────────────────────────────────────────
# Check pwsh availability
# ─────────────────────────────────────────────────────────────────
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshPath) {
    Write-Host ""
    Write-Host "SKIP: pwsh unavailable — all PowerShell tests skipped"
    Write-Host "====================="
    printf "Cases: 0 | Assertions: 0 | ✅ PASS: 0 | ❌ FAIL: 0 | ⏭️  SKIP: 5`n"
    exit 0
}

Write-Host ""
Write-Host "timeout.ps1 test suite"
Write-Host "====================="
Write-Host ""
Info "Timeout tool: $TimeoutPs1"
Info "pwsh: $($pwshPath.Source)"

# ─────────────────────────────────────────────────────────────────
# CASE A: Timeout returns 124
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case A: Timeout returns 124 ==="
$rc = Run-Timeout -Seconds 1 -Command "pwsh" -Args @("-NoProfile", "-Command", "Start-Sleep -Seconds 10")
if ($rc -eq 124) {
    Pass "Timeout: exit 124"
} else {
    Fail "Timeout: expected 124, got $rc"
}

# ─────────────────────────────────────────────────────────────────
# CASE B: Exit code preserved
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case B: Exit code preserved ==="
$rc = Run-Timeout -Seconds 5 -Command "pwsh" -Args @("-NoProfile", "-Command", "exit 42")
if ($rc -eq 42) {
    Pass "Exit code: exit 42 preserved"
} else {
    Fail "Exit code: expected 42, got $rc"
}

# ─────────────────────────────────────────────────────────────────
# CASE C: Argument with spaces
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case C: Argument with spaces ==="
# Use a temp file to verify the argument is passed correctly
$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    $rc = Run-Timeout -Seconds 5 -Command "pwsh" -Args @(
        "-NoProfile", "-Command",
        "Set-Content -Path '$tmpFile' -Value 'hello world'"
    )
    $content = Get-Content -Path $tmpFile -Raw
    if ($content.Trim() -eq "hello world") {
        Pass "Argument with spaces: '$content' matches expected"
    } else {
        Fail "Argument with spaces: got '$content', expected 'hello world'"
    }
} finally {
    Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────
# CASE D: Grandchild cleanup via timeout.ps1
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case D: Grandchild cleanup ==="
$markerFile = [System.IO.Path]::GetTempFileName()
try {
    # Child PowerShell creates a grandchild, grandchild writes PID to marker, then sleeps
    $childScript = @"
`$grandchild = Start-Process -FilePath 'pwsh' -ArgumentList '-NoProfile', '-Command', "Set-Content -Path '$markerFile' -Value `$(`$PID); Start-Sleep -Seconds 600" -PassThru -NoNewWindow
Start-Sleep -Milliseconds 500
# Block until timeout kills us
Start-Sleep -Seconds 600
"@
    $rc = Run-Timeout -Seconds 2 -Command "pwsh" -Args @("-NoProfile", "-Command", $childScript)

    if ($rc -ne 124) {
        Fail "Grandchild: expected timeout exit 124, got $rc"
        return
    }
    Pass "Grandchild: exit 124"

    # Read grandchild PID from marker
    $grandPid = ""
    if (Test-Path $markerFile) {
        $grandPid = (Get-Content -Path $markerFile -Raw).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($grandPid)) {
        Fail "Grandchild: marker file empty or missing — PID not captured"
        return
    }

    if ($grandPid -notmatch '^\d+$') {
        Fail "Grandchild: marker PID '$grandPid' is not a valid integer"
        return
    }
    Pass "Grandchild: marker PID valid ($grandPid)"

    # Check if grandchild is still running
    Start-Sleep -Milliseconds 500
    try {
        $proc = Get-Process -Id ([int]$grandPid) -ErrorAction Stop
        # Process exists — check if zombie (On Windows, zombie-like state is rare)
        Fail "Grandchild: process $grandPid still alive"
        Stop-Process -Id ([int]$grandPid) -Force -ErrorAction SilentlyContinue
    } catch {
        Pass "Grandchild: process $grandPid terminated (not running)"
    }
} finally {
    Remove-Item -Path $markerFile -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────
# CASE E: Timeout 0 returns 125
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case E: Timeout 0 returns 125 ==="
$rc = Run-Timeout -Seconds 0 -Command "pwsh" -Args @("-NoProfile", "-Command", "exit 0")
if ($rc -eq 125) {
    Pass "Timeout 0: returns 125"
} else {
    Fail "Timeout 0: expected 125, got $rc"
}

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "====================="
$totalAssertions = $passCount + $failCount + $skipCount
Write-Host ("Cases: {0} | Assertions: {1} | ✅ PASS: {2} | ❌ FAIL: {3} | ⏭️  SKIP: {4}" -f $caseCount, $totalAssertions, $passCount, $failCount, $skipCount)

if ($failCount -gt 0) {
    Write-Host "❌ POWERSHELL TIMEOUT TESTS FAILED"
    exit 1
} else {
    Write-Host "✅ ALL POWERSHELL TIMEOUT TESTS PASSED"
    exit 0
}

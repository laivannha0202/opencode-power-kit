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
#   C. argument-with-spaces  — real argv passing with spaces
#   D. grandchild-cleanup    — timeout kills grandchild processes
#   E. timeout-zero          — timeout 0 returns 126
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

# ── Helper: run timeout.ps1 via invocation operator, capture $LASTEXITCODE ──
function Run-Timeout {
    param(
        [int]$Seconds,
        [string[]]$InvokeArgs
    )
    & pwsh -NoProfile -File $TimeoutPs1 -Seconds $Seconds @InvokeArgs
    return $LASTEXITCODE
}

# ── Helper: run timeout.ps1 with explicit ArgumentList (no shell interpolation) ──
function Run-TimeoutDirect {
    param(
        [int]$Seconds,
        [string[]]$CommandArgs
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "pwsh"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.ArgumentList.Add("-NoProfile")
    $psi.ArgumentList.Add("-File")
    $psi.ArgumentList.Add($TimeoutPs1)
    $psi.ArgumentList.Add("-Seconds")
    $psi.ArgumentList.Add([string]$Seconds)
    foreach ($a in $CommandArgs) {
        $psi.ArgumentList.Add($a)
    }
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    $proc.Dispose()
    return $exitCode
}

# ─────────────────────────────────────────────────────────────────
# Check pwsh availability
# ─────────────────────────────────────────────────────────────────
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshPath) {
    Write-Host ""
    Write-Host "SKIP: pwsh unavailable — all PowerShell tests skipped"
    Write-Host "====================="
    printf "Cases: 0 | Assertions: 0 | PASS: 0 | FAIL: 0 | SKIP: 5`n"
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
$rc = Run-TimeoutDirect -Seconds 1 -CommandArgs @("-NoProfile", "-Command", "Start-Sleep -Seconds 10")
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
$rc = Run-TimeoutDirect -Seconds 5 -CommandArgs @("-NoProfile", "-Command", "exit 42")
if ($rc -eq 42) {
    Pass "Exit code: exit 42 preserved"
} else {
    Fail "Exit code: expected 42, got $rc"
}

# ─────────────────────────────────────────────────────────────────
# CASE C: Argument with spaces (real argv, not -Command string)
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case C: Argument with spaces ==="
$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    # Create a child script that takes -Value and -OutputFile parameters
    $childScript = @"
param(
    [string]`$Value,
    [string]`$OutputFile
)
Set-Content -LiteralPath `$OutputFile -NoNewline -Value `$Value
"@
    $childFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $childFile -Value $childScript -Encoding UTF8
    try {
        # Call timeout.ps1 → child.ps1 with real argument "hello world"
        $rc = Run-TimeoutDirect -Seconds 5 -CommandArgs @(
            "-NoProfile", "-File", $childFile,
            "-Value", "hello world",
            "-OutputFile", $tmpFile
        )
        if ($rc -ne 0) {
            Fail "Argument with spaces: child exited $rc (expected 0)"
        } else {
            $content = Get-Content -Path $tmpFile -Raw
            if ($content.Trim() -eq "hello world") {
                Pass "Argument with spaces: file contains 'hello world'"
            } else {
                Fail "Argument with spaces: got '$content', expected 'hello world'"
            }
        }
    } finally {
        Remove-Item -Path $childFile -Force -ErrorAction SilentlyContinue
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
$childMarker = [System.IO.Path]::GetTempFileName()
$grandchildMarker = [System.IO.Path]::GetTempFileName()
try {
    # Child script: writes its own PID, creates grandchild.ps1, waits
    $childScript = @"
# Write child PID
Set-Content -LiteralPath '$childMarker' -NoNewline -Value "`$PID"
# Create grandchild script
`$grandchildScript = @"
Set-Content -LiteralPath '$grandchildMarker' -NoNewline -Value "`$PID"
Start-Sleep -Seconds 600
"@
`$grandchildFile = [System.IO.Path]::GetTempFileName() + ".ps1"
Set-Content -Path `$grandchildFile -Value `$grandchildScript -Encoding UTF8
# Start grandchild
`$gp = Start-Process -FilePath 'pwsh' -ArgumentList '-NoProfile', '-File', `$grandchildFile -PassThru -NoNewWindow
# Wait for grandchild to start
Start-Sleep -Milliseconds 500
# Block until timeout kills us
Start-Sleep -Seconds 600
"@
    $childFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $childFile -Value $childScript -Encoding UTF8
    try {
        $rc = Run-TimeoutDirect -Seconds 2 -CommandArgs @("-NoProfile", "-File", $childFile)

        if ($rc -ne 124) {
            Fail "Grandchild: expected timeout exit 124, got $rc"
            return
        }
        Pass "Grandchild: exit 124"

        # Read child PID
        $childPid = ""
        if (Test-Path $childMarker) {
            $childPid = (Get-Content -Path $childMarker -Raw).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($childPid) -or ($childPid -notmatch '^\d+$')) {
            Fail "Grandchild: child PID invalid or missing ('$childPid')"
            return
        }
        Pass "Grandchild: child PID valid ($childPid)"

        # Read grandchild PID
        $grandPid = ""
        if (Test-Path $grandchildMarker) {
            $grandPid = (Get-Content -Path $grandchildMarker -Raw).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($grandPid) -or ($grandPid -notmatch '^\d+$')) {
            Fail "Grandchild: grandchild PID invalid or missing ('$grandPid')"
            return
        }
        Pass "Grandchild: grandchild PID valid ($grandPid)"

        # PIDs must be different
        if ($childPid -eq $grandPid) {
            Fail "Grandchild: child PID ($childPid) == grandchild PID ($grandPid)"
            return
        }
        Pass "Grandchild: PIDs are different"

        # Both should be terminated after timeout
        Start-Sleep -Milliseconds 500
        $childAlive = $false
        $grandAlive = $false
        try { Get-Process -Id ([int]$childPid) -ErrorAction Stop | Out-Null; $childAlive = $true } catch {}
        try { Get-Process -Id ([int]$grandPid) -ErrorAction Stop | Out-Null; $grandAlive = $true } catch {}

        if (-not $childAlive -and -not $grandAlive) {
            Pass "Grandchild: both child and grandchild terminated"
        } else {
            if ($childAlive) { Fail "Grandchild: child $childPid still alive" }
            if ($grandAlive) { Fail "Grandchild: grandchild $grandPid still alive" }
        }
    } finally {
        # Cleanup: kill leftover processes
        try {
            if (Test-Path $childMarker) {
                $cpid = (Get-Content -Path $childMarker -Raw).Trim()
                if ($cpid -match '^\d+$') { Stop-Process -Id ([int]$cpid) -Force -ErrorAction SilentlyContinue }
            }
            if (Test-Path $grandchildMarker) {
                $gpid = (Get-Content -Path $grandchildMarker -Raw).Trim()
                if ($gpid -match '^\d+$') { Stop-Process -Id ([int]$gpid) -Force -ErrorAction SilentlyContinue }
            }
        } catch {}
        Remove-Item -Path $childFile -Force -ErrorAction SilentlyContinue
    }
} finally {
    Remove-Item -Path $childMarker -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $grandchildMarker -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────
# CASE E: Timeout 0 returns 126
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case E: Timeout 0 returns 126 ==="
$rc = Run-TimeoutDirect -Seconds 0 -CommandArgs @("-NoProfile", "-Command", "exit 0")
if ($rc -eq 126) {
    Pass "Timeout 0: returns 126"
} else {
    Fail "Timeout 0: expected 126, got $rc"
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

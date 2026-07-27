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
    Write-Host "  PASS: $msg"
    $script:passCount++
}

function Fail($msg) {
    Write-Host "  FAIL: $msg"
    $script:failCount++
}

function Skip($msg) {
    Write-Host "  SKIP: $msg"
    $script:skipCount++
}

function Info($msg) {
    Write-Host "  INFO: $msg"
}

# ── Helper: run timeout.ps1 via a temporary driver.ps1 ──────────
# The driver.ps1 receives:
#   -TimeoutPs1 <path> -Seconds <N> -Command <string> -ArgsJson <json>
# It calls timeout.ps1 with proper PowerShell argument binding.
function Run-TimeoutDirect {
    param(
        [int]$Seconds,
        [string]$Command,
        [string[]]$CommandArgs
    )

    # Create driver.ps1 content
    $driverContent = @'
param(
    [string]$TimeoutPs1,
    [int]$Seconds,
    [string]$Command,
    [string]$ArgsJson
)
$childArgs = @(ConvertFrom-Json $ArgsJson)
& $TimeoutPs1 -Seconds $Seconds -Command $Command -Args $childArgs
'@

    $driverFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".ps1")
    Set-Content -Path $driverFile -Value $driverContent -Encoding UTF8

    try {
        $argsJson = ConvertTo-Json -InputObject $CommandArgs -Compress

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "pwsh"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.ArgumentList.Add("-NoProfile")
        $psi.ArgumentList.Add("-File")
        $psi.ArgumentList.Add($driverFile)
        $psi.ArgumentList.Add("-TimeoutPs1")
        $psi.ArgumentList.Add($TimeoutPs1)
        $psi.ArgumentList.Add("-Seconds")
        $psi.ArgumentList.Add([string]$Seconds)
        $psi.ArgumentList.Add("-Command")
        $psi.ArgumentList.Add($Command)
        $psi.ArgumentList.Add("-ArgsJson")
        $psi.ArgumentList.Add($argsJson)

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $proc.Dispose()
        return $exitCode
    } finally {
        Remove-Item -Path $driverFile -Force -ErrorAction SilentlyContinue
    }
}

# ─────────────────────────────────────────────────────────────────
# Check pwsh availability
# ─────────────────────────────────────────────────────────────────
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshPath) {
    Write-Host ""
    Write-Host "SKIP: pwsh unavailable — all PowerShell tests skipped"
    Write-Host "====================="
    Write-Host "Cases: 0 | Assertions: 0 | PASS: 0 | FAIL: 0 | SKIP: 5"
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
$rc = Run-TimeoutDirect -Seconds 1 -Command "pwsh" -CommandArgs @("-NoProfile", "-Command", "Start-Sleep -Seconds 10")
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
$rc = Run-TimeoutDirect -Seconds 5 -Command "pwsh" -CommandArgs @("-NoProfile", "-Command", "exit 42")
if ($rc -eq 42) {
    Pass "Exit code: exit 42 preserved"
} else {
    Fail "Exit code: expected 42, got $rc"
}

# ─────────────────────────────────────────────────────────────────
# CASE C: Argument with spaces (real argv, not -Command string)
# Tests that argument boundaries are preserved through:
#   test-timeout.ps1 → timeout.ps1 → pwsh → child.ps1
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case C: Argument with spaces ==="

# Test cases: array of [expected, real argv value]
# Each value crosses test-timeout.ps1 → timeout.ps1 → pwsh → child.ps1.
$argTests = @(
    @("hello world", "hello world"),
    @("hello ""world""", "hello ""world"""),
    @("path with spaces/file.txt", "path with spaces/file.txt"),
    @("", ""),
    @("xin chào Việt Nam", "xin chào Việt Nam")
)

# Child script that writes its argument to a file
$childScriptTemplate = @'
param(
    [string]$Value,
    [string]$OutputFile
)
Set-Content -LiteralPath $OutputFile -NoNewline -Value $Value
'@

$tmpFile = [System.IO.Path]::GetTempFileName()
$childFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".ps1")
Set-Content -Path $childFile -Value $childScriptTemplate -Encoding UTF8

try {
    foreach ($test in $argTests) {
        $expected = $test[0]
        $testValue = $test[1]

        # Pass the value as a real argv element to child.ps1; never embed it in -Command.
        $rc = Run-TimeoutDirect -Seconds 5 -Command "pwsh" -CommandArgs @(
            "-NoProfile", "-File", $childFile,
            "-Value", $testValue,
            "-OutputFile", $tmpFile
        )

        if ($rc -ne 0) {
            Fail "Argument test: child exited $rc for '$expected'"
        } else {
            $content = Get-Content -Path $tmpFile -Raw
            if ($content.Trim() -eq $expected) {
                Pass "Argument test: '$expected'"
            } else {
                Fail "Argument test: got '$($content.Trim())', expected '$expected'"
            }
        }
        # Reset tmp file
        Set-Content -Path $tmpFile -NoNewline -Value ""
    }
} finally {
    Remove-Item -Path $childFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────
# CASE D: Grandchild cleanup via timeout.ps1
# Uses separate script files (no nested here-strings)
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case D: Grandchild cleanup ==="
$childMarker = [System.IO.Path]::GetTempFileName()
$grandchildMarker = [System.IO.Path]::GetTempFileName()

# Create grandchild.ps1 as separate file
$grandchildFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".ps1")
$grandchildContent = @'
param([string]$GrandchildMarker)

Set-Content -LiteralPath $GrandchildMarker -NoNewline -Value $PID
Start-Sleep -Seconds 600
'@
Set-Content -Path $grandchildFile -Value $grandchildContent -Encoding UTF8

# Create child.ps1 as separate file
$childFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".ps1")
$childContent = @'
param(
    [string]$PwshPath,
    [string]$ChildMarker,
    [string]$GrandchildScript,
    [string]$GrandchildMarker
)

Set-Content -LiteralPath $ChildMarker -NoNewline -Value $PID

# Launch grandchild via ProcessStartInfo.ArgumentList.
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $PwshPath
$psi.UseShellExecute = $false
if ($null -eq $psi.ArgumentList) {
    throw "ProcessStartInfo.ArgumentList is unavailable"
}
[void]$psi.ArgumentList.Add("-NoProfile")
[void]$psi.ArgumentList.Add("-File")
[void]$psi.ArgumentList.Add($GrandchildScript)
[void]$psi.ArgumentList.Add("-GrandchildMarker")
[void]$psi.ArgumentList.Add($GrandchildMarker)
$grandchild = [System.Diagnostics.Process]::Start($psi)
$grandchild.Dispose()

Start-Sleep -Milliseconds 500
Start-Sleep -Seconds 600
'@
Set-Content -Path $childFile -Value $childContent -Encoding UTF8

try {
    $rc = Run-TimeoutDirect -Seconds 2 -Command "pwsh" -CommandArgs @(
        "-NoProfile", "-File", $childFile,
        "-PwshPath", "pwsh",
        "-ChildMarker", $childMarker,
        "-GrandchildScript", $grandchildFile,
        "-GrandchildMarker", $grandchildMarker
    )

    if ($rc -ne 124) {
        Fail "Grandchild: expected timeout exit 124, got $rc"
    } else {
        Pass "Grandchild: exit 124"
    }

    # Read child PID
    $childPid = ""
    if (Test-Path $childMarker) {
        $childPid = (Get-Content -Path $childMarker -Raw).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($childPid) -or ($childPid -notmatch '^\d+$')) {
        Fail "Grandchild: child PID invalid or missing ('$childPid')"
    } else {
        Pass "Grandchild: child PID valid ($childPid)"
    }

    # Read grandchild PID
    $grandPid = ""
    if (Test-Path $grandchildMarker) {
        $grandPid = (Get-Content -Path $grandchildMarker -Raw).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($grandPid) -or ($grandPid -notmatch '^\d+$')) {
        Fail "Grandchild: grandchild PID invalid or missing ('$grandPid')"
    } else {
        Pass "Grandchild: grandchild PID valid ($grandPid)"
    }

    # PIDs must be different
    if ($childPid -eq $grandPid) {
        Fail "Grandchild: child PID ($childPid) == grandchild PID ($grandPid)"
    } else {
        Pass "Grandchild: PIDs are different"
    }

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
    # Cleanup: kill leftover processes (only after recording FAIL above)
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
    Remove-Item -Path $grandchildFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $childMarker -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $grandchildMarker -Force -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────
# CASE E: Timeout 0 returns 126
# ─────────────────────────────────────────────────────────────────
$caseCount++
Write-Host ""
Write-Host "=== Case E: Timeout 0 returns 126 ==="
$rc = Run-TimeoutDirect -Seconds 0 -Command "pwsh" -CommandArgs @("-NoProfile", "-Command", "exit 0")
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
Write-Host ("Cases: {0} | Assertions: {1} | PASS: {2} | FAIL: {3} | SKIP: {4}" -f $caseCount, $totalAssertions, $passCount, $failCount, $skipCount)

if ($failCount -gt 0) {
    Write-Host "POWERSHELL TIMEOUT TESTS FAILED"
    exit 1
} else {
    Write-Host "ALL POWERSHELL TIMEOUT TESTS PASSED"
    exit 0
}

# ─────────────────────────────────────────────────────────────────
# test-timeout.ps1 — Executable cross-platform timeout.ps1 tests
# opencode-power-kit v2.1.0
#
# Runs on PowerShell 7 for Linux and Windows. Every child process has an
# outer timeout so a regression fails instead of hanging the workflow.
# ─────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TimeoutPs1 = Join-Path $ScriptDir "timeout.ps1"
$PwshPath = (Get-Process -Id $PID).Path
$SuiteDeadline = [DateTime]::UtcNow.AddMinutes(3)
$OuterTimeoutMs = 15000

$passCount = 0
$failCount = 0
$skipCount = 0
$caseCount = 0
$tempPaths = [System.Collections.Generic.List[string]]::new()
$cleanupProcesses = [System.Collections.Generic.List[object]]::new()

function Pass([string]$Message) {
    Write-Host "  PASS: $Message"
    $script:passCount++
}

function Fail([string]$Message) {
    Write-Host "  FAIL: $Message"
    $script:failCount++
}

function Start-Case([string]$Name) {
    $script:caseCount++
    Write-Host ""
    Write-Host "=== $Name ==="
}

function Assert-Equal([string]$Label, $Expected, $Actual) {
    if ($Expected -ceq $Actual) {
        Pass "$Label ($Actual)"
    } else {
        Fail "$Label expected '$Expected', got '$Actual'"
    }
}

function New-TempPath([string]$Extension = "") {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + $Extension)
    $script:tempPaths.Add($path)
    return $path
}

function Get-ProcessIdentity([int]$ProcessId) {
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        return [string]$process.StartTime.ToUniversalTime().Ticks
    } catch {
        return $null
    }
}

function Register-TestProcess([int]$ProcessId, [string]$Identity) {
    $script:cleanupProcesses.Add([pscustomobject]@{ ProcessId = $ProcessId; Identity = $Identity })
}

function Stop-TestProcessSafely([int]$ProcessId, [string]$ExpectedIdentity) {
    $currentIdentity = Get-ProcessIdentity -ProcessId $ProcessId
    if ($null -eq $currentIdentity) {
        return
    }
    if ($currentIdentity -cne $ExpectedIdentity) {
        Fail "cleanup refused reused PID $ProcessId (identity changed)"
        return
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Wait-ProcessGone([int]$ProcessId, [string]$ExpectedIdentity, [int]$Milliseconds = 5000) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.ElapsedMilliseconds -lt $Milliseconds) {
        $currentIdentity = Get-ProcessIdentity -ProcessId $ProcessId
        if ($null -eq $currentIdentity -or $currentIdentity -cne $ExpectedIdentity) {
            return $true
        }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

function Invoke-Timeout {
    param(
        [string]$Seconds,
        [string]$Command,
        [string[]]$CommandArgs = @(),
        [hashtable]$Environment = @{},
        [int]$OuterMilliseconds = $OuterTimeoutMs
    )

    if ([DateTime]::UtcNow -ge $SuiteDeadline) {
        throw "PowerShell timeout suite exceeded its 3-minute outer deadline"
    }

    $driverFile = New-TempPath ".ps1"
    $driverContent = @'
param(
    [string]$TimeoutPs1,
    [string]$Seconds,
    [string]$Command,
    [string]$ArgsJson
)
$childArgs = @((ConvertFrom-Json -InputObject $ArgsJson))
& $TimeoutPs1 -Seconds $Seconds -Command $Command -Args $childArgs
exit $LASTEXITCODE
'@
    [System.IO.File]::WriteAllText($driverFile, $driverContent, [System.Text.UTF8Encoding]::new($false))

    $argsJson = ConvertTo-Json -InputObject @($CommandArgs) -Compress
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $PwshPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($argument in @(
        "-NoProfile", "-File", $driverFile,
        "-TimeoutPs1", $TimeoutPs1,
        "-Seconds", [string]$Seconds,
        "-Command", $Command,
        "-ArgsJson", $argsJson
    )) {
        [void]$psi.ArgumentList.Add($argument)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $psi.Environment[[string]$entry.Key] = [string]$entry.Value
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($OuterMilliseconds)
    if (-not $completed) {
        try { $process.Kill($true) } catch { try { $process.Kill() } catch {} }
        try { [void]$process.WaitForExit(5000) } catch {}
    }

    try { [void]$stdoutTask.Wait(5000) } catch {}
    try { [void]$stderrTask.Wait(5000) } catch {}
    $stdout = if ($stdoutTask.IsCompletedSuccessfully) { $stdoutTask.Result } else { "<stdout read timed out>" }
    $stderr = if ($stderrTask.IsCompletedSuccessfully) { $stderrTask.Result } else { "<stderr read timed out>" }
    $stopwatch.Stop()
    $exitCode = if ($completed) { $process.ExitCode } else { -1 }
    $process.Dispose()

    return [pscustomobject]@{
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
        ElapsedMilliseconds = $stopwatch.ElapsedMilliseconds
        OuterTimedOut = -not $completed
    }
}

function Assert-NoStackTrace([string]$Label, [string]$Text) {
    if ($Text -match '(?im)\b(CategoryInfo|FullyQualifiedErrorId|ScriptStackTrace)\b|\bat .*\.ps1:\s*line\s+\d+') {
        Fail "$Label emitted a PowerShell stack trace: $Text"
    } else {
        Pass "$Label emitted no PowerShell stack trace"
    }
}

try {
    Write-Host ""
    Write-Host "timeout.ps1 test suite"
    Write-Host "====================="
    Write-Host "  INFO: timeout tool: $TimeoutPs1"
    Write-Host "  INFO: pwsh: $PwshPath"

    Start-Case "Normal and child exit codes"
    foreach ($code in @(0, 1, 2, 10, 31, 32, 42, 125, 126, 127)) {
        $result = Invoke-Timeout -Seconds 5 -Command $PwshPath -CommandArgs @("-NoProfile", "-Command", "exit $code")
        Assert-Equal "child exit $code preserved" $code $result.ExitCode
        Assert-Equal "child exit $code outer timeout" $false $result.OuterTimedOut
    }

    Start-Case "Timeout and invalid arguments"
    $result = Invoke-Timeout -Seconds 1 -Command $PwshPath -CommandArgs @("-NoProfile", "-Command", "Start-Sleep -Seconds 30")
    Assert-Equal "real timeout returns 124" 124 $result.ExitCode
    Assert-Equal "timeout invocation outer timeout" $false $result.OuterTimedOut

    foreach ($seconds in @("0", "-1", "abc", "2147483648")) {
        $result = Invoke-Timeout -Seconds $seconds -Command $PwshPath -CommandArgs @("-NoProfile", "-Command", "exit 0")
        Assert-Equal "Seconds $seconds returns 126" 126 $result.ExitCode
        Assert-NoStackTrace "Seconds $seconds" ($result.Stdout + $result.Stderr)
    }
    $result = Invoke-Timeout -Seconds "5" -Command ""
    Assert-Equal "empty command returns 126" 126 $result.ExitCode
    Assert-NoStackTrace "empty command" ($result.Stdout + $result.Stderr)

    $result = Invoke-Timeout -Seconds "5" -Command $PwshPath -Environment @{ OPK_TIMEOUT_TEST_FORCE_INTERNAL_FAILURE = "1" }
    Assert-Equal "internal wrapper failure returns 125" 125 $result.ExitCode
    Assert-NoStackTrace "internal wrapper failure" ($result.Stdout + $result.Stderr)

    Start-Case "Command resolution failures"
    $missing = "opk-command-that-does-not-exist-$PID"
    $result = Invoke-Timeout -Seconds 5 -Command $missing
    Assert-Equal "missing command returns 127" 127 $result.ExitCode
    Assert-NoStackTrace "missing command" ($result.Stdout + $result.Stderr)

    $wildcardTarget = Join-Path ([System.IO.Path]::GetTempPath()) $(if ($IsWindows) { "opk-wildcard-$PID-target.cmd" } else { "opk-wildcard-$PID-target" })
    $tempPaths.Add($wildcardTarget)
    $wildcardContent = if ($IsWindows) { "@exit /b 0" } else { "#!/bin/sh`nexit 0`n" }
    [System.IO.File]::WriteAllText($wildcardTarget, $wildcardContent, [System.Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) {
        & chmod 700 $wildcardTarget
        if ($LASTEXITCODE -ne 0) { throw "chmod failed for wildcard fixture" }
    }
    $wildcardPath = [System.IO.Path]::GetTempPath() + [System.IO.Path]::PathSeparator + $env:PATH
    $result = Invoke-Timeout -Seconds "5" -Command "opk-wildcard-$PID-*" -Environment @{ PATH = $wildcardPath }
    Assert-Equal "wildcard command name is literal and returns 127" 127 $result.ExitCode
    Assert-NoStackTrace "wildcard command" ($result.Stdout + $result.Stderr)

    $badExecutable = if ($IsWindows) { New-TempPath ".exe" } else { New-TempPath }
    [System.IO.File]::WriteAllText($badExecutable, "this is not an executable image", [System.Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) {
        & chmod 700 $badExecutable
        if ($LASTEXITCODE -ne 0) { throw "chmod failed for bad executable fixture" }
    }
    $result = Invoke-Timeout -Seconds 5 -Command $badExecutable
    Assert-Equal "found but bad executable returns 126" 126 $result.ExitCode
    Assert-NoStackTrace "bad executable" ($result.Stdout + $result.Stderr)

    Start-Case "Argument boundaries"
    $argumentChild = New-TempPath ".ps1"
    $argumentOutput = New-TempPath ".txt"
    $argumentChildContent = @'
param(
    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    [string]$Value,
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)
[System.IO.File]::WriteAllText($OutputFile, $Value, [System.Text.UTF8Encoding]::new($false))
'@
    [System.IO.File]::WriteAllText($argumentChild, $argumentChildContent, [System.Text.UTF8Encoding]::new($false))
    foreach ($value in @(
        "hello world",
        'hello "quoted" world',
        "xin chào Việt Nam — 東京",
        "",
        "  leading whitespace",
        "trailing whitespace  ",
        "   "
    )) {
        $result = Invoke-Timeout -Seconds 5 -Command $PwshPath -CommandArgs @(
            "-NoProfile", "-File", $argumentChild,
            "-Value", $value,
            "-OutputFile", $argumentOutput
        )
        Assert-Equal "argument child exits 0" 0 $result.ExitCode
        $actual = [System.IO.File]::ReadAllText($argumentOutput)
        Assert-Equal "argument preserved: <$value>" $value $actual
    }

    Start-Case "Early completion"
    $result = Invoke-Timeout -Seconds 30 -Command $PwshPath -CommandArgs @("-NoProfile", "-Command", "exit 0")
    Assert-Equal "early completion exits 0" 0 $result.ExitCode
    if ($result.ElapsedMilliseconds -lt 5000) {
        Pass "early completion does not wait for timeout ($($result.ElapsedMilliseconds) ms)"
    } else {
        Fail "early completion took $($result.ElapsedMilliseconds) ms"
    }

    Start-Case "Child and grandchild cleanup"
    $childMarker = New-TempPath ".json"
    $grandchildMarker = New-TempPath ".json"
    $grandchildFile = New-TempPath ".ps1"
    $childFile = New-TempPath ".ps1"

    $grandchildContent = @'
param([string]$Marker)
$identity = [string](Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks
@{ pid = $PID; identity = $identity } | ConvertTo-Json -Compress | Set-Content -LiteralPath $Marker -NoNewline
Start-Sleep -Seconds 600
'@
    $childContent = @'
param(
    [string]$PwshPath,
    [string]$ChildMarker,
    [string]$GrandchildScript,
    [string]$GrandchildMarker
)
$identity = [string](Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks
@{ pid = $PID; identity = $identity } | ConvertTo-Json -Compress | Set-Content -LiteralPath $ChildMarker -NoNewline
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $PwshPath
$psi.UseShellExecute = $false
foreach ($argument in @("-NoProfile", "-File", $GrandchildScript, "-Marker", $GrandchildMarker)) {
    [void]$psi.ArgumentList.Add($argument)
}
$grandchild = [System.Diagnostics.Process]::Start($psi)
$grandchild.Dispose()
$deadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath $GrandchildMarker) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 50
}
Start-Sleep -Seconds 600
'@
    [System.IO.File]::WriteAllText($grandchildFile, $grandchildContent, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($childFile, $childContent, [System.Text.UTF8Encoding]::new($false))

    $result = Invoke-Timeout -Seconds 8 -Command $PwshPath -CommandArgs @(
        "-NoProfile", "-File", $childFile,
        "-PwshPath", $PwshPath,
        "-ChildMarker", $childMarker,
        "-GrandchildScript", $grandchildFile,
        "-GrandchildMarker", $grandchildMarker
    )
    Assert-Equal "process tree timeout returns 124" 124 $result.ExitCode

    foreach ($entry in @(
        [pscustomobject]@{ Label = "child"; Marker = $childMarker },
        [pscustomobject]@{ Label = "grandchild"; Marker = $grandchildMarker }
    )) {
        if (-not (Test-Path -LiteralPath $entry.Marker)) {
            Fail "$($entry.Label) marker missing"
            continue
        }
        $record = Get-Content -LiteralPath $entry.Marker -Raw | ConvertFrom-Json
        $processId = [int]$record.pid
        $identity = [string]$record.identity
        Register-TestProcess -ProcessId $processId -Identity $identity
        if (Wait-ProcessGone -ProcessId $processId -ExpectedIdentity $identity) {
            Pass "$($entry.Label) process terminated (PID $processId)"
        } else {
            Fail "$($entry.Label) process still alive with original identity (PID $processId)"
        }
    }
} catch {
    Fail "test suite internal failure: $($_.Exception.Message)"
} finally {
    foreach ($record in $cleanupProcesses) {
        Stop-TestProcessSafely -ProcessId $record.ProcessId -ExpectedIdentity $record.Identity
    }
    foreach ($path in $tempPaths) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "====================="
$totalAssertions = $passCount + $failCount + $skipCount
Write-Host ("Cases: {0} | Assertions: {1} | PASS: {2} | FAIL: {3} | SKIP: {4}" -f $caseCount, $totalAssertions, $passCount, $failCount, $skipCount)
if ($failCount -gt 0) {
    Write-Host "POWERSHELL TIMEOUT TESTS FAILED"
    exit 1
}
Write-Host "ALL POWERSHELL TIMEOUT TESTS PASSED"
exit 0

# ─────────────────────────────────────────────────────────────────
# timeout.ps1 — Portable timeout wrapper (PowerShell 7+)
# opencode-power-kit v2.1.0
#
# Usage:
#   pwsh -NoProfile -File timeout.ps1 -Seconds <N> -Command <string> [-Args <string[]>]
#
# Exit codes:
#   124   — timeout occurred
#   125   — runtime or internal wrapper failure
#   126   — invalid arguments or command found but cannot execute
#   127   — command not found
#   other — original child exit code
# ─────────────────────────────────────────────────────────────────

param(
    [AllowEmptyString()]
    [string]$Seconds = "",

    [AllowEmptyString()]
    [string]$Command = "",

    [Alias("Args")]
    [AllowEmptyCollection()]
    [string[]]$CommandArgs = @()
)

$ErrorActionPreference = "Stop"

function Write-TimeoutError([string]$Message) {
    [Console]::Error.WriteLine("Error: $Message")
}

function Resolve-TimeoutCommand([string]$Name) {
    $isPath = [System.IO.Path]::IsPathRooted($Name) -or
        $Name.Contains([System.IO.Path]::DirectorySeparatorChar) -or
        $Name.Contains([System.IO.Path]::AltDirectorySeparatorChar)

    if ($isPath) {
        if (Test-Path -LiteralPath $Name -PathType Leaf) {
            $resolvedPath = (Resolve-Path -LiteralPath $Name).ProviderPath
            return [pscustomobject]@{ Status = "Found"; Path = $resolvedPath }
        }
        if (Test-Path -LiteralPath $Name) {
            return [pscustomobject]@{ Status = "CannotExecute"; Path = $Name }
        }
        return [pscustomobject]@{ Status = "Missing"; Path = $null }
    }

    $literalName = [System.Management.Automation.WildcardPattern]::Escape($Name)
    $application = Get-Command -Name $literalName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $application) {
        $applicationPath = if (-not [string]::IsNullOrWhiteSpace($application.Source)) {
            $application.Source
        } elseif (-not [string]::IsNullOrWhiteSpace($application.Path)) {
            $application.Path
        } else {
            $application.Definition
        }
        return [pscustomobject]@{ Status = "Found"; Path = $applicationPath }
    }

    $nonApplication = Get-Command -Name $literalName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $nonApplication) {
        return [pscustomobject]@{ Status = "CannotExecute"; Path = $Name }
    }
    return [pscustomobject]@{ Status = "Missing"; Path = $null }
}

function Get-StartFailureExitCode(
    [System.Exception]$Exception,
    [bool]$CommandWasResolved
) {
    if ($Exception -is [System.UnauthorizedAccessException]) {
        return 126
    }
    if ($Exception -is [System.IO.FileNotFoundException] -or
        $Exception -is [System.IO.DirectoryNotFoundException]) {
        return $(if ($CommandWasResolved) { 126 } else { 127 })
    }
    if ($Exception -is [System.ComponentModel.Win32Exception]) {
        $nativeCode = $Exception.NativeErrorCode
        if ($nativeCode -in @(2, 3)) {
            return $(if ($CommandWasResolved) { 126 } else { 127 })
        }
        if ($nativeCode -in @(5, 8, 13, 193, 216)) {
            return 126
        }
    }
    return 125
}

function Stop-TimeoutProcess([System.Diagnostics.Process]$Process) {
    try {
        $Process.Kill($true)
    } catch {
        # A parent-only fallback cannot satisfy the process-tree contract. Try
        # it only to reduce leakage, then report an internal wrapper failure.
        try {
            if (-not $Process.HasExited) {
                $Process.Kill()
                [void]$Process.WaitForExit(5000)
            }
        } catch {}
        return $false
    }

    try {
        return $Process.WaitForExit(5000)
    } catch {
        return $false
    }
}

$process = $null
$exitCode = 125

try {
    $secondsValue = 0
    $secondsValid = [int]::TryParse($Seconds, [ref]$secondsValue)
    if (-not $secondsValid -or $secondsValue -le 0) {
        Write-TimeoutError "timeout must be a positive integer (>= 1)"
        $exitCode = 126
    } elseif ([string]::IsNullOrEmpty($Command)) {
        Write-TimeoutError "command must not be empty"
        $exitCode = 126
    } else {
        if ($env:OPK_TIMEOUT_TEST_FORCE_INTERNAL_FAILURE -eq "1") {
            throw "forced internal failure for timeout wrapper regression test"
        }
        $resolution = Resolve-TimeoutCommand -Name $Command
        switch ($resolution.Status) {
            "Missing" {
                Write-TimeoutError "command not found: $Command"
                $exitCode = 127
            }
            "CannotExecute" {
                Write-TimeoutError "command cannot execute: $Command"
                $exitCode = 126
            }
            "Found" {
                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName = $resolution.Path
                $psi.UseShellExecute = $false
                if ($null -eq $psi.ArgumentList) {
                    Write-TimeoutError "ProcessStartInfo.ArgumentList is unavailable"
                    $exitCode = 125
                    break
                }
                foreach ($argument in $CommandArgs) {
                    [void]$psi.ArgumentList.Add($argument)
                }

                try {
                    $process = [System.Diagnostics.Process]::Start($psi)
                } catch {
                    $startException = $_.Exception.GetBaseException()
                    $exitCode = Get-StartFailureExitCode -Exception $startException -CommandWasResolved $true
                    if ($exitCode -eq 125) {
                        Write-TimeoutError "internal process start failure: $($startException.Message)"
                    } else {
                        Write-TimeoutError "command cannot execute: $Command"
                    }
                    break
                }

                if ($null -eq $process) {
                    Write-TimeoutError "runtime returned no process handle"
                    $exitCode = 125
                    break
                }

                $timeoutMilliseconds = [Math]::Min([int64]$secondsValue * 1000, [int]::MaxValue)
                try {
                    $completed = $process.WaitForExit([int]$timeoutMilliseconds)
                } catch {
                    [void](Stop-TimeoutProcess -Process $process)
                    Write-TimeoutError "internal wait failure: $($_.Exception.Message)"
                    $exitCode = 125
                    break
                }

                if (-not $completed) {
                    if (Stop-TimeoutProcess -Process $process) {
                        $exitCode = 124
                    } else {
                        Write-TimeoutError "failed to terminate and reap timed-out process tree"
                        $exitCode = 125
                    }
                    break
                }

                $exitCode = $process.ExitCode
            }
        }
    }
} catch {
    if ($null -ne $process -and -not $process.HasExited) {
        [void](Stop-TimeoutProcess -Process $process)
    }
    Write-TimeoutError "internal wrapper failure: $($_.Exception.Message)"
    $exitCode = 125
} finally {
    if ($null -ne $process) {
        $process.Dispose()
    }
}

exit $exitCode

# ─────────────────────────────────────────────────────────────────
# timeout.ps1 — Portable timeout wrapper (PowerShell)
# opencode-power-kit v2.1.0
#
# Runs a command with a timeout. Returns exit code 124 if timeout occurs.
#
# Usage:
#   pwsh timeout.ps1 -Seconds <N> -Command <string> [-Args <string[]>]
#
# Examples:
#   pwsh timeout.ps1 -Seconds 5 -Command "sleep" -Args 10
#   pwsh timeout.ps1 -Seconds 5 -Command "sleep" -Args 2
#
# Exit codes:
#   0-N   — exit code from the command
#   124   — timeout occurred
#   125   — invalid arguments
# ─────────────────────────────────────────────────────────────────

param(
    [Parameter(Mandatory=$true)]
    [int]$Seconds,

    [Parameter(Mandatory=$true)]
    [string]$Command,

    [string[]]$Args = @()
)

if ($Seconds -le 0) {
    Write-Error "Error: timeout must be a positive integer"
    exit 125
}

# Helper: quote an argument that contains spaces or special characters
function Protect-Argument {
    param([string]$Arg)
    if ($Arg -match '[\s"''`]') {
        # Contains whitespace or quotes — escape internal double-quotes and wrap
        $escaped = $Arg -replace '"', '""'
        return "`"$escaped`""
    }
    return $Arg
}

$process = $null
try {
    # Build argument list with proper quoting
    $quotedArgs = @()
    foreach ($a in $Args) {
        $quotedArgs += Protect-Argument $a
    }

    # Start the process using Start-Process -PassThru (no -Wait)
    # -ArgumentList handles the argument array properly
    if ($quotedArgs.Count -gt 0) {
        $process = Start-Process -FilePath $Command -ArgumentList $quotedArgs -PassThru -NoNewWindow
    } else {
        $process = Start-Process -FilePath $Command -PassThru -NoNewWindow
    }

    # Wait with timeout using WaitForExit(milliseconds)
    $timeoutMs = $Seconds * 1000
    $exited = $process.WaitForExit($timeoutMs)

    if (-not $exited) {
        # Timeout — kill the entire process tree
        try {
            $process.Kill($true)  # Kill entire process tree (child processes included)
        } catch {
            # Fallback: try taskkill /T /F
            try {
                taskkill /PID $process.Id /T /F 2>$null
            } catch {
                # Last resort: kill the process without tree
                try { $process.Kill() } catch {}
            }
        }
        exit 124
    }

    # Command completed — return its actual exit code
    exit $process.ExitCode
} catch {
    Write-Error "Error running command: $_"
    exit 125
} finally {
    if ($process -ne $null) {
        $process.Dispose()
    }
}

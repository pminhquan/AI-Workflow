<#
.SYNOPSIS
    Starts Antigravity with remote debugging enabled.
.DESCRIPTION
    Checks if Antigravity is already running and listening on a remote debugging port
    (supporting explicit port, configured ANTIGRAVITY_PORT or DEVTOOLS_PORT, or runtime discovery via DevToolsActivePort).
    If not listening, launches Antigravity with --remote-debugging-port=<port>
    and waits until the port is available. Does not modify the Antigravity installation.
.PARAMETER ExePath
    Path to the Antigravity executable. Defaults to standard local app data installation path.
.PARAMETER Port
    Target TCP remote debugging port. When omitted or 0, attempts port resolution from ANTIGRAVITY_PORT, DEVTOOLS_PORT, or DevToolsActivePort runtime discovery before failing closed.
.PARAMETER TimeoutSec
    Maximum seconds to wait for port to become available. Defaults to 30.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ExePath = "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe",

    [int]$Port = 0,

    [int]$TimeoutSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PortListening {
    param(
        [string]$Address = '127.0.0.1',
        [Parameter(Mandatory = $true)]
        [int]$TargetPort,
        [int]$TimeoutMs = 500
    )

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $tcpClient.BeginConnect($Address, $TargetPort, $null, $null)
        $waitSuccess = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($waitSuccess -and $tcpClient.Connected) {
            $tcpClient.EndConnect($asyncResult)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $tcpClient.Close()
    }
}

# Resolve target port using configured runtime discovery if not explicitly specified
$portExplicit = ($PSBoundParameters.ContainsKey('Port') -and $Port -gt 0)
$discoveryMethod = ""

if (-not $portExplicit) {
    if ($env:ANTIGRAVITY_PORT -and ($env:ANTIGRAVITY_PORT -as [int]) -gt 0) {
        $Port = [int]$env:ANTIGRAVITY_PORT
        $discoveryMethod = "environment variable ANTIGRAVITY_PORT"
    } elseif ($env:DEVTOOLS_PORT -and ($env:DEVTOOLS_PORT -as [int]) -gt 0) {
        $Port = [int]$env:DEVTOOLS_PORT
        $discoveryMethod = "environment variable DEVTOOLS_PORT"
    } else {
        $candidates = @(
            (Join-Path $env:APPDATA "Antigravity\DevToolsActivePort"),
            (Join-Path $env:LOCALAPPDATA "Antigravity\DevToolsActivePort"),
            (Join-Path $env:APPDATA "Antigravity IDE\DevToolsActivePort")
        )
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c -PathType Leaf) {
                try {
                    $firstLine = (Get-Content -LiteralPath $c -TotalCount 1 -ErrorAction SilentlyContinue).Trim()
                    if ($firstLine -as [int] -and [int]$firstLine -gt 0) {
                        $Port = [int]$firstLine
                        $discoveryMethod = "runtime discovery ($c)"
                        break
                    }
                } catch {}
            }
        }
    }
    if ($Port -le 0) {
        Write-Error "STATUS: FAIL - Failed to resolve remote debugging port: No explicit -Port specified, neither ANTIGRAVITY_PORT nor DEVTOOLS_PORT environment variable is set, and DevToolsActivePort could not be found or read. Implicit default port 9222 is disabled to prevent fail-open assumptions."
        exit 1
    }
} else {
    $discoveryMethod = "explicit argument (-Port $Port)"
}

Write-Host "=== Antigravity Startup Check ==="
Write-Host "Target Port   : $Port ($discoveryMethod)"
Write-Host "Wait Timeout  : $TimeoutSec seconds"

# 1. Check if port is already listening
if (Test-PortListening -TargetPort $Port) {
    Write-Host "Antigravity remote debugging port $Port is already active and listening."
    Write-Host "STATUS: PASS"
    exit 0
}

# 2. Resolve executable path
$resolvedExe = $ExePath
if (-not (Test-Path -LiteralPath $resolvedExe -PathType Leaf)) {
    $candidate = "C:\Users\My Laptop\AppData\Local\Programs\antigravity\Antigravity.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $resolvedExe = $candidate
    } else {
        Write-Error "STATUS: FAIL - Antigravity executable not found at '$resolvedExe'."
        exit 1
    }
}

Write-Host "Executable    : $resolvedExe"

# 3. Check if Antigravity process exists without port listening
$runningProcesses = @(Get-Process -Name "*antigravity*" -ErrorAction SilentlyContinue)

if ($runningProcesses.Count -gt 0) {
    Write-Host "Antigravity process detected ($($runningProcesses.Count) process(es)), but remote debugging port $Port is not listening."
    Write-Error "STATUS: FAIL - Antigravity process exists without a usable bridge on port $Port. Force-kill or automatic restart is disabled to protect active work. Please close Antigravity manually and rerun this script, or restart Antigravity with --remote-debugging-port=$Port."
    exit 1
}

# 4. Safe startup behavior for absent process
Write-Host "Launching Antigravity with --remote-debugging-port=$Port..."
try {
    Start-Process -FilePath $resolvedExe -ArgumentList "--remote-debugging-port=$Port"
} catch {
    Write-Error "STATUS: FAIL - Failed to launch Antigravity: $($_.Exception.Message)"
    exit 1
}

# 5. Wait for port to become available
Write-Host "Waiting for TCP port $Port to listen (timeout: $TimeoutSec s)..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$portReady = $false

while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSec) {
    if (Test-PortListening -TargetPort $Port) {
        $portReady = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if ($portReady) {
    Write-Host "Antigravity is listening on port $Port (ready in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2))s)."
    Write-Host "STATUS: PASS"
    exit 0
} else {
    Write-Error "STATUS: FAIL - Port $Port did not become available within $TimeoutSec seconds."
    exit 1
}

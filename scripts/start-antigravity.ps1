<#
.SYNOPSIS
    Starts Antigravity with remote debugging enabled on port 9222.
.DESCRIPTION
    Checks if Antigravity is already running and listening on port 9222.
    If not listening, launches Antigravity with --remote-debugging-port=9222
    and waits until TCP port 9222 is available. Does not modify the Antigravity installation.
.PARAMETER ExePath
    Path to the Antigravity executable. Defaults to standard local app data installation path.
.PARAMETER Port
    Target TCP remote debugging port. Defaults to 9222.
.PARAMETER TimeoutSec
    Maximum seconds to wait for port to become available. Defaults to 30.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ExePath = "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe",

    [int]$Port = 9222,

    [int]$TimeoutSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PortListening {
    param(
        [string]$Address = '127.0.0.1',
        [int]$TargetPort = 9222,
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

Write-Host "=== Antigravity Startup Check ==="
Write-Host "Target Port   : $Port"
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

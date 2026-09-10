<#
.SYNOPSIS
    Checks Antigravity bridge and session readiness.
.DESCRIPTION
    Validates that the Antigravity process is running, TCP port 9222 is listening,
    the DevTools HTTP endpoint is reachable, at least one active page target exists,
    and no stale-session symptoms are detected. Reports PASS, WARN, FAIL, and final readiness status.
.PARAMETER Port
    Target TCP remote debugging port. Defaults to 9222.
.PARAMETER HostAddress
    Target loopback address. Defaults to 127.0.0.1.
.PARAMETER TimeoutSec
    HTTP request timeout in seconds. Defaults to 5.
#>
[CmdletBinding()]
param(
    [int]$Port = 9222,

    [string]$HostAddress = '127.0.0.1',

    [int]$TimeoutSec = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$passes = [System.Collections.Generic.List[string]]::new()
$warns = [System.Collections.Generic.List[string]]::new()
$fails = [System.Collections.Generic.List[string]]::new()

# 1. Check Antigravity process
$procList = @(Get-Process -Name "*antigravity*" -ErrorAction SilentlyContinue)
if ($procList.Count -gt 0) {
    $pids = ($procList | ForEach-Object { $_.Id }) -join ', '
    $passes.Add("Antigravity process running ($($procList.Count) process(es), PID(s): $pids)")
} else {
    $fails.Add("Antigravity process is not running")
}

# 2. Check TCP port listening
$portListening = $false
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $asyncResult = $tcpClient.BeginConnect($HostAddress, $Port, $null, $null)
    $waitSuccess = $asyncResult.AsyncWaitHandle.WaitOne(1000, $false)
    if ($waitSuccess -and $tcpClient.Connected) {
        $tcpClient.EndConnect($asyncResult)
        $portListening = $true
    }
} catch {
    $portListening = $false
} finally {
    $tcpClient.Close()
}

if ($portListening) {
    $passes.Add("TCP port $Port is LISTENING on $HostAddress")
} else {
    $fails.Add("TCP port $Port is NOT listening on $HostAddress")
}

# 3. Check DevTools endpoint reachable & version info
$devToolsReady = $false
$versionData = $null
if ($portListening) {
    $versionUrl = "http://${HostAddress}:${Port}/json/version"
    try {
        $versionData = Invoke-RestMethod -Uri $versionUrl -TimeoutSec $TimeoutSec -ErrorAction Stop
        if ($versionData -and $versionData.Browser) {
            $passes.Add("DevTools endpoint reachable ($($versionData.Browser))")
            $devToolsReady = $true
        } else {
            $fails.Add("DevTools endpoint returned empty or malformed version data")
        }
    } catch {
        $fails.Add("DevTools endpoint unreachable at ($versionUrl): $($_.Exception.Message)")
    }
} else {
    $fails.Add("DevTools endpoint skipped because port $Port is not listening")
}

# 4. Check usable session: active page count > 0 with usable webSocketDebuggerUrl and non-blank URL
if ($devToolsReady) {
    $listUrl = "http://${HostAddress}:${Port}/json"
    try {
        $targets = Invoke-RestMethod -Uri $listUrl -TimeoutSec $TimeoutSec -ErrorAction Stop
        $pageTargets = @($targets | Where-Object { $_.type -eq 'page' })

        if ($pageTargets.Count -gt 0) {
            $usableTargets = @($pageTargets | Where-Object {
                $_.webSocketDebuggerUrl -and
                -not [string]::IsNullOrWhiteSpace($_.webSocketDebuggerUrl) -and
                $_.url -and
                $_.url -ne 'about:blank' -and
                -not [string]::IsNullOrWhiteSpace($_.url)
            })

            if ($usableTargets.Count -gt 0) {
                $passes.Add("Usable session verified ($($usableTargets.Count) active non-blank page target(s) exposing webSocketDebuggerUrl)")
            } else {
                $wsAvailable = @($pageTargets | Where-Object { $_.webSocketDebuggerUrl -and -not [string]::IsNullOrWhiteSpace($_.webSocketDebuggerUrl) })
                if ($wsAvailable.Count -eq 0) {
                    $fails.Add("Unusable session: page targets exist but none expose a valid webSocketDebuggerUrl")
                } else {
                    $fails.Add("Unusable session: all detected page targets are blank or uninitialized (about:blank)")
                }
            }
        } elseif ($targets.Count -gt 0) {
            $fails.Add("Unusable session: DevTools targets detected ($($targets.Count)) but no page-type target found")
        } else {
            $fails.Add("Unusable session: page count is 0 (no DevTools pages detected; session may be detached or stale)")
        }
    } catch {
        $fails.Add("Failed to query DevTools page targets at ($listUrl): $($_.Exception.Message)")
    }
} else {
    $fails.Add("Session readiness check skipped because DevTools endpoint is not ready")
}

# 5. Output PASS / WARN / FAIL sections and readiness status
Write-Host "=== Antigravity Bridge Check ==="
Write-Host "`nPASS:"
if ($passes.Count -gt 0) {
    foreach ($p in $passes) { Write-Host "  - $p" }
} else {
    Write-Host "  None"
}

Write-Host "`nWARN:"
if ($warns.Count -gt 0) {
    foreach ($w in $warns) { Write-Host "  - $w" }
} else {
    Write-Host "  None"
}

Write-Host "`nFAIL:"
if ($fails.Count -gt 0) {
    foreach ($f in $fails) { Write-Host "  - $f" }
} else {
    Write-Host "  None"
}

Write-Host "`nREADINESS STATUS:"
if ($fails.Count -eq 0 -and $warns.Count -eq 0) {
    Write-Host "STATUS: PASS (READY)"
    exit 0
} else {
    Write-Host "STATUS: FAIL (NOT READY)"
    exit 1
}

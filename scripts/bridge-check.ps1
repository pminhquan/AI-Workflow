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

# 4. Check page count > 0 and stale-session symptoms
if ($devToolsReady) {
    $listUrl = "http://${HostAddress}:${Port}/json"
    try {
        $targets = Invoke-RestMethod -Uri $listUrl -TimeoutSec $TimeoutSec -ErrorAction Stop
        $pageTargets = @($targets | Where-Object { $_.type -eq 'page' })

        if ($pageTargets.Count -gt 0) {
            $passes.Add("Active page count > 0 ($($pageTargets.Count) page target(s) detected)")

            # Inspect for stale-session symptoms
            $wsAvailable = @($pageTargets | Where-Object { $_.webSocketDebuggerUrl })
            if ($wsAvailable.Count -eq 0) {
                $warns.Add("Stale-session symptom: pages exist but none expose a valid webSocketDebuggerUrl")
            }

            $blankCount = @($pageTargets | Where-Object { $_.url -eq 'about:blank' -or [string]::IsNullOrWhiteSpace($_.url) }).Count
            if ($blankCount -eq $pageTargets.Count) {
                $warns.Add("Stale-session symptom: all detected page targets are blank or uninitialized")
            }
        } elseif ($targets.Count -gt 0) {
            $warns.Add("DevTools targets detected ($($targets.Count)) but no page-type target found")
        } else {
            $fails.Add("Page count is 0 (no DevTools pages detected; session may be detached or stale)")
        }
    } catch {
        $fails.Add("Failed to query DevTools page targets at ($listUrl): $($_.Exception.Message)")
    }
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
} elseif ($fails.Count -eq 0) {
    Write-Host "STATUS: PASS (READY with warnings)"
    exit 0
} else {
    Write-Host "STATUS: FAIL (NOT READY)"
    exit 1
}

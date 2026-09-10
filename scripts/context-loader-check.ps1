<#
.SYNOPSIS
    Focused test suite for context-loader.ps1 (Phase 2.1).
.DESCRIPTION
    Validates deterministic context loading, task classification, manual @load overrides,
    path traversal safety, and non-destructive behavior for missing/invalid inputs.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loaderScript = Join-Path $scriptDir "context-loader.ps1"

if (-not (Test-Path -LiteralPath $loaderScript -PathType Leaf)) {
    Write-Error "context-loader.ps1 not found at: $loaderScript"
    exit 1
}

$passes = [System.Collections.Generic.List[string]]::new()
$fails = [System.Collections.Generic.List[string]]::new()

function Assert-Equal {
    param(
        [string]$TestName,
        [string]$Actual,
        [string]$Expected
    )
    if ($Actual -eq $Expected) {
        $passes.Add("${TestName}: matched '$Expected'")
    } else {
        $fails.Add("${TestName}: expected '$Expected', got '$Actual'")
    }
}

function Get-LoadedFiles {
    param(
        [string]$Task = "",
        [string]$Project = ""
    )
    $invokeArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $invokeArgs += @('-Project', $Project)
    }
    if (-not [string]::IsNullOrWhiteSpace($Task)) {
        $invokeArgs += @('-Task', $Task)
    }

    $raw = & $loaderScript @invokeArgs
    $line = ($raw | Where-Object { $_ -match '^LOADED:\s*(.*)$' })
    if ($line -match '^LOADED:\s*(.*)$') {
        return $Matches[1].Trim()
    }
    return ""
}

# 1. Acceptance Test: "fix login session bug"
Assert-Equal "Acceptance 1 (fix login session bug)" (Get-LoadedFiles -Task "fix login session bug") "summary.md, health.md, context.md, issues.md"

# 2. Acceptance Test: "design database migration"
Assert-Equal "Acceptance 2 (design database migration)" (Get-LoadedFiles -Task "design database migration") "summary.md, health.md, architecture.md, decisions.md"

# 3. Acceptance Test: manual override "@load architecture decisions"
Assert-Equal "Acceptance 3 (manual override @load architecture decisions)" (Get-LoadedFiles -Task "@load architecture decisions") "summary.md, health.md, architecture.md, decisions.md"

# 4. Classification: feature/implement
Assert-Equal "Classification feature/implement" (Get-LoadedFiles -Task "implement user authentication feature") "summary.md, health.md, context.md, architecture.md"

# 5. Classification: security
Assert-Equal "Classification security" (Get-LoadedFiles -Task "security vulnerability hardening") "summary.md, health.md, architecture.md, issues.md"

# 6. Classification: planning
Assert-Equal "Classification planning" (Get-LoadedFiles -Task "sprint planning and roadmap milestones") "summary.md, health.md, roadmap.md"

# 7. Classification: history
Assert-Equal "Classification history" (Get-LoadedFiles -Task "review changelog history") "summary.md, health.md, decisions.md, changelog.md"

# 8. Path Traversal & Unapproved Memory Override Safety
Assert-Equal "Safety unapproved override rejection" (Get-LoadedFiles -Task "@load ../../secret evil.ps1 context") "summary.md, health.md, context.md"

# 9. Deterministic handling of empty / invalid input (non-destructive)
Assert-Equal "Empty input default" (Get-LoadedFiles) "summary.md, health.md"

# 10. Labeled text output format check
$rawOutput = & $loaderScript -Task "fix login session bug"
$loadedLine = ($rawOutput | Where-Object { $_ -match '^LOADED:\s*(.*)$' })
Assert-Equal "Standard labeled output format" $loadedLine "LOADED: summary.md, health.md, context.md, issues.md"

# 11. Real file presence test in temporary isolated project directory
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wf-test-" + [System.Guid]::NewGuid().ToString("N"))
try {
    [void](New-Item -ItemType Directory -Path $tempDir)
    Set-Content -LiteralPath (Join-Path $tempDir "summary.md") -Value "# Summary"
    Set-Content -LiteralPath (Join-Path $tempDir "health.md") -Value "# Health"
    Set-Content -LiteralPath (Join-Path $tempDir "context.md") -Value "# Context"
    # Note: issues.md omitted intentionally to verify Missing status

    $tempOutput = & $loaderScript -Project $tempDir -Task "fix login session bug"
    $filesLine = ($tempOutput | Where-Object { $_ -match '^FILES:\s*(.*)$' })
    if ($filesLine -match 'summary\.md \(Found\)' -and
        $filesLine -match 'health\.md \(Found\)' -and
        $filesLine -match 'context\.md \(Found\)' -and
        $filesLine -match 'issues\.md \(Missing\)') {
        $passes.Add("File status detection: accurately reports Found and Missing files without mutation")
    } else {
        $fails.Add("File status detection failed: got '$filesLine'")
    }
} finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Host "PASS:"
foreach ($p in $passes) {
    Write-Host "- $p"
}

if ($fails.Count -gt 0) {
    Write-Host "`nFAIL:"
    foreach ($f in $fails) {
        Write-Host "- $f"
    }
    exit 1
} else {
    Write-Host "`nFAIL:`nNone"
}

Write-Host "`nNEXT:`nContext loader tests passed successfully."
exit 0

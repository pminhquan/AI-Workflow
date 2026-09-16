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
Assert-Equal "Acceptance 1 (fix login session bug)" (Get-LoadedFiles -Task "fix login session bug") "summary.md, context.md, issues.md"

# 2. Acceptance Test: "design database migration"
Assert-Equal "Acceptance 2 (design database migration)" (Get-LoadedFiles -Task "design database migration") "summary.md, architecture.md, decisions.md"

# 3. Acceptance Test: manual override "@load architecture decisions"
Assert-Equal "Acceptance 3 (manual override @load architecture decisions)" (Get-LoadedFiles -Task "@load architecture decisions") "summary.md, architecture.md, decisions.md"

# 4. Classification: feature/implement
Assert-Equal "Classification feature/implement" (Get-LoadedFiles -Task "implement user authentication feature") "summary.md, context.md, architecture.md"

# 5. Classification: security
Assert-Equal "Classification security" (Get-LoadedFiles -Task "security vulnerability hardening") "summary.md, architecture.md, issues.md"

# 6. Classification: planning
Assert-Equal "Classification planning" (Get-LoadedFiles -Task "sprint planning and roadmap milestones") "summary.md, roadmap.md"

# 7. Classification: history
Assert-Equal "Classification history" (Get-LoadedFiles -Task "review changelog history") "summary.md, decisions.md, changelog.md"

# 8. Path Traversal & Unapproved Memory Override Safety
Assert-Equal "Safety unapproved override rejection" (Get-LoadedFiles -Task "@load ../../secret evil.ps1 context") "summary.md, context.md"

# 9. Deterministic handling of empty / invalid input (non-destructive)
Assert-Equal "Empty input default" (Get-LoadedFiles) "summary.md"

# 10. Labeled text output format check
$rawOutput = & $loaderScript -Task "fix login session bug"
$loadedLine = ($rawOutput | Where-Object { $_ -match '^LOADED:\s*(.*)$' })
Assert-Equal "Standard labeled output format" $loadedLine "LOADED: summary.md, context.md, issues.md"

# 11. Real file presence test in temporary isolated project directory via test seam
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wf-test-root-" + [System.Guid]::NewGuid().ToString("N"))
$tempProjDir = Join-Path $tempRoot "test-proj"
try {
    [void](New-Item -ItemType Directory -Path $tempProjDir)
    Set-Content -LiteralPath (Join-Path $tempProjDir "summary.md") -Value "# Summary"
    Set-Content -LiteralPath (Join-Path $tempProjDir "context.md") -Value "# Context"
    # Note: issues.md omitted intentionally to verify Missing status

    $env:PROJECT_MEMORY_ROOT = $tempRoot
    $tempOutput = & $loaderScript -Project "test-proj" -Task "fix login session bug"
    $filesLine = ($tempOutput | Where-Object { $_ -match '^FILES:\s*(.*)$' })
    if ($filesLine -match 'summary\.md \(Found\)' -and
        $filesLine -match 'context\.md \(Found\)' -and
        $filesLine -match 'issues\.md \(Missing\)') {
        $passes.Add("File status detection: accurately reports Found and Missing files without mutation")
    } else {
        $fails.Add("File status detection failed: got '$filesLine'")
    }
} finally {
    Remove-Item env:PROJECT_MEMORY_ROOT -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 12. Classification: conditional health/audit loading
Assert-Equal "Classification health/audit" (Get-LoadedFiles -Task "system health check and audit") "summary.md, health.md"

# 13. Empty or unrelated tasks load only always-loaded boundary
Assert-Equal "Unrelated task loads always-loaded boundary" (Get-LoadedFiles -Task "unrelated conversational question") "summary.md"

# 14. Clear failure reporting for missing project
$missingProjOut = & $loaderScript -Project "nonexistent_proj_xyz" -Task "fix login bug"
$statusLine = ($missingProjOut | Where-Object { $_ -match '^STATUS:\s*(.*)$' })
if ($statusLine -match '^STATUS:\s*FAIL\s*\(Project directory not found:') {
    $passes.Add("Missing project: returns explicit clear failure STATUS")
} else {
    $fails.Add("Missing project failed to return explicit failure STATUS: got '$statusLine'")
}

# 15. Authoritative root resolution and bounded context content delivery
$aiWorkflowOut = & $loaderScript -Project "ai-workflow" -Task "fix login bug"
$contentBegun = ($aiWorkflowOut | Where-Object { $_ -eq '--- BEGIN CONTEXT CONTENT ---' })
$summaryBlock = ($aiWorkflowOut | Where-Object { $_ -match '^=== CONTEXT FILE: summary\.md' })
$statusPass = ($aiWorkflowOut | Where-Object { $_ -match '^STATUS:\s*PASS' })
if ($contentBegun -and $summaryBlock -and $statusPass) {
    $passes.Add("Content delivery: delivers bounded labeled context content with PASS status from authoritative root")
} else {
    $fails.Add("Content delivery failed: expected BEGIN CONTEXT, summary.md block, and STATUS: PASS")
}

# 16. Explicit failure when configured environment root is invalid
$badRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("nonexistent-root-" + [System.Guid]::NewGuid().ToString("N"))
try {
    $env:PROJECT_MEMORY_ROOT = $badRoot
    $missingRootOut = & $loaderScript -Project "ai-workflow"
    $rootStatusLine = ($missingRootOut | Where-Object { $_ -match '^STATUS:\s*(.*)$' })
    if ($rootStatusLine -match '^STATUS:\s*FAIL\s*\(Project memory root not found:') {
        $passes.Add("Missing memory root: returns explicit clear failure STATUS without falling back")
    } else {
        $fails.Add("Missing memory root failed to return explicit failure STATUS: got '$rootStatusLine'")
    }
} finally {
    Remove-Item env:PROJECT_MEMORY_ROOT -ErrorAction SilentlyContinue
}

# 17. Absence of repo-local projects fallback (non-destructive source inspection and runtime verification)
$loaderContent = Get-Content -LiteralPath $loaderScript -Raw
$hasRepoFallback = ($loaderContent -match '\$repoRoot' -or $loaderContent -match 'Join-Path.*["'']projects["'']')
$hasDefaultAuthority = ($loaderContent -match '\$defaultMemoryRoot\s*=\s*["''][^"'']*codex-anti[\\/]projects["'']')

$noFallbackOut = & $loaderScript -Project "dummy-nonexistent-project"
$noFallbackStatus = ($noFallbackOut | Where-Object { $_ -match '^STATUS:\s*(.*)$' })
$noFallbackMemRoot = ($noFallbackOut | Where-Object { $_ -match '^MEMORY_ROOT:\s*(.*)$' })

if (-not $hasRepoFallback -and
    $hasDefaultAuthority -and
    $noFallbackMemRoot -match 'MEMORY_ROOT:\s*.*codex-anti[\\/]projects' -and
    $noFallbackStatus -match '^STATUS:\s*FAIL\s*\(Project directory not found: .*codex-anti[\\/]projects[\\/]dummy-nonexistent-project\)') {
    $passes.Add("Absence of repo-local fallback: verified loader source has no repo-local fallback and runtime defaults to authoritative root")
} else {
    $fails.Add("Absence of repo-local fallback failed: hasRepoFallback=$hasRepoFallback, hasDefaultAuthority=$hasDefaultAuthority, status='$noFallbackStatus'")
}

# 18. Project input cannot escape authoritative root
$escapeOut = & $loaderScript -Project "..\..\escape-test"
$escapeStatus = ($escapeOut | Where-Object { $_ -match '^STATUS:\s*(.*)$' })
if ($escapeStatus -match '^STATUS:\s*FAIL\s*\(Project directory not found: .*codex-anti[\\/]projects[\\/]escape-test\)') {
    $passes.Add("Root containment: project input is constrained to authoritative root and cannot traverse paths")
} else {
    $fails.Add("Root containment failed: got '$escapeStatus'")
}

# 19. Context size measurement (Phase 3.1 lightweight observability)
$sizeCheckOut = & $loaderScript -Project "ai-workflow" -Task "fix login bug"
$sizeLine = ($sizeCheckOut | Where-Object { $_ -match '^SIZE_BYTES:\s*(\d+)$' })
if ($sizeLine -match '^SIZE_BYTES:\s*(\d+)' -and [int]$Matches[1] -gt 0) {
    $passes.Add("Context measurement: accurately reports UTF-8 context size in bytes ($($Matches[1]) bytes)")
} else {
    $fails.Add("Context measurement failed: expected positive integer SIZE_BYTES, got '$sizeLine'")
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

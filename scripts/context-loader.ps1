<#
.SYNOPSIS
    Lightweight, deterministic project memory context loader (Phase 2.1).
.DESCRIPTION
    Deterministically selects and loads project memory files from projects/<project>/
    based on task classification rules or manual @load override syntax.
    Strictly read-only and non-destructive; never modifies repository files or executes external services.
.PARAMETER Project
    Target project name or directory under projects/. Defaults to 'default'.
.PARAMETER Task
    Task description for classification, or string containing manual @load override.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Project = "",

    [Parameter(Position = 1)]
    [string]$Task = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Location).Path
$warnings = [System.Collections.Generic.List[string]]::new()

# Canonical memory layout in stable deterministic order
$canonicalMemoryFiles = @(
    'summary.md',
    'health.md',
    'context.md',
    'architecture.md',
    'decisions.md',
    'roadmap.md',
    'issues.md',
    'changelog.md'
)

# Always select summary.md and health.md
$selectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$selectedSet.Add('summary.md')
[void]$selectedSet.Add('health.md')

# Check for manual override syntax (@load ...)
$overrideString = ""
if (-not [string]::IsNullOrWhiteSpace($Task) -and ($Task -match '(?i)@load\s+([^@\r\n]+)')) {
    $overrideString = $Matches[1].Trim()
}

if (-not [string]::IsNullOrWhiteSpace($overrideString)) {
    # Manual override mode: strictly allowlist known memory names to prevent directory traversal
    $tokens = $overrideString -split '[\s,]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $unapproved = [System.Collections.Generic.List[string]]::new()

    foreach ($token in $tokens) {
        $clean = $token.Trim().Trim('`', '"', "'", ';', '.')
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        $candidate = if ($clean.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
            $clean.ToLowerInvariant()
        } else {
            "$($clean.ToLowerInvariant()).md"
        }

        if ($candidate -in $canonicalMemoryFiles) {
            [void]$selectedSet.Add($candidate)
        } else {
            $unapproved.Add($clean)
        }
    }

    if ($unapproved.Count -gt 0) {
        $warnings.Add("Ignored unapproved memory override(s): $($unapproved -join ', ')")
    }
} else {
    # Deterministic task classification rules
    if (-not [string]::IsNullOrWhiteSpace($Task)) {
        if ($Task -match '(?i)\b(feature|implement|implementation|feat)\b|/feature|/implement') {
            [void]$selectedSet.Add('context.md')
            [void]$selectedSet.Add('architecture.md')
        }
        if ($Task -match '(?i)\b(bug|fix|defect|patch|hotfix)\b|/fix') {
            [void]$selectedSet.Add('context.md')
            [void]$selectedSet.Add('issues.md')
        }
        if ($Task -match '(?i)\b(database|db|migration|sql|schema)\b|/db') {
            [void]$selectedSet.Add('architecture.md')
            [void]$selectedSet.Add('decisions.md')
        }
        if ($Task -match '(?i)\b(security|vulnerability|cve|vuln|hardening)\b|/security') {
            [void]$selectedSet.Add('architecture.md')
            [void]$selectedSet.Add('issues.md')
        }
        if ($Task -match '(?i)\b(planning|plan|roadmap|milestone)\b') {
            [void]$selectedSet.Add('roadmap.md')
        }
        if ($Task -match '(?i)\b(history|changelog)\b|/release') {
            [void]$selectedSet.Add('decisions.md')
            [void]$selectedSet.Add('changelog.md')
        }
    }
}

# Retain stable canonical order
$selectedFiles = @($canonicalMemoryFiles | Where-Object { $selectedSet.Contains($_) })

# Resolve project memory directory explicitly and deterministically
$projectDir = $null
$projectName = ""

if (-not [string]::IsNullOrWhiteSpace($Project)) {
    if (Test-Path -LiteralPath $Project -PathType Container) {
        $projectDir = (Resolve-Path -LiteralPath $Project).Path
        $projectName = Split-Path -Path $projectDir -Leaf
    } else {
        $candidateSub = Join-Path (Join-Path $repoRoot "projects") $Project
        if (Test-Path -LiteralPath $candidateSub -PathType Container) {
            $projectDir = (Resolve-Path -LiteralPath $candidateSub).Path
            $projectName = Split-Path -Path $projectDir -Leaf
        } else {
            $projectDir = $candidateSub
            $projectName = $Project
            $warnings.Add("Project memory directory not found: projects/$Project")
        }
    }
} else {
    $projectDir = Join-Path (Join-Path $repoRoot "projects") "default"
    $projectName = "default"
}

# Inspect selected files presence (non-destructive)
$fileRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
$missingFiles = [System.Collections.Generic.List[string]]::new()

foreach ($file in $selectedFiles) {
    $fullPath = Join-Path $projectDir $file
    $exists = Test-Path -LiteralPath $fullPath -PathType Leaf
    $status = if ($exists) { "Found" } else { "Missing" }
    if (-not $exists) {
        $missingFiles.Add($file)
    }
    $fileRecords.Add([PSCustomObject]@{
        Name   = $file
        Status = $status
        Path   = $fullPath
        Exists = $exists
    })
}

if ($missingFiles.Count -gt 0) {
    $warnings.Add("Missing memory file(s) in ${projectName}: $($missingFiles -join ', ')")
}

$loadedDisplay = $selectedFiles -join ', '
$filesDisplay = ($fileRecords | ForEach-Object { "$($_.Name) ($($_.Status))" }) -join ', '
$warningsDisplay = if ($warnings.Count -gt 0) { $warnings -join "; " } else { "None" }

Write-Output "PROJECT: $projectName"
Write-Output "TASK: $Task"
Write-Output "LOADED: $loadedDisplay"
Write-Output "FILES: $filesDisplay"
Write-Output "WARNINGS: $warningsDisplay"

exit 0

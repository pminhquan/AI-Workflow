<#
.SYNOPSIS
    Lightweight, deterministic project memory context loader (Phase 2.1).
.DESCRIPTION
    Deterministically selects and loads project memory files from the single authoritative memory root
    (default: D:\AI\codex-anti\projects [Antigravity memory root] or explicit $env:PROJECT_MEMORY_ROOT) based on the explicit loading
    boundary: always compact project identity (summary.md); conditionally deeper architecture,
    decisions, issues, roadmap, health, and changelog; manual @load overrides strictly allowlisted.
    Returns bounded labeled context content for usable agent ingestion.
    Strictly read-only and non-destructive; never modifies repository files or executes external services.
.PARAMETER Project
    Target project name under authoritative memory root. Defaults to 'default'.
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

$MaxLinesPerFile = 200
$MaxBytesPerFile = 16384
$warnings = [System.Collections.Generic.List[string]]::new()

# Resolve single authoritative project-memory root (no repo-local fallback)
$defaultMemoryRoot = "D:\AI\codex-anti\projects"
$MemoryRoot = $null

if (-not [string]::IsNullOrWhiteSpace($env:PROJECT_MEMORY_ROOT)) {
    # Explicit configured environment override for portability/testing: must fail clearly if invalid
    $MemoryRoot = $env:PROJECT_MEMORY_ROOT
    if (Test-Path -LiteralPath $MemoryRoot -PathType Container) {
        $MemoryRoot = (Resolve-Path -LiteralPath $MemoryRoot).Path
    }
} else {
    # Default authoritative root
    $MemoryRoot = $defaultMemoryRoot
    if (Test-Path -LiteralPath $MemoryRoot -PathType Container) {
        $MemoryRoot = (Resolve-Path -LiteralPath $MemoryRoot).Path
    }
}

$rootExists = Test-Path -LiteralPath $MemoryRoot -PathType Container
if (-not $rootExists) {
    $warnings.Add("Authoritative project memory root not found: $MemoryRoot")
}

# Resolve project memory directory under authoritative root (prevent root escape)
$projectDir = $null
$projectName = ""
$projectFound = $false

if ($rootExists) {
    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        # Strip any path separators or traversal elements; project is strictly a child directory of MemoryRoot
        $projectName = Split-Path -Path $Project.Trim().TrimEnd('\', '/') -Leaf
        if ([string]::IsNullOrWhiteSpace($projectName) -or $projectName -eq '.' -or $projectName -eq '..' -or $projectName -match '^[a-zA-Z]:') {
            $projectName = "invalid-project"
        }
        $candidateSub = Join-Path $MemoryRoot $projectName
        if (Test-Path -LiteralPath $candidateSub -PathType Container) {
            $projectDir = (Resolve-Path -LiteralPath $candidateSub).Path
            $projectFound = $true
        } else {
            $projectDir = $candidateSub
            $warnings.Add("Project memory directory not found: $candidateSub")
        }
    } else {
        $projectName = "default"
        $candidateDefault = Join-Path $MemoryRoot "default"
        if (Test-Path -LiteralPath $candidateDefault -PathType Container) {
            $projectDir = (Resolve-Path -LiteralPath $candidateDefault).Path
            $projectFound = $true
        } else {
            $projectDir = $candidateDefault
            $warnings.Add("Project memory directory not found: $candidateDefault")
        }
    }
} else {
    $projectName = if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $clean = Split-Path -Path $Project.Trim().TrimEnd('\', '/') -Leaf
        if ([string]::IsNullOrWhiteSpace($clean) -or $clean -eq '.' -or $clean -eq '..' -or $clean -match '^[a-zA-Z]:') { "invalid-project" } else { $clean }
    } else {
        "default"
    }
    $projectDir = Join-Path $MemoryRoot $projectName
}

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

# Explicit loading boundary: always compact project identity (summary.md)
$selectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$selectedSet.Add('summary.md')

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
    # Deterministic task classification rules: conditional memory loading
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
        if ($Task -match '(?i)\b(health|audit|status|check|metrics)\b|/audit') {
            [void]$selectedSet.Add('health.md')
        }
    }
}

# Retain stable canonical order
$selectedFiles = @($canonicalMemoryFiles | Where-Object { $selectedSet.Contains($_) })

# Inspect selected files presence and retrieve bounded content (non-destructive)
$fileRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
$missingFiles = [System.Collections.Generic.List[string]]::new()
$contentBlocks = [System.Collections.Generic.List[string]]::new()
$contextSizeBytes = 0

foreach ($file in $selectedFiles) {
    $fullPath = Join-Path $projectDir $file
    $exists = $projectFound -and (Test-Path -LiteralPath $fullPath -PathType Leaf)
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

    if ($exists) {
        try {
            $lines = [System.IO.File]::ReadAllLines($fullPath)
            $totalLines = $lines.Count
            $boundedLines = if ($totalLines -gt $MaxLinesPerFile) {
                $lines[0..($MaxLinesPerFile - 1)]
            } else {
                $lines
            }
            $joined = $boundedLines -join [System.Environment]::NewLine
            if ($joined.Length -gt $MaxBytesPerFile) {
                $joined = $joined.Substring(0, $MaxBytesPerFile) + "`n[... TRUNCATED: Content bounded to $MaxBytesPerFile bytes ...]"
            } elseif ($totalLines -gt $MaxLinesPerFile) {
                $joined += "`n[... TRUNCATED: Content bounded to $MaxLinesPerFile lines (total $totalLines) ...]"
            }
            $contextSizeBytes += [System.Text.Encoding]::UTF8.GetByteCount($joined)
            $contentBlocks.Add("=== CONTEXT FILE: $file ($fullPath) ===`n$joined")
        } catch {
            $warnings.Add("Failed reading $file : $($_.Exception.Message)")
            $contentBlocks.Add("=== CONTEXT FILE: $file (ERROR: $($_.Exception.Message)) ===")
        }
    } else {
        $contentBlocks.Add("=== CONTEXT FILE: $file (MISSING: $fullPath) ===`n[File missing: $fullPath]")
    }
}

if ($missingFiles.Count -gt 0) {
    $warnings.Add("Missing memory file(s) in ${projectName}: $($missingFiles -join ', ')")
}

$statusDisplay = if (-not $rootExists) {
    "FAIL (Project memory root not found: $MemoryRoot)"
} elseif (-not $projectFound) {
    "FAIL (Project directory not found: $projectDir)"
} elseif ($missingFiles.Count -gt 0) {
    "FAIL (Missing memory file(s) in ${projectName}: $($missingFiles -join ', '))"
} else {
    "PASS"
}

$loadedDisplay = $selectedFiles -join ', '
$filesDisplay = ($fileRecords | ForEach-Object { "$($_.Name) ($($_.Status))" }) -join ', '
$warningsDisplay = if ($warnings.Count -gt 0) { $warnings -join "; " } else { "None" }

Write-Output "STATUS: $statusDisplay"
Write-Output "PROJECT: $projectName"
Write-Output "MEMORY_ROOT: $MemoryRoot"
Write-Output "TASK: $Task"
Write-Output "LOADED: $loadedDisplay"
Write-Output "FILES: $filesDisplay"
Write-Output "SIZE_BYTES: $contextSizeBytes"
Write-Output "WARNINGS: $warningsDisplay"
Write-Output ""
Write-Output "--- BEGIN CONTEXT CONTENT ---"
foreach ($block in $contentBlocks) {
    Write-Output $block
    Write-Output ""
}
Write-Output "--- END CONTEXT CONTENT ---"

exit 0

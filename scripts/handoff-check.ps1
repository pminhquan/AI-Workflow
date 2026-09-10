<#
.SYNOPSIS
    Read-only validator for task handoff Markdown contracts.
.DESCRIPTION
    Validates task handoff Markdown files against the canonical contract:
    1. Verifies the presence of all nine required headings (META, INTENT, RISK, TARGET,
       ALLOWLIST, EXECUTOR, ACCEPTANCE CRITERIA, TEST, EVIDENCE).
    2. Validates META.STATE against the six permitted lifecycle values:
       CREATED, READY, EXECUTING, VERIFYING, COMPLETED, FAILED.
    3. Requires an existing evidence directory via -EvidenceDir when the state is
       VERIFYING, COMPLETED, or FAILED.
    Strictly read-only; never mutates files, schedules work, or invokes external services.
.PARAMETER Path
    Path to the task handoff Markdown file.
.PARAMETER EvidenceDir
    Explicit path to the evidence directory. Mandatory when state is VERIFYING, COMPLETED, or FAILED.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Position = 1)]
    [string]$EvidenceDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$passes = [System.Collections.Generic.List[string]]::new()
$fails = [System.Collections.Generic.List[string]]::new()

# 1. Validate file existence
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Host "FAIL:"
    Write-Host "- Handoff file does not exist: $Path"
    exit 1
}

$content = Get-Content -LiteralPath $Path -Raw
if ([string]::IsNullOrWhiteSpace($content)) {
    Write-Host "FAIL:"
    Write-Host "- Handoff file is empty: $Path"
    exit 1
}

# 2. Validate all nine required headings
$requiredHeadings = @(
    'META',
    'INTENT',
    'RISK',
    'TARGET',
    'ALLOWLIST',
    'EXECUTOR',
    'ACCEPTANCE CRITERIA',
    'TEST',
    'EVIDENCE'
)

$missingHeadings = [System.Collections.Generic.List[string]]::new()
foreach ($heading in $requiredHeadings) {
    $pattern = "(?mi)^#{1,6}\s+" + [regex]::Escape($heading) + "\s*$"
    if ($content -match $pattern) {
        $passes.Add("Required heading present: $heading")
    } else {
        $missingHeadings.Add($heading)
        $fails.Add("Missing required heading: $heading")
    }
}

# 3. Validate META.STATE against the six permitted lifecycle values
$validStates = @('CREATED', 'READY', 'EXECUTING', 'VERIFYING', 'COMPLETED', 'FAILED')
$extractedState = $null

if ($content -match '(?msi)^#{1,6}\s+META\s*$(.*?)(?=^#{1,6}\s+|\z)') {
    $metaSection = $Matches[1]
    if ($metaSection -match '(?mi)\bSTATE\b\*{0,2}\s*:\s*[`"'']?([A-Za-z_-]+)[`"'']?') {
        $extractedState = $Matches[1].ToUpperInvariant()
    }
}

if ([string]::IsNullOrWhiteSpace($extractedState)) {
    $fails.Add("META.STATE not found or not specified in META section")
} elseif ($extractedState -in $validStates) {
    $passes.Add("Valid lifecycle state in META: $extractedState")
} else {
    $fails.Add("Invalid META.STATE '$extractedState'. Permitted states: $($validStates -join ', ')")
}

# 4. Require existing evidence directory when state is VERIFYING, COMPLETED, or FAILED
$evidenceRequiredStates = @('VERIFYING', 'COMPLETED', 'FAILED')
if (-not [string]::IsNullOrWhiteSpace($extractedState) -and ($extractedState -in $evidenceRequiredStates)) {
    if ([string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $fails.Add("Evidence directory (-EvidenceDir) is required when META.STATE is '$extractedState'")
    } elseif (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) {
        $fails.Add("Required evidence directory does not exist: $EvidenceDir")
    } else {
        $passes.Add("Evidence directory verified for '$extractedState': $EvidenceDir")
    }
} elseif (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
    if (Test-Path -LiteralPath $EvidenceDir -PathType Container) {
        $passes.Add("Optional evidence directory verified: $EvidenceDir")
    } else {
        $fails.Add("Provided evidence directory does not exist: $EvidenceDir")
    }
}

# 5. Output results and exit
if ($fails.Count -gt 0) {
    Write-Host "FAIL:"
    foreach ($f in $fails) {
        Write-Host "- $f"
    }
    exit 1
}

Write-Host "PASS:"
foreach ($p in $passes) {
    Write-Host "- $p"
}
exit 0

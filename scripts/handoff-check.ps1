<#
.SYNOPSIS
    Read-only validator for task handoff Markdown contracts.
.DESCRIPTION
    Validates task handoff Markdown files against the canonical contract:
    1. Verifies the presence of all nine required headings (META, INTENT, RISK, TARGET,
       ALLOWLIST, EXECUTOR, ACCEPTANCE CRITERIA, TEST, EVIDENCE).
    2. Validates explicit execution request contract fields: task ID, target workspace,
       executor, and artifact location (rejecting unknown-workspace and implicit-executor assumptions).
    3. Validates META.STATE against the six unified lifecycle values:
       CREATED, SUBMITTED, RUNNING, ARTIFACT_READY, VERIFIED, CLOSED.
    4. Requires an existing evidence directory via -EvidenceDir when the state is
       ARTIFACT_READY, VERIFIED, or CLOSED.
    Strictly read-only; never mutates files, schedules work, or invokes external services.
.PARAMETER Path
    Path to the task handoff Markdown file.
.PARAMETER EvidenceDir
    Explicit path to the evidence directory. Mandatory when state is ARTIFACT_READY, VERIFIED, or CLOSED.
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

# 2b. Validate META.STATE and extract lifecycle state
$validStates = @('CREATED', 'SUBMITTED', 'RUNNING', 'ARTIFACT_READY', 'VERIFIED', 'CLOSED')
$bridgeExecutionStates = @('SUBMITTED', 'RUNNING', 'ARTIFACT_READY', 'VERIFIED', 'CLOSED')
$extractedState = $null
$metaSection = ""

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
    $fails.Add("Invalid META.STATE '$extractedState'. Permitted unified states: $($validStates -join ', ')")
}

$isExecutionState = (-not [string]::IsNullOrWhiteSpace($extractedState) -and ($extractedState -in $bridgeExecutionStates))

# 2c. Validate explicit execution request properties
# Explicit task ID in META
if (-not [string]::IsNullOrWhiteSpace($metaSection)) {
    if ($metaSection -match '(?mi)\b(?:id|task|taskid)\b\*{0,2}\s*:\s*[`"'']?([A-Za-z0-9_.-]+|<[A-Za-z0-9_.-]+>)[`"'']?') {
        $passes.Add("Explicit task identifier present in META: $($Matches[1])")
    } else {
        $fails.Add("META section missing explicit task identifier (id/taskId)")
    }
}

# Explicit workspace in TARGET (rejecting unknown-workspace assumptions)
if ($content -match '(?msi)^#{1,6}\s+TARGET\s*$(.*?)(?=^#{1,6}\s+|\z)') {
    $targetBody = $Matches[1].Trim()
    if ([string]::IsNullOrWhiteSpace($targetBody) -or $targetBody -match '(?i)^\s*(`?unknown`?|`?unspecified`?|`?tbd`?)\s*$') {
        $fails.Add("TARGET section must specify an explicit workspace or target; unknown-workspace assumption rejected")
    } elseif ($isExecutionState) {
        $hasAbsolutePath = ($targetBody -match '(?m)(?:^|\s|[`"''])([A-Za-z]:[\\/][^`"''\r\n]*|\\\\[^`"''\r\n\s]+[\\/][^`"''\r\n\s]+)') -and
                           ($targetBody -notmatch '(?i)\b(unknown|unspecified|tbd)\b')
        if ($hasAbsolutePath) {
            $matchedPath = $Matches[1].Trim()
            $passes.Add("Explicit absolute workspace path specified in TARGET: $matchedPath")
        } else {
            $fails.Add("TARGET section must contain an explicit absolute workspace path (Windows drive or UNC, not unknown/unspecified) for execution state '$extractedState'")
        }
    } else {
        $passes.Add("Explicit workspace/target specified in TARGET")
    }
}

# Explicit executor in EXECUTOR (rejecting implicit-executor assumptions)
if ($content -match '(?msi)^#{1,6}\s+EXECUTOR\s*$(.*?)(?=^#{1,6}\s+|\z)') {
    $executorBody = $Matches[1].Trim()
    if ([string]::IsNullOrWhiteSpace($executorBody) -or $executorBody -match '(?i)^\s*(`?unknown`?|`?unspecified`?|`?implicit`?|`?tbd`?)\s*$') {
        $fails.Add("EXECUTOR section must specify an explicit executor; implicit-executor assumption rejected")
    } else {
        $isDelegated = ($content -match '(?mi)\b(?:delegated|bridge)\b') -or
                       ($executorBody -match '(?i)\bantigravity\b') -or
                       ($metaSection -match '(?mi)\b(?:routing|mode)\b.*delegated')

        if ($isExecutionState -and $isDelegated) {
            if ($executorBody -match '(?i)\bantigravity\b') {
                if ($metaSection -match '(?mi)\b(?:routing|routingdecision)\b\*{0,2}\s*:\s*[`"'']?direct[`"'']?') {
                    $fails.Add("Delegated execution identifying Antigravity cannot record routing: DIRECT (must be DELEGATED; DIRECT preserved only where Codex executes directly)")
                } else {
                    $passes.Add("Explicit executor specified in EXECUTOR (delegated bridge execution identifies Antigravity)")
                }
            } else {
                $fails.Add("EXECUTOR section for delegated bridge execution must identify Antigravity (found: $executorBody)")
            }
        } elseif ($executorBody -match '(?i)\b(antigravity|native codex|codex|chatweb|user)\b') {
            $passes.Add("Explicit executor specified in EXECUTOR: $executorBody")
        } else {
            $passes.Add("Explicit executor specified in EXECUTOR")
        }
    }
}

# Explicit artifact location/expectations in EVIDENCE
if ($content -match '(?msi)^#{1,6}\s+EVIDENCE\s*$(.*?)(?=^#{1,6}\s+|\z)') {
    $evidenceBody = $Matches[1].Trim()
    if ([string]::IsNullOrWhiteSpace($evidenceBody) -or $evidenceBody -match '(?i)^\s*(`?unknown`?|`?unspecified`?|`?tbd`?)\s*$') {
        $fails.Add("EVIDENCE section must specify explicit artifact expectations; unknown or empty rejected")
    } elseif ($isExecutionState) {
        $hasDirLocation = ($evidenceBody -match '(?mi)\b(?:artifact\s+directory|evidence\s+directory|directory|artifact\s+location|evidence\s+location|location|jobfolder|folder)\b\*{0,2}\s*[:=]\s*([^\r\n]+)') -or
                          ($evidenceBody -match '(?m)(?:^|\s|[`"''])(?:[A-Za-z]:[\\/]|\\\\[^`"''\s]+|\.?[\\/]?(?:handoffs[\\/](?:active|completed)[\\/][A-Za-z0-9_.-]+|\.antigravity-bridge[\\/]jobs[\\/][A-Za-z0-9_.-]+))')

        if ($hasDirLocation) {
            $matchedLocation = if ($Matches[1]) { $Matches[1].Trim() } else { "explicit directory/location identified" }
            $passes.Add("Explicit artifact/evidence directory or location specified in EVIDENCE: $matchedLocation")
        } else {
            $fails.Add("EVIDENCE section must identify an explicit artifact/evidence directory or artifact location for execution state '$extractedState' (cannot merely say 'result')")
        }
    } else {
        if ($evidenceBody -match '(?mi)^\s*(`?unknown`?|`?unspecified`?|`?tbd`?)\s*$') {
            $fails.Add("EVIDENCE section contains unknown/unspecified artifact expectations")
        } else {
            $passes.Add("Artifact expectations specified in EVIDENCE (CREATED planning state)")
        }
    }
}

# 4. Require existing evidence directory when state is ARTIFACT_READY, VERIFIED, or CLOSED
$evidenceRequiredStates = @('ARTIFACT_READY', 'VERIFIED', 'CLOSED')
if (-not [string]::IsNullOrWhiteSpace($extractedState) -and ($extractedState -in $evidenceRequiredStates)) {
    if ([string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $fails.Add("Evidence directory (-EvidenceDir) is required when META.STATE is '$extractedState'")
    } elseif (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) {
        $fails.Add("Required evidence directory does not exist: $EvidenceDir")
    } else {
        $passes.Add("Evidence directory verified for '$extractedState': $EvidenceDir")

        # Issue 2: CLOSED must be allowed only after verification succeeds
        if ($extractedState -eq 'CLOSED') {
            $statusJsonInEvidence = Join-Path $EvidenceDir "status.json"
            if (Test-Path -LiteralPath $statusJsonInEvidence -PathType Leaf) {
                try {
                    $sObj = ConvertFrom-Json (Get-Content -LiteralPath $statusJsonInEvidence -Raw) -ErrorAction Stop
                    $vStat = if ($sObj.PSObject.Properties['validation']) { [string]$sObj.validation } elseif ($sObj.PSObject.Properties['status']) { [string]$sObj.status } else { "" }
                    if ($vStat.ToUpperInvariant() -ne 'PASS') {
                        $fails.Add("META.STATE is CLOSED but evidence status.json validation is '$vStat' (CLOSED allowed only after verification succeeds)")
                    } else {
                        $passes.Add("CLOSED state corroborated by passing evidence validation status in status.json")
                    }
                } catch {
                    $fails.Add("META.STATE is CLOSED but status.json in evidence directory could not be parsed")
                }
            }
        }
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

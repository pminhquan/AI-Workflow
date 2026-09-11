<#
.SYNOPSIS
    Lightweight evidence validator for task closure reliability (Phase 2.3).
.DESCRIPTION
    Validates task execution evidence folders against the canonical contract:
    1. Artifact validation: verifies status.json, result.md, changed-files.txt, diff.patch,
       and test-output-summary.md (when required).
    2. JSON validation: verifies status.json is valid JSON with required properties.
    3. Consistency validation: verifies task ID matches between handoff and evidence,
       and validation result is explicit.
    4. Scope validation: verifies changed-files.txt matches diff.patch changes, and all changed
       files respect the ALLOWLIST.
    5. Test validation: verifies test totals are internally consistent and any failures are waived.
.PARAMETER EvidenceDir
    Path to the evidence directory to validate.
.PARAMETER HandoffPath
    Optional path to the associated task handoff Markdown file. Auto-discovered if omitted.
.PARAMETER Allowlist
    Optional explicit list of permitted file paths or glob patterns overriding handoff ALLOWLIST.
.PARAMETER RequireTestSummary
    Switch to mandate test-output-summary.md even if not detected from handoff/policy.
.PARAMETER SelfCheck
    Switch to run isolated assert-based self-checks covering valid, missing, and incomplete evidence.
#>
[CmdletBinding(DefaultParameterSetName = 'Validate')]
param(
    [Parameter(ParameterSetName = 'Validate', Position = 0, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EvidenceDir,

    [Parameter(ParameterSetName = 'Validate', Position = 1)]
    [string]$HandoffPath = "",

    [Parameter(ParameterSetName = 'Validate')]
    [string[]]$Allowlist,

    [Parameter(ParameterSetName = 'Validate')]
    [switch]$RequireTestSummary,

    [Parameter(ParameterSetName = 'SelfTest', Mandatory = $true)]
    [switch]$SelfCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ==============================================================================
# Helper Functions
# ==============================================================================

function Get-TaskIdentifier {
    param($StatusObj)
    if ($null -eq $StatusObj) { return $null }
    foreach ($prop in @('task', 'taskId', 'id')) {
        if ($StatusObj.PSObject.Properties[$prop] -and -not [string]::IsNullOrWhiteSpace([string]$StatusObj.$prop)) {
            return ([string]$StatusObj.$prop).Trim()
        }
    }
    return $null
}

function Normalize-PathStr {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    $norm = $Path.Trim().Replace('\', '/')
    while ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    while ($norm.StartsWith('/')) { $norm = $norm.Substring(1) }
    return $norm.TrimEnd('/')
}

function Extract-DiffFiles {
    param([string]$DiffContent)
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ([string]::IsNullOrWhiteSpace($DiffContent)) { return @() }

    # Standard git diff headers: diff --git a/path b/path
    $gitMatches = [regex]::Matches($DiffContent, '(?m)^diff --git\s+(?:a/)?(\S+)\s+(?:b/)?(\S+)')
    foreach ($m in $gitMatches) {
        $fileA = $m.Groups[1].Value
        $fileB = $m.Groups[2].Value
        $chosen = if ($fileB -match '/dev/null' -or $fileB -eq 'dev/null') { $fileA } else { $fileB }
        $norm = Normalize-PathStr $chosen
        if ($norm -and $norm -ne 'dev/null') {
            [void]$files.Add($norm)
        }
    }

    # Fallback to +++ b/path if no git diff header found
    if (@($files).Count -eq 0) {
        $plusMatches = [regex]::Matches($DiffContent, '(?m)^\+\+\+\s+(?:b/)?(\S+)')
        foreach ($pm in $plusMatches) {
            $raw = $pm.Groups[1].Value
            $norm = Normalize-PathStr $raw
            if ($norm -and $norm -ne 'dev/null') {
                [void]$files.Add($norm)
            }
        }
    }

    return @($files) | Sort-Object
}

function Extract-ChangedFiles {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return @() }
    $lines = Get-Content -LiteralPath $FilePath
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed.ToUpperInvariant() -eq 'NONE') { continue }
        $norm = Normalize-PathStr $trimmed
        if ($norm) { $list.Add($norm) }
    }
    return @($list | Sort-Object -Unique)
}

function Parse-HandoffAllowlist {
    param([string]$HandoffContent)
    $allowed = [System.Collections.Generic.List[string]]::new()
    $forbidden = [System.Collections.Generic.List[string]]::new()

    if ($HandoffContent -match '(?msi)^#{1,6}\s+ALLOWLIST\s*$(.*?)(?=^#{1,6}\s+|\z)') {
        $section = $Matches[1]
        $lines = $section -split "`r?`n"
        $inForbidden = $false

        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if (-not $trimmed) { continue }
            if ($trimmed -match '(?i)^forbidden') {
                $inForbidden = $true
                continue
            }
            if ($trimmed -match '(?i)^allowed') {
                $inForbidden = $false
                continue
            }

            # Match bullet item: - path or * path
            if ($trimmed -match '^[-*]\s+(.*)$') {
                $item = $Matches[1].Trim('`', '"', "'", ' ')
                if ($item.ToUpperInvariant() -eq 'NONE') { continue }
                if ($inForbidden) {
                    $forbidden.Add((Normalize-PathStr $item))
                } else {
                    $allowed.Add((Normalize-PathStr $item))
                }
            }
        }
    }

    return @{
        Allowed = @($allowed);
        Forbidden = @($forbidden)
    }
}

function Test-MatchesAnyPattern {
    param(
        [string]$FilePath,
        [string[]]$Patterns
    )
    $normFile = Normalize-PathStr $FilePath
    foreach ($pattern in $Patterns) {
        $normPattern = Normalize-PathStr $pattern
        if ($normFile -like $normPattern -or $normFile -eq $normPattern) {
            return $true
        }
        # Suffix / directory prefix wildcard matching (e.g. apps/gui matches apps/gui/foo.py)
        if ($normFile.StartsWith($normPattern.TrimEnd('/') + '/')) {
            return $true
        }
    }
    return $false
}

function Extract-IntCount {
    param(
        [string]$Text,
        [string]$Pattern
    )
    $match = [regex]::Match($Text, $Pattern)
    if ($match.Success) {
        return [int]$match.Groups[1].Value
    }
    return $null
}

# ==============================================================================
# Core Validation Function
# ==============================================================================

function Invoke-EvidenceValidation {
    param(
        [string]$TargetDir,
        [string]$TargetHandoff = "",
        [string[]]$ExplicitAllowlist = @(),
        [switch]$MandateTestSummary
    )

    $checkResults = [ordered]@{
        'artifact validation'    = 'PASS'
        'json validation'        = 'PASS'
        'consistency validation' = 'PASS'
        'scope validation'       = 'PASS'
        'test validation'        = 'PASS'
    }

    $details = [ordered]@{
        'artifact validation'    = [System.Collections.Generic.List[string]]::new()
        'json validation'        = [System.Collections.Generic.List[string]]::new()
        'consistency validation' = [System.Collections.Generic.List[string]]::new()
        'scope validation'       = [System.Collections.Generic.List[string]]::new()
        'test validation'        = [System.Collections.Generic.List[string]]::new()
    }

    # --------------------------------------------------------------------------
    # 0. Resolve Paths & Auto-discovery
    # --------------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        $checkResults['artifact validation'] = 'FAIL'
        $details['artifact validation'].Add("Evidence directory does not exist: $TargetDir")
        return @{
            Status = 'FAIL'
            Checks = $checkResults
            Details = $details
        }
    }

    $resolvedEvidenceDir = (Resolve-Path -LiteralPath $TargetDir).Path
    $folderName = Split-Path -Leaf $resolvedEvidenceDir

    # Status.json presence check first for metadata
    $statusJsonPath = Join-Path $resolvedEvidenceDir "status.json"
    $statusObj = $null
    $rawStatusJson = ""

    if (Test-Path -LiteralPath $statusJsonPath -PathType Leaf) {
        $rawStatusJson = Get-Content -LiteralPath $statusJsonPath -Raw
        try {
            $statusObj = ConvertFrom-Json -InputObject $rawStatusJson -ErrorAction Stop
        } catch {
            $statusObj = $null
        }
    }

    # Auto-discover handoff if not provided
    $resolvedHandoffPath = ""
    $handoffValidationRequested = -not [string]::IsNullOrWhiteSpace($TargetHandoff)
    $handoffFileMissing = $false

    if ($handoffValidationRequested) {
        if (Test-Path -LiteralPath $TargetHandoff -PathType Leaf) {
            $resolvedHandoffPath = (Resolve-Path -LiteralPath $TargetHandoff).Path
        } else {
            $handoffFileMissing = $true
            $details['consistency validation'].Add("Specified handoff file not found: $TargetHandoff")
        }
    } else {
        # Candidates based on status.json task id (priority: task, taskId, id) or folder name
        $taskCandidates = @()
        $discoveredTaskId = Get-TaskIdentifier -StatusObj $statusObj
        if ($discoveredTaskId) { $taskCandidates += $discoveredTaskId }
        if ($folderName -match '^TASK-') { $taskCandidates += $folderName }

        $searchRoots = @(
            (Join-Path $resolvedEvidenceDir ".."),
            (Join-Path $resolvedEvidenceDir "..\.."),
            (Join-Path $resolvedEvidenceDir "..\..\active"),
            (Join-Path $resolvedEvidenceDir "..\..\completed"),
            (Join-Path $resolvedEvidenceDir "..\active"),
            (Join-Path $resolvedEvidenceDir "..\completed")
        )

        foreach ($candidate in ($taskCandidates | Select-Object -Unique)) {
            $fileName = "$candidate.md"
            foreach ($root in $searchRoots) {
                $candPath = Join-Path $root $fileName
                if (Test-Path -LiteralPath $candPath -PathType Leaf) {
                    $resolvedHandoffPath = (Resolve-Path -LiteralPath $candPath).Path
                    break
                }
            }
            if ($resolvedHandoffPath) { break }
        }
    }

    $handoffContent = ""
    if ($resolvedHandoffPath) {
        $handoffContent = Get-Content -LiteralPath $resolvedHandoffPath -Raw
    }

    # Determine if task TEST requirement is NONE
    $testRequirementNone = $false
    if ($handoffContent) {
        if ($handoffContent -match '(?mi)^TEST\s*:\s*[`"'']?NONE\b') {
            $testRequirementNone = $true
        } elseif ($handoffContent -match '(?msi)^#{1,6}\s+TEST\s*$(.*?)(?=^#{1,6}\s+|\z)') {
            $testSec = $Matches[1].Trim()
            if ($testSec -match '(?i)^\s*NONE\b' -or
                $testSec -match '(?i)^[-*]\s*NONE\b' -or
                $testSec -match '(?i)\bCheck\b\*{0,2}\s*:\s*[`"'']?NONE\b') {
                $testRequirementNone = $true
            }
        }
    }

    # Determine if tests are required
    $testsRequired = $false
    if ($MandateTestSummary) {
        $testsRequired = $true
    } elseif ($testRequirementNone) {
        $testsRequired = $false
    } elseif ($statusObj -and $statusObj.PSObject.Properties['tests'] -and $statusObj.tests.PSObject.Properties['total'] -and [int]$statusObj.tests.total -gt 0) {
        $testsRequired = $true
    } elseif ($handoffContent -and $handoffContent -match '(?msi)^#{1,6}\s+TEST\s*$(.*?)(?=^#{1,6}\s+|\z)') {
        $testSec = $Matches[1].Trim()
        if ($testSec -and $testSec -notmatch '(?i)\bNONE\b|<focused command>') {
            $testsRequired = $true
        }
    }

    # --------------------------------------------------------------------------
    # Check 1: Artifact Validation
    # --------------------------------------------------------------------------
    $standardArtifacts = @('status.json', 'result.md', 'changed-files.txt', 'diff.patch')
    $missingArtifacts = [System.Collections.Generic.List[string]]::new()
    $incompleteArtifacts = [System.Collections.Generic.List[string]]::new()
    $templatePlaceholderPattern = '<\s*(?:objective|target|explicit paths|risk level|pass condition|focused command|verified paths|test output|remaining risk|stable-task-id|ISO-8601|TODO|TBD)\b[^>]*>'

    foreach ($art in $standardArtifacts) {
        $artPath = Join-Path $resolvedEvidenceDir $art
        if (-not (Test-Path -LiteralPath $artPath -PathType Leaf)) {
            $missingArtifacts.Add($art)
        } else {
            $content = Get-Content -LiteralPath $artPath -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                if ($art -eq 'diff.patch') {
                    # Empty diff is only valid if changed-files.txt is also empty / NONE
                    $cfPath = Join-Path $resolvedEvidenceDir 'changed-files.txt'
                    $cfFiles = @(Extract-ChangedFiles $cfPath)
                    if (@($cfFiles).Count -gt 0) {
                        $incompleteArtifacts.Add("$art (empty diff with non-empty changed-files.txt)")
                    }
                } else {
                    $incompleteArtifacts.Add("$art (empty file)")
                }
            } elseif ($art -ne 'diff.patch' -and $content -match $templatePlaceholderPattern) {
                $incompleteArtifacts.Add("$art (contains unresolved template placeholders)")
            }
        }
    }

    # Conditional artifact: test-output-summary.md (only required when tests are enabled)
    $testSummaryPath = Join-Path $resolvedEvidenceDir "test-output-summary.md"
    $hasTestSummary = Test-Path -LiteralPath $testSummaryPath -PathType Leaf
    if ($testsRequired) {
        if (-not $hasTestSummary) {
            $missingArtifacts.Add("test-output-summary.md (required by handoff/status.json)")
        } else {
            $summaryText = Get-Content -LiteralPath $testSummaryPath -Raw
            if ([string]::IsNullOrWhiteSpace($summaryText)) {
                $incompleteArtifacts.Add("test-output-summary.md (empty file)")
            } elseif ($summaryText -match $templatePlaceholderPattern) {
                $incompleteArtifacts.Add("test-output-summary.md (contains unresolved template placeholders)")
            }
        }
    }

    if (@($missingArtifacts).Count -gt 0) {
        $checkResults['artifact validation'] = 'FAIL'
        $details['artifact validation'].Add("Missing required artifact(s): $(@($missingArtifacts) -join ', ')")
    } elseif (@($incompleteArtifacts).Count -gt 0) {
        $checkResults['artifact validation'] = 'UNVERIFIED'
        $details['artifact validation'].Add("Incomplete artifact(s): $(@($incompleteArtifacts) -join '; ')")
    } else {
        $countDesc = if ($hasTestSummary -and $testsRequired) { "5/5 artifacts verified" } else { "4/4 standard artifacts verified (no test summary required)" }
        $details['artifact validation'].Add("All required artifacts present and non-empty ($countDesc)")
    }

    # --------------------------------------------------------------------------
    # Check 2: JSON Validation
    # --------------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $statusJsonPath -PathType Leaf)) {
        $checkResults['json validation'] = 'FAIL'
        $details['json validation'].Add("status.json is missing")
    } elseif ($null -eq $statusObj) {
        $checkResults['json validation'] = 'FAIL'
        $details['json validation'].Add("status.json is not valid JSON syntax")
    } else {
        $missingProps = [System.Collections.Generic.List[string]]::new()
        $hasValidationStatus = ($statusObj.PSObject.Properties['validation'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.validation)) -or
                               ($statusObj.PSObject.Properties['status'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.status))
        if (-not $hasValidationStatus) {
            $missingProps.Add('status')
        }

        # Check for task identifier (priority: task, taskId, id; if none exists: FAIL)
        $statusTaskId = Get-TaskIdentifier -StatusObj $statusObj
        if (-not $statusTaskId) {
            $missingProps.Add('task')
        }

        if (@($missingProps).Count -gt 0) {
            $checkResults['json validation'] = 'FAIL'
            $details['json validation'].Add("status.json missing required property: $(@($missingProps) -join ', ')")
        } else {
            $details['json validation'].Add("status.json is valid JSON with required properties")
        }
    }

    # --------------------------------------------------------------------------
    # Check 3: Consistency Validation
    # --------------------------------------------------------------------------
    $consistencyFailures = [System.Collections.Generic.List[string]]::new()
    $extractedEvidenceTaskId = Get-TaskIdentifier -StatusObj $statusObj
    if ($statusObj -and -not $extractedEvidenceTaskId) {
        $consistencyFailures.Add("Task identifier missing in status.json (checked 'task', 'taskId', 'id')")
    }

    $extractedHandoffTaskId = ""
    if ($handoffContent) {
        if ($handoffContent -match '(?mi)^id\s*:\s*([^\r\n]+)') {
            $extractedHandoffTaskId = $Matches[1].Trim()
        } elseif ($handoffContent -match '(?mi)-\s*\*\*ID\*\*\s*:\s*[`"'']?([^`"''\r\n]+)') {
            $extractedHandoffTaskId = $Matches[1].Trim()
        }
    }

    # Handoff validation requirement: if handoff validation was requested and handoff is missing, fail task ID validation
    if ($handoffFileMissing) {
        $consistencyFailures.Add("Specified handoff file does not exist: $TargetHandoff")
        $consistencyFailures.Add("Task ID validation failed: handoff file missing")
    } else {
        # Task ID matching
        if ($extractedEvidenceTaskId -and $extractedHandoffTaskId) {
            if ($extractedEvidenceTaskId -ne $extractedHandoffTaskId) {
                $consistencyFailures.Add("Task ID mismatch: handoff='$extractedHandoffTaskId' vs status.json='$extractedEvidenceTaskId'")
            }
        }
    }

    if ($extractedEvidenceTaskId -and $folderName -match '^TASK-' -and $folderName -ne $extractedEvidenceTaskId) {
        $consistencyFailures.Add("Task ID mismatch: folder='$folderName' vs status.json='$extractedEvidenceTaskId'")
    }

    # Explicit validation result in status.json: allowed values only PASS, FAIL, BLOCKED, UNVERIFIED
    $evidenceStatus = ""
    if ($statusObj) {
        if ($statusObj.PSObject.Properties['validation'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.validation)) {
            $evidenceStatus = [string]$statusObj.validation
        } elseif ($statusObj.PSObject.Properties['status'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.status)) {
            $evidenceStatus = [string]$statusObj.status
        }
    }
    $allowedStatuses = @('PASS', 'FAIL', 'BLOCKED', 'UNVERIFIED')

    if ([string]::IsNullOrWhiteSpace($evidenceStatus)) {
        $consistencyFailures.Add("Validation result status is missing in status.json")
    } elseif ($evidenceStatus.ToUpperInvariant() -notin $allowedStatuses) {
        $consistencyFailures.Add("Invalid validation status '$evidenceStatus' in status.json. Allowed values only: PASS, FAIL, BLOCKED, UNVERIFIED")
    }

    # Result.md corroboration
    $resultMdPath = Join-Path $resolvedEvidenceDir "result.md"
    if (Test-Path -LiteralPath $resultMdPath -PathType Leaf) {
        $resultText = Get-Content -LiteralPath $resultMdPath -Raw
        if ($extractedEvidenceTaskId -and $resultText -notmatch [regex]::Escape($extractedEvidenceTaskId)) {
            $consistencyFailures.Add("result.md does not reference task ID '$extractedEvidenceTaskId'")
        }
    }

    if (@($consistencyFailures).Count -gt 0) {
        $checkResults['consistency validation'] = 'FAIL'
        $details['consistency validation'].Add((@($consistencyFailures) -join '; '))
    } else {
        $normStat = $evidenceStatus.ToUpperInvariant()
        if ($normStat -eq 'BLOCKED' -or ($statusObj -and $statusObj.PSObject.Properties['blocked'] -and $statusObj.blocked -eq $true)) {
            $checkResults['consistency validation'] = 'BLOCKED'
            $details['consistency validation'].Add("Task is explicitly flagged as BLOCKED")
        } elseif ($normStat -eq 'UNVERIFIED') {
            $checkResults['consistency validation'] = 'UNVERIFIED'
            $details['consistency validation'].Add("Task status is explicitly UNVERIFIED")
        } elseif ($normStat -eq 'FAIL') {
            $checkResults['consistency validation'] = 'FAIL'
            $details['consistency validation'].Add("Task status is explicitly FAIL in evidence")
        } else {
            $details['consistency validation'].Add("Task ID '$extractedEvidenceTaskId' matches; validation status '$evidenceStatus' is explicit")
        }
    }

    # --------------------------------------------------------------------------
    # Check 4: Scope Validation
    # --------------------------------------------------------------------------
    $diffPath = Join-Path $resolvedEvidenceDir "diff.patch"
    $changedFilesPath = Join-Path $resolvedEvidenceDir "changed-files.txt"
    $diffFiles = @()
    $declaredFiles = @()

    if (Test-Path -LiteralPath $diffPath -PathType Leaf) {
        $diffContent = Get-Content -LiteralPath $diffPath -Raw
        $diffFiles = @(Extract-DiffFiles $diffContent)
    }
    if (Test-Path -LiteralPath $changedFilesPath -PathType Leaf) {
        $declaredFiles = @(Extract-ChangedFiles $changedFilesPath)
    }

    $scopeFailures = [System.Collections.Generic.List[string]]::new()

    # Compare changed-files.txt vs diff.patch (do not skip when handoff is missing)
    $inDiffNotDeclared = @(@($diffFiles) | Where-Object { $_ -notin @($declaredFiles) })
    $inDeclaredNotInDiff = @(@($declaredFiles) | Where-Object { $_ -notin @($diffFiles) })

    if (@($inDiffNotDeclared).Count -gt 0) {
        $scopeFailures.Add("diff.patch modifies file(s) not in changed-files.txt: $(@($inDiffNotDeclared) -join ', ')")
    }
    if (@($inDeclaredNotInDiff).Count -gt 0) {
        $scopeFailures.Add("changed-files.txt lists file(s) not in diff.patch: $(@($inDeclaredNotInDiff) -join ', ')")
    }

    # ALLOWLIST checking (do not skip: check explicit or handoff allowlist, fail if requested handoff missing)
    $allowedPatterns = [System.Collections.Generic.List[string]]::new()
    $forbiddenPatterns = [System.Collections.Generic.List[string]]::new()

    $normExplicitAllowlist = if ($ExplicitAllowlist) { @($ExplicitAllowlist) } else { @() }
    if (@($normExplicitAllowlist).Count -gt 0) {
        foreach ($item in $normExplicitAllowlist) {
            $allowedPatterns.Add((Normalize-PathStr $item))
        }
    } elseif ($handoffContent) {
        $parsedHandoffAllow = Parse-HandoffAllowlist $handoffContent
        foreach ($a in @($parsedHandoffAllow.Allowed)) { $allowedPatterns.Add($a) }
        foreach ($f in @($parsedHandoffAllow.Forbidden)) { $forbiddenPatterns.Add($f) }
    } elseif ($handoffFileMissing) {
        $scopeFailures.Add("ALLOWLIST validation failed: handoff file missing and no explicit allowlist provided")
    }

    if (@($allowedPatterns).Count -gt 0 -or @($forbiddenPatterns).Count -gt 0) {
        $outsideAllowlist = [System.Collections.Generic.List[string]]::new()
        $insideForbidden = [System.Collections.Generic.List[string]]::new()

        foreach ($file in @($declaredFiles)) {
            if (@($allowedPatterns).Count -gt 0) {
                if (-not (Test-MatchesAnyPattern -FilePath $file -Patterns $allowedPatterns.ToArray())) {
                    $outsideAllowlist.Add($file)
                }
            }
            if (@($forbiddenPatterns).Count -gt 0) {
                if (Test-MatchesAnyPattern -FilePath $file -Patterns $forbiddenPatterns.ToArray()) {
                    $insideForbidden.Add($file)
                }
            }
        }

        if (@($outsideAllowlist).Count -gt 0) {
            $scopeFailures.Add("File(s) outside ALLOWLIST: $(@($outsideAllowlist) -join ', ')")
        }
        if (@($insideForbidden).Count -gt 0) {
            $scopeFailures.Add("File(s) match forbidden scope: $(@($insideForbidden) -join ', ')")
        }
    }

    if (@($scopeFailures).Count -gt 0) {
        $checkResults['scope validation'] = 'FAIL'
        $details['scope validation'].Add((@($scopeFailures) -join '; '))
    } else {
        $details['scope validation'].Add("changed-files.txt matches diff.patch ($(@($declaredFiles).Count) file(s)) and respects ALLOWLIST")
    }

    # --------------------------------------------------------------------------
    # Check 5: Test Validation
    # --------------------------------------------------------------------------
    $testFailures = [System.Collections.Generic.List[string]]::new()
    $testStatusVal = 'PASS'

    if ($testsRequired) {
        if (-not $hasTestSummary) {
            $testFailures.Add("Tests required but test-output-summary.md is missing")
        } else {
            $summaryText = Get-Content -LiteralPath $testSummaryPath -Raw

            # Extract counts from summary markdown
            $summaryTotal   = Extract-IntCount $summaryText '(?mi)\bTotal(?:\s+Test\s+Count|\s+Tests?)?\b\*{0,2}\s*[:=]\s*(\d+)'
            $summaryPassed  = Extract-IntCount $summaryText '(?mi)\bPassed\b\*{0,2}\s*[:=]\s*(\d+)'
            $summaryFailed  = Extract-IntCount $summaryText '(?mi)\bFailed\b\*{0,2}\s*[:=]\s*(\d+)'
            $summaryErrors  = Extract-IntCount $summaryText '(?mi)\bErrors?\b\*{0,2}\s*[:=]\s*(\d+)'
            $summarySkipped = Extract-IntCount $summaryText '(?mi)\bSkipped\b\*{0,2}\s*[:=]\s*(\d+)'

            if ($null -eq $summaryTotal -and $summaryText -match '(?mi)(\d+)\s+total(?:\s+tests?)?\b') {
                $summaryTotal = [int]$Matches[1]
            }
            if ($null -eq $summaryPassed -and $summaryText -match '(?mi)(\d+)\s+passed\b') {
                $summaryPassed = [int]$Matches[1]
            }
            if ($null -eq $summaryFailed -and $summaryText -match '(?mi)(\d+)\s+failed\b') {
                $summaryFailed = [int]$Matches[1]
            }

            # Enforce numeric counts for Total, Passed, Failed
            $missingNumericCounts = [System.Collections.Generic.List[string]]::new()
            if ($null -eq $summaryTotal) { $missingNumericCounts.Add('Total') }
            if ($null -eq $summaryPassed) { $missingNumericCounts.Add('Passed') }
            if ($null -eq $summaryFailed) { $missingNumericCounts.Add('Failed') }

            if (@($missingNumericCounts).Count -gt 0) {
                $testFailures.Add("Test summary missing required numeric count(s): $(@($missingNumericCounts) -join ', ') (must specify numeric Total, Passed, Failed)")
            } else {
                # Check internal mathematical consistency in test summary
                $p = $summaryPassed
                $f = $summaryFailed
                $e = if ($null -ne $summaryErrors) { $summaryErrors } else { 0 }
                $s = if ($null -ne $summarySkipped) { $summarySkipped } else { 0 }
                $sum = $p + $f + $e + $s

                if ($sum -ne $summaryTotal) {
                    $testFailures.Add("Test summary count mismatch: Total ($summaryTotal) != Passed ($p) + Failed ($f) + Errors ($e) + Skipped ($s) = $sum")
                }

                # Compare with status.json if test object is present
                if ($statusObj -and $statusObj.PSObject.Properties['tests']) {
                    $jsonTests = $statusObj.tests
                    $jTotal  = if ($jsonTests.PSObject.Properties['total']) { [int]$jsonTests.total } else { $null }
                    $jPassed = if ($jsonTests.PSObject.Properties['passed']) { [int]$jsonTests.passed } else { $null }
                    $jFailed = if ($jsonTests.PSObject.Properties['failed']) { [int]$jsonTests.failed } else { $null }

                    if ($null -ne $jTotal -and $jTotal -ne $summaryTotal) {
                        $testFailures.Add("status.json total ($jTotal) != test summary total ($summaryTotal)")
                    }
                    if ($null -ne $jPassed -and $jPassed -ne $summaryPassed) {
                        $testFailures.Add("status.json passed ($jPassed) != test summary passed ($summaryPassed)")
                    }
                    if ($null -ne $jFailed -and $jFailed -ne $summaryFailed) {
                        $testFailures.Add("status.json failed ($jFailed) != test summary failed ($summaryFailed)")
                    }

                    # status.json internal consistency
                    if ($null -ne $jTotal -and $null -ne $jPassed -and $null -ne $jFailed) {
                        if (($jPassed + $jFailed) -gt $jTotal) {
                            $testFailures.Add("status.json passed ($jPassed) + failed ($jFailed) exceeds total ($jTotal)")
                        }
                    }
                }

                # Check failure waiver policy
                if ($summaryFailed -gt 0) {
                    $hasWaiver = $false
                    if ($statusObj -and $statusObj.PSObject.Properties['waiver']) {
                        $w = $statusObj.waiver
                        if ($w.PSObject.Properties['status'] -and [string]$w.status -eq 'WAIVED') {
                            $hasWaiver = $true
                        }
                    }
                    if ($summaryText -match '(?mi)##\s*Failure Waiver.*?\bStatus\b\*{0,2}\s*:\s*WAIVED') {
                        $hasWaiver = $true
                    }

                    if (-not $hasWaiver) {
                        $testFailures.Add("$summaryFailed failed test(s) without approved WAIVED record")
                    }
                }
            }

            # Check for unverified state
            if ($summaryText -match '(?mi)\bStatus\b\*{0,2}\s*:\s*\*{0,2}UNVERIFIED\b') {
                $testStatusVal = 'UNVERIFIED'
            }
        }
    } else {
        $details['test validation'].Add("No test execution required for current scope")
    }

    if (@($testFailures).Count -gt 0) {
        $checkResults['test validation'] = 'FAIL'
        $details['test validation'].Add((@($testFailures) -join '; '))
    } elseif ($testStatusVal -eq 'UNVERIFIED') {
        $checkResults['test validation'] = 'UNVERIFIED'
        $details['test validation'].Add("Test suite verification status is marked UNVERIFIED")
    } elseif ($testsRequired -and $hasTestSummary) {
        $details['test validation'].Add("Test summary totals internally consistent and reconciled with status.json")
    } else {
        $details['test validation'].Add("No test execution required for current scope")
    }

    # --------------------------------------------------------------------------
    # Overall Status Calculation
    # --------------------------------------------------------------------------
    $allVals = @($checkResults.Values)

    if ($allVals -contains 'FAIL') {
        $finalStatus = 'FAIL'
    } elseif ($allVals -contains 'BLOCKED') {
        $finalStatus = 'BLOCKED'
    } elseif ($allVals -contains 'UNVERIFIED') {
        $finalStatus = 'UNVERIFIED'
    } else {
        $finalStatus = 'PASS'
    }

    # Enforce allowed statuses: PASS, FAIL, BLOCKED, UNVERIFIED. Any other value: FAIL.
    if ($finalStatus -notin $allowedStatuses) {
        $finalStatus = 'FAIL'
    }

    return @{
        Status  = $finalStatus
        Checks  = $checkResults
        Details = $details
    }
}

# ==============================================================================
# Isolated Self-Check Suite (-SelfCheck)
# ==============================================================================

function Invoke-SelfCheckSuite {
    Write-Host "================================================================="
    Write-Host "  Running Evidence Validator Self-Check Suite (Phase 2.3)        "
    Write-Host "=================================================================`n"

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("evidence-test-" + [System.Guid]::NewGuid().ToString("N"))
    [void](New-Item -ItemType Directory -Path $tempRoot)

    $testPasses = [System.Collections.Generic.List[string]]::new()
    $testFails = [System.Collections.Generic.List[string]]::new()

    function Assert-Test {
        param(
            [string]$Name,
            [string]$ExpectedStatus,
            [hashtable]$ValidationResult
        )
        $actStatus = $ValidationResult.Status
        if ($actStatus -eq $ExpectedStatus) {
            Write-Host "[PASS] $Name -> Expected: $ExpectedStatus, Got: $actStatus" -ForegroundColor Green
            $testPasses.Add($Name)
        } else {
            Write-Host "[FAIL] $Name -> Expected: $ExpectedStatus, Got: $actStatus" -ForegroundColor Red
            Write-Host "       Checks: $($ValidationResult.Checks | Out-String)" -ForegroundColor DarkRed
            Write-Host "       Details: $($ValidationResult.Details | Out-String)" -ForegroundColor DarkYellow
            $testFails.Add($Name)
        }
    }

    try {
        # 1. Valid Evidence Case
        $case1Dir = Join-Path $tempRoot "case1-valid"
        [void](New-Item -ItemType Directory -Path $case1Dir)
        Set-Content -LiteralPath (Join-Path $case1Dir "status.json") -Value @'
{
  "task": "TASK-100",
  "status": "PASS",
  "tests": {
    "total": 10,
    "passed": 10,
    "failed": 0
  }
}
'@
        Set-Content -LiteralPath (Join-Path $case1Dir "result.md") -Value @'
# Task Execution Result: TASK-100
Status: PASS
All criteria satisfied.
'@
        Set-Content -LiteralPath (Join-Path $case1Dir "changed-files.txt") -Value "src/app.py`nsrc/utils.py"
        Set-Content -LiteralPath (Join-Path $case1Dir "diff.patch") -Value @'
diff --git a/src/app.py b/src/app.py
--- a/src/app.py
+++ b/src/app.py
@@ -1 +1 @@
-old
+new
diff --git a/src/utils.py b/src/utils.py
--- a/src/utils.py
+++ b/src/utils.py
@@ -1 +1 @@
-old
+new
'@
        Set-Content -LiteralPath (Join-Path $case1Dir "test-output-summary.md") -Value @'
# Test Summary
- **Total Test Count**: 10
- **Passed**: 10
- **Failed**: 0
- **Status**: PASS
'@
        $h1Path = Join-Path $tempRoot "TASK-100.md"
        Set-Content -LiteralPath $h1Path -Value @'
# Task Handoff
## META
id: TASK-100
STATE: COMPLETED
## ALLOWLIST
Allowed files:
- src/app.py
- src/utils.py
## TEST
- Check: run tests
## EVIDENCE
- status.json
- test-output-summary.md
'@
        $res1 = Invoke-EvidenceValidation -TargetDir $case1Dir -TargetHandoff $h1Path
        Assert-Test "Case 1: Valid evidence folder" "PASS" $res1

        # 2. Missing Artifact Case (diff.patch missing)
        $case2Dir = Join-Path $tempRoot "case2-missing-artifact"
        [void](New-Item -ItemType Directory -Path $case2Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case2Dir
        Remove-Item -LiteralPath (Join-Path $case2Dir "diff.patch") -Force
        $res2 = Invoke-EvidenceValidation -TargetDir $case2Dir -TargetHandoff $h1Path
        Assert-Test "Case 2: Missing artifact (diff.patch missing)" "FAIL" $res2

        # 3. Incomplete Evidence - Blocked
        $case3Dir = Join-Path $tempRoot "case3-blocked"
        [void](New-Item -ItemType Directory -Path $case3Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case3Dir
        Set-Content -LiteralPath (Join-Path $case3Dir "status.json") -Value @'
{
  "task": "TASK-100",
  "status": "BLOCKED"
}
'@
        $res3 = Invoke-EvidenceValidation -TargetDir $case3Dir -TargetHandoff $h1Path
        Assert-Test "Case 3: Incomplete evidence (BLOCKED status)" "BLOCKED" $res3

        # 4. Incomplete Evidence - Unverified
        $case4Dir = Join-Path $tempRoot "case4-unverified"
        [void](New-Item -ItemType Directory -Path $case4Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case4Dir
        Set-Content -LiteralPath (Join-Path $case4Dir "status.json") -Value @'
{
  "task": "TASK-100",
  "status": "UNVERIFIED"
}
'@
        $res4 = Invoke-EvidenceValidation -TargetDir $case4Dir -TargetHandoff $h1Path
        Assert-Test "Case 4: Incomplete evidence (UNVERIFIED status)" "UNVERIFIED" $res4

        # 5. Inconsistent Test Totals
        $case5Dir = Join-Path $tempRoot "case5-bad-tests"
        [void](New-Item -ItemType Directory -Path $case5Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case5Dir
        Set-Content -LiteralPath (Join-Path $case5Dir "test-output-summary.md") -Value @'
# Test Summary
- **Total Test Count**: 10
- **Passed**: 8
- **Failed**: 0
- **Status**: PASS
'@
        $res5 = Invoke-EvidenceValidation -TargetDir $case5Dir -TargetHandoff $h1Path
        Assert-Test "Case 5: Inconsistent test totals (10 != 8 + 0)" "FAIL" $res5

        # 6. Scope Mismatch (changed-files.txt does not match diff.patch)
        $case6Dir = Join-Path $tempRoot "case6-scope-mismatch"
        [void](New-Item -ItemType Directory -Path $case6Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case6Dir
        Set-Content -LiteralPath (Join-Path $case6Dir "changed-files.txt") -Value "src/app.py`nsrc/untracked.py"
        $res6 = Invoke-EvidenceValidation -TargetDir $case6Dir -TargetHandoff $h1Path
        Assert-Test "Case 6: Scope mismatch between changed files and diff" "FAIL" $res6

        # 7. Allowlist Violation
        $case7Dir = Join-Path $tempRoot "case7-allowlist-violation"
        [void](New-Item -ItemType Directory -Path $case7Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case7Dir
        Set-Content -LiteralPath (Join-Path $case7Dir "changed-files.txt") -Value "src/app.py`nsecret.key"
        Set-Content -LiteralPath (Join-Path $case7Dir "diff.patch") -Value @'
diff --git a/src/app.py b/src/app.py
--- a/src/app.py
+++ b/src/app.py
@@ -1 +1 @@
-old
+new
diff --git a/secret.key b/secret.key
--- a/secret.key
+++ b/secret.key
@@ -1 +1 @@
-old
+new
'@
        $res7 = Invoke-EvidenceValidation -TargetDir $case7Dir -TargetHandoff $h1Path
        Assert-Test "Case 7: Allowlist violation" "FAIL" $res7

        # 8. Corrupted JSON Syntax
        $case8Dir = Join-Path $tempRoot "case8-bad-json"
        [void](New-Item -ItemType Directory -Path $case8Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case8Dir
        Set-Content -LiteralPath (Join-Path $case8Dir "status.json") -Value "{ broken json"
        $res8 = Invoke-EvidenceValidation -TargetDir $case8Dir -TargetHandoff $h1Path
        Assert-Test "Case 8: Invalid JSON in status.json" "FAIL" $res8

        # 9. Missing Handoff When Requested
        $nonExistentHandoff = Join-Path $tempRoot "nonexistent-handoff.md"
        $res9 = Invoke-EvidenceValidation -TargetDir $case1Dir -TargetHandoff $nonExistentHandoff
        Assert-Test "Case 9: Missing handoff file when requested" "FAIL" $res9

        # 10. Invalid Validation Status in status.json
        $case10Dir = Join-Path $tempRoot "case10-invalid-status"
        [void](New-Item -ItemType Directory -Path $case10Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case10Dir
        Set-Content -LiteralPath (Join-Path $case10Dir "status.json") -Value @'
{
  "task": "TASK-100",
  "status": "UNKNOWN_STATUS"
}
'@
        $res10 = Invoke-EvidenceValidation -TargetDir $case10Dir -TargetHandoff $h1Path
        Assert-Test "Case 10: Invalid validation status in status.json" "FAIL" $res10

        # 11. Task TEST requirement is NONE
        $case11Dir = Join-Path $tempRoot "case11-test-none"
        [void](New-Item -ItemType Directory -Path $case11Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case11Dir
        Remove-Item -LiteralPath (Join-Path $case11Dir "test-output-summary.md") -Force
        $h11Path = Join-Path $tempRoot "TASK-110.md"
        Set-Content -LiteralPath (Join-Path $case11Dir "status.json") -Value @'
{
  "task": "TASK-110",
  "status": "PASS"
}
'@
        Set-Content -LiteralPath (Join-Path $case11Dir "result.md") -Value @'
# Task Execution Result: TASK-110
Status: PASS
'@
        Set-Content -LiteralPath $h11Path -Value @'
# Task Handoff
## META
id: TASK-110
STATE: COMPLETED
## ALLOWLIST
Allowed files:
- src/app.py
- src/utils.py
## TEST
NONE
## EVIDENCE
<!-- Validated with scripts/evidence-check.ps1: status.json, result.md, changed-files.txt, diff.patch, test-output-summary.md (when tests required). -->
- status.json
- result.md
'@
        $res11 = Invoke-EvidenceValidation -TargetDir $case11Dir -TargetHandoff $h11Path
        Assert-Test "Case 11: Task TEST requirement is NONE" "PASS" $res11

        # 12. Test Summary Missing Numeric Counts
        $case12Dir = Join-Path $tempRoot "case12-no-numeric-counts"
        [void](New-Item -ItemType Directory -Path $case12Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case12Dir
        Set-Content -LiteralPath (Join-Path $case12Dir "test-output-summary.md") -Value @'
# Test Summary
All tests executed and verified successfully. No numbers here.
'@
        $res12 = Invoke-EvidenceValidation -TargetDir $case12Dir -TargetHandoff $h1Path
        Assert-Test "Case 12: Test summary missing numeric counts" "FAIL" $res12

        # 13. Auto-discovery using taskId
        $case13Dir = Join-Path $tempRoot "case13-taskId"
        [void](New-Item -ItemType Directory -Path $case13Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case13Dir
        Set-Content -LiteralPath (Join-Path $case13Dir "status.json") -Value @'
{
  "taskId": "TASK-100",
  "status": "PASS",
  "tests": {
    "total": 10,
    "passed": 10,
    "failed": 0
  }
}
'@
        $res13 = Invoke-EvidenceValidation -TargetDir $case13Dir
        Assert-Test "Case 13: Auto-discovery using taskId" "PASS" $res13

        # 14. Auto-discovery using id
        $case14Dir = Join-Path $tempRoot "case14-id"
        [void](New-Item -ItemType Directory -Path $case14Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case14Dir
        Set-Content -LiteralPath (Join-Path $case14Dir "status.json") -Value @'
{
  "id": "TASK-100",
  "status": "PASS",
  "tests": {
    "total": 10,
    "passed": 10,
    "failed": 0
  }
}
'@
        $res14 = Invoke-EvidenceValidation -TargetDir $case14Dir
        Assert-Test "Case 14: Auto-discovery using id" "PASS" $res14

        # 15. Missing task identifier (neither task, taskId, nor id)
        $case15Dir = Join-Path $tempRoot "case15-no-task-id"
        [void](New-Item -ItemType Directory -Path $case15Dir)
        Copy-Item -Path (Join-Path $case1Dir "*") -Destination $case15Dir
        Set-Content -LiteralPath (Join-Path $case15Dir "status.json") -Value @'
{
  "status": "PASS",
  "tests": {
    "total": 10,
    "passed": 10,
    "failed": 0
  }
}
'@
        $res15 = Invoke-EvidenceValidation -TargetDir $case15Dir
        Assert-Test "Case 15: Missing task identifier fails" "FAIL" $res15

    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "`nSelf-Check Summary: $(@($testPasses).Count) passed, $(@($testFails).Count) failed.`n"
    if (@($testFails).Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# ==============================================================================
# Main Execution Dispatch
# ==============================================================================

if ($SelfCheck) {
    Invoke-SelfCheckSuite
}

$validation = Invoke-EvidenceValidation `
    -TargetDir $EvidenceDir `
    -TargetHandoff $HandoffPath `
    -ExplicitAllowlist $Allowlist `
    -MandateTestSummary:$RequireTestSummary

# Output Deterministic Result Contract
Write-Output "STATUS:"
Write-Output $validation.Status
Write-Output ""
Write-Output "CHECKS:"
foreach ($key in $validation.Checks.Keys) {
    Write-Output "- $($key): $($validation.Checks[$key])"
}
Write-Output ""
Write-Output "DETAILS:"
foreach ($key in $validation.Details.Keys) {
    $items = @($validation.Details[$key])
    if (@($items).Count -gt 0) {
        foreach ($it in $items) {
            Write-Output "- $($key): $it"
        }
    }
}

# Exit code: 0 for PASS, 1 for non-PASS (FAIL, BLOCKED, UNVERIFIED)
if ($validation.Status -eq 'PASS') {
    exit 0
} else {
    exit 1
}

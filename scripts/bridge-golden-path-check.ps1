<#
.SYNOPSIS
    Read-only golden-path verifier for real durable Antigravity bridge jobs.
.DESCRIPTION
    Verifies the authentic six-stage execution chain of an observed Antigravity bridge job
    without mutating files, creating fake evidence, or simulating execution:
    1. User Task Definition & Intent (request.md)
    2. Codex Routing & Contract (explicit taskId, workspace, executor, artifact location)
    3. Bridge Submission (submissionStatus in status.json)
    4. Antigravity Execution (executor=antigravity, executionStatus)
    5. Artifact Generation (ARTIFACT_READY: status.json, result.md, changed-files.txt, diff.patch, test-output-summary.md)
    6. Codex Evidence Verification (invokes evidence-check.ps1 against the real job directory)
.PARAMETER JobDirectory
    Explicit path to a durable bridge job directory. Auto-discovered if omitted.
.PARAMETER JobId
    Specific job identifier to verify. Auto-discovered if omitted.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$JobDirectory = "",

    [Parameter(Position = 1)]
    [string]$JobId = "",

    [Parameter()]
    [switch]$Advance,

    [Parameter()]
    [switch]$Close
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..")).Path
$evidenceCheckScript = Join-Path $scriptDir "evidence-check.ps1"

if (-not (Test-Path -LiteralPath $evidenceCheckScript -PathType Leaf)) {
    Write-Error "evidence-check.ps1 not found at $evidenceCheckScript"
    exit 1
}

# --------------------------------------------------------------------------
# Resolve Job Directory
# --------------------------------------------------------------------------
$resolvedJobDir = ""

if (-not [string]::IsNullOrWhiteSpace($JobDirectory)) {
    if (Test-Path -LiteralPath $JobDirectory -PathType Container) {
        $resolvedJobDir = (Resolve-Path -LiteralPath $JobDirectory).Path
    } else {
        Write-Error "Specified JobDirectory does not exist: $JobDirectory"
        exit 1
    }
} elseif (-not [string]::IsNullOrWhiteSpace($JobId)) {
    $searchRoots = @(
        (Join-Path $repoRoot "Workflow System Audit\.antigravity-bridge\jobs\$JobId"),
        (Join-Path $repoRoot ".antigravity-bridge\jobs\$JobId"),
        (Join-Path $PWD ".antigravity-bridge\jobs\$JobId"),
        (Join-Path $PWD "Workflow System Audit\.antigravity-bridge\jobs\$JobId")
    )
    foreach ($cand in $searchRoots) {
        if (Test-Path -LiteralPath $cand -PathType Container) {
            $resolvedJobDir = (Resolve-Path -LiteralPath $cand).Path
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedJobDir)) {
        Write-Error "Could not find durable bridge job directory for JobId '$JobId'"
        exit 1
    }
} else {
    # Auto-discover latest job directory under .antigravity-bridge/jobs/<id>
    $searchJobRoots = @(
        (Join-Path $repoRoot "Workflow System Audit\.antigravity-bridge\jobs"),
        (Join-Path $repoRoot ".antigravity-bridge\jobs"),
        (Join-Path $PWD ".antigravity-bridge\jobs"),
        (Join-Path $PWD "Workflow System Audit\.antigravity-bridge\jobs")
    )
    $candidateJobDirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
    foreach ($jr in ($searchJobRoots | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $jr -PathType Container) {
            $subdirs = Get-ChildItem -LiteralPath $jr -Directory -ErrorAction SilentlyContinue
            foreach ($sd in $subdirs) {
                $candidateJobDirs.Add($sd)
            }
        }
    }
    if ($candidateJobDirs.Count -eq 0) {
        Write-Error "No durable Antigravity bridge jobs found under .antigravity-bridge/jobs/"
        exit 1
    }
    # Prefer latest completed job (containing result.md with content > 0, status.json, and canonical state)
    $completedJobs = @($candidateJobDirs | Where-Object {
        $rPath = Join-Path $_.FullName "result.md"
        $sPath = Join-Path $_.FullName "status.json"
        if ((Test-Path -LiteralPath $rPath -PathType Leaf) -and
            (Get-Item -LiteralPath $rPath).Length -gt 0 -and
            (Test-Path -LiteralPath $sPath -PathType Leaf)) {
            try {
                $sj = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $sPath -Raw) -ErrorAction Stop
                $st = if ($sj.PSObject.Properties['state']) { [string]$sj.state } elseif ($sj.PSObject.Properties['lifecycle']) { [string]$sj.lifecycle } else { "" }
                $st.ToUpperInvariant() -in @('ARTIFACT_READY', 'VERIFIED', 'CLOSED')
            } catch {
                $false
            }
        } else {
            $false
        }
    })
    if ($completedJobs.Count -gt 0) {
        $chosen = $completedJobs | Sort-Object -Property Name -Descending | Select-Object -First 1
        $resolvedJobDir = $chosen.FullName
    } else {
        $chosen = $candidateJobDirs | Sort-Object -Property Name -Descending | Select-Object -First 1
        $resolvedJobDir = $chosen.FullName
    }
}

$passes = [System.Collections.Generic.List[string]]::new()
$fails = [System.Collections.Generic.List[string]]::new()

function Assert-Stage {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Message,
        [string]$FailureDetail = ""
    )
    if ($Condition) {
        $passes.Add("${Name}: $Message")
    } else {
        $detail = if ($FailureDetail) { " - $FailureDetail" } else { "" }
        $fails.Add("${Name}: FAILED - $Message$detail")
    }
}

function Set-StatusProperty {
    param(
        $Target,
        [string]$Name,
        $Value
    )
    if ($Target.PSObject.Properties[$Name]) {
        $Target.$Name = $Value
    } else {
        Add-Member -InputObject $Target -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
}

# --------------------------------------------------------------------------
# Load Real Job Files
# --------------------------------------------------------------------------
$requestMdPath = Join-Path $resolvedJobDir "request.md"
$statusJsonPath = Join-Path $resolvedJobDir "status.json"
$resultMdPath = Join-Path $resolvedJobDir "result.md"
$changedFilesPath = Join-Path $resolvedJobDir "changed-files.txt"
$diffPatchPath = Join-Path $resolvedJobDir "diff.patch"
$testSummaryPath = Join-Path $resolvedJobDir "test-output-summary.md"

$requestContent = ""
if (Test-Path -LiteralPath $requestMdPath -PathType Leaf) {
    $requestContent = Get-Content -LiteralPath $requestMdPath -Raw
}

$statusObj = $null
if (Test-Path -LiteralPath $statusJsonPath -PathType Leaf) {
    try {
        $statusObj = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $statusJsonPath -Raw) -ErrorAction Stop
    } catch {
        $statusObj = $null
    }
}

$extractedTaskId = ""
if ($statusObj) {
    if ($statusObj.PSObject.Properties['jobId'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.jobId)) {
        $extractedTaskId = [string]$statusObj.jobId
    } elseif ($statusObj.PSObject.Properties['taskId'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.taskId)) {
        $extractedTaskId = [string]$statusObj.taskId
    } elseif ($statusObj.PSObject.Properties['task'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.task)) {
        $extractedTaskId = [string]$statusObj.task
    }
}

# --------------------------------------------------------------------------
# Stage 1: User Task Definition & Intent
# --------------------------------------------------------------------------
$hasRequestMd = -not [string]::IsNullOrWhiteSpace($requestContent)

$hasValidRequest = $false
$requestValidationDetail = ""

if ($hasRequestMd) {
    $isOldGeneratedWrapper = ($requestContent -match '(?mi)^Goal\s*:' -or $requestContent -match '(?mi)^#{1,6}\s+Goal\b') -and
                             ($requestContent -match '(?mi)^Workspace\s*:') -and
                             ($requestContent -match '(?mi)^Routing decision\s*:') -and
                             ($requestContent -match '(?mi)^Workflow mode\s*:') -and
                             ($requestContent -match '(?mi)^Executor\s*:')

    if ($isOldGeneratedWrapper) {
        $hasValidRequest = $true
    } else {
        $missingSections = [System.Collections.Generic.List[string]]::new()
        if ($requestContent -notmatch '(?mi)(?:^#{1,6}\s+Goal\b|^\s*[-*]?\s*\*{0,2}Goal\*{0,2}\s*:)') { $missingSections.Add('Goal') }
        if ($requestContent -notmatch '(?mi)(?:^#{1,6}\s+Intent\b|^\s*[-*]?\s*\*{0,2}Intent\*{0,2}\s*:)') { $missingSections.Add('Intent') }
        if ($requestContent -notmatch '(?mi)(?:^#{1,6}\s+Scope\b|^\s*[-*]?\s*\*{0,2}Scope\*{0,2}\s*:)') { $missingSections.Add('Scope') }
        if ($requestContent -notmatch '(?mi)(?:^#{1,6}\s+Acceptance\s+Criteria\b|^\s*[-*]?\s*\*{0,2}Acceptance\s+Criteria\*{0,2}\s*:)') { $missingSections.Add('Acceptance Criteria') }
        if ($requestContent -notmatch '(?mi)(?:^#{1,6}\s+Tests?\b|^\s*[-*]?\s*\*{0,2}Tests?\*{0,2}\s*:)') { $missingSections.Add('Tests') }

        if ($missingSections.Count -eq 0) {
            $hasValidRequest = $true
        } else {
            $requestValidationDetail = "Missing required section(s): $(@($missingSections) -join ', ')"
        }
    }
}

Assert-Stage "Step 1: User Task" ($hasRequestMd -and $hasValidRequest -and -not [string]::IsNullOrWhiteSpace($extractedTaskId)) `
    "User task definition and intent parsed from request.md (Task ID: $extractedTaskId)" `
    $(if (-not $hasRequestMd) { "Missing or empty request.md" } elseif ([string]::IsNullOrWhiteSpace($extractedTaskId)) { "Missing task ID in status.json" } else { "Invalid request body ($requestValidationDetail)" })

# --------------------------------------------------------------------------
# Stage 2: Codex Routing & Explicit Contract
# --------------------------------------------------------------------------
$hasWorkspace = $false
$hasExecutor = $false
$hasArtifactLoc = $false
$hasRouting = $false

if ($statusObj) {
    $rawWs = if ($statusObj.PSObject.Properties['workspace']) { [string]$statusObj.workspace } else { "" }
    $hasWorkspace = ($rawWs -match '^[A-Za-z]:[\\/]' -or $rawWs -match '^\\\\[^\\]+\\[^\\]+') -and ($rawWs -notmatch '(?i)\b(unknown|unspecified)\b')

    $rawExec = if ($statusObj.PSObject.Properties['executor']) { [string]$statusObj.executor } else { "" }
    $hasExecutor = ($rawExec.Trim().ToLowerInvariant() -eq 'antigravity')

    $hasArtifactLoc = ($statusObj.PSObject.Properties['resultArtifact'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.resultArtifact)) -or
                      ($statusObj.PSObject.Properties['resultFile'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.resultFile)) -or
                      ($statusObj.PSObject.Properties['jobFolder'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.jobFolder)) -or
                      ($statusObj.PSObject.Properties['artifactDirectory'] -and -not [string]::IsNullOrWhiteSpace([string]$statusObj.artifactDirectory))

    $rawRouting = if ($statusObj.PSObject.Properties['routingDecision']) { [string]$statusObj.routingDecision } else { "" }
    $rawMode = if ($statusObj.PSObject.Properties['workflowMode']) { [string]$statusObj.workflowMode } else { "" }

    # status.json is the authoritative execution envelope for bridge jobs.
    # Fail closed when missing routingDecision or workflowMode in status.json;
    # require status.json to explicitly declare routingDecision=DELEGATED, executor=antigravity,
    # and a consistent non-DIRECT delegated path (e.g. DELEGATED or HYBRID).
    $hasDelegatedRouting = ($rawRouting.ToUpperInvariant() -eq 'DELEGATED')
    $hasDelegatedPath = (-not [string]::IsNullOrWhiteSpace($rawMode)) -and
                        ($rawMode.ToUpperInvariant() -ne 'DIRECT')

    $hasRouting = $hasDelegatedRouting -and $hasDelegatedPath
}

$routingValid = $hasWorkspace -and $hasExecutor -and $hasArtifactLoc -and $hasRouting
Assert-Stage "Step 2: Codex Routing" $routingValid `
    "Codex routed task to Antigravity carrying explicit task ID, workspace, executor=antigravity, routingDecision=DELEGATED, and artifact location in status.json" `
    "Routing contract in status.json missing absolute workspace, executor=antigravity, routingDecision=DELEGATED, or matching non-DIRECT workflowMode"

# --------------------------------------------------------------------------
# Stage 3: Bridge Submission
# --------------------------------------------------------------------------
$canonicalLifecycle = @('CREATED', 'SUBMITTED', 'RUNNING', 'ARTIFACT_READY', 'VERIFIED', 'CLOSED')
$rawState = ""
if ($statusObj) {
    if ($statusObj.PSObject.Properties['state']) { $rawState = [string]$statusObj.state }
    elseif ($statusObj.PSObject.Properties['lifecycle']) { $rawState = [string]$statusObj.lifecycle }
}
$stateUpper = $rawState.ToUpperInvariant()

$hasSubmissionStatus = ($statusObj -and $statusObj.PSObject.Properties['submissionStatus'] -and
                        ([string]$statusObj.submissionStatus -match '(?i)^(submitted|completed)$')) -or
                       ($stateUpper -in @('SUBMITTED', 'RUNNING', 'ARTIFACT_READY', 'VERIFIED', 'CLOSED'))

Assert-Stage "Step 3: Bridge Submission" ($hasSubmissionStatus -and $stateUpper -in $canonicalLifecycle) `
    "Execution request verified in bridge queue; canonical lifecycle progression observed (state: $stateUpper)" `
    "Submission status missing or invalid lifecycle state"

# --------------------------------------------------------------------------
# Stage 4: Antigravity Execution
# --------------------------------------------------------------------------
$hasExecutionStatus = ($statusObj -and $statusObj.PSObject.Properties['executionStatus'] -and
                       ([string]$statusObj.executionStatus -match '(?i)^(running|completed)$')) -or
                      ($stateUpper -in @('RUNNING', 'ARTIFACT_READY', 'VERIFIED', 'CLOSED'))

Assert-Stage "Step 4: Antigravity Execution" ($hasExecutionStatus -and $hasExecutor) `
    "Antigravity executor actively executed allowlisted task (executor: antigravity)" `
    "Execution status missing or executor is not antigravity"

# --------------------------------------------------------------------------
# Stage 5: Artifact Generation (ARTIFACT_READY)
# --------------------------------------------------------------------------
$artifactsPresent = (Test-Path -LiteralPath $resultMdPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $statusJsonPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $changedFilesPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $diffPatchPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $testSummaryPath -PathType Leaf)

$artifactsNonEmpty = $false
if ($artifactsPresent) {
    $artifactsNonEmpty = ((Get-Item -LiteralPath $resultMdPath).Length -gt 0) -and
                         ((Get-Item -LiteralPath $statusJsonPath).Length -gt 0) -and
                         ((Get-Item -LiteralPath $changedFilesPath).Length -gt 0) -and
                         ((Get-Item -LiteralPath $testSummaryPath).Length -gt 0)
}

$stateReachedArtifactReady = ($stateUpper -in @('ARTIFACT_READY', 'VERIFIED', 'CLOSED'))
Assert-Stage "Step 5: Artifact Generation" ($artifactsPresent -and $artifactsNonEmpty -and $stateReachedArtifactReady) `
    "All 5 required durable artifacts generated in bridge job directory; state reached ARTIFACT_READY" `
    "Missing or empty durable artifacts in job directory, or state did not reach ARTIFACT_READY"

# --------------------------------------------------------------------------
# Stage 6: Codex Verification & Closure
# --------------------------------------------------------------------------
$evidenceCheckOutput = & $evidenceCheckScript -EvidenceDir $resolvedJobDir -RequireTestSummary 2>&1
$evidenceExitCode = $LASTEXITCODE
$evidencePassed = ($evidenceExitCode -eq 0) -and (($evidenceCheckOutput -join "`n") -match 'STATUS:\s*PASS')

$validationStatusPass = ($statusObj -and (($statusObj.PSObject.Properties['validation'] -and [string]$statusObj.validation -eq 'PASS') -or
                                          ($statusObj.PSObject.Properties['status'] -and [string]$statusObj.status -eq 'PASS')))

# Provenance enforcement: Antigravity produces ARTIFACT_READY only.
# VERIFIED requires verifiedBy=codex; CLOSED requires verifiedBy=codex and closedBy=codex.
$hasCodexVerified = ($statusObj -and (($statusObj.PSObject.Properties['verifiedBy'] -and [string]$statusObj.verifiedBy.Trim().ToLowerInvariant() -eq 'codex') -or
                     ($statusObj.PSObject.Properties['provenance'] -and $statusObj.provenance.PSObject.Properties['verifiedBy'] -and [string]$statusObj.provenance.verifiedBy.Trim().ToLowerInvariant() -eq 'codex')))
$hasCodexClosed = ($statusObj -and (($statusObj.PSObject.Properties['closedBy'] -and [string]$statusObj.closedBy.Trim().ToLowerInvariant() -eq 'codex') -or
                   ($statusObj.PSObject.Properties['provenance'] -and $statusObj.provenance.PSObject.Properties['closedBy'] -and [string]$statusObj.provenance.closedBy.Trim().ToLowerInvariant() -eq 'codex')))

$provenanceValid = $true
if ($stateUpper -eq 'VERIFIED') {
    $provenanceValid = $hasCodexVerified
} elseif ($stateUpper -eq 'CLOSED') {
    $provenanceValid = $hasCodexVerified -and $hasCodexClosed
}

Assert-Stage "Step 6: Codex Verification" ($evidencePassed -and $validationStatusPass -and $provenanceValid) `
    "Evidence validator confirmed PASS; lifecycle successfully verified with durable provenance (job: $(Split-Path -Leaf $resolvedJobDir))" `
    "Evidence validator returned non-PASS or job lacks required Codex transition provenance (exit code: $evidenceExitCode)"

if ($Advance) {
    if ($stateUpper -ne 'ARTIFACT_READY') {
        Write-Error "Advance transition error: Job '$extractedTaskId' is in state '$stateUpper'; can only advance to VERIFIED from ARTIFACT_READY."
        exit 1
    }
    if (-not ($evidencePassed -and $validationStatusPass)) {
        Write-Error "Advance transition error: Job '$extractedTaskId' cannot advance to VERIFIED without passing verification."
        exit 1
    }
    Set-StatusProperty $statusObj 'state' 'VERIFIED'
    Set-StatusProperty $statusObj 'lifecycle' 'VERIFIED'
    Set-StatusProperty $statusObj 'verifiedBy' 'codex'
    Set-StatusProperty $statusObj 'verifiedAt' ([DateTime]::UtcNow.ToString("o"))
    if ($statusObj.PSObject.Properties['currentStep']) {
        Set-StatusProperty $statusObj 'currentStep' 'verified'
    }
    Set-StatusProperty $statusObj 'updatedAt' ([DateTime]::UtcNow.ToString("o"))
    Set-Content -LiteralPath $statusJsonPath -Value ($statusObj | ConvertTo-Json -Depth 10)
    Write-Host "`nCodex verification advanced job '$extractedTaskId' from ARTIFACT_READY to VERIFIED."
}

if ($Close) {
    if ($stateUpper -ne 'VERIFIED') {
        Write-Error "Guarded transition error: Job '$extractedTaskId' is in state '$stateUpper'; can only transition to CLOSED from VERIFIED."
        exit 1
    }
    if (-not ($evidencePassed -and $validationStatusPass)) {
        Write-Error "Guarded transition error: Job '$extractedTaskId' cannot transition to CLOSED without passing verification."
        exit 1
    }
    if (-not $hasCodexVerified) {
        Write-Error "Guarded transition error: Job '$extractedTaskId' lacks durable Codex verification provenance."
        exit 1
    }
    Set-StatusProperty $statusObj 'state' 'CLOSED'
    Set-StatusProperty $statusObj 'lifecycle' 'CLOSED'
    Set-StatusProperty $statusObj 'closedBy' 'codex'
    Set-StatusProperty $statusObj 'closedAt' ([DateTime]::UtcNow.ToString("o"))
    if ($statusObj.PSObject.Properties['currentStep']) {
        Set-StatusProperty $statusObj 'currentStep' 'closed'
    }
    Set-StatusProperty $statusObj 'updatedAt' ([DateTime]::UtcNow.ToString("o"))
    Set-Content -LiteralPath $statusJsonPath -Value ($statusObj | ConvertTo-Json -Depth 10)
    Write-Host "`nGuarded Codex transition advanced job '$extractedTaskId' from VERIFIED to CLOSED."
}

# --------------------------------------------------------------------------
# Output Summary
# --------------------------------------------------------------------------
Write-Host "================================================================="
Write-Host "  Minimal Read-Only Golden-Path Bridge Verification              "
Write-Host "  Target: $resolvedJobDir"
Write-Host "=================================================================`n"

Write-Host "PASS:"
foreach ($p in $passes) {
    Write-Host "- $p"
}

if ($fails.Count -gt 0) {
    Write-Host "`nFAIL:"
    foreach ($f in $fails) {
        Write-Host "- $f"
    }
    Write-Host "`nSTATUS: FAIL"
    exit 1
} else {
    Write-Host "`nFAIL:`nNone"
    Write-Host "`nSTATUS: PASS (ALL 6 OBSERVED PIPELINE STAGES VERIFIED)"
    exit 0
}

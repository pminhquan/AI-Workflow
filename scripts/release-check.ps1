<#
.SYNOPSIS
    Read-only pre-release readiness and evidence-based gate verification check.
.DESCRIPTION
    Validates release readiness across Git state, build tool availability, test tier
    compliance, release artifact integrity, and runtime smoke evidence without performing
    git mutations, tags, or deployments.
.PARAMETER RepoPath
    The directory of the git repository to check. Defaults to current directory.
.PARAMETER RequireClean
    Enforces that the working tree must have no uncommitted changes. Defaults to true.
.PARAMETER RequireBranch
    Optional expected branch name (e.g., 'main', 'release/v1.0').
.PARAMETER RequiredFiles
    Array of file paths that must exist for release readiness. Defaults to @('README.md').
.PARAMETER TestTier
    Verification tier being checked (0, 1, 2, 3, or 4). Default is 4.
.PARAMETER TestEvidence
    Path to test log/report file, or inline summary string (e.g. 'PASS (42 tests)').
.PARAMETER AllowSkippedTests
    If specified, permits tests to be SKIPPED without failing the gate (dry-run mode).
.PARAMETER ValidateBuild
    If specified, explicitly validates build execution/outcome.
.PARAMETER BuildTool
    Optional build tool override ('mvn', 'gradle', 'npm', 'dotnet', 'python').
.PARAMETER BuildEvidence
    Path to build log/report file, or inline summary string. Required when -ValidateBuild is specified.
.PARAMETER ArtifactPath
    Path to the release artifact file to validate.
.PARAMETER SupportedArtifactExtensions
    Allowed artifact file extensions. Defaults to common packaging formats.
.PARAMETER SmokeEvidence
    Path to smoke test log/report, or inline smoke evidence summary string.
.PARAMETER SafeMode
    If specified, runs in non-blocking safe inspection mode against current workspace.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = (Get-Location).Path,

    [bool]$RequireClean = $true,

    [string]$RequireBranch,

    [string[]]$RequiredFiles = @('README.md'),

    [ValidateRange(0, 4)]
    [int]$TestTier = 4,

    [string]$TestEvidence,

    [switch]$AllowSkippedTests,

    [switch]$ValidateBuild,

    [string]$BuildTool,

    [string]$BuildEvidence,

    [string]$ArtifactPath,

    [string[]]$SupportedArtifactExtensions = @('.jar', '.war', '.zip', '.tar.gz', '.tgz', '.whl', '.nupkg', '.exe', '.dll', '.bin', '.tar'),

    [string]$SmokeEvidence,

    [switch]$SafeMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Pre-Release Readiness Check (Tier $TestTier) ==="

$sourceFailures = [System.Collections.Generic.List[string]]::new()
$artifactFailures = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------
# 1. GIT VALIDATION
# ---------------------------------------------------------
Write-Host "`n[GIT_VALIDATION]"

# Verify Git executable
$gitCmd = Get-Command -Name "git" -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    $sourceFailures.Add("Git executable not found in PATH.")
    Write-Host "[-] Git executable: NOT FOUND"
} else {
    Write-Host "[+] Git executable: Available ($($gitCmd.Source))"
}

# Verify repository path
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    Write-Error "Repository path does not exist or is not a directory: $RepoPath"
    exit 1
}

$resolvedPath = (Resolve-Path -LiteralPath $RepoPath).Path
Write-Host "[+] Repository Path: $resolvedPath"

# Verify inside git work tree
$isGit = $false
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $gitOut = @(& git -C $resolvedPath rev-parse --is-inside-work-tree 2>&1)
    if ($LASTEXITCODE -eq 0 -and ($gitOut -join '').Trim() -eq 'true') {
        $isGit = $true
    }
} catch {
    $isGit = $false
} finally {
    $ErrorActionPreference = $prevEAP
}

if (-not $isGit) {
    $sourceFailures.Add("Directory is not a Git repository: $resolvedPath")
    Write-Host "[-] Git Repository: NOT A GIT REPOSITORY"
} else {
    # Get current branch with exit code validation
    $branchOut = @(& git -C $resolvedPath rev-parse --abbrev-ref HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $sourceFailures.Add("Git rev-parse --abbrev-ref HEAD failed with exit code $LASTEXITCODE : $($branchOut -join '; ')")
        Write-Host "[-] Current Branch : FAIL (rev-parse exited with code $LASTEXITCODE)"
        $currentBranch = "UNKNOWN"
    } else {
        $currentBranch = ($branchOut -join '').Trim()
        Write-Host "[+] Current Branch : $currentBranch"
    }

    # Get target commit SHA with exit code validation
    $shaOut = @(& git -C $resolvedPath rev-parse --short HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $sourceFailures.Add("Git rev-parse --short HEAD failed with exit code $LASTEXITCODE : $($shaOut -join '; ')")
        Write-Host "[-] Target Commit  : FAIL (rev-parse exited with code $LASTEXITCODE)"
        $currentSha = "UNKNOWN"
    } else {
        $currentSha = ($shaOut -join '').Trim()
        Write-Host "[+] Target Commit  : $currentSha"
    }

    # Branch check if required
    if ($RequireBranch) {
        if ($currentBranch -ne $RequireBranch) {
            $sourceFailures.Add("Expected branch '$RequireBranch', but currently on '$currentBranch'.")
            Write-Host "[-] Branch Check   : FAIL (Expected: $RequireBranch, Actual: $currentBranch)"
        } else {
            Write-Host "[+] Branch Check   : PASS (Matches expected: $RequireBranch)"
        }
    }

    # Clean working tree check with exit code validation
    $statusLines = @(& git -C $resolvedPath status --porcelain 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $sourceFailures.Add("Git status --porcelain failed with exit code $LASTEXITCODE : $($statusLines -join '; ')")
        Write-Host "[-] Working Tree   : FAIL (git status exited with code $LASTEXITCODE)"
        $dirtyLines = @()
        $dirtyCount = -1
    } else {
        $dirtyLines = @($statusLines | Where-Object { $_ -and $_.Trim() -ne '' })
        $dirtyCount = $dirtyLines.Count

        if ($dirtyCount -gt 0) {
            if ($RequireClean -and -not $SafeMode) {
                $sourceFailures.Add("Working tree has $dirtyCount uncommitted change(s). Release requires a clean working tree.")
                Write-Host "[-] Working Tree   : DIRTY ($dirtyCount uncommitted change(s))"
            } else {
                Write-Host "[!] Working Tree   : DIRTY ($dirtyCount changed file(s); allowed by configuration/SafeMode)"
            }
        } else {
            Write-Host "[+] Working Tree   : CLEAN (0 uncommitted changes)"
        }
    }

    # Unexpected untracked release files check
    $releasePatterns = @('*.jar', '*.war', '*.zip', '*.tar.gz', '*.tgz', '*.whl', '*.nupkg', '*.exe', '*.dll', '*.bin', '*.tar', 'release/*', 'dist/*', 'build/libs/*', 'target/*.jar')
    $untrackedReleaseFiles = @()
    foreach ($line in $dirtyLines) {
        if ($line -like '?? *') {
            $relFile = $line.Substring(3).Trim().Trim('"')
            foreach ($pattern in $releasePatterns) {
                if ($relFile -like $pattern) {
                    $untrackedReleaseFiles += $relFile
                    break
                }
            }
        }
    }

    if ($untrackedReleaseFiles.Count -gt 0) {
        $sourceFailures.Add("Unexpected untracked release file(s) detected: $($untrackedReleaseFiles -join ', ')")
        Write-Host "[-] Untracked Files: FAIL (Found untracked release files: $($untrackedReleaseFiles -join ', '))"
    } else {
        Write-Host "[+] Untracked Files: PASS (No unexpected untracked release files)"
    }
}

# ---------------------------------------------------------
# 2. BUILD VALIDATION
# ---------------------------------------------------------
Write-Host "`n[BUILD_VALIDATION]"

# Detect build tools and wrappers
$detectedBuildTools = [System.Collections.Generic.List[string]]::new()
$hasMavenWrapper = (Test-Path -LiteralPath (Join-Path $resolvedPath "mvnw") -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $resolvedPath "mvnw.cmd") -PathType Leaf)
$hasGradleWrapper = (Test-Path -LiteralPath (Join-Path $resolvedPath "gradlew") -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $resolvedPath "gradlew.cmd") -PathType Leaf)

if ($hasMavenWrapper) { $detectedBuildTools.Add("Maven Wrapper (mvnw)") }
if ($hasGradleWrapper) { $detectedBuildTools.Add("Gradle Wrapper (gradlew)") }

$mvnCmd = Get-Command -Name "mvn" -ErrorAction SilentlyContinue
if ($mvnCmd) { $detectedBuildTools.Add("Maven CLI") }
$gradleCmd = Get-Command -Name "gradle" -ErrorAction SilentlyContinue
if ($gradleCmd) { $detectedBuildTools.Add("Gradle CLI") }
$npmCmd = Get-Command -Name "npm" -ErrorAction SilentlyContinue
if ($npmCmd) { $detectedBuildTools.Add("npm") }

# Determine selected build tool reflecting Maven wrapper priority
$selectedBuildTool = ""
if ($BuildTool) {
    $selectedBuildTool = $BuildTool
} elseif ($hasMavenWrapper) {
    $selectedBuildTool = "Maven Wrapper (mvnw)"
} elseif (Test-Path -LiteralPath (Join-Path $resolvedPath "pom.xml") -PathType Leaf) {
    $selectedBuildTool = if ($mvnCmd) { "Maven CLI (mvn)" } else { "Maven" }
} elseif ($hasGradleWrapper) {
    $selectedBuildTool = "Gradle Wrapper (gradlew)"
} elseif (Test-Path -LiteralPath (Join-Path $resolvedPath "build.gradle") -PathType Leaf) {
    $selectedBuildTool = if ($gradleCmd) { "Gradle CLI (gradle)" } else { "Gradle" }
} elseif ($detectedBuildTools.Count -gt 0) {
    $selectedBuildTool = $detectedBuildTools[0]
} else {
    $selectedBuildTool = "None detected"
}

if ($BuildTool) {
    $customCmd = Get-Command -Name $BuildTool -ErrorAction SilentlyContinue
    if ($customCmd) {
        Write-Host "[+] Build Tool ($BuildTool): Available ($($customCmd.Source))"
    } else {
        $sourceFailures.Add("Specified build tool '$BuildTool' not found in PATH.")
        Write-Host "[-] Build Tool ($BuildTool): NOT FOUND"
    }
} elseif ($detectedBuildTools.Count -gt 0) {
    Write-Host "[+] Available Tools: $($detectedBuildTools -join ', ')"
} else {
    Write-Host "[*] Available Tools: None detected at top level"
}

Write-Host "[+] Selected Tool  : $selectedBuildTool"
if ($hasMavenWrapper) {
    Write-Host "[+] Maven Wrapper  : Present and supported (selected for build validation)"
} else {
    Write-Host "[*] Maven Wrapper  : Not present"
}

if ($ValidateBuild) {
    Write-Host "[+] Build Result   : Validating explicitly requested build execution ($selectedBuildTool)"
    if ($BuildEvidence -and $BuildEvidence.Trim() -ne '') {
        $buildEvidenceText = $BuildEvidence
        if (Test-Path -LiteralPath $BuildEvidence -PathType Leaf) {
            try {
                $buildEvidenceText = Get-Content -LiteralPath $BuildEvidence -Raw
                Write-Host "[+] Build Evidence : Loaded from file: $BuildEvidence"
            } catch {
                $sourceFailures.Add("Unable to read build evidence file: $BuildEvidence")
                $buildEvidenceText = ""
            }
        } else {
            Write-Host "[+] Build Evidence : Supplied inline summary: $BuildEvidence"
        }

        if ($buildEvidenceText -match '(?i)\b(fail|failed|failure|build failure|errors?:\s*[1-9])\b') {
            $sourceFailures.Add("Build validation failed: Build evidence indicates build failure for $selectedBuildTool.")
            Write-Host "[-] Build Result   : FAIL (Build evidence indicates failure for $selectedBuildTool)"
        } elseif ($buildEvidenceText -match '(?i)\b(pass|passed|success|build success|ok)\b') {
            Write-Host "[+] Build Result   : PASS (Verified build evidence for $selectedBuildTool)"
        } else {
            $sourceFailures.Add("Build validation failed: Build evidence does not confirm successful status for $selectedBuildTool.")
            Write-Host "[-] Build Result   : FAIL (Build evidence does not confirm successful status)"
        }
    } else {
        # Fail closed when requested evidence/result is absent
        $sourceFailures.Add("Build validation failed: -ValidateBuild requested but verifiable build evidence was absent (use -BuildEvidence <file|string>). Fail-closed.")
        Write-Host "[-] Build Result   : FAIL (No verifiable build evidence supplied for $selectedBuildTool; fail-closed)"
    }
} else {
    Write-Host "[*] Build Result   : SKIPPED (Validation of build result only executed when explicitly requested via -ValidateBuild)"
}

# ---------------------------------------------------------
# 3. TEST VALIDATION
# ---------------------------------------------------------
Write-Host "`n[TEST_VALIDATION]"
Write-Host "[+] Declared Tier  : Tier $TestTier"

$testStatus = "SKIPPED"
if ($TestEvidence -and $TestEvidence.Trim() -ne '') {
    $evidenceText = $TestEvidence
    if (Test-Path -LiteralPath $TestEvidence -PathType Leaf) {
        try {
            $evidenceText = Get-Content -LiteralPath $TestEvidence -Raw
            Write-Host "[+] Test Evidence  : Loaded from file: $TestEvidence"
        } catch {
            $sourceFailures.Add("Unable to read test evidence file: $TestEvidence")
            $testStatus = "FAILED"
        }
    } else {
        Write-Host "[+] Test Evidence  : Supplied inline summary: $TestEvidence"
    }

    if ($testStatus -ne "FAILED") {
        if ($evidenceText -match '(?i)\b(pass|passed|success|ok)\b' -and $evidenceText -notmatch '(?i)\b(fail|failed|failure|errors?:\s*[1-9])\b') {
            $testStatus = "PASSED"
        } else {
            $testStatus = "FAILED"
        }
    }
} else {
    Write-Host "[*] Test Evidence  : None supplied"
}

Write-Host "[+] Test Status    : $testStatus"

# Enforce declared TestTier
if ($TestTier -eq 0) {
    Write-Host "[+] Tier Gate      : PASS (Tier 0 - docs/static; test suite execution not required)"
} elseif ($testStatus -eq "PASSED") {
    Write-Host "[+] Tier Gate      : PASS (Tier $TestTier test evidence verified)"
} elseif ($testStatus -eq "SKIPPED") {
    if ($AllowSkippedTests -or $SafeMode) {
        Write-Host "[!] Tier Gate      : SKIPPED (Tier $TestTier test execution skipped; permitted by configuration/SafeMode)"
    } else {
        $sourceFailures.Add("Test validation failed: Tier $TestTier requires verified test evidence (use -TestEvidence or -AllowSkippedTests).")
        Write-Host "[-] Tier Gate      : FAIL (Tier $TestTier requires test evidence; status is SKIPPED)"
    }
} else {
    $sourceFailures.Add("Test validation failed: Test evidence indicates test failures.")
    Write-Host "[-] Tier Gate      : FAIL (Test evidence indicates failure)"
}

# ---------------------------------------------------------
# 4. REQUIRED FILES VALIDATION
# ---------------------------------------------------------
if ($RequiredFiles -and $RequiredFiles.Count -gt 0) {
    $missingFiles = @()
    foreach ($file in $RequiredFiles) {
        $fullFilePath = Join-Path $resolvedPath $file
        if (-not (Test-Path -LiteralPath $fullFilePath)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        $sourceFailures.Add("Missing required release file(s): $($missingFiles -join ', ')")
        Write-Host "[-] Required Files : FAIL (Missing: $($missingFiles -join ', '))"
    } else {
        Write-Host "[+] Required Files : PASS ($($RequiredFiles.Count) verified present)"
    }
}

# ---------------------------------------------------------
# 5. ARTIFACT VALIDATION
# ---------------------------------------------------------
Write-Host "`n[ARTIFACT_VALIDATION]"
$artifactValidated = $false
$artifactSha256 = ""
$resolvedArtifact = ""

if ($ArtifactPath -and $ArtifactPath.Trim() -ne '') {
    $resolvedArtifact = if ([System.IO.Path]::IsPathRooted($ArtifactPath)) {
        $ArtifactPath
    } else {
        Join-Path $resolvedPath $ArtifactPath
    }

    Write-Host "[+] Target Artifact: $resolvedArtifact"

    # 1. Existing regular file
    if (-not (Test-Path -LiteralPath $resolvedArtifact -PathType Leaf)) {
        $artifactFailures.Add("Artifact file does not exist or is not a regular file: $resolvedArtifact")
        Write-Host "[-] File Existence : FAIL (File does not exist: $resolvedArtifact)"
    } else {
        Write-Host "[+] File Existence : PASS (Regular file exists)"

        # 2. Supported file type
        $isSupportedExt = $false
        $matchedExt = ""
        $fileNameLower = [System.IO.Path]::GetFileName($resolvedArtifact).ToLowerInvariant()

        foreach ($ext in $SupportedArtifactExtensions) {
            $extLower = $ext.ToLowerInvariant()
            if ($fileNameLower.EndsWith($extLower)) {
                $isSupportedExt = $true
                $matchedExt = $extLower
                break
            }
        }

        if (-not $isSupportedExt) {
            $artifactFailures.Add("Artifact format is not supported: $fileNameLower (Supported: $($SupportedArtifactExtensions -join ', '))")
            Write-Host "[-] File Type      : FAIL ($fileNameLower is not in supported list)"
        } else {
            Write-Host "[+] File Type      : PASS ($matchedExt is supported)"
        }

        # 3. Non-zero size
        $item = Get-Item -LiteralPath $resolvedArtifact
        if ($item.Length -le 0) {
            $artifactFailures.Add("Artifact file is empty (0 bytes).")
            Write-Host "[-] File Size      : FAIL (0 bytes)"
        } else {
            Write-Host "[+] File Size      : PASS ($($item.Length) bytes)"
        }

        # 4. SHA-256 checksum
        try {
            $hashResult = Get-FileHash -LiteralPath $resolvedArtifact -Algorithm SHA256
            $artifactSha256 = $hashResult.Hash
            Write-Host "[+] SHA-256 Hash   : $artifactSha256"
        } catch {
            $artifactFailures.Add("Failed to calculate SHA-256 checksum: $($_.Exception.Message)")
            Write-Host "[-] SHA-256 Hash   : FAIL ($($_.Exception.Message))"
        }

        if ($artifactFailures.Count -eq 0) {
            $artifactValidated = $true
        }
    }
} else {
    Write-Host "[*] Target Artifact: None specified"
    $artifactFailures.Add("No artifact path specified via -ArtifactPath.")
}

# ---------------------------------------------------------
# 6. RUNTIME VALIDATION
# ---------------------------------------------------------
Write-Host "`n[RUNTIME_VALIDATION]"
$runtimeVerified = $false

if ($SmokeEvidence -and $SmokeEvidence.Trim() -ne '') {
    $smokeText = $SmokeEvidence
    if (Test-Path -LiteralPath $SmokeEvidence -PathType Leaf) {
        try {
            $smokeText = (Get-Content -LiteralPath $SmokeEvidence -Raw).Trim()
            Write-Host "[+] Smoke Evidence : Loaded from file: $SmokeEvidence"
        } catch {
            Write-Host "[-] Smoke Evidence : Unable to read file: $SmokeEvidence"
        }
    } else {
        Write-Host "[+] Smoke Evidence : Supplied inline: $SmokeEvidence"
    }

    if ($smokeText -match '(?i)\b(pass|passed|verified|success|healthy|200 ok)\b' -and $smokeText -notmatch '(?i)\b(fail|failed|failure|crash|unhealthy)\b') {
        $runtimeVerified = $true
        Write-Host "[+] Runtime Status : VERIFIED (Smoke evidence validated)"
    } else {
        Write-Host "[-] Runtime Status : UNVERIFIED (Smoke evidence did not confirm healthy status)"
    }
} else {
    Write-Host "[*] Runtime Status : UNVERIFIED (No smoke evidence supplied; never claim runtime readiness without evidence)"
}

# ---------------------------------------------------------
# 7. SECTION OUTPUT CONTRACT
# ---------------------------------------------------------
Write-Host "`n============================================================"
$sourceStatus = if ($sourceFailures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Host "SOURCE_VALIDATION: $sourceStatus"
if ($sourceFailures.Count -gt 0) {
    foreach ($f in $sourceFailures) {
        Write-Host "  - $f"
    }
}

Write-Host "`n============================================================"
$artifactStatus = if ($artifactValidated -and $artifactFailures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Host "ARTIFACT_VALIDATION: $artifactStatus"
if ($artifactFailures.Count -gt 0) {
    foreach ($f in $artifactFailures) {
        Write-Host "  - $f"
    }
} elseif ($artifactValidated) {
    Write-Host "  - Artifact: $resolvedArtifact"
    Write-Host "  - SHA-256 : $artifactSha256"
}

Write-Host "`n============================================================"
$runtimeStatus = if ($runtimeVerified) { "VERIFIED" } else { "UNVERIFIED" }
Write-Host "RUNTIME_VALIDATION: $runtimeStatus"
if (-not $runtimeVerified) {
    Write-Host "  - Notice: Runtime readiness is unverified without supplied smoke evidence."
}

Write-Host "`n============================================================"
Write-Host "HUMAN-RELEASE DECISION BOUNDARY"
Write-Host "============================================================"
Write-Host "Final release decisions, git tagging, and deployments remain the"
Write-Host "exclusive responsibility of the human engineer. AI agents are strictly"
Write-Host "prohibited from executing git mutations, tags, or deployment triggers."

# Exit code logic
if ($SafeMode) {
    Write-Host "`nRelease gate execution completed under SafeMode (safe inspection mode: release readiness not certified; gates not passed)."
    exit 0
}

if ($sourceStatus -eq "PASS" -and $artifactStatus -eq "PASS" -and $runtimeStatus -eq "VERIFIED") {
    Write-Host "`nRelease gate check completed: ALL GATES PASSED."
    exit 0
} else {
    $blockers = [System.Collections.Generic.List[string]]::new()
    if ($sourceStatus -ne "PASS") { $blockers.Add("SOURCE_VALIDATION: $sourceStatus") }
    if ($artifactStatus -ne "PASS") { $blockers.Add("ARTIFACT_VALIDATION: $artifactStatus") }
    if ($runtimeStatus -ne "VERIFIED") { $blockers.Add("RUNTIME_VALIDATION: $runtimeStatus (smoke evidence required for release readiness)") }
    Write-Host "`nRelease gate check completed: GATE BLOCKED ($($blockers -join '; '))."
    exit 1
}

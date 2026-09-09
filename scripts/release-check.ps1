<#
.SYNOPSIS
    Read-only release readiness and gate verification check.
.DESCRIPTION
    Validates release readiness criteria (clean working tree, required files)
    without performing git mutations, tags, or deployments.
.PARAMETER RepoPath
    The directory of the git repository to check. Defaults to current directory.
.PARAMETER RequireClean
    Enforces that the working tree must have no uncommitted changes. Defaults to true.
.PARAMETER RequiredFiles
    Optional array of file paths that must exist for release readiness.
.PARAMETER TestTier
    Verification tier being checked (0, 1, 2, 3, or 4). Default is 4.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = (Get-Location).Path,

    [bool]$RequireClean = $true,

    [string[]]$RequiredFiles = @('README.md'),

    [ValidateRange(0, 4)]
    [int]$TestTier = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Pre-Release Readiness Check (Tier $TestTier) ==="

# 1. Verify Git executable
$gitCmd = Get-Command -Name "git" -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Error "Git executable not found in PATH."
    exit 1
}

# 2. Verify repository path
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    Write-Error "Repository path does not exist or is not a directory: $RepoPath"
    exit 1
}

$resolvedPath = (Resolve-Path -LiteralPath $RepoPath).Path

# 3. Verify inside git work tree
$isGit = $false
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $gitOut = & git -C $resolvedPath rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -eq 0 -and ($gitOut -join '').Trim() -eq 'true') {
        $isGit = $true
    }
} catch {
    $isGit = $false
} finally {
    $ErrorActionPreference = $prevEAP
}

if (-not $isGit) {
    Write-Error "Directory is not a Git repository: $resolvedPath"
    exit 1
}

$currentBranch = (& git -C $resolvedPath rev-parse --abbrev-ref HEAD).Trim()
$currentSha = (& git -C $resolvedPath rev-parse --short HEAD).Trim()
Write-Host "Repository : $resolvedPath"
Write-Host "Target SHA : $currentSha ($currentBranch)"

# 4. Clean tree check
$statusLines = & git -C $resolvedPath status --porcelain
$dirtyCount = 0
if ($statusLines) {
    $dirtyCount = ($statusLines | Where-Object { $_ -and $_.Trim() -ne '' }).Count
}

if ($RequireClean -and $dirtyCount -gt 0) {
    Write-Error "Release check failed: Working tree has $dirtyCount uncommitted change(s). Release requires a clean working tree."
    exit 1
} else {
    Write-Host "[PASS] Working tree cleanliness verified."
}

# 5. Required files check
if ($RequiredFiles -and $RequiredFiles.Count -gt 0) {
    $missingFiles = @()
    foreach ($file in $RequiredFiles) {
        $fullFilePath = Join-Path $resolvedPath $file
        if (-not (Test-Path -LiteralPath $fullFilePath)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Error ("Release check failed: Missing required file(s):`n" + ($missingFiles -join "`n"))
        exit 1
    } else {
        Write-Host "[PASS] Required release files present ($($RequiredFiles.Count) verified)."
    }
}

Write-Host "`nRelease gate check completed: ALL CHECKS PASSED."
Write-Host "Note: Final release, tagging, and deployment remain the exclusive responsibility of the human engineer."
exit 0

<#
.SYNOPSIS
    Read-only Git health and status check.
.DESCRIPTION
    Inspects git repository status, branch, and uncommitted changes without modifying repository state.
.PARAMETER RepoPath
    The directory of the git repository to check. Defaults to current directory.
.PARAMETER RequireClean
    If specified, fails if there are uncommitted or untracked changes.
.PARAMETER RequireBranch
    If specified, fails if current branch does not match the specified name.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = (Get-Location).Path,

    [switch]$RequireClean,

    [string]$RequireBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$repoRoot = (& git -C $resolvedPath rev-parse --show-toplevel).Trim()
$currentBranch = (& git -C $resolvedPath rev-parse --abbrev-ref HEAD).Trim()
$currentSha = (& git -C $resolvedPath rev-parse --short HEAD).Trim()
$statusLines = & git -C $resolvedPath status --porcelain

$uncommittedCount = 0
if ($statusLines) {
    $uncommittedCount = ($statusLines | Where-Object { $_ -and $_.Trim() -ne '' }).Count
}

Write-Host "=== Git Status Check ==="
Write-Host "Repository : $repoRoot"
Write-Host "Branch     : $currentBranch"
Write-Host "Commit     : $currentSha"
Write-Host "Dirty Files: $uncommittedCount"

if ($RequireBranch -and ($currentBranch -ne $RequireBranch)) {
    Write-Error "Expected branch '$RequireBranch', but currently on '$currentBranch'."
    exit 1
}

if ($RequireClean -and ($uncommittedCount -gt 0)) {
    Write-Error "Working tree is dirty ($uncommittedCount changed files), but -RequireClean was specified."
    exit 1
}

Write-Host "Git check passed successfully."
exit 0

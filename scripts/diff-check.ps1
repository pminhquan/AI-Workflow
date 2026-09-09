<#
.SYNOPSIS
    Read-only diff inspection and modification boundary check.
.DESCRIPTION
    Inspects unstaged and staged changes, validates against an allowlist and forbidden patterns,
    without mutating git repository state.
.PARAMETER RepoPath
    The directory of the git repository to check. Defaults to current directory.
.PARAMETER Allowlist
    Optional list of permitted relative file paths or glob patterns.
.PARAMETER ForbiddenPatterns
    Optional list of prohibited relative file paths or glob patterns (e.g., secrets, credentials).
.PARAMETER MaxChangedFiles
    Optional maximum number of changed files allowed before flagging an error.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = (Get-Location).Path,

    [string[]]$Allowlist,

    [string[]]$ForbiddenPatterns = @('*.key', '*.pem', '*.pfx', '*.env', '*credential*', '*secret*'),

    [int]$MaxChangedFiles = 0
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

# 4. Get list of changed files from git status
$rawStatus = & git -C $resolvedPath status --porcelain
$changedFiles = @()

if ($rawStatus) {
    foreach ($line in $rawStatus) {
        if (-not $line -or $line.Length -lt 4) { continue }
        # Format is 'XY path' or 'XY orig -> dest'
        $filePath = $line.Substring(3).Trim()
        if ($filePath -match ' -> ') {
            $filePath = ($filePath -split ' -> ')[-1].Trim()
        }
        # Strip surrounding quotes if present
        $filePath = $filePath.Trim('"')
        $changedFiles += $filePath
    }
}

Write-Host "=== Diff Boundary Check ==="
Write-Host "Repository    : $resolvedPath"
Write-Host "Total Changes : $($changedFiles.Count) file(s)"

if ($changedFiles.Count -eq 0) {
    Write-Host "No changes detected in working tree."
    exit 0
}

# 5. Check MaxChangedFiles limit
if ($MaxChangedFiles -gt 0 -and $changedFiles.Count -gt $MaxChangedFiles) {
    Write-Error "Change count ($($changedFiles.Count)) exceeds maximum allowed limit ($MaxChangedFiles)."
    exit 1
}

# 6. Check ForbiddenPatterns
$forbiddenViolations = @()
foreach ($file in $changedFiles) {
    foreach ($pattern in $ForbiddenPatterns) {
        if ($file -like $pattern) {
            $forbiddenViolations += "$file (matches forbidden pattern: $pattern)"
        }
    }
}

if ($forbiddenViolations.Count -gt 0) {
    Write-Error ("Forbidden file pattern detected in diff:`n" + ($forbiddenViolations -join "`n"))
    exit 1
}

# 7. Check Allowlist if provided
if ($Allowlist -and $Allowlist.Count -gt 0) {
    $disallowedFiles = @()
    foreach ($file in $changedFiles) {
        # Normalize slashes for comparison
        $normalizedFile = $file -replace '\\', '/'
        $isAllowed = $false
        foreach ($allowed in $Allowlist) {
            $normalizedAllowed = $allowed.Trim() -replace '\\', '/'
            if ($normalizedFile -like $normalizedAllowed) {
                $isAllowed = $true
                break
            }
        }
        if (-not $isAllowed) {
            $disallowedFiles += $file
        }
    }

    if ($disallowedFiles.Count -gt 0) {
        Write-Error ("Files changed outside the defined ALLOWLIST:`n" + ($disallowedFiles -join "`n"))
        exit 1
    }
}

# 8. Display concise diff stat
Write-Host "`nChanged Files Summary:"
$changedFiles | ForEach-Object { Write-Host "  - $_" }

Write-Host "`nDiff Stat:"
& git -C $resolvedPath diff --stat
& git -C $resolvedPath diff --staged --stat

Write-Host "`nDiff check passed successfully."
exit 0

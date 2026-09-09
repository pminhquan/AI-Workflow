<#
.SYNOPSIS
    Read-only workflow integrity and repository health check.
.DESCRIPTION
    Validates framework structure, required folders and files, shortcut documentation,
    skill and agent integrity, broken file references, workflow components,
    and suspicious hardcoded external project paths without modifying repository state.
.PARAMETER RepoPath
    The directory of the repository to check. Defaults to current directory.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1. Verify and resolve repository root
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    Write-Error "Repository path does not exist or is not a directory: $RepoPath"
    exit 1
}

$resolvedPath = (Resolve-Path -LiteralPath $RepoPath).Path
$repoRoot = $resolvedPath

# Resolve repository root: if invoked from within scripts/ directory, navigate up to repo root
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot "core"))) {
    if ((Split-Path $repoRoot -Leaf) -eq 'scripts' -and (Test-Path -LiteralPath (Join-Path $repoRoot "..\core"))) {
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot "..")).Path
    }
}

$passes = [System.Collections.Generic.List[string]]::new()
$fails = [System.Collections.Generic.List[string]]::new()
$warns = [System.Collections.Generic.List[string]]::new()

# Check 1: Required folders
$requiredFolders = @('agents', 'skills', 'prompts', 'core', 'scripts')
$missingFolders = @()
foreach ($dir in $requiredFolders) {
    $targetDir = Join-Path $repoRoot $dir
    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        $missingFolders += $dir
    }
}
if ($missingFolders.Count -gt 0) {
    $fails.Add("Missing required folder(s): $($missingFolders -join ', ')")
} else {
    $passes.Add("Required folders present: $($requiredFolders -join ', ')")
}

# Check 2: Required files
$requiredFiles = @(
    'core/AGENT_RULES.md',
    'core/BRIDGE_POLICY.md',
    'core/GIT_POLICY.md',
    'core/TASK_TEMPLATE.md',
    'core/TASK_CLASSIFICATION.md',
    'core/QUICK_TASK_TEMPLATE.md',
    'prompts/shortcuts.md'
)
$missingFiles = @()
foreach ($file in $requiredFiles) {
    $norm = $file -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $targetFile = Join-Path $repoRoot $norm
    if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
        $missingFiles += $file
    }
}
if ($missingFiles.Count -gt 0) {
    $fails.Add("Missing required file(s): $($missingFiles -join ', ')")
} else {
    $passes.Add("Required files present: $($requiredFiles -join ', ')")
}

# Check 3: Shortcut names documented
$expectedShortcuts = @('/fix', '/feature', '/debug', '/audit', '/review', '/test', '/release', '/ui', '/db', '/security')
$shortcutsFile = Join-Path $repoRoot "prompts\shortcuts.md"
if (Test-Path -LiteralPath $shortcutsFile -PathType Leaf) {
    $scText = Get-Content -LiteralPath $shortcutsFile -Raw
    $missingShortcuts = @()
    foreach ($sc in $expectedShortcuts) {
        $scEsc = [regex]::Escape($sc)
        $pattern = '(\|\s*`?' + $scEsc + '`?\s*\||\b' + $scEsc + ')'
        if ($scText -notmatch [regex]::Escape($sc)) {
            $missingShortcuts += $sc
        }
    }
    if ($missingShortcuts.Count -gt 0) {
        $fails.Add("Undocumented shortcut name(s) in prompts/shortcuts.md: $($missingShortcuts -join ', ')")
    } else {
        $passes.Add("All shortcut names documented in prompts/shortcuts.md ($($expectedShortcuts -join ', '))")
    }
} else {
    $fails.Add("Cannot check shortcuts: prompts/shortcuts.md does not exist")
}

# Check 4: Every skill folder contains skill.md
$skillsDir = Join-Path $repoRoot "skills"
if (Test-Path -LiteralPath $skillsDir -PathType Container) {
    $skillDirs = Get-ChildItem -LiteralPath $skillsDir -Directory
    if ($skillDirs.Count -eq 0) {
        $fails.Add("No skill folders found in skills/")
    } else {
        $missingSkillMd = @()
        foreach ($sd in $skillDirs) {
            $skillMdPath = Join-Path $sd.FullName "skill.md"
            if (-not (Test-Path -LiteralPath $skillMdPath -PathType Leaf)) {
                $missingSkillMd += "$($sd.Name)/skill.md"
            }
        }
        if ($missingSkillMd.Count -gt 0) {
            $fails.Add("Missing skill.md in skill folder(s): $($missingSkillMd -join ', ')")
        } else {
            $passes.Add("Every skill folder contains skill.md ($($skillDirs.Count) verified: $(($skillDirs | ForEach-Object { $_.Name }) -join ', '))")
        }
    }
} else {
    $fails.Add("Skills folder missing: cannot verify skill.md")
}

# Check 5: Every agent markdown file exists
$agentsDir = Join-Path $repoRoot "agents"
$expectedAgents = @('architect.md', 'developer.md', 'reviewer.md', 'security.md', 'tester.md')
if (Test-Path -LiteralPath $agentsDir -PathType Container) {
    $missingAgents = @()
    foreach ($ag in $expectedAgents) {
        $agPath = Join-Path $agentsDir $ag
        if (-not (Test-Path -LiteralPath $agPath -PathType Leaf)) {
            $missingAgents += $ag
        }
    }
    $agentFiles = Get-ChildItem -LiteralPath $agentsDir -File
    $nonMd = @($agentFiles | Where-Object { $_.Extension -ne '.md' })
    if ($nonMd.Count -gt 0) {
        $fails.Add("Non-markdown file(s) found in agents/: $(($nonMd | ForEach-Object { $_.Name }) -join ', ')")
    }
    if ($missingAgents.Count -gt 0) {
        $fails.Add("Missing agent markdown file(s): $($missingAgents -join ', ')")
    } else {
        $passes.Add("Every agent markdown file exists ($($expectedAgents -join ', '))")
    }
} else {
    $fails.Add("Agents folder missing: cannot verify agent markdown files")
}

# Check 6: Broken file references
$brokenRefs = @()
$mdFiles = @()
$foundMd = Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter *.md -ErrorAction SilentlyContinue
if ($foundMd) {
    $mdFiles = @($foundMd | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch '[\\/]\.antigravity-bridge[\\/]'
    })
}

foreach ($mf in $mdFiles) {
    $fileText = Get-Content -LiteralPath $mf.FullName -Raw
    $fileDir = $mf.DirectoryName
    $relSource = $mf.FullName.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/'

    # Markdown links [label](target)
    $matches = [regex]::Matches($fileText, '\[[^\]]*\]\(([^)]+)\)')
    foreach ($m in $matches) {
        $rawTarget = $m.Groups[1].Value.Trim()
        if ($rawTarget -match '^(https?://|mailto:|#|ftp:)') { continue }
        $targetPath = ($rawTarget -split '[?#]')[0].Trim()
        if ([string]::IsNullOrWhiteSpace($targetPath)) { continue }

        $norm = $targetPath -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $cand1 = Join-Path $fileDir $norm
        $cand2 = Join-Path $repoRoot $norm

        if (-not (Test-Path -LiteralPath $cand1) -and -not (Test-Path -LiteralPath $cand2)) {
            $brokenRefs += "$relSource -> $rawTarget"
        }
    }

    # Explicit repository paths in backticks: `(core|agents|skills|prompts|scripts)/...`
    $btMatches = [regex]::Matches($fileText, '`((agents|skills|prompts|core|scripts)/[A-Za-z0-9_./-]+)`')
    foreach ($bm in $btMatches) {
        $btPath = $bm.Groups[1].Value
        if ($btPath -match '\.\.\.') { continue }
        $normBt = $btPath -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $c1 = Join-Path $repoRoot $normBt
        $c2 = Join-Path $fileDir $normBt
        if (-not (Test-Path -LiteralPath $c1) -and -not (Test-Path -LiteralPath $c2)) {
            $brokenRefs += ($relSource + " -> '" + $btPath + "'")
        }
    }
}

if ($brokenRefs.Count -gt 0) {
    $fails.Add("Broken file reference(s) detected: $($brokenRefs -join '; ')")
} else {
    $passes.Add("No broken file references detected across documentation files")
}

# Check 7: Missing workflow components
$expectedComponents = @(
    'agents/architect.md',
    'agents/developer.md',
    'agents/reviewer.md',
    'agents/security.md',
    'agents/tester.md',
    'core/AGENT_RULES.md',
    'core/BRIDGE_POLICY.md',
    'core/GIT_POLICY.md',
    'core/PROJECT_CONTEXT_TEMPLATE.md',
    'core/QUICK_TASK_TEMPLATE.md',
    'core/TASK_CLASSIFICATION.md',
    'core/TASK_TEMPLATE.md',
    'core/TEST_POLICY.md',
    'prompts/audit.md',
    'prompts/debug.md',
    'prompts/implement.md',
    'prompts/release.md',
    'prompts/review.md',
    'prompts/shortcuts.md',
    'scripts/bridge-check.ps1',
    'scripts/diff-check.ps1',
    'scripts/git-check.ps1',
    'scripts/load-context.ps1',
    'scripts/release-check.ps1',
    'scripts/start-antigravity.ps1',
    'scripts/workflow-check.ps1',
    'skills/database/skill.md',
    'skills/frontend/skill.md',
    'skills/java-web/skill.md',
    'skills/python/skill.md',
    'skills/release/skill.md',
    'README.md'
)
$missingComponents = @()
foreach ($comp in $expectedComponents) {
    $normComp = $comp -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $targetPath = Join-Path $repoRoot $normComp
    if (-not (Test-Path -LiteralPath $targetPath)) {
        $missingComponents += $comp
    }
}
if ($missingComponents.Count -gt 0) {
    $fails.Add("Missing workflow component(s): $($missingComponents -join ', ')")
} else {
    $passes.Add("All workflow components present ($($expectedComponents.Count) components verified)")
}

# Check 8: Suspicious hardcoded external project paths
$candidateFiles = @()
$foundCandidates = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -ErrorAction SilentlyContinue
if ($foundCandidates) {
    $candidateFiles = @($foundCandidates | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/]\.antigravity-bridge[\\/]' -and
        $_.Name -ne 'workflow-check.ps1'
    })
}

$externalPathRegex = [regex]'(?<![A-Za-z0-9_])([A-Za-z]:[\\/][^\s`"''\)>\]]+|/(Users|home)/[^\s`"''\)>\]]+)'

foreach ($cf in $candidateFiles) {
    $relFile = $cf.FullName.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    $lines = Get-Content -LiteralPath $cf.FullName
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $match = $externalPathRegex.Match($line)
        if ($match.Success) {
            $matchedPath = $match.Value
            # Ignore generic placeholders, URL schemes, and Antigravity paths
            if ($line -notmatch 'https?://' -and $line -notmatch '(?i)antigravity' -and $matchedPath -notmatch '(?i)(/path/to|<path>|\[path\])') {
                $warns.Add("Suspicious hardcoded external project path in $relFile (line $($i + 1)): $matchedPath")
            }
        }
    }
}

# Check 9: Bridge scripts and recovery documentation
$bridgeScripts = @('scripts/start-antigravity.ps1', 'scripts/bridge-check.ps1')
$missingBridge = @()
foreach ($bs in $bridgeScripts) {
    $bsNorm = $bs -replace '/', [System.IO.Path]::DirectorySeparatorChar
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $bsNorm) -PathType Leaf)) {
        $missingBridge += $bs
    }
}
$bridgePolicyPath = Join-Path $repoRoot "core\BRIDGE_POLICY.md"
$hasPolicy = Test-Path -LiteralPath $bridgePolicyPath -PathType Leaf

$readmePath = Join-Path $repoRoot "README.md"
$hasRecoveryDoc = $false
if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $readmeContent = Get-Content -LiteralPath $readmePath -Raw
    if ($readmeContent -match '(?i)bridge recovery|fresh-codex-session|recovery steps') {
        $hasRecoveryDoc = $true
    }
}

if ($missingBridge.Count -gt 0) {
    $fails.Add("Missing bridge script(s): $($missingBridge -join ', ')")
} elseif (-not $hasPolicy) {
    $fails.Add("Missing core/BRIDGE_POLICY.md")
} elseif (-not $hasRecoveryDoc) {
    $fails.Add("Documentation in README.md does not reference bridge recovery")
} else {
    $passes.Add("Bridge scripts (start-antigravity.ps1, bridge-check.ps1), BRIDGE_POLICY.md, and recovery documentation verified")
}

# Output exactly four sections: PASS:, FAIL:, WARN:, NEXT:
Write-Output "PASS:"
if ($passes.Count -gt 0) {
    foreach ($p in $passes) {
        Write-Output "- $p"
    }
} else {
    Write-Output "None"
}

Write-Output "`nFAIL:"
if ($fails.Count -gt 0) {
    foreach ($f in $fails) {
        Write-Output "- $f"
    }
} else {
    Write-Output "None"
}

Write-Output "`nWARN:"
if ($warns.Count -gt 0) {
    foreach ($w in $warns) {
        Write-Output "- $w"
    }
} else {
    Write-Output "None"
}

Write-Output "`nNEXT:"
if ($fails.Count -gt 0) {
    Write-Output "Resolve the reported FAIL items before using the workflow."
    exit 1
} elseif ($warns.Count -gt 0) {
    Write-Output "Review warning items. Workflow repository structure is healthy and operational."
    exit 0
} else {
    Write-Output "Workflow repository structure is fully verified and healthy."
    exit 0
}

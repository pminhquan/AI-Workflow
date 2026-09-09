<#
.SYNOPSIS
    Lightweight, read-only project context loader.
.DESCRIPTION
    Inspects a target project directory to detect project identity, context file presence (.ai\CONTEXT.md),
    and suggest relevant framework skills based on top-level project indicators and context keywords.
    Strictly read-only; never mutates the target project or executes external commands.
.PARAMETER ProjectPath
    Path to the project directory to inspect.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1. Validate target project path
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Write-Warning "Path does not exist or is not a directory: $ProjectPath"
    exit 1
}

$resolvedPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$projectName = Split-Path -Path $resolvedPath -Leaf
$warnings = [System.Collections.Generic.List[string]]::new()

# 2. Inspect .ai\CONTEXT.md
$contextRelPath = Join-Path ".ai" "CONTEXT.md"
$contextFullPath = Join-Path $resolvedPath $contextRelPath
$contextStatus = "Missing"
$contextText = ""

if (Test-Path -LiteralPath $contextFullPath -PathType Leaf) {
    $contextStatus = "Found ($contextRelPath)"
    try {
        $contextText = [System.IO.File]::ReadAllText($contextFullPath)
    } catch {
        $warnings.Add("Unable to read $contextRelPath : $($_.Exception.Message)")
    }
} else {
    $warnings.Add("No $contextRelPath found in project. Consider copying core/PROJECT_CONTEXT_TEMPLATE.md to $contextRelPath.")
}

# 3. Lightweight top-level indicator inspection (Depth 0 only)
$topLevelNames = @()
try {
    $topItems = Get-ChildItem -LiteralPath $resolvedPath -Force -ErrorAction SilentlyContinue
    if ($topItems) {
        $topLevelNames = @($topItems | ForEach-Object { $_.Name.ToLowerInvariant() })
    }
} catch {
    $warnings.Add("Unable to inspect top-level directory entries: $($_.Exception.Message)")
}

# 4. Suggest applicable skills (strictly from existing workflow skills: java-web, python, database, frontend, release)
$suggestedSkills = [System.Collections.Generic.HashSet[string]]::new()

# Indicator patterns
$hasJava = ($topLevelNames | Where-Object { $_ -in @('pom.xml', 'build.gradle', 'build.gradle.kts', 'mvnw', 'gradlew') }) -or
           ($contextText -match '(?i)\b(java|spring|servlet|controller|maven|gradle)\b')

$hasPython = ($topLevelNames | Where-Object { $_ -in @('requirements.txt', 'pyproject.toml', 'setup.py', 'pipfile', 'poetry.lock', 'environment.yml') }) -or
             ($contextText -match '(?i)\b(python|django|fastapi|flask|pytest)\b')

$hasDatabase = ($topLevelNames | Where-Object { $_ -in @('migrations', 'schema.sql', 'db', 'database') }) -or
               ($contextText -match '(?i)\b(database|sql|postgres|mysql|sqlite|migration|orm|schema)\b')

$hasFrontend = ($topLevelNames | Where-Object { $_ -in @('package.json', 'tsconfig.json', 'webpack.config.js', 'index.html', 'vite.config.js', 'ui') }) -or
               ($contextText -match '(?i)\b(frontend|ui|react|vue|angular|css|html|component)\b')

$hasRelease = ($topLevelNames | Where-Object { $_ -in @('dockerfile', 'compose.yaml', 'docker-compose.yml', 'changelog.md') }) -or
              ($contextText -match '(?i)\b(release|deployment|production|staging|artifact|pipeline)\b')

if ($hasJava) { [void]$suggestedSkills.Add("java-web") }
if ($hasPython) { [void]$suggestedSkills.Add("python") }
if ($hasDatabase) { [void]$suggestedSkills.Add("database") }
if ($hasFrontend) { [void]$suggestedSkills.Add("frontend") }
if ($hasRelease) { [void]$suggestedSkills.Add("release") }

# Fallback skill if none detected but context was found
if ($suggestedSkills.Count -eq 0 -and $contextText.Length -gt 0) {
    [void]$suggestedSkills.Add("release")
}

$skillsDisplay = if ($suggestedSkills.Count -gt 0) {
    ($suggestedSkills | Sort-Object) -join ", "
} else {
    "None detected"
}

$warningsDisplay = if ($warnings.Count -gt 0) {
    $warnings -join "; "
} else {
    "None"
}

# 5. Output exactly labeled sections
Write-Output "PROJECT: $projectName"
Write-Output "CONTEXT: $contextStatus"
Write-Output "SKILLS: $skillsDisplay"
Write-Output "WARNINGS: $warningsDisplay"

exit 0

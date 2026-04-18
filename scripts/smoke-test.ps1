[CmdletBinding()]
param(
    [switch]$RunSkill,
    [string]$OutputDir = (Join-Path (Get-Location) 'test-output')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$skillRoot = Join-Path $repoRoot 'skills\photoshop-cutout'
$requiredPaths = @(
    (Join-Path $skillRoot 'SKILL.md'),
    (Join-Path $skillRoot 'agents\openai.yaml'),
    (Join-Path $skillRoot 'references\troubleshooting.md'),
    (Join-Path $skillRoot 'scripts\photoshop-cutout.ps1')
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required path: $path"
    }
}

$openAiYaml = Get-Content -LiteralPath (Join-Path $skillRoot 'agents\openai.yaml') -Raw
if ($openAiYaml -notmatch '\$photoshop-cutout') {
    throw 'agents/openai.yaml default_prompt must mention $photoshop-cutout.'
}

$scriptPath = Join-Path $skillRoot 'scripts\photoshop-cutout.ps1'
$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    $messages = ($parseErrors | ForEach-Object { $_.Message } | Sort-Object -Unique)
    throw ("PowerShell parse errors found in {0}: {1}" -f $scriptPath, ($messages -join '; '))
}

Write-Output 'structure_check=ok'

if ($RunSkill) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    & powershell -ExecutionPolicy Bypass -File $scriptPath -OutputDir $OutputDir -BaseName 'smoke'
}

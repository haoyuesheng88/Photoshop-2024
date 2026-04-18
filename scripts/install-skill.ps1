[CmdletBinding()]
param(
    [string]$CodexHome,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-TargetCodexHome {
    param(
        [string]$ExplicitCodexHome
    )

    if ($ExplicitCodexHome) {
        return $ExplicitCodexHome
    }

    if ($env:CODEX_HOME) {
        return $env:CODEX_HOME
    }

    return (Join-Path $HOME '.codex')
}

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$sourceSkillDir = Join-Path $repoRoot 'skills\photoshop-cutout'
$codexHomePath = Get-TargetCodexHome -ExplicitCodexHome $CodexHome
$targetSkillDir = Join-Path $codexHomePath 'skills\photoshop-cutout'

if (-not (Test-Path -LiteralPath $sourceSkillDir)) {
    throw "Source skill directory not found: $sourceSkillDir"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Path $targetSkillDir -Parent) | Out-Null

if ((Test-Path -LiteralPath $targetSkillDir) -and -not $Force) {
    throw "Target skill already exists: $targetSkillDir . Re-run with -Force to overwrite."
}

if (Test-Path -LiteralPath $targetSkillDir) {
    Remove-Item -LiteralPath $targetSkillDir -Recurse -Force
}

Copy-Item -LiteralPath $sourceSkillDir -Destination $targetSkillDir -Recurse -Force

Write-Output ("installed_skill={0}" -f $targetSkillDir)
Write-Output ("suggested_prompt=Use `$photoshop-cutout to connect to the already-open Photoshop window and cut out the active image.")

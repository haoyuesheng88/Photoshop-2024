# Photoshop-2024

Portable Codex skill packaging for Adobe Photoshop 2024 on Windows.

This repository packages one reusable skill:

- `skills/photoshop-cutout`

It is designed for the workflow where Photoshop is already open and Codex needs to connect to the active document, run a closed-loop cutout flow, place a refined layer back into the source document when possible, and export transparent plus white-background outputs.

## Repo Layout

```text
skills/photoshop-cutout/
  SKILL.md
  agents/openai.yaml
  references/troubleshooting.md
  scripts/photoshop-cutout.ps1
scripts/
  install-skill.ps1
  smoke-test.ps1
```

## Install On Another Computer

Clone the repository and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-skill.ps1
```

By default this installs the skill into:

- `$env:CODEX_HOME\skills\photoshop-cutout` when `CODEX_HOME` is set
- `$HOME\.codex\skills\photoshop-cutout` otherwise

## Use The Skill

After installation, ask Codex for something like:

- `Use $photoshop-cutout to connect to the already-open Photoshop window and cut out the active image.`
- `Use $photoshop-cutout to export transparent and white-background outputs from the active Photoshop document.`

You can also run the script directly from the repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\photoshop-cutout\scripts\photoshop-cutout.ps1
```

## Smoke Test

Structure-only validation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1
```

Optional runtime smoke test against an already-open Photoshop session:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test.ps1 -RunSkill
```

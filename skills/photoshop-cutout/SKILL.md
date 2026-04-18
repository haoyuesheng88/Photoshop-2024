---
name: photoshop-cutout
description: Use when Adobe Photoshop is already open on Windows and the user wants Codex to connect to the active Photoshop document, remove the background or cut out the subject, optionally place the refined result back into the source document, and export transparent plus white-background outputs.
---

# Photoshop Cutout

## Overview

This skill drives an already-open Photoshop session through COM automation. It is for live desktop workflows where Codex must work against the document the user already has open, not for offline image processing pipelines.

## Trigger Conditions

Use this skill when:

- Photoshop is already installed and running on Windows.
- The user wants Codex to connect to the currently open Photoshop document.
- The task is subject cutout, background removal, transparent PNG export, white-background export, or placing a refined cutout back into the source document.
- The user wants a closed-loop result with concrete output paths.

## Primary Workflow

1. Confirm Photoshop is open and the target image document is visible.
2. If multiple Photoshop documents are open, make the intended document active first. If needed, pass `-SourceDocumentName` to the script.
3. Run [scripts/photoshop-cutout.ps1](./scripts/photoshop-cutout.ps1).
4. Read back the script output:
   - `transparent_full` keeps the original canvas size.
   - `transparent_trim` trims transparent borders.
   - `white_jpg` and `white_png` are white-background exports.
   - `placed_back` reports whether the refined result is now represented in the source document.
   - `used_existing_cutout` reports whether the script had to fall back to an existing `Codex Cutout Refined` layer because Photoshop would not perform a fresh automatic subject selection.

## Direct Script Usage

Run the script directly when you want deterministic execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\photoshop-cutout\scripts\photoshop-cutout.ps1
```

Useful flags:

- `-OutputDir <path>` writes exports to a chosen folder. Default is `.\photoshop_cutout`.
- `-BaseName <name>` changes the output filename prefix.
- `-SourceDocumentName <name>` targets a specific open Photoshop document by name.
- `-PlacedLayerName <name>` changes the name of the layer placed back into the source document.
- `-ExistingLayerName <name>` changes the name used for fallback export from an already refined layer.
- `-SkipPlaceBack` exports files without placing the transparent result back into the source document.
- `-SkipWhiteExports` exports only transparent outputs.
- `-KeepPreviousCodexLayer` leaves an existing refined layer in the source document instead of replacing it.
- `-DisableExistingCutoutFallback` fails fast instead of reusing an existing refined layer.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\photoshop-cutout\scripts\photoshop-cutout.ps1 `
  -SourceDocumentName "Portrait.psd" `
  -OutputDir "C:\Exports\Photoshop" `
  -BaseName "portrait_a"
```

## Decision Notes

- Prefer the active document when it is clearly the user document.
- If Photoshop has helper or temporary documents open, the script prefers a non-helper document and then breaks same-name ties by choosing the document with more layers.
- If fresh automatic cutout fails but the source document already contains an `ExistingLayerName` layer, the script can still export usable transparent and white-background outputs from that layer.
- If the user asks for exact ID-photo sizes, run this skill first and then resize the exported white-background output in a separate follow-up step.

## Troubleshooting

Read [references/troubleshooting.md](./references/troubleshooting.md) when:

- Photoshop is open but no document is being found.
- Multiple documents are open and the wrong one is selected.
- `used_existing_cutout=true` appears in the output.
- Fresh subject selection is unavailable in the current Photoshop session.

## Resources

- `scripts/photoshop-cutout.ps1`: Main automation entry point.
- `references/troubleshooting.md`: Failure modes and recovery guidance.

# Troubleshooting

## No document found

- Make sure Photoshop is already open.
- Open the target image manually in Photoshop before invoking the skill.
- If Photoshop has only helper or temporary documents open, activate the real user document first.

## Wrong document selected

- Activate the intended Photoshop document before running the script.
- If several documents are open, pass `-SourceDocumentName <name>`.
- If two open documents share the same name, close the extra helper copy or rename the real one before running again.

## `used_existing_cutout=true`

This means Photoshop did not perform a fresh automatic subject selection in the current session, and the script fell back to exporting from an already existing refined layer.

Use that result when it is acceptable. If a fresh cutout is required:

- make sure the user document is active
- remove stale helper documents
- confirm the source still contains a normal image layer
- rerun after manual cleanup in Photoshop if needed

## Fresh subject selection fails

Possible causes:

- Photoshop is focused on the wrong document
- a helper or temporary document is active
- the current document state does not allow automatic subject selection

The safest recovery path is:

1. Close helper documents.
2. Activate the real user document.
3. Rerun the script.
4. If the document already contains a valid refined layer, allow fallback export.

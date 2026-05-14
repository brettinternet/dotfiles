# Fast Local Edits

Use this mode for small, low-ambiguity tasks.

## Scope

Best for single-file tweaks, obvious bug fixes, renames, config edits, and minor test updates.

## Workflow

1. Confirm scope and target file(s).
2. Make the smallest correct change.
3. Run the lightest meaningful verification.
4. Report results briefly.

## Rules

- Follow nearby patterns; do not redesign.
- Avoid scope creep unless required for correctness.
- If complexity grows, escalate to Smart/Deep.
- Never skip verification.

## Report Format

```md
## Done

- Changed: ...
- Files: ...
- Verified: ...
- Notes: ...
```

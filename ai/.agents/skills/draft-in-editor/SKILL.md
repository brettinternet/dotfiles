---
name: draft-in-editor
description: Hand a draft to the user's editor and use the saved file as the source of truth.
---

# Draft in Editor

Use this only for a non-empty draft the user is expected to review. It does not authorize sending, posting, or committing.

Put the draft under `$(git rev-parse --git-dir)/drafts/<slug>.md`, or a temporary directory outside a repository. Reuse the same path for the same artifact. Apply `user-voice` before writing externally directed text, print the draft in chat, and open it without waiting.

Always open the draft directly with `$HOME/.bin/context-editor --no-terminal <path>`. Run the CLI without waiting; do not use the workbench skill or tool. If `context-editor` fails, print the path and report the failure rather than falling back to another editor.

Stop after handoff. When the user later authorizes the external action, reread the file immediately beforehand and use its contents exactly. Do not reconcile it with the original draft or apply another writing pass. An empty file cancels the action; a missing file means it was discarded.

Treat routing markers such as `path:line` as metadata, never comment text. After the artifact is successfully sent, posted, or committed, move the draft to trash.

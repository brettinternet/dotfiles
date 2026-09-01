---
name: draft-in-editor
description: Hand a draft to the user's editor and use the saved file as the source of truth.
---

# Draft in Editor

Use this only for a non-empty draft the user is expected to review. It does not authorize sending, posting, or committing.

Put the draft under `$(git rev-parse --git-dir)/drafts/<slug>.md`, or a temporary directory outside a repository. Reuse the same path for the same artifact. Apply `user-voice` before writing externally directed text, print the draft in chat, and open it without waiting.

Prefer `$HOME/.bin/context-editor --no-terminal <path>`. If unavailable, use a non-blocking graphical `$VISUAL` or `$EDITOR`. Never launch a terminal editor or wait inside a tool call. If no safe editor is available, print the path.

Stop after handoff. When the user later authorizes the external action, reread the file immediately beforehand and use its contents exactly. Do not reconcile it with the original draft or apply another writing pass. An empty file cancels the action; a missing file means it was discarded.

Treat routing markers such as `path:line` as metadata, never comment text. After the artifact is successfully sent, posted, or committed, move the draft to trash.

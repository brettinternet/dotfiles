---
name: draft-in-editor
description: Hand a generated draft to the user's editor and treat the edited file as the source of truth. Use whenever a workflow produces a draft the user is expected to review or amend before it is sent, posted, or committed, such as a PR review, a comment, a commit message, or an issue body.
---

# Draft in Editor

Write the draft to a file, open it in the user's editor, and stop. When the workflow later acts on the draft, it reads that file back rather than the chat transcript. This skill controls draft handoff only and never grants permission to send, post, or commit.

## Path

Put the file inside the git directory so it is never staged, never committed, and never noise in `git status`.

```bash
path="$(git rev-parse --git-dir)/drafts/<slug>.md"
mkdir -p "$(dirname "$path")"
```

Use a `<slug>` that identifies the artifact, such as `pr-review-1234` or `commit-msg`. Outside a git repository, use `$(mktemp -d)/<slug>.md`. Reuse the same path when regenerating the same artifact rather than accumulating numbered copies.

## Handoff

Before writing an externally directed draft, apply the `user-voice` skill, including its `writer` routing. The destination workflow still owns content and structure, and anything the user edits afterward remains untouched.

Write the file, print the draft in chat as well, then open it without waiting.

```bash
editor="${VISUAL:-${EDITOR:-}}"
editor="${editor% --wait}"; editor="${editor% -w}"
nohup $editor "$path" >/dev/null 2>&1 &
```

Strip the wait flag and detach the process. `EDITOR` commonly carries `--wait` for git, but a tool call times out long before a real edit session ends, so waiting here just kills the editor mid-edit.

The Bash tool has no TTY, so a terminal editor such as `vim`, `nvim`, or `helix` will hang or corrupt the session. Check the editor's base command against that list first and skip the open when it matches. Skip it too when `VISUAL` and `EDITOR` are both unset. In either case print the path so the user can open it themselves.

After opening, stop and say the draft is in the editor and that the workflow will use the file as saved. Do not summarize the draft again, and do not ask whether it looks good.

## Reading it back

After the user authorizes sending, posting, or committing, read the file fresh in a new tool call. Construct the outbound body exclusively from the contents returned by that read—never from the original draft, the chat transcript, or memory. Do not rewrite, reconcile, or regenerate it. If the file cannot be read, do not act. The user may have rewritten, reordered, or deleted anything in it.

- Treat the file contents as final wording. Do not re-apply voice rules, re-run a finding bar, or reconcile it against what you originally drafted.
- An empty file, or one reduced to whitespace, means cancel. Say so and do nothing.
- If the file is missing, the user discarded it. Ask before regenerating.
- Treat any location marker used to route a comment, such as `path:line`, as metadata, never as part of the comment body. Try the exact location first, then a nearby valid location in the same file when the destination rejects it. If no suitable inline location exists, post the comment without location metadata. **MUST NOT** prepend, append, or otherwise copy the marker into the posted text.

Delete the file once the artifact is sent, posted, or committed.

## Rules

- **MUST** open the editor non-blocking and never wait on it inside a tool call.
- **MUST** re-read the file immediately before acting on the draft.
- **MUST NOT** open a terminal editor from a tool call.
- **MUST NOT** treat opening the editor as authorization to send, post, or commit.

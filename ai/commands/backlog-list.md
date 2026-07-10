---
description: List the next items to work on from the backlog
argument-hint: <backlog|remote-refs> [item-ids|titles|ranges|description]
---

List the all next open backlog items from `$ARGUMENTS`. Tell me the order in which I should complete these backlog items and if any can be parallelized. Only point to the work chunks as backlog items such as tickets or backlog files. Don't list an order more granular than the backlog items (e.g. don't list sequential subitems).

## Backlog storage policy

Derive storage behavior per resolved backlog source from repository context:

- a local markdown backlog file named in `$ARGUMENTS` is a writable backlog source
- a remote item makes an existing local backlog entry writable only when exactly one repo markdown file matches it structurally as a backlog — an item list or item headings carrying the item's ID — not merely any file that mentions the ID
- every other remote item is remote-only: never write repo backlog/spec/planning markdown for it

Never create new backlog/spec/planning markdown unless the repo already demonstrates that exact convention, such as existing snapshot or spec files matching remote item IDs. When in doubt, do not create files; write only to writable backlog sources. Moving or renaming an existing backlog file into the repo's archive location per repo convention is an edit to an existing source, not creation.

Remote backlog sources:

Remote backlog references, such as Linear project identifiers, issue IDs, or issue URLs, are discovery inputs only. Do not implement directly against a moving remote source.

Invoking this command with remote backlog references is the standing authorization to update those exact remote items' status through the first-party tool — mark an item done or merged when its work is integrated. It does not authorize editing remote item content, creating or deleting remote items, or touching items outside `$ARGUMENTS`.

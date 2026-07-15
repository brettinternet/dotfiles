# Loose Markdown

## Source and item mapping

Resolve an explicit existing Markdown path or one unambiguous caller-configured conventional path. Validate that it follows an established item, status, dependency, and checkpoint convention. This reference does not invent a generic Markdown backlog format.

- `Source.id`: canonical source-file identity
- `WorkRef.itemID`: stable ID defined by the source convention and qualified by `Source.id`
- dependencies/state/order: parsed only from the established convention
- provider version: SHA-256 of the exact current source bytes

All items in one file share a source-wide mutation boundary. Parse complete source content before selection; do not treat a heading mention or fuzzy title as an item ID.

## Worklease resource policy

Use the bundled Markdown key policy:

```python
from worklease.adapters import key

resource_key = key("markdown", source_path, item_id)
```

The returned resource is source-scoped, so every item in the same file contends on one claim. Build complete replacement content separately, retain the current SHA-256, and call the equivalent core guarded replacement with the matching source resource.

For that exact expected-hash file replacement, the durable provider is the file itself: the matching source claim, ownership validation, expected SHA-256, and atomic replacement may support `providerMutationFenced: true` for that one mutation. Direct edits, arbitrary commands, moves, or writes outside the guarded replacement remain unfenced and must not inherit that value.

## Authoritative operations

The Markdown file remains authoritative. A successful replacement receipt plus a post-write SHA-256/read verifies the checkpoint. Never store provider status or progress in the Worklease database.

Review and archive behavior exists only when the source convention defines durable markers or an archive location. If it does not, return `capability`; do not delete content, invent a completed section, or move the file as an implicit archive.

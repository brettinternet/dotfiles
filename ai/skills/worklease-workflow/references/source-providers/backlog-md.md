# Backlog.md

## Source and item mapping

Resolve an explicit Backlog.md project path or caller-configured project. Use supported Backlog.md operations for discovery and reads; do not parse or edit task Markdown files as a substitute for the provider interface.

- `Source.id`: stable canonical project identity supplied by the caller
- `WorkRef.itemID`: exact task ID, qualified by `Source.id`
- `WorkItem.dependencies`: task dependencies returned by Backlog.md, converted to source-qualified references
- terminal/blocked state: caller-declared mapping of the project's configured statuses and blockers
- order: provider ordinal/priority after dependency and explicit-source ordering

Source-only discovery enumerates the complete project. An explicit task selector does not authorize mutation of its dependency closure.

## Worklease resource policy

Use the bundled Backlog.md key policy after resolution:

```python
from worklease.adapters import key

resource_key = key("backlog-md", project_path, task_id)
```

This produces an item-scoped local key. Its local guarded-operation capability does not make a Backlog.md CLI, MCP, SDK, or remote write provider-fenced. Normalize direct provider mutations as `local-coordination` and set `providerMutationFenced: false` unless the provider operation itself returns conditional-write evidence.

## Authoritative operations

The caller supplies authorized Backlog.md reads and writes. Refresh the task and dependency state before mutation. Preserve fields outside the requested patch. A durable receipt is the resulting task ID plus provider state/version that can be read again from the project; a Worklease `exec` receipt or command exit status alone is insufficient.

Use Backlog.md's documented status, progress, review, document, and archive operations when authorized. If the installed interface cannot perform or verify a requested operation, return `capability`; never edit `docs/backlog/` records directly or maintain a writable local shadow.

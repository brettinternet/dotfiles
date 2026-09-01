---
description: Implement one complete requested change
argument-hint: <feature and acceptance criteria>
---

Implement `$ARGUMENTS` completely.

Preserve unrelated work and follow repository conventions. Inspect the affected code, callers, and tests before editing. Use an isolated worktree when it protects existing work or the repository workflow requires one.

Make the smallest coherent source change. Update required callers, tests, configuration, generated artifacts, and documentation. Remove paths made obsolete by the change rather than retaining compatibility shims without a requirement.

Exercise the changed behavior directly, then run the smallest relevant checks. Use independent review or verification when the change is materially risky or the repository requires it.

Commit when the request or repository workflow calls for it. Never infer permission to push or open a PR; those require explicit user authorization.

Report the changed behavior, verification performed, commit or integration result when applicable, and any exact blocker.

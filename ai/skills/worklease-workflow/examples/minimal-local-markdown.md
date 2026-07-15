# Example: Local Markdown Source Replacement

Use this shape when one established Markdown file is the authoritative provider and every item shares one source-wide mutation boundary.

## Composition

1. Resolve and validate the explicit source path.
2. Parse the complete established backlog format into source-qualified `WorkRef` and `WorkItem` values.
3. Select work through `worklease-workflow`; the Markdown adapter does not select.
4. Derive the source-scoped resource and acquire it through the Worklease CLI or `LeaseStore`.
5. Build complete candidate content without modifying the source.
6. Hash the exact current source and run the matching guarded replacement.
7. Re-read/hash the source as the durable checkpoint, then release.

```python
import hashlib
from pathlib import Path

from worklease import AcquireRequest, LeaseStore, MutationRequest, replace_file
from worklease.adapters import key

source = Path("docs/work.md").resolve()
candidate = Path(".tmp/work.md.candidate")
resource = key("markdown", str(source), "__source__").resource
store = LeaseStore()

acquired = store.acquire(
    AcquireRequest(
        resource=resource,
        claim_id=claim_id,
        agent_id=agent_id,
        session_id=session_id,
        owner_id=owner_id,
        work_key=work_key,
    )
)
claim = acquired["claim"]
expected_sha256 = hashlib.sha256(source.read_bytes()).hexdigest()

replacement = replace_file(
    store,
    MutationRequest(
        resource=resource,
        claim_id=claim["claimId"],
        token=claim["token"],
        revision=claim["revision"],
        operation_id=replace_operation_id,
    ),
    source,
    expected_sha256,
    candidate,
)
updated_claim = replacement["claim"]
```

Verify the resulting source bytes and provider checkpoint before calling release with `updated_claim` and a new release operation ID. The release reason records what was verified; it does not prove verification.

For this exact mutation, the provider is the local file and the guarded operation enforces both ownership and expected SHA-256 before atomic replacement. `providerMutationFenced: true` may describe this replacement only. Do not carry that value to direct edits, arbitrary commands, or file moves.

The variables representing IDs and candidate content are caller-owned inputs. Never print or persist `claim["token"]` outside claim mutations and the guarded replacement.

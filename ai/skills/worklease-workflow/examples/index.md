# Source Workflow Examples

Choose the example by mutation guarantee, not by provider name:

- [`minimal-local-markdown.md`](minimal-local-markdown.md) — exact local file replacement under a source claim and expected SHA-256
- [`remote-provider-local-coordination.md`](remote-provider-local-coordination.md) — same-host scheduling around an unfenced remote provider mutation
- [`provider-conditional-write.md`](provider-conditional-write.md) — provider mutation that atomically rejects a stale provider version

Every example inherits scheduling and claim-lifecycle rules from `worklease-workflow`. Provider credentials, authorized operations, source formats, and stable IDs remain caller-owned.

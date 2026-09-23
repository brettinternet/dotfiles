---
name: worklease
description: Coordinate explicitly requested concurrent work with Worklease.
---

# Worklease

Use this skill only when the user explicitly requests Worklease.

Run `worklease instructions safety` before acquiring or managing a claim and treat its output as authoritative. When running inside a repeated autonomous loop also run `worklease instructions loop` and follow its output. Do not load the loop instructions for ordinary one-shot work.

## Session selection

Choose one full, collision-resistant identifier for each independent worker or repeated loop. Never truncate an identifier or derive one from a prefix.

- When `PI_LOOP_RUN_ID` is non-empty, use its exact value as the contextual handle selector for the entire Pi loop. Pass `--session "$PI_LOOP_RUN_ID"` to every CLI lifecycle command, or set `WORKLEASE_SESSION_ID="$PI_LOOP_RUN_ID"` for that invocation. Pass the same exact value as `sessionId` to MCP `acquire`, then use the returned opaque `lease` for later MCP lifecycle calls. Never substitute `PI_SESSION_ID` while `PI_LOOP_RUN_ID` is available. If the loop's claim expires, reacquire the same item only after proving every delegated executor and command has stopped, confirming there is no active conflicting claim, and revalidating provider eligibility. Expiry alone is insufficient.
- Otherwise, use an existing non-empty `WORKLEASE_SESSION_ID`.
- For one-shot work, a full harness-provided session ID is suitable; in Pi, use `PI_SESSION_ID`.
- For a repeated workflow in another harness, use its stable workflow or loop ID, not an iteration, turn, or replacement-session ID. If none is available, create one full UUID before acquire and preserve it for the complete claim lifecycle.

A successful `verify` proves access to the selected private handle, not that the current worker created it. It does not establish checkout ownership or authorize discarding uncommitted changes. Do not adopt an existing claim based only on successful verification, matching agent identity, or a similar session label.

Use one shared Worklease authority and the same exact canonical resource for every contender. Keep provider state authoritative for eligibility and progress; a Worklease claim only coordinates callers using that authority and resource.

Acquire immediately after choosing an item, before reading its full intent, planning, delegation, or edits. Skip items already shown as claimed. On contention, do not wait: select the next ready item. Hold at most one claim while selecting. Before attempting to take over previously claimed work, inspect the authoritative claim state and lifecycle history and verify that the prior claim was released; expiration alone is not a release. If release cannot be verified, do not acquire the resource.

Maintain and revalidate ownership as directed by the live instructions, especially around long work and before durable writes. Persist provider-visible progress, release the claim when finished, and verify the release before reporting completion. Never expose private handles, credentials, or bearer tokens.

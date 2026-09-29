---
name: worklease
description: Coordinate explicitly requested concurrent work with Worklease.
---

# Worklease

Use this skill only when the user explicitly requests Worklease.

Run `worklease instructions safety` before acquiring or managing a claim and treat its output as authoritative. When running inside a repeated autonomous loop also run `worklease instructions loop` and follow its output. Do not load the loop instructions for ordinary one-shot work.

## Supervised runs

When `WORKLEASE_RUN_ID` is set, this process runs under `worklease run`, which already holds, renews, and on exit releases the claim for the handed-off item. Do not select another item, acquire, heartbeat, or release. Use the inherited `WORKLEASE_SESSION_ID` and `WORKLEASE_HANDLE` for `verify` and `checkpoint`, and before exiting write `{"outcome":"done|blocked|review|failed","summary":"..."}` to `$WORKLEASE_RUN_RESULT`.

## Session selection

Choose one full, collision-resistant identifier for each independent worker or repeated loop. Never truncate an identifier or derive one from a prefix.

- When `PI_LOOP_RUN_ID` is non-empty, use its exact value as the contextual handle selector for the entire Pi loop. Pass `--session "$PI_LOOP_RUN_ID"` to every CLI lifecycle command, or set `WORKLEASE_SESSION_ID="$PI_LOOP_RUN_ID"` for that invocation. Pass the same exact value as `sessionId` to MCP `acquire`, then use the returned opaque `lease` for later MCP lifecycle calls. Never substitute `PI_SESSION_ID` while `PI_LOOP_RUN_ID` is available. If the loop's claim expires, reacquire the same item only after proving every delegated executor and command has stopped, confirming there is no active conflicting claim, and revalidating provider eligibility. Expiry alone is insufficient.
- Otherwise, use an existing non-empty `WORKLEASE_SESSION_ID`.
- For one-shot work, a full harness-provided session ID is suitable; in Pi, use `PI_SESSION_ID`.
- For a repeated workflow in another harness, use its stable workflow or loop ID, not an iteration, turn, or replacement-session ID. If none is available, create one full UUID before acquire and preserve it for the complete claim lifecycle.

## Continuation and ownership evidence

A new turn, compacted context, or replacement session within the same loop is not itself a takeover. After acquisition, preserve a non-secret continuation record in durable loop state or a Worklease checkpoint: exact loop/worker ID, authority, claim ID, canonical resources, provider item, and acquisition evidence. When creating a worktree, also retain its creation receipt, canonical path, and branch. Keep a pointer to this record in the loop's continuation context; do not rely on the current transcript alone or copy private handles or tokens into it.

Before selecting new work on a later iteration, recover this record and check for the loop's existing claim. Use available history/recall and durable checkpoints before declaring acquisition evidence missing. When the evidence ties the claim to this exact loop, verify the exact claim and resources, refresh provider eligibility and progress, and continue without requesting a human handoff. Do not reacquire or release merely because the session ID changed. Account for any still-running delegated executors or commands before overlapping their work. Skip claimed items when selecting new work, not the loop's own verified continuation.

A successful `verify` alone proves access to the selected private handle, not who acquired it. A matching loop ID alone is also insufficient. If recovered evidence does not establish continuity, another worker may still be active, or the claim is expired/lost, follow the live recovery instructions rather than assuming ownership. Ask for a handoff only when the remaining ownership question genuinely requires human input.

Claim continuity and destructive checkout cleanup are separate permissions. Missing worktree-creation evidence blocks destructive cleanup, not otherwise authorized implementation under a verified continuing claim. Preserve unrelated changes and leave unverified worktrees in place; never infer cleanup authority from the claim.

Use one shared Worklease authority and the same exact canonical resource for every contender. Keep provider state authoritative for eligibility and progress; a Worklease claim only coordinates callers using that authority and resource.

For new work, acquire immediately after choosing an item, before reading its full intent, planning, delegation, or edits. Skip items already shown as claimed. On contention, do not wait: select the next ready item. Hold at most one claim while selecting. Before attempting to take over previously claimed work, inspect the authoritative claim state and lifecycle history and verify that the prior claim was released; expiration alone is not a release. If release cannot be verified, do not acquire the resource.

Maintain and revalidate ownership as directed by the live instructions, especially around long work and before durable writes. Persist provider-visible progress, release the claim when finished, and verify the release before reporting completion. Never expose private handles, credentials, or bearer tokens.

---
name: worklease
description: Coordinate explicitly requested concurrent work with Worklease.
---

# Worklease

Use this skill only when the user explicitly requests Worklease.

Run `worklease instructions safety` before acquiring or managing a claim and treat its output as authoritative. When running inside a repeated autonomous loop such as Pi `/loop` or a Ralph loop, also run `worklease instructions loop` and follow its output. Do not load the loop instructions for ordinary one-shot work.

Use one shared Worklease authority and the same exact canonical resource for every contender. Keep provider state authoritative for eligibility and progress; a Worklease claim only coordinates callers using that authority and resource.

Acquire before delegation or edits. On contention, wait or select other ready work. Before attempting to take over previously claimed work, inspect the authoritative claim state and lifecycle history and verify that the prior claim was released; expiration alone is not a release. If release cannot be verified, do not acquire the resource.

Maintain and revalidate ownership as directed by the live instructions, especially around long work and before durable writes. Persist provider-visible progress, release the claim when finished, and verify the release before reporting completion. Never expose private handles, credentials, or bearer tokens.

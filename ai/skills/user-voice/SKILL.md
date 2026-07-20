---
name: user-voice
description: Draft or revise external communication in the user's concise, direct, informal voice. Use whenever Codex is asked to write, draft, reply, post, or comment on the user's behalf, including posting comments for them without an explicit "as the user" instruction. This skill controls wording only and never grants permission to send or post.
---

# User Voice

Never infer permission to post, send, approve, request changes, resolve threads, or mutate remote state. The invoking workflow owns audience, message type, content threshold, and communication authority; its requirements override this skill.

Lead with the point. Write succinct, direct, informal, concrete text, usually one or two sentences for a short comment. Use lowercase with light punctuation where natural, but preserve correct capitalization for names, acronyms, identifiers, commands, code, and quoted text.

Do not use em dashes or semicolons. Avoid corporate polish, filler, hedging, canned praise, ceremonial openings, stacked requests, and unnecessary headers or bullets. Praise only when useful. State blockers plainly. Casual wording must never change the evidence, facts, certainty, severity, or requested action.

Prefer `done, also added coverage for the reopen path` over `Great catch! I've gone ahead and made the requested change.`

## Final Check

Before returning externally directed text:

1. Put the point first and remove anything uninformative.
1. Prioritize clarity, brevity, and directness over formality or polish.
1. Verify facts, certainty, severity, and requested action against the evidence.
1. Match the form to the intent; do not turn a status or explanation into a question unless an answer is needed.
1. Remove em dashes, semicolons, stacked requests, canned praise, and unnecessary formatting.
1. Preserve protected technical capitalization and exact quoted text.
1. Confirm the workflow permits sending or posting; otherwise return a draft only.
1. Don't point out obvious facts such as CI state, unless they are relevant to the request or action.

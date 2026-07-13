---
name: user-voice
description: Draft or revise external communication in the user's concise, direct, informal voice. Use when a command or user request explicitly says to write, draft, reply, or post as the user. This skill controls wording only and never grants permission to send or post.
---

# User Voice

This skill controls wording, not authority. It does not grant permission to post, send, approve, request changes, resolve threads, or mutate remote state. The invoking command owns the audience, message type, content threshold, and permission to communicate.

## Core voice

- Lead with the point.
- Be succinct, direct, informal, and concrete. One or two sentences beats a paragraph for a short comment.
- Use mostly lowercase and light punctuation where natural, while preserving the correct spelling and capitalization of names, acronyms, identifiers, commands, quoted text, and code.
- Do not use em dashes or semicolons.
- Avoid corporate polish, filler, hedging, canned praise, and ceremonial openings such as "Overall," "Great work!", "Nice catch!", or "Thanks for the review!".
- Do not add headers or bullet scaffolding to a short comment.
- Praise sparingly and only when it communicates something useful.
- State blockers plainly. Never soften or change facts, certainty, severity, or the requested action merely to sound casual.

The invoking workflow may require a specific message form, content threshold, or stricter tone. Those constraints override this skill.

## Examples

Representative only. Do not copy them mechanically.

Good:

- `done, also added coverage for the reopen path`
- `the deploy is green and the migration finished cleanly`
- `left this as-is because the retry is already idempotent. lmk if i'm missing a non-idempotent path`

Avoid:

- `Great catch! I've gone ahead and made the requested change.`
- `Overall, this looks great; however, I was wondering whether perhaps we should reconsider the retry strategy?`
- `Could you check the deploy, and should we also wait for the migration?`

## Final check

Before returning externally directed text:

1. Put the actual point first and delete any opener or sentence that adds no information.
2. Confirm certainty, severity, facts, and the requested action match the evidence.
3. Match the form to the actual intent. Do not turn a status or explanation into a question unless an answer is needed.
4. Remove em dashes, semicolons, stacked requests, canned praise, and unnecessary formatting.
5. Preserve technical names and exact quoted text.
6. Confirm the invoking workflow permits sending or posting. If it does not, return a draft only.

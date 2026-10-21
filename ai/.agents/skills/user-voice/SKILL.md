---
name: user-voice
description: Draft human-facing external communication in the user's concise, clear, direct, plain voice; exclude agent-to-agent prompts and messages.
---

# User Voice

This skill controls wording, not permission to send or post.
Apply this skill only when a human is an intended reader. Do not use it for prompts, comments, posts, or messages addressed solely to another agent or automated system, even when they are written on the user's behalf.

Write concise, clear, direct, plain language. Prefer familiar words and concrete statements. Include only the context needed to understand the point and act on it.

Lead with the point. Use short, natural sentences and mostly conventional grammar. Keep a short comment to one or two sentences, about 25 words by default. Go longer only when the reader could not act without the extra context. State concrete facts, uncertainty, and requested action without ceremonial openings, praise, corporate polish, or a closing summary. Be plain and direct but humble and sincere. Own the limits of what you checked instead of hedging every claim, and never be coy, sarcastic, or ask a leading question whose answer you already know. Do not restate what the reader can already see, such as their own code, diff, or message.

Write for a peer who knows the code better than you. Say what they need to know, not how you found it. Your verification stays with you; include at most the one fact or reference that lets them confirm the point quickly. When the reader can confirm a suspicion faster than you can, ask a plain question and give your reason in a short clause, such as `I think I only saw it in a closed PR.` That is sincere, not leading or hedging.

Use one message for one point. Anchor it with at most one or two technical references. Put technical tokens in backticks. Ask a direct question only when an answer is needed; otherwise state the requested action. Make one ask per message. Do not chain follow-ups such as `If so, can we ...`; post a second point separately or drop it.

Delete vague warnings such as “might be worth checking,” “just flagging,” “thoughts?”, and “could be a problem.” Name the concrete trigger or omit the sentence. State the consequence only when the reader would not see it right away. Never use em dashes. Never use `gate` or any of its tenses. Do not use a colon to introduce a prose explanation or elaboration. Write a complete sentence such as `The root cause is ...` instead of `Root cause: ...`. Avoid fake contrasts, press-release vocabulary, repeated conclusions, and inventories of identifiers.

Never reference commit hashes or SHAs; the reader can already see them. Use relative language that fits the sequence, such as `my last commit`, `the next commit`, or `I will do that`.

Prefer:

`Deleting the row leaves orders pointing at a missing customer. Should this cascade instead?`

over:

`Might be worth double checking the delete path here, could be a problem?`

Prefer:

``Does `session/heartbeat/` have a backend endpoint? I think I only saw it in a closed PR.``

over:

``This posts to `session/heartbeat/`, which only existed in smartcall#2484, and that was closed without merging. The open backend stack only routes `user/heartbeat/`, so every beat would 404 and no agent would be enrolled. It looks like #3247 already targets the new route. Is this PR superseded by that one? If so, can we close it?``

Before returning, remove each sentence in turn and keep it only if the reader would understand or act differently without it. Preserve exact quoted text and required format constraints.

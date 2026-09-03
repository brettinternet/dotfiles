---
name: user-voice
description: Draft external communication in the user's concise, direct, informal voice.
---

# User Voice

This skill controls wording, not permission to send or post.

Lead with the point. Use short, natural sentences and mostly conventional grammar. Keep a short comment to one or two sentences. State concrete facts, uncertainty, and requested action without ceremonial openings, praise, corporate polish, or a closing summary.

Use one message for one point. Anchor it with at most one or two technical references. Put technical tokens in backticks. Ask a direct question only when an answer is needed; otherwise state the requested action.

Delete vague warnings such as “might be worth checking,” “just flagging,” “thoughts?”, and “could be a problem.” Name the trigger and consequence or omit the sentence. Never use em dashes. Never use `gate` or any of its tenses. Avoid fake contrasts, press-release vocabulary, repeated conclusions, and inventories of identifiers.

Never reference commit hashes. Use relative language that fits the sequence, such as `my last commit`, `the next commit`, or `I will do that`.

Prefer:

`Deleting the row leaves orders pointing at a missing customer. Should this cascade instead?`

over:

`Might be worth double checking the delete path here, could be a problem?`

Before returning, cut anything that does not change what the reader understands or does. Preserve exact quoted text and required format constraints.

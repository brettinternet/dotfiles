---
name: user-voice
description: Draft or revise external communication in the user's concise, direct, informal voice. Use whenever you are asked to write, draft, reply, post, or comment on the user's behalf, including posting comments for them without an explicit "as the user" instruction. This skill controls wording only and never grants permission to send or post.
---

# User Voice

This skill controls wording only. Never assume permission to post, send, approve, request changes, or resolve threads, and never change remote state without permission. The workflow owns the audience, message type, content threshold, and communication authority, and its requirements override this skill.

## Writer routing

When the `writer` subagent is available and you are not that agent, delegate final wording to it before returning, writing, sending, or posting the message. Give it a compact brief with the audience, message type, purpose, evidence and facts, certainty and severity, exact identifiers or quoted text, required action, and workflow-owned format or content threshold. Do not prewrite prose merely for it to polish.

The caller retains content, factual, routing, and communication authority. Check that the returned wording preserves the brief, then use it verbatim. If it needs a factual or format correction, ask `writer` to revise it instead of rewriting it in the caller. Never route text through `writer` after the user has edited it. If the agent is unavailable or delegation fails, apply this skill directly.

## Voice

Lead with the point. Write clear, direct, informal text. Keep short comments to one or two sentences. Use contractions and vary sentence length instead of uniform blocks. Use mostly conventional grammar and punctuation, allowing lowercase when natural. Preserve capitalization for names, acronyms, identifiers, commands, code, and quoted text.
Use inline code backticks for technical tokens when they are referenced as such, including identifiers, file paths, commands, flags, configuration keys, and literal values. Do not wrap ordinary prose, whole sentences, or punctuation that is not part of the token.

Do not use em dashes, colons, or semicolons. Cut corporate polish, filler, hedging, canned praise, ceremonial openings, stacked requests, and any header or bullet the message does not need. State significant concerns plainly and keep the evidence, facts, certainty, severity, and requested action unchanged.

Prefer `Done. I also added coverage for the reopen path.` over `Great catch! I've made the requested change.`

## Structure

One message carries one point. State the point in the first sentence, then at most one supporting fact and at most one request. Put the location or identifier next to the thing it refers to instead of in a preamble. Never open with a sweeping statement about the state of anything or close with a summary or inspirational wrap-up.

## Questions

Do not use `Could` to frame a question. It reads as an indirect request that the recipient ought to act. Choose the question form that matches the actual unknown. Use `Should` for intended behavior, `Why` for rationale, `What` for an expected result or constraint, and `How` for mechanism. Other direct, earnest questions are appropriate when they fit. Never mechanically rewrite every question with `Should`. If an action is required rather than genuinely in question, state the requested action directly.

## AI tells

These vocabulary and phrasing patterns mark text as AI-written. Rewrite the sentence to state the concrete fact, or delete it.

- Marker words, especially in figurative use. `delve`, `dive into`, `navigate`, `landscape`, `realm`, `unpack`, `harness`, `leverage`, `foster`, `bolster`, `underscore`, `shed light on`, `pave the way`, `pivotal`, `groundbreaking`, `cutting-edge`, `transformative`, `game-changing`, `robust`, `seamless`, `comprehensive`, `holistic`, `multifaceted`, `vibrant`, `testament`
- Filler phrases. `In today's ... world`, `it's important to note`, `it's worth noting`, `when it comes to`, `at its core`, `at the end of the day`, `this is where X comes in`, `let's break it down`, `plays a crucial role`, `cannot be overstated`
- Fake-contrast constructions that mimic insight. `It's not just X, it's Y`, `Not only X but Y`, `This isn't about X. It's about Y.`, `No X. No Y. Just Z.`
- The `**Bold term**: explanation` bullet format.
- Saying the same point twice in different words.

## Be specific or drop it

Every request names its exact target and the exact action wanted. Every claim names the concrete thing that goes wrong. When you cannot name the target, the action, or the failure, delete the sentence. Do not keep it as a hedge, a caveat, a heads up, or a softer question.

Delete these outright rather than rewording them.

- `consider ...`, `might want to ...`, `you may want to look at ...`, `worth checking ...`
- `double check ...`, `are you sure ...`, `just to be safe ...`, `no strong opinion but ...`
- `could be a problem`, `might cause issues`, `feels off`, `seems fragile`
- `thoughts?`, `just flagging this`, `keep an eye on this`
- praise that isn't the point of the message, a summary of work the reader already did, and any sentence that can be deleted without changing what the reader does

“Deleting the row leaves `orders.customer_id` pointing at a missing customer. Should this cascade instead?” beats “Might be worth double checking the delete path here, could be a problem?”

## Final check

Before returning externally directed text, perform a dedicated revision pass for succinctness, directness, and clarity, then confirm each item.

1. The point is first and every uninformative sentence is gone.
2. Language is clear, direct, and succinct with mostly conventional grammar and punctuation.
3. Facts, certainty, severity, and the requested action match the evidence.
4. Every request names one target and one action, and anything vague was deleted rather than softened.
5. Form matches intent. A status or explanation is not phrased as a question unless an answer is needed.
6. Questions do not use `Could`, and their form matches the actual unknown rather than defaulting to `Should`. Required actions are stated directly.
7. No em dashes, colons, semicolons, stacked requests, canned praise, or unnecessary formatting.
8. No AI tells. Read it back and rewrite anything that sounds like a press release.
9. Technical tokens use inline code backticks where appropriate, without wrapping surrounding prose.
10. Protected technical capitalization and exact quoted text are preserved.
11. The workflow permits sending or posting. Otherwise return a draft only.

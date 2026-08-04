---
description: Post a chaotic joke review — emoji micro-comments on real diff lines plus a poem, approving when unblocked
argument-hint: <pr-number|url>
---

Review PR $ARGUMENTS using `gh pr view` and `gh pr diff`. First perform a real
review for blockers, then become an unsupervised haunted carnival. Produce:

- 6-18 inline 0-5 word comments on random changed lines of code. Every comment
  must contain 1-4 random emoji such as 🤣, 🤔, 🫠, 🫡, 🤠, 👽, 🤯, 😬, 🆗,
  💀, 😳, 🫦, 💔, 🥔, 🦷, 🪱, 🧌, 🧯, 🛒, or 🦀. Vary the energy wildly:
  ominous prophecy, panicked sports commentary, fake legal warning, feral
  praise, surreal accusation, or a noise no human should make. At least one
  comment must be ALL CAPS, one must be only emoji, and one must confidently
  mention an irrelevant animal.
- A short poem about the PR that rhymes badly, contains one stage direction,
  and ends with an abrupt technical verdict.

Collect every line-specific joke and submit them together as real file-line
comments in one final GitHub review API request, not as preliminary or
top-level comments that merely name a line. Use the actual file line numbers
from the diff and `side=RIGHT`. If there are fewer changed lines than requested
comments, use only the available changed lines. Do not explain the jokes,
repeat a joke format, or let coherence survive between adjacent comments.

Choose exactly one final review event: `APPROVE` with the poem and inline jokes
when there are no blockers; otherwise `COMMENT` with the poem, inline jokes,
and any non-line-specific concern. Never submit a preliminary `COMMENT` review
or a `REQUEST_CHANGES` review. Use a top-level body only when a concern cannot
be attached to a specific changed line.

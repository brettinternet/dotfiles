---
description: Post a chaotic joke review — emoji micro-comments on real diff lines plus a poem, approving when unblocked
argument-hint: <pr-number|url>
---

Review PR $ARGUMENTS using `gh pr view` and `gh pr diff`. Produce a chaotic review with:

- 1-8 inline 0-3 word comments on random changed lines of code, each with a random emoji such as 🤣, 🤔, 🫠, 🫡, 🤠, 👽, 🤯, 😬, 🆗, 💀, 😳, 🫦, 💔, or 🥔
- A short poem about the PR.

Collect every line-specific joke and submit them together as real file-line
comments in one final GitHub review API request, not as preliminary or
top-level comments that merely name a line. Use the actual file line numbers
from the diff and `side=RIGHT`. If there are fewer changed lines than requested
comments, use only the available changed lines. Keep comments short and weird.

Choose exactly one final review event: `APPROVE` with the poem and inline jokes
when there are no blockers; otherwise `COMMENT` with the poem, inline jokes,
and any non-line-specific concern. Never submit a preliminary `COMMENT` review
or a `REQUEST_CHANGES` review. Use a top-level body only when a concern cannot
be attached to a specific changed line.

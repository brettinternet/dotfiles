---
name: backlog-unblock
description: Resolve human decisions, missing inputs, stale blocker records, and decision-only tickets that prevent backlog work from advancing. Use when a user asks to unblock blocked work, answer or surface questions in backlog items, resolve blocker tickets, or persist decisions across loose Markdown, Backlog.md, Linear, GitHub Issues, or another supported provider.
---

# Backlog Unblock

Turn genuine blockers into durable decisions or precise remaining unblock conditions, then commit scoped local backlog changes. Resolve exactly the requested sources/items, prompt the human only for consequential input that evidence cannot supply, and write the resulting decision back to every affected backlog item so a future agent can proceed without chat context.

Apply `backlog-source-workflow` for source resolution, provider dispatch, dependency analysis, claims, and durable writes. Read its provider-neutral contract, the matching provider heading for each resolved kind, and its claim rules before any claim or mutation. This skill may mutate only:

- specification text needed to record a decision, rationale, constraints, and acceptance impact
- the exact question or blocker evidence resolved by that decision
- the provider's existing ready/unblocked state when all recorded blockers are resolved
- a decision-only item's terminal state when the recorded decision satisfies its entire definition of done
- the matching claim lifecycle and provider receipt/checkpoint metadata required by the shared workflow

Never implement production work, infer approval to change unrelated status, close an implementation ticket, create a writable shadow, or replace a defined incomplete prerequisite with a human blocker.

## Resolve scope and blockers

Preserve explicit source and selector order. A source-only request inspects the complete collection; selectors narrow mutation scope to the selected items, although dependency and dependent items may be read to understand impact. Never mutate an unselected dependency or dependent; report other affected items for a later explicitly authorized pass.

Build the dependency graph before classifying blockers. Distinguish:

- `decision/input`: a human must choose or supply consequential product, design, policy, ownership, credential, or external information
- `stale/answered`: authoritative evidence already resolves the recorded blocker
- `decision-only ticket`: the ticket exists solely to capture a decision that gates dependents
- `external action`: another person or system must act; a decision alone cannot complete it
- `dependency-gated`: a defined prerequisite is incomplete; this is `ready after <item>`, not blocked
- `active claim`: another worker owns progress; this is `WAIT`, not blocked
- `invalid blocker`: ordinary technical difficulty, missing-path investigation, test failure, or a routine reversible implementation choice

Refresh each candidate before prompting. Search the backlog, dependencies and dependents, repository instructions and history, product/design evidence, callsites, provider comments, and established patterns. Resolve stale, invalid, routine, or safely reversible choices from evidence and record the disposition without asking the user. Never silently reinterpret an explicit provider-authored requirement.

## Form decision packets

For each unresolved human decision, prepare one self-contained packet:

1. State the exact question and the behavior or work it blocks.
2. Summarize the strongest relevant evidence and constraints.
3. Offer two or three mutually exclusive viable options. Put the preferred option first, label it `(Recommended)`, and state its concrete consequence in one sentence. Include a free-form path when the prompt facility supplies one.
4. Explain the recommendation in one or two sentences, including the default's reversibility and main tradeoff.
5. Name the backlog items and acceptance criteria the answer will change.

Do not ask the user to perform repository investigation or choose among options that repository convention already decides. Combine duplicate questions that require the same decision, but preserve the mapping from one answer to every affected item. Ask no more than three questions in one prompt; use prioritized rounds when more remain.

Use the product's structured user-input prompt when available. Otherwise ask the same decision packets as concise numbered questions and stop the turn for answers. Do not mutate a question-dependent item before the human answers.

## Consult the oracle

Use at most one read-only oracle consultation per invocation, after evidence gathering and before prompting, only when a decision is consequential and hard to reverse, two viable interpretations remain materially different, blocker evidence may be stale, or the preferred recommendation depends on architecture, security, product, design, or ownership judgment. Batch all qualifying questions with their evidence, constraints, candidate options, reversibility, and affected items.

Treat oracle advice as advisory. Verify it against primary evidence, choose the preferred option in the active agent, and never expose an oracle transcript as a substitute for a clear recommendation. Routine, reversible, or user-authored choices do not require an oracle.

## Persist answers

After the human answers, treat the answer as authoritative product input within the stated scope. If it conflicts with a hard repository constraint or leaves mutually inconsistent selected items, explain the conflict and ask one targeted follow-up before mutation. Otherwise:

1. Preflight the exact specification, blocker, state, and optional decision-ticket completion operations for every affected selected item.
2. Acquire the strongest contract-supported claim, refresh the item and dependencies, and stop on stale scope, changed question, active ownership, or unavailable canonical mutation capability. Report coordination-only work as `LOCAL COORDINATION (UNFENCED)`.
3. Write a durable decision near the relevant requirement: the answer, date, rationale, constraints, rejected alternatives when useful, affected acceptance criteria, and evidence that it resolves the original question. Replace or mark the original question answered; do not merely append a chat-like comment when the provider supports specification updates.
4. Remove or resolve only blocker records whose objective unblock conditions the answer now satisfies. Preserve unrelated blockers. When no genuine blocker remains, use the provider's established ready/unblocked vocabulary; do not invent a new status or marker.
5. Complete a decision-only ticket only when the captured answer satisfies every acceptance criterion and no implementation or external action remains. Otherwise leave it open and rewrite its next action or remaining unblock condition precisely.
6. Refresh the provider state and affected dependency graph. Require the decision and state transition to be durably discoverable before releasing the claim. Retain provider and claim receipts.

For loose Markdown, preserve its existing syntax and use the fenced whole-source replacement path. For Backlog.md, use supported provider operations from the canonical control checkout and never edit task files directly. For GitHub, use `gh` only. For Linear, use authenticated first-party tooling and describe coordination-only writes accurately.

## Orchestration and completion

Keep source resolution, classification, recommendations, prompts, claims, authoritative writes, and synthesis in the active agent. Use bounded read-only exploration for materially independent evidence surfaces and one oracle only under the policy above. Subagents never prompt the user, mutate providers, manage claims, or decide final recommendations.

Before declaring an item unblocked, verify that every selected question has an answer or evidence-backed disposition; every answer is written into the specification rather than chat only; blocker and status changes are no broader than the resolved condition; decision-only completion is justified; dependents now see the expected terminal/ready state; and all claims, receipts, and provider refreshes succeeded.

Run applicable formatting and validation, then commit all scoped local backlog changes concisely. Include no unrelated dirty work, do not add a co-author, and do not push or open a pull request without explicit authority. Treat a required guarded Backlog.md provider-state commit as this commit and retain its hash; do not create a duplicate commit. When only remote items changed, report that there is nothing local to commit and never create a local shadow merely to produce one.

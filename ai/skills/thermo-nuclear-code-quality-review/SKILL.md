---
name: thermo-nuclear-code-quality-review
description: Run an extremely strict maintainability review for abstraction quality, giant files, and spaghetti-condition growth. Use for a thermo-nuclear code quality review, thermonuclear review, deep code quality audit, or especially harsh maintainability review.
disable-model-invocation: true
---

# Thermo-Nuclear Code Quality Review

Audit the current branch's changes for implementation quality, maintainability, abstraction quality, and codebase health. This review never grants permission to edit, commit, push, or post. Preserve behavior, but be ambitious about restructuring. Measure twice, cut once.

## Standard

Actively seek "code judo": use the existing architecture more effectively to make the implementation dramatically simpler, smaller, and more inevitable. Reframe the design so concepts, branches, helpers, modes, conditionals, or layers disappear. Prefer deleting complexity to rearranging it, and do not accept working code that leaves the design messier when a materially cleaner path is visible.

Review every meaningful change for:

- **Size and decomposition:** Treat a PR moving a file from below 1,000 lines to above 1,000 as a strong smell and presumptive blocker. Explicitly ask whether it should be decomposed first. Waive only for a compelling structural reason when the file remains clearly organized. Prefer focused helpers, components, or modules.
- **Spaghetti and branch growth:** Treat ad hoc conditionals, scattered feature checks, one-off booleans, nullable modes, temporary branches, and edge cases embedded in busy flows as design problems. Prefer a dedicated abstraction, pure helper, typed state model, dispatcher, policy, or module. Call out increased coupling, statefulness, and cognitive load even when tests pass.
- **Abstraction quality:** Prefer direct, boring code over brittle or magical mechanisms. Reject generic machinery that hides simple data assumptions, thin or identity wrappers, pass-through helpers, and refactors that only redistribute complexity. Extract or reuse helpers when they reduce concepts; eliminate indirection when they do not.
- **Types and boundaries:** Challenge unnecessary `any`, `unknown`, casts, optionality, nullable flags, ad hoc object shapes, and silent fallbacks that obscure invariants. Prefer explicit typed models and shared contracts. Keep logic in the package, service, module, or API layer that canonically owns the concept; flag feature leakage into shared paths, implementation leakage across APIs, bespoke duplicates, and missed reuse of canonical utilities.
- **Orchestration and state:** Flag independent work serialized without reason and related updates that can leave half-applied state. Prefer parallel execution when it also simplifies the flow and atomic updates when partial state harms reasoning. Do not substitute micro-optimization for structural judgment.

For each concern, identify the structural cost and propose the clearest concrete remedy: delete a layer, simplify the state model, change ownership, unify duplicate branches, extract a focused module, reuse the canonical helper, make a type boundary explicit, separate orchestration from business logic, parallelize independent work, or make updates atomic. Push for the larger simplification when it is plausible; do not settle for naming nits or a polished version of the same messy idea.

## Output

Report a small number of high-conviction, actionable findings rather than cosmetic noise. Prioritize structural regressions and missed code-judo opportunities, then spaghetti growth, boundary/type/abstraction defects, file-size concerns, modularity, and legibility. State the affected code, why it worsens maintainability, and the requested change. Be direct and demanding without being rude; do not soften a major problem into a mild suggestion.

## Approval Bar

Do not approve merely because behavior is correct. Require no clear structural regression, obvious missed dramatic simplification, unjustified file-size explosion, spaghetti growth, hacky or magical abstraction, unnecessary wrapper/cast/optionality churn, architecture-boundary leak, canonical-helper duplication, or missed obvious decomposition.

Treat a plausible simplification that deletes incidental complexity, a below-to-above-1,000-line crossing, tangled ad hoc branching, scattered feature checks in shared code, an unnecessary indirect or cast-heavy contract, or logic outside its clear canonical home as a blocker unless clearly justified. Leave explicit, actionable feedback until the bar is met.

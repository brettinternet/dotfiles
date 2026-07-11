# Pass Procedures

Read only the section selected by current source state.

## IMPLEMENT

Before editing:

1. Isolate work from unrelated user changes when the repository flow requires a worktree/subtree.
2. Read existing patterns, callsites, tests, migrations, and UI/API behavior needed by the selected task.
3. Settle shared interfaces before delegating disjoint work.
4. Confirm the selected task is a refined coherent outcome. Repair and commit clearly unrefined/oversized writable local task boundaries before coding; stop and invoke `backlog-refine` for remote-only sizing repairs.

Execute:

- Complete exactly the selected coherent task with real behavior, required callsites, and behavior-focused tests.
- Reuse canonical repository patterns and remove paths made obsolete by the change.
- Fix in-scope failures, fixtures, and outdated tests rather than recording them as blockers.
- Keep tests with the implementer that owns the behavior.
- Use an oracle only for one batched set of consequential, hard-to-reverse design questions or a genuine possible external blocker not resolved by repository evidence.

Finish:

1. Run the smallest targeted verification that proves the task.
2. Commit the coherent implementation. Record its task name, implementation commit, verification result, current `in-progress` or `review-pending` status, exact next task or `REVIEW`, and remaining acceptance criteria in the writable backlog item. When the implementation commit cannot be named in the same commit, immediately create one state-only commit naming it.
3. For a remote-only item, post the equivalent canonical `implemented:` comment. If write-back fails, do not claim the pass complete or substitute handoff state.
4. Hand off `IMPLEMENT` with the exact next task while any task remains; otherwise persist and hand off `REVIEW` with every accumulated implementation commit, changed file, criterion, and verification result. Never begin the next implementation task in this invocation.

## REVIEW

Apply the `implementation-review` skill to the complete accumulated item or safe batch. Never review only the last task or commit.

Before findings:

1. Establish intent from every item, issue/PR description, implementation commit, and relevant documentation.
2. Map the complete changed surface, callsites, data flows, tests, and shared interfaces.
3. Review directly unless the batch contains materially large independent subsystems. If delegation is warranted, use no more than two bounded `explore` workers and make each apply all relevant review lenses to its subsystem.

Review and fix:

- Verify every acceptance criterion and inspect correctness, security, performance, maintainability, and latent failure modes.
- Validate every candidate against current code and runtime/test evidence before treating it as a finding.
- Fix valid issues at the source in this pass, including required tests and fixtures. Do not suppress warnings or narrow tests.
- Keep fixes within scoped implementation and directly required callsites.
- Batch architectural drift or genuinely product-blocked findings into the pass's one oracle consultation.
- Make no code change when the accumulated implementation is already sound.

Finish:

1. Run targeted verification covering the complete reviewed/fixed behavior.
2. Commit review fixes once. Treat that verified commit as covered by this review pass.
3. Write one item-local `status: complete; remaining: none; reviewed:` marker per clean item naming its implementation commit set and review-fix commit, if any. Post it as a comment for a remote-only item; handoff-only markers are invalid.
4. Commit writable marker/completion state separately; this state-only commit does not invalidate the marker. If remote marker write-back fails, leave the item incomplete.
5. Integrate only after all tasks, criteria, verification, durable marker, and completion requirements are satisfied.

## BLOCKED

Use this state only after safe work, repository investigation, in-scope fixes, and one oracle consultation fail to produce a safe path.

- Complete and verify all unblocked acceptance criteria first.
- Do not mark the item complete.
- Write one exact durable `status: blocked; blocked:` marker with reason, tried path, concrete unblock condition, and remaining acceptance criteria. Commit it in a writable local item or post it as a remote-only item comment; do not substitute handoff state.
- Commit only coherent, useful work.
- Continue to the next eligible scoped item instead of repeatedly selecting the same valid blocker.
- If every remaining item has a valid blocker, report the human-required blocker queue with `NEXT CONTEXT REQUIRED`.

## ARCHIVE

Archive only writable local backlog sources and only according to an established repository convention. For each remote-only source, first post its required durable `status: complete; remaining: none` review marker, then apply the authorized done/merged transition through the first-party tool when supported. Failed marker write-back leaves `NEXT CONTEXT REQUIRED`; an unsupported workflow transition is reported separately. Never create archive/spec Markdown solely for remote state.

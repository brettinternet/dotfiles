# Fixture backlog

This tiny backlog is copied into `.local/fixture-rig/backlog.md` by
`assets/scripts/make-fixture-rig.sh`. Keep the task IDs stable so later workflow
checks can refer to them.

## FIX-DEP — Add a greeting check

Add a small check that confirms the fixture program prints the required greeting.

Acceptance criteria:

- [ ] `./check.sh` exits successfully.
- [ ] The check compares the complete output with `hello from fixture`.

## FIX-REVIEW — Improve the greeting output

Update the greeting program without changing its command-line interface.
Depends on: FIX-DEP

Acceptance criteria:

- [ ] `./hello.py` remains executable directly from the repository root.
- [ ] The output is exactly `hello from fixture` followed by one newline.
- [ ] `./check.sh` passes with no environment variables set.
- [ ] Keep the implementation in `hello.py`; do not replace it with a shell alias.

## FIX-INDEPENDENT — Document the fixture check

Add this exact HTML comment to `AGENTS.md`:

```markdown
<!-- Deterministic validation: run `./check.sh`; `./check.sh --fail` is an intentional failure mode for exercising review and repair paths. -->
```

Acceptance criteria:

- [ ] `AGENTS.md` contains that exact comment once.
- [ ] `./check.sh` still exits successfully.

## FIX-REPAIR — Exercise the bounded repair loop

Add the `REPAIR-READY` marker to `AGENTS.md` and leave the existing fixture
check behavior unchanged.

Review harness marker: `fixture:fail-once`.

Acceptance criteria:

- [ ] `AGENTS.md` contains exactly one `REPAIR-READY` marker.
- [ ] `./check.sh` still passes with no environment variables set.
- [ ] Keep the implementation in `AGENTS.md`; do not change `hello.py`.

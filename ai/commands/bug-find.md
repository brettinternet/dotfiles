---
description: Trace the bug described in $ARGUMENTS to its true root cause with evidence, then apply the fix only when it is small and unambiguous, otherwise hand off the diagnosis
argument-hint: <bug-description|failing-test|error|repro-steps|remote-ref> [files|suspected-area]
---

Find the true source of the bug described in `$ARGUMENTS`, prove it with evidence, and fix it only when the fix is small and unambiguous; otherwise stop and hand off a precise diagnosis. Preserve unrelated unstaged work, keep any change limited to the root cause, and make the continuation status unambiguous.

Treat `$ARGUMENTS` as the exact symptom to diagnose: a bug description, failing test, error message, stack trace, reproduction steps, or a remote reference (such as a Linear issue ID or URL) that reports the bug, plus any files or suspected area that scope the search. Do not diagnose unrelated behavior except where needed to trace the cause. Any files named in `$ARGUMENTS` are a scope hint for where to look first, not a limit — follow the cause wherever it leads. If `$ARGUMENTS` names an explicit file path that does not exist, check for nearby existing paths only in path-like locations (same directory, or same basename after a move/rename); auto-substitute only when exactly one candidate is unambiguous and clearly adjacent and report it, otherwise stop and report the missing path plus candidates.

## Remote sources

A remote reference (such as a Linear issue ID or URL) is read-only discovery input, not the thing you diagnose in place:

1. Resolve it with the available first-party tool for that system. For Linear, use the Linear MCP/tooling when available; if no authenticated tool is available, stop and report the missing integration.
2. Pull the reported symptom, reproduction steps, expected vs. actual behavior, and any linked context, and use that as the symptom to diagnose. Note any repro detail the remote item omits as information you still need.
3. Do not write status, comments, or results back to the remote item unless the repo's convention and available tooling support it and the user expects it; keep the diagnosis local and say the remote item is unchanged.

## Establish the failure first

1. Reproduce the reported behavior before theorizing. Identify the exact command, test, input, or state that triggers it and confirm you observe the same symptom.
2. If you cannot reproduce it, do not guess at a cause. Record what you tried, state the missing information or environment needed to reproduce, and treat that as the blocker.
3. Capture the observable facts: the failing output, error, stack trace, wrong value, or diverging state, and where each is first observed.

## Localize the root cause

1. Trace the symptom backward to the earliest point where state, control flow, or data first diverges from correct — the source, not the surface where it surfaces.
2. Read the relevant code, callsites, and data flow. Prefer evidence (logs, values, a bisected commit, a failing assertion) over speculation at every step.
3. Distinguish the root cause from its symptoms and from incidental code near the failure. Name the specific mechanism: the exact line, condition, invariant, ordering, boundary, type, permission, migration, or dependency behavior that is wrong.
4. Confirm the cause explains the full symptom. If part of the observed behavior is unexplained, keep tracing — a partial theory is not a root cause.

## Consult the oracle

- Before you build further investigation on a load-bearing assumption (about intended behavior, an invariant, ownership, or why code exists), consult the oracle agent to validate it. Record the assumption and the oracle's read.
- When you are stuck after repeated dead ends, when competing theories fit the evidence equally, or when you suspect the reproduction itself is wrong, consult the oracle agent for a second opinion on the diagnosis and the next thing to check.
- Before declaring the root cause unfindable or the bug human-required, consult the oracle agent. If it confirms or cannot resolve it, report it as a human-required blocker with the exact missing information.

## Fix policy

- Apply the fix only when it is small and unambiguous — a change at the identified source whose correctness is obvious from the diagnosis, with no material design choice.
- Otherwise make no code change. Output the diagnosis and hand off the fix, stating the recommended fix direction and why applying it needs a decision (design tradeoff, product input, broad blast radius, or unverified assumption).
- When you do fix: fix at the source, not by suppressing the symptom, narrowing a test, or adding a guard that hides the cause. Keep the change limited to the root cause and directly required callsites. Add or update a targeted test that fails without the fix and passes with it.
- Do not disturb unrelated unstaged or untracked work.

## Verify and finish

- When a fix was applied, run the smallest targeted check that proves it: the previously failing repro/test now passes, plus any directly affected tests, typecheck, or lint. Re-run after any follow-up change. Do not claim project-wide health unless project-wide checks were run.
- When a fix was applied, commit only the fix with a concise message, and integrate per the repo's flow — resolved from the repo's `CLAUDE.md`, `AGENTS.md`, or config (an `Integration: pull-request` or `Integration: local-merge` line), else auto-detected (no push access to the base branch, a protected base branch, or an `origin` you do not own implies `pull-request`), else `local-merge`. For `pull-request`, push the fix branch and open a PR with `gh`; invoking this command authorizes pushing this fix's own branch only and does not authorize force-pushing, merging, or touching unrelated branches.

Start the final report with exactly one status line:

- `ROOT CAUSE FIXED` — the root cause was identified, proven, fixed, and the fix verified. Then give the root cause and mechanism, the evidence, what changed, the verification run, and where the fix landed (local commit or PR URL).
- `DIAGNOSIS ONLY — FIX HANDED OFF` — the root cause was identified and proven but not fixed. Then give the root cause and mechanism, the supporting evidence, the exact recommended fix direction, and why it was not applied.
- `ROOT CAUSE NOT FOUND` — the source could not be established (including cannot-reproduce). Then give the best-supported theory, the evidence for and against it, what was ruled out, the oracle's read, and the exact missing information or decision needed to proceed.

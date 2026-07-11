# Backlog Loop Handoff

Start with exactly one status line:

```text
NEXT CONTEXT REQUIRED
```

or:

```text
BACKLOG COMPLETE AND ARCHIVED
```

Then provide:

```text
Sources: <ordered requested sources>
Resolved sources: <source -> pinned/local mapping>
Item/task or review batch: <exact identifiers and titles>
Pass completed: <IMPLEMENT | REVIEW | BLOCKED | ARCHIVE>
Commits: implementation=<sha(s) or none>; review-fix=<sha or none>; state=<sha or none>
Reviewed state: <exact implementation commit set plus review-fix, if applicable>
Changed/inspected files: <paths>
Verification: <exact command/scenario and result>
Acceptance completed: <criteria/tasks proven>
Review result: <findings/fixes or clean; marker written per item>
Three-month risk: <concrete mechanism and now/follow-up decision>
Integration: <local merge | PR URL | not yet eligible>
Archive/remote status: <location or transition/skipped reason>
Oracle: <not used | recommendation and accepted/rejected reason>
Unrelated state: <preserved dirty work or unrelated failures>
Remaining: <ordered tasks, criteria, unreviewed items, blockers, decisions>
Next state: <IMPLEMENT | REVIEW | BLOCKED | ARCHIVE>
Next target: <source, item, exact task or review batch>
Next invocation: <copy-pasteable command or skill invocation with scope>
```

Omit no field whose state affects continuation. Use `none` or `not applicable` rather than leaving ambiguity.

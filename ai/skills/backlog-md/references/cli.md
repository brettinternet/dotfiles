# Backlog.md CLI Reference

This is a compact operational reference for the Backlog.md CLI. It was checked against the upstream CLI reference on 2026-07-14: <https://github.com/MrLesk/Backlog.md/blob/main/CLI-INSTRUCTIONS.md>. The installed CLI remains authoritative; consult live help only when a documented command is rejected or a required capability is unclear.

## Setup and workflow guidance

```sh
backlog init "Project name"
backlog init
backlog config
backlog instructions overview
backlog instructions task-creation
backlog instructions task-execution
backlog instructions task-finalization
```

Use `bunx backlog.md <command>` only when the installed `backlog` executable is unavailable and one-off dependency execution is authorized. Do not use `npx backlog`; it can resolve a different package.

## Task operations

```sh
backlog task create "Outcome title"
backlog task create "Outcome title" --desc "Context and scope"
backlog task create "Outcome title" --plan "- [ ] T1 — ..."
backlog task create "Outcome title" --ac "AC1 — ..." --ac "AC2 — ..."
backlog task create "Outcome title" --dod "DOD1 — ..."
backlog task create "Outcome title" --dep task-1,task-2
backlog task create -p 14 "Child outcome"

backlog task list --plain
backlog task list --search "query" --limit 10 --plain
backlog task list -s "To Do" --plain
backlog task <id> --plain
backlog task edit <id> --plan "- [ ] T1 — ...
- [x] T2 — ..."
backlog task edit <id> --ac "AC1 — ..."
backlog task edit <id> --dod "DOD1 — ..."
backlog task edit <id> --append-notes "Progress evidence"
backlog task edit <id> --append-final-summary "Completion summary"
backlog task archive <id>
```

Use `--parent`/`-p`, `--dep`, labels, priority, status, and assignee only when they are authorized and improve scheduling or visibility. Assignment is not a claim.

## Native checkbox operations

```sh
backlog task edit <id> --check-ac 1
backlog task edit <id> --uncheck-ac 1
backlog task edit <id> --check-dod 1
backlog task edit <id> --uncheck-dod 1
```

The current CLI reference documents native AC and DoD check/uncheck flags, but no plan checkbox flag. For plan tasks, replace the complete plan field while preserving every stable task ID and checkbox state. Perform the operation through the selected claim path and reread the provider item afterward.

## Supporting operations

```sh
backlog search "query" --plain
backlog search --modified-file src/path.ts --plain
backlog milestone list --plain
backlog milestone add "Release name"
backlog board
backlog board export
backlog overview
backlog browser --no-open
backlog cleanup
```

## Safe command rules

- Prefer `--plain` for machine-readable output.
- For multiline values, repeat `--append-*` flags or pass literal newlines. Do not assume a quoted `\n` becomes a newline.
- Use single-quoted shell arguments for literal backticks; unescaped backticks can execute command substitution before Backlog.md sees them.
- Run provider reads and writes from the canonical Backlog.md control checkout.
- Run mutations through `backlog-claim exec ... -- backlog ...` when the selected claim mode supports it; never edit task files directly.
- After every mutation, reread the exact item and retain provider plus claim receipts.
- If a command fails because the CLI version differs, run the narrowest relevant `backlog <command> --help`, update the local reference only when the difference is stable and intentional, then retry under the existing claim rules.

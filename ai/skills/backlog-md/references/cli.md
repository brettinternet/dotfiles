# Backlog.md CLI reference

Prefer the installed CLI; use `bunx backlog.md` only when dependency execution is authorized.

```sh
backlog instructions overview
backlog instructions task-creation
backlog instructions task-execution
backlog instructions task-finalization

backlog task list --plain
backlog task list --search "query" --limit 10 --plain
backlog task <id> --plain

backlog task create "Outcome title" --desc "Context and scope"
backlog task create "Outcome title" --plan "- [ ] T1 — ..."
backlog task create "Outcome title" --ac "AC1 — ..." --dod "DOD1 — ..."
backlog task create "Child outcome" --parent <id> --dep <id>

backlog task edit <id> --plan "- [x] T1 — ..."
backlog task edit <id> --append-notes "Progress evidence"
backlog task edit <id> --append-final-summary "Completion summary"
backlog task edit <id> --check-ac 1
backlog task edit <id> --uncheck-ac 1
backlog task edit <id> --check-dod 1
backlog task edit <id> --uncheck-dod 1
backlog task archive <id>

backlog search "query" --plain
backlog milestone list --plain
backlog overview
```

Use literal newlines for multiline fields; do not assume `\n` is converted. Quote shell metacharacters such as backticks. The CLI has no plan-checkbox command, so replace the complete plan while preserving every task and checkbox. Use narrow `backlog <command> --help` when this map does not cover an installed-version difference.

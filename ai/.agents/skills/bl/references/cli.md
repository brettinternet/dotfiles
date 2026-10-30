# bl CLI reference

Every command accepts `--json` (`-j`) and `-C DIR`. IDs accept shorthand (`12`, `BL-12`) or `source:ID` when ambiguous.

```sh
bl instructions workflow   # also: overview, query, format, json
bl config show --json
bl doctor --json

bl ls 'is:open label:cli' --json
bl show ID --json
bl show ID --section criteria --json
bl next --explain --json

bl next --claim --start --session S --json
bl claim ID --session S --json
bl heartbeat --session S --json
bl release ID --session S --json
bl done ID --session S --if-version V --json
printf '%s\n' 'What I did. Next: ...' | bl handoff ID - --session S --json
bl history ID --json

bl new 'Outcome title !high #label <BL-7 ^BL-1 ~m-1' --ac 'AC text' --json
printf '%s\n' 'Context and scope' | bl new 'Outcome title' --body - --json
bl set ID priority=high label+=bug blocked_by+=BL-7 assignees=@me --if-version V --json
bl note ID 'Progress evidence' --if-version V --json
bl ac ID check 1 --evidence 'cmd: result' --if-version V --json
bl ac ID uncheck 1 --if-version V --json
bl ac ID add 'New criterion' --json
bl ac ID rm 2 --if-version V --json
bl archive ID --json
```

Quick-add tokens: `!` priority, `#` label, `@` assignee, `^` parent, `<` blocked by, `~` milestone, `:` type.

Plan, DoD, and summary have no field flags; update them with `EDITOR` set to a non-interactive command and `bl edit ID --section plan|dod|summary|description|notes --json` (exit 4 means someone saved first). Pipe multiline text through `-` instead of relying on `\n` escapes.

Exit codes: 2 usage or `session-required`, 3 not found, 4 stale version or `claim-held`, 5 rejected or invalid config, 6 unavailable or `unknown-outcome`, 7 contention.

Use `bl COMMAND --help` when this map does not cover the installed version.

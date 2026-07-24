# GC-18 validation

**Scope/date:** Final acceptance sweep for the installed Gas City 1.3.5 city,
Beads 1.1.0, sidecar, and Dolt (2.2.0 initially; 2.2.2 on the final doctor),
observed 2026-07-23/24. Every command
and result below was observed during this sweep; this record does not add
outputs that were not observed.

**Clean-pass preflight:** The first happy-demo attempt found stale fixture import
`fx-3ndj`, which was deleted. A later attempt timed out because prior GC-15
fixture workflow `fx-bjbu` remained ready on intake; `gc convoy delete fx-bjbu
--force` closed that nine-bead graph. Another otherwise passing happy run failed
only its session-cleanup guard because the selected verifier session still owned
prior GC-13 root `fx-s9yu`. An active-root audit also found historical roots
`fx-y10` and GC-06 recovery root `fx-m2l`; root-oriented `gc convoy delete ROOT
--force` closed all three, after which the audit returned `[]`. These are stale-
fixture recovery actions, not success evidence. The final runs below began with
no open or in-progress fixture workflow roots.

## Acceptance results

### Doctor

```sh
cd ai/gascity && mise exec -- gc doctor --json
```

Observed final result: `ok=true`, `passed=78`, `failed=0`, and
`blocking_failed=0`. An immediately preceding probe found the fixture
`beads-health`, `gate-sweep`, and `order-tracking-sweep` schedules stale; running
those three supported orders reconciled the runtime state before this final
probe. Remaining warnings were machine/runtime advisories: a local-only JSONL
archive, an inactive legacy split store, order-tracking retention, and the
3.46-GB hq Noms store approaching its warning threshold. No doctor error
remained unexplained; the warnings are not treated as errors.

### OMP worker and supported session evidence

```sh
mise exec -- gc --city ai/gascity --rig fixture session list --state all --json |
  jq '[.sessions[] |
    select((.id // .session_id // "") == "gc-wisp-woxg0t") |
    {id:(.id // .session_id),provider,template,state,closed}]'
mise exec -- gc --city ai/gascity --rig fixture session peek gc-wisp-woxg0t --json --lines 1
```

Observed while workflow `fx-hxwb` was active: the supported Gas City session
record had `id=gc-wisp-woxg0t`, `provider=omp`,
`template=fixture/gc.intake`, `state=active`, and `closed=false`. `gc session
peek` returned `ok=true`, `line_count=25`, with worker output about durable
artifact and `gc.output_json` requirements. This is supported `gc session
list`/`peek` evidence. Native OMP transcript paths were not used, and this
validation does not claim that `gc session logs` resolves OMP transcripts.

### Triple import, complete fixture workflow, and separate contexts

```sh
task gascity:demo:reset
task gascity:demo
```

Observed exit `0`. The first import created `fix-independent` as bead `fx-n71h`;
the second import reused that bead; the mid-flow third import also reused the
same bead. The workflow dispatched root `fx-h58b`, verified durable artifacts
under `.local/fixture-rig/.gascity/work/fx-h58b`, passed explicit write-back, and
finished the bounded doctor gate clean after one retry. The root closed with
`gc.outcome=pass`.

The persisted selected sessions were intake `gc-wisp-ynw6cu`, planner
`gc-wisp-1ua2m4`, implementer `gc-wisp-wsj0wk`, verifier `gc-wisp-60vg84`, and
reviewer `gc-wisp-3uehfe`. Implementer and reviewer IDs were distinct, providing
the observed separate implementation/review session evidence. The architecture
contract keeps reviewer input bounded to the current plan, acceptance criteria,
diff, and latest report rather than prior provider transcripts.

### Failed review, fresh repair context, and configured halt

The initial failed attempts are recorded explicitly and are not claimed as
passes:

```sh
task gascity:demo:repair
```

Observed in the initial attempt: root `fx-xwd2` assigned attempts 1 and 2 to
the same session `gc__implementer-gc-u60htd`, exposing the Gas City v1.3.5
reuse race. Moving outer polling retirement earlier still failed on root
`fx-gvnf`: event order showed attempt 1 closed and attempt 2 emitted 22 seconds
later, before the outer poll reached the session. The repair guarantee was
therefore moved to the review-check boundary: `assets/scripts/review-check.sh`
synchronously retires the exact completed implementer session on a failed
non-final review before returning nonzero to the formula loop.
This post-hardening diagnostic is distinct from the earlier successful
pre-hardening repair run and is non-success evidence: root `fx-a4lo`
used compiled control `fx-oco8`, whose metadata was `gc.kind=ralph`,
`gc.step_id=implement`, `gc.max_attempts=2`, and `gc.partial_retry=false`.
The finalizer reached its active-work guard, but that guard counted bookkeeping
root metadata as active work and did not retire the implementer session. Both
attempts therefore reused `gc__implementer-gc-vw5fxo`, and the demo failed its
distinct-session assertion. The guard then excluded bookkeeping kinds from its
active-work count. This run remains diagnostic evidence, not a pass; the final
rerun is recorded only in the later verification below.

Final repair verification:

```sh
task gascity:demo:reset
task gascity:demo:repair
```

Observed exit `0`. Root `fx-l0hh` and bead `fx-pkhz` completed with distinct
attempts: attempt 1 `fx-30c1` used session `gc__implementer-gc-1wt7cm`, and
attempt 2 `fx-92oh` used session `gc-wisp-32eghs`. Attempt 1 failed
intentionally, attempt 2 passed, durable artifacts and explicit write-back
passed, and the bounded doctor gate finished clean.
Latest post-hardening repair-race diagnostic (not a pass):

The subsequent run used root `fx-9r84`; attempt bead `fx-v802` (attempt 1)
and attempt bead `fx-yvwo` (attempt 2) both ran under the canonical session
`gc__implementer-gc-w16gif`. The workflow itself closed with `gc.outcome=pass`,
but the demo rejected the reused canonical session, so this run is a
diagnostic failure rather than repair-race success. After the failed review,
the close/reset request left `continuation_reset_pending=true`; the next
attempt was emitted and adopted before `gc__implementer-gc-w16gif` had reached
terminal retirement. Immediate `gc session close --json` success was therefore
insufficient to prove that the session was unavailable for the next iteration.

The correction requires exact identity equality when resolving and polling the
implementer session. The only permitted normalization strips one leading `s-`;
identifier suffixes, alternate IDs, and other heuristics are not matches. The
formula check timeout is `15m`, while the script starts a hard internal
deadline of `840s` at entry, so repository/root resolution and input assembly
also consume the bounded budget. The workflow artifact root comes directly from
`GC_ROOT_BEAD_ID`, or from the root-ID basename exported in `GC_MOLECULE_DIR`,
without a normal-path Beads lookup. Primary reviewer attempts are individually
bounded. The OMP fallback has its own 180-second bound and cannot run past 360
seconds before the internal deadline, reserving the maximum 300-second
retirement plus the 60-second abort window. For a non-final failed check, the
retirement command/poll deadline starts before the first `gc session list` or
`gc session close` invocation and reserves at least 60 seconds of the internal
budget for the fail-closed root-abort helper. The compiled-control lookup ends
before the maximum retirement-plus-abort window; the current-root active-work
audit, `gc session list`, and `gc session close` are TERM/KILL bounded by the
remaining retirement time. The exhaustion write ends before the abort window,
and each abort helper `gc bd update`, `gc convoy delete`, and `gc bd show` is
TERM/KILL bounded by the remaining internal deadline. These bounds use a Bash
deadline wrapper and do not assume that GNU `timeout` is installed. It polls
`gc session list --state all --json` for that exact identity until the session
is missing or observably terminal before the failed check returns nonzero.
Retirement-proof or finalizer-control-write failure is not a retry: it records
`gc.outcome=fail` and
`gc.failure_class=review_session_retirement_unverified` with root, attempt, and
session diagnostics, runs the supported root-oriented
`gc convoy delete ROOT --force`, and re-reads root status to confirm terminal
closure. After confirmed closure, the check exits zero solely to suppress
Ralph's retry signal; the durable root outcome remains `fail`. If closure cannot
be confirmed, it exits 2 with the combined diagnostic.

Abort-path smoke runs are diagnostic, not success evidence. Root `fx-p13e` hit a
malformed attempt-selector jq program, recorded
`gc.failure_class=review_session_retirement_unverified`, and force-closed with
`gc.outcome=fail`. Because that version then exited nonzero, the in-flight Ralph
loop still materialized attempt 2 despite the closed root. Follow-up roots
`fx-ixkn` and `fx-5720` each force-closed with one attempt after exact-session
resolution failed; their confirmed-closure exit zero suppressed attempt 2. Root
`fx-wmxq` then exposed that `GC_MOLECULE_DIR` names Gas City's molecule
directory, not the rig artifact directory: both checks failed before review and
reused one session. Root resolution now uses `GC_ROOT_BEAD_ID`, or the molecule
directory's root-ID basename, to address `.gascity/work/ROOT`. The embedded jq
programs were compile-checked, and an already missing or closed exact session
became successful retirement proof only after the current-root active-work audit
passes. Later root `fx-0o9r` exercised the current distinct-session path and
closed with `gc.outcome=pass`, but the demo rejected a finalizer-authored
reference to nonexistent bead `fx-5b1j`; this model-output integrity failure is
also diagnostic, not a pass. The final verification below exercises the normal
path with valid final artifacts.

Final post-hardening repair verification:

```sh
task gascity:demo:reset
task gascity:demo:repair
```

Observed exit `0`. Root `fx-mcqr` closed with `gc.outcome=pass`. Attempt 1 bead
`fx-vqw4` used canonical session `gc__implementer-gc-2gz9ur`; exact-session
retirement completed before attempt 2 bead `fx-qjv6` was emitted into fresh
one-shot session `gc-wisp-dcifxgb`. This run exercised the current entry-to-exit
Bash deadline, bounded preflight/input/artifact/control/active-work/session
commands, then verified durable artifacts, explicit write-back, final-report
integrity, and a clean bounded doctor gate. This is the final repair-race PASS;
the earlier `fx-a4lo`, `fx-9r84`, `fx-p13e`, `fx-ixkn`, `fx-5720`, `fx-wmxq`,
and `fx-0o9r` runs remain diagnostic failures.

Configured exhaustion verification:

```sh
task gascity:demo:reset
task gascity:demo:halt
```

Observed exit `0` with the expected halt and no write-back. Root `fx-ric8`
closed with `gc.outcome=fail`, `gc.failure_class=review_attempts_exhausted`,
and `gc.exhausted_attempts=1`; compiled Ralph control `fx-basx` carried
`gc.max_attempts=1`, and its only attempt bead was `fx-pg99`. The script asserted
no attempt 2, no `verify.md`, retained failed `final.md`, `report.md`,
`review.md`, and `verdict.json` artifacts, and printed `expected halt after 1
review attempt(s)`.

### Reports and stop/start durability

The successful happy demo waited until the exact selected phase sessions were
missing or closed before validating reports. Required artifacts existed:
`brief.md`, `plan.md`, `verify.md`, `final.md`, and attempt-1 `report.md`,
`review.md`, and `verdict.json`.

Pre-stop SHA-256 values:

```text
brief.md   33c49c5a1ca060e43f0128ca64809ef4082f974320f9b9e96a9545aff897debd
plan.md    97756dac110474951addb75ac71d797c09d7d138601914158c31af6c2078cb7f
verify.md  7833157a544166747c804b8f8a9586fdf855af556004a0ca3c526026aa5d51c1
final.md   40430e82baeb7be2cee6230009dd906343df63d7117c7dfb116bc18366347869
report.md  951e14bb80bcde7a38380423155ee2a9cdaa513e3cdcde86383c1b20b863e234
review.md  4ad220156a74e4f3dd20f36842edbecea07fe355d5b66da5810f39e99af102cd
verdict.json 0f4e9c687abf78d360bd537b9119c0ad7340594164e346b6ebda19ce1a52716e
```

```sh
mise exec -- gc --city ai/gascity stop --json
mise exec -- gc --city ai/gascity start --json
```

Observed stop result: `ok=true`, `message="City stopped."`; all seven hashes
were identical while stopped. Observed start result: `ok=true`,
`message="City started under supervisor."`; all seven hashes remained
identical after restart.

### README commands, task inventory, and repository hygiene

```sh
task -l
```

Observed all public Gas City tasks: `demo`, `demo:repair`, `demo:halt`,
`demo:reset`, `doctor`, `up`, `down`, `status`, `init`, and sidecar `init`,
`serve`, and `test`.

The README reset/happy/repair/halt sequence reproduced after clean-queue
preparation:

```sh
task gascity:demo:reset
task gascity:demo
task gascity:demo:reset
task gascity:demo:repair
task gascity:demo:reset
task gascity:demo:halt
```

```sh
git ls-files ai/gascity
```

Observed no tracked `city.local.toml`, `city.sidecar.toml`, `.env`, `.gc`,
`.beads`, `.local`, or sidecar SQLite runtime.

```sh
mise exec -- gitleaks git --redact --verbose --no-banner
```

Observed 1,240 commits and approximately 2.98 MB scanned; no leaks found.

## Sidecar matrix

The matrix labels the evidence class. **Unit-suite evidence** exercises the
sidecar contract in its test suite. **Live evidence** exercises the independent
loopback service, Gas City, and the fixture workflow.

| Evidence class                 | Command or compact sequence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Observed result                                                                                                                                                                                                                                                                                 |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unit-suite                     | `task gascity:sidecar:test`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | `105 passed, 2 skipped in 4.14s`; covers pause/resume admission, drain safety, budget matrix, event replay/dedupe/crash recovery, Pushover environment disable, desired-state/cursor restart, and HTTP status/dispatch behavior.                                                                |
| Live: independent start/status | `./sidecar/launchd-run.sh`; `curl --request GET --fail http://127.0.0.1:8787/health`; `curl --request GET --fail http://127.0.0.1:8787/status`                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Started as a separate service (initial pid `59408`, restarted pid `79551`). `/health` returned `{"status":"ok","gc":"ok"}`. `/status` reported the controller running, health usable, and real Gas City data.                                                                                   |
| Live: sidecar absence          | Harness stopped sidecar while workflow `fx-hxwb` was in progress; `mise exec -- gc status --json`; `mise exec -- gc bd show fx-hxwb`; harness restarted only sidecar; `curl --request GET --fail http://127.0.0.1:8787/status`                                                                                                                                                                                                                                                                                                                                                                     | Direct Gas City status still returned `ok=true`, controller running, and health usable. `gc bd show fx-hxwb` remained `in_progress`. Restarting only the sidecar restored `/status`. Removing the sidecar did not stop or mutate Gas City.                                                      |
| Live: pause/resume admission   | `curl --request POST --fail http://127.0.0.1:8787/control/pause`; `curl --request POST --header 'content-type: application/json' --data-binary '{"bead_id":"fx-hxwb","external_source_ref":"validation:fx-hxwb","target":"fixture/gc.intake","provider":"omp"}' http://127.0.0.1:8787/workflows/dispatch`; `curl --request POST --fail http://127.0.0.1:8787/control/resume`                                                                                                                                                                                                                       | Pause set `paused=true` and warned that active sessions were unchanged. The dispatch probe returned HTTP `409 admission_refused`; the active root remained in progress. Resume restored `paused=false`.                                                                                         |
| Live: drain safety             | `curl --request POST --fail http://127.0.0.1:8787/control/drain`; `mise exec -- gc bd show fx-hxwb`; `curl --request POST --fail http://127.0.0.1:8787/control/resume`                                                                                                                                                                                                                                                                                                                                                                                                                             | Drain paused admission and warned `active sessions are unchanged`; direct root inspection showed the active run still in progress. Resume restored admission. Drain did not kill the active run.                                                                                                |
| Live: budget admission         | `curl --request PUT --fail --header 'content-type: application/json' --data-binary '{"mode":"critical"}' http://127.0.0.1:8787/control/codex-budget-mode`; `curl --request POST --header 'content-type: application/json' --data-binary '{"bead_id":"fx-hxwb","external_source_ref":"validation:fx-hxwb","target":"fixture/gc.intake","provider":"codex"}' http://127.0.0.1:8787/workflows/dispatch`; `curl --request PUT --fail --header 'content-type: application/json' --data-binary '{"mode":"normal"}' http://127.0.0.1:8787/control/codex-budget-mode`; `mise exec -- gc supervisor reload` | Critical mode changed policy immediately and the Codex dispatch probe returned HTTP `409 admission_refused`. Normal mode was restored. A reload-timeout warning was handled by restoring desired concurrency `2` and running `gc supervisor reload`, which reported `Reconciliation triggered`. |
| Live: restart state/cursor     | `curl --request GET --fail http://127.0.0.1:8787/status`; harness restarted sidecar; `curl --request GET --fail http://127.0.0.1:8787/status`; harness SQLite inspection of checkpoint/desired state                                                                                                                                                                                                                                                                                                                                                                                               | Before restart: `paused=false`, `concurrency=1`, `budget=normal`, cursor `170939`. After restart: policy was preserved and cursor advanced to `184892`, not reset. Later SQLite state showed checkpoint `205645` and desired state `paused=0`, `concurrency=2`, `budget=normal`.                |
| Live: replay dedupe            | Harness SQLite inspection of `notification_dedupe` row count, distinct notification keys, and pending notifications                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `52304` `notification_dedupe` rows and `52304` distinct notification keys; no duplicate persisted key; pending notifications were zero. Replayed events did not re-notify.                                                                                                                      |
| Live: Pushover                 | Independent sidecar logs with Pushover environment disabled                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Logs repeatedly showed `Pushover disabled; notification skipped for event` followed by concrete event IDs. Source uses only `PUSHOVER_APP_TOKEN` and `PUSHOVER_USER_KEY` environment variables.                                                                                                 |

## Closing summary

**Final architecture.** External Markdown remains the user-facing source and is
read-only for preview/import/dispatch; guarded explicit write-back is separate.
Beads/Dolt owns imported tasks, dependencies, workflow state, claims, and
outcomes. Gas City owns formula scheduling, phase execution, event sequencing,
and workflow closure under the supervisor. The sidecar owns admission, desired
state, budget policy, notifications, event-consumer bookkeeping, and the
Markdown adapter; it is not a second orchestrator. Each phase uses a fresh,
one-shot pool. An intentional non-final reviewer failure uses the synchronous
check-boundary finalizer, which reads the compiled Ralph control bead's literal
`gc.max_attempts`, not an independently supplied root variable. It resolves
the exact implementer identity with only leading `s-` normalization, proves
that session missing or terminal, and polls that state before returning the
retry status for another attempt. Retirement-proof or finalizer-control-write
failure instead records `gc.outcome=fail` and
`gc.failure_class=review_session_retirement_unverified`, force-closes with
`gc convoy delete ROOT --force`, and confirms the root terminal. It then exits
zero solely to suppress Ralph's retry signal while preserving the failed root;
unconfirmed closure exits 2 with diagnostics. Rig artifacts and Beads state
survive session termination and city stop/start.

**Exact tracked files created/changed expected for GC-18:**

- `ai/gascity/assets/scripts/review-check.sh`
- `ai/gascity/assets/scripts/gc11-demo.sh`
- `ai/gascity/formulas/backlog-item.toml`
- `ai/gascity/formulas/backlog-item-repair-1.toml`
- `ai/gascity/formulas/backlog-item-repair-3.toml`
- `ai/gascity/README.md`
- `ai/gascity/docs/validation.md` (new)
- `ai/gascity/docs/architecture.md` (small clarification)
- `ai/gascity/BACKLOG.md`
- `ai/gascity/Taskfile.yaml` (formatting-only)

**Exact demo commands:**

```sh
task gascity:demo:reset
task gascity:demo

task gascity:demo:reset
task gascity:demo:repair

task gascity:demo:reset
task gascity:demo:halt
```

**Current limitations:** Linear/Jira adapters are contract-only; sidecar
mutations are loopback-only and have no remote authentication; budget usage is
manual/provider policy rather than live Codex quota retrieval; notification
delivery remains local unless Pushover environment variables are set; the JSONL
archive is local-only; installed Gas City v1.3.5 can time out on reload/runtime
probes and produces scheduled-order warnings that bounded demo doctor recovery
reconciles; and native OMP transcripts still do not resolve through `gc session
logs`. GC-18 therefore uses supported OMP `gc session list`/`peek` evidence and
does not claim native transcript support.

**Next smallest real-repository integration step:** register the repository as a
rig, point the sidecar Markdown source at its `backlog.md`, preview, import one
item, and dispatch it with low concurrency.

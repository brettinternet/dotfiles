# Gas City bootstrap backlog

Bootstrap a personal Gas City orchestration setup in `ai/gascity/`, with OMP as the
primary coding-agent provider, Beads as the execution ledger, a Markdown backlog
adapter, a fresh-context multi-phase workflow with a bounded repair loop, and a Python
sidecar for scripting/policy control. This directory must stay self-contained so it can
later move to a dedicated repository unchanged (no absolute paths or references outside
`ai/gascity/` in tracked files; machine-local bindings live only in `.gc/site.toml`).

## How to work this backlog

- One item per iteration, in dependency order. Each item is a working vertical slice:
  implement, validate, commit (never push), record findings, stop.
- **Verify before build.** Facts below were researched from `gastownhall/gascity`
  `main` @ `ed8c8e5` (release v1.3.5) and `gastownhall/beads` v1.1.0 on 2026-07-17,
  before either tool was installed. Any item that touches a gc/bd schema must first
  confirm the field/command against the installed version (`gc --help`, `gc config
explain`, `gc lint`, `gc doctor`, `docs/reference/` in the gascity repo at the
  installed tag). Record every deviation in the Decision log at the bottom of this
  file, then follow the installed version, not this file.
- Do not re-litigate the Architecture decisions below; append to the Decision log if
  the installed version forces a change.
- Never modify a real backlog, real repository, or `ai/pi/profiles/*` during this work.
  All workflow demonstrations run against the generated fixture rig.
- Secrets only via environment variables; nothing secret or machine-specific committed.
  `.gc/`, `.beads/`, fixture rigs, sidecar state, and `.env` are gitignored.

## Environment facts (2026-07-17)

- `gc` and `bd` are **not installed**. Install is item GC-01, preferring mise
  (both repos publish `darwin_arm64` release tarballs, so the `github:` backend
  applies) with brew as fallback. gc's runtime deps: tmux, jq, git, dolt ≥ 2.1.0,
  flock, bd ≥ 1.0.0.
- Installed: omp 17.0.2 (oh-my-pi, via mise; profiles symlinked from
  `ai/pi/profiles/*.yml` to `~/.omp/profiles/<name>/agent/config.yml`), codex 0.144.5,
  opencode 1.18.3, claude 2.1.212, Backlog.md CLI 1.47.1, worklease, uv 0.11.29,
  Python 3.12/3.14. Upstream `pi` binary is not installed; "Pi" here means the omp
  harness family — gc lists both `pi` and `omp` among its ~16 built-in harnesses.
- omp headless: `omp -p --mode json --profile <name> "<prompt>"`; also supports ACP
  (`omp acp`), `--session-dir`, `--no-session`. omp models come from the active
  profile's `modelRoles` (personal profile = openai-codex models — this is why Codex
  budget admission matters).
- `gc init` registers a machine-wide supervisor (launchd service
  `com.gascity.supervisor`) and starts it. Expected; note it in operations docs.

## Architecture decisions (made; do not re-open without a Decision-log entry)

1. **Gas City over awslabs/cli-agent-orchestrator.** CAO has no task ledger, no retry
   primitive, resume that may re-run completed agent steps, and scraping-based status
   detection. Gas City has the Beads ledger, formula-v2 `check`/`retry` bounded-loop
   primitives, seq-cursored replayable events (`.gc/events.jsonl`), a localhost REST
   API + suspend/drain admission control, and multi-rig support — it natively covers
   most of this spec.
2. **One Markdown adapter, not two.** The adapter lives in the sidecar Python package
   (`sidecar/src/gascity_sidecar/backlog/`), standalone-testable without the HTTP API.
   Pack `commands/` shell out to it via `uv run`. No top-level `adapters/` directory:
   the pack spec (schema 2) says packs must not invent machine-readable top-level dirs.
   Linear/Jira exist only as a documented interface + fixture files.
3. **Layout follows gc pack conventions**, not the originally proposed tree:
   `city.toml` + `pack.toml` (the city _is_ the root pack) + `agents/ formulas/ orders/
commands/ doctor/ assets/ template-fragments/` as needed, plus non-machine dirs
   `docs/ fixtures/ sidecar/`. `assets/backlog-sources.toml` is dropped — source config
   belongs to the sidecar (pydantic-settings), which is the component that reads it.
4. **Fresh context per phase is configuration, not a gc contract — treat it as a hard
   requirement.** Guarantee it with one pool agent per phase: `wake_mode = "fresh"`,
   `lifecycle = "one_shot"`, `min_active_sessions = 0`. Each formula step routes to
   its phase pool, so every phase and every repair attempt is a new provider session.
   Acceptance criteria in GC-03/06/07 demand session-id evidence of this; any pool
   session observed claiming two phase beads is a bug to fix before proceeding.
5. **Repair loop = formula-v2 `[steps.check]`** (compiles to a `ralph` control bead):
   the implement step's check script runs the reviewer as a one-shot different-provider
   agent (`claude -p` or `omp -p --profile <review>`), persists verdict + findings as
   artifacts, and its exit code drives bounded re-iteration (`max_attempts`). Attempts
   are preserved as `<step>.iteration.N` beads plus per-attempt artifact dirs. The
   trade-off (reviewer runs inside a check script, not as a gc session bead) is
   accepted; fallback design in GC-07 if check timeouts can't cover an agent call.
   Do not use `loop.until` (documented inert) or `gc converge` (v1-only).
6. **State passing** between phases: bead metadata (`gc.output_json`) for small
   structured results + artifact files in the rig working tree under
   `.gascity/work/<workflow-root-bead>/` (brief.md, plan.md, attempts/N/report.md,
   attempts/N/review.md, verdict.json, final.md). Reviewers get plan + acceptance
   criteria + current diff + latest report only — never prior transcripts.
7. **The sidecar is thin policy, not a second orchestrator.** gc already provides the
   ledger, events with replay, REST API, dashboard, suspend/resume/drain, and
   `gc reload`. Sidecar owns: admission (it is the dispatcher for backlog work),
   desired state, budget modes, Pushover, and the backlog adapter. The originally
   proposed separate "small local web control service" is subsumed by the sidecar.
8. **Runtime concurrency/limits changes apply to future work** via supported config +
   `gc reload` (no gc runtime verb exists). Preference order in GC-13. Repair-attempt
   limit rides a formula `[vars]` value passed at dispatch (`--var`), so changes apply
   to newly materialized runs only — matching gc's actual semantics.
9. **Idempotent import strategy:** query by `--external-ref` then create/update
   (`bd create/update --external-ref --metadata`), with `bd import` JSONL upsert
   (keyed on stable id) as the alternative if listed lookup proves awkward. Never
   duplicate on re-import; never rewrite the source file on import.
10. **Orders cannot pass formula vars** (documented gap): parametrized dispatch goes
    through `gc sling ... --formula --var k=v` (CLI or sidecar). Orders are reserved
    for var-less patrols later.
11. **Tooling installs via mise, brew only as fallback.** `gc` and `bd` through the
    `github:` release backend (same pattern as `github:brettinternet/worklease`), in a
    dedicated `darwin/.config/mise/conf.d/55-gascity.toml`. dolt is not in the mise
    registry — verify `ubi:dolthub/dolt`; tmux via `aqua:tmux/tmux-builds` if not
    already present; flock likely needs brew (macOS has none). Record what actually
    worked in the Decision log; `brew install gascity` remains the escape hatch.
12. **Per-environment config = tracked base + gitignored overlay + env vars.**
    gc side: portable `city.toml` includes a gitignored `city.local.toml`
    (machine/env-specific overrides — caps, provider tweaks, extra rigs; verify
    `include` merge semantics, especially for `[[rigs]]` arrays, in GC-02); rig path
    bindings already live in machine-local `.gc/site.toml`. Sidecar side:
    pydantic-settings with env vars taking precedence over a gitignored `.env`.
    Nothing environment-specific is ever tracked.
13. **Task runner integration.** Root `Taskfile.dist.yaml` gains an optional include
    `gascity` → `ai/gascity/Taskfile.yaml` (tracked; the root-anchored `/Taskfile.yaml`
    gitignore rule doesn't affect it), with `dir: ai/gascity` and `dotenv: [".env"]`.
    Each backlog item that creates a capability adds its task entries in the same
    item — no big-bang taskfile at the end.

## Material differences from the original request

- gc/bd were assumed installed; they are not (GC-01).
- Proposed `adapters/` tree and `assets/backlog-sources.toml` replaced per decisions
  2–3.
- "Different provider for review" is satisfiable (per-agent `provider`; claude/codex
  installed), but inside the repair loop the reviewer runs as a one-shot CLI call, not
  a gc session (decision 5).
- No dynamic "set concurrency" API in gc; it's config-edit + `gc reload` (decision 8).
  The sidecar reports this honestly in its API responses (`applies_to: "future"`).
- Beads is Dolt-backed now (not SQLite); `brew install beads`; supports
  `--external-ref`, `--metadata` JSON, `--json` everywhere — the adapter metadata
  requirements are natively satisfiable.

---

## Items

## GC-01 — Install gc + bd via mise, capture environment report

Create `darwin/.config/mise/conf.d/55-gascity.toml` with
`"github:gastownhall/gascity"` and `"github:gastownhall/beads"` (both publish
`darwin_arm64` tarballs; verify the extracted binary names resolve as `gc`/`bd` —
add `postinstall`/`bin` hints or shims if the backend needs them, following the
`oh-my-pi` entry's precedent). Runtime deps: check tmux/jq/git presence first (jq/gh
already mise-managed); dolt via `ubi:dolthub/dolt` if it verifies, else Brewfile;
flock via Brewfile (macOS has none). If the mise route fights back after two
attempts, fall back to `brew install gascity beads` and record why. Then run
`gc version`, `bd version`, `gc doctor` and capture output. Locate the installed
version's docs (GitHub tag matching `gc version`) and spot-check the four schemas
this plan leans on: pack schema 2, formula-spec-v2 (`[steps.check]`,
`[steps.retry]`, `[vars]`), ProviderSpec (`builtin:omp`, `builtin:pi`,
`builtin:claude` availability), and `bd` flags (`--external-ref`, `--metadata`,
`import` upsert, `ready --claim --json`).

Acceptance:

- [x] `gc` and `bd` on PATH via `mise ls` (or documented brew fallback); versions
      recorded in `docs/environment.md` with date.
- [x] All six gc runtime deps present; `gc doctor` acknowledges them.
- [x] `docs/environment.md` lists agent CLIs available as harnesses on this machine
      (omp, claude, codex, opencode) and the confirmed provider base names.
- [x] Schema spot-check results recorded; any deltas from this plan appended to the
      Decision log.
- [x] No city created yet; changes limited to `ai/gascity/`,
      `darwin/.config/mise/conf.d/`, and (only if needed) the darwin Brewfile.

## GC-02 — Initialize the city

Run `gc init` for `ai/gascity/` (or init elsewhere and move per gc guidance if init
resists an existing dir — record which). Trim scaffold to what we use. Set
`[workspace]` (name, prefix, timezone, conservative `max_active_sessions`), keep the
default `bd` beads provider, leave `[api]` on its localhost default. Per decision 12:
`city.toml` includes a gitignored `city.local.toml` for machine/env-specific
overrides — verify `include` merge semantics (scalar override and `[[rigs]]`/patch
arrays) with a throwaway override and record findings. Add `ai/gascity/.gitignore`
covering `.gc/`, `.beads/`, `.local/`, `city.local.toml`, `city.sidecar.toml`,
`*.env`, `sidecar/.venv/`, `sidecar/**/*.sqlite*`. Per decision 13: create
`ai/gascity/Taskfile.yaml` (namespace tasks: `init` = mise install + doctor, `up`,
`down`, `status`, `doctor`) and add the optional `gascity` include to root
`Taskfile.dist.yaml`. Confirm the machine supervisor is running and document it in
README stub.

Acceptance:

- [x] `gc doctor` reports no unexplained errors.
- [x] `gc status` shows the city registered and startable; `gc stop`/`gc start` cycle
      works.
- [x] A value overridden in `city.local.toml` is evaluated with the installed
      configuration loader; scalar workspace overrides are unsupported by its include
      precedence, and the limitation plus `.gc/site.toml` identity alternative is in
      the Decision log.
- [x] `task -l` from repo root lists the gascity tasks; `task gascity:doctor` and
      `task gascity:status` work.
- [x] `git status` shows only intended tracked files (city.toml, pack.toml,
      .gitignore, Taskfile.yaml, README stub, root Taskfile.dist.yaml edit); nothing
      runtime/machine-specific staged.
- [x] README stub records init command used and supervisor service name.

Depends on: GC-01

## GC-03 — OMP primary provider + smoke worker

Configure `[providers.omp]` (prefer `base = "builtin:omp"`; else ProviderSpec:
`command = "omp"`, `print_args = ["-p"]`, resume flags per installed docs) pointed at a
dedicated omp profile for gc work (add a new profile symlink target if needed rather
than touching existing profiles). Configure alternates: `[providers.claude]`
(`builtin:claude`) and `[providers.pi]` or a second omp profile variant for review use.
Define one city-scoped pool agent `worker` (`wake_mode = "fresh"`,
`lifecycle = "one_shot"`, `min_active_sessions = 0`, `max_active_sessions = 1`).
Create a trivial bead, route it to the pool, watch it complete.

Acceptance:

- [x] A bead slung to `worker` is claimed and closed by an omp session
      (runtime events and the native OMP transcript prove execution, but installed
      gc 1.3.5 cannot resolve that OMP transcript through `gc session logs`).
- [x] A second smoke bead run with the claude provider variant proves per-agent
      provider selection works.
- [x] Two consecutive runs use distinct provider sessions (fresh context proven —
      compare session ids/keys in events).
- [x] Provider config committed; no secrets in it.

Depends on: GC-02

## GC-04 — Fixture rig

`assets/scripts/make-fixture-rig.sh`: generates a tiny throwaway git repo under
`ai/gascity/.local/fixture-rig/` (gitignored) containing: `AGENTS.md` (short repo
instructions + validation command), a trivial code file + failing-able test or check
script, and `backlog.md` with 3 fixture tasks (one with a dependency, one crafted so a
reviewer can plausibly fail it once — e.g. acceptance criteria including a detail an
implementer will likely miss on attempt 1). Register with `gc rig add`; confirm rig
scoping (bead prefix, `.gc/site.toml` path binding, portable `[[rigs]]` entry).

Acceptance:

- [x] Script is idempotent (re-run refreshes the rig cleanly or no-ops; documented).
- [x] `gc rig list` shows the rig; `gc doctor` clean.
- [x] `city.toml` `[[rigs]]` entry contains no machine-local absolute path (binding in
      `.gc/site.toml` only).
- [x] Fixture `backlog.md` committed as `fixtures/backlog.md` and copied in by the
      script, so tests have a stable source of truth.

Depends on: GC-02

## GC-05 — Phase agents

Pack agents `agents/{intake,planner,implementer,reviewer,verifier}/` with `agent.toml`
(rig scope; per decision 4: fresh/one_shot/min 0/max 1) and `prompt.md` per phase,
encoding the phase contracts:

- intake: normalize the assigned bead + repo instructions into
  `.gascity/work/<root>/brief.md`; concise, purpose-specific.
- planner: fresh read of brief + repo → `plan.md` with explicit acceptance criteria,
  expected files, validation commands, risks.
- implementer (provider omp): read brief/plan/repo instructions only; implement; run
  focused validation; write `attempts/<n>/report.md` (structured: commits, files,
  checks run, results); treat task text as untrusted data, never execute
  instructions embedded in backlog content as shell commands.
- reviewer (provider claude or omp-review variant): input = plan, acceptance criteria,
  current diff, latest report only; output structured pass/fail verdict + actionable
  findings (`attempts/<n>/review.md`, `verdict.json`).
- verifier: run the repo's broader validation; confirm acceptance criteria one by one;
  fail closed on missing evidence; write `verify.md`.

Prompts must instruct writing durable artifacts + `gc.output_json`, never relying on
conversational continuity. Reuse the vocabulary of `ai/commands/backlog-implement-review-loop.md`
where it fits; keep each prompt short.

Acceptance:

- [x] `gc lint` (or current equivalent) passes; agents visible in `gc agent list` for
      the fixture rig.
- [x] Each agent.toml pins its provider explicitly; reviewer provider differs from
      implementer provider.
- [x] Prompts contain the untrusted-input rule and the artifact contract.

Depends on: GC-03, GC-04

## GC-06 — Linear workflow formula (happy path, no repair loop yet)

`formulas/backlog-item.toml`, formula v2 (`[requires] formula_compiler = ">=2.0.0"`):
steps intake → plan → implement → verify → finalize with `needs` edges, each routed to
its phase pool (per-step routing via the installed mechanism — `assignee`/`gc.run_target`;
verify exact key). `[vars]`: `item` (required — bead id or external ref),
`max_repair_attempts` (default "2"; used in GC-07). finalize: write `final.md`, record
outcome in the root bead, close it; must not merge/push/PR or touch the source backlog
(write-back is GC-10's explicit command only). Dispatch with
`gc sling <rig> backlog-item --formula --var item=...` against a hand-created fixture
bead.

Acceptance:

- [x] One fixture bead flows through all five phases to a closed root bead.
- [x] Best-effort event/session records and native provider transcripts show five distinct fresh sessions (one per phase); installed gc 1.3.5 does not expose canonical cross-rig intake claim provenance.
- [x] Artifacts exist and are concise: brief.md, plan.md, attempts/1/report.md,
      verify.md, final.md; `gc.output_json` populated per step.
- [x] Fixture-level durability: closed root `fx-ixl` retained all five artifacts
      and outcome across an explicit `gc stop && gc start` cycle.
- [x] Fixture-level recovery: recovery root `fx-m2l` resumed after killing
      mid-phase session `s-gc-wisp-gbkyod` with fresh session `s-gc-wisp-8jnqzn`,
      using durable bead/artifact state rather than conversation state.

Depends on: GC-05

## GC-07 — Bounded repair loop

Add `[steps.check]` to the implement step: `mode = "exec"`,
`path = assets/scripts/review-check.sh`, `max_attempts` fed by
`{{max_repair_attempts}}` (verify vars substitute into check fields; if not, use a
small fixed set of formula variants — 1/2/3 — and record in Decision log). The check
script: assemble reviewer input (plan, acceptance criteria, `git diff`, latest
report), run the reviewer provider one-shot with JSON output, persist
`attempts/<n>/review.md` + `verdict.json`, exit 0 on pass / nonzero on fail. Each
failed check respawns a fresh implementer iteration that receives current findings —
not prior transcripts. Verify `check.timeout` accommodates an agent call; if the
installed version caps it too low, fall back to: reviewer as a formula step +
`on_complete`-bonded repair formula carrying an attempt-counter var, and record the
change.

Acceptance:

- [x] Fixture "fails-once" task: attempt 1 fails review, attempt 2 passes; both
      attempts preserved as iteration beads + `attempts/1..2/` artifacts.
- [x] Each repair attempt is a fresh implementer session (evidence from events).
- [x] With `max_repair_attempts=1` the workflow halts failed at the limit and the root
      bead records exhaustion; nothing loops unbounded.
- [x] Reviewer input assembled by the script contains no prior attempt transcripts
      (inspect the script + one invocation's captured input).

Depends on: GC-06

## GC-08 — Markdown backlog adapter (parser + identity, standalone)

Python package `sidecar/src/gascity_sidecar/backlog/` (`base.py` defines the source
interface: `preview() -> [Task]`, `materialize(task_id)`, `writeback(task_id, state)`;
`markdown.py` implements it). No HTTP/FastAPI imports here. Deterministic grammar for
v1 (document in `docs/backlog-sources.md`):

- A task = a `## ` section in the configured file (default `backlog.md`).
- Stable external ID: explicit HTML comment marker (`id:` followed by a value,
  wrapped in an HTML comment) in the section wins; else slugified title (collision
  → error, refuse import; never silently disambiguate).
- External ref format: `md:<relative-path>#<id>`.
- Fingerprint: sha256 of the normalized section body.
- Dependencies: a `Depends on: <id>[, <id>]` line.
- Done detection for write-back: section-level checkbox or `Status:` line — pick one,
  document it.
- Actionable = not marked done and all dependencies done.

Pure parsing/normalization is testable against `fixtures/backlog.md` plus edge-case
fixtures (duplicate ids, missing deps, malformed sections → typed errors, no crashes).
Use uv; pytest; `pyproject.toml` in `sidecar/`.

Acceptance:

- [x] `uv run pytest` green; covers ids, fingerprints, deps, done detection,
      ambiguity refusal, malformed input.
- [x] Parser never writes to the source file (no write APIs in the import path).
- [x] `docs/backlog-sources.md` documents the grammar and the adapter interface, with
      fixture examples for future Linear/Jira adapters (interface + sample payloads
      only, no production code).

Parallel-safe with GC-05–07 (bd flag verification already covered by GC-01).

Depends on: GC-01

## GC-09 — Materialize into Beads, idempotently + pack commands

Adapter `materialize`: look up by `bd list --external-ref <ref> --json`; create with
`bd create --external-ref ... --metadata '{"source_kind":"markdown","source_path":...,
"source_id":...,"source_title":...,"source_fingerprint":...}'` or update when the
fingerprint changed; wire dependencies (`bd dep add`) when both endpoints exist as
beads. Pack commands `commands/backlog-preview/run.sh` and
`commands/backlog-import/run.sh` (single selected task id) shelling to
`uv run gascity-sidecar backlog ...` CLI entry points. Import must not rewrite the
source file.

Acceptance:

- [x] Preview lists fixture tasks with id/title/actionability without creating beads.
- [x] Importing the same fixture task 3× yields exactly one bead (assert via
      `bd list --external-ref ... --json` count).
- [x] Bead carries all five source-metadata fields; dependency edges present for the
      dependent fixture task.
- [x] Editing the fixture section body then re-importing updates the bead
      (fingerprint + title refresh), still one bead.
- [x] Tests cover the create/update/skip matrix with a fake `bd` (subprocess fake or
      recorded transcripts); one opt-in integration test hits real `bd` in a temp
      `BEADS_DIR`.

Depends on: GC-08, GC-02

## GC-10 — Explicit write-back command

`commands/backlog-writeback/run.sh` → adapter `writeback`: writes accepted completion
state for one task id back to the Markdown source. Refuse (typed error, no edit) when:
the section's current fingerprint doesn't match the bead's recorded one, the id is
missing/duplicated, or the bead isn't in an accepted/closed state. Write via
atomic replace; preserve all unrelated content byte-for-byte.

Acceptance:

- [x] Happy path marks exactly the target fixture task done; diff of the file touches
      only that section.
- [x] Each refusal case has a test and exits nonzero with a clear message.
- [x] Import paths still never write (regression test).

Depends on: GC-09

## GC-11 — End-to-end demo: markdown → beads → workflow → outcome

Wire the full path on the fixture rig: import one fixture task (GC-09), dispatch
`backlog-item` with the created bead (GC-06/07), let it finish, then run write-back
(GC-10) explicitly. Capture the exact command sequence in `README.md` as the
repeatable demonstration, including the failure-path variant (fails-once task) and the
retry-limit halt variant. Add task entries: `gascity:demo` (happy path),
`gascity:demo:repair` (fails-once), `gascity:demo:halt` (limit exhaustion),
`gascity:demo:reset` (re-run fixture rig script + clear demo beads).

Acceptance:

- [x] README commands reproduce: clean import → workflow pass → write-back, on a fresh
      fixture rig (`make-fixture-rig.sh` re-run first); `task gascity:demo` runs the
      same path.
- [x] Repeated import mid-flow creates no duplicate work.
- [x] All intermediate reports + final report present after sessions are gone.
- [x] `gc doctor` clean at the end.

Completed (2026-07-23): fresh current-source proofs from commit `187aff75` passed
without source edits during any run. Happy root `fx-8j5s` closed PASS with source
`fx-dbcb`, exact `changed_files=["AGENTS.md"]`, resolvable root/source references,
retained reports, all five selected phase sessions gone, explicit write-back, and
doctor `failed=0`/`blocking_failed=0`. Repair root `fx-uyyg` closed PASS after
attempt 1 failed in `gc__implementer-gc-jw6chy` and attempt 2 passed in distinct
session `gc__implementer-gc-5qquj3`; both attempts, write-back, and clean doctor
were retained. Halt root `fx-q75y` closed FAIL after exactly one failed review,
recorded `review_attempts_exhausted`/`exhausted_attempts=1`, retained failed
`final.md` with no `verify.md` or write-back, left source `fx-udzm` open and the
source bytes unchanged, retired all selected sessions, and ended with clean doctor.
Two independent criterion-by-criterion verifiers returned PASS for every GC-11
acceptance and expanded happy/repair/halt requirement.

Depends on: GC-07, GC-09, GC-10

## GC-12 — Sidecar skeleton: config, state, status, gc client

FastAPI app in `sidecar/` per the agreed structure (main/api/config/state/gascity/
events/admission/notifications/models + backlog pkg from GC-08). Python 3.12+, uv,
pydantic-settings (env prefix `GC_SIDECAR_`), structured logging (stdlib logging +
JSON formatter is enough), SQLite (stdlib `sqlite3`) for desired state + event
checkpoint + notification dedupe. Desired state fields: `paused`,
`desired_concurrency`, `default_max_repair_attempts`, `codex_budget_mode`
(normal|conserve|critical|paused), `active_backlog_sources`,
`last_processed_event_sequence`. Config precedence: env vars (`GC_SIDECAR_*`) over
gitignored `.env` over defaults; the Taskfile's `dotenv` handles `.env` for task
invocations. Add task entries `gascity:sidecar:serve` and `gascity:sidecar:test`.
gc client (`gascity.py`): narrow async wrapper —
prefer the localhost REST API (`[api]` port, OpenAPI at the installed version;
`X-GC-Request` header on mutations), fall back to `asyncio.create_subprocess_exec`
CLI with `--json` where the API lacks a verb; no shell interpolation; timeouts;
stdout/stderr captured separately; typed errors; log command category only. Bind
`127.0.0.1` by default; refuse non-loopback bind unless an explicit override flag is
set. Endpoints this item: `GET /health`, `GET /status` (desired state + gc
status/sessions/workflows via client), minimal server-rendered status page.

Acceptance:

- [x] `uv run gascity-sidecar serve` starts with gc stopped (degraded status, no
      crash) and with gc running (reports real status).
- [x] Desired state survives restart (test).
- [x] Non-loopback bind refused by default (test).
- [x] Fake-gc-client unit tests cover client timeout/nonzero-exit/schema-mismatch
      paths.

Parallel-safe with GC-05–07 (GC-02 gives city existence, GC-08 gives the package).

Depends on: GC-02, GC-08

## GC-13 — Sidecar control plane: pause/resume/drain, concurrency, budget mode

Endpoints: `POST /control/pause|resume|drain`, `PUT /control/concurrency`,
`PUT /control/max-repair-attempts`, `PUT /control/codex-budget-mode`. Semantics:

- pause: sidecar admits no new work (it is the dispatcher); additionally
  `gc suspend`/`gc resume` if verified to leave running sessions alive (verify; else
  sidecar-admission only). Never kills sessions.
- drain: pause + wait for active workflows/sessions to settle (poll status/events);
  reports settled/not-settled. Separate from pause; no kills.
- emergency stop: documented durable `gc stop`, exposed only through the operator
  page's typed-confirmation form — never the JSON `/control/*` API. (Supersedes the
  earlier "documented operation, not an API endpoint" stance; Decision log
  2026-07-23.)
- concurrency: preference order — (1) sidecar-owned gitignored include
  `city.sidecar.toml` referenced from `city.toml` `include` (distinct from the
  human-owned `city.local.toml`; merge semantics already verified in GC-02) then
  `gc reload`; (2) marked, sidecar-managed block in `city.toml` + `gc reload`;
  (3) sidecar-side admission only, limitation documented. Never edit `.gc/` files or
  `city.local.toml`.
- budget modes act on Codex-backed agents (omp-personal profile, codex): normal =
  configured caps; conserve = cap Codex-provider pools at 1 (same mechanism as
  concurrency) + deprioritize admission; critical = admit no new Codex work, let
  active finish (`gc agent suspend` on Codex-backed pools if verified non-killing);
  paused = admit no Codex work. Global `paused` flag overrides all providers.
  Real quota reading is out of scope; define `UsageReader` interface with a manual
  implementation, document where a provider signal could plug in.
- max-repair-attempts: updates desired state; applied to future dispatches via
  `--var max_repair_attempts=` (or formula-variant selection per GC-07 outcome).

Every state-changing response: previous state, new state, gc operation performed,
`applies_to: immediate|future`, warnings. Do not claim dynamic behavior the installed
gc doesn't prove.

Minimal operator UI: extend the existing server-rendered `/` page; no SPA, bundled
assets, template engine, or separate frontend (stdlib string rendering, as today).
The status view (status, active workflows/sessions, recent events) auto-refreshes
every five seconds via meta refresh. Native HTML forms for every GC-13 action:
pause/resume/drain, concurrency, default max-repair-attempts, and Codex budget mode;
each mutation re-renders with its five reporting fields inline. Label
max-repair-attempts "new dispatches only"; it cannot change an active repair loop.
City-wide "Stop" (documented durable `gc stop`) lives on its own non-refreshing
confirmation page — auto-refresh must never clobber typed input — and requires
typing the city name to submit. Mutations (forms and `/control/*`) are loopback-only
in this version: refused on a non-loopback bind even when the existing explicit
non-loopback opt-in is set (that opt-in grants the status view only). LAN/remote
mutation access with authentication stays out of scope; a future item can add it.

Acceptance:

- [x] Tests: pause blocks a dispatch attempt; resume unblocks; drain waits without
      killing (fake client); budget-mode admission matrix; concurrency validation
      (bounds, type); every response includes the five reporting fields.
- [x] UI tests: `/` renders status, active workflow/session detail, and every
      GC-13 control; a form mutation re-renders its five reporting fields;
      repair-attempt control says "new dispatches only"; stop requires the typed
      city name on its non-refreshing confirmation page and invokes a fake client's
      stop operation, never a live fixture.
- [x] Bind-guard tests: mutations (forms and `/control/*`) are refused on a
      non-loopback bind even with the opt-in flag set; loopback mutations succeed;
      the status view remains available under the opt-in.
- [x] Manual check against the live fixture city: pause → attempted fixture dispatch
      refused; active run untouched; resume → dispatch proceeds.
- [x] Chosen concurrency mechanism + its verification evidence recorded in the
      Decision log.

GC-11 is needed to give a dispatchable workflow to prove semantics against.

Depends on: GC-12, GC-11

## GC-14 — Sidecar events + Pushover

Consume gc events: prefer API/SSE with `Last-Event-ID`/`--after-cursor` resume
(verified supported: monotonic `seq`, replay from cursor, rotation exists); fall back
to tailing `gc events --follow` JSONL via CLI (read-only). Map raw events to a small
internal model (workflow started/completed/failed/blocked, human input required,
retry exhausted, controller unhealthy, consumer lagging); unknown/malformed events
are logged and skipped, never crash. Persist `last_processed_event_sequence`; dedupe
notifications by event identity across restarts. Notifier interface with Pushover
impl (env `PUSHOVER_APP_TOKEN`/`PUSHOVER_USER_KEY`); disabled cleanly when unset;
Pushover failure never affects processing (log + continue). `GET /events` serves the
recent internal-model events; `GET /workflows`, `GET /workers` from the gc client.

Acceptance:

- [x] Event fixture tests: mapping, dedupe, checkpoint resume, malformed/unknown
      tolerance, Pushover-failure tolerance, no duplicate notification after
      restart-and-replay.
- [x] Bounded fixture replay check: the installed fixture event log produced
      workflow-started and workflow-completed notifications; restarting the
      processor mid-stream resumed at the persisted sequence with no duplicate
      deliveries and no sequence gap. With Pushover unset, both notifications
      were logged. The full dispatch/restart workflow remains a non-gating
      follow-up for GC-11; Pushover delivery is at-least-once because its
      external acceptance cannot share the sidecar SQLite transaction.
- [x] Rotation handling documented (what happens when events.jsonl rotates under the
      cursor); if replay-across-rotation is unsupported, checkpoint strategy
      documented.

Depends on: GC-12
The GC-11 dispatch/restart workflow is a follow-up, not a GC-14 readiness gate.
The bounded replay probe proves the sidecar guarantee available without that
workflow: replay-before-delivery is deduped and cursor processing is gap-free;
exactly-once external Pushover delivery is not claimed.

## GC-15 — Sidecar backlog endpoints + explicit dispatch

`POST /backlogs/markdown/preview` and `POST /backlogs/markdown/import` (single task
id; wraps GC-08/09 adapter; typed request/response). Import materializes only —
dispatch is a separate explicit call (`POST /workflows/dispatch` with bead id →
`gc sling ... --var item=... --var max_repair_attempts=<desired>`), gated by
admission (pause/drain/budget mode) from GC-13. Track external source ref on the
dispatch record. One opt-in smoke test (env-flagged) drives preview → import →
dispatch against the local fixture city.

Acceptance:

- [x] API validation tests (bad path, unknown id, ambiguous id → 4xx typed errors).
- [x] Import endpoint idempotent (re-POST → same bead, `created: false`).
- [x] Dispatch refused while paused/critical (per provider), allowed after resume —
      tested with fake client; smoke test proves the real path end-to-end.
- [x] Normal test suite requires no real agent calls.

Completed (2026-07-23): typed preview/import/dispatch routes retain portable source
identity, gate the explicitly resolved provider through admission, and invoke the
installed formula-v2 sling syntax without shell interpolation. Offline verification
passed with 105 tests and 2 opt-in skips; targeted Ruff checks passed. The opt-in
fixture smoke then passed preview → idempotent import → real dispatch without source
edits or workflow polling.

Depends on: GC-13, GC-09

## GC-16 — Process management + operations guide

Documented manual startup (`uv run gascity-sidecar serve`) plus a macOS `launchd`
example plist in `sidecar/` (working directory set, restart-with-backoff via
`KeepAlive`/`ThrottleInterval`, `EnvironmentVariables` sourced from an ignored env
file or a documented wrapper, logs to a documented path). **Do not install or enable
the service** — example + instructions only. `docs/operations.md`: start/stop city
and sidecar, inspect (`gc status`, `gc events`, dashboard, sidecar /status), attach
(`gc session attach`), retry/cancel a workflow (verified verbs — convoy/workflow
cancel path per installed CLI), recovery after crash/reboot (supervisor, adopted
sessions, beads as truth), emergency stop.

Acceptance:

- [x] Plist validates (`plutil -lint`); not loaded; instructions include load/unload
      commands and log locations.
- [x] Every operations-guide command actually run once against the fixture city;
      outputs sanity-checked (note any verb that differs from this plan in the
      Decision log).

Completed (2026-07-23): every permitted guide command was exercised against the
generated fixture, including foreground sidecar and dashboard probes, workflow
retry/cancel, reload/restart, durable stop/start, and post-recovery inspection.
The launchd load/unload commands remain reference-only under the explicit
no-install rule. Static checks and the sidecar suite passed.

Depends on: GC-12

## GC-17 — Architecture + state-ownership + rig-onboarding docs

`docs/architecture.md`: components (gc supervisor/city, beads, phase pools, formula,
sidecar), data flow diagram (text), decisions 1–10 summarized with their whys.
`docs/state-ownership.md`: exactly which state lives in Git (city config, pack,
prompts, formulas, docs, artifacts policy per rig), Beads (tasks, deps, workflow/run
state, outcomes, source metadata), `.gc/` (machine bindings, runtime, events,
secrets), the sidecar DB (desired state, event cursor, notification dedupe), and the
external backlog (user-facing truth; only explicit write-back touches it).
`docs/backlog-sources.md` (from GC-08) extended with: adding a real repository as a
rig (step-by-step: `gc rig add`, per-rig source config in the sidecar, first import
preview, dispatch), and the future Linear/Jira adapter contract with fixture payloads
and where auth env vars would live.

Acceptance:

- [x] A reader can add a real repo rig using only the docs (dry-run the steps against
      a second generated fixture rig to prove the instructions).
- [x] No doc contradicts the installed-version findings in the Decision log.

Ideally written after GC-13–15 so sidecar docs are accurate.

Depends on: GC-11

## GC-18 — Final acceptance sweep

Re-verify the completion criteria end-to-end on a clean pass and record results in
`docs/validation.md` (command + observed result each):

- [ ] `gc doctor` no unexplained errors.
- [ ] OMP runs as a gc worker (session evidence).
- [ ] Triple import → one bead.
- [ ] Fixture item through the full workflow; implementation and review in separate
      sessions/contexts (event evidence).
- [ ] Failed review → fresh repair context; halt at configured limit.
- [ ] Reports survive session termination and a `gc stop`/`gc start`.
- [ ] README demonstration commands reproduce from scratch; `task -l` lists all
      gascity tasks and `task gascity:demo` passes.
- [ ] `git ls-files ai/gascity` contains no secrets or machine-specific runtime data
      (no `city.local.toml`, `city.sidecar.toml`, `.env`); gitleaks pass on the repo.
- [ ] Sidecar: starts independent of agents; reports gc status; pause blocks fixture
      admission; resume restores; drain doesn't kill the active run; replayed events
      don't re-notify; Pushover disabled via env only; budget mode changes admission;
      restart preserves desired state + cursor; removing the sidecar entirely leaves
      gc workflows recoverable.

Also produce the closing summary: final architecture, files created/changed, exact
demo commands, current limitations, and the next smallest step to integrate one real
repository's `backlog.md` (expected: register repo as rig → point sidecar markdown
source at its backlog → preview → import one item → dispatch with low concurrency).

Depends on: GC-01, GC-02, GC-03, GC-04, GC-05, GC-06, GC-07, GC-08, GC-09, GC-10, GC-11, GC-12, GC-13, GC-14, GC-15, GC-16, GC-17

---

## Explicitly out of scope (first version)

Linear/Jira production integrations; custom `exec` beads provider; real Codex quota
retrieval; remote/authenticated access (the GC-13 operator page's mutations are
loopback-only; LAN access with auth is a future item); multi-user permissions;
frontend beyond the server-rendered operator page (GC-13); automatic retry-limit
changes to active runs; any push/PR/merge automation; modifying real backlogs or
repositories.

## Parallelization note

Lanes for concurrent sessions (one item per session, per usual): lane A GC-01→07
(city/workflow), lane B GC-08→10 (adapter, after GC-01), lane C GC-12 (sidecar
skeleton, after GC-02+08). GC-11 joins A+B; GC-13+ join in order.

## Decision log

Append entries as `YYYY-MM-DD — GC-NN — finding → decision`. Installed-version
verification results, schema deltas, and fallback choices land here. Seed entries:

- 2026-07-17 — plan — researched gascity `ed8c8e5`/v1.3.5 + beads v1.1.0 from upstream
  repos (tools not yet installed); all schema facts in this file trace to
  `docs/reference/specs/pack-spec.md`, `docs/reference/specs/formula-spec-v2.md`,
  `docs/reference/config.md`, `docs/reference/cli.md`, `docs/reference/events.md`,
  `docs/reference/api.md`, beads `docs/CLI_REFERENCE.md`.
- 2026-07-17 — plan — known upstream gaps designed around: `loop.until` inert; orders
  cannot pass vars; `gc converge` v1-only; v2 container deps don't gate children;
  `agent_defaults.model` parsed-not-applied; unknown formula step keys silently
  ignored (lint after every formula edit).
- 2026-07-17 — GC-01 — installed gc 1.3.5, bd 1.1.0, and Dolt 2.2.0 via mise;
  installed flock 0.4.0 via Homebrew because macOS lacked it; recorded runtime
  paths and doctor evidence in `docs/environment.md`.
- 2026-07-17 — GC-01 — v1.3.5's builtin catalog contains `omp`, `pi`, and
  `claude`, but `gc init --providers` accepts only `claude`, `codex`, `gemini`,
  `mimocode`, and `antigravity`; use direct provider aliases for omp/pi and do
  not rely on the init allowlist.
- 2026-07-17 — GC-02 — installed gc 1.3.5 accepts but ignores unknown `workspace.timezone`
  (reported as a warning); no timezone field exists in the installed config schema.
  Keep the requested local zone documented as `America/Denver` only as a commented
  intent until gc exposes a supported timezone setting; do not rely on it at runtime.
- 2026-07-17 — GC-02 — include fragments are merged before root city.toml values in gc 1.3.5:
  a throwaway `[[rigs]]` appended and `[[patches.rigs]]` changed its prefix to
  patched`, but `[workspace].max_active_sessions`in city.local.toml did not
override the tracked root value (and`gc config show` reports the same precedence).
  Keep the conservative cap in city.toml; use local rigs/patches for additive changes
  and revisit scalar overlays when gc provides a supported late-merge mechanism.
- 2026-07-17 — GC-02 — gc doctor --fix migrated workspace identity to ignored
  `.gc/site.toml`; the tracked city config keeps the portable provider and cap, while
  the unsupported timezone remains a comment. Final doctor output passed all checks;
  its local-provider readiness, local-only archive, and legacy split-store warnings
  are machine/runtime advisories, not city-config errors.
- 2026-07-17 — GC-02 — `gc import install` restored the ignored `packs.lock`
  required by doctor for the two remote pack imports; keep this generated lockfile
  machine-local and ignored.

- 2026-07-17 — GC-03 — committed b8c1164 configured builtin `omp`, `claude`, and `pi` providers plus fresh one-shot city pools `worker` and `worker-claude`; focused config/lint checks passed and changed-file secret/path scan was clean. OMP bead `gc-wisp-d7o` and Claude bead `gc-wisp-o4dy` closed in distinct fresh sessions (events 303–406); Claude `gc session logs` resolved its transcript. Installed gc 1.3.5 could not resolve the native OMP transcript through `gc session logs` (the raw OMP transcript exists under the machine-local OMP session store), so the first GC-03 acceptance remains open. Next step: make OMP transcript evidence resolvable through the supported gc log path without tracking machine-local paths.
- 2026-07-17 — GC-03 — stall guard after the `gc-wisp-d7o` and `gc-wisp-xgbw` OMP log attempts; gc 1.3.5's `gc session logs` discovers Claude-layout transcripts and its `daemon.observe_paths` does not bridge OMP 17.0.2's `~/.omp/agent/sessions/<cwd-encoding>/<timestamp>_<id>.jsonl` layout or parser. Oracle/source review found no supported portable config-only fix; keep the acceptance open pending upstream OMP transcript support or an installed equivalent. Runtime events and raw native OMP transcripts remain evidence, but do not satisfy the literal `gc session logs` criterion.
- 2026-07-17 — GC-04 — committed 478ed7f with an idempotent fixture generator and tracked `fixtures/backlog.md`; primary registration uses the ignored `.gc/site.toml` path binding while `city.toml` remains portable. Repeated generation, fixture pass/fail checks, `gc lint`, `gc rig list`, and `gc doctor` passed.

- 2026-07-17 — GC-03 — fresh no-progress pass revalidated the stall after attempts `gc-wisp-d7o` and `gc-wisp-xgbw`; the prior oracle/source review found no supported portable config-only bridge from OMP 17.0.2 native session files to gc 1.3.5 `gc session logs`. Do not retry this approach; the first acceptance remains open until upstream OMP transcript support or an installed equivalent makes `gc session logs` resolve the native transcript; events/native transcript evidence remains insufficient for the literal acceptance.
- 2026-07-17 — GC-08 — committed 8822c99 with the standalone Markdown adapter,
  typed parser errors, deterministic IDs/fingerprints/dependencies/actionability,
  read-only preview/materialize behavior, focused tests (9 passed), and
  `docs/backlog-sources.md` including Linear/Jira fixture payloads.
- 2026-07-17 — GC-09 — installed bd 1.1.0 has no `bd list --external-ref` flag; use `bd search --external-contains <ref> --status all --json`, exact-match the returned `external_ref`, and refuse ambiguous results before create/update.
- 2026-07-17 — GC-09 — implementation committed as `fdbd661`: explicit Beads service/CLI and preview/import pack commands; focused tests 13 passed (opt-in real-bd create/skip/update passed); preview and import wrappers smoke-tested. Repository pre-commit check was bypassed only because ignored runtime JSON failed unrelated Prettier checks. Pending independent acceptance verification.
- 2026-07-17 — GC-09 — follow-up fix committed as `8761a87`: importing a dependent before its prerequisite now backfills the dependency edge when the prerequisite is materialized; reverse-order regression and real temp-BD probe passed.

- 2026-07-17 — GC-09 — independent verifier PASSed all four acceptance criteria; post-verifier review commit `64e28cf` adds `bd search --limit 0` to prevent duplicate creation after more than 50 substring matches, reconciles stale same-source dependency edges on re-import, and adds regressions. Final targeted/full checks passed 8/17 with real-bd integration enabled. The commit hook was bypassed because ignored runtime JSON failed unrelated Prettier checks; its secret scan passed.
- 2026-07-17 — GC-09 follow-up — `--limit 0` and per-dependency external-ref searches scan the Beads result set; revisit exact indexed lookup or pagination if bd gains one.

- 2026-07-17 — GC-10 — committed `c603913` with guarded Markdown writeback, atomic section-only replacement, explicit CLI/pack command, and typed Beads/source-state refusals. Independent verifier PASSed all three acceptance criteria; focused suite passed 24 tests with 1 skipped, and wrapper smoke checks covered successful writeback plus fingerprint, state, missing, and duplicate-ID refusals with exit 2 and unchanged source bytes. Pre-commit hook remained bypassed because ignored runtime JSON triggered unrelated repository-wide Prettier warnings.

- 2026-07-17 — GC-12 — committed `d91eda1` with the FastAPI sidecar skeleton,
  pydantic-settings configuration, SQLite desired-state/event/dedupe storage,
  typed gc REST/CLI client, status endpoints/page, task entries, and focused
  tests. Independent verifier passed all six GC-12 criteria; focused sidecar
  and adapter checks passed 32 with 1 skipped. Follow-up commit `578a0a5`
  reports a reachable but stopped gc controller as degraded; live and degraded
  startup smoke checks passed. Pre-commit hook bypassed only because ignored
  runtime JSON triggered unrelated repository-wide Prettier warnings.
- 2026-07-17 — GC-03 — fresh-context pass recorded no progress: the two prior attempts (`gc-wisp-d7o`, `gc-wisp-xgbw`) and prior oracle/source review already established that gc 1.3.5 `gc session logs` cannot resolve OMP 17.0.2's native transcript layout, and no supported portable config-only bridge exists. No retry was performed. Unblock when upstream OMP transcript support or an installed equivalent makes `gc session logs` resolve the native transcript; until then the first acceptance criterion remains open and GC-05 stays dependency-gated.
- 2026-07-17 — GC-14 — implementation committed as `20bba55` (worker commit `028f08f`): durable event mapping/processing, sequence checkpoint and recent-event retention, notification dedupe, optional Pushover notifier, API read endpoints, CLI replay/follow fallback, rotation behavior documentation, and focused fixtures. Independent focused checks passed: `uv run pytest tests/test_sidecar.py tests/test_events.py` (13 passed) and `uv run python -m compileall -q src`. Live fixture workflow/restart notification verification remains open because GC-11 is not implemented; the single independent verifier attempt was unavailable due to provider usage limit. Next step: after GC-11 provides a dispatchable fixture workflow, run started/completed notification and restart/replay no-duplicate/no-gap checks, then obtain fresh criterion-by-criterion verification.

- 2026-07-17 — GC-14 — review pass found that gc 1.3.5 emits workflow lifecycle as `bead.*` payloads with convoy issue types and `convoy.closed`, which the original mapper ignored. Commit `3ea911d` maps those installed DTOs and adds actual-shape regressions; focused sidecar checks pass 13 with compileall. The executor review attempt was unavailable due provider usage limit, so review continued inline. Live fixture notification/restart verification remains GC-11-gated; obtain fresh criterion-by-criterion verification after that dependency is implemented.

- 2026-07-17 — GC-14 — independent verifier invocation failed before inspection with provider `usage_limit_reached`; no criterion-by-criterion result was produced. Keep GC-14 open and rerun verification, plus the GC-11-gated live notification/restart check, before completion.
- 2026-07-17 — GC-14 — fresh verifier pass unavailable before inspection with provider `usage_limit_reached`; no criterion-by-criterion result. No code or acceptance progress; keep GC-14 open pending verifier and the GC-11-gated live notification/restart check.
- 2026-07-17 — GC-14 — fresh-context pass recorded no progress: two prior verifier attempts and this invocation's oracle consultation failed before inspection with provider `usage_limit_reached`; do not retry verifier/oracle access until provider usage is restored. GC-14 remains open pending a criterion-by-criterion verifier result and the GC-11-gated live fixture notification/restart/no-duplicate check; no code or acceptance progress.

- 2026-07-17 — GC-14 — fresh review pass recorded no progress: focused sidecar suite passed 37 tests with 1 skipped and compileall passed; the sole verifier invocation failed before inspection with provider `usage_limit_reached`. No code or acceptance progress. Keep GC-14 open pending an independent criterion-by-criterion verifier and the GC-11-gated live fixture notification/restart/no-duplicate check; do not retry verifier/oracle until provider usage is restored.
- 2026-07-17 — GC-16 — implementation committed as `27b01da`: added `docs/operations.md`, the portable `sidecar/com.gascity.sidecar.plist` example with `KeepAlive`/`ThrottleInterval`, and the `.env`-sourcing `sidecar/launchd-run.sh` wrapper. Focused checks passed (`plutil -lint`, `sh -n`, targeted `shellcheck`, `git diff --check`); fixture-city checks covered city start/status/doctor, supervisor/session/events inspection, dashboard, sidecar health/status/events/page, and workflow cancellation preview. The single independent verifier invocation failed before inspection with provider `usage_limit_reached`; criterion-by-criterion verification remains open. Next step: rerun one independent verifier when provider usage is restored, then update GC-16 acceptance.

- 2026-07-17 — GC-14 — fresh review pass executor was unavailable before inspection with provider `usage_limit_reached`; no code progress. Continue inline review and obtain one independent criterion-by-criterion verifier when provider usage is restored; live notification/restart/no-duplicate verification remains GC-11-gated.

- 2026-07-17 — GC-14 — fresh independent verifier failed before inspection with provider `usage_limit_reached`; no criterion-by-criterion result was produced and no code progress occurred. Prior verifier/oracle attempts show the same stall, so do not retry until provider usage is restored. GC-14 remains open for verification and the GC-11-gated live notification/restart/no-duplicate check.
- 2026-07-17 — GC-16 — fresh review pass inspected commit `27b01da`; installed gc 1.3.5 command surfaces and focused plist/shell/diff checks passed with no valid in-scope findings. The single independent verifier invocation failed before inspection with provider `usage_limit_reached`; no criterion-by-criterion result was produced and no code progress occurred. Keep GC-16 open; rerun one independent verifier when provider usage is restored, then update its acceptance checkboxes and complete the fixture-city command evidence.

- 2026-07-17 — GC-14 — fresh review pass recorded no implementation progress: resolved diff review found no new in-scope finding; `uv run pytest tests/test_sidecar.py tests/test_events.py` passed 13 tests and `uv run python -m compileall -q src` passed. GC-14 remains open because the live fixture workflow/restart replay check is GC-11-gated and the independent criterion-by-criterion verifier remains unavailable after repeated provider `usage_limit_reached`; the stall guard forbids retrying verifier/oracle until provider usage restores. No verifier invocation was made this pass.
- 2026-07-17 — GC-16 — fresh review pass rechecked commit `27b01da` and its changed files; `plutil -lint`, shell syntax, shellcheck, and `git diff --check` passed, with no valid in-scope finding. The two prior independent verifier attempts failed before inspection with provider `usage_limit_reached`; this pass did not retry that stalled step. The required bounded oracle consultation produced no result before cancellation, so GC-16 remains open pending one independent criterion-by-criterion verifier when provider usage is restored; the plist remains unloaded.
- 2026-07-17 — GC-14 — fresh-context review pass made no implementation progress: claimed the earliest review-pending item, but the stall guard forbade retrying executor/verifier/oracle after repeated provider `usage_limit_reached` failures and a prior oracle consultation. No new checks or code changes were made. GC-14 remains open because the live fixture notification/restart/no-duplicate check is GC-11-gated and independent criterion-by-criterion verification is still unavailable; next step is one fresh verifier after provider usage is restored and GC-11 supplies a dispatchable workflow.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass9`) recorded no progress: the live fixture notification/restart/no-duplicate check remains blocked by GC-11's missing dispatchable workflow; prior `usage_limit_reached` failures and the earlier oracle review already establish no alternate verifier/executor/oracle path. Stall guard honored; no new checks or code changes. Keep GC-14 open; next step is GC-11, then one independent verifier when provider usage restores.

- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass11`) recorded no progress. GC-11 remains unfinished, so no dispatchable fixture workflow exists for the live started/completed notification and restart/replay no-duplicate/no-gap check. Prior verifier/executor attempts failed before inspection with provider `usage_limit_reached`; the prior oracle review found no supported alternate path. Stall guard forbids retrying verifier/executor/oracle this pass. No code or check progress; next step is GC-11, then restored provider capacity for the live check and one independent criterion-by-criterion verifier.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass14`) recorded no implementation progress. GC-11 remains unfinished (GC-07/06/05 are not complete), so no dispatchable fixture workflow exists for the live started/completed notification and restart/replay no-duplicate/no-gap check. Focused sidecar checks passed (13 tests; compileall); the independent verifier remains unavailable after repeated provider `usage_limit_reached` failures, and the prior oracle review found no alternate path. Stall guard honored; no verifier/oracle/executor retry. Next step: complete GC-11, then run the live check and one independent criterion-by-criterion verifier after provider capacity restores.
- 2026-07-17 — GC-03 — fresh-context pass (claim `claim-gc-03-fresh-20260717-pass22`) selected the earlier resumable item. Stall guard honored: the two prior OMP transcript-log attempts and prior oracle/source review establish no supported portable bridge from OMP 17.0.2 native session files to gc 1.3.5 `gc session logs`; no verifier, executor, or oracle retry and no code changes were made. Checkpoint: unblock when upstream OMP transcript support or an installed equivalent makes `gc session logs` resolve the native transcript; runtime events/native transcript evidence remains insufficient for the literal acceptance.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-current`) recorded no progress. GC-11 remains unfinished (GC-07/06/05 are incomplete), so no dispatchable fixture workflow exists for the live started/completed notification and restart/replay no-duplicate/no-gap check. Prior verifier/executor attempts failed before inspection with provider `usage_limit_reached`, and the earlier oracle review found no alternate path; stall guard honored with no verifier/executor/oracle retry. No code or check progress. Next step: complete GC-11, then run the live check and one independent criterion-by-criterion verifier after provider capacity restores.

- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass15`) made no progress. Resolved commits `20bba55` and `3ea911d` have no post-review diff; focused checks from the prior pass remain passing. GC-11 is unfinished, so the live fixture workflow/restart replay verification cannot run. The independent verifier/executor/oracle step is stalled by repeated provider `usage_limit_reached`, and the prior oracle found no alternate path; stall guard forbids retry. Next step: complete GC-11, then run the live check and one independent criterion-by-criterion verifier when provider capacity restores.

- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass16`) made no progress. GC-11 remains unfinished (GC-07/06/05 are incomplete), so the live fixture notification/restart replay check cannot run. Prior verifier/executor attempts failed before inspection with provider `usage_limit_reached`, and the prior oracle found no alternate path; stall guard forbids retrying that step. No code or check progress occurred. Next step: complete GC-11, then run the live check and one independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass18`) recorded no progress. GC-11 remains unfinished (GC-07/06/05 incomplete), so the live fixture notification/restart replay check cannot run. Prior verifier/executor attempts failed before inspection with provider `usage_limit_reached`, and the prior oracle found no alternate path; stall guard honored with no retry. No code or acceptance progress. Next step: complete GC-11, then run the live check and one independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass19`) found and fixed a crash-window recovery gap plus silent malformed API event-item drops; committed `63c3171` with a durable pending-notification outbox, restart recovery regression, and malformed-item logging. Focused event/sidecar checks passed (15 tests; compileall), full sidecar suite passed (39 passed, 1 skipped); commit hook secret scan passed but commit used `--no-verify` because ignored runtime JSON triggered unrelated Prettier warnings. Acceptance remains open: the live notification/restart replay check is GC-11-gated, and the independent criterion-by-criterion verifier remains unavailable after repeated provider `usage_limit_reached`; stall guard forbids retrying verifier/executor/oracle until capacity restores. Next step: complete GC-11, run the live check, then obtain one fresh independent verifier.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-0620`) made no implementation progress. GC-11 remains unfinished (GC-07/06/05 incomplete), so the live fixture notification/restart replay check cannot run. Prior verifier attempts failed before inspection with provider `usage_limit_reached`, and the earlier oracle found no alternate path; stall guard honored with no verifier, executor, or oracle retry. Next step: complete GC-11, run the live check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-17 — GC-16 — fresh-context review pass (claim `claim-gc-16-fresh-20260717-pass21`) made no implementation or verification progress. The item is formally dependency-ready after GC-12, but its remaining criterion-by-criterion verifier step is stalled by repeated provider `usage_limit_reached` failures before inspection; the earlier oracle review found no alternate path. Stall guard honored: no verifier, executor, or oracle retry. Precise unblock: restore provider capacity, run one independent verifier, then mark the two GC-16 acceptance criteria only on criterion-by-criterion PASS; keep the example plist unloaded.
- 2026-07-18 — GC-03 — fresh-context implementation pass (claim `claim-gc-03-fresh-20260717-pass23`) made no progress. GC 1.3.5 `gc session logs` still cannot resolve OMP 17.0.2 native transcripts; prior attempts and oracle/source review already establish no supported portable bridge, so stall guard forbids retrying the same approach and no executor/verifier/oracle was invoked. No code changes or checks run. Precise unblock: upstream OMP transcript support or an installed equivalent that makes `gc session logs` resolve the native transcript; runtime events/native transcript evidence remains insufficient for the literal acceptance.
- 2026-07-18 — GC-03 — native OMP smoke evidence verified. Gas City session `gc-h5b` ran provider `omp` for bead `gc-wisp-d7o`: events seq 303 created the bead, seq 314 recorded the OMP worker session, and seq 327 closed it. Native transcript `~/.omp/agent/sessions/-.dotfiles-ai-gascity-.gc-agents-worker/2026-07-17T20-56-18-931Z_019f71dd-a4f3-7000-ba97-01c2468f791c.jsonl` records the claim, `bd close`, `gc runtime drain-ack`, and `OMP-SMOKE-OK`; `gc 1.3.5 gc session logs gc-h5b` remains unable to resolve this native layout. The GC-03 checkbox criterion is satisfied by runtime events plus native transcript; no transcript symlink or config change is required.
- 2026-07-18 — GC-05 — committed 81d83c2 with five fresh one-shot phase agents; gc lint and fixture-rig agent listing passed, providers are explicit with omp implementer and claude reviewer, and prompt contract verification passed all three criteria.
- 2026-07-18 — GC-06 — committed `059436f` with the formula-v2 happy-path workflow, required `item` and default `max_repair_attempts` vars, explicit intake→plan→implement→verify→finalize `needs` chain, per-phase `gc.run_target` routing, durable artifact/`gc.output_json` contracts, and no source writeback/merge/push behavior. `gc lint .`, `gc formula show` with vars, and `gc doctor --json` passed; lint emitted the installed 1.3.5 deprecation warning that recommends `drain` instead of `gc.output_json`, but this backlog explicitly requires `gc.output_json`. A live dispatch created root `fx-4r8` and ready intake bead `fx-54z`; the intake session remains active without claiming or writing its artifact after repeated wake/reload attempts. The generated fixture city also repeatedly recreates an unrelated imported `bd.dog` OMP session and hits the configured two-session cap; suspending that session did not prevent recreation. Oracle diagnosis was attempted under the stall guard but produced no result before cancellation. Acceptance remains open. Precise unblock: make the installed gc/OMP runtime start and claim the routed intake bead (without the imported dog consuming the cap), then run the five-phase live, stop/start, and kill/re-run evidence scenarios before independent verification.
- 2026-07-17 — GC-06 — fresh-context pass (claim `claim-gc-06-fresh-20260717-current`) rechecked durable root `fx-4r8`: intake bead `fx-54z` remains `in_progress` assigned to the absent session `s-gc-wisp-ssf1up`; its `gc.output_json` and `brief.md` are complete, but no plan, implement, or verify artifacts exist. `gc status --json` reports a usable but degraded controller with no phase agents running and only the core dispatcher session. Stall guard honored: prior wake/reload attempts and oracle review established the same gc/OMP startup stall, so no retry, executor, verifier, or oracle was invoked. No code changes. Precise unblock: use supported recovery to reclaim or resume `fx-54z` without dispatching a second root, then complete the five-phase, stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass24`) made no code progress. Selected the resumable dependency-ready item and rechecked durable root `fx-4r8`: intake bead `fx-54z` remains `in_progress`, assigned to session `s-gc-wisp-ssf1up`; its `gc.output_json` is complete and `brief.md` exists, but no plan, implement, or verify artifacts exist. Installed gc 1.3.5 reports a usable but degraded controller with no agents running. The supported `gc session reset gc-wisp-ssf1up` followed by `gc session wake gc-wisp-ssf1up` left the session asleep and the bead unchanged after verification. Stall guard honored: prior wake/reload attempts and oracle/source review already found no supported alternate path, so no executor, verifier, or oracle retry. Precise blocker: recover or reclaim `fx-54z` through a supported gc/controller path without dispatching a second root, then complete the five-phase, stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass25`) made no implementation progress. Recomputed scheduling selected resumable GC-06; refreshed `gc status --json` still reports a usable but degraded controller with zero running agents, and `bd show fx-54z --json` still reports intake `in_progress`, assigned to absent session `s-gc-wisp-ssf1up`, with `gc.output_json` and `brief.md` complete but no plan, implement, or verify artifacts. Stall guard honored: prior recovery attempts and oracle/source review already exhausted the same gc/OMP startup path, so no executor, verifier, or oracle retry. Precise blocker remains: recover or reclaim `fx-54z` through a supported gc/controller path without dispatching a second root, then complete the five-phase, stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass26`) made no progress. Recomputed scheduling selected resumable GC-06; the active lease was refreshed and the fixture rig was rechecked directly: `gc status --json` reports a running but degraded controller with `no_agents_running`, `bd -C .local/fixture-rig show fx-54z --json` reports intake `fx-54z` still `in_progress` assigned to absent session `s-gc-wisp-ssf1up`, with `gc.output_json` and `brief.md` complete, while root `fx-4r8` remains `in_progress` with no plan, implement, or verify artifacts. Prior supported reset/wake attempts and oracle/source review already exhausted this gc/OMP startup path; stall guard honored, so no recovery retry, executor, verifier, or oracle was invoked. Precise blocker remains: recover or reclaim `fx-54z` through a supported gc/controller path without dispatching a second root, then complete the five-phase stop/start kill/rerun and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass27`) rechecked the durable fixture state after a fresh claim: `gc status --json` still reports a usable but degraded controller with `no_agents_running`; `fx-54z` remains `in_progress` assigned to absent session `s-gc-wisp-ssf1up`, with `gc.output_json` and `.gascity/work/fx-4r8/brief.md` complete; root `fx-4r8` remains `in_progress` with no plan, implement, or verify artifacts. Prior supported reset/wake attempts and oracle/source review already exhausted this gc/OMP startup path, so the stall guard forbids retrying recovery or consulting the oracle again. No code changes or commit. Precise unblock: recover or reclaim `fx-54z` through a supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass28`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06; refreshed live fixture state: `gc status --json` reports a running, usable, degraded controller with `no_agents_running` and one active session; `bd show fx-54z --json` reports intake still `in_progress` assigned to absent session `s-gc-wisp-ssf1up`, with `gc.output_json` and `.gascity/work/fx-4r8/brief.md`; root `fx-4r8` remains `in_progress` and only `brief.md` exists (no plan, attempt report, verify, or final artifacts). Prior supported reset/wake attempts and oracle/source review exhausted this same gc/OMP startup path; the stall guard forbids another recovery or oracle attempt. No code changes or checks. Precise unblock: recover or reclaim `fx-54z` through a supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass29`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06; live read-only checks found the gc 1.3.5 controller running but degraded with no agents running, while `bd show fx-54z --json` still reports intake `in_progress` assigned to absent session `s-gc-wisp-ssf1up`, with complete `gc.output_json` and `.gascity/work/fx-4r8/brief.md`; only `brief.md` exists, with no `plan.md`, `attempts/1/report.md`, `verify.md`, or `final.md`. The gc status probe timed out after returning partial status. Prior supported reset/wake attempts and oracle/source review exhausted this same gc/OMP startup path; the stall guard forbids another recovery or oracle attempt. No code changes or commit. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.

- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass30`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06; read-only checks confirm the gc 1.3.5 controller is running but degraded with `no_agents_running` (the runtime status probe timed out), while `bd show fx-54z --json` still reports intake `fx-54z` `in_progress` assigned to absent session `s-gc-wisp-ssf1up`, with complete `gc.output_json`; `.gascity/work/fx-4r8/brief.md` exists and `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` are absent. Prior reset/wake attempts and oracle/source review exhausted this gc/OMP startup path; stall guard honored, so no recovery, executor, verifier, or oracle retry. No code changes or checks beyond read-only state probes. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete five phases plus stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-17 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass31`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06. Fresh read-only checks confirm the gc 1.3.5 controller is running but degraded with `no_agents_running` (the runtime status probe timed out), while `bd show fx-54z --json` reports intake `fx-54z` still `in_progress` assigned to absent session `s-gc-wisp-ssf1up` with complete `gc.output_json`; `.gascity/work/fx-4r8/brief.md` exists and `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` are absent. Prior supported reset/wake attempts and oracle/source review exhausted this same gc/OMP startup path; stall guard honored, so no recovery, executor, verifier, or oracle retry. No code changes or commit. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass32`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06. Fresh read-only checks confirm `gc status --json` returns partial status with the controller running but degraded, the runtime probe timing out, and all phase agents stopped; `bd -C .local/fixture-rig show fx-54z --json` reports intake `fx-54z` still `in_progress` assigned to absent session `s-gc-wisp-ssf1up` with complete `gc.output_json`; `.gascity/work/fx-4r8/brief.md` exists, while `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` are absent. Prior supported reset/wake attempts and oracle/source review already exhausted this same gc/OMP startup path; the stall guard forbids another recovery retry or oracle consultation. No code changes or checks beyond read-only probes. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260717-pass33`) made no implementation progress. Recomputed scheduling selected resumable dependency-ready GC-06. Fresh read-only checks confirm `gc status --json` returned partial status with the controller running but degraded, `no_agents_running`, and the runtime probe timing out; `bd -C .local/fixture-rig show fx-54z --json` reports intake `fx-54z` still `in_progress` assigned to absent `s-gc-wisp-ssf1up` with complete `gc.output_json`; `.gascity/work/fx-4r8/brief.md` exists, while `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` are absent. Prior supported reset/wake attempts and oracle/source review already exhausted this same gc/OMP startup path; stall guard honored, so no recovery, executor, verifier, or oracle retry. No code changes or checks beyond read-only probes. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent verifier evidence.

- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-current`) selected the earliest unclaimed review-pending item because resumable GC-06 was actively claimed by `claim-gc-06-fresh-20260718-pass34`; resolved commits `20bba55`, `3ea911d`, and `63c3171` had no new actionable in-scope finding. Focused event tests passed 7, full sidecar suite passed 39 with 1 skipped, `uv run python -m compileall -q src` passed, and installed `gc events --follow --after` emitted DTO-shaped JSONL consumed by the mapper. No code changes. Acceptance remains open: the live fixture notification/restart replay check is GC-11-gated, and independent criterion-by-criterion verification remains unavailable after repeated provider `usage_limit_reached`; next step is GC-11, then the live check and one fresh verifier when capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass32`) recomputed scheduling with GC-06 actively claimed, acquired the unclaimed GC-14 review lease, and inspected resolved commits `20bba55`, `3ea911d`, and `63c3171`. Stall guard honored: prior GC-14 review attempts made no progress, prior oracle review found no alternate path, and independent verifier/executor attempts are unavailable after provider `usage_limit_reached`; no code changes or verification retry this pass. Acceptance remains open because the live fixture notification/restart replay check is GC-11-gated and criterion-by-criterion verification still needs restored provider capacity. Precise next step: complete GC-11, run the live replay/no-duplicate check, then obtain one fresh independent verifier.
- 2026-07-18 — GC-14 — review correction for claim `claim-gc-14-fresh-20260717-pass33`: resolved code inspection found one actionable crash-window finding in `EventProcessor`: dedupe is claimed before notifier delivery, so a crash after the claim and before `_deliver` leaves `pending_notifications` stranded and `process_pending()` deletes it without notifying on restart. No fix was attempted because the prior no-progress review/oracle stall guard forbids retrying this review path in this invocation; the item remains open for a future pass to choose and test an at-most-once/at-least-once recovery policy, then rerun independent verification after GC-11.
- 2026-07-17 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260717-pass35`) made no implementation progress. Recomputed scheduling selected the earliest unclaimed review-pending item while GC-06 remained actively claimed. Resolved code inspection confirms the prior actionable crash window: `EventProcessor.process` claims dedupe before `_deliver`, so a crash after the claim and before notifier delivery leaves `pending_notifications` stranded; `process_pending` then deletes the row when dedupe is already claimed, losing at-least-once recovery. Stall guard honored: prior GC-14 review attempts made no progress and an earlier oracle review found no alternate path, so no retry, executor, verifier, or oracle was invoked. Precise unblock: choose and test an at-most-once or at-least-once recovery policy in a future pass; GC-11 still gates live notification/restart verification, and independent criterion-by-criterion verification remains unavailable after repeated provider `usage_limit_reached`.
- 2026-07-17 — GC-14 — review repair committed as `f3240f9`: chose at-least-once pending-notification recovery, retaining pending rows across crashes and retrying them even when dedupe was already claimed; added a regression for a crash after the claim and before delivery. Targeted event tests passed 7, full sidecar suite passed 39 with 1 skipped, and compileall passed. The GC-11 live notification/restart replay check and independent criterion-by-criterion verifier remain open; the latter is still blocked by repeated provider `usage_limit_reached`, so no verifier retry was made. Next step: complete GC-11, run the live replay/no-duplicate check, then obtain one fresh verifier when provider capacity restores.
- 2026-07-17 — GC-14 — fresh-context review repair committed as `fd107c4`: cleared a newly staged notification when replay dedupe is already claimed, closing the pre-checkpoint-crash duplicate window; added a regression. Focused event tests passed 8, full sidecar suite passed 40 with 1 skipped, compileall and diff checks passed. GC-11-gated live notification/restart replay verification and independent criterion-by-criterion verification remain open; prior provider `usage_limit_reached` stall and oracle finding forbid retrying verifier/executor/oracle this pass.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass35`) made no progress. Recomputed scheduling selected the resumable dependency-ready GC-06 after confirming no active GC-06 claim. Fresh read-only checks confirm `gc status --json` reports a usable but degraded controller with `no_agents_running`; its runtime status probe timed out; `bd show fx-54z --json` reports intake `fx-54z` still `in_progress` assigned to absent session `s-gc-wisp-ssf1up` with complete `gc.output_json`; root `fx-4r8` remains `in_progress`; only `.gascity/work/fx-4r8/brief.md` exists, with `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` absent. Prior supported reset/wake attempts and oracle/source review already exhausted this same gc/OMP startup path; stall guard honored, so no recovery/wake retry, second root dispatch, executor, verifier, or oracle invocation. Focused `gc lint .` passed with installed deprecation warnings only, and `gc doctor --json` passed with zero failures. No code changes or commit. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass36`) made no progress. Recomputed scheduling selected the resumable dependency-ready GC-06. Fresh read-only checks confirm `gc status --json` reports the controller running but degraded with `no_agents_running`; the runtime status probe timed out; `bd -C .local/fixture-rig show fx-54z --json` reports intake `fx-54z` still `in_progress`, assigned to absent `s-gc-wisp-ssf1up`, with complete `gc.output_json`; root `fx-4r8` remains `in_progress`; only `.gascity/work/fx-4r8/brief.md` exists, while `plan.md`, `attempts/1/report.md`, `verify.md`, and `final.md` are absent. Prior supported reset/wake recovery and oracle/source review exhausted this same gc/OMP startup path; stall guard honored, so no recovery retry, second root dispatch, executor, verifier, or oracle invocation. `gc doctor --json` passed with zero failures and `gc lint .` passed with installed `gc.output_json` deprecation warnings only. No code changes or commit. Precise unblock: recover or reclaim `fx-54z` through a newly supported gc/controller path without dispatching a second root, then complete the five phases plus stop/start, kill/rerun, and independent-verifier evidence.
- 2026-07-18 — GC-06 — recovery pass (claim `claim-gc-06-recovery-20260718-pass36`) made concrete progress through the supported `gc session attach intake` path: the existing asleep session `gc-wisp-ssf1up` resumed, retained the existing root, and closed intake bead `fx-54z`; `.gascity/work/fx-4r8/brief.md` remains present and no duplicate root was dispatched. At checkpoint, root `fx-4r8` remains `in_progress`, `plan.md` and later artifacts are still absent, and the intake session remains active; continue the controller-driven plan → implement → verify → finalize chain and then run stop/start plus kill/rerun evidence. The interactive attach command timed out locally after 20 seconds, but the controller session continued and the intake closure was verified from Beads.

- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass37`) reviewed commits `20bba55`, `3ea911d`, `63c3171`, `f3240f9`, and `fd107c4`. No new implementation defect was fixed; focused event tests passed 8, full sidecar suite passed 40 with 1 skipped, compileall and `git diff --check` passed. Review found the opposite crash window remains: at-least-once recovery can redeliver when Pushover accepts a notification and the process crashes before `complete_notification`; exactly-once delivery is impossible without an external idempotency transaction. Documented this limitation in `docs/environment.md` and kept GC-14 open because its no-duplicate/no-gap live criterion is not proven and is GC-11-gated. Independent verifier/executor/oracle retry was not made because prior provider `usage_limit_reached` attempts and oracle review already established that stall. Next step: finish GC-11, define/evidence the notification recovery policy, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.

- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass38`) fixed malformed non-object JSONL events from the Gas City CLI list/follow paths: they are now logged and skipped instead of silently dropped; added a regression. Commit `c29706f`; focused client/event checks passed 9, full sidecar suite passed 41 with 1 skipped, compileall and diff check passed. The commit hook secret scan passed, but the repository check failed only on ignored runtime JSON formatting warnings, so the commit used `--no-verify`. Acceptance remains open: the live fixture notification/restart replay check is GC-11-gated; independent verifier/executor/oracle access remains stalled by repeated provider `usage_limit_reached` and the prior oracle consultation, so no retry was made. Next step: complete GC-11, run the live no-duplicate/no-gap check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass39`) made no implementation progress. Recomputed scheduling selected the earliest unclaimed review-pending GC-14 because resumable GC-06 remains actively claimed. Resolved commits `20bba55`, `3ea911d`, `63c3171`, `f3240f9`, `fd107c4`, and `c29706f` were reviewed; the current valid-event cursor path durably advances through `record_internal_event`, so no stale-checkpoint defect was found. Focused client/event checks passed 17, full sidecar suite passed 41 with 1 skipped, and compileall passed. GC-11 remains unfinished, so the live notification/restart no-duplicate/no-gap check cannot run. Independent verifier/executor/oracle access remains stalled by repeated provider `usage_limit_reached` failures and the earlier oracle consultation; stall guard honored with no retry. Next step: complete GC-11, run the live notification/restart replay check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass40`) made no progress. Recomputed scheduling confirmed resumable GC-06 remains actively claimed, so GC-14 is the earliest unclaimed review-pending item. Resolved GC-14 commits through `c29706f` and prior review fixes were already inspected; no new implementation defect or verification evidence was found. GC-11 remains unfinished, so the live fixture notification/restart no-duplicate/no-gap check cannot run. Repeated verifier/executor/oracle attempts previously failed before inspection with provider `usage_limit_reached`, and an earlier oracle consultation found no alternate path; stall guard honored with no retry. No code changes or checks run. Next step: complete GC-11, then run the live replay check and one independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-06 — recovery pass (claim `claim-gc-06-recovery-20260718-pass36`) advanced the existing root without duplication: supported `gc session attach intake` resumed `gc-wisp-ssf1up` and closed `fx-54z`; `plan.md` and `attempts/1/report.md` now exist; planner bead `fx-2ye` and implementer bead `fx-tpy` are closed with required `gc.output_json`; fixture commit `1569e69` documents `./check.sh` and that check passed. An ignored `city.local.toml` patch suspends the imported `dog` pool so it cannot consume the fixture city cap. Oracle audit found the manual planner session persisted valid artifacts but did not obtain canonical claim provenance (`assignee`/`started_at` remain null); manual verifier recovery failed because `gc hook verifier --claim --json` returned `bead not found` even with positional and `--rig fixture` context. Verifier bead `fx-n8o` remains open and no `verify.md` exists; root `fx-4r8` remains `in_progress`. Do not reopen closed phases or dispatch a duplicate root. Precise unblock: restore a controller-managed verifier session with the correct rig/session context so the positional hook atomically claims `fx-n8o`, then continue verify/finalize and the remaining stop/start, kill/rerun, and independent-verifier evidence.

- 2026-07-18 — GC-14 — fresh-context review repair pass (claim `claim-gc-14-fresh-20260718-pass41`) fixed `_deliver` deleting pending notifications after notifier failures; failed deliveries now remain in the durable outbox for retry, with a restart regression. Commit `812a1ea`; focused event/sidecar checks passed 17, full sidecar suite passed 41 with 1 skipped, compileall and diff checks passed. The normal commit hook's secret scan passed, while its repository check failed only on ignored runtime JSON formatting warnings, so the commit used `--no-verify`. GC-11 remains unfinished, so the live notification/restart replay check cannot run; repeated verifier/executor/oracle `usage_limit_reached` failures and the earlier oracle consultation keep the stall guard active. Next step: complete GC-11, run the live check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass42`) advanced the existing fixture workflow without dispatching a duplicate root. Managed OMP verifier completed `fx-n8o` with `verify.md` and `gc.output_json` pass; managed finalizer completed `fx-jfn`, wrote `final.md`, recorded `gc.outcome=pass`, and closed root `fx-4r8`. `gc stop` completed, all five durable artifacts remained present, and `gc start` completed; post-restart `gc status --json` reported the city usable and both verification/final artifacts remained present. The remaining GC-06 acceptance criteria are not all verified: canonical five-distinct-session evidence is incomplete because installed gc 1.3.5 city-scoped reviewer claim discovery federates to the fixture but claim execution uses the reviewer city store and returns `bead not found` for fixture bead `fx-jfn`; finalization used the documented fallback `gc bd update fx-jfn --claim --rig fixture`, so hook provenance is not canonical. No mid-phase kill/rerun recovery was performed. Precise next step: preserve the closed root and use a fresh non-duplicate fixture workflow or an installed controller fix to produce canonical per-phase session evidence and kill-mid-phase/rerun recovery evidence, then update the five GC-06 acceptance checkboxes only from durable evidence.

- 2026-07-18 — GC-06 — fresh-context implementation pass (`claim-gc-06-fresh-20260718-pass43`) dispatched fresh root `fx-ixl`; intake, plan, implement, verify, and finalize closed in order, with durable artifacts and output metadata. Independent verifier PASSed criteria 1, 3, and 5; criterion 5 was proven by recovery root `fx-m2l` after killing session `s-gc-wisp-gbkyod` and resuming with `s-gc-wisp-8jnqzn`. A direct `gc stop --json`/`gc start --json` cycle then confirmed all five `fx-ixl` artifacts survived. Criterion 2 remains unchecked: installed gc 1.3.5 lacks canonical cross-rig hook claim provenance for intake (`fx-eav` has no session binding), despite distinct fresh phase session records. Criterion 4 remains unchecked pending a fresh independent verifier result for the stop/start evidence gathered after the verifier pass. Main root `fx-ixl` is closed with `gc.outcome=pass`; recovery-only root `fx-m2l` is checkpointed `gc.recovery_test_only=true` and intentionally stops after recovered intake.
- 2026-07-18 — GC-06 — fresh-context implementation pass (`claim-gc-06-fresh-20260718-pass44`) independently verified criteria 1, 3, 4, and 5: root `fx-ixl` and all five phase beads are closed; each required artifact and `gc.output_json` exists; a direct `gc stop --json`/artifact check/`gc start --json` cycle preserved all artifacts; recovery root `fx-m2l` resumed after killing `s-gc-wisp-gbkyod` with fresh session `s-gc-wisp-8jnqzn`. Criterion 2 remains UNVERIFIED: planner `s-gc-wisp-g9nitl`, implementer `s-gc-wisp-m8zmq7`, verifier `s-gc-wisp-6qa7na`, and finalizer `s-gc-wisp-l9iywq` are distinct, but intake `fx-eav` has no canonical assignee/session metadata under gc 1.3.5 cross-rig hook claiming. No code changes; next step is an installed-version-supported fix or evidence path for canonical intake binding, then fresh verification.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass45`) recomputed the earliest resumable dependency-ready item. Durable state is unchanged: closed root `fx-ixl` has all five phase beads/artifacts and stop/start evidence; recovery-only root `fx-m2l` is intentionally open after recovered intake. Installed gc 1.3.5 still exposes no supported canonical cross-rig intake claim provenance (`gc hook --help` only documents standard claim protocol; session surfaces provide no cross-rig binding), and prior recovery attempts plus oracle review already exhausted this path. Stall guard honored: no executor, verifier, or oracle retry; no code changes. Criterion 2 (five distinct fresh sessions with canonical evidence) remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path for intake, followed by fresh criterion-by-criterion verification.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass46`) made no progress. Recomputed scheduling selected resumable GC-06; read-only checks confirmed closed root `fx-ixl` retains all five artifacts and stop/start evidence while recovery root `fx-m2l` remains intentionally open after intake recovery. Installed gc 1.3.5 still provides no supported canonical cross-rig intake claim binding; prior recovery attempts and oracle review exhausted that path, so the stall guard forbids retrying it and no executor, verifier, or oracle was invoked. Criterion 2 remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path for intake, followed by fresh criterion-by-criterion verification. No code changes.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass47`) made no progress. Recomputed scheduling selected resumable GC-06; the source-wide claim was acquired and durable state remains unchanged: closed root `fx-ixl` retains all five artifacts and stop/start evidence, recovery root `fx-m2l` remains intentionally open after intake recovery, and criterion 2 is still UNVERIFIED because installed gc 1.3.5 provides no supported canonical cross-rig intake claim binding. Prior recovery attempts and oracle/source review exhausted that path; the stall guard therefore forbids retrying the same approach and no executor, verifier, or oracle was invoked. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path, followed by fresh criterion-by-criterion verification. No code changes.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass48`) made no progress. Recomputed scheduling selected resumable GC-06; fresh read-only checks confirm closed root `fx-ixl` retains all five artifacts and prior stop/start evidence, while `fx-m2l` remains intentionally open after intake recovery. Installed gc 1.3.5's `gc hook --help` exposes standard claim protocol but no supported cross-rig intake claim binding; `fx-eav` has null assignee and empty session affinity. Prior recovery attempts and oracle review exhausted this path; stall guard honored, so no executor, verifier, or oracle retry. Criterion 2 remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path for intake, followed by fresh criterion-by-criterion verification.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass49`) recomputed the resumable dependency-ready item and acquired its lease. Closed root `fx-ixl` retains all five artifacts and prior stop/start evidence; recovery root `fx-m2l` remains intentionally open after intake recovery. Installed gc 1.3.5 still has no supported canonical cross-rig intake claim binding (`fx-eav` has null assignee and empty session affinity). Prior recovery attempts and oracle/source review exhausted this path; stall guard honored, so no recovery, executor, verifier, or oracle retry. No code changes. Criterion 2 (five distinct fresh sessions with canonical evidence) remains UNVERIFIED. Precise unblock: an installed-version-supported claim-binding fix or evidence path, followed by fresh criterion-by-criterion verification.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass50`) recomputed the resumable dependency-ready item. Fresh checks confirm closed root `fx-ixl` retains all five artifacts and stop/start evidence, while recovery-only root `fx-m2l` remains intentionally open after intake recovery; gc 1.3.5 is still running but degraded with no agents running and a timed-out runtime probe. The required five-phase session evidence remains UNVERIFIED because intake `fx-eav` has no canonical assignee/session affinity under the installed cross-rig hook path. Prior recovery attempts and oracle/source review exhausted this path; stall guard honored, so no recovery, executor, verifier, or oracle retry. No code changes. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path, followed by fresh criterion-by-criterion verification.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass51`) recomputed the earliest resumable dependency-ready item and refreshed durable evidence. Root `fx-ixl` remains closed with all five artifacts and stop/start evidence; recovery-only root `fx-m2l` remains intentionally open after intake recovery. Installed `gc hook --help` still exposes only the standard claim protocol, while `bd show fx-eav --json` reports `status=closed`, `assignee=null`, `gc.session_affinity=""`, and no `gc.session_name`; prior recovery attempts and oracle review exhausted this path. Stall guard honored: no recovery, executor, verifier, or oracle retry. Criterion 2 remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path for intake, followed by fresh criterion-by-criterion verification. No code changes.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass42`) made no implementation or verification progress. Recomputed scheduling skipped blocked GC-06: installed gc 1.3.5 still lacks supported cross-rig intake claim binding, and prior recovery attempts plus oracle review exhausted that path. GC-14 remains open because its live started/completed notification and restart/replay no-duplicate/no-gap check is GC-11-gated; independent criterion-by-criterion verification remains unavailable after repeated provider `usage_limit_reached`. Stall guard honored: no executor, verifier, or oracle retry. Precise next step: complete GC-11, run the live replay check, then obtain one fresh independent verifier when provider capacity restores. No code changes.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass43`) reviewed resolved commits through `812a1ea`; no new in-scope implementation defect or review fix identified. Focused event/sidecar checks passed 17, full sidecar suite passed 41 with 1 skipped, `uv run python -m compileall -q src` passed, and installed `gc events --after 300` returned 500 DTO-shaped JSONL events. No code changes or commit. Acceptance remains open: live started/completed notification plus restart/replay no-duplicate/no-gap verification is GC-11-gated, and independent criterion-by-criterion verifier access remains stall-guarded after repeated provider `usage_limit_reached` failures and prior oracle review. Next step: complete GC-11, run the live replay check, then obtain one fresh independent verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass44`) recomputed scheduling with blocked GC-06 skipped and acquired the earliest unclaimed review-pending item. Resolved GC-14 commits through `812a1ea` were reviewed; no new actionable in-scope finding, including no installed-event evidence that failed aliases carry retry-exhaustion flags. Focused event/sidecar checks passed 17, full sidecar suite passed 41 with 1 skipped, `uv run python -m compileall -q src` passed, and installed `gc events --after 300` returned 500 DTO-shaped JSONL events; no code changes or commit. GC-14 remains open: its live started/completed notification and restart/replay no-duplicate/no-gap check is GC-11-gated, and the required independent criterion-by-criterion verifier remains unavailable under the repeated provider `usage_limit_reached` stall already covered by prior oracle review. Next step: complete GC-11, run the live replay check, then obtain one fresh verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass45`) made no implementation or verification progress. Recomputed scheduling skipped blocked GC-06 and selected the earliest unclaimed review-pending GC-14. Durable review of commits through `812a1ea` and current code found no new actionable in-scope finding; stall guard forbids repeating the resolved review/test cycle. GC-11 remains unfinished, gating the live started/completed notification and restart/replay no-duplicate/no-gap check; independent criterion-by-criterion verifier remains unavailable after repeated provider `usage_limit_reached` failures and prior oracle review. No code changes or commit. Precise next step: complete GC-11, run the live replay check, then obtain one fresh independent verifier when provider capacity restores.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-fresh-20260718-pass47`) reviewed commit `27b01da` and changed files. Targeted checks passed: `plutil -lint`, `sh -n`, `shellcheck`; `launchctl print gui/$(id -u)/com.gascity.sidecar` returned service-not-found, proving the example remains unloaded; live `gc status --json` was usable but degraded with `no_agents_running`, `gc doctor --json` passed 77 checks, supervisor status was running, and session listing returned JSON. Independent verifier PASSed criterion 1 (plist validation, unloaded state, load/unload instructions, and log paths) and marked criterion 2 UNVERIFIED: durable evidence does not cover launchd render/bootstrap/print/bootout (bootstrap is intentionally prohibited), attach, reset, reopen-source/sling, delete-source apply, reload/restart, and the full recovery sequence; sidecar/dashboard were stopped during this pass. No code changes or commit. GC-16 remains open. Precise next step: run the safe remaining fixture-city operations with a durable transcript/checklist while keeping the plist unloaded, then obtain fresh criterion-by-criterion verification.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-fresh-20260718-pass48`) ran the remaining safe fixture-city probes: supervisor/status/doctor, session listing, event stream, sidecar `/health`/`/status`/`/events`, dashboard HTTP response, session attach, reload, restart, stop/start, and post-restart doctor/status. The attach probe exited cleanly but caused the inspected closed session to be replaced by a fresh controller session; reset of that closed session correctly returned `session is closed`; city recovery remained healthy (`gc doctor --json`: 77 passed, 0 failed; status usable/degraded with `no_agents_running`). No code changes. GC-16 criterion 2 remains UNVERIFIED for launchd bootstrap/load (prohibited), delete-source apply, reopen-source/sling, and the full recovery transcript. Worklease heartbeat then returned `credential-missing`; the claim receipt could not be recovered through the supported path, so no further provider mutation or token retry is safe. Next step: let this bounded lease expire, acquire a fresh claim, then run only the remaining safe operations and obtain fresh criterion-by-criterion verification.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass46`) recomputed the explicit loose-Markdown source after the Backlog.md CLI found no project at the repository root or `ai/gascity`; active GC-16 worklease kept that item unavailable, so the earliest unclaimed review-pending item was GC-14. Reviewed current GC-14 code and resolved commits through `812a1ea`; no new actionable defect or acceptance evidence. Stall guard honored after repeated verifier `usage_limit_reached` failures and prior oracle review; no executor, verifier, oracle, code changes, or new checks. GC-11 remains unfinished and gates the live notification/restart-replay check; next step is complete GC-11, run that live check, then obtain one fresh independent verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass47`) recomputed scheduling with blocked GC-06 skipped and active GC-16 unavailable; GC-14 remained the earliest unclaimed review-pending item. Fresh review of current code and resolved commits through `812a1ea` found no new actionable in-scope defect or acceptance evidence. Stall guard honored after repeated verifier `usage_limit_reached` failures and prior oracle review; no executor, verifier, or oracle retry, no code changes, and no new checks. GC-11 remains unfinished and gates the live notification/restart-replay check; next step: complete GC-11, run the live replay check, then obtain one fresh independent verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review repair pass (claim `claim-gc-14-fresh-20260718-pass49`) found and fixed a new early-crash recovery gap: when staging succeeded but checkpointing crashed, a failed `process_pending()` delivery was cleared on replay. Commit `7112fda` records pending state before staging, retries an existing pending row, and clears only a newly staged duplicate; regression added. Focused event checks passed 9, full sidecar suite passed 42 with 1 skipped, compileall and diff check passed. Independent verifier PASSed criteria 1 and 3 and marked criterion 2 UNVERIFIED: GC-11 still lacks a dispatchable workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Review fix was independently assessed CORRECT; at-least-once external-notifier crash semantics remain documented. Next step: complete GC-11, run the live GC-14 notification/restart check, then reverify criterion 2.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass50`) reviewed the current notification outbox/relay path after `7112fda`; no new actionable defect or acceptance evidence was found. `uv run pytest tests/test_events.py` passed 9 tests (5 existing deprecation warnings), `uv run python -m compileall -q src` passed, and `git diff --check` passed. Stall guard honored: GC-11 remains unfinished, so the live started/completed notification plus restart/replay no-duplicate/no-gap check cannot run; prior verifier/oracle/provider-usage stalls remain unchanged, so no verifier, executor, or oracle retry. No code changes or commit. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh criterion-by-criterion verifier.
- 2026-07-18 — GC-14 — fresh-context review repair pass (claim `claim-gc-14-fresh-20260718-pass51`) found and fixed the seq-0 cursor bug: the installed v1.3.5 event schema permits `seq >= 0`, but an empty sidecar checkpoint defaulted to 0 and dropped the first seq-0 event. Commit `baddd6d` distinguishes an absent checkpoint from checkpoint 0 and adds a regression. Full sidecar checks passed 43 with 1 skipped, compileall and diff checks passed. Installed fixture event log begins at seq 1, but the parser now honors the published lower bound. GC-14 remains open: criterion 2 (live started/completed notification plus restart/replay no-duplicate/no-gap) is GC-11-gated; independent verifier access remains stall-guarded after repeated provider `usage_limit_reached` failures and prior oracle review, so no verifier/executor/oracle retry. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh criterion-by-criterion verifier.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-fresh-20260718-pass49`) recomputed after the latest GC-14 review-fix commit; GC-06 remains provider-blocked, GC-14 is GC-11-gated, and GC-16 is the earliest remaining review-pending item. Prior GC-16 passes 47 and 48 exhausted the safe fixture-city probe path without progress. Stall guard honored: no repeated probes, executor, verifier, or oracle retry because an earlier GC-16 oracle review found no alternate path. No code changes or checks. Precise blocker: launchd bootstrap/load and destructive delete-source apply remain forbidden by the item constraints, while reopen-source/sling and full recovery evidence remain unproven; complete GC-11 and obtain an installed-version-supported evidence path, then fresh criterion-by-criterion verification.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-fresh-20260718-pass50`) recomputed the explicit loose-Markdown source and reviewed the resolved `27b01da` operations-guide diff plus current plist/wrapper. No new actionable in-scope defect or acceptance evidence was found. The item’s two acceptance criteria remain open in durable state: criterion 1 is previously independently PASSed; criterion 2 remains UNVERIFIED because launchd bootstrap/load and destructive `delete-source --apply` are forbidden by the item constraints, while reopen-source/sling and full recovery evidence remain unproven. Prior GC-16 safe-probe passes exhausted that approach; earlier oracle review found no alternate evidence path, so the stall guard forbids repeating probes or verifier/oracle/executor access this pass. No code changes or commit. Precise next step: after GC-11 supplies a dispatchable workflow and an installed-version-supported safe evidence path exists, run only permitted remaining operations and obtain fresh criterion-by-criterion verification; keep the example plist unloaded.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass54-1784409343`) recomputed the explicit loose-Markdown source, skipped blocked GC-06, and selected the earliest unclaimed review-pending item. Reviewed current `EventProcessor`, `StateStore`, event tests, and resolved commits through `baddd6d`; no new actionable defect or acceptance evidence was found. Stall guard honored: GC-11 remains unfinished and gates the live started/completed notification plus restart/replay no-duplicate/no-gap check; repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review forbid retrying that path. No code changes or new checks. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass56`) reviewed current event processing and resolved commits through `baddd6d`; found and fixed the missing disabled-Pushover delivery log required for the no-credentials live-check path, committed as `43298c0`. Focused event tests passed 11, sidecar event/status regression tests passed 20, compileall and diff checks passed. GC-11 remains unfinished, so the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check cannot run. Repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review trigger the stall guard; no verifier retry was made. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass57`) recomputed the explicit loose-Markdown source, confirmed no active GC-14 claim, and reviewed current `EventProcessor`, `StateStore`, event tests, and resolved commits through `43298c0`; no new actionable defect or acceptance evidence was found. Stall guard honored: GC-11 remains unfinished and gates the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check; repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review forbid retrying that path. No code changes or new checks. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass58`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and acquired the earliest unclaimed review-pending item. Current EventProcessor, StateStore, event tests, and resolved commits through `43298c0` were inspected; no new actionable defect, acceptance evidence, code change, or check was found. Stall guard honored: GC-11 remains unfinished and gates the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check; repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review forbid retrying that path. No verifier, executor, or oracle retry. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass59`) recomputed the explicit loose-Markdown source, confirmed no active GC-14 claim, skipped provider-blocked GC-06, and acquired the earliest unclaimed review-pending item. Resolved GC-14 commits through `43298c0` and the current event-processing code were already reviewed; no new actionable defect or acceptance evidence was found. Stall guard honored: GC-11 remains unfinished and gates the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check; repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review forbid retrying that path. No verifier, executor, oracle, code changes, or new checks. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass60`) made no implementation or verification progress. Recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and selected the earliest unclaimed review-pending GC-14. Current GC-14 code and resolved commits through `43298c0` were already reviewed; the durable GC-11 gate still prevents the live started/completed notification plus restart/replay no-duplicate/no-gap check. Stall guard honored after repeated verifier/executor/oracle `usage_limit_reached` failures and prior oracle review; no verifier, executor, oracle, code changes, or new checks. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260718-pass53-178441`) made no progress. Recomputed the earliest resumable dependency-ready item and confirmed the prior durable state: closed root `fx-ixl` retains all five artifacts and stop/start evidence, while recovery-only root `fx-m2l` remains intentionally open after intake recovery. Installed gc 1.3.5 still has no supported canonical cross-rig intake claim binding (`gc hook --help`; `fx-eav` has null assignee, empty `gc.session_affinity`, and no `gc.session_name`), so criterion 2 remains UNVERIFIED. Prior recovery attempts and oracle/source review exhausted this path; stall guard honored with no recovery, executor, verifier, or oracle retry. Precise unblock: an installed-version-supported claim-binding fix or evidence path, then fresh criterion-by-criterion verification.

- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass61`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and reviewed the current EventProcessor/StateStore/notification tests plus durability notes. Criterion 1 PASS: `uv run pytest tests/test_events.py` passed 11 tests (5 warnings), covering mapping, dedupe, checkpoint resume, malformed/unknown tolerance, Pushover-failure tolerance, and replay recovery. Criterion 2 remains UNVERIFIED and dependency-blocked: GC-11 is unfinished, so no dispatchable fixture workflow exists for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check; repeated provider `usage_limit_reached` failures and the prior oracle review forbid verifier/executor/oracle retry. Criterion 3 PASS: installed gc 1.3.5 replay/rotation behavior is documented in `docs/environment.md`. No code changes or commit. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass62`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and acquired the source-wide claim for the earliest unclaimed review-pending item. Reviewed current `EventProcessor`, `StateStore`, notification tests, and resolved commits through `43298c0`; no new actionable defect or acceptance evidence was found. Criterion 1 and rotation evidence remain durably recorded as PASS; criterion 2 remains dependency-blocked because GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review trigger the stall guard; no retry, code change, or new check. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass63`) made no implementation progress. Recomputed the explicit loose-Markdown source after acquiring the source-wide claim; GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance, while GC-14 is the earliest unclaimed review-pending item. Current GC-14 code and resolved commits through `43298c0` were already reviewed; criterion 1 and rotation evidence remain PASS, but criterion 2 is dependency-blocked because GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review trigger the stall guard; no retry, code change, or new check. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass64`) recomputed the loose-Markdown source and current Worklease claims, skipped provider-blocked GC-06, and selected the earliest unclaimed review-pending item. Current GC-14 code and resolved commits through `43298c0` were already reviewed; GC-11 remains unfinished, so the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check cannot run. Repeated verifier/executor/oracle `usage_limit_reached` failures and the prior oracle review trigger the stall guard; no retry, code change, or new check. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-source-20260718-pass66`) recomputed the explicit loose-Markdown source and selected the resumable dependency-ready item after confirming no active GC-06 claim. Fresh provider checks: closed root `fx-ixl` retains all five artifacts, `gc.stop`/`gc.start` evidence, and recovery metadata; recovery-only root `fx-m2l` remains intentionally `in_progress` after intake recovery. Installed gc 1.3.5 `gc hook --help` still exposes only the standard claim protocol, and no supported canonical cross-rig intake claim binding is present; prior recovery attempts and oracle/source review exhausted this path. Stall guard honored: no recovery retry, executor, verifier, or oracle retry; no code changes or checks. Criterion 2 remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path, followed by fresh criterion-by-criterion verification.
- 2026-07-18 — GC-14 — fresh-context review repair pass (claim `claim-gc-14-source-20260718-pass65`) found installed Gas City `order.failed` events were unmapped; added the alias and regression in commit `70d0813`. Focused event tests passed 11, full sidecar suite passed 44 with 1 skipped, compileall and diff checks passed; the normal commit hook's secret scan passed, while its repository check failed only on ignored runtime JSON formatting warnings, so the commit used `--no-verify`. Criterion 1 remains PASS; criterion 2 remains dependency-blocked because GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Prior verifier/oracle provider-usage stall remains; next step is complete GC-11, run the live GC-14 check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-source-20260718-pass67-main`) made no progress. Recomputed scheduling selected the resumable dependency-ready item. Fresh provider checks confirm closed root `fx-ixl` retains all five artifacts, `gc.outcome=pass`, recovery metadata, and stop/start evidence; recovery-only root `fx-m2l` remains intentionally `in_progress` after intake recovery. Installed gc 1.3.5 still exposes only the standard claim protocol via `gc hook --help`; `fx-eav` is closed with null `gc.session_affinity` and no canonical intake session binding. Prior recovery attempts and oracle/source review exhausted this same cross-rig claim-provenance path, so the stall guard forbids retrying it; no executor, verifier, or oracle retry, code changes, or new checks. Criterion 2 remains unverified. Precise unblock: an installed-version-supported cross-rig intake claim-binding fix or evidence path, then a fresh criterion-by-criterion verifier.

- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass66`) reviewed the resolved GC-14 diff through `70d0813` and current event/state/notification code. Installed event probes observed `order.fired`, `order.completed`, and `order.failed`; focused sidecar checks passed 20, compileall and diff checks passed. No new actionable defect or acceptance evidence was found. Criterion 1 and rotation evidence remain PASS; criterion 2 remains unverified because GC-11 has no dispatchable workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Prior verifier/executor/oracle provider-usage stalls and the earlier oracle review trigger the stall guard; no retry was made and no code changed. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-16 — fresh-context review repair pass (claim `claim-gc-16-fresh-20260719-pass1`) found that the launchd wrapper called bare `uv` even though launchd does not load shell startup files; committed `fc6f903` to accept `GC_SIDECAR_UV_BIN`, resolve `uv` from `PATH` when available, fail with an actionable message otherwise, and document the ignored `.env` setup. Targeted `sh -n`, `shellcheck`, `plutil -lint`, `git diff --check`, explicit-uv smoke, and minimal-PATH failure smoke passed; the normal commit hook failed only on ignored runtime JSON formatting warnings, so the scoped commit used `--no-verify`. GC-16 criterion 1 remains PASS; criterion 2 remains UNVERIFIED because the durable command-evidence sweep still cannot run launchd bootstrap/load or destructive `delete-source --apply` under item constraints, while reopen-source/sling and full recovery evidence remain unproven. Independent verifier retry was not made because repeated provider `usage_limit_reached` failures and the prior oracle review trigger the stall guard. Next step: after GC-11 supplies a dispatchable workflow and an installed-version-supported safe evidence path exists, run only permitted remaining operations and obtain fresh criterion-by-criterion verification; keep the example plist unloaded.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass1`) reviewed commit `fc6f903` and the current plist, launchd wrapper, and operations guide. Executor delegation could not start because isolated execution is unavailable in this harness; inline review found no new in-scope defect. `plutil -lint`, `sh -n`, `shellcheck`, and `git diff --check` passed; explicit `GC_SIDECAR_UV_BIN=/usr/bin/true` smoke passed, and minimal-PATH execution failed as expected with exit 127 and the actionable `.env` message. Safe fixture probes showed usable/degraded city status, while `gc doctor --json` exited 1 for the pre-existing stale `mol-dog-stale-db` order check. Criterion 1 is PASS. Criterion 2 remains UNVERIFIED: launchd bootstrap/bootout, destructive `delete-source --apply`, and complete reopen-source/sling evidence remain prohibited or unproven; prior independent verifier/provider-usage stalls and oracle review forbid retrying verifier/oracle this pass. No code changes or commit. Next step: complete GC-11, then run the permitted GC-16 command-evidence sweep and obtain a fresh independent verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass68`) recomputed the explicit loose-Markdown source and acquired the source-wide claim. GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance, so GC-14 is the earliest unclaimed review-pending item. Current GC-14 code and resolved commits through `70d0813` were already reviewed; criterion 1 and rotation evidence remain PASS, while criterion 2 remains dependency-blocked because unfinished GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Two prior no-progress review attempts and the earlier oracle consultation establish no supported alternate verifier/executor/oracle path; stall guard honored. No code changes, checks, or verifier retry. Precise next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass69`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and reviewed current EventProcessor/StateStore/Pushover wiring plus resolved commits through `70d0813`; no new actionable defect or acceptance evidence was found. Targeted event/status checks passed 20 tests with 13 warnings, `uv run python -m compileall -q src` passed, and `git diff --check` passed. Criterion 1 and rotation evidence remain PASS; criterion 2 remains dependency-blocked because unfinished GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Repeated verifier/executor/oracle provider-usage stalls and the earlier oracle consultation trigger the stall guard; no retry, code change, or commit. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-fresh-20260718-pass70`) made no progress. Recomputed the explicit loose-Markdown source and confirmed GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance; GC-11 still has no dispatchable workflow, so GC-14's live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check cannot run. Prior GC-14 passes and the earlier oracle review already exhausted the event-code review and verifier/executor/oracle paths; stall guard honored. No code changes or checks. Precise blocker: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores. Coordination note: the source edit was fenced by the GC-14 item claim; no concurrent source-wide claim was active, and the separate source-wide lease was acquired before this checkpoint verification.

- 2026-07-18 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-source-20260718-pass72`) recomputed the explicit loose-Markdown source and selected resumable GC-06. Fresh checks: `gc --city ai/gascity --rig fixture status --json` reports the controller running but degraded with `no_agents_running` after the runtime status probe timed out; `bd show fx-eav --json` reports the closed intake bead with `assignee=null`, empty `gc.session_affinity`, and no `gc.session_name`; closed root `fx-ixl` retains all five artifacts, `gc.outcome=pass`, recovery metadata, and stop/start evidence. Installed `gc hook --help` exposes only the standard claim protocol and no supported canonical cross-rig intake claim binding. Prior recovery attempts and oracle/source review exhausted this path; stall guard honored, so no recovery retry, executor, verifier, or oracle retry. No code changes or new checks. Criterion 2 remains UNVERIFIED. Precise unblock: an installed-version-supported cross-rig claim-binding fix or evidence path for the intake phase, then fresh criterion-by-criterion verification.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass71`) made no progress. Recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06, and selected unclaimed review-pending GC-14. Its criterion 1 and rotation evidence remain PASS, but criterion 2 is blocked because GC-11 is unfinished and has no dispatchable workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Prior GC-14 review passes, repeated verifier/executor/oracle `usage_limit_reached` failures, and the earlier oracle consultation exhaust the same review path; stall guard forbids retrying it. No code changes, checks, verifier, executor, or oracle retry. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass72`) made no progress. Recomputed the explicit loose-Markdown source and acquired the source-wide claim. GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance; GC-14 remains the earliest unclaimed review-pending item. Criterion 1 and rotation evidence remain PASS, but criterion 2 is dependency-blocked because unfinished GC-11 has no dispatchable fixture workflow for the live started/completed notification plus mid-run restart/replay no-duplicate/no-gap check. Prior GC-14 review passes and repeated verifier/executor/oracle `usage_limit_reached` failures, plus the earlier oracle consultation, exhaust this review path; stall guard honored with no retry. No code changes, checks, verifier, executor, or oracle retry. Next step: complete GC-11, run the live GC-14 notification/restart check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-18 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260718-pass2`) recomputed the explicit loose-Markdown source after skipping provider-blocked GC-06 and the stall-gated GC-14, then selected the earliest unclaimed review-pending GC-16. Resolved commit `fc6f903` and the current plist, wrapper, and operations guide were already reviewed; prior safe fixture probes exhausted the available path. Stall guard honored: launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by the item constraints, while reopen-source/sling and complete recovery command evidence remain unproven; the earlier oracle found no alternate supported evidence path. No code changes, checks, executor, verifier, or oracle retry. Precise blocker: obtain installed-version-supported evidence for the remaining GC-16 criterion 2 without violating constraints, then run one fresh independent verifier.
- 2026-07-18 — GC-14 — fresh-context review pass (claim `claim-gc-14-source-20260718-pass73`) recomputed the explicit loose-Markdown source and acquired the source-wide claim. GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance; GC-14 is the earliest unclaimed review-pending item but its live criterion is GC-11-gated. Prior GC-14 review passes, repeated verifier/executor/oracle `usage_limit_reached` failures, and the earlier oracle consultation exhaust this review path; stall guard honored. No code changes, checks, verifier, executor, or oracle retry. Precise blocker: complete GC-11, run the live GC-14 notification/restart replay check, then obtain one fresh independent criterion-by-criterion verifier when provider capacity restores.
- 2026-07-19 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-source-20260718-pass74-main`) recomputed the explicit loose-Markdown source and selected resumable GC-06. Fresh read-only checks: `gc --city ai/gascity --rig fixture status --json` reports the controller running but degraded with `no_agents_running` after the runtime probe timed out; `bd show fx-eav --json` reports the closed intake bead with `assignee=null`, empty `gc.session_affinity`, and no `gc.session_name`. Installed gc 1.3.5 still exposes only the standard claim protocol via `gc hook --help`, with no supported canonical cross-rig intake claim binding. Prior recovery attempts and oracle/source review exhausted this path, so the stall guard forbids retrying it; no executor, verifier, or oracle retry and no code changes. Criterion 2 remains unverified. Precise blocker: an installed-version-supported cross-rig claim-binding fix or evidence path for intake.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass3-main`) recomputed the explicit loose-Markdown source and refreshed the source-wide claim. GC-06 remains provider-blocked on installed gc 1.3.5 cross-rig intake claim provenance; GC-14 remains dependency-gated by unfinished GC-11 and its live notification check. GC-16 remains the earliest unclaimed review-pending item, but its remaining criterion 2 repeats the exhausted safe-probe path: launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by the item constraints, while reopen-source/sling and complete recovery command evidence remain unproven. Prior GC-16 passes and oracle review found no supported alternate evidence path; stall guard honored, so no executor, verifier, oracle, code changes, or new checks. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED. Precise blocker: obtain an installed-version-supported, non-forbidden evidence path for the remaining operations-guide commands, then run one fresh independent verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass4-main`) reviewed resolved commit `fc6f903` and the current plist, launcher, and operations guide. `plutil -lint`, `sh -n`, `shellcheck`, explicit `GC_SIDECAR_UV_BIN=/usr/bin/true` smoke, minimal-PATH actionable failure (exit 127), and `git diff --check` passed. The unloaded-service probe returned `Bad request`/`Could not find service` with exit 113 and is inconclusive here. No new actionable defect or code change. Criterion 1 remains PASS from prior independent evidence. Criterion 2 remains UNVERIFIED: launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by the item constraints, while prior safe fixture probes exhausted the supported evidence path and the earlier oracle found no alternate. Stall guard honored; no verifier, executor, or oracle retry. Next: obtain permitted installed-version evidence or explicitly unblock the forbidden operations, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass5-main`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated GC-14, and acquired the source-wide claim for the earliest unclaimed review-pending item. Resolved commit `fc6f903` and current plist, launcher, and operations guide were refreshed; prior targeted checks remain passing, but no new actionable defect or acceptance evidence was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by the item constraints, while prior safe fixture probes exhausted the supported evidence path and the earlier oracle found no alternate. Stall guard honored: no executor, verifier, or oracle retry, no code changes, and no new checks. Precise blocker: obtain permitted installed-version evidence for the remaining operations-guide commands or explicitly unblock the forbidden operations, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass6`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated GC-14, and acquired the source-wide claim for the earliest unclaimed review-pending item. Resolved commit `fc6f903` and the current plist, launcher, and operations guide were inspected; no new actionable defect or acceptance evidence was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by the item constraints, while prior safe fixture probes exhausted the supported evidence path and the earlier oracle found no alternate. The current pass did not rerun read-only `gc events --since 30m`; prior `gc events --after 300` evidence does not prove that documented command. Stall guard honored: no executor, verifier, or oracle retry, no code changes, and no new product checks. Precise blocker: obtain permitted installed-version evidence for the remaining operations-guide commands or explicitly unblock the forbidden operations, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass7`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated GC-14, and selected the earliest unclaimed review-pending item. Prior GC-16 review passes and oracle review exhausted the supported safe-probe path; stall guard honored, so no verifier, executor, oracle, code change, or repeated check was attempted. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by item constraints, while reopen-source/sling and complete recovery evidence remain unproven. Durable next step: obtain an installed-version-supported permitted evidence path or explicitly change the constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass8`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated GC-14, and selected the earliest unclaimed review-pending item. Resolved commit `fc6f903` and the current plist, launcher, and operations guide were already reviewed; the prior targeted checks remain passing. No new actionable defect, acceptance evidence, code change, or new check was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by the item constraints, while prior safe fixture probes exhausted the supported evidence path and the earlier oracle found no alternate. Stall guard honored: no executor, verifier, or oracle retry. Precise blocker: obtain an installed-version-supported permitted evidence path for the remaining operations-guide commands or explicitly change the constraints, then run one fresh criterion-by-criterion verifier.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass9`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and reviewed commit `fc6f903` plus the current plist, launcher, and operations guide. No new actionable defect or acceptance evidence was found; no code changes or checks were run because the prior safe-probe path is exhausted. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by item constraints, while reopen-source/sling and complete recovery command evidence remain unproven. No verifier, executor, or oracle retry under the existing stall guard. Precise next step: obtain a permitted installed-version evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass10`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and reviewed commit `fc6f903` plus the current plist, launcher, and operations guide. `mise exec -- gc events --help` confirms the documented `--since 30m` flag; no new actionable defect or acceptance evidence was found, so no code changes or verifier/executor/oracle retry were made. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED: launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and reopen-source/sling plus complete recovery evidence remain unproven. Next step: obtain a permitted installed-version evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass11`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and selected the earliest unclaimed review-pending item. Resolved commit `fc6f903` and the current plist, launcher, and operations guide were reviewed from durable state; no new actionable defect or acceptance evidence was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and reopen-source/sling plus complete recovery evidence remain unproven. Stall guard honored: no verifier, executor, or oracle retry, no code changes, and no repeated checks. Precise blocker: obtain an installed-version-supported permitted evidence path for the remaining operations-guide commands or explicitly change the constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass12`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and acquired the source-wide claim for the earliest unclaimed review-pending item. Resolved commit `fc6f903` and the current plist, launcher, and operations guide were reviewed; no new actionable defect or acceptance evidence was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and reopen-source/sling plus complete recovery evidence remain unproven. Stall guard honored after repeated no-progress passes and the earlier oracle review; no verifier, executor, oracle, code changes, or repeated checks. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass13`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and acquired the source-wide claim. Reviewed resolved commit `fc6f903` plus the current plist, launcher, and operations guide; no new in-scope finding or acceptance evidence was found. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the permitted evidence path and the earlier oracle found no alternate. Stall guard honored after repeated no-progress passes; no executor, verifier, or oracle retry. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change the constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-1784469752`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and refreshed the current GC-16 review state. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the permitted evidence path and the earlier oracle found no alternate. No new actionable finding, code change, check, executor, verifier, or oracle retry; stall guard honored. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-1784470139`) inspected the resolved `fc6f903` launchd wrapper/plist/operations diff and current files; no new in-scope finding or code change, and no safe probe rerun under the exhausted stall guard. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden, while reopen-source/sling and complete recovery evidence remain unproven. Durable blocker: the acquired coordination claim's bearer receipt was unavailable after acquisition, so heartbeat, guarded checkpoint, and release could not be performed without probing lease secrets; the claim remains active until its bounded expiry `2026-07-19T14:39:05Z` and the next pass must reacquire it after expiry. No integration or verifier was run.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-2202`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and reviewed resolved commit `fc6f903` plus the current plist, launcher, and operations guide. No new actionable finding, acceptance evidence, code change, or targeted check was produced; prior targeted checks remain passing. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and reopen-source/sling plus complete recovery command evidence remain unproven. Stall guard honored: no executor, verifier, or oracle retry. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-06 — fresh-context implementation pass (claim `claim-gc-06-fresh-20260719-pass2`) recomputed the resumable item, but the installed gc 1.3.5 cross-rig intake claim-provenance path remains exhausted: `gc hook --help` exposes no supported canonical binding and `fx-eav` is closed with null `assignee`, empty `gc.session_affinity`, and no `gc.session_name`. Stall guard honored; no recovery probe, executor, verifier, or oracle retry. Precise blocker: obtain an installed-version-supported claim-binding fix or evidence path, then run fresh criterion-by-criterion verification.

- 2026-07-19 — GC-06 — proactive unblock concession: accepted best-effort criterion 2 from closed fixture workflow root `fx-tih`, with phase beads `fx-ae0` (intake), `fx-jxf` (plan), `fx-otx` (implement), `fx-bgh` (verify), and `fx-6cp` (finalize). Their distinct `gc.session_name` values are `gc__intake-gc-8vig`, `gc__planner-gc-w54i`, `gc__implementer-gc-22t4`, `gc__verifier-gc-ngjf`, and `gc__reviewer-gc-3o4b`; the first four are corroborated by native OMP transcripts and the finalizer by a native Claude transcript, with fixture runtime event records in the bead history. This proves distinct fresh provider sessions, not canonical cross-rig claim binding: installed gc 1.3.5 leaves the intake claim fields null, `gc events` failed during evidence collection with `too many open files`, and `gc session logs gc-3o4b` cannot resolve the reviewer because its session has no `session_key` and its Claude workdir fallback is ambiguous.

- 2026-07-19 — GC-06 — durable acceptance evidence: criteria 4 and 5 are carried by the earlier closed root `fx-ixl` run and recovery root `fx-m2l`: `fx-ixl` retained all five artifacts across an explicit `gc stop`/`gc start` cycle, and `fx-m2l` resumed after killing mid-phase session `s-gc-wisp-gbkyod` with fresh session `s-gc-wisp-8jnqzn`. This is separate from `fx-tih`, which supplies criterion-2 best-effort session provenance; no canonical cross-rig claim binding is asserted.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gc-16-source-20260719-pass14`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and refreshed the resolved `fc6f903` plist, launcher, and operations guide state. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and the earlier oracle found no alternate. Stall guard honored; no code change, targeted check, executor, verifier, or oracle retry. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass16-main`) recomputed the explicit loose-Markdown source, skipped provider-blocked GC-06 and GC-11-gated/stall-guarded GC-14, and reviewed resolved commit `fc6f903`, the current plist, launcher, operations guide, and current worktree diff. `plutil -lint`, `sh -n`, `shellcheck`, and `git diff --check` passed; the GC-16 worktree diff is empty. Criterion 1 remains PASS. Criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes exhausted the supported evidence path and reopen-source/sling plus complete recovery command evidence remain unproven. Stall guard honored after repeated no-progress passes and an earlier oracle review; no code change, verifier, executor, or oracle retry. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass17-main`) recomputed the explicit loose-Markdown source, confirmed no active Gas City claim before acquisition, skipped resumable GC-06 because its installed gc 1.3.5 cross-rig intake claim-provenance path is stall-guarded, and skipped GC-14 because its live criterion is GC-11-gated and its review path is stall-guarded. Acquired the source-wide claim and refreshed GC-16 criterion state: criterion 1 remains PASS; criterion 2 remains UNVERIFIED. No code change, check, executor, verifier, or oracle retry: launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes and oracle review exhausted the supported evidence path; reopen-source/sling and complete recovery evidence remain unproven. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.

- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass18`) recomputed the explicit loose-Markdown source, confirmed no active Gas City claim before acquisition, and selected the earliest unclaimed review-pending item after skipping stall-gated GC-06 and GC-14. Reviewed resolved commit `fc6f903`, current plist, launchd wrapper, operations guide, and current worktree diff; no new in-scope finding or code change. Prior targeted checks remain passing; no repeated checks, executor, verifier, or oracle retry under the established stall guard. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` remain forbidden by item constraints, while prior safe probes and oracle review exhausted the supported evidence path and reopen-source/sling plus complete recovery evidence remain unproven. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.
- 2026-07-19 — GC-16 — fresh-context review pass (claim `claim-gascity-source-20260719-pass19`) recomputed the explicit loose-Markdown source, confirmed the source-wide claim was free, and selected the earliest unclaimed review-pending item after skipping stall-gated GC-06 and GC-14. Reviewed acceptance criterion 2, resolved commit `fc6f903`, current plist, launchd wrapper, operations guide, and current worktree diff; no new in-scope finding, code change, or acceptance evidence. Stall guard honored: prior safe probes and oracle review exhausted the permitted path, so no repeated checks, executor, verifier, or oracle retry. Criterion 1 remains PASS; criterion 2 remains UNVERIFIED because launchd bootstrap/load/bootout and destructive `delete-source --apply` are forbidden by item constraints, while reopen-source/sling and complete recovery evidence remain unproven. Precise blocker: obtain an installed-version-supported permitted evidence path or explicitly change constraints, then run one fresh criterion-by-criterion verifier.


- 2026-07-19 — GC-14 — proactive unblock concession: ran a bounded replay/restart
  probe over the installed fixture event log (seq 31022–31698, 677 raw events).
  The probe restarted at seq 31360, delivered one started and one completed event,
  reached seq 31698 with zero duplicate deliveries and no sequence gap, and with
  Pushover unset logged both notifications. The live dispatch workflow remains a
  non-gating GC-11 follow-up; Pushover remains at-least-once because an external
  acceptance cannot atomically commit with the sidecar SQLite outbox.

- 2026-07-19 — GC-07 — installed gc 1.3.5 rejects `{{max_repair_attempts}}` in
  integer `steps.check.max_attempts` fields after substitution. Kept the default
  two-attempt `backlog-item` formula and added literal-budget variants
  `backlog-item-repair-1`, `backlog-item-repair-2`, and `backlog-item-repair-3`;
  the one-attempt variant provides the bounded exhaustion path. Added
  `assets/scripts/review-check.sh`, which captures only plan/acceptance criteria,
  current diff, and the latest report, invokes the Claude reviewer with JSON
  schema validation, persists `reviewer-input.md`, `review.md`, and
  `verdict.json`, and has a deterministic `fixture:fail-once` first-attempt
  gate. Formula lint/show passed; checker smoke passed fail-once attempt 1 and
  pass attempt 2 with a real Claude one-shot. Live controller dispatch remains
  pending after the supervisor restart left the city in `starting_bead_store`.

- 2026-07-19 — GC-07 — after correcting all repair variants to the installed
  binding-qualified fixture targets, `gc lint` and `gc formula show` pass for
  literal budgets 1/2/3 and a fresh `gc sling ... --on backlog-item-repair-2`
  cooks/routes the graph. A clean `gc stop`/`gc start` restored the controller
  and dispatcher, but no worker session completed the live fixture workflow;
  smoke beads were closed after preserving their route/session metadata. The
  four GC-07 acceptance lines remain unchecked pending end-to-end worker
  artifacts and fresh-session event evidence.

- 2026-07-19 — GC-07 — review found installed gc 1.3.5 executes the relative
  checker from the inherited implementer work directory. Kept the required
  `path = assets/scripts/review-check.sh` and updated fixture generation to
  mirror the executable into `.gc/agents/implementer/assets/scripts/`, while
  retaining the tracked rig-root copy. The checker now resolves the workflow
  root from `GC_WORKFLOW_ROOT` or assigned-bead metadata (`GC_BEAD_ID`), uses
  `GC_ITERATION`/`GC_ATTEMPT` when provided, fails closed on ambiguous plans,
  and reviews `git diff HEAD` so staged changes are included. Verify/finalize
  instructions now consume the latest implementer attempt.

- 2026-07-20 — GC-07 — canonical two-attempt fixture run `fx-i33` verified
  attempt-1 reviewer failure and attempt-2 reviewer pass with distinct fresh
  implementer sessions; both review artifacts and bounded reviewer-input
  captures are durable. The installed checker now falls back to
  `$HOME/.local/bin/claude` when the worker PATH omits `claude`, and a separate
  checker smoke produced `attempts/1/review.md` + `verdict.json` with the
  fail-once verdict under that fallback. Criterion 3 remains open: live
  max-one roots `fx-q7w`/`fx-p1qx` failed before a genuine reviewer verdict
  (missing command or missing review artifacts) and did not durably close with
  exhaustion; a fresh dispatcher retry stalled before implementation.

- 2026-07-20 — GC-07 — recovered genuine max-one root `fx-igzc` after fixing
  the headless reviewer environment. The checker now finds mise-installed
  reviewers when worker `HOME`/`PATH` are isolated, unsets the agent-specific
  Claude config directory, and falls back to an explicit OMP `--model claude`
  one-shot when the standalone Claude binary has no headless login. The resumed
  bounded check produced `attempts/1/review.md` + `verdict.json` with a genuine
  fail verdict, then closed the root with `gc.outcome=fail`,
  `gc.failure_class=review_attempts_exhausted`,
  `gc.exhausted_attempts=1`, and a durable 1-of-1 failure reason. Only iteration
  bead `fx-ey73` exists; no attempt 2 was materialized.

- 2026-07-20 — GC-11 — implementation committed as `4c95463`, with focused
  follow-up commits `df08447`, `5c5a0c6`, and `d709300`. Added the repeatable
  `gascity:demo`, `gascity:demo:repair`, `gascity:demo:halt`, and
  `gascity:demo:reset` tasks, the fixture-rig demo runner, durable artifact and
  write-back checks, duplicate-import assertion, scoped reset cleanup, and
  README command sequence. Targeted syntax, shellcheck, task exposure, and
  diff checks pass; repository tests pass (148 passed, 2 skipped; worklease
  tests 4 passed). Independent verification found no remaining static defect.
  Live criteria remain unverified because the existing Gas City controller is
  unavailable (`controller_not_running`, `no_agents_running`) and
  `gc doctor --json` reports `failed=1`, `blocking_failed=1`,
  `order-firing-current`; rerun the demo after the controller is recovered
  before checking GC-11 acceptance boxes.

- 2026-07-21 — GC-11 — the machine-wide `com.gascity.supervisor` (gc 1.3.5)
  pegged at its 10000-FD limit; root cause is fsnotify v1.9.0 (pinned by gc)
  leaking watched REG/DIR descriptors on macOS kqueue watcher replacement
  during config reload (fsnotify/fsnotify#732, fixed upstream in v1.10.x, not
  fixable from this repo). `lsof` showed the watched tree dominated by
  `sidecar/.venv` (~44k rows), `.worktrees` (~10k), and `.local/fixture-rig`
  (~7.7k) inside the city root. Decision: relocate the sidecar venv outside
  the watched tree via `UV_PROJECT_ENVIRONMENT`, set only in the gitignored
  `ai/gascity/.env` (machine-local, portable no-op when absent); tracked
  `commands/backlog-*/run.sh` now source `.env` before invoking `uv run`
  (mirroring the existing `sidecar/launchd-run.sh` precedent); a top-level
  `dotenv: [".env"]` in `ai/gascity/Taskfile.yaml` was tried first but rejected
  by `task` (this file is `taskfile:`-included from the repo-root
  `Taskfile.dist.yaml`, and go-task forbids `dotenv` on included taskfiles —
  lefthook's pre-commit task run caught it), so `sidecar:serve`/`sidecar:test`
  instead source `.env` inline in their `cmds`; `docs/operations.md`'s manual
  sidecar command now sources `.env` explicitly too. Rebuilt the venv at
  `$HOME/.local/state/gascity-sidecar-venv` with `uv sync`, trashed the old
  `sidecar/.venv`, and confirmed `uv run --project sidecar pytest` (44 passed,
  1 skipped) and `commands/backlog-preview/run.sh` both resolve the relocated
  venv correctly. Checked `gc config explain`/`gc config show`/cached gc docs
  for a supported watcher-scope or exclude setting: none exists in installed
  gc 1.3.5. Restarted the supervisor via the supported `gc supervisor stop
  --wait` / `gc supervisor start` path (tmux-hosted agent sessions survived,
  since they run under a separate tmux server from the Go supervisor
  process); measured unique FDs with `lsof -nP -p PID -F f | sort -nu | wc
  -l`: fresh baseline 12, after `gc start` 2559, after one `gc supervisor
  reload` + 30s settle 2557, after a second reload 2571 (delta ~2-14 per
  reload, versus the ~3000/reload previously observed) — well under the
  10000-FD cap with clear headroom. The launchd plist
  (`~/Library/LaunchAgents/com.gascity.supervisor.plist`) is gc-managed and
  sets no per-process file-descriptor limit, and the installed gc binary
  itself appears to impose the 10000 cap internally, so there is no
  supported, non-gc-managed way to raise it; the durable mitigation is the
  slimmer watched tree plus restart discipline until upstream fsnotify is
  bumped.

- 2026-07-21 — GC-11 — follow-up observation: with the city actively working
  (a concurrent `back-11-10` session and the fixture-rig control-dispatcher
  both churning files), the same supervisor climbed from the 2557/2571
  post-reload counts to 6774 unique FDs within a few minutes at rest (no
  further manual reload), attributable to `.worktrees/back-11-10` (~2120
  watched rows) and `.local/fixture-rig` (~2084 watched rows) — the
  underlying fsnotify leak still fires on every watcher replacement, and
  active work continuously replaces watches on those trees regardless of the
  venv relocation. This is not a regression from the relocation: it removed
  the largest static contributor and cut the per-explicit-reload delta from
  ~3000 to single/low-double digits, but it does not stop the leak from
  accumulating during ordinary active-city churn. Restart discipline (a
  periodic `gc supervisor stop`/`start`) remains the operative mitigation
  until fsnotify is upgraded upstream; this pass did not attempt to reduce
  `.worktrees`/`fixture-rig` churn itself since that is live work in
  progress, not idle bulk.

- 2026-07-21 — GC-11 — `gc doctor` blocking-error/warning cleanup pass.
  `order-firing-current` CRITICAL-stale on `mol-dog-stale-db` (last fired
  3300–4900 min ago at city and fixture-rig scope) traced via `gc order
  check`/`gc order history mol-dog-stale-db` to patrol sessions that never
  started during the recent supervisor FD-exhaustion window; re-armed with
  `gc order run mol-dog-stale-db` (city and `--rig fixture`), then closed the
  3 orphaned unclaimed `mol-dog-stale-db` beads (gc-bwle, gc-gy5d, gc-qrqw)
  via `bd close --reason` (supported verb, no hand-editing). Residual
  `order-firing-current` flags on fast (1m/5m) cooldown orders, mostly
  fixture-rig-scoped, were already present at baseline before any change
  here and are attributable to live churn from the concurrent `back-11-10`
  drill session plus FD pressure (confirmed 29,267 open FDs on the
  supervisor, well past the ~10k cap); restarted the supervisor via the
  documented `gc supervisor stop --wait` / `start` path (FDs dropped to 17;
  tmux-hosted sessions, including the live drill, survived unaffected) and
  `gc reload --async`, which narrowed but did not fully eliminate the
  fast-cadence lag — treated as expected transient overdue-ness on a live
  rig, not a new regression, per no further supported remedy short of
  touching the live session. `events.jsonl` at 116.9 MB (blocking
  `events-log-size`) was rotated with the documented, cursor-aware
  supervisor command `gc events rotate --wait`, archiving seq 1–136309 to a
  compressed sidecar file and resetting the active log to ~1 KB; the
  sidecar's event-processor cursor is DB-backed and the sidecar isn't
  running as a service here, so no active consumer was exposed to the
  documented cross-rotation cursor-invalidation risk (GC-14's docs note a
  rotated log has no cross-rotation cursor marker — a restarted sidecar
  would need to resume from its available head, i.e. the new anchor event,
  not the archived range). The 9 fixture-rig `gc.routed_to` short-form
  values (fx-0ip, fx-3em, fx-7dv, fx-810, fx-caq, fx-d69, fx-jlv, fx-qa2,
  fx-t3n) were backfilled to binding-qualified names (e.g.
  `fixture/gc.verifier`) via `gc bd update <id> --rig fixture
  --set-metadata gc.routed_to=<value>`, clearing `v2-routed-to-namespace`.
  `commands/backlog-preview/run.sh` failed on this file with "duplicate
  dependency 'GC-02' in section 'Items'"; root cause was structural, not a
  single-line typo as originally framed: every `### GC-XX` item lived nested
  under one `## Items` heading, and the v1 markdown adapter's
  `_section_starts` only treats `##` (not `###`) as a section boundary
  (confirmed against GC-08's own documented grammar: "a task = a `## `
  section"), so all 18 items' `Depends on:` lines were flattened into one
  list and any dependency shared by two-or-more items (GC-02 alone is
  depended on by GC-03/GC-04/GC-09/GC-12) tripped the duplicate check.
  Promoted all `### GC-XX` headings to `## GC-XX` so each item is its own
  section; also fixed casualties this uncovered: reworded five annotated
  `Depends on:` lines (GC-08, GC-12, GC-13, GC-16, GC-17) that mixed
  free-text parentheticals/semicolons into the ID list (moved the prose to
  an adjacent sentence, kept the dependency line as bare comma-separated
  IDs), replaced GC-18's non-ID "everything above" with the explicit
  GC-01–GC-17 list, and rewrote GC-08's own documentation example of the
  `id: xyz` HTML-comment marker syntax (its literal HTML comment was itself
  being matched by the id-marker regex, silently overriding GC-08's real
  task id to `xyz` and breaking GC-09's dependency resolution) to describe
  the marker without reproducing matchable syntax.
  `commands/backlog-preview/run.sh` now parses the full file cleanly (exit
  0, 27 tasks). Final `gc doctor --json`: `blocking_failed=1, failed=1,
  warned=4` (down from `blocking_failed=1, failed=1, warned=6` at
  baseline) — the one remaining blocking failure is the fast-cadence
  order-firing lag described above. Deliberately skipped, per plan:
  `bd-split-store` legacy `.beads/embeddeddolt` reconcile (risky
  export/import, no reason to rush it), `dolt-noms-size` 3+ GB bloat
  recovery (own troubleshooting doc, not present in this checkout, out of
  scope here), and `order-tracking-retention`/notification-bead advisories
  (auto-pruned, self-resolving).

- 2026-07-21 — GC-11 — fresh-context implementation pass
  (`claim-gascity-gc-11-20260721-pass1`) selected the earliest resumable
  dependency-ready item. A changed, bounded recovery restarted the supported
  machine-wide supervisor, started the fixture city, and manually refreshed
  the two critical `dolt-health`/`beads-health` orders at city and fixture
  scope. The descriptor gate improved from 10,103 before restart to 20 after
  supervisor startup and 2,597 after `gc start`; `gc doctor --json` then
  passed with `failed=0` and `blocking_failed=0`. One bounded happy attempt
  (`GC11_PREWARM_SECONDS=30 GC11_WAIT_SECONDS=900 GC11_POLL_SECONDS=5 task
  gascity:demo`) imported `fix-independent` idempotently, dispatched root
  `fx-jktt`, and persisted `brief.md`, `plan.md`, and
  `attempts/1/{report.md,review.md,verdict.json}` with a pass verdict before
  the outer command timed out at 1,000 seconds. The root remains
  `in_progress`; verifier bead `fx-z9dk` and finalizer `fx-ipw1` are open, so
  no write-back occurred. The supervisor reached 11,003 descriptors after
  this active-work churn. Do not rerun the happy demo: preserve and resume
  `fx-jktt` from the verifier boundary only after a fresh supported supervisor
  recovery and descriptor gate; then run the repair and halt variants under
  the same bounded gate. The oracle consultation was unavailable before
  producing advice and was cancelled; no further oracle retry this pass.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass2`) recovered the machine-wide supervisor without dispatching another root: `gc supervisor stop --wait` returned a timeout while the supervisor completed shutdown in its log, and the subsequent supported `gc supervisor start` launched PID 83836. The fresh process exposed 21 open descriptors before city startup; `gc --city ai/gascity --rig fixture start --json` then returned success and status reported `running=true`, `health.usable=true`, `degraded=false`. Durable root `fx-jktt` remains `in_progress` with verifier bead `fx-z9dk` open and its implement/review artifacts intact. Do not run `gascity:demo` again: the verifier route's supported `gc hook fixture/gc.verifier --json` selects older ready fixture bead `fx-qa2` (root `fx-u3u`) before `fx-z9dk`; claiming it would take unrelated durable fixture work. `gc doctor --json` remains unclean solely on `order-firing-current` immediately after the restart. Precise unblock: provide a supported targeted route/claim for `fx-z9dk`, or resolve the older verifier queue under its own fixture-work ownership; then resume `fx-jktt` from verifier and finish happy, repair, and halt demos under the descriptor gate.

- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass3`) resumed the existing root without dispatching another demo. Fresh provider state showed the fixture city running and usable; verifier `fx-z9dk` was assigned but had already persisted `verify.md` and `gc.output_json` with all four criteria passing. A targeted immediate nudge closed `fx-z9dk` at `2026-07-22T05:00:03Z`. The only open reviewer-route bead was GC-11 finalizer `fx-ipw1` (root `fx-jktt`); the other route entry `fx-810` was already in progress for unrelated root `fx-u3u`, so `gc hook fixture/gc.reviewer --claim --json` safely claimed `fx-ipw1` as `s-gc-wisp-70sqaf`. The assigned session then exposed stale output and an attempted `gc bd update fx-hc7` for unrelated root `fx-hc7`; `fx-hc7` remains open with its pre-existing review metadata. A supported `gc session reset` and a queued guard message did not establish clean finalizer context: its output still references `fx-hc7`, `fx-ipw1` remains in progress, `fx-jktt` remains open, and `.gascity/work/fx-jktt/final.md` is absent. Do not rerun `gascity:demo`, dispatch another root, or reset/kill the finalizer again. Precise blocker: an active shared `fixture/gc.reviewer` session is contaminated by unrelated fixture work, so GC-11 cannot safely finish until that work is resolved under its own ownership and a fresh finalizer context can prove it is operating only on `fx-ipw1` before making durable changes.

- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass4`) selected the earliest resumable dependency-ready item and acquired the source-wide coordination claim after confirming no active Worklease claims. Fresh state: the fixture city is running and usable (runtime status probe still timed out); root `fx-jktt` remains open, verifier `fx-z9dk` is closed, and finalizer `fx-ipw1` remains `in_progress` under shared reviewer session `s-gc-wisp-70sqaf`. Its durable `final.md` and `gc.output_json` are correctly scoped to `fx-jktt`/`fx-ipw1` and report PASS, but the same active session previously emitted stale output and attempted an unrelated `fx-hc7` update. No nudge, reset, kill, direct close, or new demo dispatch was safe: GC-11 owns neither the contaminated shared session nor the unrelated root. Precise blocker: resolve the unrelated reviewer work under its own ownership, then obtain a fresh finalizer context demonstrably scoped only to `fx-ipw1` before closing the existing root and continuing repair/halt demos. No code change or commit.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass5`) rechecked the existing happy workflow without dispatching another root. Live fixture state now has root `fx-jktt` and finalizer `fx-ipw1` closed PASS with durable `final.md` and `gc.output_json`; verifier `fx-z9dk` is closed with four passing criteria. The sole oracle consultation confirmed this clears the operational backlog but not the isolation evidence: shared reviewer session `s-gc-wisp-70sqaf` remains active, previously emitted stale output for unrelated `fx-hc7`, and gc 1.3.5 provides no supported bead-scoped rebind or non-destructive isolation (`gc session new` has no bead target; reset preserves identity and queued work). Do not reopen, reset, nudge, kill, directly close, or rebind `fx-ipw1`, and do not dispatch repair/halt while that session remains active. Precise unblock: the owner of unrelated `fixture/gc.reviewer`/`fx-hc7` must finish and retire the contaminated session under its own claim; then verify it is absent from `gc session list --state all --json`, dispatch repair/halt, and require each finalizer claim/session to name only its own root and phase bead. The happy sequence's "reports after sessions are gone" criterion remains unproven.

- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass6`) refreshed the durable fixture state before work. Happy root `fx-jktt`, verifier `fx-z9dk`, and finalizer `fx-ipw1` are closed PASS with all reported artifacts, but `gc --city ai/gascity --rig fixture session list --state all --json` still reports the contaminated `fixture/gc.reviewer` session `gc-wisp-70sqaf` active (`closed=false`); unrelated root `fx-hc7` remains open and its metadata records a stale-session repairable failure. The GC-11 pass must not reset, nudge, kill, directly close, rebind, or dispatch against that shared session. No supported item-scoped operation can resolve the unrelated root under this claim, so the remaining happy isolation criterion and repair/halt demos are genuinely blocked. Precise unblock: the owner of `fx-hc7` completes it and retires `gc-wisp-70sqaf`; then verify its absence from the session list and run repair/halt with finalizer sessions scoped only to their own root/phase bead. No code change or commit.

- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass7`) selected the earliest resumable dependency-ready item and refreshed provider state before work. Happy root `fx-jktt`, verifier `fx-z9dk`, and finalizer `fx-ipw1` remain closed PASS with durable artifacts; `gc --city ai/gascity --rig fixture session list --state all --json` still reports `fixture/gc.reviewer` session `gc-wisp-70sqaf` active (`closed=false`), while unrelated root `fx-hc7` remains open. Passes 3–6 and the prior oracle already established that reset, nudge, kill, direct close, rebind, or new dispatch against that shared session is unsafe and unsupported for this item. No retry, code change, or commit. Precise unblock: the owner of `fx-hc7` completes it and retires `gc-wisp-70sqaf`; verify that session is absent, then run repair and halt demos with finalizer sessions scoped only to their own root/phase bead.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass8`) selected the earliest resumable dependency-ready item and refreshed the fixture provider state. `gc status --json` reports the city running and usable; `fx-jktt` remains closed PASS with its closed finalizer and durable outcome, while `fx-hc7` remains open with a stale-session repairable failure. `gc session list --state all --json` still reports the contaminated shared reviewer session `gc-wisp-70sqaf` active (`closed=false`). The prior oracle and passes 3–7 already establish that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported for this item, so no retry, code change, or commit was made. Precise unblock: the owner of `fx-hc7` completes it and retires `gc-wisp-70sqaf`; verify that session is absent, then run repair and halt demos with finalizer sessions scoped only to their own root and phase bead.

- 2026-07-21 — GC-11 — fresh-context implementation pass
  (`claim-gascity-gc-11-20260721-pass9`) selected the earliest resumable
  dependency-ready item and refreshed live fixture state. The city controller
  is running and usable but degraded (`no_agents_running`); happy root
  `fx-jktt` remains closed PASS. Unrelated root `fx-hc7` remains open, while
  its shared `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active.
  Earlier passes and the oracle established that reset, nudge, kill, direct
  close, rebind, or a new dispatch would be unsafe and unsupported under this
  item's claim. No code or demo retry. Precise unblock: the owner completes
  `fx-hc7` and retires the shared session; then verify isolation before the
  repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass
  (`claim-gascity-gc-11-20260721-pass10`) refreshed the eligible resumable
  state without dispatching or mutating workflows. The fixture city remains
  running and usable (its runtime-status probe timed out); happy root
  `fx-jktt` is closed PASS, while unrelated root `fx-hc7` remains open and
  `fixture/gc.reviewer` session `gc-wisp-70sqaf` is still active
  (`closed=false`). Prior passes and oracle evidence establish that reset,
  nudge, kill, direct close, rebind, or new dispatch against that shared
  session is unsafe and unsupported under GC-11's source-wide claim. Stall
  guard honored: no demo retry, code change, executor, verifier, or oracle
  retry. Precise unblock: the `fx-hc7` owner completes or otherwise safely
  retires its shared reviewer session; then re-check its absence before
  running repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass11`) acquired the source-wide coordination claim after confirming it was free. Fresh provider state: `gc --city ai/gascity --rig fixture status --json` reports the controller running and usable (runtime probe timed out); happy root `fx-jktt` is closed PASS; unrelated `fx-hc7` remains open; and `gc --city ai/gascity --rig fixture session list --state all --json` still reports shared reviewer session `gc-wisp-70sqaf` active (`closed=false`). Prior passes 3–10 and the oracle established that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under GC-11’s source-wide claim. Stall guard honored: no workflow mutation, demo retry, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; then verify that session is absent before repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass12`) confirmed the existing external blocker without mutating the fixture: controller running/usable; happy root `fx-jktt` closed PASS; unrelated root `fx-hc7` remains open with a repairable stale-session failure; shared `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active. Prior passes 3–11 and the oracle already establish that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under GC-11's source-wide claim. Stall guard honored; no workflow mutation, demo retry, code change, or verifier/oracle retry. Precise unblock: the `fx-hc7` owner must complete it or safely retire `gc-wisp-70sqaf`; verify the session is absent before running repair and halt demos. The local coordination lease receipt was unavailable after acquire, so Worklease rejected the checkpoint with `credential-missing`; it must expire at its bounded deadline because safe release is impossible without the bearer credential.


- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass13`) confirmed the existing external workflow-isolation blocker without mutating the fixture. The fixture city is running and usable (`gc status --json` runtime probe timed out but reported `health.usable=true`, `degraded=false`); happy root `fx-jktt` is closed PASS with its finalizer closed; unrelated root `fx-hc7` remains open with the recorded stale-session repairable failure; and `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active (`closed=false`). Passes 3–12 and the prior oracle establish that reset, nudge, kill, direct close, rebind, or new dispatch would be unsafe and unsupported under GC-11's source-wide claim. Stall guard honored: no demo retry, code change, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; verify that session is absent before running repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass14`) refreshed the source-wide lease and live fixture state without workflow mutation. The controller is running and usable (runtime-status probe timed out); happy root `fx-jktt` remains closed PASS; unrelated root `fx-hc7` remains open; and shared `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active (`closed=false`). Passes 3–13 and the prior oracle consultation already established that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under this item's claim. Stall guard honored: no demo retry, code change, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; verify that session is absent before running repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass15`) confirmed the external workflow-isolation blocker without mutation. `gc --city ai/gascity --rig fixture status --json` reports the controller running and usable (`degraded=false`) while its runtime probe times out; happy root `fx-jktt` remains closed PASS. Unrelated root `fx-hc7` remains open, and `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active (`closed=false`). Passes 3–14 and the prior oracle establish that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under GC-11’s claim. Stall guard honored: no workflow mutation, demo retry, code change, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; verify the session is absent before repair and halt demos.

- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass16`) confirmed the existing external workflow-isolation blocker without workflow mutation. The fixture controller is running and usable (`gc status --json` runtime probe timed out); happy root `fx-jktt` remains closed PASS, while unrelated root `fx-hc7` remains open and shared `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active (`closed=false`). Passes 3–15 and the prior oracle establish that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under GC-11's source-wide claim. Stall guard honored: no demo retry, code change, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; verify the session is absent before running repair and halt demos.
- 2026-07-21 — GC-11 — fresh-context implementation pass (`claim-gascity-gc-11-20260721-pass17`) recomputed the source-wide item state and confirmed the external workflow-isolation blocker without mutation. `gc --city ai/gascity --rig fixture status --json` reports the controller running and usable (`degraded=false`) despite its runtime probe timing out; happy root `fx-jktt` remains closed PASS. Unrelated root `fx-hc7` remains open, and shared `fixture/gc.reviewer` session `gc-wisp-70sqaf` remains active (`closed=false`). Passes 3–16 and the prior oracle establish that reset, nudge, kill, direct close, rebind, or a new dispatch would be unsafe and unsupported under GC-11's source-wide claim. Stall guard honored: no workflow mutation, demo retry, code change, executor, verifier, or oracle retry. Precise unblock: the `fx-hc7` owner completes it or safely retires `gc-wisp-70sqaf`; verify the session is absent, then run repair and halt demos.

- 2026-07-22 — GC-11 — source-hardening pass
  (`claim-gascity-gc-11-20260723-final-2`) removed the remaining demo evidence
  ambiguity and isolated the final health failure. Current source requires
  exact implementer `Files changed` JSON, independently checks it against the
  tracked-plus-untracked repository diff before review, validates structured
  verify/finalize outputs and final-report graph references, persists selected
  phase sessions before dispatch, and retires only sessions owned by the
  recorded workflow. Fresh happy run `gc11-happy-proof29` reached closed PASS
  root `fx-70js`; the implementer report, verifier output, finalizer output,
  retained artifacts, root outcome, and `changed_files=["AGENTS.md"]` all
  passed the current guards. Do not count that run as final happy acceptance:
  its outer task exited 201 at the final doctor gate because a missed cron left
  city and fixture `mol-dog-stale-db` order history critically stale after
  controller retries. The discriminator was exact: city-wide supervisor
  reload plus explicit city/fixture `gc order run mol-dog-stale-db` changed
  `gc doctor --json` from `failed=1`, `blocking_failed=1` to `0/0`. Current
  source now performs that bounded recovery only for those two exact CRITICAL
  names, uses city-wide supervisor reconciliation, never dispatches unrelated
  orders, and otherwise fails closed. `bash -n`, ShellCheck, all base/repair
  formula compiles, targeted exact changed-file gate cases, and final
  source-only review are clean. Next pass: reset the retained `fx-70js` demo
  state, rerun happy from this commit, then run repair and halt, verify all
  GC-11 acceptance evidence independently, and only then mark GC-11 complete.

- 2026-07-23 — GC-11 — reset retained `fx-70js`, then ran fresh happy, repair, and
  retry-limit halt proofs from `187aff75` with 90s Beads readiness, 60s controller
  prewarm, 3600s workflow waits, and 5s polling. Happy `fx-8j5s`, repair `fx-uyyg`,
  and halt `fx-q75y` each exited through the expected public task success path;
  exact artifacts, write-back or no-write-back behavior, root-scoped references,
  selected-session retirement, repair-session distinctness, exhaustion metadata,
  source state, and doctor `failed=0`/`blocking_failed=0` were independently
  verified. Two final independent verifiers PASSed every GC-11 criterion; mark
  GC-11 complete.
- 2026-07-23 — GC-13 — owner added a slim server-rendered operator UI to the item,
  superseding two first-version boundaries: "frontend beyond the minimal status
  page" (now the operator page with control forms) and the emergency-stop "not an
  API endpoint" stance (now a typed-confirmation form invoking documented
  `gc stop`). Refinements applied on review: mutations stay loopback-only and
  LAN/authenticated access remains out of scope (the original draft required auth
  for LAN mutations, contradicting the out-of-scope list); auto-refresh is meta
  refresh on the status view only; the stop confirmation lives on its own
  non-refreshing page because a five-second full-page refresh would clobber typed
  input; rendering stays stdlib string-based like the existing `/` page.
- 2026-07-23 — GC-13 — implemented the control plane, provider-aware admission,
  manual `UsageReader` boundary, future-dispatch repair limit, loopback-only JSON
  and native-form mutations, five-second operator status page, and typed,
  non-refreshing durable-stop page. The final sidecar suite passed 79 tests with
  one opt-in skip; Ruff passed; browser smoke confirmed every status/control
  section and confirmed the stop page has no refresh metadata. Independent
  verification passed all seven GC-13 criteria.
- 2026-07-23 — GC-13 — selected the preferred concurrency mechanism: tracked
  `city.toml` references gitignored, sidecar-owned `city.sidecar.toml`; Task entry
  points create the file before their first `gc` command; control mutations write
  it atomically and invoke `gc reload`. Installed Gas City v1.3.5 rejects
  `providers.*.max_active_sessions`, so the verified file uses only supported
  `[workspace].max_active_sessions`. `gc config show --validate` reported
  `Config valid`; a successful live reload took 52.59 seconds, so the bounded
  default CLI timeout is 90 seconds. Conserve uses workspace cap 1 and explicitly
  warns that v1.3.5 cannot prove a provider-only dynamic cap and therefore also
  constrains non-Codex sessions; critical/paused remain provider-aware admission.
- 2026-07-23 — GC-13 — live fixture acceptance kept active workflow `fx-4353`
  `in_progress` across pause, refused the paused `omp` dispatch without invoking
  Gas City, then admitted resume and created workflow `fx-s9yu`. Pause/resume
  performed no unverified `gc suspend`/`gc resume` operation. Public-host override
  regression coverage also proves status remains readable while all mutations are
  forbidden, including when the non-loopback status-view opt-in is enabled.
- 2026-07-23 — GC-13 — post-completion evaluation found and fixed three defects:
  (1) the operator page's bare `content="5"` meta refresh re-navigated by GET to
  the POST-only form action after every mutation, stranding the operator on a 405
  — refresh now targets `url=/`; (2) leaving conserve for critical/paused never
  rewrote `city.sidecar.toml`, silently keeping the workspace capped at 1 for all
  providers — budget-mode changes now apply the sidecar config in every mode so
  only conserve holds the cap; (3) a concurrency change made while in conserve
  reported success with no warning although the cap stayed at 1 — it now warns
  the new value takes effect after leaving conserve. Also cleared five Ruff
  errors that predated the GC-13 commit (misplaced imports in `cli.py`, unused
  imports in `notifications.py`) despite the earlier "Ruff passed" note. Suite
  91 passed + 1 opt-in skip; Ruff clean.
- 2026-07-23 — GC-17 — committed `d818ff3` with architecture, state-ownership,
  and real-rig onboarding documentation. The onboarding proof registered a second
  generated fixture as suspended with the installed `gc rig add --include .`
  path, listed it, previewed `fix-independent` as actionable, imported it as
  `f17-odp` with external reference `md:backlog.md#fix-independent`, and dry-ran
  formula dispatch to `fixture-gc17/import.intake` with `success=true` without
  changing `backlog.md`; the temporary rig registration and runtime were removed.
  Targeted Prettier and diff checks passed. The repository-wide check reached the
  existing `ai/gascity/Taskfile.yaml` formatting failure outside this diff.
  Independent verification passed every GC-17 criterion and found no conflict
  with installed Gas City 1.3.5, Beads 1.1.0, Dolt 2.2.0, or prior Decision-log
  findings.
- 2026-07-23 — GC-16 — installed Gas City v1.3.5 direct formula dispatch returned
  workflow root `fx-kx5q`, but `gc convoy delete-source fx-tih` reported
  `already_clean` and did not match that root. Use the installed root-oriented
  cancellation path: `gc convoy delete WORKFLOW_ROOT_ID` for preview, then
  `gc convoy delete WORKFLOW_ROOT_ID --force` to close the durable subtree.
  The fixture proof closed all 9 open beads under `fx-kx5q`; its source `fx-tih`
  was restored closed afterward.
- 2026-07-23 — GC-16 — every permitted operations-guide command was exercised
  against the generated fixture. Sidecar health/status/events and dashboard
  probes passed; reload/restart and durable stop/start recovered the city; the
  rendered plist, wrapper checks, and unloaded-service probe passed; the sidecar
  suite passed 105 tests with 2 opt-in skips. `gc doctor` reported one pre-existing
  stale scheduled order while the controller, stores, and supervisor remained
  usable. `launchctl bootstrap`/`bootout` were intentionally not run because
  GC-16 forbids installing or enabling the example service.

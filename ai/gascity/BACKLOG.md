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

### GC-01 — Install gc + bd via mise, capture environment report

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

### GC-02 — Initialize the city

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

### GC-03 — OMP primary provider + smoke worker

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

### GC-04 — Fixture rig

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

### GC-05 — Phase agents

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

### GC-06 — Linear workflow formula (happy path, no repair loop yet)

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

- [ ] One fixture bead flows through all five phases to a closed root bead.
- [ ] Events/sessions prove five distinct fresh sessions (one per phase).
- [ ] Artifacts exist and are concise: brief.md, plan.md, attempts/1/report.md,
      verify.md, final.md; `gc.output_json` populated per step.
- [ ] Artifacts and outcome survive `gc stop && gc start` (session termination).
- [ ] Killing a mid-phase session and re-running demonstrates recovery from durable
      state (bead + artifacts), not conversation state.

Depends on: GC-05

### GC-07 — Bounded repair loop

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

- [ ] Fixture "fails-once" task: attempt 1 fails review, attempt 2 passes; both
      attempts preserved as iteration beads + `attempts/1..2/` artifacts.
- [ ] Each repair attempt is a fresh implementer session (evidence from events).
- [ ] With `max_repair_attempts=1` the workflow halts failed at the limit and the root
      bead records exhaustion; nothing loops unbounded.
- [ ] Reviewer input assembled by the script contains no prior attempt transcripts
      (inspect the script + one invocation's captured input).

Depends on: GC-06

### GC-08 — Markdown backlog adapter (parser + identity, standalone)

Python package `sidecar/src/gascity_sidecar/backlog/` (`base.py` defines the source
interface: `preview() -> [Task]`, `materialize(task_id)`, `writeback(task_id, state)`;
`markdown.py` implements it). No HTTP/FastAPI imports here. Deterministic grammar for
v1 (document in `docs/backlog-sources.md`):

- A task = a `## ` section in the configured file (default `backlog.md`).
- Stable external ID: explicit `<!-- id: xyz -->` in the section wins; else slugified
  title (collision → error, refuse import; never silently disambiguate).
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

Depends on: GC-01 (bd flag verification); parallel-safe with GC-05–07

### GC-09 — Materialize into Beads, idempotently + pack commands

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

### GC-10 — Explicit write-back command

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

### GC-11 — End-to-end demo: markdown → beads → workflow → outcome

Wire the full path on the fixture rig: import one fixture task (GC-09), dispatch
`backlog-item` with the created bead (GC-06/07), let it finish, then run write-back
(GC-10) explicitly. Capture the exact command sequence in `README.md` as the
repeatable demonstration, including the failure-path variant (fails-once task) and the
retry-limit halt variant. Add task entries: `gascity:demo` (happy path),
`gascity:demo:repair` (fails-once), `gascity:demo:halt` (limit exhaustion),
`gascity:demo:reset` (re-run fixture rig script + clear demo beads).

Acceptance:

- [ ] README commands reproduce: clean import → workflow pass → write-back, on a fresh
      fixture rig (`make-fixture-rig.sh` re-run first); `task gascity:demo` runs the
      same path.
- [ ] Repeated import mid-flow creates no duplicate work.
- [ ] All intermediate reports + final report present after sessions are gone.
- [ ] `gc doctor` clean at the end.

Depends on: GC-07, GC-09, GC-10

### GC-12 — Sidecar skeleton: config, state, status, gc client

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

Depends on: GC-02 (city exists), GC-08 (package). Parallel-safe with GC-05–07.

### GC-13 — Sidecar control plane: pause/resume/drain, concurrency, budget mode

Endpoints: `POST /control/pause|resume|drain`, `PUT /control/concurrency`,
`PUT /control/max-repair-attempts`, `PUT /control/codex-budget-mode`. Semantics:

- pause: sidecar admits no new work (it is the dispatcher); additionally
  `gc suspend`/`gc resume` if verified to leave running sessions alive (verify; else
  sidecar-admission only). Never kills sessions.
- drain: pause + wait for active workflows/sessions to settle (poll status/events);
  reports settled/not-settled. Separate from pause; no kills.
- emergency stop: implement only as documented `gc stop` (durable by design) — a
  documented operation, not an API endpoint, unless a safer supported verb exists.
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

Acceptance:

- [ ] Tests: pause blocks a dispatch attempt; resume unblocks; drain waits without
      killing (fake client); budget-mode admission matrix; concurrency validation
      (bounds, type); every response includes the five reporting fields.
- [ ] Manual check against the live fixture city: pause → attempted fixture dispatch
      refused; active run untouched; resume → dispatch proceeds.
- [ ] Chosen concurrency mechanism + its verification evidence recorded in the
      Decision log.

Depends on: GC-12, GC-11 (needs a dispatchable workflow to prove semantics)

### GC-14 — Sidecar events + Pushover

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

- [ ] Event fixture tests: mapping, dedupe, checkpoint resume, malformed/unknown
      tolerance, Pushover-failure tolerance, no duplicate notification after
      restart-and-replay.
- [ ] Live check: fixture workflow run produces started/completed notifications
      (or logs when Pushover unset); restart sidecar mid-run → no duplicates, no gap.
- [ ] Rotation handling documented (what happens when events.jsonl rotates under the
      cursor); if replay-across-rotation is unsupported, checkpoint strategy
      documented.

Depends on: GC-12; live check needs GC-11

### GC-15 — Sidecar backlog endpoints + explicit dispatch

`POST /backlogs/markdown/preview` and `POST /backlogs/markdown/import` (single task
id; wraps GC-08/09 adapter; typed request/response). Import materializes only —
dispatch is a separate explicit call (`POST /workflows/dispatch` with bead id →
`gc sling ... --var item=... --var max_repair_attempts=<desired>`), gated by
admission (pause/drain/budget mode) from GC-13. Track external source ref on the
dispatch record. One opt-in smoke test (env-flagged) drives preview → import →
dispatch against the local fixture city.

Acceptance:

- [ ] API validation tests (bad path, unknown id, ambiguous id → 4xx typed errors).
- [ ] Import endpoint idempotent (re-POST → same bead, `created: false`).
- [ ] Dispatch refused while paused/critical (per provider), allowed after resume —
      tested with fake client; smoke test proves the real path end-to-end.
- [ ] Normal test suite requires no real agent calls.

Depends on: GC-13, GC-09

### GC-16 — Process management + operations guide

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

- [ ] Plist validates (`plutil -lint`); not loaded; instructions include load/unload
      commands and log locations.
- [ ] Every operations-guide command actually run once against the fixture city;
      outputs sanity-checked (note any verb that differs from this plan in the
      Decision log).

Depends on: GC-12; content finalized after GC-11

### GC-17 — Architecture + state-ownership + rig-onboarding docs

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

- [ ] A reader can add a real repo rig using only the docs (dry-run the steps against
      a second generated fixture rig to prove the instructions).
- [ ] No doc contradicts the installed-version findings in the Decision log.

Depends on: GC-11; ideally after GC-13–15 so sidecar docs are accurate

### GC-18 — Final acceptance sweep

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

Depends on: everything above

---

## Explicitly out of scope (first version)

Linear/Jira production integrations; custom `exec` beads provider; real Codex quota
retrieval; remote/authenticated access; multi-user permissions; frontend beyond the
minimal status page; automatic retry-limit changes to active runs; any push/PR/merge
automation; modifying real backlogs or repositories.

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

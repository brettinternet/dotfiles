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
   `city.toml` + `pack.toml` (the city *is* the root pack) + `agents/ formulas/ orders/
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
- [ ] A bead slung to `worker` is claimed and closed by an omp session
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
- [ ] Script is idempotent (re-run refreshes the rig cleanly or no-ops; documented).
- [ ] `gc rig list` shows the rig; `gc doctor` clean.
- [ ] `city.toml` `[[rigs]]` entry contains no machine-local absolute path (binding in
      `.gc/site.toml` only).
- [ ] Fixture `backlog.md` committed as `fixtures/backlog.md` and copied in by the
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
- [ ] `gc lint` (or current equivalent) passes; agents visible in `gc agent list` for
      the fixture rig.
- [ ] Each agent.toml pins its provider explicitly; reviewer provider differs from
      implementer provider.
- [ ] Prompts contain the untrusted-input rule and the artifact contract.

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
- [ ] `uv run pytest` green; covers ids, fingerprints, deps, done detection,
      ambiguity refusal, malformed input.
- [ ] Parser never writes to the source file (no write APIs in the import path).
- [ ] `docs/backlog-sources.md` documents the grammar and the adapter interface, with
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
- [ ] Preview lists fixture tasks with id/title/actionability without creating beads.
- [ ] Importing the same fixture task 3× yields exactly one bead (assert via
      `bd list --external-ref ... --json` count).
- [ ] Bead carries all five source-metadata fields; dependency edges present for the
      dependent fixture task.
- [ ] Editing the fixture section body then re-importing updates the bead
      (fingerprint + title refresh), still one bead.
- [ ] Tests cover the create/update/skip matrix with a fake `bd` (subprocess fake or
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
- [ ] Happy path marks exactly the target fixture task done; diff of the file touches
      only that section.
- [ ] Each refusal case has a test and exits nonzero with a clear message.
- [ ] Import paths still never write (regression test).

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
- [ ] `uv run gascity-sidecar serve` starts with gc stopped (degraded status, no
      crash) and with gc running (reports real status).
- [ ] Desired state survives restart (test).
- [ ] Non-loopback bind refused by default (test).
- [ ] Fake-gc-client unit tests cover client timeout/nonzero-exit/schema-mismatch
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
  patched`, but `[workspace].max_active_sessions` in city.local.toml did not
  override the tracked root value (and `gc config show` reports the same precedence).
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

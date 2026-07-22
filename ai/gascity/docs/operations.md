# Gas City operations

Run city commands from `ai/gascity/`. The city supervisor is machine-wide;
starting or stopping this city does not install or remove the supervisor.
The installed macOS service label is `com.gascity.supervisor`; the sidecar
example below is a separate, optional user-agent label.
Runtime state, event logs, Beads, sidecar state, and logs stay under ignored
paths.

## Manual startup and shutdown

```sh
cd ai/gascity
mise exec -- gc start
mise exec -- gc status
mise exec -- gc doctor
```

Start the sidecar in a second terminal. It binds to loopback by default and
loads environment overrides from the ignored `ai/gascity/.env`. Source that
file first so `uv` itself sees machine-local overrides such as
`UV_PROJECT_ENVIRONMENT` (the sidecar venv location) before it resolves the
project:

```sh
cd ai/gascity
set -a && [ -f .env ] && . .env; set +a
uv run --project sidecar gascity-sidecar serve
```

`task sidecar:serve` and `task sidecar:test` source `.env` inline before
invoking `uv run` (this Taskfile is included by the repo-root `Taskfile.dist.yaml`,
and go-task rejects a top-level `dotenv` declaration on included taskfiles);
`commands/*/run.sh` source it directly.

Read-only sidecar checks:

```sh
curl --fail http://127.0.0.1:8787/health
curl --fail http://127.0.0.1:8787/status
curl --fail http://127.0.0.1:8787/events
```

Stop the foreground sidecar with `Ctrl-C`, then stop this city when its
sessions should no longer run:

```sh
cd ai/gascity
mise exec -- gc stop
mise exec -- gc status
```

`gc stop` is durable: Beads, workflow state, artifacts, and the event log are
not deleted. The machine-wide supervisor can remain running:

```sh
mise exec -- gc supervisor status
```

## Inspect a running city

```sh
cd ai/gascity
mise exec -- gc status
mise exec -- gc doctor
mise exec -- gc session list --state all --json
mise exec -- gc events --seq
mise exec -- gc events --since 30m
```

The dashboard is a local read/operation surface. Start it in a terminal and
open `http://127.0.0.1:8080`:

```sh
cd ai/gascity
mise exec -- gc dashboard serve --port 8080
```

The sidecar status page is at `http://127.0.0.1:8787/`; JSON endpoints are
`/health`, `/status`, `/events`, `/workflows`, and `/workers`.

Attach to a known session only when interactive inspection is intended:

```sh
cd ai/gascity
mise exec -- gc session attach SESSION_ID_OR_ALIAS
```

Use `gc session list --state all --json` first. `gc session attach` may resume a
suspended session and therefore is not a read-only command.

## Retry or cancel a workflow

Gas City 1.3.5 does not expose a `gc workflow cancel` command. `gc workflow`
is a deprecated alias for the convoy dispatch commands. Preview workflow
cleanup first, then close the workflow subtree without deleting its durable
beads:

```sh
cd ai/gascity
mise exec -- gc convoy delete-source SOURCE_BEAD_ID
mise exec -- gc convoy delete-source SOURCE_BEAD_ID --apply
```

To retry a session without closing its bead, request a fresh provider context:

```sh
cd ai/gascity
mise exec -- gc session reset SESSION_ID_OR_ALIAS --json
```

To retry a closed source workflow, reopen the source bead and dispatch it again
with the formula and variables required by that workflow:

```sh
cd ai/gascity
mise exec -- gc convoy reopen-source SOURCE_BEAD_ID
mise exec -- gc sling TARGET backlog-item --formula \
  --var item=SOURCE_BEAD_ID --var max_repair_attempts=2 --json
```

Use the exact configured target and formula variables for the selected city;
`gc sling --dry-run` previews routing without dispatching. Do not use
`--delete` on `delete-source` unless the closed workflow beads are intentionally
being garbage-collected.

## Crash and reboot recovery

After a shell, sidecar, controller, or host restart:

```sh
cd ai/gascity
mise exec -- gc supervisor status
mise exec -- gc start
mise exec -- gc status
mise exec -- gc session list --state all --json
mise exec -- gc events --seq
uv run --project sidecar gascity-sidecar serve
```

The supervisor re-adopts the registered city; the Beads store and event log are
the durable workflow record. The sidecar SQLite state database preserves its
desired state, event cursor, recent mapped events, and notification dedupe.
If configuration changed while the city remained registered, ask the
controller to reload it:

```sh
mise exec -- gc reload --async
```

For a full city restart, use `gc restart` instead of manually killing a
controller. Emergency stop is the documented `gc stop`; it stops city sessions
without deleting durable state. Do not kill individual supervisor processes.

## Optional launchd sidecar service

`sidecar/com.gascity.sidecar.plist` is a portable example, not an installed
service. It contains the `__REPO_ROOT__` placeholder because launchd requires
an absolute working directory and program path. `sidecar/launchd-run.sh`
resolves the checkout at runtime and sources the ignored `.env` before running
`uv run --project sidecar gascity-sidecar serve`.
Launchd does not load shell startup files, so the wrapper cannot assume a
mise-managed `uv` is on `PATH`. Set `GC_SIDECAR_UV_BIN` to an absolute `uv`
path in the ignored `ai/gascity/.env` (for example, the output of
`command -v uv` from the shell where `uv` is installed) before loading the
rendered service.

Keep the example unloaded in the repository. To render, validate, load, and
inspect a user-local copy:

```sh
cd ai/gascity
REPO_ROOT="$(cd ../.. && pwd)"
mkdir -p .local/launchd
sed "s#__REPO_ROOT__#${REPO_ROOT}#g" \
  sidecar/com.gascity.sidecar.plist \
  > .local/launchd/com.gascity.sidecar.plist
plutil -lint .local/launchd/com.gascity.sidecar.plist
launchctl bootstrap "gui/$(id -u)" .local/launchd/com.gascity.sidecar.plist
launchctl print "gui/$(id -u)/com.gascity.sidecar"
```

The rendered copy writes stdout/stderr to
`ai/gascity/.local/sidecar.stdout.log` and
`ai/gascity/.local/sidecar.stderr.log`. Unload it before removing the rendered
copy:

```sh
launchctl bootout "gui/$(id -u)/com.gascity.sidecar"
trash .local/launchd/com.gascity.sidecar.plist
```

Do not run `launchctl bootstrap` from setup automation. Manual foreground
startup is the supported default and is sufficient when launchd is not wanted.

# Gas City environment

Verified 2026-07-17 on macOS arm64.

## Tooling

| Tool | Version | Installation |
|---|---|---|
| mise | 2026.7.7 macos-arm64 | existing mise installation |
| gc | 1.3.5 | `github:gastownhall/gascity` via `darwin/.config/mise/conf.d/55-gascity.toml` |
| bd | 1.1.0 (`8e4e59d39f34`) | `github:gastownhall/beads` via `darwin/.config/mise/conf.d/55-gascity.toml` |
| dolt | 2.2.0 | `ubi:dolthub/dolt` via the same mise config |
| tmux | latest | existing mise installation |
| jq | system installation | already installed |
| git | Homebrew | already installed |
| flock | 0.4.0 Homebrew | added to `darwin/Brewfile` and installed |

The six gc runtime dependencies resolve in the gc environment: `tmux`, `jq`,
`git`, `dolt`, `flock`, and the `bd` executable.
The gc and bd release tarballs were GitHub-attestation verified by mise before
extraction. Dolt installed through mise's `ubi` backend; mise warns that this
backend is deprecated, but the release resolved and installed successfully.
After mise config deployment and a fresh login shell, `mise ls` and PATH expose
gc and bd directly.

## Agent CLIs

| CLI | Version | gc builtin provider base |
|---|---:|---|
| omp | 17.0.2 | `builtin:omp` |
| claude | 2.1.212 | `builtin:claude` |
| codex | 0.144.5 | `builtin:codex` |
| opencode | 1.18.3 | `builtin:opencode` |

The installed v1.3.5 builtin provider catalog also contains `pi`; the planned
review bases `builtin:omp`, `builtin:pi`, and `builtin:claude` are valid provider
base names in the catalog. `gc init --providers` has a narrower readiness-aware
allowlist: passing `omp` produced `unknown provider "omp"` and listed only
`claude`, `codex`, `gemini`, `mimocode`, and `antigravity`. Configure an omp
provider alias directly in city configuration rather than relying on that init
wizard flag.

## Doctor and city state

No city was created or registered under `ai/gascity/`. A disposable temporary
city was initialized with `gc init --no-start` only to exercise the installed
`gc doctor`, then removed with `trash`; `gc cities` reports no registered cities.

Running `gc doctor` from the repository correctly refuses because there is no
`city.toml` yet. The disposable doctor run found the required `tmux`, `git`, and
`jq` binaries, reached the Dolt server, and reported the expected pre-city
issues: missing Dolt author identity prevented store initialization, pack import
state was not installed, `beads.role` was unset, and no sessions existed. These
are GC-02 initialization concerns, not installation failures.

## Schema spot-checks

- **Pack schema:** v1.3.5 `pack-spec.md` declares pack schema `2`; `pack.toml`
  requires `[pack]` with `name` and `schema = 2`, and machine-readable pack
  content uses the reserved directories such as `agents/`, `formulas/`,
  `commands/`, and `doctor/`.
- **Formula v2:** `formula-spec-v2.md` requires
  `[requires].formula_compiler = ">=2.0.0"` for graph-only features. A check
  is authored as `[steps.check]` with `max_attempts`, nested
  `[steps.check.check]` with `mode = "exec"`, `path`, and optional `timeout`.
  Retry uses `[steps.retry]` with `max_attempts` and `on_exhausted`. Variables
  use top-level `[vars]`; required variables use table form and callers pass
  values with `gc sling ... --var key=value`.
- **ProviderSpec:** v1.3.5 `config.md` supports `base = "builtin:<name>"`,
  `command`, `args`, `print_args`, resume fields, and provider capability
  fields. The installed source catalog lists `claude`, `pi`, and `omp`.
- **Beads:** installed `bd 1.1.0` help exposes `bd create --external-ref` and
  `--metadata`; `bd import` documents incremental upsert semantics and
  `--json`; `bd ready` documents atomic `--claim --json`.

No schema delta changes the GC-01 architecture. The init-provider allowlist
exception is recorded in the Decision log below.

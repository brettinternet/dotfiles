# Gas City

This directory is the portable city configuration and pack. Runtime state,
beads, and machine-local overrides remain ignored (`.gc/`, `.beads/`,
`city.local.toml`, and `.env`).

## Initialize

The city was initialized with:

```sh
mise exec -- gc init --template gascity --default-provider codex \
  --skip-provider-readiness --yes --preserve-existing ai/gascity
```

`gc init` registers and starts the city under the machine-wide launchd
supervisor `com.gascity.supervisor`. Use the namespaced Taskfile commands from
the repository root:

```sh
task gascity:doctor
task gascity:status
task gascity:up
task gascity:down
```

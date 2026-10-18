# Dotfiles

![desktop screenshot](./screenshot.png)

Basic dotfiles setup with [dotbot](https://github.com/anishathalye/dotbot/tree/master) for consoles, nix-darwin, linux servers and Xorg. For advanced system setup, see my [homelab](https://github.com/brettinternet/homelab) playbooks.

```sh
./install
```

## Herdr command panes

`pane` (`base/.bin/pane`, installed by the base group) launches arbitrary argv in a new Herdr pane. Use [`agent`](ai/README.md#herdr-placement) for named coding agents and readiness detection instead.

```sh
pane -w test -- echo test
pane -w maintenance -t logs -- tail -f app.log
pane -s down -- bun test --watch
pane -w test -t checks --reuse-tab -- bun test
pane -t checks --wait -- bun test # block and return bun's exit status; keep output
pane -t disposable --close-on-exit -- echo done
pane --herdr-session default -w jobs -C ~/dev/me/project -- bun test
pane -w test -- sh -c 'echo test; date'
```

Without placement flags, `pane` splits the calling pane to the right. `-w` reuses a workspace matching label and canonical cwd; `-t` creates a fresh tab (title defaults to the command basename). `--reuse-tab` adds a split to the first matching tab instead. Workspace tie-breaking and focus behavior match `agent`: prefer a matching caller workspace only in the inherited session, refuse other ambiguous workspace matches, and preserve focus unless `-f` is supplied. `-s` cannot be combined with workspace, tab, or explicit session selection. Outside Herdr, both `--herdr-session` and `-w` are required.

Commands must follow `--`. Arguments are passed literally, not interpolated into shell text; use `sh -c` explicitly for pipelines, redirects, or expansion. Python 3 must be available in the new pane. `-C` selects cwd, `-e KEY[=VALUE]` copies or sets environment variables (`HERDR_*` overrides are forbidden), and `-T` labels the pane. `-n/--dry-run` prints a plan without contacting Herdr and redacts environment values; command arguments are shown verbatim.

By default, the command returns to the pane’s shell with its output and exit status visible. `--close-on-exit` closes only the created pane after command completion, including failure, and discards its output. The launcher’s JSON acknowledges submission with `pane_id` and `submitted`; its exit status is **not** the command’s eventual exit status. With `--wait`, the launcher instead stays running until the command exits, prints a second JSON response with `pane_id` and `exit_code`, and returns that exit code (128 + signal for signal termination). The pane stays open unless `--close-on-exit` is also supplied. Completion uses a private Unix socket on the same host, not terminal-output matching; the launcher and pane must share the local filesystem. Before the bootstrap connects, a lost pane, Herdr error, or 30-second startup timeout fails rather than reporting success. After connection, the socket tracks completion directly; if the bootstrap dies without reporting status, waiting fails even if the pane's shell survives.

Ctrl-C exits 130 and SIGTERM exits 143 while waiting, retaining the pane and **leaving the command running**. Scheduler cancellation therefore cancels observation, not the work: inspect or explicitly close the retained pane before retrying. Failed submissions retain the created pane for inspection and are never automatically retried. `pane` does not replace existing processes or offer agent-name operations.

## Set up a workstation

```
make {darwin|server|thinkpad}
```

### Machine-local Git configuration (macOS)

The managed `~/.gitconfig` includes `~/.gitconfig.local` last. Put machine-local
settings there to override managed defaults without editing tracked dotfiles.
The local file is not installed or tracked; it is harmless if missing.

To authenticate GitHub CLI, run `gh auth login`, choose HTTPS, and answer **No**
when asked whether to authenticate Git with your GitHub credentials. After CLI
login, configure its Git credential helper separately:

```sh
GIT_CONFIG_GLOBAL="$HOME/.gitconfig.local" gh auth setup-git --hostname github.com
```

This writes the helper configuration to the local file rather than the managed
`~/.gitconfig`. Use the same override when rerunning `gh auth setup-git`.

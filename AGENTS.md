# AGENTS.md

## Overview

Dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot). Supports macOS (darwin), Linux servers, Thinkpad/Xorg, and VM guests.

Make sure linting passes after each change.

## Install

```sh
# Full install (base group by default)
./install

# Platform-specific
make darwin    # macOS: base + darwin groups
make server    # Linux server: base + archlinux groups
make thinkpad  # Thinkpad: base + x11 + thinkpad + archlinux groups
```

## Lint

```sh
make lint   # runs yamllint + shellcheck
```

## Structure

- `base.yaml` / `darwin.yaml` / `thinkpad.yaml` / etc. — dotbot config files per group; define symlinks, directories to create, and shell commands to run
- `base/` / `darwin/` / `thinkpad/` / etc. — actual dotfiles for each group
- `install` — dotbot entrypoint; reads `DOTFILE_GROUPS` env var (comma-separated) to select which yaml configs to apply
- `Makefile` — sets `DOTFILE_GROUPS` and calls `./install` for each platform target

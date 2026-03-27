# AGENTS.md

## Overview

Dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot). Supports macOS (darwin), Linux servers, Thinkpad/Xorg, and VM guests.

Make sure the checks passes after each change. Keep working until all checks pass.

## Setup

Project setup uses go-task @Taskfile.dist.yaml to setup and develop the project.

```sh
task init # Sets up dependencies, dirnev and git hooks
```

## Install

Make is used to install the dotfiles since it's available on all target machines.

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
task check   # runs lint checks
```

## Structure

- `base.yaml` / `darwin.yaml` / `thinkpad.yaml` / etc. — dotbot config files per group; define symlinks, directories to create, and shell commands to run
- `base/` / `darwin/` / `thinkpad/` / etc. — actual dotfiles for each group
- `install` — dotbot entrypoint; reads `DOTFILE_GROUPS` env var (comma-separated) to select which yaml configs to apply
- `Makefile` — sets `DOTFILE_GROUPS` and calls `./install` for each platform target

## Tools

### GitHub

- Always use `gh` CLI for all GitHub operations. Never construct raw API calls.
- For PRs: `gh pr view`, `gh pr diff`, `gh pr comment`
- For issues: `gh issue list`, `gh issue view`
- Never open GitHub browser URLs; use CLI output only

## What NOT to do

- Don't run `git push` without explicit instruction
- Don't open PRs without explicit instruction
- Don't edit files outside the current task scope

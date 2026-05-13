# OCX Registry

Personal OCX registry for portable OpenCode profiles maintained from this dotfiles repo.

## Build

```bash
bun run build
```

## Preview

```bash
bun run preview
```

This serves `dist/` locally after building it.

## GitHub Pages

The `.github/workflows/opencode-registry-pages.yaml` workflow builds this registry and publishes the generated `dist/` contents under the `opencode/` Pages path. `index.json` must be available directly under the registry URL because `ocx registry add` validates `<url>/index.json`.

Enable Pages once in the repository settings with **Source: GitHub Actions**. The workflow does not auto-create the Pages site because GitHub's `GITHUB_TOKEN` can be blocked from enabling Pages for a repository.

Expected registry URL:

```text
https://brett.cloud/dotfiles/opencode
```

## Install

Install one profile directly from the registry URL:

```bash
ocx profile add omo-claude-openai --source brettinternet/omo-claude-openai --from https://brett.cloud/dotfiles/opencode --global
```

Or save the registry alias first:

```bash
ocx registry add https://brett.cloud/dotfiles/opencode --name brettinternet --global
ocx profile add omo-openai --source brettinternet/omo-openai --global
ocx profile add omo-claude --source brettinternet/omo-claude --global
ocx profile add omo-claude-openai --source brettinternet/omo-claude-openai --global
ocx profile add omo-openrouter --source brettinternet/omo-openrouter --global
```

## Refresh a profile

```bash
ocx profile remove omo-claude-openai --global
ocx profile add omo-claude-openai --source brettinternet/omo-claude-openai --from https://brett.cloud/dotfiles/opencode --global
```

## Notes

- Registry alias is `brettinternet`.
- Profile source files live under `files/profiles/<name>/`.
- Built registry files are generated in `dist/` and should not be edited by hand.
- See `AGENTS.md` for the local maintenance rules.

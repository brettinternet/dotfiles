# OCX registry maintenance

## Source layout

- `files/profiles/<name>/` contains profile sources.
- `registry.jsonc` only lists root-relative source files.
- Keep targets free of absolute paths and `../` traversal.

## Build validation

- Run `bun run build` after any registry or profile change.
- Check the build output in `dist/` before calling the work done.

## Profile conventions

- Each profile should ship `ocx.jsonc`, `opencode.jsonc`, and a short `README.md`.
- Keep OpenAI model routing in `oh-my-openagent.jsonc`.
- Keep Claude profiles conservative; do not copy Claude Code-only settings unless they already fit OpenCode.

## Documentation

- Update `README.md` when install, preview, or refresh steps change.
- Keep this file short and current.

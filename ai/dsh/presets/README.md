# DSH agent presets

`~/.dsh/.agent-presets` is symlinked to this directory; the harness scans it
as a user-trust preset root.

- `liangshen/` — the dsh-tui preset, migrated here from
  `~/.dsh/.agent-presets` during the initial wiring (it was identical to the
  copy shipped in the dsh-tui bundle).
- To author a preset: copy a shipped one (`standard`, `code`, `minimal`,
  `cordis`) via the settings UI, or copy its directory here and edit
  `agent.cordis.yml`. A preset composes the agent-plane plugins: persona,
  instructions, tools, skills, delegation, and workflows.

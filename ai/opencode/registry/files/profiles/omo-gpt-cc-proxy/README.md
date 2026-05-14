# GPT+Claude Meridian proxy profile

OpenCode profile for OpenAI GPT plus Claude routing through a local Meridian proxy.

- `opencode.jsonc` points the Anthropic provider at `{env:MERIDIAN_BASE_URL}`.
- The Darwin mise config sets `MERIDIAN_BASE_URL=http://127.0.0.1:3456` as the default.
- Start Meridian before using Claude models from this profile.
- Claude subscription auth stays external: run `claude login`, then `meridian`.

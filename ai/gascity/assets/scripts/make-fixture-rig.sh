#!/usr/bin/env bash
# Generate the disposable GC-04 rig from the tracked fixture backlog.
#
# Re-running this script refreshes the generated files and creates a commit only
# when they changed. The rig's .git, .beads, and .gc directories are preserved so
# a registered rig remains usable across refreshes.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: make-fixture-rig.sh [--help]

Generate ai/gascity/.local/fixture-rig from the tracked fixtures/backlog.md.
The output is a tiny git repository. Re-running refreshes its generated files
idempotently while preserving registration/runtime state in .beads and .gc.
Use ./check.sh for the passing check, or ./check.sh --fail for a deterministic
intentional failure.
EOF
}

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi
if (($#)); then
  printf 'error: unknown argument: %s\n' "$1" >&2
  usage >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CITY_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
RIG_DIR="$CITY_DIR/.local/fixture-rig"
BACKLOG_SOURCE="$CITY_DIR/fixtures/backlog.md"

[[ -f "$BACKLOG_SOURCE" ]] || {
  printf 'error: missing fixture source: %s\n' "$BACKLOG_SOURCE" >&2
  exit 1
}

mkdir -p "$RIG_DIR"
if [[ ! -d "$RIG_DIR/.git" ]]; then
  git -C "$RIG_DIR" init -q
  git -C "$RIG_DIR" branch -M main
fi

cat > "$RIG_DIR/AGENTS.md" <<'EOF'
# Fixture rig instructions

This repository is disposable and exists for Gas City workflow checks.

Validation command: `./check.sh`

The check is deterministic. `./check.sh --fail` is an intentional failure mode
for exercising review and repair paths; it never changes repository state.
EOF

cat > "$RIG_DIR/hello.py" <<'EOF'
#!/usr/bin/env python3
print("hello from fixture")
EOF
chmod +x "$RIG_DIR/hello.py"

cat > "$RIG_DIR/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == "--fail" ]]; then
  printf 'intentional fixture failure\n' >&2
  exit 1
fi
if (($#)); then
  printf 'usage: ./check.sh [--fail]\n' >&2
  exit 2
fi

actual=$(./hello.py)
expected='hello from fixture'
if [[ "$actual" != "$expected" ]]; then
  printf 'expected %q, got %q\n' "$expected" "$actual" >&2
  exit 1
fi
printf 'fixture check passed\n'
EOF
chmod +x "$RIG_DIR/check.sh"

cat > "$RIG_DIR/.gitignore" <<'EOF'
.beads/
.gc/
.agents/
.claude/
CLAUDE.md
.dolt/
.dolt-backup/
EOF

mkdir -p "$RIG_DIR/assets/scripts"
cp "$SCRIPT_DIR/review-check.sh" "$RIG_DIR/assets/scripts/review-check.sh"
chmod +x "$RIG_DIR/assets/scripts/review-check.sh"

cp "$BACKLOG_SOURCE" "$RIG_DIR/backlog.md"

git -C "$RIG_DIR" add AGENTS.md hello.py check.sh .gitignore backlog.md assets/scripts/review-check.sh
if ! git -C "$RIG_DIR" diff --cached --quiet; then
  git -C "$RIG_DIR" -c user.name='GC fixture' -c user.email='gc-fixture@example.invalid' \
    commit -q -m 'Refresh GC-04 fixture rig'
fi

printf 'fixture rig ready: %s\n' "$RIG_DIR"

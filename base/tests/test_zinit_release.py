from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / "base/.zsh/zinit-release.zsh"
ZSHRC = ROOT / "base/.zshrc"


class ZinitReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def run_zsh(
        self, script: str, *, expected_code: int = 0
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            ["zsh", "-dfc", f'source "$HELPERS"; {script}'],
            text=True,
            capture_output=True,
            cwd=self.root,
            env={**os.environ, "HELPERS": str(HELPERS)},
            check=False,
            timeout=10,
        )
        self.assertEqual(
            expected_code, completed.returncode, completed.stderr or completed.stdout
        )
        return completed

    def make_executable(self, path: str) -> Path:
        executable = self.root / path
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        return executable

    def test_activates_all_supported_release_layouts(self) -> None:
        fixtures = (
            ("atuin", "atuin-aarch64/atuin", "./atuin './atuin*/atuin'"),
            ("direnv", "direnv.darwin-arm64", "./direnv './direnv.*'"),
            ("mise", "mise/bin/mise", "./mise './mise/bin/mise'"),
            ("usage", "usage", "./usage"),
            ("eza", "eza", "./eza"),
        )

        for label, relative_path, patterns in fixtures:
            with self.subTest(label=label):
                directory = self.root / label
                expected = self.make_executable(f"{label}/{relative_path}")
                completed = self.run_zsh(
                    f"cd {directory}; "
                    f"zinit_activate_release_command {label} {patterns}; "
                    f'print -r -- "$REPLY"; command -v {label}; {label}'
                )
                exposed = label if expected.name != label else str(expected.resolve())
                self.assertEqual(
                    [str(expected.resolve()), exposed], completed.stdout.splitlines()
                )

    def test_atuin_release_selector_excludes_server_assets(self) -> None:
        match = re.search(
            r'bpick"([^"]+)"',
            next(
                line
                for line in ZSHRC.read_text().splitlines()
                if "zinit ice" in line and "atuin-" in line
            ),
        )
        self.assertIsNotNone(match)
        pattern = match.group(1)

        for name in (
            "atuin-aarch64-apple-darwin.tar.gz",
            "atuin-x86_64-unknown-linux-gnu.tar.gz",
            "atuin-server-x86_64-unknown-linux-gnu.tar.gz",
            "source.tar.gz",
        ):
            (self.root / name).touch()

        completed = self.run_zsh(
            f"matches=( {pattern}(N) ); print -l -- ${{matches:t}}"
        )
        self.assertEqual(
            [
                "atuin-aarch64-apple-darwin.tar.gz",
                "atuin-x86_64-unknown-linux-gnu.tar.gz",
            ],
            completed.stdout.splitlines(),
        )

    def test_missing_release_executable_is_loud(self) -> None:
        completed = self.run_zsh(
            "zinit_activate_release_command atuin ./atuin './atuin*/atuin'",
            expected_code=1,
        )
        self.assertIn("zinit: atuin executable missing", completed.stderr)

    def test_generated_file_replaces_output_only_after_success(self) -> None:
        generated = self.root / "completion"
        generated.write_text("old\n")

        failed = self.run_zsh(
            "if zinit_generate_file completion /usr/bin/false; then exit 9; fi; "
            'print -r -- "$(<completion)"'
        )
        self.assertEqual("old", failed.stdout.strip())
        self.assertEqual([], list(self.root.glob("completion.tmp.*")))

        succeeded = self.run_zsh(
            'zinit_generate_file completion /bin/echo new; print -r -- "$(<completion)"'
        )
        self.assertEqual("new", succeeded.stdout.strip())

    def test_eval_init_reports_failure_without_evaluating_output(self) -> None:
        command = self.root / "broken-init"
        command.write_text("#!/bin/sh\necho 'should_not_load=1'\nexit 1\n")
        command.chmod(0o755)

        completed = self.run_zsh(
            "if zinit_eval_init example ./broken-init; then exit 9; fi; "
            'print -r -- "${should_not_load:-unset}"'
        )
        self.assertIn("zinit: example shell initialization failed", completed.stderr)
        self.assertEqual("unset", completed.stdout.strip())


if __name__ == "__main__":
    unittest.main()

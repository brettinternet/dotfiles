from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCROLLBACK = ROOT / "base/.bin/context-scrollback"


class ContextScrollbackTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.editor_log = self.root / "editor.log"
        self.command_log = self.root / "commands.log"
        self.environment = {
            key: value
            for key, value in os.environ.items()
            if key not in {"HERDR_ENV", "HERDR_PANE_ID", "TMUX", "TMUX_PANE"}
        }
        self.environment.update(
            {
                "CONTEXT_SCROLLBACK_COMMAND_LOG": str(self.command_log),
                "CONTEXT_SCROLLBACK_EDITOR_LOG": str(self.editor_log),
                "EDITOR": str(self.write_command("editor", self.editor_script())),
                "PATH": f"{self.bin}:{self.environment['PATH']}",
                "TMPDIR": str(self.root),
            }
        )

    def write_command(self, name: str, content: str) -> Path:
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)
        return path

    @staticmethod
    def editor_script() -> str:
        return """#!/bin/sh
printf 'path=%s\n' "$1" >"$CONTEXT_SCROLLBACK_EDITOR_LOG"
printf 'content=' >>"$CONTEXT_SCROLLBACK_EDITOR_LOG"
cat "$1" >>"$CONTEXT_SCROLLBACK_EDITOR_LOG"
"""

    def run_scrollback(
        self, *arguments: str, expected_code: int = 0, **environment: str
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            [str(SCROLLBACK), *arguments],
            text=True,
            capture_output=True,
            cwd=ROOT,
            env={**self.environment, **environment},
            check=False,
            timeout=10,
        )
        self.assertEqual(expected_code, completed.returncode, completed.stderr)
        return completed

    def captures(self) -> list[Path]:
        return list(self.root.glob("context-scrollback.*"))

    def test_opens_terminal_exported_file(self) -> None:
        exported = self.root / "ghostty.txt"
        exported.write_text("ghostty scrollback\n")

        self.run_scrollback(str(exported))

        self.assertEqual(
            f"path={exported}\ncontent=ghostty scrollback\n",
            self.editor_log.read_text(),
        )
        self.assertTrue(exported.exists())

    def test_captures_tmux_scrollback_without_terminal_file(self) -> None:
        self.write_command(
            "tmux",
            """#!/bin/sh
printf '%s\n' "$*" >"$CONTEXT_SCROLLBACK_COMMAND_LOG"
printf 'tmux scrollback\n'
""",
        )

        self.run_scrollback(TMUX="/tmp/tmux/default,1,0", TMUX_PANE="%7")

        lines = self.editor_log.read_text().splitlines()
        captured = Path(lines[0].removeprefix("path="))
        self.assertEqual("content=tmux scrollback", lines[1])
        self.assertEqual(
            "capture-pane -p -J -S - -t %7\n", self.command_log.read_text()
        )
        self.assertFalse(captured.exists())

    def test_herdr_precedes_tmux_and_terminal_file(self) -> None:
        self.write_command(
            "herdr",
            """#!/bin/sh
printf 'herdr:%s\n' "$*" >"$CONTEXT_SCROLLBACK_COMMAND_LOG"
printf 'herdr scrollback\n'
""",
        )
        self.write_command(
            "tmux",
            """#!/bin/sh
printf 'tmux:%s\n' "$*" >"$CONTEXT_SCROLLBACK_COMMAND_LOG"
printf 'tmux scrollback\n'
""",
        )
        exported = self.root / "ghostty.txt"
        exported.write_text("ghostty scrollback\n")

        self.run_scrollback(
            str(exported),
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p3",
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%7",
        )

        self.assertIn("content=herdr scrollback", self.editor_log.read_text())
        self.assertEqual(
            "herdr:pane read w1:p3 --source recent-unwrapped --format text --lines 1000000\n",
            self.command_log.read_text(),
        )
        captured = Path(
            self.editor_log.read_text().splitlines()[0].removeprefix("path=")
        )
        self.assertFalse(captured.exists())

    def test_reports_missing_herdr_cli(self) -> None:
        completed = self.run_scrollback(
            expected_code=1,
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p3",
            PATH=f"{self.bin}:/usr/bin:/bin",
        )

        self.assertIn("Herdr CLI not found", completed.stderr)
        self.assertEqual([], self.captures())

    def test_cleans_up_when_herdr_capture_fails(self) -> None:
        self.write_command("herdr", "#!/bin/sh\nexit 2\n")

        completed = self.run_scrollback(
            expected_code=1, HERDR_ENV="1", HERDR_PANE_ID="w1:p3"
        )

        self.assertIn("could not read Herdr pane w1:p3", completed.stderr)
        self.assertEqual([], self.captures())

    def test_reports_missing_tmux_cli(self) -> None:
        completed = self.run_scrollback(
            expected_code=1,
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%7",
            PATH=f"{self.bin}:/usr/bin:/bin",
        )

        self.assertIn("tmux CLI not found", completed.stderr)
        self.assertEqual([], self.captures())

    def test_cleans_up_when_tmux_capture_fails(self) -> None:
        self.write_command("tmux", "#!/bin/sh\nexit 2\n")

        completed = self.run_scrollback(
            expected_code=1, TMUX="/tmp/tmux/default,1,0", TMUX_PANE="%7"
        )

        self.assertIn("could not read tmux pane %7", completed.stderr)
        self.assertEqual([], self.captures())

    def test_plain_terminal_reports_missing_provider(self) -> None:
        completed = self.run_scrollback(expected_code=1)

        self.assertIn("no scrollback provider", completed.stderr)
        self.assertFalse(self.editor_log.exists())

    def test_rejects_missing_terminal_file(self) -> None:
        completed = self.run_scrollback(str(self.root / "missing"), expected_code=1)

        self.assertIn("file does not exist", completed.stderr)
        self.assertFalse(self.editor_log.exists())


if __name__ == "__main__":
    unittest.main()

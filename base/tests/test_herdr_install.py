from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "base"


class HerdrShellTests(unittest.TestCase):
    def test_herdr_panes_are_exempt_from_idle_logout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "uname").write_text("#!/bin/sh\nprintf 'Linux\\n'\n")
            (bin_dir / "tty").write_text("#!/bin/sh\nprintf '/dev/pts/1\\n'\n")
            for command in ("uname", "tty"):
                (bin_dir / command).chmod(0o755)

            script = f'. "{BASE / ".profile"}"; printf "%s" "${{TMOUT-unset}}"'
            environment = {
                "HOME": str(root),
                "PATH": f"{bin_dir}:/usr/bin:/bin",
                "TERM": "xterm-256color",
                "HERDR_ENV": "1",
            }
            completed = subprocess.run(
                ["sh", "-c", script],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertEqual("unset", completed.stdout)


if __name__ == "__main__":
    unittest.main()

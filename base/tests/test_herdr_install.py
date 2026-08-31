from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import tomllib

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "base"


class HerdrInstallTests(unittest.TestCase):
    def test_base_installer_links_config_and_helpers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            completed = subprocess.run(
                [
                    str(ROOT / "dotbot/bin/dotbot"),
                    "-d",
                    str(ROOT),
                    "-c",
                    str(ROOT / "base.yaml"),
                    "--only",
                    "link",
                ],
                cwd=ROOT,
                env={**os.environ, "HOME": str(home)},
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, completed.returncode, completed.stderr)
            self.assertEqual(
                BASE / ".config/herdr/config.toml",
                (home / ".config/herdr/config.toml").resolve(),
            )
            self.assertEqual(
                BASE / ".config/hwt/config.yaml",
                (home / ".config/hwt/config.yaml").resolve(),
            )
            for name in (
                "herdr-insert-file-path",
                "herdr-open-dev-dir",
                "herdr-split-before",
            ):
                self.assertEqual(BASE / ".bin" / name, (home / ".bin" / name).resolve())
            self.assertEqual(
                BASE / ".functions/herdr.sh",
                (home / ".functions/herdr.sh").resolve(),
            )
            self.assertEqual(
                BASE / ".functions/_hwt",
                (home / ".functions/_hwt").resolve(),
            )

    def test_base_mise_fragment_provides_herdr_runtimes(self) -> None:
        config = tomllib.loads((BASE / ".config/mise/conf.d/00-base.toml").read_text())
        tools = config["tools"]
        for tool in (
            "herdr",
            "github:dkarter/hwt",
            "jq",
            "python",
            "node",
            "fd",
            "fzf",
            "gdu",
            "lazygit",
        ):
            self.assertIn(tool, tools)

    def test_local_plugins_support_linux_and_macos(self) -> None:
        manifests = (BASE / ".config/herdr/plugins").glob("*/herdr-plugin.toml")
        self.assertGreater(sum(1 for _ in manifests), 0)
        for manifest in (BASE / ".config/herdr/plugins").glob("*/herdr-plugin.toml"):
            with self.subTest(plugin=manifest.parent.name):
                platforms = tomllib.loads(manifest.read_text())["platforms"]
                self.assertEqual(["linux", "macos"], platforms)

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

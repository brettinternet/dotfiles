import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
SPEC = importlib.util.spec_from_file_location("install_lid_awake", SCRIPTS / "install-lid-awake.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS IOKit and Swift")
class LidAwakeTests(unittest.TestCase):
    def test_power_transitions_and_privilege_boundary(self):
        with tempfile.TemporaryDirectory(prefix="lid-awake-test-") as directory:
            binary = str(Path(directory) / "helper")
            source = str(SCRIPTS / "lid-awake.swift")
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-D", "TESTING", source,
                str(Path(__file__).with_name("lid-awake-policy.swift")), "-o", binary,
            ], check=True)
            subprocess.run([binary], check=True)
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", source, "-o", binary,
            ], check=True)
            invalid = subprocess.run([binary, "enable", "extra"], capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            self.assertIn("Usage:", invalid.stderr)
            if os.getuid() != 0:
                unprivileged = subprocess.run([binary, "enable"], capture_output=True, text=True)
                self.assertNotEqual(unprivileged.returncode, 0)
                self.assertIn("sudo rule", unprivileged.stderr)

    def test_installer_rejects_root_and_unsafe_account_before_any_commands(self):
        with patch.object(installer.subprocess, "run") as run:
            with patch.object(installer.os, "getuid", return_value=0):
                with self.assertRaises(SystemExit):
                    installer.main()
            with patch.object(installer.os, "getuid", return_value=501):
                with patch.object(installer.pwd, "getpwuid") as account:
                    account.return_value.pw_name = "unsafe ALL=(ALL)"
                    with self.assertRaises(SystemExit):
                        installer.main()
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()

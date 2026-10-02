import importlib.util
import os
from pathlib import Path
import shlex
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
            invalid = subprocess.run([binary, "enable"], capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            self.assertIn("Usage:", invalid.stderr)
            if os.getuid() != 0:
                unprivileged = subprocess.run([binary, "watch"], capture_output=True, text=True)
                self.assertNotEqual(unprivileged.returncode, 0)
                self.assertIn("root LaunchDaemon", unprivileged.stderr)

    def test_installer_rejects_root_before_any_commands(self):
        with patch.object(installer.subprocess, "run") as run:
            with patch.object(installer.os, "getuid", return_value=0):
                with self.assertRaises(SystemExit):
                    installer.main([])
            run.assert_not_called()

    def test_installer_elevates_once_and_quotes_paths(self):
        with patch.object(installer.subprocess, "run") as run:
            installer.main([])
        privileged = [c.args[0] for c in run.call_args_list if c.args[0][0] != "/usr/bin/xcrun"]
        self.assertEqual(len(privileged), 1, "Managed sudo may prompt on every call")
        self.assertEqual(privileged[0][:2], ["/usr/bin/sudo", "/bin/sh"])
        borrowed = installer.elevate(Path("/tmp/a b/install.sh"), "admin")
        self.assertEqual(borrowed[:3], ["/usr/bin/su", "admin", "-c"])
        self.assertEqual(shlex.split(borrowed[3]), ["/usr/bin/sudo", "/bin/sh", "/tmp/a b/install.sh"])
        script = installer.root_script(Path("/tmp/a b/x"), Path("/tmp/p"), 501, 20)
        # The control directory path contains a space and must stay one argument.
        self.assertIn("-o 501 -g 20 -m 755 '/Library/Application Support/local.lid-awake'", script)
        self.assertIn("'/tmp/a b/x'", script)


if __name__ == "__main__":
    unittest.main()

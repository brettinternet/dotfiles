import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
SPEC = importlib.util.spec_from_file_location("install_window_rules", SCRIPTS / "install-window-rules.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS and Swift")
class WindowRulesTests(unittest.TestCase):
    def test_rule_matching_and_argument_parsing(self):
        with tempfile.TemporaryDirectory(prefix="window-rules-test-") as directory:
            binary = str(Path(directory) / "policy")
            source = str(SCRIPTS / "window-rules.swift")
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-D", "TESTING", source,
                str(Path(__file__).with_name("window-rules-policy.swift")), "-o", binary,
            ], check=True)
            subprocess.run([binary], check=True)
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", source, "-o", binary], check=True)
            invalid = subprocess.run([binary], capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            self.assertIn("Usage:", invalid.stderr)

    def test_rebuilds_keep_the_designated_requirement(self):
        # TCC keeps Device Control and Data Access approval while the designated requirement is unchanged.
        with tempfile.TemporaryDirectory(prefix="window-rules-test-") as directory:
            directory = Path(directory)
            keychain = directory / "test.keychain-db"
            try:
                with patch.object(installer, "KEYCHAIN", keychain):
                    installer.open_keychain()
                    self.assertIsNone(installer.find_identity())
                    installer.create_identity(directory)
                    identity = installer.find_identity()
                    self.assertIsNotNone(identity)
                    signatures = []
                    for optimization in ("-O", "-Onone"):
                        binary = directory / optimization / "window-rules"
                        binary.parent.mkdir()
                        subprocess.run([
                            "xcrun", "swiftc", "-parse-as-library", optimization,
                            str(SCRIPTS / "window-rules.swift"), "-o", str(binary),
                        ], check=True)
                        installer.sign(binary, identity)
                        details = subprocess.run(["codesign", "-dvvv", "-r-", str(binary)],
                                                 capture_output=True, text=True, check=True)
                        output = details.stdout + details.stderr
                        signatures.append((
                            re.search(r"^CDHash=(\w+)", output, re.MULTILINE).group(1),
                            re.search(r"^designated => (.+)$", output, re.MULTILINE).group(1),
                        ))
            finally:
                if keychain.exists():
                    subprocess.run(["security", "delete-keychain", str(keychain)], check=True)
            (first_hash, first_requirement), (second_hash, second_requirement) = signatures
            self.assertNotEqual(first_hash, second_hash, "The builds differ")
            self.assertEqual(first_requirement, second_requirement)
            self.assertIn(f'identifier "{installer.LABEL}"', first_requirement)
            self.assertIn(f'certificate leaf = H"{identity.lower()}"', first_requirement)

    def test_installer_rejects_root_before_any_commands(self):
        with patch.object(installer.subprocess, "run") as run:
            with patch.object(installer.os, "getuid", return_value=0):
                with self.assertRaises(SystemExit):
                    installer.main([])
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()

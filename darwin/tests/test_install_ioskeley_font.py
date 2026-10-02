import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile


spec = importlib.util.spec_from_file_location(
    "install_ioskeley_font",
    Path(__file__).resolve().parents[1] / "scripts/install-ioskeley-font.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FontInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ioskeley-font-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)

    def report(self, family=None):
        return subprocess.CompletedProcess([], 0, json.dumps({
            "SPFontsDataType": [] if family is None else [{
                "path": "/Library/Fonts/custom-name.ttf",
                "enabled": "no",
                "typefaces": [{"family": family, "enabled": "no"}],
            }],
        }))

    def archive(self, path):
        with zipfile.ZipFile(path, "w") as bundle:
            bundle.writestr("Normal/Hinted/IoskeleyMonoTerm-Regular.ttf", b"regular")
            bundle.writestr("Normal/Hinted/IoskeleyMonoTerm-Bold.ttf", b"bold")
            bundle.writestr("Normal/Unhinted/IoskeleyMonoTerm-Regular.ttf", b"unhinted")
            bundle.writestr("Extended/Hinted/IoskeleyMonoTermExtended-Regular.ttf", b"wide")
            bundle.writestr("Normal/Hinted/../../outside.ttf", b"unsafe")

    def test_existing_family_skips_download_even_system_wide_or_disabled(self):
        with patch.object(module.subprocess, "run", return_value=self.report(module.FAMILY)) as run:
            module.main()
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], ["system_profiler", "SPFontsDataType", "-json"])

    def test_installs_only_one_variant_when_only_non_term_family_exists(self):
        def run(command, **kwargs):
            if command[0] == "system_profiler":
                return self.report("Ioskeley Mono")
            self.assertEqual(command[:3], ["gh", "release", "download"])
            self.archive(Path(command[-1]) / module.ASSET)
            return subprocess.CompletedProcess(command, 0)

        with patch.object(module.subprocess, "run", side_effect=run), patch.object(module.Path, "home", return_value=self.home):
            module.main()
        fonts = self.home / "Library/Fonts"
        self.assertEqual({p.name: p.read_bytes() for p in fonts.iterdir()}, {
            "IoskeleyMonoTerm-Regular.ttf": b"regular",
            "IoskeleyMonoTerm-Bold.ttf": b"bold",
        })
        self.assertFalse((self.home / "outside.ttf").exists())

    def test_unregistered_font_file_skips_download(self):
        fonts = self.home / "Library/Fonts/disabled"
        fonts.mkdir(parents=True)
        (fonts / "IoskeleyMonoTerm-Bold.ttf").write_bytes(b"existing")
        with patch.object(module.subprocess, "run", return_value=self.report()) as run, patch.object(module.Path, "home", return_value=self.home):
            module.main()
        run.assert_called_once()

    def test_inventory_or_download_failure_does_not_install(self):
        for results in (
            [subprocess.CalledProcessError(1, "system_profiler")],
            [self.report(), subprocess.CalledProcessError(1, "gh")],
        ):
            with self.subTest(results=results), patch.object(module.subprocess, "run", side_effect=results), patch.object(module.Path, "home", return_value=self.home):
                with self.assertRaises(subprocess.CalledProcessError):
                    module.main()
                self.assertFalse((self.home / "Library").exists())

    def test_conflict_refuses_entire_install_without_overwriting(self):
        archive = self.home / module.ASSET
        self.archive(archive)
        fonts = self.home / "fonts"
        fonts.mkdir()
        existing = fonts / "IoskeleyMonoTerm-Bold.ttf"
        existing.write_bytes(b"keep")
        with self.assertRaises(FileExistsError):
            module.install_archive(archive, fonts)
        self.assertEqual(list(fonts.iterdir()), [existing])
        self.assertEqual(existing.read_bytes(), b"keep")

    def test_unexpected_archive_layout_fails_without_creating_destination(self):
        archive = self.home / module.ASSET
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("other/font.ttf", b"font")
        destination = self.home / "fonts"
        with self.assertRaises(ValueError):
            module.install_archive(archive, destination)
        self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()

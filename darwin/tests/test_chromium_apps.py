import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "chromium_apps", Path(__file__).resolve().parents[1] / "scripts/chromium-apps.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ChromiumAppsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="chromium-apps-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / "config.json"
        self.browser = self.home / "fake browser"
        self.browser.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
        self.browser.chmod(0o755)

    def generate(self, apps):
        self.config.write_text(json.dumps({"apps": apps}))
        module.generate(self.config, self.home, self.browser)

    def test_launch_arguments_isolation_icons_and_rename(self):
        icon = self.home / "custom.icns"
        icon.write_bytes(b"icon fixture")
        name = "One's $(touch unexpected)"
        self.generate([
            {"id": "one", "name": name, "icon": str(icon)},
            {"id": "two", "name": "Two"},
        ])
        profiles = []
        for app_name in (name, "Two"):
            bundle = self.home / "Applications" / f"{app_name}.app"
            with (bundle / "Contents/Info.plist").open("rb") as source:
                info = plistlib.load(source)
            launch = bundle / "Contents/MacOS" / info["CFBundleExecutable"]
            args = subprocess.check_output([str(launch), "https://example.org/a b"], text=True).splitlines()
            profiles.append(args[0])
            self.assertEqual(args[1:], ["https://example.org/a b"])
        self.assertNotEqual(*profiles)
        bundle = self.home / "Applications" / f"{name}.app"
        self.assertEqual((bundle / "Contents/Resources/app.icns").read_bytes(), icon.read_bytes())
        profile = self.home / "Library/Application Support/Chromium-Profiles/one"
        profile.mkdir(parents=True)
        (profile / "sentinel").write_text("preserve")
        self.generate([{"id": "one", "name": "Renamed"}])
        self.assertFalse(bundle.exists())
        launch = self.home / "Applications/Renamed.app/Contents/MacOS/launch"
        self.assertEqual(subprocess.check_output([str(launch)], text=True).strip(), profiles[0])
        self.assertEqual((profile / "sentinel").read_text(), "preserve")
        self.assertTrue((self.home / "Applications/Two.app").exists())
        self.generate([{"id": "one", "name": "Renamed"}])

    def test_validation_precedes_generation(self):
        for invalid in (
            {"id": "../escape", "name": "Two"},
            {"id": "two", "name": "../escape"},
            {"id": "one", "name": "Two"},
            {"id": "two", "name": "ONE"},
            {"id": "two", "name": "Two", "icon": "/missing.icns"},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                self.generate([{"id": "one", "name": "One"}, invalid])
            self.assertFalse((self.home / "Applications").exists())

    def test_unmanaged_collision_and_managed_symlinks_are_preserved(self):
        bundle = self.home / "Applications/One.app"
        bundle.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "unmanaged"):
            self.generate([{"id": "one", "name": "One"}])
        self.assertEqual(list(bundle.iterdir()), [])
        self.generate([{"id": "two", "name": "Two"}])
        with self.assertRaisesRegex(ValueError, "another app"):
            self.generate([{"id": "two", "name": "One"}])
        launch = self.home / "Applications/Two.app/Contents/MacOS/launch"
        saved = launch.with_name("saved")
        launch.rename(saved)
        launch.symlink_to(saved)
        before = saved.read_bytes()
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.generate([{"id": "two", "name": "Two"}])
        self.assertEqual(saved.read_bytes(), before)

    def test_missing_config_and_browser(self):
        module.generate(self.config, self.home, self.browser)
        self.assertFalse((self.home / "Applications").exists())
        self.config.write_text('{"apps": [{"id": "one", "name": "One"}]}')
        with self.assertRaisesRegex(ValueError, "executable not found"):
            module.generate(self.config, self.home, self.home / "missing")
        self.assertFalse((self.home / "Applications").exists())


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS AppleScript")
class URLHandlerTests(unittest.TestCase):
    def test_url_event_routes_and_quotes_without_launching_browser(self):
        with tempfile.TemporaryDirectory(prefix="chromium-url-test-") as temporary:
            root = Path(temporary)
            browser = root / "fake browser"
            browser.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            browser.chmod(0o755)
            source = Path(module.__file__).with_name("chromium-url-handler.applescript").read_text()
            source = source.replace(str(module.BROWSER), str(browser))
            # Run synchronously and capture fake-browser arguments instead of detaching.
            source = source.replace(' & " >/dev/null 2>&1 &"', '')
            script = root / "handler.applescript"
            script.write_text(source)
            compiled = root / "handler.scpt"
            subprocess.run(["osacompile", "-o", str(compiled), str(script)], check=True)
            url = "https://example.org/?q=one's%20two&literal=$(echo unexpected)"
            driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                      + '\ntell handlerScript to open location ' + json.dumps(url))
            result = subprocess.check_output(["osascript", "-e", driver], text=True).splitlines()
            self.assertEqual(result, [
                f"--user-data-dir={Path.home()}/Library/Application Support/Chromium", url,
            ])
            rejected = subprocess.run(["osascript", "-e", driver.replace(url, "file:///tmp/example")],
                                      capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("Only HTTP and HTTPS", rejected.stderr)
            run_driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                          + '\nrun handlerScript')
            self.assertEqual(subprocess.check_output(["osascript", "-e", run_driver], text=True).strip(),
                             f"--user-data-dir={Path.home()}/Library/Application Support/Chromium")

    def test_installer_preserves_unmanaged_apps(self):
        with tempfile.TemporaryDirectory(prefix="chromium-url-test-") as temporary:
            home = Path(temporary)
            destination = home / "Applications/Chromium Default.app"
            destination.mkdir(parents=True)
            sentinel = destination / "sentinel"
            sentinel.write_text("preserve")
            with self.assertRaisesRegex(ValueError, "unmanaged"):
                module.install_url_handler(home)
            self.assertEqual(sentinel.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()

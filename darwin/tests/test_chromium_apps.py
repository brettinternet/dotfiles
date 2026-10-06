import importlib.util
import json
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


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


class SetupTests(unittest.TestCase):
    def test_cli_setup_is_explicit_and_ordered(self):
        calls = []
        with patch.object(module, "install_url_handler", side_effect=lambda *a, **k: calls.append("install")), \
                patch.object(module, "set_default_browser", side_effect=lambda *a: calls.append("default")), \
                patch.object(module, "pin_to_dock", side_effect=lambda *a: calls.append("dock")), \
                patch.object(module, "generate", side_effect=lambda *a: calls.append("generate")):
            for flags, expected in (
                ([], ["generate"]),
                (["--install-url-handler"], ["install"]),
                (["--set-default"], ["default"]),
                (["--pin-to-dock"], ["dock"]),
                (["--install-url-handler", "--enable-remote-debugging", "--set-default", "--pin-to-dock"],
                 ["install", "default", "dock"]),
            ):
                calls.clear()
                with self.subTest(flags=flags), patch.object(sys, "argv", ["chromium-apps"] + flags):
                    module.main()
                    self.assertEqual(calls, expected)

    def test_default_failure_stops_setup(self):
        with patch.object(sys, "argv", ["chromium-apps", "--set-default", "--pin-to-dock"]), \
                patch.object(module.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "helper")), \
                patch.object(module, "pin_to_dock") as dock, self.assertRaises(SystemExit) as exited:
            module.main()
        self.assertEqual(exited.exception.code, 1)
        dock.assert_not_called()

    def test_dock_add_replace_and_repeat(self):
        with tempfile.TemporaryDirectory(prefix="chromium-dock-test-") as temporary:
            home = Path(temporary)
            bundle = home / "Applications/Chromium Default.app"
            bundle.mkdir(parents=True)
            browser = module.BROWSER.parent.parent.parent
            for existing, expected in (
                ([], ["--add", str(bundle)]),
                ([browser], ["--add", str(bundle), "--replacing", str(browser)]),
                ([bundle], None),
                ([browser, bundle], ["--remove", str(browser)]),
            ):
                for as_url in (False, True):
                    listing = "\n".join(f"tile\t{path.as_uri() if as_url else path}/\tpersistentApps"
                                        for path in existing)
                    with self.subTest(existing=existing, as_url=as_url), \
                            patch.object(module.shutil, "which", return_value="dockutil"), \
                            patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, listing)) as run:
                        module.pin_to_dock(home)
                        self.assertEqual(run.call_count, 2 if expected else 1)
                        if expected:
                            self.assertEqual(run.call_args.args[0], ["dockutil"] + expected)


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS AppleScript")
class URLHandlerTests(unittest.TestCase):
    def test_url_event_routes_and_quotes_without_launching_browser(self):
        with tempfile.TemporaryDirectory(prefix="chromium-url-test-") as temporary:
            root = Path(temporary)
            browser = root / "fake browser"
            browser.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            browser.chmod(0o755)
            source = Path(module.__file__).with_name("chromium-url-handler.applescript").read_text()
            # Capture the Launch Services argv without starting a real browser.
            source = source.replace('/usr/bin/open', shlex.quote(str(browser)))
            source = source.replace('do shell script "test -x "', '-- do shell script "test -x "')
            script = root / "handler.applescript"
            script.write_text(source)
            compiled = root / "handler.scpt"
            subprocess.run(["osacompile", "-o", str(compiled), str(script)], check=True)
            url = "https://example.org/?q=one's%20two&literal=$(echo unexpected)"
            driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                      + '\ntell handlerScript to open location ' + json.dumps(url))
            result = subprocess.check_output(["osascript", "-e", driver], text=True).splitlines()
            expected = [
                "-n", "-a", "/Applications/Chromium.app", "--args",
                f"--user-data-dir={Path.home()}/Library/Application Support/Chromium",
            ]
            self.assertEqual(result, expected + [url])
            debug_driver = driver.replace('\ntell handlerScript',
                                          '\nset remoteDebuggingEnabled of handlerScript to true'
                                          '\ntell handlerScript')
            self.assertEqual(subprocess.check_output(["osascript", "-e", debug_driver],
                                                     text=True).splitlines(),
                             expected + ["--remote-debugging-port=9222", url])
            rejected = subprocess.run(["osascript", "-e", driver.replace(url, "file:///tmp/example")],
                                      capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("Only HTTP and HTTPS", rejected.stderr)
            run_driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                          + '\nrun handlerScript')
            self.assertEqual(subprocess.check_output(["osascript", "-e", run_driver], text=True).splitlines(),
                             expected)
            debug_run = run_driver.replace('\nrun handlerScript',
                                           '\nset remoteDebuggingEnabled of handlerScript to true'
                                           '\nrun handlerScript')
            self.assertEqual(subprocess.check_output(["osascript", "-e", debug_run], text=True).splitlines(),
                             expected + ["--remote-debugging-port=9222"])
            document = root / "one's $(echo unexpected).xhtml"
            document.write_text("<html/>")
            file_driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                           + '\nset documentFile to POSIX file ' + json.dumps(str(document)) + ' as alias'
                           + '\ntell handlerScript to open {documentFile}')
            self.assertEqual(subprocess.check_output(["osascript", "-e", file_driver], text=True).splitlines(),
                             expected + [str(document.resolve())])

    def test_installer_compiles_opt_in_and_can_disable_it(self):
        run = subprocess.run

        def without_registration(args, **kwargs):
            if Path(args[0]).name == "lsregister":
                return subprocess.CompletedProcess(args, 0)
            return run(args, **kwargs)

        with tempfile.TemporaryDirectory(prefix="chromium-url-test-") as temporary:
            home = Path(temporary)
            bundle = home / "Applications/Chromium Default.app"
            for enabled in (False, True, False):
                with self.subTest(enabled=enabled), patch.object(module.subprocess, "run",
                                                                 side_effect=without_registration):
                    module.install_url_handler(home, remote_debugging=enabled)
                compiled = bundle / "Contents/Resources/Scripts/main.scpt"
                driver = ('set handlerScript to load script POSIX file ' + json.dumps(str(compiled))
                          + '\nreturn remoteDebuggingEnabled of handlerScript')
                result = subprocess.check_output(["osascript", "-e", driver], text=True).strip()
                self.assertEqual(result, str(enabled).lower())
                subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)
                with (bundle / "Contents/Info.plist").open("rb") as source:
                    info = plistlib.load(source)
                schemes = info["CFBundleURLTypes"][0]["CFBundleURLSchemes"]
                self.assertIn("http", schemes)
                self.assertIn("https", schemes)

    def test_default_helper_rejects_missing_bundle_without_changing_preferences(self):
        helper = Path(module.__file__).with_name("chromium-default-browser.swift")
        with tempfile.TemporaryDirectory(prefix="chromium-default-test-") as temporary:
            result = subprocess.run(["xcrun", "swift", str(helper), "--set", temporary],
                                    capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Install Chromium Default", result.stderr)

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

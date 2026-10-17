import importlib.util
import json
from pathlib import Path
import plistlib
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


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS AppKit")
class URLHandlerTests(unittest.TestCase):
    def test_native_events_and_installer_updates(self):
        run = subprocess.run
        with tempfile.TemporaryDirectory(prefix="chromium-url-test-") as temporary:
            home = Path(temporary)
            log = home / "arguments.jsonl"
            recorder = home / "record arguments"
            recorder.write_text(
                f"#!{sys.executable}\nimport json, sys\n"
                f"with open({str(log)!r}, 'a') as output:\n"
                "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            )
            recorder.chmod(0o755)
            source = Path(module.__file__).with_name("chromium-url-handler.swift").read_text()
            source = source.replace('"/usr/bin/open"', json.dumps(str(recorder)))
            browser = home / "Chromium.app"
            executable = browser / "Contents/MacOS/Chromium"
            executable.parent.mkdir(parents=True)
            executable.symlink_to(recorder)
            source = source.replace('"/Applications/Chromium.app"', json.dumps(str(browser)))
            script = home / "chromium-url-handler.swift"
            script.write_text(source)
            bundle = home / "Applications/Chromium Default.app"

            def without_registration(args, **kwargs):
                if Path(args[0]).name == "lsregister":
                    return subprocess.CompletedProcess(args, 0)
                return run(args, **kwargs)

            expected = [
                "-n", "-a", str(browser), "--args",
                f"--user-data-dir={Path.home()}/Library/Application Support/Chromium",
            ]
            url = "https://example.org/?q=one's%20two&literal=$(echo%20unexpected)"
            document = home / "one's $(echo unexpected).xhtml"
            document.write_text("<html/>")
            for enabled in (False, True, False):
                with self.subTest(enabled=enabled), \
                        patch.object(module, "__file__", str(home / "chromium-apps.py")), \
                        patch.object(module.subprocess, "run", side_effect=without_registration):
                    module.install_url_handler(home, remote_debugging=enabled)
                # Updating must replace the bundle, not retain old AppleScript resources.
                self.assertFalse((bundle / "Contents/Resources/Scripts").exists())
                subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)
                plist = bundle / "Contents/Info.plist"
                with plist.open("rb") as stream:
                    info = plistlib.load(stream)
                self.assertIn("http", info["CFBundleURLTypes"][0]["CFBundleURLSchemes"])
                self.assertIn("https", info["CFBundleURLTypes"][0]["CFBundleURLSchemes"])
                # Isolate Launch Services tests from the user's installed default handler.
                info["CFBundleIdentifier"] += ".test"
                with plist.open("wb") as stream:
                    plistlib.dump(info, stream)
                subprocess.run(["codesign", "--force", "--sign", "-", str(bundle)], check=True)
                for targets in ([url], [str(document.resolve())], []):
                    before = log.read_text().splitlines() if log.exists() else []
                    subprocess.run(["/usr/bin/open", "-W", "-n", "-a", str(bundle), *targets],
                                   check=True, timeout=20)
                    calls = [json.loads(line) for line in log.read_text().splitlines()[len(before):]]
                    flags = ["--remote-debugging-port=9222"] if enabled else []
                    self.assertEqual(calls, [expected + flags + targets])
                before = log.read_text()
                subprocess.run(["/usr/bin/open", "-W", "-n", "-a", str(bundle), "unsupported://example"],
                               check=True, timeout=20)
                self.assertEqual(log.read_text(), before)
                # Restore managed identity and seed obsolete applet resources for the next update.
                info["CFBundleIdentifier"] = "local.chromium-default-url-handler"
                with plist.open("wb") as stream:
                    plistlib.dump(info, stream)
                obsolete = bundle / "Contents/Resources/Scripts"
                obsolete.mkdir(parents=True)
                (obsolete / "main.scpt").write_text("obsolete applet")

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

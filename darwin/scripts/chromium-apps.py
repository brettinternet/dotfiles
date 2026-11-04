#!/usr/bin/env python3
"""Generate local macOS Chromium or Chrome launchers from a private JSON configuration."""

import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import tempfile
from typing import NamedTuple
from urllib.parse import unquote, urlsplit


PREFIX = "local.chromium-apps."


class Browser(NamedTuple):
    name: str
    app: Path
    executable: Path
    bundle_id: str
    # Relative to ~/Library/Application Support.
    data_dir: str
    debug_data_dir: str
    profiles_dir: str


BROWSERS = {
    "chromium": Browser("Chromium", Path("/Applications/Chromium.app"),
                        Path("/Applications/Chromium.app/Contents/MacOS/Chromium"),
                        "org.chromium.Chromium", "Chromium", "Chromium", "Chromium-Profiles"),
    # Chrome 136+ ignores --remote-debugging-port on its default data directory.
    "chrome": Browser("Google Chrome", Path("/Applications/Google Chrome.app"),
                      Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
                      "com.google.Chrome", "Google/Chrome", "Google/Chrome-Remote-Debugging",
                      "Google/Chrome-Profiles"),
}


def default_browser(home):
    """Use the installed handler's browser, else Chromium, else Chrome when only Chrome exists."""
    try:
        with (home / "Applications/Chromium Default.app/Contents/Info.plist").open("rb") as source:
            bundle_id = plistlib.load(source).get("BrowserBundleIdentifier")
    except (OSError, ValueError, AttributeError, plistlib.InvalidFileException):
        bundle_id = None
    for key, browser in BROWSERS.items():
        if browser.bundle_id == bundle_id:
            return key
    if not os.access(BROWSERS["chromium"].executable, os.X_OK) \
            and os.access(BROWSERS["chrome"].executable, os.X_OK):
        return "chrome"
    return "chromium"


def generate(config, home, browser=BROWSERS["chromium"]):
    if not config.exists():
        print(f"No configuration at {config}; nothing to generate.")
        return
    data = json.loads(config.read_text())
    if not isinstance(data, dict) or set(data) != {"apps"} or not isinstance(data["apps"], list):
        raise ValueError('Expected an object containing an "apps" array')
    plans = []
    ids, names = set(), set()
    apps_dir = home / "Applications"
    for entry in data["apps"]:
        if not isinstance(entry, dict) or set(entry) - {"id", "name", "icon"}:
            raise ValueError("Each app requires id and name, with an optional .icns icon")
        app_id, name = entry.get("id"), entry.get("name")
        if not isinstance(app_id, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", app_id):
            raise ValueError("IDs must use lowercase letters, digits, and internal hyphens")
        if (not isinstance(name, str) or not name.strip() or name != name.strip()
                or name.startswith(".") or any(c in name for c in '/:\\')
                or any(ord(c) < 32 for c in name)):
            raise ValueError("Names must be nonempty, plain filenames without leading/trailing spaces")
        if app_id in ids or name.casefold() in names:
            raise ValueError("App IDs and names must be unique")
        ids.add(app_id)
        names.add(name.casefold())
        icon = entry.get("icon")
        if icon is not None:
            if not isinstance(icon, str):
                raise ValueError("Icon must be a path to an .icns file")
            icon = Path(icon).expanduser()
            if not icon.is_absolute() or icon.suffix.lower() != ".icns" or not icon.is_file():
                raise ValueError(f"Icon must be an existing absolute or ~/ .icns path: {icon}")
        destination = apps_dir / f"{name}.app"
        existing = []
        for candidate in apps_dir.glob("*.app"):
            try:
                with (candidate / "Contents/Info.plist").open("rb") as source:
                    info = plistlib.load(source)
            except (OSError, ValueError, plistlib.InvalidFileException):
                continue
            if isinstance(info, dict) and info.get("ChromiumAppsID") == app_id:
                existing.append(candidate)
        if len(existing) > 1:
            raise ValueError(f"Multiple launchers for ID {app_id}; resolve manually")
        previous = existing[0] if existing else destination
        if os.path.lexists(destination) and destination != previous:
            raise ValueError(f"Refusing to replace another app: {destination}")
        if os.path.lexists(previous):
            if not existing:
                raise ValueError(f"Refusing to overwrite unmanaged app: {previous}")
            # Do not follow links when updating generated files.
            for relative in (".", "Contents", "Contents/MacOS", "Contents/Resources",
                             "Contents/Info.plist", "Contents/MacOS/launch", "Contents/Resources/app.icns"):
                if (previous / relative).is_symlink():
                    raise ValueError(f"Refusing to update symlink inside {previous}")
        plans.append((app_id, name, icon, previous, destination))
    if plans and not os.access(browser.executable, os.X_OK):
        raise ValueError(f"{browser.name} executable not found: {browser.executable}")
    for app_id, name, icon, previous, destination in plans:
        if previous != destination and previous.exists():
            previous.rename(destination)
        contents = destination / "Contents"
        (contents / "MacOS").mkdir(parents=True, exist_ok=True)
        (contents / "Resources").mkdir(exist_ok=True)
        profile = home / "Library/Application Support" / browser.profiles_dir / app_id
        executable = contents / "MacOS/launch"
        executable.write_text(
            "#!/bin/sh\nexec " + shlex.quote(str(browser.executable)) + " "
            + shlex.quote(f"--user-data-dir={profile}") + ' "$@"\n'
        )
        executable.chmod(0o755)
        info = {
            "CFBundleExecutable": "launch",
            "CFBundleIdentifier": PREFIX + app_id,
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1",
            "ChromiumAppsID": app_id,
        }
        # Use the browser's icon when no custom icon is configured.
        icon = icon or browser.executable.parent.parent / "Resources/app.icns"
        if icon.is_file():
            shutil.copyfile(icon, contents / "Resources/app.icns")
            info["CFBundleIconFile"] = "app.icns"
        with (contents / "Info.plist").open("wb") as output:
            plistlib.dump(info, output)
        print(f"Generated {destination} (profile: {profile})")


def install_url_handler(home, browser=BROWSERS["chromium"], remote_debugging=False):
    """Build a URL-event receiver; default-browser selection remains explicit."""
    destination = home / "Applications/Chromium Default.app"
    identifier = "local.chromium-default-url-handler"
    if os.path.lexists(destination):
        if destination.is_symlink() or any(p.is_symlink() for p in destination.rglob("*")):
            raise ValueError(f"Refusing to update symlink inside {destination}")
        try:
            with (destination / "Contents/Info.plist").open("rb") as source:
                old = plistlib.load(source)
        except (OSError, ValueError) as error:
            raise ValueError(f"Refusing to overwrite unmanaged app: {destination}") from error
        if not isinstance(old, dict) or old.get("CFBundleIdentifier") != identifier:
            raise ValueError(f"Refusing to overwrite unmanaged app: {destination}")
    if not os.access(browser.executable, os.X_OK):
        raise ValueError(f"{browser.name} executable not found: {browser.executable}")
    data_dir = home / "Library/Application Support" / (
        browser.debug_data_dir if remote_debugging else browser.data_dir)
    script = Path(__file__).resolve().with_name("chromium-url-handler.swift")
    # Build on the destination filesystem before replacing the managed bundle.
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="chromium-url-handler-", dir=destination.parent) as temporary:
        bundle = Path(temporary) / destination.name
        contents = bundle / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        # A newer SDK otherwise targets its own macOS, which Launch Services refuses to open here.
        target = f"{platform.machine()}-apple-macosx{platform.mac_ver()[0]}"
        subprocess.run(["/usr/bin/xcrun", "swiftc", "-O", "-target", target, str(script), "-o",
                        str(contents / "MacOS/launch")], check=True)
        plist = contents / "Info.plist"
        info = {
            "CFBundleExecutable": "launch",
            "CFBundlePackageType": "APPL",
            "BrowserApplication": str(browser.app),
            "BrowserBundleIdentifier": browser.bundle_id,
            "BrowserUserDataDir": str(data_dir),
            "ChromiumRemoteDebuggingEnabled": remote_debugging,
            "CFBundleIdentifier": identifier,
            "CFBundleName": "Chromium Default",
            "CFBundleDisplayName": "Chromium Default",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
            "LSUIElement": True,
            "CFBundleDocumentTypes": [{
                "CFBundleTypeName": "Web document",
                "CFBundleTypeRole": "Viewer",
                "LSItemContentTypes": ["public.html", "public.xhtml"],
            }],
            "CFBundleURLTypes": [{
                "CFBundleURLName": "Web URLs",
                "CFBundleTypeRole": "Viewer",
                "CFBundleURLSchemes": ["http", "https"],
            }],
        }
        icon = browser.executable.parent.parent / "Resources/app.icns"
        if icon.is_file():
            (contents / "Resources").mkdir()
            shutil.copyfile(icon, contents / "Resources/app.icns")
            info["CFBundleIconFile"] = "app.icns"
        with plist.open("wb") as output:
            plistlib.dump(info, output)
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(bundle)], check=True)
        previous = Path(temporary) / "previous.app"
        if destination.exists():
            destination.rename(previous)
        try:
            bundle.rename(destination)
        except OSError:
            if previous.exists():
                previous.rename(destination)
            raise
    subprocess.run([
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
        "-f", str(destination),
    ], check=True)
    print(f"Installed {destination} for {browser.name} (data: {data_dir})")
    print("Select Chromium Default in System Settings → Desktop & Dock → Default web browser.")
    if remote_debugging:
        print("Remote debugging enabled on loopback port 9222: local processes can access your browser.")
        if browser.debug_data_dir != browser.data_dir:
            print(f"{browser.name} refuses remote debugging on its default profile; sign in to this one.")
        print(f"Quit {browser.name} normally, then open Chromium Default to apply the launch flags.")


def set_default_browser(home):
    helper = Path(__file__).resolve().with_name("chromium-default-browser.swift")
    print("Setting HTTP/HTTPS defaults; approve any macOS confirmation prompts.", flush=True)
    subprocess.run(["/usr/bin/xcrun", "swift", str(helper), "--set",
                    str(home / "Applications/Chromium Default.app")], check=True)


def pin_to_dock(home, browser=BROWSERS["chromium"]):
    bundle = home / "Applications/Chromium Default.app"
    if not bundle.is_dir():
        raise ValueError("Install Chromium Default with --install-url-handler first")
    dockutil = shutil.which("dockutil")
    if not dockutil:
        raise ValueError("Dock setup requires dockutil (brew install dockutil)")
    # Match the real browser by URL, not a potentially unrelated tile's label.
    browser = browser.app
    listing = subprocess.run([dockutil, "--list"], check=True, capture_output=True, text=True)
    paths = set()
    for line in listing.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) >= 2:
            item = fields[1]
            paths.add((unquote(urlsplit(item).path) if item.startswith("file://") else item).rstrip("/"))
    if str(bundle) in paths:
        if str(browser) in paths:
            subprocess.run([dockutil, "--remove", str(browser)], check=True)
        return
    command = [dockutil, "--add", str(bundle)]
    if str(browser) in paths:
        command += ["--replacing", str(browser)]
    subprocess.run(command, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path,
                        default=Path.home() / ".config/chromium-apps/config.json")
    parser.add_argument("--browser", choices=BROWSERS, default=default_browser(Path.home()),
                        help="Browser to launch (default: the installed handler's, else chromium if installed)")
    parser.add_argument("--install-url-handler", action="store_true",
                        help="Install Chromium Default.app to route HTTP/HTTPS to the base browser profile")
    parser.add_argument("--enable-remote-debugging", action="store_true",
                        help="With --install-url-handler, enable unauthenticated loopback CDP on port 9222")
    parser.add_argument("--set-default", action="store_true",
                        help="Set and verify Chromium Default as the HTTP/HTTPS handler (macOS may prompt)")
    parser.add_argument("--pin-to-dock", action="store_true",
                        help="Pin Chromium Default, replacing the browser's tile if present (requires dockutil)")
    args = parser.parse_args()
    if args.enable_remote_debugging and not args.install_url_handler:
        parser.error("--enable-remote-debugging requires --install-url-handler")
    browser = BROWSERS[args.browser]
    try:
        if args.install_url_handler:
            install_url_handler(Path.home(), browser, remote_debugging=args.enable_remote_debugging)
        if args.set_default:
            set_default_browser(Path.home())
        if args.pin_to_dock:
            pin_to_dock(Path.home(), browser)
        if not (args.install_url_handler or args.set_default or args.pin_to_dock):
            generate(args.config.expanduser(), Path.home(), browser)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"chromium-apps: {error}\n")


if __name__ == "__main__":
    main()

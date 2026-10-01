#!/usr/bin/env python3
"""Generate local macOS Chromium launchers from a private JSON configuration."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil


PREFIX = "local.chromium-apps."
BROWSER = Path("/Applications/Chromium.app/Contents/MacOS/Chromium")


def generate(config, home, browser=BROWSER):
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
    if plans and not os.access(browser, os.X_OK):
        raise ValueError(f"Chromium executable not found: {browser}")
    for app_id, name, icon, previous, destination in plans:
        if previous != destination and previous.exists():
            previous.rename(destination)
        contents = destination / "Contents"
        (contents / "MacOS").mkdir(parents=True, exist_ok=True)
        (contents / "Resources").mkdir(exist_ok=True)
        profile = home / "Library/Application Support/Chromium-Profiles" / app_id
        executable = contents / "MacOS/launch"
        executable.write_text(
            "#!/bin/sh\nexec " + shlex.quote(str(browser)) + " "
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
        # Use Chromium's icon when no custom icon is configured.
        icon = icon or browser.parent.parent / "Resources/app.icns"
        if icon.is_file():
            shutil.copyfile(icon, contents / "Resources/app.icns")
            info["CFBundleIconFile"] = "app.icns"
        with (contents / "Info.plist").open("wb") as output:
            plistlib.dump(info, output)
        print(f"Generated {destination} (profile: {profile})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path,
                        default=Path.home() / ".config/chromium-apps/config.json")
    args = parser.parse_args()
    try:
        generate(args.config.expanduser(), Path.home())
    except (OSError, ValueError) as error:
        parser.exit(1, f"chromium-apps: {error}\n")


if __name__ == "__main__":
    main()

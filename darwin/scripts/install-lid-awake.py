#!/usr/bin/env python3
"""Opt this Mac into the Hammerspoon closed-lid sleep override (requires admin)."""

import os
from pathlib import Path
import plistlib
import pwd
import re
import subprocess
import sys
import tempfile

LABEL = "local.lid-awake"
HELPER = "/Library/PrivilegedHelperTools/local.lid-awake"
PLIST = f"/Library/LaunchDaemons/{LABEL}.plist"


def main():
    if sys.platform != "darwin" or os.getuid() == 0:
        sys.exit("Run as your normal macOS user, not with sudo.")
    user = pwd.getpwuid(os.getuid()).pw_name
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_-]*", user):
        sys.exit("Unsupported account name for the restricted sudo rule.")
    print("Keep the lid open during installation: the helper will restore normal sleep.", flush=True)
    source = Path(__file__).with_name("lid-awake.swift")
    with tempfile.TemporaryDirectory(prefix="lid-awake-install-") as directory:
        staging = Path(directory)
        binary = staging / "lid-awake"
        subprocess.run(
            ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-O", str(source), "-o", str(binary)],
            check=True,
        )
        plist = staging / "daemon.plist"
        plist.write_bytes(plistlib.dumps({
            "Label": LABEL,
            "ProgramArguments": [HELPER, "watch"],
            "RunAtLoad": True,
            "KeepAlive": True,
            "ThrottleInterval": 5,
            "StandardErrorPath": "/var/log/local.lid-awake.log",
        }))
        sudoers = staging / "sudoers"
        sudoers.write_text(
            f"{user} ALL=(root) NOPASSWD: {HELPER} enable, {HELPER} disable\n"
        )
        subprocess.run(["sudo", "/usr/sbin/visudo", "-cf", str(sudoers)], check=True)
        # Stop an earlier version before replacing it. A first install has no service.
        existing = subprocess.run(
            ["sudo", "/bin/launchctl", "print", f"system/{LABEL}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if existing.returncode == 0:
            subprocess.run(["sudo", HELPER, "disable"], check=True)
            subprocess.run(["sudo", "/bin/launchctl", "bootout", f"system/{LABEL}"], check=True)
        subprocess.run(
            ["sudo", "/usr/bin/install", "-d", "-o", "root", "-g", "wheel", "-m", "755",
             "/Library/PrivilegedHelperTools"], check=True,
        )
        for source_path, destination, mode in [
            (binary, HELPER, "755"),
            (plist, PLIST, "644"),
            (sudoers, "/etc/sudoers.d/local-lid-awake", "440"),
        ]:
            subprocess.run(
                ["sudo", "/usr/bin/install", "-o", "root", "-g", "wheel", "-m", mode,
                 str(source_path), destination], check=True,
            )
        subprocess.run(["sudo", "/bin/launchctl", "bootstrap", "system", PLIST], check=True)
    print("Installed locally. Reload Hammerspoon to show the Lid menu. Sleep starts enabled.")


if __name__ == "__main__":
    main()

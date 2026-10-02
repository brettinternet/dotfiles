#!/usr/bin/env python3
"""Opt this Mac into the Hammerspoon closed-lid sleep override (one sudo session)."""

import argparse
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile

LABEL = "local.lid-awake"
HELPER = "/Library/PrivilegedHelperTools/local.lid-awake"
PLIST = f"/Library/LaunchDaemons/{LABEL}.plist"
CONTROL = "/Library/Application Support/local.lid-awake"
OLD_SUDOERS = "/etc/sudoers.d/local-lid-awake"


def root_script(binary, plist, uid, gid):
    q = shlex.quote
    return f"""set -eu
/bin/launchctl bootout system/{LABEL} 2>/dev/null || true
/usr/bin/pmset -a disablesleep 0
/bin/rm -f {q(OLD_SUDOERS)}
/usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
/usr/bin/install -o root -g wheel -m 755 {q(str(binary))} {q(HELPER)}
/usr/bin/install -o root -g wheel -m 644 {q(str(plist))} {q(PLIST)}
/usr/bin/install -d -o {uid} -g {gid} -m 755 {q(CONTROL)}
/bin/launchctl bootstrap system {q(PLIST)}
"""


def elevate(script, admin):
    command = ["/usr/bin/sudo", "/bin/sh", str(script)]
    if admin:
        # A standard user borrows a separate administrator's sudo rights.
        command = ["/usr/bin/su", admin, "-c", shlex.join(command)]
    return command


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admin", help="administrator account to run sudo as, if you are not one")
    args = parser.parse_args(argv)
    if sys.platform != "darwin" or os.getuid() == 0:
        sys.exit("Run as the macOS user who will use the Lid menu, not with sudo.")
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
        script = staging / "install.sh"
        script.write_text(root_script(binary, plist, os.getuid(), os.getgid()))
        # Root reads the staged files directly, so they stay private to this user.
        subprocess.run(elevate(script, args.admin), check=True)
    print("Installed locally. Reload Hammerspoon to show the Lid menu. Sleep starts enabled.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Install the window-rules LaunchAgent for the current user (no sudo)."""

import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import sys
import tempfile

LABEL = "local.window-rules"
HOME = Path.home()
BINARY = HOME / "Library/Application Support" / LABEL / "window-rules"
PLIST = HOME / "Library/LaunchAgents" / f"{LABEL}.plist"
LOG = HOME / "Library/Logs" / f"{LABEL}.log"
# A dedicated keychain avoids the login keychain, which terminals outside the GUI
# security session cannot write. Its empty password adds no weaker access than a
# login-keychain key that codesign may use without prompting.
KEYCHAIN = HOME / "Library/Keychains/dotfiles-local-codesign.keychain-db"
IDENTITY = "Dotfiles Local Code Signing"


def open_keychain():
    if not KEYCHAIN.exists():
        subprocess.run(["/usr/bin/security", "create-keychain", "-p", "", str(KEYCHAIN)], check=True)
        subprocess.run(["/usr/bin/security", "set-keychain-settings", str(KEYCHAIN)], check=True)
    subprocess.run(["/usr/bin/security", "unlock-keychain", "-p", "", str(KEYCHAIN)], check=True)


def find_identity():
    found = subprocess.run(
        ["/usr/bin/security", "find-certificate", "-c", IDENTITY, "-Z", str(KEYCHAIN)],
        capture_output=True, text=True,
    )
    match = re.search(r"^SHA-1 hash: ([0-9A-F]{40})$", found.stdout, re.MULTILINE)
    return match.group(1) if found.returncode == 0 and match else None


def create_identity(directory):
    """Create a self-signed code-signing certificate in the dedicated keychain."""
    key, cert, bundle = (directory / name for name in ("key.pem", "cert.pem", "identity.p12"))
    password = secrets.token_hex(16)  # Only protects the transient import file.
    subprocess.run([
        "/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650",
        "-keyout", str(key), "-out", str(cert), "-subj", f"/CN={IDENTITY}",
        "-addext", "basicConstraints=critical,CA:false",
        "-addext", "keyUsage=critical,digitalSignature",
        "-addext", "extendedKeyUsage=critical,codeSigning",
    ], check=True, capture_output=True)
    subprocess.run([
        "/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(key), "-in", str(cert),
        "-out", str(bundle), "-passout", f"pass:{password}",
    ], check=True)
    # -T lets codesign use the private key without a keychain prompt.
    subprocess.run([
        "/usr/bin/security", "import", str(bundle), "-k", str(KEYCHAIN), "-P", password,
        "-T", "/usr/bin/codesign",
    ], check=True)
    # Without Apple tool partitions, codesign needs a GUI prompt (errSecInternalComponent).
    subprocess.run([
        "/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", "",
        str(KEYCHAIN),
    ], check=True, stdout=subprocess.DEVNULL)


def sign(binary, identity):
    """TCC matches the designated requirement (identifier and certificate), not the
    binary hash, so rebuilds signed by the same certificate keep their Device Control and Data Access approval."""
    subprocess.run(
        ["/usr/bin/codesign", "--force", "--sign", identity, "--keychain", str(KEYCHAIN),
         "--identifier", LABEL, str(binary)],
        check=True,
    )


def install_binary(built, installed):
    installed.parent.mkdir(parents=True, exist_ok=True)
    staged = installed.with_name(f".{installed.name}.new")
    shutil.copy2(built, staged)
    os.replace(staged, installed)


def main(argv=None):
    if sys.platform != "darwin" or os.getuid() == 0:
        sys.exit("Run as the macOS user whose session should be watched, not with sudo.")
    source = Path(__file__).with_name("window-rules.swift")
    with tempfile.TemporaryDirectory(prefix="window-rules-install-") as directory:
        directory = Path(directory)
        built = directory / BINARY.name
        subprocess.run(
            ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-O", str(source), "-o", str(built)],
            check=True,
        )
        open_keychain()
        identity = find_identity()
        if identity is None:
            create_identity(directory)
            identity = find_identity()
            if identity is None:
                sys.exit(f"Could not find the '{IDENTITY}' certificate after creating it.")
        sign(built, identity)
        install_binary(built, BINARY)
    PLIST.parent.mkdir(parents=True, exist_ok=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    PLIST.write_bytes(plistlib.dumps({
        "Label": LABEL,
        "ProgramArguments": [str(BINARY), "watch"],
        "RunAtLoad": True,
        "KeepAlive": True,
        "ThrottleInterval": 5,
        "ProcessType": "Interactive",
        "StandardErrorPath": str(LOG),
    }))
    domain = f"gui/{os.getuid()}"
    subprocess.run(["/bin/launchctl", "bootout", f"{domain}/{LABEL}"], stderr=subprocess.DEVNULL)
    subprocess.run(["/bin/launchctl", "bootstrap", domain, str(PLIST)], check=True)
    print(f"Running. If not yet allowed, enable {BINARY} under")
    print("System Settings > Privacy & Security > Device Control and Data Access. Updates keep the approval.")
    print(f"Log: {LOG}")


if __name__ == "__main__":
    main()

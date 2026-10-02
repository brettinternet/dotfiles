#!/usr/bin/env python3
"""Install Ioskeley Mono Term for the current user unless already installed."""

import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import zipfile


FAMILY = "Ioskeley Mono Term"
ASSET = "IoskeleyMono-Term.zip"


def installed():
    result = subprocess.run(
        ["system_profiler", "SPFontsDataType", "-json"],
        check=True, capture_output=True, text=True,
    )
    fonts = json.loads(result.stdout)["SPFontsDataType"]
    if any(
        face.get("family") == FAMILY
        for font in fonts
        for face in font.get("typefaces", [])
    ):
        return True
    # The profiler can omit user fonts (including disabled/unregistered files).
    return any(
        font.is_file()
        for directory in (Path.home() / "Library/Fonts", Path("/Library/Fonts"))
        for font in directory.rglob("IoskeleyMonoTerm-*.ttf")
    )


def install_archive(archive, destination):
    with zipfile.ZipFile(archive) as bundle:
        # Install one variant only: mixing hinted/unhinted creates duplicates.
        members = [
            entry for entry in bundle.infolist()
            if PurePosixPath(entry.filename).parent == PurePosixPath("Normal/Hinted")
            and PurePosixPath(entry.filename).name.startswith("IoskeleyMonoTerm-")
            and PurePosixPath(entry.filename).suffix == ".ttf"
        ]
        if not members:
            raise ValueError("Release archive contains no normal-width hinted fonts")
        names = [PurePosixPath(entry.filename).name for entry in members]
        if len(names) != len(set(names)):
            raise ValueError("Release archive contains duplicate font names")
        # Refuse conflicts before writing any fonts, including dangling symlinks.
        for name in names:
            target = destination / name
            if target.exists() or target.is_symlink():
                raise FileExistsError(f"Refusing to overwrite {target}")
        destination.mkdir(parents=True, exist_ok=True)
        for entry, name in zip(members, names):
            with bundle.open(entry) as source, (destination / name).open("xb") as target:
                shutil.copyfileobj(source, target)
    return len(members)


def main():
    if installed():
        print(f"{FAMILY} is already installed; skipping")
        return
    with tempfile.TemporaryDirectory(prefix="ioskeley-font-") as staging:
        subprocess.run(
            ["gh", "release", "download", "--repo", "ahatem/IoskeleyMono",
             "--pattern", ASSET, "--dir", staging],
            check=True,
        )
        destination = Path.home() / "Library/Fonts"
        count = install_archive(Path(staging) / ASSET, destination)
        print(f"Installed {count} {FAMILY} fonts in {destination}")


if __name__ == "__main__":
    main()

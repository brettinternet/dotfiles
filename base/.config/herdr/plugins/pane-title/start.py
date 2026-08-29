#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path


def main() -> None:
    watcher = Path(__file__).with_name("watch.py")
    subprocess.Popen(
        [sys.executable, str(watcher)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        start_new_session=True,
    )


if __name__ == "__main__":
    main()

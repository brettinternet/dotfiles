from __future__ import annotations

import os
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EDITOR = ROOT / "base/.bin/context-editor"


class ContextEditorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.prompt = self.root / "prompt.md"
        self.prompt.write_text("draft\n")
        self.log = self.root / "calls.log"
        self.environment = {
            key: value
            for key, value in os.environ.items()
            if key
            not in {
                "CONTEXT_EDITOR_CODE",
                "CONTEXT_EDITOR_GHOSTTY_APP",
                "CONTEXT_EDITOR_MODE",
                "CONTEXT_EDITOR_NVIM",
                "DISPLAY",
                "HERDR_ENV",
                "HERDR_PANE_ID",
                "HERDR_TAB_ID",
                "HERDR_WORKSPACE_ID",
                "SSH_CLIENT",
                "SSH_CONNECTION",
                "SSH_TTY",
                "TMUX",
                "TMUX_PANE",
                "WAYLAND_DISPLAY",
            }
        }
        self.environment.update(
            {
                "CONTEXT_EDITOR_TEST_LOG": str(self.log),
                "PATH": f"{self.bin}:{self.environment['PATH']}",
            }
        )
        self.write_command(
            "nvim",
            '#!/bin/sh\nprintf "nvim:%s\\n" "$*" >>"$CONTEXT_EDITOR_TEST_LOG"\n',
        )
        self.write_command(
            "code",
            '#!/bin/sh\nprintf "code:%s\\n" "$*" >>"$CONTEXT_EDITOR_TEST_LOG"\n',
        )

    def write_command(self, name: str, content: str) -> Path:
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)
        return path

    def run_editor(
        self, mode: str = "auto", *, expected_code: int = 0, **environment: str
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            [str(EDITOR), "--mode", mode, str(self.prompt)],
            text=True,
            capture_output=True,
            cwd=ROOT,
            env={**self.environment, **environment},
            check=False,
            timeout=10,
        )
        self.assertEqual(
            expected_code, completed.returncode, completed.stderr or completed.stdout
        )
        return completed

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_profile_selects_dispatcher_with_vim_fallback(self) -> None:
        for installed in (False, True):
            with self.subTest(installed=installed):
                home = self.root / f"home-{installed}"
                editor = home / ".bin/context-editor"
                editor.parent.mkdir(parents=True)
                if installed:
                    editor.write_text("#!/bin/sh\n")
                    editor.chmod(0o755)
                completed = subprocess.run(
                    [
                        "sh",
                        "-c",
                        '. "$1"; printf "%s\\n%s\\n%s\\n" "$VISUAL" "$EDITOR" "$SYSTEMD_EDITOR"',
                        "sh",
                        str(ROOT / "base/.profile"),
                    ],
                    text=True,
                    capture_output=True,
                    env={
                        **self.environment,
                        "DISPLAY": ":0",
                        "HOME": str(home),
                        "TERM": "xterm-256color",
                    },
                    check=False,
                    timeout=10,
                )
                self.assertEqual(0, completed.returncode, completed.stderr)
                expected = str(editor) if installed else "vim"
                self.assertEqual(
                    [expected, expected, expected], completed.stdout.splitlines()
                )

    def install_herdr(self) -> None:
        self.write_command(
            "herdr",
            """#!/usr/bin/env bash
set -eu
printf 'herdr:%s\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
case "$1:$2" in
  pane:current)
    printf '%s\\n' '{"result":{"pane":{"pane_id":"w1:p1","workspace_id":"w1"}}}'
    ;;
  pane:layout)
    [[ "${3:-}:${4:-}" == "--pane:w1:p1" ]] || exit 2
    if [[ -n "${HERDR_TEST_LAYOUT:-}" ]]; then
      printf '%s\\n' "$HERDR_TEST_LAYOUT"
    else
      printf '%s\\n' '{"result":{"layout":{"focused_pane_id":"w1:p9","panes":[{"pane_id":"w1:p1","rect":{"width":120,"height":60}},{"pane_id":"w1:p9","rect":{"width":40,"height":100}}]}}}'
    fi
    ;;
  pane:split)
    printf '%s\\n' '{"result":{"pane":{"pane_id":"w1:p2"}}}'
    ;;
  tab:create)
    printf '%s\\n' '{"result":{"tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p3"}}}'
    ;;
  pane:run)
    PATH=/usr/bin:/bin /bin/bash -c "$4" &
    ;;
  pane:close|tab:close)
    ;;
  *)
    exit 2
    ;;
esac
""",
        )

    def install_tmux(self) -> None:
        self.write_command(
            "tmux",
            """#!/usr/bin/env bash
set -eu
printf 'tmux:%s\\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
case "$1" in
  display-message)
    printf '%s\\n' "$TMUX_PANE"
    ;;
  split-window)
    child_command="${!#}"
    /bin/bash -c "$child_command" >/dev/null 2>&1 &
    printf '%%2\\n'
    ;;
  kill-pane)
    ;;
  *)
    exit 2
    ;;
esac
""",
        )

    def test_auto_uses_herdr_pane_without_workspace_environment(self) -> None:
        self.install_herdr()

        self.run_editor(
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p1",
            SSH_CONNECTION="client remote 22",
        )

        calls = self.calls()
        self.assertIn("herdr:pane layout --pane w1:p1", calls)
        self.assertTrue(
            any(
                call.startswith("herdr:pane split w1:p1 --direction right")
                for call in calls
            )
        )
        self.assertIn(f"nvim:{self.prompt}", calls)
        self.assertIn("herdr:pane close w1:p2", calls)

    def test_physically_tall_herdr_pane_splits_down(self) -> None:
        self.install_herdr()

        self.run_editor(
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p1",
            HERDR_TEST_LAYOUT='{"result":{"layout":{"panes":[{"pane_id":"w1:p1","rect":{"width":79,"height":67}}]}}}',
        )

        self.assertTrue(
            any(
                call.startswith("herdr:pane split w1:p1 --direction down")
                for call in self.calls()
            )
        )

    def test_physically_wide_herdr_pane_splits_right(self) -> None:
        self.install_herdr()

        self.run_editor(
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p1",
            HERDR_TEST_LAYOUT='{"result":{"layout":{"panes":[{"pane_id":"w1:p1","rect":{"width":158,"height":67}}]}}}',
        )

        self.assertTrue(
            any(
                call.startswith("herdr:pane split w1:p1 --direction right")
                for call in self.calls()
            )
        )

    def test_malformed_herdr_layout_falls_back_to_right(self) -> None:
        self.install_herdr()

        self.run_editor(
            HERDR_ENV="1",
            HERDR_PANE_ID="w1:p1",
            HERDR_TEST_LAYOUT='{"result":{"layout":{"panes":"invalid"}}}',
        )

        self.assertTrue(
            any(
                call.startswith("herdr:pane split w1:p1 --direction right")
                for call in self.calls()
            )
        )

    def test_auto_prefers_herdr_over_tmux(self) -> None:
        self.install_herdr()
        self.install_tmux()

        self.run_editor(
            HERDR_ENV="1",
            HERDR_WORKSPACE_ID="w1",
            HERDR_PANE_ID="w1:p1",
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%1",
            SSH_CONNECTION="client remote 22",
        )

        self.assertFalse(any(call.startswith("tmux:") for call in self.calls()))

    def test_auto_uses_tmux_pane_over_ssh(self) -> None:
        self.install_tmux()

        self.run_editor(
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%1",
            SSH_CONNECTION="client remote 22",
        )

        calls = self.calls()
        self.assertTrue(
            any(call.startswith("tmux:split-window -h -t %1") for call in calls)
        )
        self.assertIn(f"nvim:{self.prompt}", calls)
        self.assertIn("tmux:kill-pane -t %2", calls)

    def test_auto_falls_back_when_tmux_control_is_unreachable(self) -> None:
        self.write_command("tmux", "#!/bin/sh\nexit 1\n")

        completed = self.run_editor(
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%1",
            SSH_TTY="/dev/pts/1",
        )

        self.assertIn("tmux control is unavailable", completed.stderr)
        self.assertEqual([f"nvim:{self.prompt}"], self.calls())

    def test_auto_uses_terminal_over_ssh_without_herdr(self) -> None:
        self.run_editor(SSH_CONNECTION="client remote 22")

        self.assertEqual([f"nvim:{self.prompt}"], self.calls())

    def test_auto_falls_back_when_herdr_context_is_unreachable(self) -> None:
        self.write_command("herdr", "#!/bin/sh\nexit 1\n")

        completed = self.run_editor(
            HERDR_ENV="1",
            HERDR_WORKSPACE_ID="w1",
            HERDR_PANE_ID="w1:p1",
            SSH_TTY="/dev/pts/1",
        )

        self.assertIn("Herdr control is unavailable", completed.stderr)
        self.assertEqual([f"nvim:{self.prompt}"], self.calls())

    def test_explicit_herdr_tab_closes_only_created_tab(self) -> None:
        self.install_herdr()

        self.run_editor(
            "herdr-tab",
            HERDR_ENV="1",
            HERDR_WORKSPACE_ID="stale",
            HERDR_PANE_ID="w1:p1",
        )

        calls = self.calls()
        self.assertTrue(
            any(call.startswith("herdr:tab create --workspace w1") for call in calls)
        )
        self.assertIn("herdr:tab close w1:t2", calls)
        self.assertNotIn("herdr:pane close w1:p1", calls)

    def test_tmux_child_failure_is_returned_and_created_pane_is_closed(self) -> None:
        self.install_tmux()
        self.write_command("nvim", "#!/bin/sh\nexit 7\n")

        self.run_editor(
            "tmux-pane",
            expected_code=7,
            TMUX="/tmp/tmux/default,1,0",
            TMUX_PANE="%1",
        )

        self.assertIn("tmux:kill-pane -t %2", self.calls())

    def test_explicit_code_waits_for_vscode(self) -> None:
        self.run_editor("code")
        self.assertEqual([f"code:--wait {self.prompt}"], self.calls())

    def test_child_signal_records_failure_before_exiting(self) -> None:
        completion = self.root / "completion"
        self.write_command(
            "nvim",
            """#!/bin/sh
trap 'exit 0' HUP INT TERM
printf 'ready\n' >>"$CONTEXT_EDITOR_TEST_LOG"
while :; do sleep 1; done
""",
        )
        process = subprocess.Popen(
            [str(EDITOR), "--child", str(self.prompt), str(completion), "nvim"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=ROOT,
            env=self.environment,
            start_new_session=True,
        )
        try:
            for _ in range(50):
                if "ready" in self.calls():
                    break
                time.sleep(0.02)
            else:
                self.fail("child editor did not start")
            os.killpg(process.pid, signal.SIGTERM)
            process.communicate(timeout=5)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()

        self.assertEqual(129, process.returncode)
        self.assertEqual("129\n", completion.read_text())

    def test_parent_signal_closes_created_pane_and_exits(self) -> None:
        self.install_herdr()
        self.write_command(
            "nvim",
            """#!/bin/sh
trap 'exit 0' HUP INT TERM
printf 'ready\n' >>"$CONTEXT_EDITOR_TEST_LOG"
while :; do sleep 1; done
""",
        )
        environment = {
            **self.environment,
            "HERDR_ENV": "1",
            "HERDR_WORKSPACE_ID": "w1",
            "HERDR_PANE_ID": "w1:p1",
        }
        process = subprocess.Popen(
            [str(EDITOR), "--mode", "herdr-pane", str(self.prompt)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=ROOT,
            env=environment,
            start_new_session=True,
        )
        try:
            for _ in range(100):
                if "ready" in self.calls():
                    break
                time.sleep(0.02)
            else:
                self.fail("Herdr child editor did not start")
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=5)
            self.assertEqual(130, process.returncode)
            self.assertIn("herdr:pane close w1:p2", self.calls())
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)

    def test_tmux_parent_signal_closes_created_pane_and_exits(self) -> None:
        self.install_tmux()
        self.write_command(
            "nvim",
            """#!/bin/sh
trap 'exit 0' HUP INT TERM
printf 'ready\n' >>"$CONTEXT_EDITOR_TEST_LOG"
while :; do sleep 1; done
""",
        )
        environment = {
            **self.environment,
            "TMUX": "/tmp/tmux/default,1,0",
            "TMUX_PANE": "%1",
        }
        process = subprocess.Popen(
            [str(EDITOR), "--mode", "tmux-pane", str(self.prompt)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=ROOT,
            env=environment,
            start_new_session=True,
        )
        try:
            for _ in range(100):
                if "ready" in self.calls():
                    break
                time.sleep(0.02)
            else:
                self.fail("tmux child editor did not start")
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=5)
            self.assertEqual(130, process.returncode)
            self.assertIn("tmux:kill-pane -t %2", self.calls())
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)

    def test_ghostty_parent_signal_closes_created_window_and_exits(self) -> None:
        ghostty = self.root / "Ghostty.app"
        ghostty.mkdir()
        self.write_command("uname", "#!/bin/sh\nprintf 'Darwin\\n'\n")
        self.write_command(
            "nvim",
            """#!/bin/sh
trap 'exit 0' HUP INT TERM
printf 'ready\n' >>"$CONTEXT_EDITOR_TEST_LOG"
while :; do sleep 1; done
""",
        )
        self.write_command(
            "osascript",
            """#!/bin/sh
printf 'osascript:%s\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
if [ "$#" -eq 6 ]; then
  PATH=/usr/bin:/bin "$2" --child "$3" "$4" "$6" >/dev/null 2>&1 &
  printf 'terminal-1\n'
fi
""",
        )
        environment = {
            **self.environment,
            "CONTEXT_EDITOR_GHOSTTY_APP": str(ghostty),
        }
        process = subprocess.Popen(
            [str(EDITOR), "--mode", "ghostty", str(self.prompt)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=ROOT,
            env=environment,
            start_new_session=True,
        )
        try:
            for _ in range(100):
                if "ready" in self.calls():
                    break
                time.sleep(0.02)
            else:
                self.fail("Ghostty child editor did not start")
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=5)
            self.assertEqual(130, process.returncode)
            self.assertIn("osascript:- terminal-1", self.calls())
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)

    def test_auto_uses_ghostty_locally_on_macos(self) -> None:
        ghostty = self.root / "Ghostty.app"
        ghostty.mkdir()
        self.write_command("uname", "#!/bin/sh\nprintf 'Darwin\\n'\n")
        self.write_command(
            "osascript",
            """#!/bin/sh
printf 'osascript:%s\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
if [ "$#" -eq 6 ]; then
  printf '0\n' >"$4"
  printf 'terminal-1\n'
fi
""",
        )

        self.run_editor(CONTEXT_EDITOR_GHOSTTY_APP=str(ghostty))

        self.assertTrue(any(call.startswith("osascript:- ") for call in self.calls()))
        self.assertIn("osascript:- terminal-1", self.calls())

    def test_auto_uses_vscode_in_graphical_non_macos_session(self) -> None:
        self.write_command("uname", "#!/bin/sh\nprintf 'Linux\\n'\n")

        self.run_editor(DISPLAY=":0")

        self.assertEqual([f"code:--wait {self.prompt}"], self.calls())

    def test_ghostty_child_uses_resolved_nvim_path(self) -> None:
        ghostty = self.root / "Ghostty.app"
        ghostty.mkdir()
        self.write_command("uname", "#!/bin/sh\nprintf 'Darwin\\n'\n")
        self.write_command(
            "osascript",
            """#!/bin/sh
printf 'osascript:%s\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
if [ "$#" -eq 6 ]; then
  PATH=/usr/bin:/bin "$2" --child "$3" "$4" "$6"
  printf 'terminal-1\n'
fi
""",
        )

        self.run_editor("ghostty", CONTEXT_EDITOR_GHOSTTY_APP=str(ghostty))

        self.assertIn(f"nvim:{self.prompt}", self.calls())
        self.assertIn("osascript:- terminal-1", self.calls())

    def test_ghostty_child_failure_closes_created_window(self) -> None:
        ghostty = self.root / "Ghostty.app"
        ghostty.mkdir()
        self.write_command("uname", "#!/bin/sh\nprintf 'Darwin\\n'\n")
        self.write_command("nvim", "#!/bin/sh\nexit 7\n")
        self.write_command(
            "osascript",
            """#!/bin/sh
printf 'osascript:%s\n' "$*" >>"$CONTEXT_EDITOR_TEST_LOG"
if [ "$#" -eq 6 ]; then
  PATH=/usr/bin:/bin "$2" --child "$3" "$4" "$6"
  printf 'terminal-1\n'
fi
""",
        )

        self.run_editor(
            "ghostty",
            expected_code=7,
            CONTEXT_EDITOR_GHOSTTY_APP=str(ghostty),
        )

        self.assertIn("osascript:- terminal-1", self.calls())

    def test_ghostty_launch_failure_returns_without_waiting(self) -> None:
        ghostty = self.root / "Ghostty.app"
        ghostty.mkdir()
        self.write_command("uname", "#!/bin/sh\nprintf 'Darwin\\n'\n")
        self.write_command("osascript", "#!/bin/sh\nexit 3\n")

        completed = self.run_editor(
            "ghostty",
            expected_code=1,
            CONTEXT_EDITOR_GHOSTTY_APP=str(ghostty),
        )

        self.assertIn("could not open Ghostty editor window", completed.stderr)

    def test_child_failure_is_returned_and_created_pane_is_closed(self) -> None:
        self.install_herdr()
        self.write_command("nvim", "#!/bin/sh\nexit 7\n")

        self.run_editor(
            "herdr-pane",
            expected_code=7,
            HERDR_ENV="1",
            HERDR_WORKSPACE_ID="w1",
            HERDR_PANE_ID="w1:p1",
        )

        self.assertIn("herdr:pane close w1:p2", self.calls())

    def test_unknown_mode_fails_clearly(self) -> None:
        completed = self.run_editor("elsewhere", expected_code=1)

        self.assertIn("unknown mode 'elsewhere'", completed.stderr)


if __name__ == "__main__":
    unittest.main()

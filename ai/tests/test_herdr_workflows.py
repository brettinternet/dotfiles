import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


AI_ROOT = Path(__file__).parents[1]
WORKSPACE_SCRIPT = AI_ROOT / "herdr/plugins/last-workspace/workspace.py"
NAVIGATION_SCRIPT = AI_ROOT / "herdr/plugins/seamless-navigation/dispatch.sh"

spec = importlib.util.spec_from_file_location("last_workspace", WORKSPACE_SCRIPT)
last_workspace = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(last_workspace)


class LastWorkspaceTest(unittest.TestCase):
    def test_record_tracks_only_workspace_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            state_dir = Path(temporary)

            self.assertEqual(last_workspace.record(state_dir, "w1"), "")
            self.assertEqual(last_workspace.record(state_dir, "w2"), "w1")
            self.assertEqual(last_workspace.record(state_dir, "w2"), "w1")
            self.assertEqual((state_dir / "current").read_text(), "w2\n")
            self.assertEqual((state_dir / "previous").read_text(), "w1\n")

    def test_toggle_focuses_previous_workspace(self):
        with tempfile.TemporaryDirectory() as temporary:
            state_dir = Path(temporary)
            last_workspace.record(state_dir, "w1")
            last_workspace.record(state_dir, "w2")
            environment = {"HERDR_PLUGIN_STATE_DIR": temporary}

            with (
                mock.patch.dict(os.environ, environment, clear=True),
                mock.patch.object(last_workspace, "focused_workspace", return_value="w2"),
                mock.patch.object(last_workspace.subprocess, "run") as run,
                mock.patch.object(last_workspace.sys, "argv", ["workspace.py", "toggle"]),
            ):
                last_workspace.main()

            self.assertEqual(run.call_args.args[0], ["herdr", "workspace", "focus", "w1"])


class SeamlessNavigationTest(unittest.TestCase):
    def run_dispatch(self, process_name, *arguments):
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            log = temporary_path / "calls"
            herdr = temporary_path / "herdr"
            herdr.write_text(
                "#!/bin/sh\n"
                "if [ \"$1 $2\" = \"pane process-info\" ]; then\n"
                f"  printf '%s\\n' '{{\"result\":{{\"process_info\":{{\"foreground_processes\":[{{\"name\":\"{process_name}\"}}]}}}}}}'\n"
                "  exit 0\n"
                "fi\n"
                f"printf '%s\\n' \"$*\" >> '{log}'\n"
            )
            herdr.chmod(0o755)
            environment = os.environ | {
                "HERDR_BIN_PATH": str(herdr),
                "HERDR_ACTIVE_PANE_ID": "w1:p2",
            }
            subprocess.run(
                ["sh", str(NAVIGATION_SCRIPT), *arguments],
                check=True,
                env=environment,
            )
            return log.read_text().strip()

    def test_navigates_herdr_from_a_shell(self):
        call = self.run_dispatch("zsh", "navigate", "right", "ctrl+l")
        self.assertEqual(call, "pane focus --direction right --pane w1:p2")

    def test_forwards_navigation_into_vim(self):
        call = self.run_dispatch("nvim", "navigate", "right", "ctrl+l")
        self.assertEqual(call, "pane send-keys w1:p2 ctrl+l")

    def test_resizes_herdr_from_a_shell(self):
        call = self.run_dispatch("zsh", "resize", "left", "alt+shift+h")
        self.assertEqual(call, "pane resize --direction left --pane w1:p2")

    def test_resizes_herdr_when_vim_has_no_resize_mapping(self):
        call = self.run_dispatch("nvim", "resize", "left", "alt+shift+h")
        self.assertEqual(call, "pane resize --direction left --pane w1:p2")

    def test_sends_prefix_navigation_into_tmux(self):
        call = self.run_dispatch("tmux", "navigate", "right", "ctrl+l")
        self.assertEqual(call, "pane send-keys w1:p2 ctrl+a l")

    def test_sends_prefix_resize_into_tmux(self):
        call = self.run_dispatch("tmux", "resize", "left", "alt+shift+h")
        self.assertEqual(call, "pane send-keys w1:p2 ctrl+a alt+h")


if __name__ == "__main__":
    unittest.main()

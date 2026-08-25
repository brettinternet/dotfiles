import importlib.util
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


AI_ROOT = Path(__file__).parents[1]
WORKSPACE_SCRIPT = AI_ROOT / "herdr/plugins/last-workspace/workspace.py"
NAVIGATION_SCRIPT = AI_ROOT / "herdr/plugins/seamless-navigation/dispatch.sh"
WORKSPACE_PICKER_SCRIPT = AI_ROOT / "herdr/plugins/command-palette/workspace-picker.py"
FILEPATH_SCRIPT = AI_ROOT / ".bin/herdr-insert-file-path"
ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")

spec = importlib.util.spec_from_file_location("last_workspace", WORKSPACE_SCRIPT)
last_workspace = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(last_workspace)

picker_spec = importlib.util.spec_from_file_location("workspace_picker", WORKSPACE_PICKER_SCRIPT)
workspace_picker = importlib.util.module_from_spec(picker_spec)
assert picker_spec.loader is not None
picker_spec.loader.exec_module(workspace_picker)


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



class WorkspacePickerTest(unittest.TestCase):
    def setUp(self):
        self.state = {
            "workspaces": [
                {
                    "workspace_id": "w2",
                    "number": 2,
                    "label": "second",
                    "tab_count": 1,
                    "pane_count": 1,
                    "agent_status": "idle",
                    "active_tab_id": "w2:t1",
                },
                {
                    "workspace_id": "w1",
                    "number": 1,
                    "label": "first",
                    "tab_count": 1,
                    "pane_count": 1,
                    "agent_status": "working",
                    "active_tab_id": "w1:t1",
                },
            ],
            "tabs": [
                {
                    "workspace_id": "w1",
                    "tab_id": "w1:t1",
                    "number": 1,
                    "label": "agent",
                    "agent_status": "working",
                }
            ],
            "panes": [
                {
                    "workspace_id": "w1",
                    "tab_id": "w1:t1",
                    "pane_id": "w1:p1",
                    "agent": "omp",
                    "agent_status": "working",
                    "terminal_title_stripped": "Fix tests",
                    "focused": True,
                }
            ],
        }

    def test_rows_are_workspace_ordered(self):
        rows = [
            ANSI_ESCAPE.sub("", row)
            for row in workspace_picker.workspace_rows(self.state).splitlines()
        ]
        self.assertTrue(rows[0].startswith("w1\tfirst\t1 tab\t1 pane\t● working"))
        self.assertTrue(rows[1].startswith("w2\tsecond"))

    def test_preview_shows_tabs_panes_and_active_screen(self):
        screen = subprocess.CompletedProcess([], 0, stdout="active pane output\n")
        with mock.patch.object(workspace_picker, "herdr_command", return_value=screen) as herdr:
            preview = ANSI_ESCAPE.sub("", workspace_picker.workspace_preview(self.state, "w1"))

        self.assertIn("Tab 1  agent", preview)
        self.assertIn("w1:p1  omp  ● working  Fix tests", preview)
        self.assertIn("active pane output", preview)
        self.assertIn("--format", herdr.call_args.args)
        self.assertIn("ansi", herdr.call_args.args)

    def test_preview_honors_fzf_column_width(self):
        screen = subprocess.CompletedProcess([], 0, stdout=f"{workspace_picker.GREEN}{'x' * 80}\n")
        with (
            mock.patch.dict(os.environ, {"FZF_PREVIEW_COLUMNS": "41"}),
            mock.patch.object(workspace_picker, "herdr_command", return_value=screen),
        ):
            preview = workspace_picker.workspace_preview(self.state, "w1")

        plain_lines = [ANSI_ESCAPE.sub("", line) for line in preview.splitlines()]
        self.assertIn("─" * 40, plain_lines)
        self.assertTrue(all(len(line) <= 40 for line in plain_lines))

    def test_selection_focuses_workspace(self):
        selection = subprocess.CompletedProcess([], 0, stdout="w2\tsecond\t1 tabs\t1 panes\tidle\n")
        with (
            mock.patch.object(workspace_picker, "snapshot", return_value=self.state),
            mock.patch.object(workspace_picker.subprocess, "run", return_value=selection),
            mock.patch.object(workspace_picker, "herdr_command") as herdr,
        ):
            workspace_picker.pick_workspace()

        herdr.assert_called_once_with("workspace", "focus", "w2")

class CommandPaletteTest(unittest.TestCase):
    def test_invokes_selected_action_with_cli_argument_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            bin_dir = home / ".local/bin"
            bin_dir.mkdir(parents=True)
            log = home / "herdr.log"
            fzf = bin_dir / "fzf"
            fzf.write_text("#!/bin/sh\nsed -n '1p'\n")
            fzf.chmod(0o755)
            herdr = bin_dir / "herdr"
            herdr.write_text(
                "#!/bin/sh\n"
                "if [ \"$1 $2 $3\" = \"plugin action list\" ]; then\n"
                "  printf '%s\\n' '{\"result\":{\"actions\":[{\"title\":\"Equalize\",\"plugin_id\":\"brett.pane-equalize\",\"action_id\":\"equalize\"}]}}'\n"
                "  exit 0\n"
                "fi\n"
                f"printf '%s\\n' \"$*\" > '{log}'\n"
            )
            herdr.chmod(0o755)
            environment = os.environ | {
                "HOME": temporary,
                "HERDR_BIN_PATH": str(herdr),
            }

            subprocess.run(
                ["sh", str(AI_ROOT / "herdr/plugins/command-palette/palette.sh")],
                check=True,
                env=environment,
            )

            self.assertEqual(
                log.read_text().strip(),
                "plugin action invoke equalize --plugin brett.pane-equalize",
            )




class FilepathInsertionTest(unittest.TestCase):
    def test_inserts_plain_relative_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            bin_dir = home / ".local/bin"
            bin_dir.mkdir(parents=True)
            log = home / "herdr.log"
            for name, content in {
                "fd": "#!/bin/sh\nprintf '%s\\n' 'docs/file with spaces.md'\n",
                "fzf": "#!/bin/sh\nsed -n '1p'\n",
                "herdr": f"#!/bin/sh\nprintf '%s\\n' \"$*\" > '{log}'\n",
            }.items():
                executable = bin_dir / name
                executable.write_text(content)
                executable.chmod(0o755)

            environment = os.environ | {
                "HOME": temporary,
                "HERDR_BIN_PATH": str(bin_dir / "herdr"),
                "HERDR_ACTIVE_PANE_ID": "w1:p1",
                "HERDR_ACTIVE_PANE_CWD": temporary,
            }
            subprocess.run(["sh", str(FILEPATH_SCRIPT)], check=True, env=environment)

            self.assertEqual(log.read_text().strip(), "pane send-text w1:p1 docs/file with spaces.md")

if __name__ == "__main__":
    unittest.main()

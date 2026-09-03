import copy
import importlib.util
import json
import os
import re
import subprocess
import tempfile
import sys
import unittest
from pathlib import Path
from unittest import mock


BASE_ROOT = Path(__file__).parents[1]
WORKSPACE_SCRIPT = BASE_ROOT / ".config/herdr/plugins/last-workspace/workspace.py"
NAVIGATION_SCRIPT = BASE_ROOT / ".config/herdr/plugins/seamless-navigation/dispatch.sh"
WORKSPACE_PICKER_SCRIPT = BASE_ROOT / ".config/herdr/plugins/command-palette/workspace-picker.py"
PANE_TITLE_SCRIPT = BASE_ROOT / ".config/herdr/plugins/pane-title/sync.py"
PANE_TITLE_WATCHER = BASE_ROOT / ".config/herdr/plugins/pane-title/watch.py"
PREVIOUS_PANE_TRACKER = BASE_ROOT / ".config/herdr/plugins/previous-pane-focus/track-focus.sh"
PREVIOUS_PANE_RESTORER = BASE_ROOT / ".config/herdr/plugins/previous-pane-focus/restore-previous.sh"
FILEPATH_SCRIPT = BASE_ROOT / ".bin/herdr-insert-file-path"
ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")

spec = importlib.util.spec_from_file_location("last_workspace", WORKSPACE_SCRIPT)
last_workspace = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(last_workspace)

picker_spec = importlib.util.spec_from_file_location("workspace_picker", WORKSPACE_PICKER_SCRIPT)
workspace_picker = importlib.util.module_from_spec(picker_spec)
assert picker_spec.loader is not None
picker_spec.loader.exec_module(workspace_picker)

pane_title_spec = importlib.util.spec_from_file_location("pane_title", PANE_TITLE_SCRIPT)
pane_title = importlib.util.module_from_spec(pane_title_spec)
assert pane_title_spec.loader is not None
pane_title_spec.loader.exec_module(pane_title)

pane_title_watcher_spec = importlib.util.spec_from_file_location(
    "pane_title_watcher", PANE_TITLE_WATCHER
)
pane_title_watcher = importlib.util.module_from_spec(pane_title_watcher_spec)
assert pane_title_watcher_spec.loader is not None
with mock.patch.dict(sys.modules, {"sync": pane_title}):
    pane_title_watcher_spec.loader.exec_module(pane_title_watcher)


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


class PaneTitleTest(unittest.TestCase):
    def test_combines_agent_and_terminal_title(self):
        pane = {
            "pane_id": "w1:p1",
            "agent": "omp",
            "display_agent": None,
            "terminal_title_stripped": "Fix pane headers",
            "title": None,
        }

        with mock.patch.object(pane_title, "herdr_request") as request:
            pane_title.sync_pane(pane)

        request.assert_called_once_with(
            "pane.report_metadata",
            {
                "pane_id": "w1:p1",
                "source": "brett.pane-title",
                "title": "omp · Fix pane headers",
                "tokens": {"brett_pane_title": "1"},
            },
        )

    def test_does_not_duplicate_identical_agent_and_title(self):
        pane = {
            "agent": "omp",
            "terminal_title_stripped": "OMP",
        }

        self.assertEqual(pane_title.pane_title(pane), "omp")

    def test_custom_pane_label_overrides_automatic_title(self):
        pane = {
            "pane_id": "w1:p1",
            "label": "Database migration",
            "agent": None,
            "display_agent": None,
            "terminal_title_stripped": None,
            "title": "zsh",
            "tokens": {"brett_pane_title": "1"},
        }

        with (
            mock.patch.object(pane_title, "foreground_process_name") as process,
            mock.patch.object(pane_title, "herdr_request") as request,
        ):
            pane_title.sync_pane(pane)

        process.assert_not_called()
        request.assert_called_once_with(
            "pane.report_metadata",
            {
                "pane_id": "w1:p1",
                "source": "brett.pane-title",
                "clear_title": True,
                "tokens": {"brett_pane_title": None},
            },
        )

    def test_empty_custom_pane_label_restores_automatic_title(self):
        pane = {
            "pane_id": "w1:p1",
            "label": "  ",
            "agent": "omp",
            "terminal_title_stripped": "Fix pane headers",
            "title": None,
        }

        with mock.patch.object(pane_title, "herdr_request") as request:
            pane_title.sync_pane(pane)

        request.assert_called_once_with(
            "pane.report_metadata",
            {
                "pane_id": "w1:p1",
                "source": "brett.pane-title",
                "title": "omp · Fix pane headers",
                "tokens": {"brett_pane_title": "1"},
            },
        )

    def test_uses_terminal_title_without_agent_prefix_for_shell_pane(self):
        pane = {
            "pane_id": "w1:p2",
            "agent": None,
            "display_agent": None,
            "terminal_title_stripped": "project.py - Nvim",
            "title": None,
        }

        with mock.patch.object(pane_title, "herdr_request") as request:
            pane_title.sync_pane(pane)

        request.assert_called_once_with(
            "pane.report_metadata",
            {
                "pane_id": "w1:p2",
                "source": "brett.pane-title",
                "title": "project.py - Nvim",
                "tokens": {"brett_pane_title": "1"},
            },
        )

    def test_falls_back_to_foreground_process_for_untitled_shell(self):
        pane = {
            "pane_id": "w1:p3",
            "agent": None,
            "display_agent": None,
            "terminal_title_stripped": None,
            "title": None,
        }
        process_info = {
            "process_info": {
                "shell_pid": 10,
                "foreground_processes": [
                    {"pid": 10, "name": "zsh"},
                    {"pid": 11, "name": "lazygit"},
                ],
            }
        }

        with mock.patch.object(
            pane_title,
            "herdr_request",
            side_effect=[process_info, {"type": "ok"}],
        ) as request:
            pane_title.sync_pane(pane)

        self.assertEqual(
            request.call_args_list,
            [
                mock.call("pane.process_info", {"pane_id": "w1:p3"}),
                mock.call(
                    "pane.report_metadata",
                    {
                        "pane_id": "w1:p3",
                        "source": "brett.pane-title",
                        "title": "lazygit",
                        "tokens": {"brett_pane_title": "1"},
                    },
                ),
            ],
        )

    def test_event_syncs_only_its_pane(self):
        panes = [
            {
                "pane_id": "w1:p1",
                "agent": "omp",
                "terminal_title_stripped": "First",
                "title": None,
            },
            {
                "pane_id": "w1:p2",
                "agent": "claude",
                "terminal_title_stripped": "Second",
                "title": None,
            },
        ]
        snapshot = {"snapshot": {"panes": panes}}

        with (
            mock.patch.dict(os.environ, {"HERDR_PANE_ID": "w1:p2"}, clear=True),
            mock.patch.object(
                pane_title, "herdr_request", side_effect=[snapshot, {"type": "ok"}]
            ) as request,
        ):
            pane_title.main()

        self.assertEqual(
            request.call_args_list,
            [
                mock.call("session.snapshot", {}),
                mock.call(
                    "pane.report_metadata",
                    {
                        "pane_id": "w1:p2",
                        "source": "brett.pane-title",
                        "title": "claude · Second",
                        "tokens": {"brett_pane_title": "1"},
                    },
                ),
            ],
        )

    def test_watcher_refreshes_titles_without_querying_processes(self):
        pane = {
            "pane_id": "w1:p1",
            "agent": "omp",
            "terminal_title_stripped": "Updated task",
        }

        with (
            mock.patch.object(pane_title, "snapshot_panes", return_value=[pane]),
            mock.patch.object(pane_title, "foreground_process_name") as process,
            mock.patch.object(pane_title, "sync_pane") as sync_pane,
        ):
            pane_title_watcher.refresh_panes({}, {}, 20.0)

        process.assert_not_called()
        sync_pane.assert_called_once_with(pane, "")

    def test_watcher_throttles_background_process_queries(self):
        pane = {
            "pane_id": "w1:p2",
            "agent": None,
            "display_agent": None,
            "terminal_title_stripped": None,
            "focused": False,
        }

        with (
            mock.patch.object(pane_title, "snapshot_panes", return_value=[pane]),
            mock.patch.object(
                pane_title, "foreground_process_name", return_value="lazygit"
            ) as process,
            mock.patch.object(pane_title, "sync_pane") as sync_pane,
        ):
            names, refreshed = pane_title_watcher.refresh_panes({}, {}, 20.0)
            pane_title_watcher.refresh_panes(names, refreshed, 25.0)

        process.assert_called_once_with("w1:p2")
        self.assertEqual(
            sync_pane.call_args_list,
            [mock.call(pane, "lazygit"), mock.call(pane, "lazygit")],
        )

    def test_does_not_report_unchanged_title(self):
        pane = {
            "pane_id": "w1:p1",
            "agent": "omp",
            "display_agent": None,
            "terminal_title_stripped": "Fix pane headers",
            "title": "omp · Fix pane headers",
        }

        with mock.patch.object(pane_title, "herdr_request") as request:
            pane_title.sync_pane(pane)

        request.assert_not_called()


class PreviousPaneFocusTest(unittest.TestCase):
    def test_tracker_records_tab_with_pane(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ | {
                "XDG_STATE_HOME": temporary,
                "HERDR_TAB_ID": "w1:t1",
                "HERDR_PANE_ID": "w1:p1",
            }

            subprocess.run(["sh", str(PREVIOUS_PANE_TRACKER)], check=True, env=environment)
            subprocess.run(["sh", str(PREVIOUS_PANE_TRACKER)], check=True, env=environment)

            history = Path(temporary) / "herdr/previous-pane-focus.history"
            self.assertEqual(history.read_text(), "w1:t1\tw1:p1\n")

    def run_restore(self, history: str, panes: list[dict], closed_id: str) -> str:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state_dir = root / "herdr"
            state_dir.mkdir()
            (state_dir / "previous-pane-focus.history").write_text(history)
            log = root / "calls"
            herdr = root / "herdr-bin"
            pane_json = json.dumps({"result": {"panes": panes}})
            herdr.write_text(
                "#!/bin/sh\n"
                "if [ \"$1 $2\" = \"pane list\" ]; then\n"
                f"  printf '%s\\n' '{pane_json}'\n"
                "  exit 0\n"
                "fi\n"
                f"printf '%s\\n' \"$*\" > '{log}'\n"
            )
            herdr.chmod(0o755)
            environment = os.environ | {
                "XDG_STATE_HOME": temporary,
                "HERDR_BIN_PATH": str(herdr),
                "HERDR_PANE_ID": closed_id,
            }

            subprocess.run(["sh", str(PREVIOUS_PANE_RESTORER)], check=True, env=environment)
            return log.read_text().strip() if log.exists() else ""

    def test_restores_nearest_open_pane_above_closed_pane_in_same_tab(self):
        call = self.run_restore(
            "w1:t1\tw1:p1\nw1:t1\tw1:p3\nw2:t1\tw2:p1\nw1:t1\tw1:p2\n",
            [
                {"pane_id": "w1:p1", "tab_id": "w1:t1"},
                {"pane_id": "w2:p1", "tab_id": "w2:t1"},
            ],
            "w1:p2",
        )

        self.assertEqual(call, "agent focus w1:p1")

    def test_keeps_default_focus_when_same_tab_has_no_open_history(self):
        call = self.run_restore(
            "w2:t1\tw2:p1\nw1:t1\tw1:p2\n",
            [{"pane_id": "w2:p1", "tab_id": "w2:t1"}],
            "w1:p2",
        )

        self.assertEqual(call, "")


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

    def test_focus_bypasses_vim_navigation(self):
        call = self.run_dispatch("nvim", "focus", "right", "ctrl+alt+l")
        self.assertEqual(call, "pane focus --direction right --pane w1:p2")

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
        self.assertTrue(rows[0].startswith("w1\tw1\tfirst\t1 tab\t1 pane\t● working"))
        self.assertTrue(rows[1].startswith("w2\tw2\tsecond"))

    def test_pane_rows_include_searchable_metadata(self):
        rows = ANSI_ESCAPE.sub("", workspace_picker.pane_rows(self.state, "w1"))

        self.assertEqual("w1:p1\tw1\tTab 1\tw1:p1\tomp\t● working\tFix tests", rows)

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

    def test_cycles_preview_across_workspace_panes(self):
        state = copy.deepcopy(self.state)
        state["workspaces"][1]["pane_count"] = 2
        state["panes"].append(
            {
                "workspace_id": "w1",
                "tab_id": "w1:t1",
                "pane_id": "w1:p2",
                "agent": "claude",
                "agent_status": "idle",
                "terminal_title_stripped": "Review changes",
                "focused": False,
            }
        )
        screen = subprocess.CompletedProcess([], 0, stdout="pane output\n")
        with tempfile.TemporaryDirectory() as temporary:
            with (
                mock.patch.dict(os.environ, {"HERDR_PLUGIN_STATE_DIR": temporary}),
                mock.patch.object(workspace_picker, "herdr_command", return_value=screen) as herdr,
                mock.patch.object(workspace_picker, "herdr_request") as request,
            ):
                first = ANSI_ESCAPE.sub("", workspace_picker.workspace_preview(state, "w1"))
                workspace_picker.cycle_preview_pane("w1", 1)
                second = ANSI_ESCAPE.sub("", workspace_picker.workspace_preview(state, "w1"))
                workspace_picker.focus_selection(state, "w1:p2", "w1")
                workspace_picker.cycle_preview_pane("w1", 1)
                wrapped = ANSI_ESCAPE.sub("", workspace_picker.workspace_preview(state, "w1"))
                searched = ANSI_ESCAPE.sub("", workspace_picker.workspace_preview(state, "w1", "w1:p2"))

        self.assertIn("Pane 1/2  w1:p1", first)
        self.assertIn("Pane 2/2  w1:p2", second)
        self.assertIn("Pane 1/2  w1:p1", wrapped)
        self.assertIn("Pane 2/2  w1:p2", searched)
        herdr.assert_any_call("workspace", "focus", "w1")
        request.assert_called_once_with("pane.focus", {"pane_id": "w1:p2"})

    def test_selection_focuses_workspace(self):
        selection = subprocess.CompletedProcess([], 0, stdout="w2\tw2\tsecond\t1 tab\t1 pane\tidle\n")
        with (
            mock.patch.object(workspace_picker, "snapshot", return_value=self.state),
            mock.patch.object(workspace_picker.subprocess, "run", return_value=selection) as run,
            mock.patch.object(workspace_picker, "herdr_command") as herdr,
        ):
            workspace_picker.pick_workspace()
        herdr.assert_called_once_with("workspace", "focus", "w2")

        binding_args = [argument for argument in run.call_args.args[0] if argument.startswith("--bind=")]
        binding = ",".join(argument.removeprefix("--bind=") for argument in binding_args)
        self.assertIn("ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up", binding)
        self.assertIn("alt-up:execute-silent", binding)
        self.assertIn("alt-down:execute-silent", binding)
        self.assertIn("ctrl-f:reload-sync(", binding)
        self.assertIn("rows-panes {2}", binding)
        self.assertIn("change-prompt(Search panes › )+enable-search+clear-query", binding)
        self.assertIn("ctrl-b:reload-sync(", binding)
        self.assertIn("rows-workspaces", binding)
        self.assertIn("change-prompt(Go to workspace › )+enable-search+clear-query", binding)
        self.assertNotIn("disable-search", binding)
        self.assertIn("cycle {2} 1", binding)
        self.assertIn("cycle {2} -1", binding)
        self.assertIn("--with-nth=3..", run.call_args.args[0])
        self.assertIn("--id-nth=2", run.call_args.args[0])
        self.assertIn("--track", run.call_args.args[0])
        self.assertIn("--no-scrollbar", run.call_args.args[0])
        self.assertIn("--pointer=▶", run.call_args.args[0])

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
                ["sh", str(BASE_ROOT / ".config/herdr/plugins/command-palette/palette.sh")],
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

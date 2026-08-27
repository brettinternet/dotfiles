import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

MODULE_PATH = Path(__file__).with_name("workspace-picker.py")
SPEC = importlib.util.spec_from_file_location("workspace_picker", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
workspace_picker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = workspace_picker
SPEC.loader.exec_module(workspace_picker)


class WorkspacePickerTest(unittest.TestCase):
    def test_pane_rows_advance_to_next_tabs_first_pane_and_wrap(self) -> None:
        state = {
            "tabs": [
                {"workspace_id": "w1", "tab_id": "t2", "number": 2},
                {"workspace_id": "w1", "tab_id": "t1", "number": 1},
                {"workspace_id": "w1", "tab_id": "t3", "number": 3},
            ],
            "panes": [
                {"workspace_id": "w1", "tab_id": "t2", "pane_id": "p2b"},
                {"workspace_id": "w1", "tab_id": "t1", "pane_id": "p1b"},
                {"workspace_id": "w1", "tab_id": "t3", "pane_id": "p3a"},
                {"workspace_id": "w1", "tab_id": "t2", "pane_id": "p2a"},
                {"workspace_id": "w1", "tab_id": "t1", "pane_id": "p1a"},
            ],
        }

        def first_pane(after: str) -> str:
            return workspace_picker.pane_rows(state, "w1", after).split("\t", 1)[0]

        self.assertEqual(first_pane("w1"), "p1a")
        self.assertEqual(first_pane("p1b"), "p2a")
        self.assertEqual(first_pane("p2a"), "p3a")
        self.assertEqual(first_pane("p3a"), "p1a")

    def test_workspace_and_pane_modes_have_vim_navigation_aliases(self) -> None:
        state = {
            "workspaces": [
                {
                    "workspace_id": "w1",
                    "number": 1,
                    "label": "dotfiles",
                    "tab_count": 1,
                    "pane_count": 1,
                    "agent_status": "working",
                }
            ]
        }
        fzf_result = subprocess.CompletedProcess(["fzf"], 1, stdout="", stderr="")

        with (
            mock.patch.object(workspace_picker, "snapshot", return_value=state),
            mock.patch.object(workspace_picker, "reset_preview_indexes"),
            mock.patch.object(workspace_picker.subprocess, "run", return_value=fzf_result) as run,
        ):
            workspace_picker.pick_workspace()

        arguments = run.call_args.args[0]
        bindings = {
            key: action
            for argument in arguments
            if argument.startswith("--bind=")
            for key, action in (
                binding.split(":", 1)
                for binding in argument.removeprefix("--bind=").split(",")
            )
        }
        self.assertEqual(bindings["ctrl-l"], bindings["ctrl-f"])
        self.assertIn("+first", bindings["ctrl-f"])
        self.assertEqual(bindings["ctrl-h"], bindings["ctrl-b"])
        self.assertNotEqual(bindings["ctrl-h"], "backward-delete-char")


if __name__ == "__main__":
    unittest.main()

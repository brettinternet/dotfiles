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
        self.assertEqual(bindings["ctrl-h"], bindings["ctrl-b"])
        self.assertNotEqual(bindings["ctrl-h"], "backward-delete-char")


if __name__ == "__main__":
    unittest.main()

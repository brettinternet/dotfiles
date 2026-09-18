import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

CLOSE_PLUGIN = (
    Path(__file__).parents[1] / ".config" / "worktrunk" / "close-herdr-workspace.py"
)
CLOSE_SPEC = importlib.util.spec_from_file_location(
    "herdr_worktrunk_close", CLOSE_PLUGIN
)
assert CLOSE_SPEC and CLOSE_SPEC.loader
herdr_worktrunk_close = importlib.util.module_from_spec(CLOSE_SPEC)
CLOSE_SPEC.loader.exec_module(herdr_worktrunk_close)


class HerdrWorktrunkTests(unittest.TestCase):
    def test_closes_only_workspace_for_removed_checkout(self) -> None:
        workspace_list = """{
            "result": {
                "workspaces": [
                    {
                        "workspace_id": "w1",
                        "worktree": {"checkout_path": "/repo/.worktrees/removed"}
                    },
                    {
                        "workspace_id": "w2",
                        "worktree": {"checkout_path": "/repo"}
                    }
                ]
            }
        }"""

        with patch.object(herdr_worktrunk_close.subprocess, "run") as run:
            run.return_value.returncode = 0
            run.return_value.stdout = workspace_list
            self.assertEqual(herdr_worktrunk_close.main("/repo/.worktrees/removed"), 0)

        self.assertEqual(run.call_count, 2)
        self.assertEqual(
            run.call_args_list[1].args[0],
            ["herdr", "workspace", "close", "w1"],
        )

    def test_cleanup_is_noop_when_herdr_is_unavailable(self) -> None:
        with patch.object(
            herdr_worktrunk_close.subprocess,
            "run",
            side_effect=FileNotFoundError,
        ) as run:
            self.assertEqual(herdr_worktrunk_close.main("/repo/.worktrees/removed"), 0)

        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()

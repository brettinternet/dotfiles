import importlib.util
import os
import unittest
from pathlib import Path
from unittest.mock import patch


PLUGIN = (
    Path(__file__).parents[1]
    / ".config"
    / "herdr"
    / "plugins"
    / "worktrunk"
    / "create.py"
)
SPEC = importlib.util.spec_from_file_location("herdr_worktrunk", PLUGIN)
assert SPEC and SPEC.loader
herdr_worktrunk = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(herdr_worktrunk)

CLOSE_PLUGIN = PLUGIN.with_name("close.py")
CLOSE_SPEC = importlib.util.spec_from_file_location("herdr_worktrunk_close", CLOSE_PLUGIN)
assert CLOSE_SPEC and CLOSE_SPEC.loader
herdr_worktrunk_close = importlib.util.module_from_spec(CLOSE_SPEC)
CLOSE_SPEC.loader.exec_module(herdr_worktrunk_close)


class HerdrWorktrunkTests(unittest.TestCase):
    def test_creates_from_selected_checkout_and_requests_focus(self) -> None:
        context = '{"worktree":{"checkout_path":"/repo/project"}}'

        with (
            patch.dict(os.environ, {"HERDR_PLUGIN_CONTEXT_JSON": context}, clear=True),
            patch("builtins.input", side_effect=["feature/test", ""]),
            patch.object(herdr_worktrunk.subprocess, "run") as run,
        ):
            run.return_value.returncode = 0
            self.assertEqual(herdr_worktrunk.main(), 0)

        args, kwargs = run.call_args
        self.assertEqual(
            args[0],
            [
                "wt",
                "-C",
                "/repo/project",
                "switch",
                "--create",
                "feature/test",
                "--base",
                "@",
                "--no-cd",
                "--format=json",
            ],
        )
        self.assertEqual(kwargs["env"]["WORKTRUNK_HERDR_FOCUS"], "1")

    def test_blank_branch_cancels_without_creating(self) -> None:
        context = '{"workspace_cwd":"/repo/project"}'

        with (
            patch.dict(os.environ, {"HERDR_PLUGIN_CONTEXT_JSON": context}, clear=True),
            patch("builtins.input", return_value=""),
            patch.object(herdr_worktrunk.subprocess, "run") as run,
        ):
            self.assertEqual(herdr_worktrunk.main(), 0)

        run.assert_not_called()

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
            self.assertEqual(
                herdr_worktrunk_close.main("/repo/.worktrees/removed"), 0
            )

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
            self.assertEqual(
                herdr_worktrunk_close.main("/repo/.worktrees/removed"), 0
            )

        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()

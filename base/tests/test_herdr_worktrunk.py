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


if __name__ == "__main__":
    unittest.main()

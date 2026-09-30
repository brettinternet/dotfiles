import importlib.machinery
import importlib.util
import json
import subprocess
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

REMOVE_SCRIPT = Path(__file__).parents[1] / ".bin" / "herdr-remove-worktree"
REMOVE_SPEC = importlib.util.spec_from_loader(
    "herdr_worktrunk_remove",
    importlib.machinery.SourceFileLoader("herdr_worktrunk_remove", str(REMOVE_SCRIPT)),
)
assert REMOVE_SPEC and REMOVE_SPEC.loader
herdr_worktrunk_remove = importlib.util.module_from_spec(REMOVE_SPEC)
REMOVE_SPEC.loader.exec_module(herdr_worktrunk_remove)


class HerdrWorktrunkTests(unittest.TestCase):
    def setUp(self) -> None:
        environment = patch.dict(
            herdr_worktrunk_close.os.environ, {"HERDR_BIN_PATH": "herdr"}
        )
        environment.start()
        self.addCleanup(environment.stop)

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
            run.side_effect = [
                subprocess.CompletedProcess([], 0, workspace_list),
                subprocess.CompletedProcess([], 0),
                subprocess.CompletedProcess([], 0, '{"result":{"workspaces":[]}}'),
            ]
            self.assertEqual(herdr_worktrunk_close.main("/repo/.worktrees/removed"), 0)

        self.assertEqual(run.call_count, 3)
        self.assertEqual(
            run.call_args_list[1].args[0],
            ["herdr", "workspace", "close", "w1"],
        )

    def test_remove_requires_matching_checkout_and_confirmation(self) -> None:
        workspace = {
            "result": {
                "workspace": {
                    "worktree": {
                        "is_linked_worktree": True,
                        "checkout_path": "/repo/.worktrees/feature",
                        "repo_root": "/repo",
                    }
                }
            }
        }
        listing = {
            "items": [
                {
                    "branch": "feature",
                    "worktree": {"path": "/repo/.worktrees/feature", "main": False},
                }
            ]
        }
        with (
            patch.dict(
                herdr_worktrunk_remove.os.environ,
                {
                    "HERDR_ACTIVE_WORKSPACE_ID": "w1",
                    "HERDR_BIN_PATH": "herdr",
                    "WORKTRUNK_BIN_PATH": "wt",
                },
            ),
            patch.object(
                herdr_worktrunk_remove.subprocess,
                "check_output",
                side_effect=[
                    json.dumps(workspace).encode(),
                    json.dumps(listing).encode(),
                ],
            ) as output,
            patch.object(herdr_worktrunk_remove.subprocess, "run") as run,
            patch("builtins.input", return_value="feature"),
        ):
            run.return_value.returncode = 0
            self.assertEqual(herdr_worktrunk_remove.main(), 0)
        self.assertEqual(
            output.call_args_list[0].args[0], ["herdr", "workspace", "get", "w1"]
        )
        self.assertEqual(
            output.call_args_list[1].args[0],
            ["wt", "-C", "/repo", "list", "--format=json"],
        )
        run.assert_called_once_with(
            [
                "wt",
                "-C",
                "/repo",
                "remove",
                "/repo/.worktrees/feature",
                "--foreground",
                "--format=json",
            ],
            check=False,
        )

    def test_remove_cancelled_without_exact_branch(self) -> None:
        workspace = {
            "result": {
                "workspace": {
                    "worktree": {
                        "is_linked_worktree": True,
                        "checkout_path": "/repo/.worktrees/feature",
                        "repo_root": "/repo",
                    }
                }
            }
        }
        listing = {
            "items": [
                {
                    "branch": "feature",
                    "worktree": {
                        "path": "/repo/.worktrees/feature",
                        "main": False,
                    },
                }
            ]
        }
        with (
            patch.dict(
                herdr_worktrunk_remove.os.environ,
                {
                    "HERDR_ACTIVE_WORKSPACE_ID": "w1",
                    "HERDR_BIN_PATH": "herdr",
                    "WORKTRUNK_BIN_PATH": "wt",
                },
            ),
            patch.object(
                herdr_worktrunk_remove.subprocess,
                "check_output",
                side_effect=[
                    json.dumps(workspace).encode(),
                    json.dumps(listing).encode(),
                ],
            ),
            patch.object(herdr_worktrunk_remove.subprocess, "run") as run,
            patch("builtins.input", return_value="wrong"),
        ):
            self.assertEqual(herdr_worktrunk_remove.main(), 0)
        run.assert_not_called()

    def test_remove_rejects_unlisted_checkout(self) -> None:
        workspace = {
            "result": {
                "workspace": {
                    "worktree": {
                        "is_linked_worktree": True,
                        "checkout_path": "/repo/.worktrees/stale",
                        "repo_root": "/repo",
                    }
                }
            }
        }
        with (
            patch.dict(
                herdr_worktrunk_remove.os.environ,
                {
                    "HERDR_ACTIVE_WORKSPACE_ID": "w1",
                    "HERDR_BIN_PATH": "herdr",
                    "WORKTRUNK_BIN_PATH": "wt",
                },
            ),
            patch.object(
                herdr_worktrunk_remove.subprocess,
                "check_output",
                side_effect=[
                    json.dumps(workspace).encode(),
                    json.dumps({"items": []}).encode(),
                ],
            ),
            patch.object(herdr_worktrunk_remove.subprocess, "run") as run,
        ):
            self.assertEqual(herdr_worktrunk_remove.main(), 1)
        run.assert_not_called()

    def test_cleanup_reports_when_herdr_is_unavailable(self) -> None:
        with patch.object(
            herdr_worktrunk_close.subprocess,
            "run",
            side_effect=FileNotFoundError,
        ) as run:
            self.assertEqual(herdr_worktrunk_close.main("/repo/.worktrees/removed"), 1)

        run.assert_called_once()

    def test_cleanup_reports_lookup_and_close_failures(self) -> None:
        listing = subprocess.CompletedProcess(
            [],
            0,
            json.dumps(
                {
                    "result": {
                        "workspaces": [
                            {
                                "workspace_id": "w1",
                                "worktree": {"checkout_path": "/removed"},
                            },
                        ]
                    }
                }
            ),
        )
        failure = subprocess.CalledProcessError(1, ["herdr"])
        for responses in (
            [failure],
            [subprocess.CompletedProcess([], 0, "not json")],
            [subprocess.CompletedProcess([], 0, '{"error":"unreachable"}')],
            [listing, failure],
            [listing, subprocess.CompletedProcess([], 0), listing],
        ):
            with (
                self.subTest(responses=responses),
                patch.object(
                    herdr_worktrunk_close.subprocess, "run", side_effect=responses
                ),
                patch("sys.stderr") as stderr,
            ):
                self.assertEqual(herdr_worktrunk_close.main("/removed"), 1)
                self.assertIn(
                    "Herdr cleanup failed", stderr.write.call_args_list[0].args[0]
                )

    def test_cleanup_without_matching_workspace_does_not_close_anything(self) -> None:
        with patch.object(herdr_worktrunk_close.subprocess, "run") as run:
            run.return_value.stdout = (
                '{"result":{"workspaces":[{"workspace_id":"w1","worktree":null}]}}'
            )
            self.assertEqual(herdr_worktrunk_close.main("/removed"), 0)
        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()

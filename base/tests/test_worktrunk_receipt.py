import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).parents[1] / ".config" / "worktrunk" / "record-agent-worktree.py"
)


class WorktrunkReceiptTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="worktrunk-receipt-test-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name).resolve() / "repo"
        self.repo.mkdir()
        self.git("init", "--initial-branch=main")
        self.git(
            "-c",
            "user.name=Test",
            "-c",
            "user.email=test@example.com",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "--allow-empty",
            "-m",
            "Initial",
        )
        self.checkout = self.repo / ".worktrees" / "feature with spaces"
        self.git("worktree", "add", "-b", "feature", str(self.checkout))
        self.env = dict(
            os.environ,
            PI_SESSION_ID="creator",
            PI_LOOP_RUN_ID="loop",
            PI_SESSION_FILE="/sessions/creator.jsonl",
        )

    def git(self, *args: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(self.repo), *args], text=True, stderr=subprocess.PIPE
        ).strip()

    def receipt_path(self) -> Path:
        return (
            Path(self.git("-C", str(self.checkout), "rev-parse", "--absolute-git-dir"))
            / "agent-creation.json"
        )

    def record(self, **context: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(SCRIPT)],
            input=json.dumps(
                {
                    "hook_type": "pre-start",
                    "worktree_path": str(self.checkout),
                    "branch": "feature",
                    **context,
                }
            ),
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

    @unittest.skipUnless(shutil.which("wt"), "Worktrunk is not installed")
    def test_real_worktrunk_creation_runs_configured_hook(self) -> None:
        config = Path(self.temp.name) / "wt.toml"
        config.write_text(
            (SCRIPT.parent / "config.toml")
            .read_text()
            .replace("$HOME/.config/worktrunk", str(SCRIPT.parent.resolve()))
        )
        result = subprocess.run(
            [
                "wt",
                "--config",
                str(config),
                "-C",
                str(self.repo),
                "switch",
                "--create",
                "hook-created",
                "--base",
                "main",
                "--no-cd",
                "--format=json",
            ],
            env=dict(self.env, HERDR_ENV="0"),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.checkout = Path(json.loads(result.stdout)["path"])
        receipt = json.loads(self.receipt_path().read_text())
        self.assertEqual(receipt["branch"], "hook-created")
        self.assertEqual(receipt["checkout_path"], str(self.checkout))
        self.assertEqual(receipt["session_id"], "creator")

    def test_receipt_survives_session_change_without_reassignment(self) -> None:
        result = self.record()
        self.assertEqual(result.returncode, 0, result.stderr)
        receipt = json.loads(self.receipt_path().read_text())
        self.assertEqual(receipt["checkout_path"], str(self.checkout))
        self.assertEqual(receipt["branch"], "feature")
        self.assertEqual(receipt["creation_commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(receipt["session_id"], "creator")
        self.assertEqual(receipt["loop_id"], "loop")
        self.assertEqual(receipt["session_file"], "/sessions/creator.jsonl")
        self.env["PI_SESSION_ID"] = "successor"
        self.assertEqual(self.record().returncode, 1)
        self.assertEqual(json.loads(self.receipt_path().read_text()), receipt)

    def test_does_not_mark_human_worktrees(self) -> None:
        self.env.pop("PI_SESSION_ID")
        self.assertEqual(self.record().returncode, 0)
        self.assertFalse(self.receipt_path().exists())

    def test_rejects_primary_checkout_and_mismatched_hook_context(self) -> None:
        for context in (
            {"worktree_path": str(self.repo), "branch": "main"},
            {"branch": "wrong"},
            {"hook_type": "post-switch"},
        ):
            with self.subTest(context=context):
                self.assertEqual(self.record(**context).returncode, 1)
        self.assertFalse(self.receipt_path().exists())
        self.assertFalse((self.repo / ".git" / "agent-creation.json").exists())

    def test_recreated_checkout_does_not_inherit_receipt(self) -> None:
        self.assertEqual(self.record().returncode, 0)
        original_receipt = self.receipt_path()
        self.git("worktree", "remove", str(self.checkout))
        self.assertFalse(original_receipt.exists())
        self.git("worktree", "add", str(self.checkout), "feature")
        self.assertFalse(self.receipt_path().exists())
        self.env["PI_SESSION_ID"] = "new-creator"
        self.assertEqual(self.record().returncode, 0)
        self.assertEqual(
            json.loads(self.receipt_path().read_text())["session_id"], "new-creator"
        )


if __name__ == "__main__":
    unittest.main()

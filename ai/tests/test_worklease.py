from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


WORKLEASE = [
    "mise",
    "exec",
    "github:brettinternet/worklease@v0.2.0",
    "--",
    "worklease",
]


class WorkleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.environment = {**os.environ, "WORKLEASE_HOME": str(self.home / "state")}

    def run_worklease(
        self,
        *arguments: str,
        expected_code: int = 0,
        cwd: Path | None = None,
    ) -> dict[str, object]:
        completed = subprocess.run(
            [*WORKLEASE, "--json", "--home", str(self.home / "state"), *arguments],
            text=True,
            capture_output=True,
            cwd=cwd,
            env=self.environment,
            check=False,
        )
        self.assertEqual(
            expected_code, completed.returncode, completed.stderr or completed.stdout
        )
        return json.loads(completed.stdout)

    def acquire(
        self,
        resource: str,
        claim_id: str,
        *,
        coordination_only: bool = False,
    ) -> dict[str, object]:
        arguments = [
            "acquire",
            "--resource",
            resource,
            "--claim-id",
            claim_id,
            "--agent-id",
            f"agent-{claim_id}",
            "--session-id",
            f"session-{claim_id}",
            "--owner-id",
            f"owner-{claim_id}",
            "--work-key",
            f"implement:{resource}",
            "--ttl",
            "10",
        ]
        if coordination_only:
            arguments.append("--coordination-only")
        return self.run_worklease(*arguments)

    @staticmethod
    def claim_arguments(
        resource: str,
        payload: dict[str, object],
        operation_id: str,
        token: str,
    ) -> list[str]:
        claim = payload["claim"]
        assert isinstance(claim, dict)
        return [
            "--resource",
            resource,
            "--claim-id",
            str(claim["claimId"]),
            "--token",
            token,
            "--revision",
            str(claim["revision"]),
            "--operation-id",
            operation_id,
        ]

    def test_pinned_release_supports_documented_cli(self) -> None:
        completed = subprocess.run(
            [*WORKLEASE, "--version"],
            text=True,
            capture_output=True,
            env=self.environment,
            check=False,
        )
        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertEqual("0.2.0", completed.stdout.strip())

    def test_lifecycle_exec_checkpoint_and_release(self) -> None:
        resource = "local:worklease-smoke"
        acquired = self.acquire(resource, "lifecycle")
        token = str(acquired["claim"]["token"])
        output = self.home / "exec-output.txt"
        executed = self.run_worklease(
            "exec",
            *self.claim_arguments(resource, acquired, "exec-1", token),
            "--",
            sys.executable,
            "-c",
            f"from pathlib import Path; Path({str(output)!r}).write_text('ok')",
        )
        self.assertTrue(executed["ok"])
        self.assertEqual("ok", output.read_text())

        checkpointed = self.run_worklease(
            "checkpoint",
            *self.claim_arguments(resource, executed, "checkpoint-1", token),
            "--checkpoint",
            '{"phase":"tests","result":"passed"}',
        )
        self.assertEqual("passed", checkpointed["checkpoint"]["result"])

        released = self.run_worklease(
            "release",
            *self.claim_arguments(resource, checkpointed, "release-1", token),
            "--reason",
            "smoke checkpoint verified",
        )
        self.assertTrue(released["ok"])
        self.assertEqual("free", self.run_worklease("status", "--resource", resource)["state"])

    def test_expected_hash_replacement_is_guarded(self) -> None:
        target = self.home / "backlog.md"
        candidate = self.home / "candidate.md"
        target.write_text("old\n")
        candidate.write_text("new\n")
        key = self.run_worklease(
            "key",
            "--provider",
            "markdown",
            "--source",
            str(target),
            "--item",
            "ITEM-1",
        )
        self.assertEqual("markdown", key["provider"])
        self.assertEqual("source", key["scope"])
        self.assertEqual("source-claim", key["capability"])
        resource = str(key["resource"])
        acquired = self.acquire(resource, "replace")
        token = str(acquired["claim"]["token"])
        replaced = self.run_worklease(
            "replace-file",
            *self.claim_arguments(resource, acquired, "replace-1", token),
            "--path",
            str(target),
            "--expected-sha256",
            hashlib.sha256(target.read_bytes()).hexdigest(),
            "--content-file",
            str(candidate),
        )
        self.assertTrue(replaced["ok"])
        self.assertEqual("new\n", target.read_text())
        conflict = self.run_worklease(
            "replace-file",
            *self.claim_arguments(resource, replaced, "replace-conflict", token),
            "--path",
            str(target),
            "--expected-sha256",
            hashlib.sha256(b"old\n").hexdigest(),
            "--content-file",
            str(candidate),
            expected_code=3,
        )
        self.assertEqual("file-version-conflict", conflict["error"])
        self.assertEqual("new\n", target.read_text())
        current = self.run_worklease("status", "--resource", resource)
        self.run_worklease(
            "release",
            *self.claim_arguments(resource, current, "replace-release", token),
            "--reason",
            "replacement verified",
        )

    def test_git_primary_runs_from_registered_primary_checkout(self) -> None:
        repository = self.home / "repository"
        checkout = self.home / "checkout"
        subprocess.run(["git", "init", str(repository)], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.name", "Test"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.email", "test@example.com"],
            check=True,
        )
        (repository / "tracked.txt").write_text("tracked\n")
        subprocess.run(["git", "-C", str(repository), "add", "tracked.txt"], check=True)
        subprocess.run(
            ["git", "-C", str(repository), "commit", "-m", "init"],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            [
                "git",
                "-C",
                str(repository),
                "worktree",
                "add",
                "-b",
                "other",
                str(checkout),
            ],
            check=True,
            capture_output=True,
        )
        common_dir = subprocess.run(
            ["git", "-C", str(repository), "rev-parse", "--git-common-dir"],
            text=True,
            capture_output=True,
            check=True,
        ).stdout.strip()
        common_path = (repository / common_dir).resolve()
        resource = f"local:provider-transaction:{common_path}"
        acquired = self.acquire(resource, "git-primary", coordination_only=True)
        self.assertEqual("local-coordination", acquired["claim"]["guarantee"])
        token = str(acquired["claim"]["token"])
        claim_id = str(acquired["claim"]["claimId"])

        def release_transaction() -> None:
            status = self.run_worklease("status", "--resource", resource)
            claim = status.get("claim")
            if status.get("state") != "active" or not isinstance(claim, dict):
                return
            if str(claim.get("claimId")) != claim_id:
                return
            self.run_worklease(
                "release",
                *self.claim_arguments(resource, status, "git-primary-cleanup", token),
                "--reason",
                "test cleanup",
                cwd=checkout,
            )

        self.addCleanup(release_transaction)
        receipt = self.run_worklease(
            "exec",
            *self.claim_arguments(resource, acquired, "git-primary-1", token),
            "--git-primary",
            "--",
            "git",
            "rev-parse",
            "--show-toplevel",
            cwd=checkout,
        )
        self.assertEqual(str(repository.resolve()), receipt["command"]["stdout"].strip())
        self.assertEqual("git-primary", receipt["command"]["executionDirectory"]["mode"])
        self.run_worklease(
            "release",
            *self.claim_arguments(resource, receipt, "git-primary-release", token),
            "--reason",
            "primary checkout verified",
            cwd=checkout,
        )


if __name__ == "__main__":
    unittest.main()

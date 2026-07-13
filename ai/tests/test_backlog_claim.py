from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest


HELPER = Path(__file__).parents[1] / ".bin" / "backlog-claim"


class BacklogClaimTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.environment = {
            **os.environ,
            "BACKLOG_CLAIM_HOME": str(self.home / "claims"),
        }

    def fake_provider_cli(self, name: str, body: str) -> Path:
        directory = self.home / "bin"
        directory.mkdir(exist_ok=True)
        executable = directory / name
        executable.write_text(f"#!/usr/bin/env python3\n{body}\n")
        executable.chmod(0o700)
        return executable

    def run_claim(self, *arguments: str, expected_code: int = 0) -> dict[str, object]:
        completed = subprocess.run(
            [str(HELPER), *arguments],
            text=True,
            capture_output=True,
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
        ttl: float = 10,
        coordination_only: bool = False,
        expected_code: int = 0,
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
            "implement:item:next",
            "--ttl",
            str(ttl),
        ]
        if coordination_only:
            arguments.append("--coordination-only")
        return self.run_claim(*arguments, expected_code=expected_code)

    @staticmethod
    def claim_arguments(
        resource: str, payload: dict[str, object], operation_id: str
    ) -> list[str]:
        claim = payload["claim"]
        assert isinstance(claim, dict)
        return [
            "--resource",
            resource,
            "--claim-id",
            str(claim["claimId"]),
            "--token",
            str(claim["token"]),
            "--revision",
            str(claim["revision"]),
            "--operation-id",
            operation_id,
        ]

    def test_concurrent_acquire_has_exactly_one_winner(self) -> None:
        barrier = threading.Barrier(2)

        def contender(claim_id: str) -> tuple[int, dict[str, object]]:
            barrier.wait()
            completed = subprocess.run(
                [
                    str(HELPER),
                    "acquire",
                    "--resource",
                    "github:example/repo#1",
                    "--claim-id",
                    claim_id,
                    "--agent-id",
                    claim_id,
                    "--session-id",
                    claim_id,
                    "--owner-id",
                    claim_id,
                    "--work-key",
                    "implement:1:next",
                ],
                text=True,
                capture_output=True,
                env=self.environment,
                check=False,
            )
            return completed.returncode, json.loads(completed.stdout)

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(contender, ("claim-a", "claim-b")))

        self.assertEqual([0, 2], sorted(code for code, _ in results))
        winner = next(payload for code, payload in results if code == 0)
        loser = next(payload for code, payload in results if code == 2)
        self.assertTrue(winner["ok"])
        self.assertIn(loser["error"], ("already-claimed", "resource-guarded"))

    def test_active_claim_rejects_another_owner(self) -> None:
        first = self.acquire("github:example/repo#2", "first")
        second = self.acquire("github:example/repo#2", "second", expected_code=2)
        self.assertEqual("already-claimed", second["error"])
        self.assertEqual(first["claim"]["claimId"], second["claim"]["claimId"])

    def test_list_returns_all_claims_in_order_and_filters_by_resource(self) -> None:
        expired_resource = "github:example/repo#expired"
        active_resource = "github:example/repo#active"
        self.acquire(expired_resource, "expired", ttl=0.1)
        time.sleep(0.2)
        self.acquire(active_resource, "active")

        all_claims = self.run_claim("list")
        claims = all_claims["claims"]
        assert isinstance(claims, list)
        self.assertEqual("list", all_claims["operation"])
        self.assertEqual(
            [active_resource, expired_resource],
            [claim["resource"] for claim in claims],
        )
        self.assertTrue(claims[0]["active"])
        self.assertFalse(claims[1]["active"])

        filtered = self.run_claim("list", "--resource", expired_resource)
        filtered_claims = filtered["claims"]
        assert isinstance(filtered_claims, list)
        self.assertEqual(
            [expired_resource], [claim["resource"] for claim in filtered_claims]
        )

        missing = self.run_claim("list", "--resource", "github:example/repo#missing")
        self.assertEqual([], missing["claims"])


    def test_lease_duration_has_a_hard_upper_bound(self) -> None:
        oversized = self.acquire(
            "github:example/repo#ttl",
            "oversized",
            ttl=3601,
            expected_code=64,
        )
        absurd = self.acquire(
            "github:example/repo#huge-ttl",
            "absurd",
            ttl=1_000_000_000_000,
            expected_code=64,
        )
        self.assertEqual("invalid-ttl", oversized["error"])
        self.assertEqual(3600, oversized["maximumInclusive"])
        self.assertEqual("invalid-ttl", absurd["error"])

    def test_expired_claim_is_reclaimed_with_new_token_and_revision(self) -> None:
        first = self.acquire("markdown:/repo:backlog.md:ITEM-1", "first", ttl=0.1)
        time.sleep(0.2)
        second = self.acquire("markdown:/repo:backlog.md:ITEM-1", "second")
        self.assertTrue(second["reclaimed"])
        self.assertNotEqual(first["claim"]["token"], second["claim"]["token"])
        self.assertGreater(second["claim"]["revision"], first["claim"]["revision"])

    def test_stale_owner_cannot_heartbeat_release_write_or_execute_after_reclaim(
        self,
    ) -> None:
        target = self.home / "backlog.md"
        candidate = self.home / "candidate.md"
        target.write_text("old\n")
        candidate.write_text("new\n")
        key = self.run_claim(
            "key",
            "--provider",
            "markdown",
            "--source",
            str(target),
            "--item",
            "ITEM-2",
        )
        resource = str(key["resource"])
        first = self.acquire(resource, "first", ttl=0.1)
        expected_hash = hashlib.sha256(target.read_bytes()).hexdigest()
        time.sleep(0.2)
        second = self.acquire(resource, "second")

        heartbeat = self.run_claim(
            "heartbeat",
            *self.claim_arguments(resource, first, "heartbeat-old"),
            expected_code=2,
        )
        release = self.run_claim(
            "release",
            *self.claim_arguments(resource, first, "release-old"),
            "--reason",
            "stale handoff",
            expected_code=2,
        )
        write = self.run_claim(
            "replace-file",
            *self.claim_arguments(resource, first, "write-old"),
            "--path",
            str(target),
            "--expected-sha256",
            expected_hash,
            "--content-file",
            str(candidate),
            expected_code=2,
        )
        stale_output = self.home / "stale-execution.txt"
        execution = self.run_claim(
            "exec",
            *self.claim_arguments(resource, first, "execute-old"),
            "--",
            sys.executable,
            "-c",
            f"from pathlib import Path; Path({str(stale_output)!r}).write_text('stale')",
            expected_code=2,
        )

        self.assertEqual("stale-claim", heartbeat["error"])
        self.assertEqual("stale-claim", release["error"])
        self.assertEqual("stale-claim", write["error"])
        self.assertEqual("stale-claim", execution["error"])
        self.assertFalse(stale_output.exists())
        self.assertEqual("old\n", target.read_text())

        current_write = self.run_claim(
            "replace-file",
            *self.claim_arguments(resource, second, "write-current"),
            "--path",
            str(target),
            "--expected-sha256",
            expected_hash,
            "--content-file",
            str(candidate),
        )
        self.assertTrue(current_write["ok"])
        self.assertEqual("new\n", target.read_text())
        different_candidate = self.home / "different-candidate.md"
        different_candidate.write_text("different\n")
        changed_write = self.run_claim(
            "replace-file",
            *self.claim_arguments(resource, second, "write-current"),
            "--path",
            str(target),
            "--expected-sha256",
            expected_hash,
            "--content-file",
            str(different_candidate),
            expected_code=3,
        )
        unsupported_exec = self.run_claim(
            "exec",
            *self.claim_arguments(resource, current_write, "markdown-exec"),
            "--",
            sys.executable,
            "-c",
            "raise SystemExit('must not run')",
            expected_code=2,
        )
        other_target = self.home / "other-backlog.md"
        other_target.write_text("other\n")
        mismatched_target = self.run_claim(
            "replace-file",
            *self.claim_arguments(resource, current_write, "wrong-target"),
            "--path",
            str(other_target),
            "--expected-sha256",
            hashlib.sha256(other_target.read_bytes()).hexdigest(),
            "--content-file",
            str(different_candidate),
            expected_code=2,
        )
        self.assertEqual("operation-id-request-mismatch", changed_write["error"])
        self.assertEqual("unsupported-provider-exec", unsupported_exec["error"])
        self.assertEqual("resource-target-mismatch", mismatched_target["error"])
        self.assertEqual("other\n", other_target.read_text())
        self.assertEqual("new\n", target.read_text())

    def test_acquire_heartbeat_and_release_retries_are_idempotent(self) -> None:
        resource = "backlog-md:/repo:BACK-1"
        first = self.acquire(resource, "claim")
        changed_acquire = self.acquire(resource, "claim", ttl=11, expected_code=3)
        self.assertEqual("claim-id-request-mismatch", changed_acquire["error"])
        retry = self.acquire(resource, "claim")
        self.assertTrue(retry["idempotent"])
        self.assertEqual(first["claim"]["token"], retry["claim"]["token"])
        self.assertEqual(first["claim"]["revision"], retry["claim"]["revision"])

        heartbeat_arguments = self.claim_arguments(resource, first, "heartbeat-1")
        heartbeat = self.run_claim("heartbeat", *heartbeat_arguments)
        changed_heartbeat_arguments = [*heartbeat_arguments, "--ttl", "10"]
        changed_heartbeat = self.run_claim(
            "heartbeat", *changed_heartbeat_arguments, expected_code=3
        )
        self.assertEqual("operation-id-request-mismatch", changed_heartbeat["error"])
        wrong_heartbeat_token = heartbeat_arguments.copy()
        wrong_heartbeat_token[wrong_heartbeat_token.index("--token") + 1] = "wrong"
        wrong_heartbeat_revision = heartbeat_arguments.copy()
        wrong_heartbeat_revision[wrong_heartbeat_revision.index("--revision") + 1] = (
            str(heartbeat["claim"]["revision"])
        )
        rejected_token = self.run_claim(
            "heartbeat", *wrong_heartbeat_token, expected_code=2
        )
        rejected_revision = self.run_claim(
            "heartbeat", *wrong_heartbeat_revision, expected_code=2
        )
        self.assertEqual("stale-claim", rejected_token["error"])
        self.assertEqual("stale-revision", rejected_revision["error"])
        heartbeat_retry = self.run_claim("heartbeat", *heartbeat_arguments)
        self.assertTrue(heartbeat_retry["idempotent"])
        self.assertEqual(
            heartbeat["claim"]["revision"], heartbeat_retry["claim"]["revision"]
        )
        renewed_acquire_retry = self.acquire(resource, "claim")
        self.assertTrue(renewed_acquire_retry["idempotent"])
        self.assertEqual(
            heartbeat["claim"]["revision"],
            renewed_acquire_retry["claim"]["revision"],
        )

        release_arguments = self.claim_arguments(resource, heartbeat, "release-1")
        release_arguments.extend(("--reason", "checkpoint complete"))
        release = self.run_claim("release", *release_arguments)
        changed_release_reason = release_arguments.copy()
        changed_release_reason[-1] = "different checkpoint"
        rejected_release_reason = self.run_claim(
            "release", *changed_release_reason, expected_code=3
        )
        self.assertEqual(
            "operation-id-request-mismatch", rejected_release_reason["error"]
        )
        wrong_release_token = release_arguments.copy()
        wrong_release_token[wrong_release_token.index("--token") + 1] = "wrong"
        wrong_release_revision = release_arguments.copy()
        wrong_release_revision[wrong_release_revision.index("--revision") + 1] = str(
            int(heartbeat["claim"]["revision"]) + 1
        )
        rejected_release_token = self.run_claim(
            "release", *wrong_release_token, expected_code=2
        )
        rejected_release_revision = self.run_claim(
            "release", *wrong_release_revision, expected_code=2
        )
        self.assertEqual("stale-claim", rejected_release_token["error"])
        self.assertEqual("stale-revision", rejected_release_revision["error"])
        release_retry = self.run_claim("release", *release_arguments)
        self.assertFalse(release["idempotent"])
        self.assertTrue(release_retry["idempotent"])
        reused = self.acquire(resource, "claim", expected_code=2)
        self.assertEqual("claim-id-reused", reused["error"])
        next_claim = self.acquire(resource, "next")
        self.assertGreater(
            next_claim["claim"]["revision"], heartbeat["claim"]["revision"]
        )

    def test_separate_items_can_be_claimed_concurrently(self) -> None:
        barrier = threading.Barrier(2)

        def acquire_item(item: str) -> dict[str, object]:
            barrier.wait()
            return self.acquire(f"github:example/repo#{item}", f"claim-{item}")

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(acquire_item, ("10", "11")))

        self.assertTrue(all(result["ok"] for result in results))

    def test_guarded_command_retry_does_not_execute_twice(self) -> None:
        resource = "github:example/repo#12"
        claim = self.acquire(resource, "claim")
        output = self.home / "executions.txt"
        other_output = self.home / "other-executions.txt"
        gh = self.fake_provider_cli(
            "gh",
            "import sys\n"
            "from pathlib import Path\n"
            "Path(sys.argv[1]).open('a').write('once\\n')",
        )
        claim_arguments = self.claim_arguments(resource, claim, "provider-write-1")
        rejected_command = self.run_claim(
            "exec",
            *claim_arguments,
            "--",
            sys.executable,
            "-c",
            "raise SystemExit('must not run')",
            expected_code=64,
        )
        arguments = ["exec", *claim_arguments, "--", str(gh), str(output)]
        first = self.run_claim(*arguments)
        changed_request = self.run_claim(
            "exec",
            *claim_arguments,
            "--",
            str(gh),
            str(other_output),
            expected_code=3,
        )
        retry = self.run_claim(*arguments)
        self.assertEqual("provider-command-mismatch", rejected_command["error"])
        self.assertEqual("operation-id-request-mismatch", changed_request["error"])
        self.assertFalse(first["idempotent"])
        self.assertTrue(retry["idempotent"])
        self.assertEqual("once\n", output.read_text())
        self.assertFalse(other_output.exists())

    def test_expired_claim_cannot_release_without_reclaim(self) -> None:
        resource = "github:example/repo#13"
        claim = self.acquire(resource, "claim", ttl=0.1)
        time.sleep(0.2)
        released = self.run_claim(
            "release",
            *self.claim_arguments(resource, claim, "release-expired"),
            "--reason",
            "expired handoff",
            expected_code=2,
        )
        self.assertEqual("claim-expired", released["error"])

    def test_provider_mutation_paths_and_release_reason_are_validated(self) -> None:
        resource = "github:example/repo#provider-gates"
        claim = self.acquire(resource, "claim")
        target = self.home / "provider-target.md"
        candidate = self.home / "provider-candidate.md"
        target.write_text("old\n")
        candidate.write_text("new\n")
        rejected_release = self.run_claim(
            "release",
            *self.claim_arguments(resource, claim, "blank-release"),
            "--reason",
            " ",
            expected_code=64,
        )
        rejected_replace = self.run_claim(
            "replace-file",
            *self.claim_arguments(resource, claim, "wrong-provider-replace"),
            "--path",
            str(target),
            "--expected-sha256",
            hashlib.sha256(target.read_bytes()).hexdigest(),
            "--content-file",
            str(candidate),
            expected_code=2,
        )
        self.assertEqual("invalid-release-reason", rejected_release["error"])
        self.assertEqual("unsupported-provider-replace-file", rejected_replace["error"])
        self.assertEqual("old\n", target.read_text())

    def test_unfenced_remote_provider_defaults_to_local_coordination(self) -> None:
        linear = self.run_claim(
            "key",
            "--provider",
            "linear",
            "--source",
            "workspace-uuid",
            "--item",
            "issue-uuid",
        )
        repeated = self.run_claim(
            "key",
            "--provider",
            "linear",
            "--source",
            "workspace-uuid",
            "--item",
            "issue-uuid",
        )
        other_item = self.run_claim(
            "key",
            "--provider",
            "linear",
            "--source",
            "workspace-uuid",
            "--item",
            "other-issue-uuid",
        )
        future = self.run_claim(
            "key",
            "--provider",
            "future-provider",
            "--source",
            "account-uuid",
            "--item",
            "work-uuid",
        )
        self.assertEqual("local-coordination", linear["capability"])
        self.assertFalse(linear["fencedMutations"])
        self.assertEqual(linear["resource"], repeated["resource"])
        self.assertNotEqual(linear["resource"], other_item["resource"])
        self.assertEqual("local-coordination", future["capability"])

    def test_fenced_provider_can_explicitly_downgrade_to_local_coordination(
        self,
    ) -> None:
        fenced = self.run_claim(
            "key",
            "--provider",
            "github",
            "--source",
            "github.com/example/repo",
            "--item",
            "115",
        )
        coordination = self.run_claim(
            "key",
            "--provider",
            "github",
            "--source",
            "github.com/example/repo",
            "--item",
            "115",
            "--coordination-only",
        )
        self.assertEqual("item-claim", fenced["capability"])
        self.assertTrue(fenced["fencedMutations"])
        self.assertEqual("local-coordination", coordination["capability"])
        self.assertFalse(coordination["fencedMutations"])
        self.assertEqual(fenced["resource"], coordination["resource"])
        resource = str(coordination["resource"])
        claim = self.acquire(
            resource,
            "downgraded-github",
            coordination_only=True,
        )
        reclassified = self.acquire(
            resource,
            "downgraded-github",
            expected_code=2,
        )
        output = self.home / "downgraded-github.txt"
        gh = self.fake_provider_cli(
            "gh",
            "import sys\n"
            "from pathlib import Path\n"
            "Path(sys.argv[1]).write_text('ran')",
        )
        rejected = self.run_claim(
            "exec",
            *self.claim_arguments(resource, claim, "downgraded-github-write"),
            "--",
            str(gh),
            str(output),
            expected_code=2,
        )
        self.assertEqual("claim-id-identity-mismatch", reclassified["error"])
        self.assertEqual("local-coordination", claim["claim"]["guarantee"])
        self.assertEqual("unsupported-coordination-exec", rejected["error"])
        self.assertFalse(output.exists())

    def test_coordination_only_markdown_rejects_fenced_replacement(self) -> None:
        target = self.home / "coordination-backlog.md"
        candidate = self.home / "coordination-candidate.md"
        target.write_text("old\n")
        candidate.write_text("new\n")
        key = self.run_claim(
            "key",
            "--provider",
            "markdown",
            "--source",
            str(target),
            "--item",
            "ITEM-1",
            "--coordination-only",
        )
        resource = str(key["resource"])
        claim = self.acquire(
            resource,
            "coordination-markdown",
            coordination_only=True,
        )
        rejected = self.run_claim(
            "replace-file",
            *self.claim_arguments(
                resource,
                claim,
                "coordination-markdown-write",
            ),
            "--path",
            str(target),
            "--expected-sha256",
            hashlib.sha256(target.read_bytes()).hexdigest(),
            "--content-file",
            str(candidate),
            expected_code=2,
        )
        self.assertEqual(
            "unsupported-coordination-replace-file",
            rejected["error"],
        )
        self.assertEqual("old\n", target.read_text())

    def test_coordination_resources_reject_guarded_provider_execution(self) -> None:
        key = self.run_claim(
            "key",
            "--provider",
            "linear",
            "--source",
            "workspace-uuid",
            "--item",
            "issue-uuid",
        )
        resource = str(key["resource"])
        claim = self.acquire(
            resource,
            "linear-coordination",
            coordination_only=True,
        )
        contender = self.acquire(
            resource,
            "other-linear-worker",
            coordination_only=True,
            expected_code=2,
        )
        output = self.home / "must-not-execute.txt"
        rejected = self.run_claim(
            "exec",
            *self.claim_arguments(resource, claim, "linear-write"),
            "--",
            sys.executable,
            "-c",
            f"from pathlib import Path; Path({str(output)!r}).write_text('ran')",
            expected_code=2,
        )
        manual_resource = "linear:workspace-uuid:issue-uuid"
        manual_claim = self.acquire(manual_resource, "manual-linear")
        manual_rejected = self.run_claim(
            "exec",
            *self.claim_arguments(
                manual_resource,
                manual_claim,
                "manual-linear-write",
            ),
            "--",
            sys.executable,
            "-c",
            "raise SystemExit('must not execute')",
            expected_code=2,
        )
        self.assertEqual("already-claimed", contender["error"])
        self.assertEqual("unsupported-coordination-exec", rejected["error"])
        self.assertEqual("unsupported-coordination-exec", manual_rejected["error"])
        self.assertFalse(output.exists())

    def test_coordination_key_requires_canonical_identity(self) -> None:
        invalid_provider = self.run_claim(
            "key",
            "--provider",
            "linear/mcp",
            "--source",
            "workspace-uuid",
            "--item",
            "issue-uuid",
            expected_code=64,
        )
        missing_item = self.run_claim(
            "key",
            "--provider",
            "linear",
            "--source",
            "workspace-uuid",
            "--item",
            " ",
            expected_code=64,
        )
        self.assertEqual("invalid-provider", invalid_provider["error"])
        self.assertEqual("invalid-resource-identity", missing_item["error"])

    def test_markdown_items_share_one_source_claim_key(self) -> None:
        source = self.home / "backlog.md"
        source.write_text("# Backlog\n")
        first = self.run_claim(
            "key",
            "--provider",
            "markdown",
            "--source",
            str(source),
            "--item",
            "ITEM-1",
        )
        second = self.run_claim(
            "key",
            "--provider",
            "markdown",
            "--source",
            str(source),
            "--item",
            "ITEM-2",
        )
        self.assertEqual("source-claim", first["capability"])
        self.assertEqual(first["resource"], second["resource"])

    def test_guard_renews_lease_and_blocks_expiry_takeover(self) -> None:
        resource = "github:example/repo#14"
        claim = self.acquire(resource, "first", ttl=0.15)
        gh = self.fake_provider_cli(
            "gh", "import sys\nimport time\ntime.sleep(float(sys.argv[1]))"
        )
        process = subprocess.Popen(
            [
                str(HELPER),
                "exec",
                *self.claim_arguments(resource, claim, "long-provider-write"),
                "--ttl",
                "0.15",
                "--",
                str(gh),
                "0.5",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=self.environment,
        )
        time.sleep(0.3)
        current = self.run_claim("status", "--resource", resource)
        contender = self.acquire(resource, "second", expected_code=2)
        stdout, stderr = process.communicate(timeout=2)
        self.assertEqual(0, process.returncode, stderr or stdout)
        self.assertEqual("active", current["state"])
        self.assertEqual("resource-guarded", contender["error"])

    def test_local_source_key_is_shared_across_git_worktrees(self) -> None:
        repository = self.home / "repository"
        checkout = self.home / "checkout"
        repository.mkdir()
        subprocess.run(
            ["git", "init", str(repository)], check=True, capture_output=True
        )
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.name", "Test"], check=True
        )
        subprocess.run(
            ["git", "-C", str(repository), "config", "user.email", "test@example.com"],
            check=True,
        )
        (repository / "backlog.md").write_text("# Backlog\n")
        subprocess.run(["git", "-C", str(repository), "add", "backlog.md"], check=True)
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
        first = self.run_claim(
            "key",
            "--provider",
            "backlog-md",
            "--source",
            str(repository / "backlog.md"),
            "--item",
            "BACK-1",
        )
        second = self.run_claim(
            "key",
            "--provider",
            "backlog-md",
            "--source",
            str(checkout / "backlog.md"),
            "--item",
            "BACK-1",
        )
        self.assertEqual(first["resource"], second["resource"])


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "ai/.bin/agent"

# A process-boundary stand-in: record actual argv/env and answer Herdr's JSON API.
CHILD = '''import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if pathlib.Path(sys.argv[0]).name != "herdr":
    print(json.dumps({"args": args, "cwd": os.getcwd(),
                      "name": os.environ.get("AGENT_NAME"),
                      "value": os.environ.get("EXTRA")}))
    sys.exit(int(os.environ.get("CHILD_EXIT", "0")))
if args[:1] == ["--session"]:
    args = args[2:]
state = json.loads(pathlib.Path(os.environ["STATE"]).read_text())
command = " ".join(args[:2])
if command == state.get("fail"):
    print("sensitive diagnostic: " + os.environ.get("EXTRA", ""), file=sys.stderr)
    sys.exit(1)
if command == "agent list":
    result = {"agents": state.get("agents", [])}
elif command == "workspace list":
    result = {"workspaces": state.get("workspaces", [])}
elif command == "tab list":
    result = {"tabs": state.get("tabs", [])}
elif command == "pane list":
    result = {"panes": state["panes"][args[-1]]}
elif command in ("workspace create", "tab create", "pane split"):
    result = {"root_pane": {"pane_id": "w9:p1"},
              "pane": {"pane_id": "w9:p1"}, "tab": {"tab_id": "w9:t1"}}
elif command in ("tab rename", "pane rename", "pane close"):
    result = {}
elif command == "agent start":
    result = {"agent": {"pane_id": "w9:p1", "name": args[2]}}
else:
    raise AssertionError(args)
print(json.dumps({"result": result}))
'''


class AgentLauncherTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.calls = self.root / "calls.jsonl"
        self.state = self.root / "state.json"
        self.state.write_text("{}")
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith("HERDR_")}
        self.environment.update(PATH=f"{self.root}:{os.environ['PATH']}",
                                CALLS=str(self.calls), STATE=str(self.state))
        for name in ("herdr", "pi", "claude", "codex"):
            child = self.root / name
            child.write_text(f"#!{sys.executable}\n{CHILD}")
            child.chmod(0o755)

    def run_agent(self, *args: str, code: int = 0) -> subprocess.CompletedProcess[str]:
        result = subprocess.run([str(LAUNCHER), "--cwd", str(self.project), *args],
                                env=self.environment, capture_output=True, text=True)
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        return result

    def commands(self) -> list[list[str]]:
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_local_exec_preserves_argv_environment_and_exit_status(self) -> None:
        literal = "quotes ' \" $HOME $(touch should-not-exist)\nnext line"
        self.environment["EXTRA"] = literal
        self.environment["CHILD_EXIT"] = "7"
        for kind in ("pi", "claude", "codex"):
            with self.subTest(kind=kind):
                result = self.run_agent("--kind", kind, "Alice Smith", "--env", "EXTRA",
                                        "--", "--resume", literal, code=7)
                received = json.loads(result.stdout)
                prefix = [] if kind == "codex" else ["--name", "Alice Smith"]
                self.assertEqual(prefix + ["--resume", literal], received["args"])
                self.assertEqual(str(self.project), received["cwd"])
                self.assertEqual("Alice Smith", received["name"])
                self.assertEqual(literal, received["value"])
        self.assertFalse((self.project / "should-not-exist").exists())

    def test_workspace_selection_uses_checkout_and_pins_session(self) -> None:
        alias = self.root / "alias"
        alias.symlink_to(self.project, target_is_directory=True)
        self.state.write_text(json.dumps({
            "workspaces": [{"label": "maintenance", "workspace_id": "wrong"},
                           {"label": "maintenance", "workspace_id": "right"}],
            "panes": {"wrong": [{"cwd": str(self.root)}], "right": [{"cwd": str(alias)}]},
        }))
        self.environment.update(HERDR_ENV="1", HERDR_WORKSPACE_ID="unrelated",
                                EXTRA="secret ' with spaces")
        self.run_agent("reviewer", "--herdr-name", "review-123", "--herdr-session", "default",
                       "--workspace", "maintenance", "--tab", "PR review", "--env", "EXTRA")
        calls = self.commands()
        self.assertTrue(all(call[:2] == ["--session", "default"] for call in calls))
        create = next(call[2:] for call in calls if call[2:4] == ["tab", "create"])
        self.assertEqual(["tab", "create", "--workspace", "right", "--label", "PR review"], create[:6])
        self.assertIn("--no-focus", create)
        self.assertIn("EXTRA=secret ' with spaces", create)
        self.assertIn("AGENT_NAME=reviewer", create)
        self.assertEqual(["agent", "start", "review-123", "--kind", "pi", "--pane", "w9:p1",
                          "--", "--name", "reviewer"], calls[-1][2:])

    def test_new_workspace_and_caller_layout_never_reuse_occupied_panes(self) -> None:
        cases = [
            (["--herdr-session", "default", "--workspace", "maintenance", "--tab", "review"],
             ["agent list", "workspace list", "workspace create", "tab rename", "agent start"]),
            (["-s"], ["agent list", "pane split", "agent start"]),
            (["-t"], ["agent list", "tab create", "agent start"]),
        ]
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1", HERDR_WORKSPACE_ID="caller")
        for options, expected in cases:
            with self.subTest(options=options):
                self.calls.write_text("")
                self.run_agent("alice", *options, "--pane-title=--Dependency PRs",
                               "--startup-timeout", "60", "--", "--model", "example")
                calls = [call[2:] if call[0] == "--session" else call for call in self.commands()]
                self.assertEqual(expected[:-1] + ["pane rename", "agent start"],
                                 [" ".join(call[:2]) for call in calls])
                self.assertEqual(["pane", "rename", "w9:p1", "--Dependency PRs"], calls[-2])
                self.assertEqual(["--timeout", "60000", "--", "--name", "alice", "--model", "example"], calls[-1][-7:])
                if "-s" in options:
                    self.assertEqual(["--current", "--direction", "right"], calls[1][2:5])
                elif "--workspace" not in options:
                    self.assertEqual(["--workspace", "caller", "--label", "alice"], calls[1][2:6])
                else:
                    self.assertEqual(["tab", "rename", "w9:t1", "review"], calls[-3])

    def reuse_state(self) -> dict:
        self.environment.update(HERDR_ENV="1", HERDR_WORKSPACE_ID="w1")
        return {"agents": [{"name": "alice", "pane_id": "w1:p1"}],
                "tabs": [{"label": "review", "tab_id": "w1:t1"}],
                "panes": {"w1": [{"pane_id": "w1:p1", "tab_id": "w1:t1"}]}}

    def test_tab_reuse_preserves_agent_unless_replacement_requested(self) -> None:
        self.state.write_text(json.dumps(self.reuse_state()))
        for flag, name in (("--reuse-tab", "alice-2"), ("--reuse-pane", "alice")):
            with self.subTest(flag=flag):
                self.calls.write_text("")
                self.run_agent("alice", "-t", "review", flag)
                calls = self.commands()
                split = next(call for call in calls if call[:2] == ["pane", "split"])
                self.assertEqual("w1:p1", split[2])
                self.assertIn("--no-focus", split)
                self.assertIn("AGENT_NAME=alice", split)
                self.assertEqual(["agent", "start", name], calls[-1][:3])
                closes = [call for call in calls if call[:2] == ["pane", "close"]]
                self.assertEqual([["pane", "close", "w1:p1"]] if flag == "--reuse-pane" else [], closes)
                if closes:
                    self.assertLess(calls.index(split), calls.index(closes[0]))
                    self.assertEqual(closes[0], calls[-2])

    def test_replacement_refuses_ambiguous_or_unrelated_targets_and_failed_split(self) -> None:
        for problem in ("duplicate tab", "other tab", "missing tab", "split failure", "rename failure"):
            with self.subTest(problem=problem):
                self.calls.write_text("")
                state = self.reuse_state()
                if problem == "duplicate tab":
                    state["tabs"].append({"label": "review", "tab_id": "w1:t2"})
                elif problem == "other tab":
                    state["panes"]["w1"][0]["tab_id"] = "w1:t2"
                elif problem == "missing tab":
                    state["tabs"] = []
                else:
                    state["fail"] = "pane rename" if problem == "rename failure" else "pane split"
                self.state.write_text(json.dumps(state))
                self.run_agent("alice", "-t", "review", "--reuse-pane", "--pane-title", "Review", code=1)
                self.assertFalse(any(call[:2] in (["pane", "close"], ["agent", "start"],
                                                ["tab", "create"]) for call in self.commands()))

    def test_close_exact_live_name_and_dry_run(self) -> None:
        state = self.reuse_state()
        self.state.write_text(json.dumps(state))
        self.run_agent("alice", "--close", "--dry-run")
        self.assertEqual([], self.commands())
        self.run_agent("alice", "--close", "--herdr-session", "test")
        self.assertEqual([["--session", "test", "agent", "list"],
                          ["--session", "test", "pane", "close", "w1:p1"]], self.commands())
        for agents in ([], state["agents"] * 2):
            self.calls.write_text("")
            self.state.write_text(json.dumps({"agents": agents}))
            self.run_agent("alice", "--close", code=1)
            self.assertEqual([["agent", "list"]], self.commands())
        self.calls.write_text("")
        for options in (("--close", "-t"), ("--reuse-pane",), ("--reuse-tab", "-s")):
            self.run_agent("alice", *options, code=2)
        self.assertEqual([], self.commands())

    def test_derived_live_name_avoids_collisions(self) -> None:
        self.state.write_text(json.dumps({"agents": [{"name": "auth-review"}, {"name": "auth-review-2"}]}))
        self.run_agent("Auth Review!", "--herdr-session", "default", "--workspace", "work")
        start = self.commands()[-1][2:]
        self.assertEqual(["agent", "start", "auth-review-3"], start[:3])
        self.assertEqual(["--name", "Auth Review!"], start[-2:])

    def test_ambiguous_workspace_and_explicit_name_collision_fail_before_creation(self) -> None:
        ambiguous = {
            "workspaces": [{"label": "work", "workspace_id": name} for name in ("a", "b")],
            "panes": {name: [{"cwd": str(self.project)}] for name in ("a", "b")},
        }
        for state, message in ((ambiguous, "refusing to guess"),
                               ({"agents": [{"name": "alice"}]}, "already exists")):
            with self.subTest(state=state):
                self.calls.write_text("")
                self.state.write_text(json.dumps(state))
                result = self.run_agent("alice", "--herdr-name", "alice", "--herdr-session", "default",
                                        "--workspace", "work", code=1)
                self.assertIn(message, result.stderr)
                self.assertTrue(all(call[3] == "list" for call in self.commands()))

    def test_failed_launch_keeps_pane_without_retry_or_secret_disclosure(self) -> None:
        self.environment["EXTRA"] = "must-not-be-printed"
        for failure in ("agent start", "pane rename"):
            with self.subTest(failure=failure):
                self.calls.write_text("")
                self.state.write_text(json.dumps({"fail": failure}))
                result = self.run_agent("alice", "--herdr-session", "default", "--workspace", "work",
                                        "--pane-title", "Review", "--env", "EXTRA", code=1)
                self.assertIn("retained Herdr pane w9:p1", result.stderr)
                self.assertNotIn(self.environment["EXTRA"], result.stdout + result.stderr)
                calls = self.commands()
                self.assertEqual(1 if failure == "agent start" else 0,
                                 sum(call[2:4] == ["agent", "start"] for call in calls))
                self.assertFalse(any("close" in call for call in calls))

    def test_dry_run_never_executes_and_redacts_environment(self) -> None:
        self.environment["EXTRA"] = "exported-secret"
        native = ["--model", "example", "literal ' $HOME prompt"]
        for options in ([], ["--herdr-session", "default", "--workspace", "work",
                             "--pane-title", "Review", "--startup-timeout", "60"]):
            with self.subTest(options=options):
                result = self.run_agent("alice", *options, "--dry-run", "--env", "EXTRA",
                                        "--env", "TOKEN=inline-secret", "--", *native)
                plan = json.loads(result.stdout)
                self.assertTrue(plan["dry_run"])
                self.assertEqual(["pi", "--name", "alice", *native], plan["argv"])
                self.assertEqual(str(self.project), plan["cwd"])
                self.assertEqual({"AGENT_NAME": "<redacted>", "EXTRA": "<redacted>", "TOKEN": "<redacted>"}, plan["env"])
                for secret in ("exported-secret", "inline-secret"):
                    self.assertNotIn(secret, result.stdout + result.stderr)
                if options:
                    self.assertEqual("default", plan["herdr"]["session"])
                    self.assertEqual("work", plan["herdr"]["workspace_label"])
                    self.assertEqual("Review", plan["herdr"]["pane_title"])
                    self.assertEqual(60, plan["herdr"]["startup_timeout_seconds"])
                else:
                    self.assertIsNone(plan["herdr"])
        self.assertEqual([], self.commands())

    def test_invalid_routing_and_reserved_environment_fail_before_side_effects(self) -> None:
        for options in (["--workspace", "work"], ["--herdr-session", "default"],
                        ["--split", "down", "--workspace", "work"], ["--focus"],
                        ["--tab", " "], ["--pane-title", "Review"], ["--startup-timeout", "60"],
                        ["--herdr-session", "default", "--workspace", "work", "--pane-title", " "],
                        ["--herdr-session", "default", "--workspace", "work", "--startup-timeout", "0"],
                        ["--herdr-session", "default", "--workspace", "work", "--startup-timeout", "301"],
                        ["--herdr-session", "default", "--workspace", "work", "--startup-timeout", "slow"],
                        ["--herdr-name", "Bad", "--herdr-session", "default", "--workspace", "work"]):
            with self.subTest(options=options):
                self.run_agent("alice", *options, code=2)
        for variable in ("HERDR_PANE_ID=other", "AGENT_NAME=bob"):
            self.run_agent("alice", "--env", variable, code=1)
        self.assertEqual([], self.commands())


if __name__ == "__main__":
    unittest.main()

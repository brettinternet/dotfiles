from __future__ import annotations

import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "ai/.bin/agent"
PANE = ROOT / "base/.bin/pane"

# A process-boundary stand-in: record actual argv/env and answer Herdr's JSON API.
CHILD = '''import json, os, pathlib, subprocess, sys
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
    if state.get("error_code"):
        print(json.dumps({"error": {"code": state["error_code"]}}), file=sys.stderr)
    else:
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
    state["launch_cwd"] = args[args.index("--cwd") + 1]
    state["launch_env"] = dict(args[index + 1].split("=", 1) for index, word in enumerate(args) if word == "--env")
    pathlib.Path(os.environ["STATE"]).write_text(json.dumps(state))
    result = {"root_pane": {"pane_id": "w9:p1"},
              "pane": {"pane_id": "w9:p1"}, "tab": {"tab_id": "w9:t1"}}
elif command in ("tab rename", "pane rename", "pane close"):
    if command == "pane close" and state.get("agent_pid"):
        import signal
        os.kill(state["agent_pid"], signal.SIGTERM)
    result = {}
elif command == "pane run":
    run = subprocess.Popen if state.get("async_run") else subprocess.run
    run(["sh", "-c", args[3]], cwd=state["launch_cwd"],
                   env={**os.environ, **state["launch_env"], "HERDR_PANE_ID": "w9:p1"},
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   start_new_session=True)
    sys.exit(0)  # Herdr pane run returns no JSON; command exit is not submission exit.
elif command == "pane process-info":
    result = {"process_info": state["process_info"]}
elif command == "pane get":
    result = {"pane": {"pane_id": args[2]}}
elif command == "agent start":
    result = {"agent": {**state.get("started", {}), "pane_id": "w9:p1", "name": args[2]}}
elif command == "agent get":
    snapshot = state["snapshots"].pop(0)
    pathlib.Path(os.environ["STATE"]).write_text(json.dumps(state))
    if snapshot.get("exit_agent"):
        import signal
        os.kill(snapshot["exit_agent"], signal.SIGTERM)
        print(json.dumps({"error": {"code": "agent_not_found"}}), file=sys.stderr)
        sys.exit(1)
    result = {"agent": snapshot}
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
                                env=self.environment, capture_output=True, text=True, timeout=30)
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        return result

    def commands(self) -> list[list[str]]:
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def run_pane(self, *args: str, code: int = 0) -> subprocess.CompletedProcess[str]:
        result = subprocess.run([str(PANE), "--cwd", str(self.project), *args],
                                env=self.environment, capture_output=True, text=True, timeout=30)
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        return result

    def test_pane_runs_literal_argv_and_keeps_output_pane_unless_close_requested(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1", EXTRA="secret ' $HOME")
        output = self.root / "received.json"
        command = [sys.executable, "-c",
                   "import json, os, pathlib, sys; pathlib.Path(sys.argv[1]).write_text("
                   "json.dumps([sys.argv[2:], os.getcwd(), os.environ['EXTRA']])); sys.exit(7)",
                   str(output), "", "quotes ' \\\" $HOME $(touch unexpected) ; echo bad", "line\\nnext"]
        for close in (False, True):
            with self.subTest(close=close):
                self.calls.write_text("")
                result = self.run_pane(*(["--close-on-exit"] if close else []), "-e", "EXTRA", "--", *command)
                self.assertEqual({"pane_id": "w9:p1", "submitted": True}, json.loads(result.stdout)["result"])
                self.assertEqual([command[4:], str(self.project), self.environment["EXTRA"]], json.loads(output.read_text()))
                self.assertFalse((self.project / "unexpected").exists())
                calls = self.commands()
                self.assertEqual(["pane", "split", "--current", "--direction", "right"], calls[0][:5])
                self.assertEqual([["pane", "close", "w9:p1"]] if close else [],
                                 [call for call in calls if call[:2] == ["pane", "close"]])

    def test_pane_wait_returns_command_status_including_close_on_exit(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1")
        for close in (False, True):
            with self.subTest(close=close):
                self.calls.write_text("")
                result = self.run_pane("--wait", *(["--close-on-exit"] if close else []),
                                       "--", sys.executable, "-c", "raise SystemExit(7)", code=7)
                self.assertEqual({"pane_id": "w9:p1", "exit_code": 7},
                                 json.loads(result.stdout.splitlines()[-1])["result"])
                self.assertEqual(close, any(call[:2] == ["pane", "close"] for call in self.commands()))

    def test_pane_wait_blocks_after_submission_and_cancellation_retains_work(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1")
        for cancel in (False, True):
            with self.subTest(cancel=cancel):
                self.calls.write_text("")
                self.state.write_text(json.dumps({"async_run": True}))
                gate = self.root / f"release-{cancel}"
                finished = self.root / f"finished-{cancel}"
                command = ("import pathlib, sys, time; gate = pathlib.Path(sys.argv[1]); "
                           "deadline = time.monotonic() + 10\n"
                           "while not gate.exists() and time.monotonic() < deadline: time.sleep(0.02)\n"
                           "pathlib.Path(sys.argv[2]).write_text('finished'); sys.exit(7)")
                with subprocess.Popen([str(PANE), "--wait", "--", sys.executable, "-c", command,
                                       str(gate), str(finished)],
                                      env=self.environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      text=True) as process:
                    try:
                        self.assertTrue(json.loads(process.stdout.readline())["result"]["submitted"])
                        self.assertIsNone(process.poll())
                        if cancel:
                            process.terminate()
                            _, stderr = process.communicate(timeout=5)
                            self.assertEqual(143, process.returncode)
                            self.assertIn("retained Herdr pane", stderr)
                        else:
                            gate.write_text("go")
                            stdout, stderr = process.communicate(timeout=5)
                            self.assertEqual(7, process.returncode, stderr)
                            self.assertEqual(7, json.loads(stdout)["result"]["exit_code"])
                        self.assertFalse(any(call[:2] == ["pane", "close"] for call in self.commands()))
                    finally:
                        gate.write_text("go")
                        if process.poll() is None:
                            process.kill()
                            process.communicate(timeout=5)
                        deadline = time.monotonic() + 5
                        while not finished.exists() and time.monotonic() < deadline:
                            time.sleep(0.02)
                        self.assertTrue(finished.exists(), "Cancellation must not stop the command")

    def test_pane_wait_fails_if_bootstrap_dies_even_when_pane_survives(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1")
        # The command kills its bootstrap, but the pane's shell survives.
        self.state.write_text("{}")
        result = self.run_pane("--wait", "--", sys.executable, "-c",
                               "import os, signal; os.kill(os.getppid(), signal.SIGKILL)", code=1)
        self.assertIn("retained Herdr pane", result.stderr)
        self.assertIn("without reporting completion", result.stderr)

    def test_pane_reuses_workspace_and_tab_without_touching_agents(self) -> None:
        state = self.reuse_state()
        state["workspaces"] = [{"label": "work", "workspace_id": "w1"}]
        state["panes"]["w1"][0]["cwd"] = str(self.project)
        self.state.write_text(json.dumps(state))
        self.run_pane("-w", "work", "-t", "review", "--reuse-tab", "--", "echo", "test")
        calls = self.commands()
        self.assertTrue(any(call[:3] == ["pane", "split", "w1:p1"] for call in calls))
        self.assertFalse(any(call[0] == "agent" or "close" in call or "create" in call for call in calls))

    def test_pane_dry_run_routing_validation_and_failed_submission(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1")
        result = self.run_pane("--dry-run", "-e", "TOKEN=secret", "--", "echo", "test")
        self.assertNotIn("secret", result.stdout)
        self.assertEqual(["echo", "test"], json.loads(result.stdout)["argv"])
        for options in (("--",), ("--herdr-session", "other", "--", "echo"),
                        ("-s", "-w", "work", "--", "echo")):
            self.run_pane(*options, code=2)
        self.run_pane("-e", "HERDR_PANE_ID=wrong", "--", "echo", code=1)
        self.assertEqual([], self.commands())
        self.state.write_text(json.dumps({"fail": "pane run"}))
        result = self.run_pane("--", "echo", code=1)
        self.assertIn("retained Herdr pane w9:p1", result.stderr)
        self.assertFalse(any("close" in call for call in self.commands()))

    def test_agent_list_routes_session_and_never_mutates(self) -> None:
        agents = [{"name": "alice", "pane_id": "w1:p1"}]
        self.state.write_text(json.dumps({"agents": agents}))
        result = self.run_agent("--list", "--herdr-session", "other")
        self.assertEqual(agents, json.loads(result.stdout)["result"]["agents"])
        self.assertEqual([["--session", "other", "agent", "list"]], self.commands())
        self.calls.write_text("")
        self.run_agent("--list", "--herdr-session", "other", "--dry-run")
        self.run_agent("alice", "--list", code=2)
        self.assertEqual([], self.commands())

    def test_agent_status_routes_exact_name_without_mutation(self) -> None:
        snapshot = {"name": "alice", "agent_status": "working", "pane_id": "w1:p1"}
        self.state.write_text(json.dumps({"snapshots": [snapshot]}))
        result = self.run_agent("--status", "alice", "--herdr-session", "other")
        self.assertEqual(snapshot, json.loads(result.stdout)["result"]["agent"])
        self.assertEqual([["--session", "other", "agent", "get", "alice"]], self.commands())
        self.calls.write_text("")
        self.run_agent("--status", "alice", "--herdr-session", "other", "--dry-run")
        self.run_agent("--status", "alice", "--close-on-done", code=2)
        self.run_agent("alice", "--close-on-done", code=2)
        self.assertEqual([], self.commands())

    def watch_identity(self) -> dict:
        self.environment.update(HERDR_ENV="1", HERDR_WORKSPACE_ID="caller")
        return {"pane_id": "w9:p1", "name": "alice", "terminal_id": "term-1", "agent": "pi",
                "agent_session": {"kind": "path", "value": "/session/one"},
                "agent_status": "idle", "state_change_seq": 1}

    def test_close_on_done_requires_work_and_rechecks_completion(self) -> None:
        identity = self.watch_identity()
        statuses = ["idle", "done", "working", "idle", "done", "done"]
        snapshots = [{**identity, "agent_status": status, "state_change_seq": min(index, 4) + 1}
                     for index, status in enumerate(statuses)]
        for options in (("--close-on-done",), ("--close-on-done", "--wait")):
            with self.subTest(options=options), subprocess.Popen(["pi", "-c", "import time; time.sleep(30)"],
                                                                executable=sys.executable) as child:
                self.calls.write_text("")
                self.state.write_text(json.dumps({"started": identity,
                                                   "snapshots": ([identity] if "--wait" in options else []) + snapshots,
                                                   "agent_pid": child.pid, "process_info": self.process_info(child.pid)}))
                try:
                    result = self.run_agent("alice", "-t", *options)
                    calls = self.commands()
                    self.assertEqual(6 + int("--wait" in options), sum(call[:2] == ["agent", "get"] for call in calls))
                    self.assertEqual(1, sum(call[:2] == ["pane", "close"] for call in calls))
                    if "--wait" in options:
                        self.assertTrue(json.loads(result.stdout.splitlines()[-1])["result"]["exited"])
                finally:
                    if child.poll() is None:
                        child.terminate()

    def test_close_on_done_cancels_on_uncertainty_without_closing(self) -> None:
        identity = self.watch_identity()
        working = {**identity, "agent_status": "working", "state_change_seq": 2}
        done = {**identity, "agent_status": "done", "state_change_seq": 3}
        cases = [
            {"snapshots": [working, {**done, "agent_status": "blocked"}]},
            {"snapshots": [working, {**done, "agent_status": "unknown"}]},
            {"snapshots": [working, done, {**done, "agent_session": {"value": "/session/two"}}]},
            {"snapshots": [working, done, {**working, "state_change_seq": 4}]},
            {"fail": "agent get"},
            {"started": {}},
            {"started": {**working, "state_change_seq": None}, "snapshots": [done, done]},
            {"started": {**identity, "agent_status": "blocked"}, "snapshots": [working, done, done]},
        ]
        for state in cases:
            with self.subTest(state=state):
                self.calls.write_text("")
                self.state.write_text(json.dumps({"started": identity, **state}))
                result = self.run_agent("alice", "-t", "--close-on-done", code=1)
                self.assertIn("retained Herdr pane w9:p1", result.stderr)
                self.assertFalse(any(call[:2] == ["pane", "close"] for call in self.commands()))

    @staticmethod
    def process_info(pid: int) -> dict:
        return {"foreground_process_group_id": pid, "shell_pid": os.getpid(),
                "foreground_processes": [{"pid": pid}]}

    def test_agent_wait_tracks_process_not_lifecycle_and_keeps_pane(self) -> None:
        identity = self.watch_identity()
        for status, close in (("idle", False), ("done", False), ("blocked", False), ("unknown", False), ("blocked", True)):
            with self.subTest(status=status, close=close):
                self.calls.write_text("")
                with subprocess.Popen(["pi", "-c", "import time; time.sleep(30)"], executable=sys.executable) as child:
                    self.state.write_text(json.dumps({"started": {**identity, "agent_status": status},
                                                       "snapshots": [identity], "process_info": self.process_info(child.pid)}))
                    with subprocess.Popen([str(LAUNCHER), "alice", "-t", "--wait",
                                           *(["--close-on-done"] if close else [])], env=self.environment,
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as waiter:
                        try:
                            json.loads(waiter.stdout.readline())  # Start acknowledged, process still alive.
                            os.kill(child.pid, signal.SIGSTOP)
                            time.sleep(0.7)
                            self.assertIsNone(waiter.poll(), "Neither a settled state nor suspension is process exit")
                            os.kill(child.pid, signal.SIGCONT)
                            child.terminate()
                            stdout, stderr = waiter.communicate(timeout=5)
                            self.assertEqual(0, waiter.returncode, stderr)
                            if close:
                                self.assertIn("auto-close cancelled", stderr)
                            result = json.loads(stdout)["result"]
                            self.assertTrue(result["exited"])
                            self.assertIsNone(result["exit_code"])
                            self.assertFalse(any(call[:2] == ["pane", "close"] for call in self.commands()))
                        finally:
                            if child.poll() is None:
                                os.kill(child.pid, signal.SIGCONT)
                                child.terminate()
                            if waiter.poll() is None:
                                waiter.kill()
                                waiter.communicate(timeout=5)

    def test_agent_wait_rejects_unrelated_foreground_job(self) -> None:
        identity = self.watch_identity()
        with subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"]) as child:
            try:
                self.state.write_text(json.dumps({"started": identity, "snapshots": [identity],
                                                   "process_info": self.process_info(child.pid)}))
                result = self.run_agent("alice", "-t", "--wait", code=1)
                self.assertIn("not the launched agent", result.stderr)
                self.assertIsNone(child.poll())
            finally:
                child.terminate()

    def test_agent_wait_observes_exit_racing_auto_close_query(self) -> None:
        identity = {**self.watch_identity(), "agent_status": "working"}
        with subprocess.Popen(["pi", "-c", "import time; time.sleep(30)"], executable=sys.executable) as child:
            try:
                self.state.write_text(json.dumps({"started": identity, "snapshots": [identity, {"exit_agent": child.pid}],
                                                   "process_info": self.process_info(child.pid)}))
                result = self.run_agent("alice", "-t", "--wait", "--close-on-done")
                self.assertTrue(json.loads(result.stdout.splitlines()[-1])["result"]["exited"])
                self.assertFalse(any(call[:2] == ["pane", "close"] for call in self.commands()))
            finally:
                if child.poll() is None:
                    child.terminate()

    def test_pane_wait_reports_external_close_without_inventing_exit_code(self) -> None:
        self.environment.update(HERDR_ENV="1", HERDR_PANE_ID="caller:p1")
        self.state.write_text(json.dumps({"fail": "pane get", "error_code": "pane_not_found"}))
        result = self.run_pane("--wait", "--", sys.executable, "-c",
                               "import os, signal; os.kill(os.getppid(), signal.SIGKILL)", code=1)
        self.assertEqual({"pane_id": "w9:p1", "closed": True, "exit_code": None},
                         json.loads(result.stdout.splitlines()[-1])["result"])
        self.state.write_text(json.dumps({"fail": "pane get", "error_code": "server_unavailable"}))
        result = self.run_pane("--wait", "--", sys.executable, "-c",
                               "import os, signal; os.kill(os.getppid(), signal.SIGKILL)", code=1)
        self.assertNotIn('"closed": true', result.stdout)

    def test_local_exec_preserves_argv_environment_and_exit_status(self) -> None:
        literal = "quotes ' \" $HOME $(touch should-not-exist)\nnext line"
        self.environment["EXTRA"] = literal
        self.environment["CHILD_EXIT"] = "7"
        for kind in ("pi", "claude", "codex"):
            with self.subTest(kind=kind):
                result = self.run_agent("--wait", "--kind", kind, "Alice Smith", "--env", "EXTRA",
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

    def test_tab_reuse_selects_first_match_and_preserves_agent_unless_replacing(self) -> None:
        state = self.reuse_state()
        state["tabs"].append({"label": "review", "tab_id": "w1:t2"})
        state["panes"]["w1"].append({"pane_id": "w1:p2", "tab_id": "w1:t2"})
        self.state.write_text(json.dumps(state))
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

    def test_replacement_refuses_unrelated_targets_and_failed_pane_setup(self) -> None:
        for problem in ("later matching tab", "other tab", "missing tab", "split failure", "rename failure"):
            with self.subTest(problem=problem):
                self.calls.write_text("")
                state = self.reuse_state()
                if problem == "later matching tab":
                    state["tabs"].append({"label": "review", "tab_id": "w1:t2"})
                    state["panes"]["w1"][0]["tab_id"] = "w1:t2"
                    state["panes"]["w1"].append({"pane_id": "w1:p2", "tab_id": "w1:t1"})
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
            result = self.run_agent("alice", "--close", code=1 if agents else 0)
            if not agents:
                self.assertEqual({"name": "alice", "closed": False, "reason": "not_found"},
                                 json.loads(result.stdout)["result"])
            self.assertEqual([["agent", "list"]], self.commands())
        self.calls.write_text("")
        self.state.write_text(json.dumps({"fail": "agent list"}))
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

    def test_workspace_preference_requires_matching_caller_in_inherited_session(self) -> None:
        state = {
            "workspaces": [{"label": "work", "workspace_id": name} for name in ("a", "b")],
            "panes": {name: [{"cwd": str(self.project)}] for name in ("a", "b")},
        }
        self.environment.update(HERDR_ENV="1", HERDR_WORKSPACE_ID="b")
        self.state.write_text(json.dumps(state))
        self.run_agent("alice", "-w", "work")
        create = next(call for call in self.commands() if call[:2] == ["tab", "create"])
        self.assertEqual(["--workspace", "b"], create[2:4])
        for caller, session in (("b", ["--herdr-session", "other"]), ("unrelated", [])):
            self.calls.write_text("")
            self.environment["HERDR_WORKSPACE_ID"] = caller
            self.run_agent("alice", "-w", "work", *session, code=1)
            self.assertFalse(any("create" in call for call in self.commands()))
        self.calls.write_text("")
        self.environment["HERDR_WORKSPACE_ID"] = "b"
        state["panes"]["b"][0]["cwd"] = str(self.root)
        self.state.write_text(json.dumps(state))
        self.run_agent("alice", "-w", "work")
        create = next(call for call in self.commands() if call[:2] == ["tab", "create"])
        self.assertEqual(["--workspace", "a"], create[2:4])

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

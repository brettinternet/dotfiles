import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / ".bin/ssh-bench"


class SshBenchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        ssh = root / "ssh"
        ssh.write_text('''#!/usr/bin/env python3
import os
import sys
import time
host, command = sys.argv[-2:]
if host == "offline":
    print("connection refused", file=sys.stderr)
    sys.exit(255)
if host == "slow":
    time.sleep(5)
if host == "short" and command.startswith("dd "):
    sys.stdout.write("short")
    sys.exit(0)
if host == "bad-upload" and command == "wc -c":
    sys.stdin.buffer.read()
    print("0")
    sys.exit(0)
if command.startswith("sh -c"):
    if host == "rtt-closed":
        sys.exit(0)
    if host == "rtt-wrong":
        print("wrong", flush=True)
        sys.exit(0)
    if host == "rtt-stalled":
        sys.stdin.buffer.readline()
        time.sleep(5)
os.execvp("sh", ["sh", "-c", command])
''')
        ssh.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{root}:{os.environ['PATH']}"}

    def run_bench(self, *targets):
        return subprocess.run(
            [str(SCRIPT), "--size", "1", "--runs", "1", "--timeout", "1", *targets],
            env=self.env, capture_output=True, text=True, timeout=10,
        )

    def test_failed_connection_does_not_get_speed_or_stop_comparison(self):
        result = self.run_bench("offline", "working")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("FAILED: connection refused", result.stdout)
        row = next(line for line in result.stdout.splitlines() if line.startswith("working"))
        values = row.split()
        self.assertGreater(float(values[-2]), 0)
        self.assertGreater(float(values[-1]), 0)
        self.assertIn("2 MiB/target", result.stdout)

    def test_success(self):
        result = self.run_bench("working")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("FAILED", result.stdout)
        row = next(line for line in result.stdout.splitlines() if line.startswith("working"))
        values = row.split()
        self.assertGreaterEqual(float(values[-3]), float(values[-4]))

    def test_truncated_transfers_are_not_reported_as_speed(self):
        for target, direction in (("short", "download"), ("bad-upload", "upload")):
            with self.subTest(target=target):
                result = self.run_bench(target)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(f"FAILED: {direction} byte count mismatch", result.stdout)

    def test_timeout_continues_to_next_target(self):
        result = self.run_bench("slow", "working")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("timed out", result.stdout)
        self.assertTrue(any(line.startswith("working") for line in result.stdout.splitlines()))

    def test_rtt_failures_continue_to_next_target(self):
        for target, message in (
            ("rtt-closed", "closed before echo"),
            ("rtt-wrong", "echo mismatch"),
            ("rtt-stalled", "probe timed out"),
        ):
            with self.subTest(target=target):
                result = self.run_bench(target, "working")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(message, result.stdout)
                row = next(line for line in result.stdout.splitlines() if line.startswith("working"))
                self.assertNotIn("FAILED", row)

    def test_rtt_excludes_warmup_and_uses_one_connection(self):
        measure_rtt = runpy.run_path(str(SCRIPT))["measure_rtt"]
        clock = []
        for index, milliseconds in enumerate([5000, *range(1, 21)]):
            start = index * 10
            clock.extend([start, start, start + milliseconds / 1000])
        with mock.patch("subprocess.Popen") as popen, \
                mock.patch("time.perf_counter", side_effect=clock), \
                mock.patch("select.select", return_value=([1], [], [])), \
                mock.patch("os.read", return_value=b"ping\n"):
            process = popen.return_value.__enter__.return_value
            process.wait.return_value = 0
            median, p95 = measure_rtt("example", 10)
        self.assertAlmostEqual(median, 10.5)
        self.assertAlmostEqual(p95, 19)
        popen.assert_called_once()
        self.assertEqual(process.stdin.write.call_count, 21)
        process.stdin.close.assert_called_once()

    def test_invalid_size(self):
        result = subprocess.run(
            [str(SCRIPT), "--size", "0", "working"],
            env=self.env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / ".bin" / "herdr-cycle-workspace"


class CycleWorkspaceTests(unittest.TestCase):
    def run_shortcut(self, direction, active, workspaces):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "herdr"
            mock.write_text(
                "#!/bin/sh\n"
                'if [ "$1 $2" = "workspace list" ]; then\n'
                '  printf "%s\\n" "$TEST_WORKSPACES"\n'
                "else\n"
                '  printf "%s\\n" "$*" > "$TEST_FOCUS"\n'
                "fi\n"
            )
            mock.chmod(0o755)
            focus = root / "focus"
            result = subprocess.run(
                [str(SCRIPT), direction],
                env={
                    **os.environ,
                    "HERDR_BIN_PATH": str(mock),
                    "HERDR_ACTIVE_WORKSPACE_ID": active,
                    "TEST_WORKSPACES": json.dumps(
                        {"result": {"workspaces": workspaces}}
                    ),
                    "TEST_FOCUS": str(focus),
                },
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return focus.read_text() if focus.exists() else None

    def test_skips_worktrees_and_wraps_in_display_order(self):
        workspaces = [
            {"workspace_id": "w9"},
            {"workspace_id": "w2", "worktree": {"is_linked_worktree": True}},
            {"workspace_id": "w3", "worktree": {"is_linked_worktree": False}},
        ]
        for direction, active, expected in [
            ("next", "w9", "w3"),
            ("previous", "w3", "w9"),
            ("next", "w3", "w9"),
            ("previous", "w9", "w3"),
            ("next", "w2", "w3"),
            ("previous", "w2", "w9"),
        ]:
            with self.subTest(direction=direction, active=active):
                self.assertEqual(
                    self.run_shortcut(direction, active, workspaces),
                    f"workspace focus {expected}\n",
                )

    def test_no_eligible_workspace_does_not_focus(self):
        for workspaces in [
            [],
            [{"workspace_id": "w2", "worktree": {"is_linked_worktree": True}}],
        ]:
            with self.subTest(workspaces=workspaces):
                self.assertIsNone(self.run_shortcut("next", "w2", workspaces))


if __name__ == "__main__":
    unittest.main()

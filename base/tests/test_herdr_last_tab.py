import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / ".bin" / "herdr-focus-last-tab"


class LastTabTests(unittest.TestCase):
    def run_shortcut(self, tabs):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "herdr"
            mock.write_text(
                "#!/bin/sh\n"
                'if [ "$1 $2" = "tab list" ]; then\n'
                '  [ "$3 $4" = "--workspace w1" ] || exit 2\n'
                '  printf "%s\\n" "$TEST_TABS"\n'
                "else\n"
                '  printf "%s\\n" "$*" > "$TEST_FOCUS"\n'
                "fi\n"
            )
            mock.chmod(0o755)
            focus = root / "focus"
            result = subprocess.run(
                [str(SCRIPT)],
                env={
                    **os.environ,
                    "HERDR_BIN_PATH": str(mock),
                    "HERDR_ACTIVE_WORKSPACE_ID": "w1",
                    "TEST_TABS": json.dumps({"result": {"tabs": tabs}}),
                    "TEST_FOCUS": str(focus),
                },
                capture_output=True,
                text=True,
            )
            return result, focus.read_text() if focus.exists() else None

    def test_focuses_last_in_display_order_not_highest_number(self):
        result, focus = self.run_shortcut(
            [{"tab_id": "w1:t9", "number": 9}, {"tab_id": "w1:t2", "number": 2}]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(focus, "tab focus w1:t2\n")

    def test_single_tab(self):
        result, focus = self.run_shortcut([{"tab_id": "w1:t1"}])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(focus, "tab focus w1:t1\n")

    def test_empty_list_does_not_focus(self):
        result, focus = self.run_shortcut([])
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(focus)


if __name__ == "__main__":
    unittest.main()

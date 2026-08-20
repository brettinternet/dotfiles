import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "herdr/plugins/pane-collapse/toggle.py"
spec = importlib.util.spec_from_file_location("pane_collapse", SCRIPT)
pane_collapse = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(pane_collapse)


def pane(pane_id):
    return {"type": "pane", "pane_id": pane_id}


def split(first, second, ratio=0.5, direction="right"):
    return {
        "type": "split",
        "direction": direction,
        "ratio": ratio,
        "first": first,
        "second": second,
    }


class PaneCollapseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.environment = mock.patch.dict(
            os.environ,
            {
                "HERDR_PANE_ID": "w1:p1",
                "HERDR_PLUGIN_STATE_DIR": self.temporary.name,
            },
            clear=True,
        )
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.temporary.cleanup()

    def run_with_layout(self, layout):
        calls = []

        def request(method, params):
            calls.append((method, params))
            if method == "layout.export":
                return {"layout": layout}
            return {"type": "layout_split_ratio_set"}

        with mock.patch.object(pane_collapse, "request", side_effect=request):
            result = pane_collapse.toggle()
        return result, calls

    def test_collapses_first_child_to_minimum(self):
        layout = {
            "tab_id": "w1:t1",
            "root": split(pane("w1:p1"), pane("w1:p2"), ratio=0.4),
        }

        result, calls = self.run_with_layout(layout)

        self.assertEqual(result, "collapsed w1:p1")
        self.assertEqual(
            calls[-1],
            (
                "layout.set_split_ratio",
                {"tab_id": "w1:t1", "path": [], "ratio": 0.1},
            ),
        )

    def test_collapses_second_child_from_opposite_edge(self):
        layout = {
            "tab_id": "w1:t1",
            "root": split(pane("w1:p2"), pane("w1:p1"), ratio=0.4),
        }

        _, calls = self.run_with_layout(layout)

        self.assertEqual(calls[-1][1]["ratio"], 0.9)

    def test_restores_exact_ratio_while_ignoring_collapsed_ratio(self):
        original = {
            "tab_id": "w1:t1",
            "root": split(pane("w1:p1"), pane("w1:p2"), ratio=0.37),
        }
        self.run_with_layout(original)
        collapsed = {
            "tab_id": "w1:t1",
            "root": split(pane("w1:p1"), pane("w1:p2"), ratio=0.1),
        }

        result, calls = self.run_with_layout(collapsed)

        self.assertEqual(result, "restored w1:p1")
        self.assertEqual(calls[-1][1]["ratio"], 0.37)

    def test_refuses_restore_after_topology_change(self):
        original = {
            "tab_id": "w1:t1",
            "root": split(pane("w1:p1"), pane("w1:p2")),
        }
        self.run_with_layout(original)
        changed = {
            "tab_id": "w1:t1",
            "root": split(
                pane("w1:p1"),
                split(pane("w1:p2"), pane("w1:p3"), direction="down"),
                ratio=0.1,
            ),
        }

        with self.assertRaisesRegex(RuntimeError, "layout changed"):
            self.run_with_layout(changed)


if __name__ == "__main__":
    unittest.main()

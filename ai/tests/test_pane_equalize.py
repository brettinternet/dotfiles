import importlib.util
import os
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "herdr/plugins/pane-equalize/equalize.py"
spec = importlib.util.spec_from_file_location("pane_equalize", SCRIPT)
pane_equalize = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(pane_equalize)


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


class PaneEqualizeTest(unittest.TestCase):
    def setUp(self):
        self.environment = mock.patch.dict(
            os.environ,
            {"HERDR_PANE_ID": "w1:p1"},
            clear=True,
        )
        self.environment.start()

    def tearDown(self):
        self.environment.stop()

    def run_with_layout(self, layout):
        calls = []

        def request(method, params):
            calls.append((method, params))
            if method == "layout.export":
                return {"layout": layout}
            return {"type": "layout_split_ratio_set"}

        with mock.patch.object(pane_equalize, "request", side_effect=request):
            result = pane_equalize.equalize()
        return result, calls

    def test_weights_each_split_by_descendant_pane_count(self):
        layout = {
            "tab_id": "w1:t1",
            "root": split(
                pane("w1:p1"),
                split(
                    pane("w1:p2"),
                    pane("w1:p3"),
                    ratio=0.8,
                    direction="down",
                ),
                ratio=0.8,
            ),
        }

        result, calls = self.run_with_layout(layout)

        self.assertEqual(result, "equalized 3 panes")
        self.assertEqual(
            calls,
            [
                ("layout.export", {"pane_id": "w1:p1"}),
                (
                    "layout.set_split_ratio",
                    {"tab_id": "w1:t1", "path": [], "ratio": 1 / 3},
                ),
                (
                    "layout.set_split_ratio",
                    {"tab_id": "w1:t1", "path": [True], "ratio": 0.5},
                ),
            ],
        )

    def test_equalizes_unbalanced_four_pane_tree(self):
        layout = {
            "tab_id": "w1:t1",
            "root": split(
                split(pane("w1:p1"), pane("w1:p2"), ratio=0.2),
                split(pane("w1:p3"), pane("w1:p4"), ratio=0.7),
                ratio=0.9,
            ),
        }

        _, calls = self.run_with_layout(layout)

        self.assertEqual([params["ratio"] for _, params in calls[1:]], [0.5, 0.5, 0.5])

    def test_single_pane_is_a_no_op(self):
        layout = {"tab_id": "w1:t1", "root": pane("w1:p1")}

        result, calls = self.run_with_layout(layout)

        self.assertEqual(result, "tab already has one pane")
        self.assertEqual(calls, [("layout.export", {"pane_id": "w1:p1"})])


if __name__ == "__main__":
    unittest.main()

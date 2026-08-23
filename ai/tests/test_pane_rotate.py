import copy
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).parents[1] / "herdr/plugins/pane-rotate/rotate.py"
spec = importlib.util.spec_from_file_location("pane_rotate", SCRIPT)
pane_rotate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(pane_rotate)


def pane(pane_id):
    return {"type": "pane", "pane_id": pane_id, "cwd": "/repo"}


def split(first, second, ratio=0.5, direction="right"):
    return {
        "type": "split",
        "direction": direction,
        "ratio": ratio,
        "first": first,
        "second": second,
    }


def remove_pane(node, pane_id):
    if node["type"] == "pane":
        return None if node["pane_id"] == pane_id else node
    first = remove_pane(node["first"], pane_id)
    second = remove_pane(node["second"], pane_id)
    if first is None:
        return second
    if second is None:
        return first
    changed = copy.deepcopy(node)
    changed["first"] = first
    changed["second"] = second
    return changed


def insert_pane(node, target_pane_id, moved_pane_id, direction, ratio):
    if node["type"] == "pane":
        if node["pane_id"] != target_pane_id:
            return node
        return split(node, pane(moved_pane_id), ratio=ratio, direction=direction)
    changed = copy.deepcopy(node)
    changed["first"] = insert_pane(
        node["first"], target_pane_id, moved_pane_id, direction, ratio
    )
    changed["second"] = insert_pane(
        node["second"], target_pane_id, moved_pane_id, direction, ratio
    )
    return changed


class FakeHerdr:
    def __init__(self, root, fail_return=False):
        self.layout = {
            "workspace_id": "w1",
            "tab_id": "w1:t1",
            "zoomed": False,
            "root": root,
        }
        self.pane_tabs = {pane_id: "w1:t1" for pane_id in self.pane_ids(root)}
        self.calls = []
        self.fail_return = fail_return

    def pane_ids(self, node):
        if node["type"] == "pane":
            return [node["pane_id"]]
        return self.pane_ids(node["first"]) + self.pane_ids(node["second"])

    def request(self, method, params):
        self.calls.append((method, copy.deepcopy(params)))
        if method == "layout.export":
            return {"type": "layout_export", "layout": copy.deepcopy(self.layout)}
        if method == "pane.get":
            pane_id = params["pane_id"]
            return {
                "type": "pane_info",
                "pane": {"pane_id": pane_id, "tab_id": self.pane_tabs[pane_id]},
            }
        if method != "pane.move":
            raise AssertionError(f"unexpected method {method}")

        pane_id = params["pane_id"]
        destination = params["destination"]
        if destination["type"] == "new_tab":
            self.layout["root"] = remove_pane(self.layout["root"], pane_id)
            self.pane_tabs[pane_id] = "w1:t2"
            return self.move_response(changed=True)

        if self.fail_return:
            self.fail_return = False
            return self.move_response(changed=False, reason="target_pane_not_found")

        self.layout["root"] = insert_pane(
            self.layout["root"],
            destination["target_pane_id"],
            pane_id,
            destination["split"],
            destination["ratio"],
        )
        self.pane_tabs[pane_id] = destination["tab_id"]
        return self.move_response(changed=True)

    @staticmethod
    def move_response(changed, reason=None):
        return {
            "type": "pane_move",
            "move_result": {"changed": changed, "reason": reason},
        }


class PaneRotateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temporary.cleanup()

    def rotate(self, fake, focused, direction):
        environment = {
            "HERDR_PANE_ID": focused,
            "HERDR_PLUGIN_ACTION_ID": f"brett.pane-rotate.{direction}",
            "HERDR_PLUGIN_STATE_DIR": self.temporary.name,
        }
        with (
            mock.patch.dict(os.environ, environment, clear=True),
            mock.patch.object(pane_rotate, "request", side_effect=fake.request),
        ):
            return pane_rotate.rotate()

    def test_rotates_each_declared_direct_neighbor(self):
        cases = (
            ("right", "w1:p1", "right", "down"),
            ("left", "w1:p2", "right", "down"),
            ("down", "w1:p1", "down", "right"),
            ("up", "w1:p2", "down", "right"),
        )
        for declared, focused, original_axis, new_axis in cases:
            with self.subTest(declared=declared):
                fake = FakeHerdr(
                    split(
                        pane("w1:p1"),
                        pane("w1:p2"),
                        ratio=0.37,
                        direction=original_axis,
                    )
                )

                result = self.rotate(fake, focused, declared)

                self.assertEqual(
                    result, f"rotated focused pane with its {declared} neighbor"
                )
                self.assertEqual(fake.layout["root"]["direction"], new_axis)
                self.assertEqual(fake.layout["root"]["ratio"], 0.37)
                self.assertEqual(fake.pane_ids(fake.layout["root"]), ["w1:p1", "w1:p2"])
                move_calls = [call for call in fake.calls if call[0] == "pane.move"]
                self.assertEqual(move_calls[0][1]["pane_id"], "w1:p2")
                self.assertFalse(move_calls[0][1]["focus"])
                self.assertEqual(move_calls[1][1]["focus"], focused == "w1:p2")

    def test_preserves_ancestor_structure_for_nested_pair(self):
        fake = FakeHerdr(
            split(
                pane("w1:p3"),
                split(
                    pane("w1:p1"),
                    pane("w1:p2"),
                    ratio=0.4,
                    direction="right",
                ),
                ratio=0.6,
                direction="down",
            )
        )

        self.rotate(fake, "w1:p1", "right")

        self.assertEqual(fake.layout["root"]["direction"], "down")
        self.assertEqual(fake.layout["root"]["ratio"], 0.6)
        rotated = fake.layout["root"]["second"]
        self.assertEqual(rotated["direction"], "down")
        self.assertEqual(rotated["ratio"], 0.4)

    def test_rejects_geometric_neighbor_that_is_not_a_direct_leaf_sibling(self):
        fake = FakeHerdr(
            split(
                pane("w1:p1"),
                split(pane("w1:p2"), pane("w1:p3"), direction="down"),
            )
        )

        with self.assertRaisesRegex(RuntimeError, "not a direct pane sibling"):
            self.rotate(fake, "w1:p1", "right")

        self.assertFalse(any(method == "pane.move" for method, _ in fake.calls))

    def test_rejects_declared_direction_that_does_not_match_sibling(self):
        fake = FakeHerdr(split(pane("w1:p1"), pane("w1:p2"), direction="right"))

        with self.assertRaisesRegex(RuntimeError, "no direct left sibling"):
            self.rotate(fake, "w1:p1", "left")

        self.assertFalse(any(method == "pane.move" for method, _ in fake.calls))

    def test_rejects_zoomed_tab(self):
        fake = FakeHerdr(split(pane("w1:p1"), pane("w1:p2")))
        fake.layout["zoomed"] = True

        with self.assertRaisesRegex(RuntimeError, "zoomed tab"):
            self.rotate(fake, "w1:p1", "right")

    def test_failed_return_move_restores_original_layout(self):
        fake = FakeHerdr(
            split(pane("w1:p1"), pane("w1:p2"), ratio=0.3), fail_return=True
        )

        with self.assertRaisesRegex(RuntimeError, "recovered interrupted rotation"):
            self.rotate(fake, "w1:p1", "right")

        self.assertEqual(fake.layout["root"]["direction"], "right")
        self.assertEqual(fake.layout["root"]["ratio"], 0.3)
        self.assertEqual(fake.pane_tabs["w1:p2"], "w1:t1")
        self.assertFalse((Path(self.temporary.name) / "rotation.json").exists())

    def test_recovers_stranded_pane_before_new_rotation(self):
        fake = FakeHerdr(pane("w1:p1"))
        fake.pane_tabs["w1:p2"] = "w1:t2"
        journal = {
            "tab_id": "w1:t1",
            "workspace_id": "w1",
            "focused_pane_id": "w1:p1",
            "first_pane_id": "w1:p1",
            "second_pane_id": "w1:p2",
            "path": [],
            "direction": "right",
            "new_direction": "down",
            "ratio": 0.5,
        }
        (Path(self.temporary.name) / "rotation.json").write_text(json.dumps(journal))

        result = self.rotate(fake, "w1:p1", "right")

        self.assertEqual(
            result, "recovered interrupted rotation; invoke the action again to rotate"
        )
        self.assertEqual(fake.layout["root"]["direction"], "right")
        self.assertEqual(fake.pane_tabs["w1:p2"], "w1:t1")


if __name__ == "__main__":
    unittest.main()

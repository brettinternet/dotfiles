import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("workspace-overview.py")
SPEC = importlib.util.spec_from_file_location("workspace_overview", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
workspace_overview = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = workspace_overview
SPEC.loader.exec_module(workspace_overview)


class WorkspaceOverviewTest(unittest.TestCase):
    def test_six_panes_use_three_by_two_grid_at_popup_size(self) -> None:
        grid = workspace_overview.calculate_grid(140, 60, 6)

        self.assertEqual((grid.columns, grid.rows), (3, 2))
        self.assertGreaterEqual(grid.card_width, 32)
        self.assertGreaterEqual(grid.card_height, 8)

    def test_small_terminal_pages_without_unusable_cards(self) -> None:
        grid = workspace_overview.calculate_grid(80, 24, 20)

        self.assertEqual((grid.columns, grid.rows), (2, 2))
        self.assertEqual(grid.capacity, 4)
        self.assertGreaterEqual(grid.card_width, 32)
        self.assertGreaterEqual(grid.card_height, 8)

    def test_rendered_frame_contains_hierarchy_and_controls(self) -> None:
        card = workspace_overview.Card(
            pane_id="w1:p1",
            workspace_id="w1",
            workspace_number=1,
            workspace_label="dotfiles",
            tab_number=2,
            tab_label="agents",
            agent="omp",
            status="working",
            cwd="/repo",
            title="Implement feature",
            revision=4,
        )

        screen, grid = workspace_overview.render_screen(
            [card], {card.pane_id: "first line\nlast line"}, 0, 80, 24
        )

        self.assertEqual(grid.columns, 1)
        self.assertIn("1 dotfiles · Tab 2 agents · w1:p1", screen)
        self.assertIn("omp · working · Implement feature", screen)
        self.assertIn("last line", screen)
        self.assertIn("Enter focus", screen)
        self.assertEqual(screen.count("\n"), 23)

    def test_selected_card_uses_thick_dark_blue_border(self) -> None:
        card = workspace_overview.Card(
            pane_id="w1:p1",
            workspace_id="w1",
            workspace_number=1,
            workspace_label="dotfiles",
            tab_number=1,
            tab_label="",
            agent="omp",
            status="working",
            cwd="/repo",
            title="",
            revision=1,
        )

        selected = workspace_overview.render_card(card, "preview", 40, 8, True)
        unselected = workspace_overview.render_card(card, "preview", 40, 8, False)

        selected_prefix = workspace_overview.BOLD + workspace_overview.BLUE + "┏"
        self.assertTrue(selected[0].startswith(selected_prefix))
        self.assertIn("┃", selected[1])
        self.assertIn("┗", selected[-1])
        self.assertIn("┌", unselected[0])
        self.assertNotIn("┏", unselected[0])


if __name__ == "__main__":
    unittest.main()

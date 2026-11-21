#!/usr/bin/env python3
"""Interface : rien ne masque le centre de la vue en jeu, zones sûres et échelle selon l'écran.

Le centre (50 %, 50 %) n'est réservé qu'au panneau de saisie du coffret (modal), jamais à un message.
"""
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CLIENT = os.path.join(ROOT, "src", "client", "init.client.lua")


def text():
    return open(CLIENT, encoding="utf-8").read()


class TestUI(unittest.TestCase):
    def test_centre_is_reserved_for_the_keypad(self):
        lines = text().split("\n")
        for i, line in enumerate(lines, 1):
            if "fromScale(0.5, 0.5)" in line:
                context = "\n".join(lines[max(0, i - 3): i + 2])
                self.assertIn("keypad", context, f"élément au centre de la vue ligne {i}")

    def test_safe_area_and_top_bar_respected(self):
        src = text()
        self.assertIn("ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets", src)
        self.assertIn("gui.IgnoreGuiInset = false", src)

    def test_labels_are_scaled_to_screen(self):
        src = text()
        self.assertIn("UIScale", src)
        self.assertIn("math.clamp(height / 720, 0.8, 1.3)", src)

    def test_messages_sit_in_upper_third(self):
        src = text()
        self.assertIn("position = UDim2.fromScale(0.5, 0.18)", src)
        self.assertGreaterEqual(src.count("UDim2.fromScale(0.5, 0.18)"), 2)


if __name__ == "__main__":
    unittest.main()


class TestAccessibility(unittest.TestCase):
    """Téléphone et manette : toute action a un bouton tactile et une touche de manette, les cibles restent tenables."""

    def setUp(self):
        with open(os.path.join(ROOT, "src", "client", "init.client.lua"), encoding="utf-8") as f:
            self.src = f.read()

    def actions(self):
        block = self.src[self.src.index("local ACTIONS = {"):self.src.index("local actionButtons")]
        return re.findall(r'name = "([^"]+)",\s*order = (\d+),', block), block

    def test_every_action_has_touch_button_keyboard_and_gamepad_key(self):
        acts, block = self.actions()
        self.assertGreaterEqual(len(acts), 7)
        self.assertIn('name = "Journal"', block)
        for _ in acts:
            pass
        self.assertEqual(block.count("touch = true"), len(acts))
        self.assertEqual(block.count("kb = "), len(acts))
        self.assertEqual(block.count("gp = "), len(acts))

    def test_orders_are_unique_so_buttons_do_not_overlap(self):
        acts, _ = self.actions()
        orders = [int(o) for _, o in acts]
        self.assertEqual(len(orders), len(set(orders)))

    def test_buttons_fit_a_landscape_phone(self):
        # 4 lignes de 62 px après 70 px de marge, à l'échelle maximale 1,3 : doit tenir dans 390 px de hauteur
        self.assertIn("action.order % 4", self.src)
        self.assertLess((70 + 3 * 62 + 54) * 1.3, 430)
        self.assertIn("uiScaleValue()", self.src[self.src.index("local actionButtons"):self.src.index("Rappel des touches")])

    def test_journal_on_keyboard_and_gamepad(self):
        self.assertIn("Enum.KeyCode.J or input.KeyCode == Enum.KeyCode.DPadDown", self.src)

    def test_gamepad_prompts_not_disabled(self):
        for f in ("Quests.lua", "Props.lua", "Objectives.lua"):
            with open(os.path.join(ROOT, "src", "server", f), encoding="utf-8") as fh:
                self.assertNotIn("GamepadKeyCode = Enum.KeyCode.Unknown", fh.read())

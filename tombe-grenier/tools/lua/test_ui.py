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

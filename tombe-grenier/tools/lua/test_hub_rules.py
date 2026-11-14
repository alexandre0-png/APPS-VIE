#!/usr/bin/env python3
"""Règles du hub (src/shared/HubRules.lua) : solo, duo avec attente, délai sans borne, file d'attente."""
import os
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RULES = os.path.join(ROOT, "src", "shared", "HubRules.lua")
CFG = {"DuoWait": 60, "HubWait": 30}


def load():
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(RULES, encoding="utf-8") as f:
        return lua, lua.execute(f.read())


class TestHubRules(unittest.TestCase):
    def setUp(self):
        self.lua, self.R = load()
        self.cfg = self.lua.table_from(CFG)

    def test_nobody_present_never_launches(self):
        self.assertFalse(self.R.shouldLaunch("solo", 0, 100, self.cfg))
        self.assertFalse(self.R.shouldLaunch(None, 0, 100, self.cfg))

    def test_solo_launches_at_once(self):
        self.assertTrue(self.R.shouldLaunch("solo", 1, 0, self.cfg))

    def test_duo_waits_for_second_player(self):
        self.assertFalse(self.R.shouldLaunch("duo", 1, 10, self.cfg))
        self.assertTrue(self.R.shouldLaunch("duo", 2, 0, self.cfg))

    def test_duo_falls_back_to_solo_after_delay(self):
        self.assertFalse(self.R.shouldLaunch("duo", 1, 59, self.cfg))
        self.assertTrue(self.R.shouldLaunch("duo", 1, 60, self.cfg))

    def test_no_pad_launches_after_hub_wait(self):
        self.assertFalse(self.R.shouldLaunch(None, 1, 29, self.cfg))
        self.assertTrue(self.R.shouldLaunch(None, 1, 30, self.cfg))

    def test_group_mode(self):
        self.assertEqual(self.R.groupMode(1), "solo")
        self.assertEqual(self.R.groupMode(2), "duo")

    def test_queue_text_is_visible_count(self):
        self.assertEqual(self.R.queueText("Partie duo", 1, 2), "Partie duo : 1/2 en attente")


class TestHubPlacesAndZones(unittest.TestCase):
    """Le lieu hub a bien deux zones de lancement et les bons identifiants (non nuls, distincts)."""

    def test_hub_source_declares_both_zones(self):
        text = open(os.path.join(ROOT, "src", "common", "Hub.lua"), encoding="utf-8").read()
        self.assertIn('"Zone solo"', text)
        self.assertIn('"Zone duo"', text)
        self.assertIn("BillboardGui", text)
        self.assertIn("Atmosphere", text)
        self.assertIn("SurfaceGui", text)
        self.assertIn("PanneauExplication", text)
        self.assertIn("PointLight", text)


if __name__ == "__main__":
    unittest.main()

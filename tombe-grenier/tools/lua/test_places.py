#!/usr/bin/env python3
"""Vérifie les identifiants de lieux : non nuls, distincts, et de la forme attendue (lieux, pas univers)."""
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.lua")

# Univers de l'expérience (à ne jamais utiliser comme lieu)
UNIVERSE_IDS = {10776611603, 10776612735}


def places():
    text = open(CONFIG, encoding="utf-8").read()
    m = re.search(r"Places = \{\s*hub = (\d+),\s*game = (\d+)\s*\}", text)
    if not m:
        raise AssertionError("Config.Game.Places introuvable")
    return int(m.group(1)), int(m.group(2))


class TestPlaces(unittest.TestCase):
    def test_both_places_are_set_and_non_zero(self):
        hub, game = places()
        self.assertNotEqual(hub, 0)
        self.assertNotEqual(game, 0)

    def test_hub_and_game_are_different(self):
        hub, game = places()
        self.assertNotEqual(hub, game)

    def test_ids_are_places_not_universes(self):
        hub, game = places()
        self.assertNotIn(hub, UNIVERSE_IDS)
        self.assertNotIn(game, UNIVERSE_IDS)


if __name__ == "__main__":
    unittest.main()

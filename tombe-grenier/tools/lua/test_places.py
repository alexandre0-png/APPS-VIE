#!/usr/bin/env python3
"""Vérifie les identifiants de lieux : non nuls, distincts, et de la forme attendue (lieux, pas univers)."""
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.lua")

# Expérience unique « Sortir Du Grenier » : un univers, deux lieux (hub et partie)
UNIVERSE_ID = 10776611603
HUB_PLACE = 77452764500707
GAME_PLACE = 88091909899710
# Univers (à ne jamais utiliser comme lieu) et anciens identifiants à ne plus employer
UNIVERSE_IDS = {UNIVERSE_ID, 10776612735}
RETIRED_IDS = {124575462695705}  # ancien hub : expérience séparée


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


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

    def test_role_comes_from_place_id_not_from_the_start_place(self):
        """Le lieu de départ de l'expérience est le hub : aucun script ne suppose qu'il s'agit du jeu."""
        hub_src = read("src", "common", "Hub.lua")
        self.assertIn("game.PlaceId == Config.Game.Places.hub", hub_src)
        self.assertIn("game.PlaceId == Config.Game.Places.game", hub_src)
        self.assertEqual(HUB_PLACE, 77452764500707)  # lieu de départ de l'expérience
        for rel in ("hub.project.json", "game.project.json"):
            self.assertNotIn(str(GAME_PLACE), read(rel))

    def test_hub_and_game_are_places_of_the_same_experience(self):
        self.assertEqual(places(), (HUB_PLACE, GAME_PLACE))

    def test_retired_hub_is_not_used_anywhere(self):
        for rel in (("src", "shared", "Config.lua"), ("src", "common", "Hub.lua"), ("src", "hub", "init.server.lua")):
            text = read(*rel)
            for old in RETIRED_IDS:
                self.assertNotIn(str(old), text, rel[-1])

    def test_profile_datastore_is_shared_by_hub_and_game(self):
        """Même expérience : un seul DataStore, sans portée propre à un lieu, lu par les deux lieux."""
        profile = read("src", "common", "Profile.lua")
        self.assertIn("GetDataStore(Config.Replay.DataStoreName)", profile)
        self.assertNotIn("PlaceId", profile)
        self.assertNotIn("GetDataStore(Config.Replay.DataStoreName,", profile)
        self.assertIn("Profile.load", read("src", "hub", "init.server.lua"))
        self.assertIn("Profile.load", read("src", "server", "init.server.lua"))
        # La clé ne dépend que du joueur
        self.assertIn('"p" .. player.UserId', profile)

    def test_private_server_with_public_fallback_and_clear_message(self):
        hub = read("src", "common", "Hub.lua")
        self.assertIn("ReserveServer(Config.Game.Places.game)", hub)
        self.assertIn("TeleportToPrivateServer", hub)
        self.assertIn("TeleportAsync(Config.Game.Places.game, group)", hub)
        self.assertIn("Serveur privé indisponible", hub)


if __name__ == "__main__":
    unittest.main()

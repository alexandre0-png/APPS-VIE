#!/usr/bin/env python3
"""Ambiance des pièces (src/shared/RoomMood.lua) : chaque pièce de la carte a une ambiance valide.

- toutes les pièces de MapData.lua sont couvertes, et seulement celles-là ;
- couleurs RVB dans 0-255, intensité entre 0 et 1, portée raisonnable ;
- chaque son référencé existe dans AudioManifest.lua ;
- chaque pièce a un repère visuel nommé.
"""
import os
import re
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MOODS = os.path.join(ROOT, "src", "shared", "RoomMood.lua")
MAPDATA = os.path.join(ROOT, "src", "shared", "MapData.lua")
MANIFEST = os.path.join(ROOT, "src", "shared", "AudioManifest.lua")


def load(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding="utf-8") as f:
        return lua, lua.execute(f.read())


class TestMoods(unittest.TestCase):
    def setUp(self):
        self.lua, self.moods = load(MOODS)
        _, self.map = load(MAPDATA)
        self.manifest = set(re.findall(r"^\t(\w+)\s*=\s*\{", open(MANIFEST, encoding="utf-8").read(), re.M))

    def room_ids(self):
        ids = set()
        for i in range(1, len(self.map.rooms) + 1):
            ids.add(self.map.rooms[i].id)
        return ids

    def test_every_room_has_a_mood_and_no_extra(self):
        mood_ids = set(k for k in self.moods.rooms.keys())
        self.assertEqual(self.room_ids(), mood_ids)

    def test_light_values_are_in_range(self):
        for rid in self.moods.rooms.keys():
            m = self.moods.rooms[rid]
            for c in (m.light[1], m.light[2], m.light[3]):
                self.assertGreaterEqual(c, 0, rid)
                self.assertLessEqual(c, 255, rid)
            self.assertGreater(m.brightness, 0, rid)
            self.assertLessEqual(m.brightness, 1, rid)
            self.assertGreaterEqual(m.range, 4, rid)
            self.assertLessEqual(m.range, 30, rid)

    def test_sounds_exist_in_manifest(self):
        for rid in self.moods.rooms.keys():
            key = self.moods.rooms[rid].sound
            if key is not None:
                self.assertIn(key, self.manifest, f"{rid} : son inconnu {key}")

    def test_every_room_has_a_named_landmark(self):
        for rid in self.moods.rooms.keys():
            detail = self.moods.rooms[rid].detail
            self.assertTrue(detail[1] and len(detail[1]) > 0, rid)


if __name__ == "__main__":
    unittest.main()

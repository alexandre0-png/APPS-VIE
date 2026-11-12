#!/usr/bin/env python3
"""Tests de logique des cinématiques : durées, plans, passage (skip) et reprise.

- CinematicTimeline (logique pure) est exécuté avec lupa.
- La durée de chaque cinématique longue est lue dans src/client/Cinematic.lua (somme des « t = N »).
"""
import os
import re
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TIMELINE = os.path.join(ROOT, "src", "shared", "CinematicTimeline.lua")
CINEMATIC = os.path.join(ROOT, "src", "client", "Cinematic.lua")

# Cinématiques de 30 à 60 secondes demandées
LONG = ["arrival", "descente", "sealed", "truth"]


def load_timeline():
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(TIMELINE, encoding="utf-8") as f:
        module = lua.execute(f.read())
    return lua, module


def shot_blocks():
    """Pour chaque cinématique de SHOTS, la liste des durées « t = N » trouvées dans son bloc."""
    text = open(CINEMATIC, encoding="utf-8").read()
    blocks = {}
    for m in re.finditer(r"^\t(\w+) = \{", text, re.M):
        name = m.group(1)
        start = m.end()
        depth = 1
        i = start
        while depth and i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[start:i]
        blocks[name] = [float(x) for x in re.findall(r"\bt = ([\d.]+)", body)]
    return blocks


class TestTimeline(unittest.TestCase):
    def setUp(self):
        self.lua, self.tl = load_timeline()
        self.plans = self.lua.table_from([self.lua.table_from({"t": 3}), self.lua.table_from({"t": 4.5}), self.lua.table_from({"t": 2})])

    def test_total_sums_plans(self):
        self.assertAlmostEqual(self.tl.total(self.plans), 9.5)

    def test_locate_walks_through_plans(self):
        i, local = self.tl.locate(self.plans, 0)
        self.assertEqual((i, local), (1, 0))
        i, local = self.tl.locate(self.plans, 3.5)
        self.assertEqual(i, 2)
        self.assertAlmostEqual(local, 0.5)
        i, local = self.tl.locate(self.plans, 9.4)
        self.assertEqual(i, 3)

    def test_locate_ends_after_total(self):
        self.assertIsNone(self.tl.locate(self.plans, 9.5))
        self.assertIsNone(self.tl.locate(self.plans, 100))
        self.assertIsNone(self.tl.locate(self.plans, -1))

    def test_resume_after_skip_has_nothing_left(self):
        # Passer au milieu : le temps restant ne devient jamais négatif, et rien ne se rejoue
        self.assertAlmostEqual(self.tl.remaining(self.plans, 4), 5.5)
        self.assertEqual(self.tl.remaining(self.plans, 50), 0)
        self.assertIsNone(self.tl.locate(self.plans, 50))


class TestCinematicDurations(unittest.TestCase):
    def test_long_cinematics_last_30_to_60_seconds(self):
        blocks = shot_blocks()
        for name in LONG:
            self.assertIn(name, blocks, f"cinématique absente : {name}")
            total = sum(blocks[name])
            self.assertGreaterEqual(total, 30, f"{name} trop courte : {total} s")
            self.assertLessEqual(total, 60, f"{name} trop longue : {total} s")

    def test_every_plan_has_positive_duration(self):
        for name, durations in shot_blocks().items():
            for d in durations:
                self.assertGreater(d, 0, f"durée nulle dans {name}")


if __name__ == "__main__":
    unittest.main()

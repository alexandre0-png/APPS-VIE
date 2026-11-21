#!/usr/bin/env python3
"""Chaîne de progression strictement séquentielle : données (Chain.lua) et verrous côté serveur (Quests.lua)."""
import itertools
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestChainData(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.C = self.lua.execute(to_lua54(read("src", "shared", "Chain.lua")))
        self.ids = [self.C.STEPS[i].id for i in range(1, len(self.C.STEPS) + 1)]

    def done(self, ids):
        return self.lua.table_from({i: True for i in ids})

    def test_chain_is_the_expected_story_order(self):
        self.assertEqual(
            self.ids,
            ["note", "reflet", "coffret", "chest", "key", "melodie", "horloge", "statues", "photos",
             "sortie", "cave", "sous_sol", "enfant", "retour"],
        )
        self.assertEqual(len(set(self.ids)), len(self.ids))

    def test_every_step_has_text_and_area(self):
        for i in range(1, len(self.ids) + 1):
            step = self.C.STEPS[i]
            self.assertTrue(step.objective and step.hint and step.area, step.id)

    def test_child_is_in_the_cave_after_entering_it_and_before_the_way_out(self):
        self.assertEqual(self.ids[-1], "retour")
        self.assertEqual(self.ids.index("enfant"), self.ids.index("sous_sol") + 1, "libérée juste après l'entrée dans la cave")
        self.assertLess(self.ids.index("enfant"), self.ids.index("retour"))
        self.assertLess(self.ids.index("sortie"), self.ids.index("sous_sol"))
        self.assertEqual(self.C.get("enfant").area, "sous-sol")

    def test_no_text_places_the_child_in_the_attic(self):
        for step in ("enfant", "retour", "sous_sol"):
            text = self.C.get(step).objective + " " + self.C.get(step).hint
            self.assertNotIn("grenier", text.lower(), step)
        self.assertIn("cave", self.C.get("enfant").objective.lower())

    def test_only_the_next_step_is_active(self):
        for k in range(len(self.ids) + 1):
            done = self.done(self.ids[:k])
            current = self.C.current(done)
            self.assertEqual(current, self.ids[k] if k < len(self.ids) else None)

    def test_no_step_is_possible_before_the_previous_one(self):
        """Pour chaque étape et chaque « trou » dans les étapes précédentes, canAct est faux."""
        for idx, sid in enumerate(self.ids):
            for hole in range(idx):
                done = self.done([s for j, s in enumerate(self.ids[:idx]) if j != hole])
                self.assertFalse(self.C.canAct(done, sid), f"{sid} possible sans {self.ids[hole]}")
            self.assertTrue(self.C.canAct(self.done(self.ids[:idx]), sid), sid)

    def test_exhaustive_subsets_of_small_prefix_space(self):
        """Tous les sous-ensembles d'étapes faites : canAct(s) est vrai exactement si toutes les précédentes sont faites."""
        n = len(self.ids)
        for mask in range(0, 1 << min(n, 12)):
            chosen = [self.ids[i] for i in range(min(n, 12)) if mask >> i & 1]
            done = self.done(chosen)
            for idx, sid in enumerate(self.ids[:12]):
                expected = all(p in chosen for p in self.ids[:idx])
                self.assertEqual(bool(self.C.canAct(done, sid)), expected)

    def test_prefix_validation(self):
        self.assertTrue(self.C.isPrefix(self.done(self.ids[:5])))
        self.assertFalse(self.C.isPrefix(self.done(self.ids[:3] + [self.ids[6]])))

    def test_locked_text_names_the_current_step(self):
        text = self.C.lockedText(self.done(self.ids[:4]), "enfant")
        self.assertIn("Pas encore", text)
        self.assertIn("clé rouillée", text)


class TestServerLocks(unittest.TestCase):
    """Chaque réalisation d'une étape dans Quests.lua est précédée d'un verrou de la chaîne."""

    FLAGS = {
        "state.note = true": "note",
        "state.mirrorRead = true": "reflet",
        "state.coffret = true": "coffret",
        "state.chest = true": "chest",
        "state.boxDone = true": "melodie",
        "state.horloge = true": "horloge",
        "state.statuesDone = true": "statues",
        "state.outside = true": "sortie",
        "state.caveOpen = true": "cave",
        "state.caveEntered = true": "sous_sol",
        "state.leftViaBasement = true": "retour",
        "state.freed = true": "enfant",
    }

    def setUp(self):
        self.src = read("src", "server", "Quests.lua")
        self.lines = self.src.split("\n")

    def test_every_flag_assignment_has_a_gate_just_before(self):
        for needle, step in self.FLAGS.items():
            positions = [i for i, line in enumerate(self.lines) if line.strip() == needle]
            self.assertTrue(positions, needle)
            for i in positions:
                window = "\n".join(self.lines[max(0, i - 40):i])
                ok = (f'gate("{step}"' in window) or (f'canAct("{step}")' in window)
                if step == "statues":
                    ok = ok or 'gate("statues"' in window
                self.assertTrue(ok, f"{needle} (ligne {i + 1}) sans verrou « {step} » dans les 40 lignes précédentes")

    def test_keypad_entries_check_the_chain(self):
        sub = self.src[self.src.index("local function submitHorloge"):self.src.index("function Quests.submitCode")]
        self.assertIn('gate("horloge"', sub)
        date = self.src[self.src.index("local function submitDate"):self.src.index("local function submitHorloge")]
        self.assertIn('canAct("enfant")', date)
        self.assertNotIn("leftViaBasement", date)  # l'enfant est dans la cave : plus besoin d'être ressorti
        code = self.src[self.src.index("function Quests.submitCode"):]
        self.assertIn('gate("coffret"', code)

    def test_child_prompt_is_chain_gated_and_in_the_cage(self):
        i = self.src.index('action = "Libérer l\'enfant"')
        window = self.src[i:i + 900]
        self.assertIn('gate("enfant"', window)
        self.assertNotIn("leftViaBasement", window)
        self.assertIn('object = "Cage"', window)

    def test_photos_and_key_pickups_go_through_the_chain(self):
        obj = read("src", "server", "Objectives.lua")
        self.assertIn("Objectives.canPick", obj)
        self.assertIn('"photo")', obj)
        self.assertIn('"key")', obj)
        self.assertIn('gate(kind == "photo" and "photos" or "key", player)', self.src)

    def test_position_milestones_follow_the_chain(self):
        track = self.src[self.src.index("local function trackOnce"):self.src.index("local function trackPositions")]
        self.assertIn('canAct("sous_sol")', track)
        self.assertIn('canAct("retour")', track)

    def test_front_door_requires_all_previous_steps(self):
        i = self.src.index("function Quests.onFrontDoor")
        self.assertIn('canAct("sortie")', self.src[i:i + 200])

    def test_no_bookshelf_shortcut_to_the_small_key(self):
        i = self.src.index("local function readBook")
        block = self.src[i:i + 1600]
        self.assertNotIn("state.smallKey = true", block)

    def test_small_key_only_from_the_coffret(self):
        assigns = [i for i, l in enumerate(self.lines) if l.strip() == "state.smallKey = true"]
        self.assertEqual(len(assigns), 1)
        window = "\n".join(self.lines[max(0, assigns[0] - 40):assigns[0]])
        self.assertIn('gate("coffret"', window)

    def test_objective_shown_for_every_step(self):
        self.assertIn("OBJECTIVE[step.id]", self.src)
        self.assertIn("pushObjective()", self.src)


class TestExitDoorOpens(unittest.TestCase):
    def test_exit_door_swings_open_and_stays_passable(self):
        g = read("src", "server", "Gestures.lua")
        i = g.index("function Gestures.swingOpen")
        self.assertIn("part.CanCollide = false", g[i:i + 300])
        self.assertIn("alongX and -100 or 100", g)  # la porte d'entrée s'ouvre vers le jardin, pas sur le mobilier
        o = read("src", "server", "Objectives.lua")
        self.assertIn("Gestures.swingOpen(part)", o)
        self.assertLess(o.index("Gestures.swingOpen(part)"), o.index("onWin(player)"))


class TestPhotoNoteSlotsMatchTheChain(unittest.TestCase):
    """Les emplacements du papier sont dans le grenier (l'étape 1 s'y déroule), les photos hors sous-sol."""

    def test_slots(self):
        sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
        import generate_map as gm

        data = gm.build()
        for slot in data["slots"]["note"]:
            self.assertGreaterEqual(slot["pos"][1], gm.BASE["attic"], f"papier hors grenier : {slot['name']}")
        for slot in data["slots"]["photo"]:
            self.assertGreaterEqual(slot["pos"][1], 0, f"photo au sous-sol : {slot['name']}")
        self.assertGreaterEqual(len(data["slots"]["note"]), 3)
        self.assertGreaterEqual(len(data["slots"]["photo"]), 6)


if __name__ == "__main__":
    unittest.main()

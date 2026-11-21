#!/usr/bin/env python3
"""Déroulé pièce par pièce : chaque étape a sa pièce, les passages s'ouvrent dans l'ordre, rien n'est ouvert trop tôt,
docs/DEROULE.md est à jour, l'indice automatique arrive après 90 s, la bannière de pièce est branchée.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_deroule  # noqa: E402

ROOT = gen_deroule.ROOT


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestDeroule(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.chain, cls.der, cls.lua = gen_deroule.load()

    def step_ids(self):
        return [self.chain.STEPS[i].id for i in range(1, len(self.chain.STEPS) + 1)]

    def stages(self):
        out = []
        for i in range(1, len(self.der.STAGES) + 1):
            stage = self.der.STAGES[i]
            out.append(
                (
                    stage.id,
                    [stage.steps[j] for j in range(1, len(stage.steps) + 1)],
                    [stage.rooms[j] for j in range(1, len(stage.rooms) + 1)],
                )
            )
        return out

    def test_stages_follow_chain_order_exactly(self):
        flat = [s for _, steps, _ in self.stages() for s in steps]
        self.assertEqual(flat, self.step_ids())

    def test_every_step_has_room_key_object(self):
        for sid in self.step_ids():
            info = self.der.STEPS[sid]
            self.assertTrue(info.room and info.key, sid)

    def test_rooms_covered_exactly_once(self):
        data = read("src", "shared", "MapData.lua")
        import re

        ids = re.findall(
            r'\{id = "([a-z0-9]+)", level = "', data[data.index("rooms = {") :]
        )
        staged = [r for _, _, rooms in self.stages() for r in rooms]
        self.assertEqual(sorted(staged), sorted(ids))

    def test_gate_opens_on_last_step_of_its_part_and_in_order(self):
        order = self.step_ids()
        opened_at = [
            order.index(self.der.GATES[g].opensAt)
            for g in ("grenier", "premier", "rez", "cave")
        ]
        self.assertEqual(opened_at, sorted(opened_at))
        self.assertEqual(len(set(opened_at)), 4)
        # grenier et premier : dernière étape de leur partie ; rez : dernière étape avant la sortie ; cave : sortie faite
        stages = {sid: steps for sid, steps, _ in self.stages()}
        self.assertEqual(self.der.GATES.grenier.opensAt, stages["grenier"][-1])
        self.assertEqual(self.der.GATES.premier.opensAt, stages["premier"][-1])
        self.assertEqual(self.der.GATES.rez.opensAt, "photos")
        self.assertEqual(self.der.GATES.cave.opensAt, "sortie")

    def test_no_gate_open_before_previous_part_is_finished(self):
        order = self.step_ids()
        gates = ("grenier", "premier", "rez", "cave")
        previous_open = 0
        for upto in range(len(order) + 1):
            done = self.lua.table_from({s: True for s in order[:upto]})
            now_open = sum(1 for g in gates if self.der.gateOpen(g, done))
            self.assertGreaterEqual(now_open, previous_open)
            self.assertLessEqual(
                now_open - previous_open, 1, "deux passages s'ouvrent d'un coup"
            )
            for index, g in enumerate(gates):
                if self.der.gateOpen(g, done):
                    for earlier in gates[:index]:
                        self.assertTrue(
                            self.der.gateOpen(earlier, done),
                            f"{g} ouvert avant {earlier}",
                        )
            previous_open = now_open
        self.assertEqual(previous_open, 4)

    def test_locked_texts_say_what_is_missing(self):
        for g in ("grenier", "premier", "rez", "cave"):
            self.assertTrue(self.der.lockedText(g).startswith("Verrouillé : "), g)

    def test_room_line_depends_on_active_step(self):
        here = self.der.roomLine("tombe", "coffret")
        self.assertIn("coffret", here)
        behind = self.der.roomLine("tombe", "horloge")
        self.assertTrue(
            behind.startswith("Cette partie de la maison est derrière toi.")
        )
        ahead = self.der.roomLine("cave", "note")
        self.assertTrue(ahead.startswith("Pas encore : "))
        self.assertIsNone(self.der.roomLine("jardin", "note"))

    def test_doc_is_up_to_date(self):
        self.assertEqual(
            read("docs", "DEROULE.md"),
            gen_deroule.render(),
            "relancer python3 tools/lua/gen_deroule.py",
        )

    def test_wiring(self):
        quests = read("src", "server", "Quests.lua")
        self.assertNotIn(
            'openHatch("TrappeGrenier")\n\t\t\t\tObjectives.unlockKey()', quests
        )
        self.assertIn('if stepDone("key") then\n\t\topenHatch("TrappeGrenier")', quests)
        self.assertIn('Deroule.lockedText("grenier")', quests)
        self.assertIn('Deroule.lockedText("premier")', quests)
        self.assertIn(
            'Deroule.lockedText("rez")', read("src", "server", "Objectives.lua")
        )
        client = read("src", "client", "init.client.lua")
        self.assertIn("BanniereSalle", client)
        self.assertIn("Deroule.roomLine", client)
        self.assertIn("step = currentStep()", quests)

    def test_auto_hint_after_90_seconds(self):
        cfg = read("src", "shared", "Config.lua")
        self.assertIn("HintDelay = 90", cfg)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Budget de lumière et repères de sol (src/shared/RoomBudget.lua), sur les vraies données de carte.

- sélection des pièces actives : la pièce du joueur d'abord, puis les plus proches, à l'étage prioritaire ;
- niveaux de qualité : auto = moyen, limites croissantes ;
- chaque repère de sol trouvé ne chevauche aucun meuble de la pièce (ou il est absent).
"""
import os
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BUDGET = os.path.join(ROOT, "src", "shared", "RoomBudget.lua")
MAPDATA = os.path.join(ROOT, "src", "shared", "MapData.lua")
LANDMARK_W, LANDMARK_D = 3, 2


class TestBudget(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        with open(BUDGET, encoding="utf-8") as f:
            self.B = self.lua.execute(f.read())
        with open(MAPDATA, encoding="utf-8") as f:
            self.map = self.lua.execute(f.read())

    def rooms_table(self):
        out = self.lua.table()
        for i in range(1, len(self.map.rooms) + 1):
            r = self.map.rooms[i]
            out[i] = self.lua.table_from({
                "id": r.id, "level": r.level,
                "cx": (r.x0 + r.x1) / 2, "cz": (r.z0 + r.z1) / 2,
            })
        return out

    def test_player_room_is_first_and_budget_respected(self):
        rooms = self.rooms_table()
        player = self.lua.table_from({"x": 20, "z": 20, "level": "basement"})
        active = self.B.activeRooms(rooms, player, 4)
        self.assertEqual(active[1], "pn")
        self.assertEqual(len(list(active.values())), 4)

    def test_other_floor_is_deprioritised(self):
        rooms = self.rooms_table()
        player = self.lua.table_from({"x": 20, "z": 20, "level": "ground"})
        active = list(self.B.activeRooms(rooms, player, 30).values())
        # Toutes les pièces du rez-de-chaussée passent avant celles d'un autre étage
        ground = [r.id for r in (self.map.rooms[i] for i in range(1, len(self.map.rooms) + 1)) if r.level == "ground"]
        self.assertEqual(sorted(active[: len(ground)]), sorted(ground))

    def test_quality_levels(self):
        self.assertEqual(self.B.qualityLimits("auto").lights, self.B.qualityLimits("moyen").lights)
        self.assertLess(self.B.qualityLimits("bas").lights, self.B.qualityLimits("moyen").lights)
        self.assertLess(self.B.qualityLimits("moyen").lights, self.B.qualityLimits("haut").lights)
        self.assertLess(self.B.qualityLimits("bas").rangeScale, self.B.qualityLimits("haut").rangeScale)
        self.assertEqual(self.B.qualityLimits("n'importe").lights, self.B.qualityLimits("moyen").lights)

    def test_landmarks_never_overlap_furniture(self):
        boxes_all = []
        for i in range(1, len(self.map.furniture) + 1):
            boxes_all.append(self.map.furniture[i])
        for i in range(1, len(self.map.rooms) + 1):
            r = self.map.rooms[i]
            room = self.lua.table_from({
                "id": r.id, "x0": r.x0, "x1": r.x1, "z0": r.z0, "z1": r.z1,
                "cx": (r.x0 + r.x1) / 2, "cz": (r.z0 + r.z1) / 2,
            })
            boxes = self.lua.table()
            k = 0
            for f in boxes_all:
                if f.y0 >= self.map.base[r.level] - 1 and f.y0 <= self.map.base[r.level] + self.map.H:
                    if (f.x0 + f.x1) / 2 >= r.x0 and (f.x0 + f.x1) / 2 <= r.x1 and (f.z0 + f.z1) / 2 >= r.z0 and (f.z0 + f.z1) / 2 <= r.z1:
                        k += 1
                        boxes[k] = self.lua.table_from({"x0": f.x0, "x1": f.x1, "z0": f.z0, "z1": f.z1})
            x, z = self.B.landmarkSpot(room, boxes, LANDMARK_W, LANDMARK_D)
            if x is None:
                continue
            for b in boxes.values():
                overlap = (x - LANDMARK_W / 2 < b.x1 and x + LANDMARK_W / 2 > b.x0
                           and z - LANDMARK_D / 2 < b.z1 and z + LANDMARK_D / 2 > b.z0)
                self.assertFalse(overlap, f"repère de {r.id} chevauche un meuble")


if __name__ == "__main__":
    unittest.main()

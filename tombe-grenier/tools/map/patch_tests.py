#!/usr/bin/env python3
"""Remplace la classe TestTags de test_map.py par des tests sur les emplacements variables."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "test_map.py")

NEW_TAGS = '''class TestTags(unittest.TestCase):
    def count(self, tag):
        return sum(1 for p in DATA["props"] if p["tag"] == tag)

    def test_fixed_tags(self):
        self.assertGreaterEqual(self.count("Waypoint"), 8)
        self.assertEqual(self.count("ExitDoor"), 1)
        self.assertEqual(self.count("Lamp"), len(gm.ROOMS))

    def test_one_lamp_per_room_at_room_centre(self):
        lamps = [p for p in DATA["props"] if p["tag"] == "Lamp"]
        for rid, lv, rect, *_ in gm.ROOMS:
            cx, cz = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
            hit = [p for p in lamps if p["room"] == rid]
            self.assertEqual(len(hit), 1, f"{rid} doit avoir une lampe")
            self.assertAlmostEqual(hit[0]["pos"][0], cx)
            self.assertAlmostEqual(hit[0]["pos"][2], cz)

    def test_slot_pool_sizes(self):
        s = DATA["slots"]
        self.assertGreaterEqual(len(s["photo"]), 6)   # 3 photos tirées par partie
        self.assertGreaterEqual(len(s["key"]), 3)
        self.assertGreaterEqual(len(s["battery"]), 3)
        self.assertGreaterEqual(len(s["fall"]), 4)
        self.assertGreaterEqual(len(s["monster"]), 2)
        self.assertEqual(set(s["interactable"]), {"journal", "bougies", "peluche", "gramophone"})
        for key, options in s["interactable"].items():
            self.assertGreaterEqual(len(options), 2, f"{key} : au moins 2 emplacements")

    def test_dark_pool_is_large_enough_and_excludes_passages(self):
        s = DATA["slots"]
        self.assertGreaterEqual(len(s["dark_eligible"]), s["dark_count"] + 2)
        for forbidden in ("hall", "entree", "palier", "gro", "tombe"):
            self.assertNotIn(forbidden, s["dark_eligible"])

    def _level_of(self, y):
        return max((b for b in gm.BASE.values() if b <= y + 1e-6), default=None)

    def _all_slots(self):
        s = DATA["slots"]
        out = []
        for group in ("photo", "key", "battery", "fall", "monster"):
            for slot in s[group]:
                out.append((group, slot))
        for key, options in s["interactable"].items():
            for slot in options:
                out.append((key, slot))
        return out

    def test_every_slot_is_inside_a_room(self):
        for group, slot in self._all_slots():
            x, y, z = slot["pos"]
            level = self._level_of(y)
            self.assertIsNotNone(level, f"{group} {slot['name']} : niveau inconnu")
            self.assertIsNotNone(gm.room_at(level, x, z), f"{group} {slot['name']} hors pièce")

    def test_slots_never_inside_furniture(self):
        for group, slot in self._all_slots():
            x, y, z = slot["pos"]
            level = self._level_of(y)
            for rid, items in gm.FURNITURE.items():
                if gm.room_by_id(rid)[1] != level:
                    continue
                for it in items:
                    if it[1] <= x <= it[3] and it[2] <= z <= it[4]:
                        top = gm.BASE[level] + it[5]
                        self.assertGreaterEqual(y, top - 0.01,
                                                f"{group} {slot['name']} sous {it[0]} ({rid})")

    def test_surface_items_sit_on_a_surface(self):
        for group in ("photo", "key", "battery"):
            for slot in DATA["slots"][group]:
                x, y, z = slot["pos"]
                level = self._level_of(y)
                if y - gm.BASE[level] < 0.5:
                    continue  # posé au sol
                tops = []
                for rid, items in gm.FURNITURE.items():
                    if gm.room_by_id(rid)[1] != level:
                        continue
                    for it in items:
                        if it[1] <= x <= it[3] and it[2] <= z <= it[4]:
                            tops.append(gm.BASE[level] + it[5])
                self.assertTrue(any(0 <= y - t <= 0.5 for t in tops),
                                f"{group} {slot['name']} ne repose sur aucun meuble")

    def test_no_duplicate_positions_within_pool(self):
        for group in ("photo", "key", "battery", "fall", "monster"):
            pos = [tuple(s["pos"]) for s in DATA["slots"][group]]
            self.assertEqual(len(pos), len(set(pos)), f"doublon dans {group}")


class TestDecor(unittest.TestCase):
    def test_decor_inside_footprint_and_marked(self):
        for d in DATA["decor"]:
            self.assertTrue(d.get("deco"), f"{d['name']} doit être décoratif")
            self.assertTrue(gm.FOOT[0] <= d["x0"] and d["x1"] <= gm.FOOT[2])
            self.assertTrue(gm.FOOT[1] <= d["z0"] and d["z1"] <= gm.FOOT[3])

    def test_rooms_exported(self):
        self.assertEqual(len(DATA["rooms"]), len(gm.ROOMS))


'''


def main():
    src = open(PATH, encoding="utf-8").read()
    a = src.index("class TestTags(unittest.TestCase):")
    b = src.index("class TestInvisibleWalls(unittest.TestCase):")
    src = src[:a] + NEW_TAGS + src[b:]
    open(PATH, "w", encoding="utf-8").write(src)
    print("patched", PATH)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Passe 2 : tests des détails narratifs (mobilier, objets au sol, traces).
    python3 -m unittest discover -s tools/map -p "test_*.py"
"""
import os
import re
import sys
import unittest
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_map as gm  # noqa: E402
import details as dt  # noqa: E402

DATA = gm.build()
DETAILS = DATA["details"]
def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
STORY_ROOMS = [r[0] for r in gm.ROOMS]
EXPECTED_KEYS = {"x0", "x1", "y0", "y1", "z0", "z1", "mat", "name", "deco", "room", "mode", "t", "col"}


def room_of(d):
    return gm.room_by_id(d["room"])


def level_of(d):
    return room_of(d)[1]


def overlap(a, b):
    return (a["x0"] < b["x1"] and b["x0"] < a["x1"] and a["y0"] < b["y1"] and b["y0"] < a["y1"]
            and a["z0"] < b["z1"] and b["z0"] < a["z1"])


class TestDetailsData(unittest.TestCase):
    def test_catalog_is_valid(self):
        for kind, spec in dt.CATALOG.items():
            self.assertIn(spec["mode"], ("flat", "floor", "wall"), kind)
            self.assertTrue(all(v > 0 for v in spec["size"]), kind)
            if spec["mode"] == "wall":
                self.assertIn("y", spec, kind)

    def test_every_listed_kind_exists(self):
        for rid, kinds in dt.ROOM_DETAILS.items():
            self.assertIn(rid, STORY_ROOMS)
            for k in kinds:
                self.assertIn(k, dt.CATALOG, f"{rid} : {k}")

    def test_materials_exist_in_builder(self):
        lua = read(os.path.join(ROOT, "src", "server", "MapBuilder.lua"))
        known = set(re.findall(r"^\t(\w+)\s+= \{ color", lua, re.M))
        for spec in dt.CATALOG.values():
            self.assertIn(spec["mat"], known, spec["mat"])

    def test_generation_is_deterministic(self):
        again = gm.place_details()
        self.assertEqual(again, DETAILS)

    def test_details_carry_no_gameplay_data(self):
        for d in DETAILS:
            self.assertTrue(d["deco"], d["name"])
            self.assertLessEqual(set(d), EXPECTED_KEYS, d["name"])

    def test_builder_never_tags_or_collides_details(self):
        lua = read(os.path.join(ROOT, "src", "server", "MapBuilder.lua"))
        block = lua[lua.index("Data.details"):]
        block = block[:block.index("Portes intérieures")]
        self.assertNotIn("AddTag", block)
        self.assertIn("CanTouch = false", block)


class TestDetailsPlacement(unittest.TestCase):
    def test_every_room_is_dressed_by_the_end(self):
        """Contrôle final de la passe : chaque pièce a au moins quatre détails."""
        if len(dt.ROOM_DETAILS) < len(STORY_ROOMS):
            self.skipTest("passe 2 en cours : %d/%d pièces" % (len(dt.ROOM_DETAILS), len(STORY_ROOMS)))
        for rid in STORY_ROOMS:
            self.assertGreaterEqual(len([d for d in DETAILS if d["room"] == rid]), 4, rid)

    def test_details_inside_their_room_and_level(self):
        for d in DETAILS:
            _, lv, (x0, z0, x1, z1), *_ = room_of(d)
            base = gm.BASE[lv]
            self.assertTrue(x0 <= d["x0"] and d["x1"] <= x1 and z0 <= d["z0"] and d["z1"] <= z1,
                            f"{d['room']} : {d['name']} sort de la pièce")
            self.assertGreaterEqual(d["y0"], base - 0.001, d["name"])
            self.assertLessEqual(d["y1"], base + gm.H - 1, f"{d['name']} trop haut")

    def test_no_detail_on_a_stair(self):
        sx0, sz0, sx1, sz1 = gm.STAIR
        for d in DETAILS:
            hit = d["x0"] < sx1 + 0.3 and d["x1"] > sx0 - 0.3 and d["z0"] < sz1 + 0.3 and d["z1"] > sz0 - 0.3
            self.assertFalse(hit, f"{d['room']} : {d['name']} touche l'escalier")

    def test_no_detail_in_a_door_approach(self):
        for d in DETAILS:
            lv = level_of(d)
            for door in gm.DOORS:
                if door["level"] != lv:
                    continue
                zx0, zz0, zx1, zz1 = gm.door_zone(door)
                hit = d["x0"] < zx1 and d["x1"] > zx0 and d["z0"] < zz1 and d["z1"] > zz0
                if d["mode"] == "wall":
                    # collé au mur : seule la largeur de l'ouverture compte
                    if door["orient"] == "v":
                        along0, along1, on_line = d["z0"], d["z1"], abs(d["x0"] - door["line"]) < 1.0 or abs(d["x1"] - door["line"]) < 1.0
                    else:
                        along0, along1, on_line = d["x0"], d["x1"], abs(d["z0"] - door["line"]) < 1.0 or abs(d["z1"] - door["line"]) < 1.0
                    hit = on_line and along0 < door["c"] + door["w"] / 2 and along1 > door["c"] - door["w"] / 2
                self.assertFalse(hit, f"{d['room']} : {d['name']} dans l'approche d'une porte")

    def test_details_do_not_touch_furniture_or_decor(self):
        for d in DETAILS:
            for f in DATA["furniture"] + DATA["decor"]:
                self.assertFalse(overlap(d, f), f"{d['room']} : {d['name']} chevauche {f.get('name')}")

    def test_details_do_not_cover_game_points_or_slots(self):
        keep = gm._keep_out_boxes()
        for d in DETAILS:
            for k in keep:
                self.assertFalse(overlap(d, k), f"{d['room']} : {d['name']} sur un repère ou un emplacement")

    def test_details_do_not_overlap_each_other(self):
        for i, a in enumerate(DETAILS):
            for b in DETAILS[i + 1:]:
                self.assertFalse(overlap(a, b), f"{a['room']} : {a['name']} chevauche {b['name']}")

    def test_no_clue_slot_in_a_closed_room(self):
        pools = DATA["slots"]
        for group in ("photo", "note", "decoy", "bathkey", "battery"):
            for s in pools[group]:
                if group in ("decoy", "bathkey", "battery"):
                    continue  # leurres, clé et piles : hors périmètre des indices de l'histoire
                self.assertFalse(gm._in_locked_room(s), f"{group} {s['name']} en pièce fermée")
        for kind, slots in pools["interactable"].items():
            for s in slots:
                self.assertFalse(gm._in_locked_room(s), f"{kind} {s['name']} en pièce fermée")


class TestAccessWithDetails(unittest.TestCase):
    """Même si les détails étaient solides (ils ne le sont pas), toutes les portes restent accessibles."""

    STEP = 0.5
    RADIUS = 0.7   # demi-largeur d'un personnage, avec marge

    def obstacles(self, level, with_details=True):
        base = gm.BASE[level]
        lo, hi = base + 0.5, base + 6.0
        out = []
        for group in ("walls", "furniture", "steps"):
            for s in DATA[group]:
                if s["y1"] > lo and s["y0"] < hi:
                    out.append(s)
        if with_details:
            out += [d for d in DETAILS if d["y1"] - d["y0"] >= 0.3 and level_of(d) == level]
        return out

    def grid(self, level, with_details=True):
        blocked = set()
        obs = self.obstacles(level, with_details)
        n = self.RADIUS
        fx0, fz0, fx1, fz1 = gm.FOOT
        st = self.STEP
        for s in obs:
            if s.get("name") == "cercueil":
                continue
            i0 = int((s["x0"] - n - fx0) / st)
            i1 = int((s["x1"] + n - fx0) / st) + 1
            j0 = int((s["z0"] - n - fz0) / st)
            j1 = int((s["z1"] + n - fz0) / st) + 1
            for i in range(max(i0, 0), i1 + 1):
                for j in range(max(j0, 0), j1 + 1):
                    x, z = fx0 + i * st, fz0 + j * st
                    if s["x0"] - n < x < s["x1"] + n and s["z0"] - n < z < s["z1"] + n:
                        blocked.add((i, j))
        return blocked

    def cell(self, x, z):
        fx0, fz0 = gm.FOOT[0], gm.FOOT[1]
        return (int(round((x - fx0) / self.STEP)), int(round((z - fz0) / self.STEP)))

    def flood(self, blocked, start):
        w = int((gm.FOOT[2] - gm.FOOT[0]) / self.STEP)
        h = int((gm.FOOT[3] - gm.FOOT[1]) / self.STEP)
        if start in blocked:
            # cellule libre la plus proche
            q = deque([start])
            seen = {start}
            while q:
                c = q.popleft()
                if c not in blocked:
                    start = c
                    break
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (c[0] + dx, c[1] + dz)
                    if n not in seen and 0 <= n[0] <= w and 0 <= n[1] <= h:
                        seen.add(n)
                        q.append(n)
        seen, q = {start}, deque([start])
        while q:
            c = q.popleft()
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dz)
                if n in seen or n in blocked or not (0 <= n[0] <= w and 0 <= n[1] <= h):
                    continue
                seen.add(n)
                q.append(n)
        return seen

    def test_every_door_and_room_reachable_with_details_solid(self):
        for lv, stairs_room in (("basement", "cave"), ("ground", "hall"), ("first", "palier"), ("attic", "gro")):
            blocked = self.grid(lv, True)
            room = gm.room_by_id(stairs_room)
            cx, cz = (room[2][0] + room[2][2]) / 2, (room[2][1] + room[2][3]) / 2
            seen = self.flood(blocked, self.cell(cx, cz))
            for door in gm.DOORS:
                if door["level"] != lv or door.get("front"):
                    continue
                if door["orient"] == "v":
                    sides = [(door["line"] - 1.5, door["c"]), (door["line"] + 1.5, door["c"])]
                else:
                    sides = [(door["c"], door["line"] - 1.5), (door["c"], door["line"] + 1.5)]
                for x, z in sides:
                    if gm.room_at(lv, x, z) is None:
                        continue  # côté jardin
                    self.assertTrue(self.cell(x, z) in seen, f"{lv} : porte ({door['line']}, {door['c']}) inaccessible")
            for r in gm.ROOMS:
                if r[1] != lv:
                    continue
                rcx, rcz = (r[2][0] + r[2][2]) / 2, (r[2][1] + r[2][3]) / 2
                near = [(rcx + dx, rcz + dz) for dx in (-3, 0, 3) for dz in (-3, 0, 3)]
                self.assertTrue(any(self.cell(x, z) in seen for x, z in near if gm.room_at(lv, x, z) == r[0]),
                                f"{lv} : pièce {r[0]} inaccessible")


if __name__ == "__main__":
    unittest.main()

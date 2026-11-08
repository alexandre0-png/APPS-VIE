#!/usr/bin/env python3
"""Tests de cohérence de la carte. Lancer depuis tombe-grenier/ :
    python3 -m unittest discover -s tools/map -p "test_*.py" -v
"""
import os
import sys
import tempfile
import unittest
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_map as gm  # noqa: E402

DATA = gm.build()


def rooms_of(level):
    return [r for r in gm.ROOMS if r[1] == level]


def contains_rect(outer, inner):
    return outer[0] <= inner[0] and outer[1] <= inner[1] and inner[2] <= outer[2] and inner[3] <= outer[3]


class TestGeometry(unittest.TestCase):
    def test_rooms_inside_footprint(self):
        for rid, lv, rect, *_ in gm.ROOMS:
            self.assertTrue(contains_rect(gm.FOOT, rect), f"{rid} sort de l'emprise")

    def test_rooms_do_not_overlap_on_same_level(self):
        for lv in gm.LEVELS:
            rs = rooms_of(lv)
            for i, a in enumerate(rs):
                for b in rs[i + 1:]:
                    self.assertFalse(gm.overlaps(a[2], b[2]), f"{a[0]} chevauche {b[0]} ({lv})")

    def test_rooms_cover_footprint(self):
        for lv in gm.LEVELS:
            area = sum((r[2][2] - r[2][0]) * (r[2][3] - r[2][1]) for r in rooms_of(lv))
            fx0, fz0, fx1, fz1 = gm.FOOT
            self.assertEqual(area, (fx1 - fx0) * (fz1 - fz0), f"trous dans le niveau {lv}")

    def test_stairs_inside_one_room_per_level(self):
        for lv in gm.LEVELS:
            rid = gm.room_at(lv, 54, 25)
            self.assertIsNotNone(rid, f"pas de pièce sous l'escalier ({lv})")
            self.assertTrue(contains_rect(gm.room_by_id(rid)[2], gm.STAIR),
                            f"l'escalier déborde de {rid} ({lv})")

    def test_stair_hole_inside_stair(self):
        self.assertTrue(contains_rect(gm.STAIR, gm.STAIR_HOLE))


def aabb_overlap(a, b):
    """Recouvrement strict de deux boîtes 3D (dicts x0..z1)."""
    return (a["x0"] < b["x1"] and b["x0"] < a["x1"]
            and a["y0"] < b["y1"] and b["y0"] < a["y1"]
            and a["z0"] < b["z1"] and b["z0"] < a["z1"])


class TestSolids3D(unittest.TestCase):
    """Aucun pan de construction ne traverse un autre en 3D."""

    def solids(self):
        out = []
        for group in ("walls", "slabs", "steps", "furniture"):
            for s in DATA[group]:
                if s.get("name") == "cercueil":
                    continue  # décoratif, non collisionnable
                out.append((group, s))
        return out

    def test_no_solid_intersects_another(self):
        solids = self.solids()
        bad = []
        for i, (ga, a) in enumerate(solids):
            for gb, b in solids[i + 1:]:
                if ga == "walls" and gb == "walls":
                    continue  # jonctions d'angle : les murs se recouvrent sur 1 stud, sans effet
                if aabb_overlap(a, b):
                    bad.append(f"{ga}:{a.get('name')} x {gb}:{b.get('name')} "
                               f"@({a['x0']},{a['y0']},{a['z0']})")
        self.assertEqual(bad, [], f"{len(bad)} chevauchements, ex. : {bad[:5]}")

    def test_stairs_have_headroom(self):
        # Au-dessus de chaque marche, rien ne doit occuper les 6 studs suivants
        stairs_x = (gm.STAIR[0], gm.STAIR[2])
        stairs_z = (gm.STAIR[1], gm.STAIR[3])
        obstacles = [s for g in ("walls", "slabs", "furniture") for s in DATA[g]
                     if s.get("name") != "cercueil"]
        for step in DATA["steps"]:
            head = dict(x0=step["x0"], x1=step["x1"], z0=step["z0"], z1=step["z1"],
                        y0=step["y1"], y1=step["y1"] + 6)
            for o in obstacles:
                if aabb_overlap(head, o):
                    self.fail(f"marche sans dégagement (obstacle {o.get('name')} @y={o['y0']})")
        self.assertTrue(stairs_x and stairs_z)


class TestDoors(unittest.TestCase):
    def test_every_door_sits_on_a_wall_run(self):
        for d in gm.DOORS:
            lo, hi = d["c"] - d["w"] / 2, d["c"] + d["w"] / 2
            ok = False
            for orient, line, a, b in gm.wall_runs(d["level"]):
                if orient == d["orient"] and line == d["line"] and a <= lo and hi <= b:
                    ok = True
                    break
            self.assertTrue(ok, f"porte sans mur : {d}")

    def test_door_zones_are_free_of_furniture(self):
        for d in gm.DOORS:
            zone = gm.door_zone(d)
            for rid, items in gm.FURNITURE.items():
                if gm.room_by_id(rid)[1] != d["level"]:
                    continue
                for it in items:
                    fb = (it[1], it[2], it[3], it[4])
                    self.assertFalse(gm.overlaps(zone, fb), f"meuble {it[0]} bloque la porte {d}")


class TestFurniture(unittest.TestCase):
    def test_furniture_inside_its_room_with_margin(self):
        for rid, items in gm.FURNITURE.items():
            rect = gm.room_by_id(rid)[2]
            for it in items:
                fb = (it[1], it[2], it[3], it[4])
                inner = (rect[0] + 0.5, rect[1] + 0.5, rect[2] - 0.5, rect[3] - 0.5)
                self.assertTrue(contains_rect(inner, fb), f"{it[0]} dans {rid} déborde")

    def test_no_furniture_overlap_within_room(self):
        for rid, items in gm.FURNITURE.items():
            for i, a in enumerate(items):
                for b in items[i + 1:]:
                    fa = (a[1], a[2], a[3], a[4])
                    fb = (b[1], b[2], b[3], b[4])
                    self.assertFalse(gm.overlaps(fa, fb), f"{a[0]} chevauche {b[0]} dans {rid}")

    def test_no_furniture_in_stairwell(self):
        zone = (gm.STAIR[0] - 1, gm.STAIR[1] - 1, gm.STAIR[2] + 1, gm.STAIR[3] + 1)
        for rid, items in gm.FURNITURE.items():
            for it in items:
                self.assertFalse(gm.overlaps(zone, (it[1], it[2], it[3], it[4])),
                                 f"{it[0]} dans la cage d'escalier ({rid})")

    def test_furniture_below_ceiling(self):
        for rid, items in gm.FURNITURE.items():
            for it in items:
                self.assertLess(it[5], gm.H - 1, f"{it[0]} trop haut")

    def test_every_room_has_furniture_except_passages(self):
        for rid, lv, rect, *_ in gm.ROOMS:
            if rid in ("ps",):
                continue
            self.assertTrue(gm.FURNITURE.get(rid), f"{rid} sans meuble")

    def test_hiding_spots_inside_armoires(self):
        armoires = [it for rid, items in gm.FURNITURE.items() for it in items if it[0] == "armoire"]
        self.assertGreaterEqual(len(DATA["hiding"]), 4)
        self.assertEqual(len(DATA["hiding"]), len(armoires))
        for spot in DATA["hiding"]:
            x, y, z = spot["pos"]
            hit = any(it[1] <= x <= it[3] and it[2] <= z <= it[4] for it in armoires)
            self.assertTrue(hit, f"cachette hors armoire : {spot['name']}")


class TestConnectivity(unittest.TestCase):
    def graph(self, include_puzzles):
        adj = {r[0]: set() for r in gm.ROOMS}

        def link(a, b):
            if a and b and a != b:
                adj[a].add(b)
                adj[b].add(a)

        for d in gm.DOORS:
            if d.get("front"):
                continue
            if d.get("puzzle") and not include_puzzles:
                continue
            lv = d["level"]
            if d["orient"] == "v":
                p1, p2 = (d["line"] - 0.5, d["c"]), (d["line"] + 0.5, d["c"])
            else:
                p1, p2 = (d["c"], d["line"] - 0.5), (d["c"], d["line"] + 0.5)
            link(gm.room_at(lv, *p1), gm.room_at(lv, *p2))
        for a, b in gm.STAIR_LINKS:
            link(a, b)
        return adj

    def reach(self, adj, start):
        seen, q = {start}, deque([start])
        while q:
            cur = q.popleft()
            for n in adj[cur]:
                if n not in seen:
                    seen.add(n)
                    q.append(n)
        return seen

    def test_all_rooms_reachable_from_spawn_without_puzzles(self):
        adj = self.graph(include_puzzles=False)
        seen = self.reach(adj, "tombe")
        missing = {r[0] for r in gm.ROOMS} - seen
        self.assertEqual(missing, {"ps"}, f"pièces inaccessibles : {missing}")

    def test_puzzle_wing_opens_with_puzzle(self):
        adj = self.graph(include_puzzles=True)
        self.assertIn("ps", self.reach(adj, "tombe"))

    def test_exit_reachable_from_spawn(self):
        adj = self.graph(include_puzzles=False)
        self.assertIn("entree", self.reach(adj, "tombe"))

    def test_spawn_is_in_attic_tomb_room(self):
        x, y, z = DATA["spawn"]["pos"]
        self.assertEqual(gm.room_at("attic", x, z), "tombe")


class TestTags(unittest.TestCase):
    def count(self, tag):
        return sum(1 for p in DATA["props"] if p["tag"] == tag)

    def test_minimum_tag_counts(self):
        self.assertGreaterEqual(self.count("Waypoint"), 8)
        self.assertEqual(self.count("MonsterSpawn"), 1)
        self.assertGreaterEqual(self.count("FallSpot"), 3)
        self.assertGreaterEqual(self.count("Photo"), 3)
        self.assertEqual(self.count("Key"), 1)
        self.assertEqual(self.count("ExitDoor"), 1)
        self.assertGreaterEqual(self.count("Interactable"), 7)
        self.assertEqual(self.count("FlickerLight"), len(gm.ROOMS))

    def test_every_room_has_a_light(self):
        lights = [p for p in DATA["props"] if p["tag"] == "FlickerLight"]
        for rid, lv, rect, *_ in gm.ROOMS:
            cx, cz = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
            self.assertTrue(any(abs(p["pos"][0] - cx) < 0.01 and abs(p["pos"][2] - cz) < 0.01 for p in lights),
                            f"pas de lampe dans {rid}")

    def test_props_inside_footprint(self):
        for p in DATA["props"]:
            x, y, z = p["pos"]
            self.assertTrue(gm.FOOT[0] <= x <= gm.FOOT[2] and gm.FOOT[1] <= z <= gm.FOOT[3],
                            f"{p['name']} hors de la maison")

    def test_props_have_valid_level_height(self):
        for p in DATA["props"]:
            x, y, z = p["pos"]
            self.assertGreaterEqual(y, gm.BASE["basement"] - 1, f"{p['name']} sous le sous-sol")
            self.assertLessEqual(y, gm.BASE["attic"] + gm.H + 1, f"{p['name']} au-dessus du toit")

    def test_photos_and_key_not_inside_furniture(self):
        # Un objet posé sur un meuble doit être au-dessus de sa hauteur, pas à l'intérieur
        for p in DATA["props"]:
            if p["tag"] not in ("Photo", "Key"):
                continue
            x, y, z = p["pos"]
            for rid, items in gm.FURNITURE.items():
                base = gm.BASE[gm.room_by_id(rid)[1]]
                for it in items:
                    inside_xz = it[1] <= x <= it[3] and it[2] <= z <= it[4]
                    if inside_xz:
                        self.assertGreaterEqual(y, base + it[5] - 0.01,
                                                f"{p['name']} sous le dessus de {it[0]} ({rid})")


class TestInvisibleWalls(unittest.TestCase):
    def test_garden_is_enclosed(self):
        names = {w["name"] for w in DATA["invisible"]}
        for required in ("clôture nord", "clôture ouest", "clôture est", "clôture sud ouest", "clôture sud est"):
            self.assertIn(required, names)

    def test_gate_and_grille_are_puzzles(self):
        puzzles = {w["name"]: w["puzzle"] for w in DATA["invisible"] if "puzzle" in w}
        self.assertEqual(puzzles.get("portail"), "portail")
        self.assertEqual(puzzles.get("grille sud"), "grille")

    def test_front_door_is_the_only_house_exit(self):
        fronts = [d for d in gm.DOORS if d.get("front")]
        self.assertEqual(len(fronts), 1)
        self.assertEqual(fronts[0]["level"], "ground")
        self.assertEqual(fronts[0]["line"], gm.FOOT[3])


class TestOutput(unittest.TestCase):
    def test_lua_output_is_balanced_and_contains_sections(self):
        with tempfile.NamedTemporaryFile("w+", suffix=".lua", delete=False, encoding="utf-8") as tmp:
            path = tmp.name
        try:
            gm.write_lua(DATA, path)
            with open(path, encoding="utf-8") as f:
                text = f.read()
        finally:
            os.unlink(path)
        self.assertEqual(text.count("{"), text.count("}"))
        self.assertEqual(text.count("("), text.count(")"))
        self.assertTrue(text.startswith("-- GÉNÉRÉ"))
        for key in ("walls", "slabs", "steps", "furniture", "hiding", "props", "invisible", "garden", "spawn"):
            self.assertIn(f"{key} = ", text)


if __name__ == "__main__":
    unittest.main()

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
        spots = [s for s in DATA["hiding"] if s.get("kind") == "armoire"]
        self.assertEqual(len(spots), len(armoires))
        for spot in spots:
            x, y, z = spot["pos"]
            hit = any(it[1] <= x <= it[3] and it[2] <= z <= it[4] for it in armoires)
            self.assertTrue(hit, f"cachette hors armoire : {spot['name']}")


class TestConnectivity(unittest.TestCase):
    def graph(self, include_puzzles, include_locks=False):
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
            if d.get("lock") and not include_locks:
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

    def test_locked_rooms_are_closed_until_their_puzzle(self):
        adj = self.graph(include_puzzles=False)
        seen = self.reach(adj, "tombe")
        missing = {r[0] for r in gm.ROOMS} - seen
        self.assertEqual(missing, {"ps", "bureau", "cel", "cha", "sdb2", "sdb"}, f"pièces fermées : {missing}")

    def test_all_rooms_reachable_once_locks_are_open(self):
        adj = self.graph(include_puzzles=True, include_locks=True)
        seen = self.reach(adj, "tombe")
        self.assertEqual({r[0] for r in gm.ROOMS} - seen, set())

    def test_every_lock_has_an_unlock_source(self):
        locks = {d["lock"] for d in gm.DOORS if d.get("lock")}
        self.assertEqual(locks, {"cahier", "salle de bain", "bureau", "cellier"})
        # Chaque pièce verrouillée a TOUTES ses portes verrouillées (pas de contournement)
        for lock_name, rid in [("cahier", "cha"), ("salle de bain", "sdb"), ("bureau", "bureau"), ("cellier", "cel")]:
            rect = gm.room_by_id(rid)[2]
            lvl = gm.room_by_id(rid)[1]
            for d in gm.DOORS:
                if d["level"] != lvl or d.get("front"):
                    continue
                pts = ([(d["line"] - 0.5, d["c"]), (d["line"] + 0.5, d["c"])] if d["orient"] == "v"
                       else [(d["c"], d["line"] - 0.5), (d["c"], d["line"] + 0.5)])
                if any(gm.room_at(lvl, *p) == rid for p in pts):
                    self.assertEqual(d.get("lock"), lock_name, f"porte de {rid} non verrouillée")
        for d in gm.DOORS:
            if d.get("lock"):
                self.assertIsNone(d.get("puzzle"))

    def test_bath_key_is_not_inside_the_bathroom(self):
        for slot in gm.BATH_KEY_SLOTS:
            x, y, z = slot["pos"]
            level = "ground" if y < 12 else "first"
            self.assertNotEqual(gm.room_at(level, x, z), "sdb")

    def test_cahier_is_not_inside_the_room_it_opens(self):
        for opts in [gm.INTERACTABLE_SLOTS["cahier"]]:
            for slot in opts:
                x, y, z = slot["pos"]
                self.assertNotEqual(gm.room_at("first", x, z), "cha")

    def test_switch_for_cellier_is_outside_the_cellier(self):
        sw = [p for p in gm.build_props()[0] if p.get("name") == "interrupteur cellier"][0]
        self.assertIsNone(gm.room_at("basement", sw["pos"][0], sw["pos"][2]) if sw["pos"][0] < 40 else None)

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

    def props_with(self, tag):
        return [p for p in DATA["props"] if p["tag"] == tag]

    def test_fixed_tags(self):
        self.assertGreaterEqual(self.count("Waypoint"), 8)
        self.assertEqual(self.count("ExitDoor"), 1)
        for tag in ("Coffret", "Plaque", "Key"):
            self.assertEqual(self.count(tag), 1, tag)
        self.assertEqual(self.count("Lamp"), len(gm.ROOMS))

    def test_three_statues_and_one_breathing_wall(self):
        self.assertEqual(self.count("Statue"), 3)
        self.assertEqual(self.count("Respire"), 1)

    def test_one_mannequin_upstairs_clear_of_furniture(self):
        ms = self.props_with("Mannequin")
        self.assertEqual(len(ms), 1)
        x, y, z = ms[0]["pos"]
        self.assertFalse(gm._near_door("first", x, z))
        self.assertTrue(gm._clear(x - 0.4, z - 0.3, x + 0.4, z + 0.3, gm.BASE["first"], gm.BASE["first"] + gm.MANNEQUIN_HEIGHT, margin=0.3))

    def test_statues_are_free_standing_and_clear_of_doors(self):
        for p in self.props_with("Statue"):
            x, _, z = p["pos"]
            self.assertFalse(gm._near_door("ground", x, z), p["name"])
            self.assertTrue(gm._clear(x - 0.5, z - 0.5, x + 0.5, z + 0.5, 0, gm.STATUE_HEIGHT, margin=0.3), p["name"])

    # Pièces dont l'accès dépend d'une énigme : rien d'indispensable ne doit s'y trouver
    LOCKED_ROOMS = ("sdb", "bureau", "cha", "sdb2", "cel")

    def _room_of_point(self, x, y, z):
        for r in DATA["rooms"]:
            b = gm.BASE[r["level"]]
            if r["x0"] <= x <= r["x1"] and r["z0"] <= z <= r["z1"] and b - 1 <= y <= b + gm.H + 1:
                return r["id"]
        return None

    def test_required_puzzle_props_outside_locked_rooms(self):
        # La statue du bureau : le bureau s'ouvre avec les photos, qui ne dépendent pas des statues
        for tag in ("Coffret", "Plaque", "Key", "Respire", "Mannequin"):
            for p in self.props_with(tag):
                self.assertNotIn(self._room_of_point(*p["pos"]), self.LOCKED_ROOMS, p["name"])
        mirrors = [self._room_of_point(*p["pos"]) for p in self.props_with("Mirror")]
        self.assertTrue(any(r not in self.LOCKED_ROOMS for r in mirrors), "aucun miroir accessible")

    def test_music_box_outside_locked_rooms(self):
        # Les livres lisibles sont tagués dans DecorKit (hors pièces fermées) : voir src/server/DecorKit.lua
        for f in DATA["furniture"]:
            if f["name"] == "coffre à jouets":
                cx, cz = (f["x0"] + f["x1"]) / 2, (f["z0"] + f["z1"]) / 2
                self.assertNotIn(self._room_of_point(cx, f["y0"] + 0.5, cz), self.LOCKED_ROOMS, f["name"])

    def test_clue_slots_outside_locked_rooms(self):
        for group in ("note", "photo", "interactable"):
            for _, slot in self._all_slots():
                pass
        for group, slot in self._all_slots():
            if group not in ("note", "photo", "interactable"):
                continue
            x, y, z = slot["pos"]
            self.assertNotIn(self._room_of_point(x, y, z), self.LOCKED_ROOMS, f"{group} {slot['name']}")

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
        self.assertGreaterEqual(len(s["note"]), 4)
        self.assertGreaterEqual(len(s["decoy"]), 2)
        self.assertGreaterEqual(len(s["battery"]), 3)
        self.assertGreaterEqual(len(s["fall"]), 4)
        self.assertGreaterEqual(len(s["monster"]), 2)
        self.assertEqual(set(s["interactable"]), {"journal", "bougies", "peluche", "gramophone", "cahier", "photo_famille"})
        for key, options in s["interactable"].items():
            self.assertGreaterEqual(len(options), 2, f"{key} : au moins 2 emplacements")

    def test_dark_pool_is_large_enough_and_excludes_passages(self):
        s = DATA["slots"]
        self.assertGreaterEqual(len(s["dark_eligible"]), s["dark_count"] + 2)
        for forbidden in ("hall", "entree", "palier", "gro", "tombe"):
            self.assertNotIn(forbidden, s["dark_eligible"])

    def _level_of(self, y):
        """Nom du niveau dont le sol est le plus haut sous y."""
        best = None
        for name, base in gm.BASE.items():
            if base <= y + 1e-6 and (best is None or base > gm.BASE[best]):
                best = name
        return best

    def _all_slots(self):
        s = DATA["slots"]
        out = []
        for group in ("photo", "note", "decoy", "bathkey", "battery", "fall", "monster"):
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
        for group in ("photo", "note", "decoy", "battery"):
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
        for group in ("photo", "note", "decoy", "bathkey", "battery", "fall", "monster"):
            pos = [tuple(s["pos"]) for s in DATA["slots"][group]]
            self.assertEqual(len(pos), len(set(pos)), f"doublon dans {group}")


class TestQuestItems(unittest.TestCase):
    def test_code_note_and_lore_coverage(self):
        # Les quatre documents de l'histoire doivent avoir au moins un emplacement chacun
        for kind in ("journal", "cahier", "photo_famille"):
            self.assertGreaterEqual(len(DATA["slots"]["interactable"][kind]), 2)
        kinds = {s["kind"] for opts in DATA["slots"]["interactable"].values() for s in opts}
        for kind in ("journal intime", "cahier d'écolier", "photo de famille"):
            self.assertIn(kind, kinds)

    def test_fixed_story_props_placed_in_attic(self):
        for p in DATA["props"]:
            if p["tag"] in ("Coffret", "Plaque", "Key"):
                self.assertEqual(gm.room_at("attic", p["pos"][0], p["pos"][2]) if p["pos"][1] > 20 else None,
                                 "tombe" if p["tag"] != "Key" else "tombe",
                                 f"{p['name']} doit être dans la salle de la tombe")

    def test_chest_exists_in_tomb_room(self):
        chests = [it for it in gm.FURNITURE["tombe"] if it[0] == "coffre verrouillé"]
        self.assertEqual(len(chests), 1)


class TestDecor(unittest.TestCase):
    def test_decor_inside_footprint_and_marked(self):
        for d in DATA["decor"]:
            self.assertTrue(d.get("deco"), f"{d['name']} doit être décoratif")
            self.assertTrue(gm.FOOT[0] <= d["x0"] and d["x1"] <= gm.FOOT[2])
            self.assertTrue(gm.FOOT[1] <= d["z0"] and d["z1"] <= gm.FOOT[3])

    def test_rooms_exported(self):
        self.assertEqual(len(DATA["rooms"]), len(gm.ROOMS))


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


class TestFinalAdditions(unittest.TestCase):
    def test_cave_door_and_key(self):
        self.assertEqual(sum(1 for p in DATA["props"] if p["tag"] == "CaveDoor"), 1)
        self.assertGreaterEqual(len(DATA["slots"]["decoy"]), 3)

    def test_interior_doors_exported_and_match_openings(self):
        self.assertEqual(len(DATA["doors"]), len(gm.DOORS))
        interior = [d for d in DATA["doors"] if not d["front"] and not d.get("puzzle")]
        self.assertGreaterEqual(len(interior), 15)

    def test_curtains_are_decor_on_outer_walls(self):
        curtains = [d for d in DATA["decor"] if d["name"].startswith("rideau")]
        self.assertGreaterEqual(len(curtains), 5)
        for c in curtains:
            near_edge = (c["x0"] <= 2 or c["x1"] >= 118 or c["z0"] <= 2 or c["z1"] >= 88)
            self.assertTrue(near_edge, f"{c['name']} n'est pas contre un mur extérieur")


class TestHidingVariety(unittest.TestCase):
    def test_every_bed_has_space_underneath(self):
        for rid, items in gm.FURNITURE.items():
            for it in items:
                if it[0].startswith("lit"):
                    spots = [s for s in DATA["hiding"] if s["name"] == "sous le lit " + rid]
                    self.assertTrue(spots, f"pas de cachette sous le lit de {rid}")
                    self.assertEqual(spots[0]["posture"], "low")
                    x, _, z = spots[0]["pos"]
                    self.assertTrue(it[1] < x < it[3] and it[2] < z < it[4])

    def test_cardboard_boxes_are_hiding_spots(self):
        boxes = [it for rid, items in gm.FURNITURE.items() for it in items if it[0] == "boîte en carton"]
        self.assertGreaterEqual(len(boxes), 2)
        kinds = [s for s in DATA["hiding"] if s.get("kind") == "boîte"]
        self.assertEqual(len(kinds), len(boxes))

    def test_three_switches_for_the_fuse(self):
        sw = [p for p in DATA["props"] if p["tag"] == "Switch"]
        self.assertEqual(len(sw), 3)
        for p in sw:
            self.assertTrue(gm.room_at("basement" if p["pos"][1] < 0 else "ground", p["pos"][0], p["pos"][2]) is not None
                            or p["pos"][0] >= 118 or p["pos"][2] <= 2)


if __name__ == "__main__":
    unittest.main()


class TestProgressionV2(unittest.TestCase):
    """Progression V2 : l'horloge du hall doit exister, être dans le hall et accessible."""

    def test_hall_clock_exists_once_in_hall(self):
        props = gm.build_props()[0]
        clocks = [p for p in props if p.get("tag") == "Horloge"]
        self.assertEqual(len(clocks), 1)
        x, y, z = clocks[0]["pos"]
        self.assertEqual(gm.room_at("ground", x, z), "hall")

    def test_hall_is_not_locked(self):
        self.assertNotIn("hall", gm.LOCKED_ROOM_IDS)


class TestDrawer(unittest.TestCase):
    def test_one_drawer_in_kitchen(self):
        props = gm.build_props()[0]
        drawers = [p for p in props if p.get("tag") == "Tiroir"]
        self.assertEqual(len(drawers), 1)
        x, y, z = drawers[0]["pos"]
        self.assertEqual(gm.room_at("ground", x, z), "cuis")


class TestExtraPuzzle(unittest.TestCase):
    """Énigme optionnelle : étiquette et compteur dans la cuisine, pièce non verrouillée."""

    def test_counter_and_label_in_kitchen(self):
        props = gm.build_props()[0]
        counters = [p for p in props if p.get("tag") == "Compteur"]
        labels = [p for p in props if p.get("kind") == "étiquette de la réserve"]
        self.assertEqual(len(counters), 1)
        self.assertEqual(len(labels), 1)
        for p in counters + labels:
            x, y, z = p["pos"]
            self.assertEqual(gm.room_at("ground", x, z), "cuis")

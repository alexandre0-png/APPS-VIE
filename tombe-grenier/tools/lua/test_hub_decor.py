#!/usr/bin/env python3
"""Décor du hub : comptage de pièces et de lumières, présence des éléments, zone d'arrivée dégagée,
aucune collision, aucun clic, aucune plaque cachée, repli procédural des modèles, rôle forcé en Studio."""
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SHARED = os.path.join(ROOT, "src", "shared")


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class Base(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)

        def mod(name):
            return self.lua.execute(to_lua54(read("src", "shared", name + ".lua")))

        self.mod = mod
        self.L = mod("HubLayout")
        self.Config = mod("Config")
        self.Budget = mod("RoomBudget")
        self.items = [self.item(i) for i in range(1, len(self.L.ITEMS) + 1)]

    def item(self, i):
        it = self.L.ITEMS[i]
        d = {k: it[k] for k in it.keys() if k not in ("size",)}
        spec = self.L.KINDS[it.kind]
        size = it.size if it.size is not None else spec.size
        d["size"] = [size[1], size[2], size[3]]
        d["spec"] = {k: spec[k] for k in spec.keys() if k != "size"}
        return d

    def fp(self, d):
        s = d["size"]
        return (d["x"] - s[0] / 2, d["x"] + s[0] / 2, d["z"] - s[2] / 2, d["z"] + s[2] / 2)


def rects_overlap(a, b, margin=0.0):
    return a[0] < b[1] + margin and b[0] < a[1] + margin and a[2] < b[3] + margin and b[2] < a[3] + margin


class TestLayoutCounts(Base):
    def test_part_count_within_budget(self):
        parts, lights = self.L.totals(self.L.ITEMS)
        self.assertLessEqual(parts, self.L.MAX_PARTS)
        self.assertGreaterEqual(parts, 80, "hub encore trop vide")

    def test_lights_within_room_budget(self):
        for quality in ("bas", "moyen", "haut"):
            limit = self.L.lightLimit(self.Budget.qualityLimits(quality))
            budget = max(0, limit - self.L.EXISTING_LIGHTS)
            plan = self.L.plan(self.L.ITEMS, self.L.MAX_PARTS, budget)
            self.assertLessEqual(plan.lights, budget, quality)
            self.assertLessEqual(plan.parts, self.L.MAX_PARTS)
        moyen = self.L.lightLimit(self.Budget.qualityLimits("moyen")) - self.L.EXISTING_LIGHTS
        plan = self.L.plan(self.L.ITEMS, self.L.MAX_PARTS, moyen)
        self.assertEqual(plan.dropped, 0)
        self.assertGreaterEqual(plan.lights, 6, "lueurs chaudes insuffisantes à qualité moyenne")

    def test_plan_drops_beyond_part_limit_and_strips_lights(self):
        plan = self.L.plan(self.L.ITEMS, 20, 0)
        self.assertLessEqual(plan.parts, 20)
        self.assertGreater(plan.dropped, 0)
        full = self.L.plan(self.L.ITEMS, self.L.MAX_PARTS, 0)
        self.assertEqual(full.lights, 0)
        items = full["items"]
        lit = [items[i] for i in range(1, len(items) + 1)]
        self.assertTrue(any(it.noLight for it in lit))

    def test_required_elements_present(self):
        count = {}
        for d in self.items:
            count[d["kind"]] = count.get(d["kind"], 0) + 1
        for kind, minimum in {"etagere": 3, "malle": 3, "lampe": 3, "bougie": 5, "toile": 4, "tapis": 2,
                              "cadre": 3, "plante_morte": 3, "poutre": 2}.items():
            self.assertGreaterEqual(count.get(kind, 0), minimum, kind)
        candle_lights = [d for d in self.items if d["kind"] == "bougie" and d.get("light")]
        self.assertGreaterEqual(len(candle_lights), 3, "bougies avec PointLight")
        labels = sorted(d["label"] for d in self.items if d.get("label"))
        self.assertEqual(labels, ["duo", "regles", "solo"])

    def test_signs_stand_in_front_of_each_pad(self):
        for mode in ("solo", "duo"):
            pad = self.L.PADS[mode]
            sign = next(d for d in self.items if d.get("label") == mode)
            self.assertLessEqual(abs(sign["x"] - pad.x), 2, mode)
            self.assertTrue(0 < sign["z"] < pad.z - pad.half, f"{mode} : entre l'arrivée et la borne")
            self.assertEqual(sign["facing"], "-z", "tourné vers l'arrivée (face avant = -Z)")

    def test_pad_positions_match_hub_source(self):
        hub = read("src", "common", "Hub.lua")
        for mode, pad in (("solo", self.L.PADS.solo), ("duo", self.L.PADS.duo)):
            self.assertIn(f"Vector3.new({int(pad.x)}, 0.5, {int(pad.z)})", hub, mode)
        self.assertIn("Vector3.new(300, 0, 300)", hub)

    def test_rules_and_pad_texts(self):
        rules = self.L.rulesText(self.Config)
        for needle in ("RÈGLES", "Ctrl", "Maj", "F :", "H : indice", "vies"):
            self.assertIn(needle, rules)
        solo = self.L.padText("solo", self.Config)
        duo = self.L.padText("duo", self.Config)
        self.assertIn("SOLO", solo)
        self.assertIn("DUO", duo)
        self.assertIn(str(self.Config.Balance.solo.lives), solo)
        self.assertIn(str(self.Config.Game.DuoWait), duo)


class TestLayoutPlacement(Base):
    def solids(self):
        return [d for d in self.items if not d["spec"].get("flat") and not d["spec"].get("high") and not d.get("on")]

    def pillars(self):
        return [(p[1], p[2]) for p in self.L.PILLARS.values()]

    def test_everything_inside_the_floor(self):
        half = self.L.HALF
        for d in self.items:
            x0, x1, z0, z1 = self.fp(d)
            self.assertTrue(-half <= x0 and x1 <= half and -half <= z0 and z1 <= half, f"{d['kind']} ({d['x']}, {d['z']}) hors du sol")

    def test_arrival_zone_is_clear(self):
        r = self.L.CLEAR_RADIUS
        for d in self.solids():
            x0, x1, z0, z1 = self.fp(d)
            nearest = (min(max(0, x0), x1) if x0 > 0 else (max(min(0, x1), x0)), min(max(0, z0), z1) if z0 > 0 else (max(min(0, z1), z0)))
            dist = (nearest[0] ** 2 + nearest[1] ** 2) ** 0.5
            self.assertGreaterEqual(dist, r, f"{d['kind']} ({d['x']}, {d['z']}) dans la zone d'arrivée (rayon {r})")

    def test_no_overlap_with_pads_pillars_bench_board(self):
        fixed = []
        for pad in (self.L.PADS.solo, self.L.PADS.duo):
            fixed.append((pad.x - pad.half, pad.x + pad.half, pad.z - pad.half, pad.z + pad.half))
        h = self.L.PILLAR_HALF
        for px, pz in self.pillars():
            fixed.append((px - h, px + h, pz - h, pz + h))
        b = self.L.BENCH
        fixed.append((b.x - b.hx, b.x + b.hx, b.z - b.hz, b.z + b.hz))
        bd = self.L.BOARD
        fixed.append((bd.x - bd.hx, bd.x + bd.hx, bd.z - bd.hz, bd.z + bd.hz))
        for d in self.solids():
            if d["spec"].get("wall"):
                continue  # cadres et toiles collés aux piliers : sur leur face, pas dans leur volume
            for f in fixed:
                self.assertFalse(rects_overlap(self.fp(d), f), f"{d['kind']} ({d['x']}, {d['z']}) sur un élément fixe")

    def test_wall_items_sit_just_outside_a_pillar_or_shelf(self):
        for d in self.items:
            if not d["spec"].get("wall"):
                continue
            near = [
                (px, pz) for px, pz in self.pillars()
                if abs(d["z"] - pz) < 0.5 and abs(abs(d["x"]) - (abs(px) - 1.6)) < 0.3
            ]
            on_shelf = abs(d["x"] + 26.6) < 0.01 and d["kind"] == "toile"
            self.assertTrue(near or on_shelf, f"{d['kind']} ({d['x']}, {d['z']}) flotte dans le vide")

    def test_no_overlap_between_decor_items(self):
        solids = self.solids()
        for i, a in enumerate(solids):
            for b in solids[i + 1:]:
                if a["spec"].get("wall") and b["spec"].get("wall"):
                    if a["kind"] == b["kind"] or a["y"] != b["y"]:
                        continue
                self.assertFalse(rects_overlap(self.fp(a), self.fp(b)), f"{a['kind']} ({a['x']}, {a['z']}) chevauche {b['kind']} ({b['x']}, {b['z']})")

    def test_orientation_matches_size_axes(self):
        for d in self.items:
            f = d.get("facing")
            if not f or d["kind"] in ("poutre",):
                continue
            sx, _, sz = d["size"]
            if f in ("+x", "-x"):
                self.assertLessEqual(sx, sz + 1e-9, f"{d['kind']} : épaisseur sur x pour une face ±x")
            else:
                self.assertLessEqual(sz, sx + 1e-9, f"{d['kind']} : épaisseur sur z pour une face ±z")

    def test_candles_stand_on_trunks_not_in_the_air(self):
        trunks = [d for d in self.items if d["kind"] == "malle"]
        for d in self.items:
            if d.get("on"):
                self.assertTrue(any(abs(t["x"] - d["x"]) < 0.01 and abs(t["z"] - d["z"]) < 0.01 and abs(d["y"] - t["size"][1]) < 0.01 for t in trunks))

    def test_rugs_are_flat_and_walkable(self):
        for d in self.items:
            if d["spec"].get("flat"):
                self.assertLessEqual(d["size"][1], 0.1)


class TestDecorSource(unittest.TestCase):
    def setUp(self):
        self.src = read("src", "common", "HubDecor.lua")

    def test_no_collision_click_or_hidden_plate(self):
        for banned in ("ProximityPrompt", "ClickDetector", "TouchInterest", "CanCollide = true", "Touched"):
            self.assertNotIn(banned, self.src, banned)
        # aucune pièce invisible (plaque cachée) : la transparence totale n'est utilisée que pour le fond d'un texte
        self.assertIsNone(re.search(r"(?<![A-Za-z])Transparency = 1\b", self.src))
        self.assertIn("p.CanCollide = false", self.src)
        self.assertIn("p.CanQuery = false", self.src)
        self.assertIn("p.CanTouch = false", self.src)

    def test_candles_and_lamps_have_point_lights_and_dust(self):
        self.assertIn("PointLight", self.src)
        self.assertIn("ParticleEmitter", self.src)
        self.assertIn("Config.Visual.Dust", self.src)
        self.assertIn("Config.Hub.Decor", self.src)

    def test_models_use_loader_with_procedural_fallback(self):
        for needle in ("InsertService", "pcall", "AssetLoad.install", "Config.Assets.Timeout", "Config.Assets.Enabled",
                       "le décor procédural reste"):
            self.assertIn(needle.replace("Config.Assets.Timeout", "Assets.Timeout").replace("Config.Assets.Enabled", "Assets.Enabled")
                          if needle.startswith("Config.Assets.") else needle, self.src, needle)
        # le procédural est construit d'abord, le remplacement vient après, dans une tâche à part
        self.assertLess(self.src.index("BUILD[it.kind]"), self.src.index("swapModels, folder, groups"))

    def test_respects_budgets(self):
        self.assertIn("HubLayout.plan", self.src)
        self.assertIn("RoomBudget.qualityLimits", self.src)

    def test_assets_declared_in_config(self):
        layout = read("src", "shared", "HubLayout.lua")
        cfg = read("src", "shared", "Config.lua")
        for key in re.findall(r'=\s*"(\w+)",?\s*\n', layout[layout.index("HubLayout.ASSETS"):layout.index("HubLayout.ASSETS") + 200]):
            self.assertRegex(cfg, rf"\b{key}\s*=\s*\d+", key)

    def test_hub_builds_decor_without_depending_on_it(self):
        hub = read("src", "common", "Hub.lua")
        self.assertIn("HubDecor", hub)
        self.assertRegex(hub, r"pcall\(function\(\)\s*require\(script\.Parent\.HubDecor\)")

    def test_explanation_board_faces_the_arrival(self):
        hub = read("src", "common", "Hub.lua")
        i = hub.index("PanneauExplication")
        self.assertIn("NormalId.Back", hub[i:i + 900])


class TestStudioRole(unittest.TestCase):
    def test_hub_script_forces_hub_role_in_studio_only(self):
        hub_init = read("src", "hub", "init.server.lua")
        self.assertIn('Config.Debug.PlaceRole = Config.Debug.PlaceRole or "hub"', hub_init)
        self.assertLess(hub_init.index("PlaceRole"), hub_init.index("require(script.Parent.Common.Hub)"))
        hub = read("src", "common", "Hub.lua")
        # en production le rôle vient de game.PlaceId : le réglage de Studio est ignoré hors Studio
        self.assertRegex(hub, r"RunService:IsStudio\(\) and \(?Config\.Debug\.PlaceRole")
        self.assertIn("game.PlaceId == Config.Game.Places.hub", hub)

    def test_default_is_unset_in_config(self):
        self.assertRegex(read("src", "shared", "Config.lua"), r"PlaceRole = nil")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Modèles Blender (clé, coffret, horloge, poupée, bougie) : identifiants, chargement, échelle, orientation, repli,
halo sur le modèle, placement sans gêne. Le vrai MapBuilder tourne dans le faux Roblox avec et sans modèles."""
import math
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "map"))
import test_spawn_map as base  # noqa: E402
import test_spawn_roles as roles  # noqa: E402
import test_robust as robust  # noqa: E402
from check_syntax import to_lua54  # noqa: E402
import generate_map as gm  # noqa: E402

ROOT = base.ROOT

IDS = {
    "CleOr": 128263149076283,
    "CoffretAncien": 80816541343966,
    "HorlogeComtoise": 121788657121996,
    "PoupeeAncienne": 114751010380157,
    "BougieChandelier": 118027923730609,
}
NAMES = {
    "CleOr": "clé or",
    "CoffretAncien": "coffret ancien",
    "HorlogeComtoise": "horloge comtoise",
    "PoupeeAncienne": "poupée ancienne",
    "BougieChandelier": "bougie chandelier",
}


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestIdsAndLoader(unittest.TestCase):
    def test_ids_are_in_config(self):
        cfg = read("src", "shared", "Config.lua")
        for key, ident in IDS.items():
            self.assertRegex(cfg, rf"\b{key} = {ident},", key)

    def test_loader_installs_each_under_its_name(self):
        loader = read("src", "server", "ModelLoader.lua")
        for key, name in NAMES.items():
            self.assertRegex(loader, rf'\b{key} = "{name}"')

    def test_loader_is_safe(self):
        loader = read("src", "server", "ModelLoader.lua")
        self.assertIn("pcall", loader)  # InsertService:LoadAsset sous pcall
        self.assertIn("Timeout", loader)  # délai maximum
        self.assertIn("AssetLoad.install", loader)  # scripts retirés, modèle vide refusé
        self.assertIn("la pièce de remplacement reste", loader)  # repli annoncé

    def test_every_plan_names_a_loaded_model(self):
        fit = read("src", "shared", "ModelFit.lua")
        planned = set(re.findall(r'\["([^"]+)"\] = \{ mode', fit))
        self.assertEqual(planned, set(NAMES.values()))


class TestModelFit(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.M = self.lua.execute(to_lua54(read("src", "shared", "ModelFit.lua")))

    def t(self, *v):
        return self.lua.table_from(list(v))

    def vals(self, tbl):
        return [tbl[1], tbl[2]]

    def test_longest_mode_matches_the_replaced_object(self):
        # clé de 0,9 stud remplaçant une pièce de 0,8 : échelle 0,8 / 0,9
        self.assertAlmostEqual(self.M.scaleFor(self.t(0.2, 0.9, 0.1), self.t(0.8, 0.1, 0.5), "longest"), 0.8 / 0.9)
        # coffret de 2 studs de large remplaçant 1,6
        self.assertAlmostEqual(self.M.scaleFor(self.t(2, 1.2, 1.4), self.t(1.6, 0.8, 1.2), "longest"), 0.8)

    def test_height_mode_for_clock_doll_and_candle(self):
        self.assertAlmostEqual(self.M.scaleFor(self.t(0.9, 2.8, 0.6), self.t(0, 6.5, 0), "height"), 6.5 / 2.8)
        self.assertAlmostEqual(self.M.scaleFor(self.t(0.5, 1.4, 0.4), self.t(0, 1.6, 0), "height"), 1.6 / 1.4)
        self.assertAlmostEqual(self.M.scaleFor(self.t(0.4, 0.75, 0.4), self.t(0, 1.0, 0), "height"), 1.0 / 0.75)

    def test_fit_mode_never_exceeds_the_box(self):
        s = self.M.scaleFor(self.t(2, 1, 1), self.t(1, 1, 1), "fit")
        self.assertAlmostEqual(s, 0.5)

    def test_invalid_measurements_give_scale_one(self):
        for ext in ((0, 1, 1), (-1, 1, 1), (float("nan"), 1, 1), (float("inf"), 1, 1), (1, 1, 0)):
            self.assertEqual(self.M.scaleFor(self.t(*ext), self.t(1, 1, 1), "longest"), 1)
        self.assertEqual(self.M.scaleFor(self.t(1, 1, 1), self.t(0, 0, 0), "longest"), 1)

    def test_scale_is_clamped(self):
        self.assertEqual(self.M.scaleFor(self.t(0.0001, 0.0001, 0.0001), self.t(10, 10, 10), "longest"), 50)
        self.assertEqual(self.M.scaleFor(self.t(1000, 1000, 1000), self.t(1, 1, 1), "longest"), 0.02)

    def test_face_toward_snaps_to_the_room_interior(self):
        self.assertEqual(self.vals(self.M.faceToward(self.t(60, 1.1), self.t(60, 22))), [0, 1])
        self.assertEqual(self.vals(self.M.faceToward(self.t(1, 20), self.t(20, 22))), [1, 0])
        self.assertEqual(self.vals(self.M.faceToward(self.t(39, 20), self.t(20, 22))), [-1, 0])
        self.assertEqual(self.vals(self.M.faceToward(self.t(10, 43), self.t(10, 22))), [0, -1])
        self.assertEqual(self.vals(self.M.faceToward(self.t(5, 5), self.t(5, 5))), [0, 1])

    def test_yaw_turns_every_front_toward_every_direction(self):
        """Rotation Roblox autour de +Y de t : (x, z) devient (x cos t + z sin t, -x sin t + z cos t)."""
        dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for front, f in ((k, tuple(self.M.FRONT[k][i] for i in (1, 2))) for k in ("-Z", "+Z", "-X", "+X")):
            for want in dirs:
                t = self.M.yawFor(front, self.t(*want))
                x = f[0] * math.cos(t) + f[1] * math.sin(t)
                z = -f[0] * math.sin(t) + f[1] * math.cos(t)
                self.assertAlmostEqual(x, want[0], places=6, msg=f"{front}->{want}")
                self.assertAlmostEqual(z, want[1], places=6, msg=f"{front}->{want}")
                self.assertTrue(-math.pi < t <= math.pi + 1e-9)

    def test_coffret_lock_side_faces_the_player(self):
        # serrure en -Z : pour regarder vers +Z (intérieur d'une pièce au nord), demi-tour
        self.assertAlmostEqual(abs(self.M.yawFor("-Z", self.t(0, 1))), math.pi)
        self.assertAlmostEqual(self.M.yawFor("-Z", self.t(0, -1)), 0)


class TestMapAndFallbacks(unittest.TestCase):
    def test_game_pieces_are_fitted_with_fallback_kept(self):
        mb = read("src", "server", "MapBuilder.lua")
        for name in ("clé or", "coffret ancien", "horloge comtoise"):
            self.assertIn(f'fitModelOver(', mb)
            self.assertIn(f'"{name}"', mb)
        fit = mb[mb.index("local function fitModelOver"):mb.index("-- Repli lisible")] if "-- Repli lisible" in mb[mb.index("local function fitModelOver"):] else mb
        body = mb[mb.index("local function fitModelOver"):mb.index("local function buildHouse")]
        # la pièce procédurale ne devient invisible qu'après la pose réussie
        self.assertLess(body.index("clone.Parent = part"), body.index("part.Transparency = 1"))
        self.assertIn("pcall(function()", body)
        self.assertIn("CanCollide = false", body)
        self.assertIn("WeldConstraint", body)

    def test_decor_models_have_a_readable_fallback(self):
        mb = read("src", "server", "MapBuilder.lua")
        self.assertIn("buildFallbackDecor", mb)
        self.assertIn('"poupée ancienne"', mb)
        self.assertIn("if not fitModelOver(anchor, d.model) then", mb)

    def test_halo_surrounds_the_model(self):
        self.assertIn('part:FindFirstChildWhichIsA("Model") or part', read("src", "server", "Markers.lua"))

    def test_decor_models_sit_on_furniture_without_hiding_clues(self):
        data = gm.build()
        models = data["decor_models"]
        self.assertGreaterEqual(len([m for m in models if m["model"] == "poupée ancienne"]), 2)
        self.assertGreaterEqual(len([m for m in models if m["model"] == "bougie chandelier"]), 2)
        slots = []
        for pool in ("photo", "note", "bathkey", "decoy", "battery"):
            slots += [s["pos"] for s in data["slots"][pool]]
        for pool in data["slots"]["interactable"].values():
            slots += [s["pos"] for s in pool]
        slots += [p["pos"] for p in data["props"]]
        for m in models:
            x, y, z = m["pos"]
            items = [f for f in gm.FURNITURE[m["room"]] if f[0] == m["on"]]
            self.assertTrue(items, m)
            f = items[0]
            base_y = gm.BASE[gm.room_by_id(m["room"])[1]]
            self.assertTrue(f[1] <= x <= f[3] and f[2] <= z <= f[4], f"hors du meuble : {m}")
            self.assertAlmostEqual(y, base_y + f[5], places=2, msg=f"pas sur le dessus : {m}")
            for sx, sy, sz in slots:
                self.assertFalse(abs(sx - x) < 1.0 and abs(sz - z) < 1.0 and abs(sy - y) < 1.5, f"cache un emplacement ({sx},{sy},{sz}) : {m}")


class TestRealBuilderWithAndWithoutModels(unittest.TestCase):
    """Le vrai MapBuilder dans le faux Roblox : avec modèles présents, les trois pièces de jeu sont habillées et gardent
    leurs invites ; sans modèles ou avec un modèle défectueux, la pièce procédurale reste visible."""

    TEMPLATES = ("clé or", "coffret ancien", "horloge comtoise", "poupée ancienne", "bougie chandelier")

    def build(self, templates, broken=()):
        lua = robust.make_capturing(roles.GAME)
        lua.execute(
            """
            local ss = game:GetService("ServerStorage")
            local folder = Instance.new("Folder"); folder.Name = "Decor"; folder.Parent = ss
            """
        )
        for name in templates:
            defect = 'm.PivotTo = function() error("modèle défectueux") end' if name in broken else ""
            lua.execute(
                f"""
                local m = Instance.new("Model"); m.Name = "{name}"
                m._ext = Vector3.new(0.9, 2.8, 0.6)
                {defect}
                local p = Instance.new("Part"); p.Name = "Corps"; p.Parent = m
                m.Parent = game:GetService("ServerStorage"):FindFirstChild("Decor")
                """
            )
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(20)")
        return lua

    def piece(self, lua, tag):
        return lua.eval(
            f"""(function()
              for _, p in ipairs(game:GetService("CollectionService"):GetTagged("{tag}")) do return p end
            end)()"""
        )

    def test_without_models_pieces_stay_visible(self):
        lua = self.build(())
        for tag in ("Key", "Coffret", "Horloge"):
            part = self.piece(lua, tag)
            self.assertIsNotNone(part, tag)
            self.assertNotEqual(part.Transparency, 1, f"{tag} invisible sans modèle")
        self.assertEqual(robust.errors(lua), [])

    def test_with_models_pieces_are_dressed_and_keep_tag_and_size(self):
        lua = self.build(self.TEMPLATES)
        for tag in ("Key", "Coffret", "Horloge"):
            part = self.piece(lua, tag)
            self.assertEqual(part.Transparency, 1, f"{tag} : la pièce de jeu est invisible, le modèle la remplace")
            self.assertTrue(lua.eval("function(p) return p:FindFirstChildWhichIsA('Model') ~= nil or #p:GetChildren() > 0 end")(part), tag)
        self.assertEqual(robust.errors(lua), [])

    def test_a_defective_model_falls_back_without_crash(self):
        lua = self.build(self.TEMPLATES, broken=("coffret ancien",))
        coffret = self.piece(lua, "Coffret")
        self.assertNotEqual(coffret.Transparency, 1, "modèle défectueux : le coffret procédural reste visible")
        self.assertEqual(self.piece(lua, "Key").Transparency, 1, "les autres modèles se posent quand même")
        self.assertEqual(robust.errors(lua), [])

    def test_decor_has_fallback_pieces_when_models_are_missing(self):
        lua = self.build(())
        n = int(lua.eval(
            """(function()
              local c = 0
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.Name == "poupée ancienne" or d.Name == "bougie chandelier" then c = c + 1 end
              end
              return c
            end)()"""
        ))
        self.assertGreaterEqual(n, 4, "deux poupées et deux chandeliers de repli")


if __name__ == "__main__":
    unittest.main()

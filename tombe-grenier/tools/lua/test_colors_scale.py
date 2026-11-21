#!/usr/bin/env python3
"""Couleurs et échelle des modèles Blender : chaque suffixe `__RRGGBB` (avec ou sans `.001`) donne exactement la couleur
attendue, le métal et le néon sont réservés aux pièces explicites, aucune pièce n'est noire par défaut, et chaque modèle
est mis à l'échelle sur sa hauteur cible à ±10 % (mesure impossible : refus, l'objet de remplacement reste)."""
import os
import random
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


def load(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("typeof = type")
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestColors(unittest.TestCase):
    def setUp(self):
        self.lua, self.C = load("src/shared/ModelColor.lua")

    def rgb(self, name):
        r = self.C.parse(name)
        return None if r is None else tuple(int(v) for v in self.C.parse(name))

    def test_exact_colors_with_and_without_blender_suffix(self):
        cases = {
            "Bois__5A3E28": (0x5A, 0x3E, 0x28),  # armoire brune
            "Bois__5A3E28.001": (0x5A, 0x3E, 0x28),
            "Bois__5A3E28.012": (0x5A, 0x3E, 0x28),
            "Tissu__6A4A3A": (0x6A, 0x4A, 0x3A),  # canapé
            "Tissu__6A4A3A.001": (0x6A, 0x4A, 0x3A),
            "Corps__101010": (0x10, 0x10, 0x10),  # monstre noir
            "Masque__FFFFFF.003": (255, 255, 255),  # masque blanc
            "Yeux__FF0000": (255, 0, 0),
            "Bois__5a3e28": (0x5A, 0x3E, 0x28),  # minuscules acceptées
        }
        for name, expected in cases.items():
            self.assertEqual(self.rgb(name), expected, name)

    def test_missing_or_malformed_suffix_gives_no_color(self):
        for name in ("Bois", "Bois__5A3E2", "Bois__5A3E280", "Bois__GGGGGG", "Bois_5A3E28", "", None):
            self.assertIsNone(self.C.parse(name), name)

    def test_metal_only_for_explicit_metallic_parts(self):
        metal = ("Anneau__C8A020", "Tige__C8A020", "Dent__C8A020", "Dents__C8A020", "Serrure__C8A020", "Poignée__C8A020", "Poignee_2__C8A020", "Cadre_Doré__B8A060", "CadreDore__B8A060", "Laiton__B5A642", "Fer__404040", "Ferrure__404040", "Chrome__B0B0B0", "Pics__505050", "Anneau__C8A020.001")
        for name in metal:
            self.assertEqual(self.C.materialKey(name), "metal", name)
        plastic = ("Bois__5A3E28", "Cadre__5A4030", "Cadre_bois__5A4030", "Tissu__6A4A3A", "Fermeture__404040", "Accident__505050", "Ferme__404040", "Dentelle__EEEEEE", "Picnic__505050", "Pierre__6A6660", "Cercle__808080", "Corps__101010", "Masque__FFFFFF", "Email__D8D4C8", "")
        for name in plastic:
            self.assertEqual(self.C.materialKey(name), "plastic", name)

    def test_neon_only_for_flame_eyes_and_lantern(self):
        for name in ("Flamme__FFB040", "Yeux__FF0000", "Oeil__FF0000", "Œil__FF0000", "Lanterne__FFD070", "Flamme__FFB040.001"):
            self.assertEqual(self.C.materialKey(name), "neon", name)
        for name in ("Lueur__FFFFFF", "Lampe__FFFFFF", "Abatjour__C8B070", "Bougie__EDE0C8", "Neonard__FFFFFF"):
            self.assertNotEqual(self.C.materialKey(name), "neon", name)

    def test_glass(self):
        self.assertEqual(self.C.materialKey("Vitre__A8C0C8"), "glass")
        self.assertEqual(self.C.materialKey("Verre__E8D8A8"), "glass")

    def test_dark_default_detection(self):
        self.assertTrue(self.C.isTooDark(0, 0, 0))
        self.assertTrue(self.C.isTooDark(10, 12, 9))
        self.assertFalse(self.C.isTooDark(90, 60, 40))
        self.assertFalse(self.C.isTooDark(31, 31, 31))


class TestPaintRuntime(unittest.TestCase):
    """Le vrai ModelColor.paint dans le faux Roblox : couleur exacte, Reflectance 0, jamais de noir par défaut."""

    def setUp(self):
        import test_spawn_map as base

        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().READ = lambda p: to_lua54(base.read(*p.split("/")))
        self.lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(base.ROOT, *p.split("/")))
        self.lua.execute(base.STUB)
        self.lua.execute("Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }")
        self.lua.execute(
            """
            local realIsA = nil
            C = require({ __path = "src/shared/ModelColor.lua" })
            function part(model, name, color)
              local p = Instance.new("Part"); p.Name = name; p.Color = color or Color3.fromRGB(163, 162, 165); p.Material = Enum.Material.Metal; p.Reflectance = 0.7
              p.Parent = model
              return p
            end
            """
        )

    def run_case(self, parts):
        self.lua.execute("MODEL = Instance.new('Model')")
        for name, color in parts:
            c = "Color3.fromRGB(%d, %d, %d)" % color if color else "nil"
            self.lua.execute("part(MODEL, %r, %s)" % (name, c))
        self.lua.execute("PAINTED = C.paint(MODEL)")
        out = {}
        for name, _ in parts:
            out[name] = self.lua.eval("MODEL:FindFirstChild(%r)" % name)
        return out

    def test_painted_parts_have_exact_color_matching_material_and_no_reflectance(self):
        parts = self.run_case([("Bois__5A3E28.001", None), ("Anneau__C8A020", None), ("Flamme__FFB040", None), ("Tissu__6A4A3A", None)])
        bois = parts["Bois__5A3E28.001"]
        self.assertEqual((round(bois.Color.R * 255), round(bois.Color.G * 255), round(bois.Color.B * 255)), (0x5A, 0x3E, 0x28))
        self.assertEqual(bois.Material, "Material.Plastic")
        for p in parts.values():
            self.assertEqual(p.Reflectance, 0)
        self.assertEqual(parts["Anneau__C8A020"].Material, "Material.Metal")
        self.assertEqual(parts["Flamme__FFB040"].Material, "Material.Neon")
        self.assertEqual(parts["Tissu__6A4A3A"].Material, "Material.Plastic")

    def test_black_is_allowed_only_when_the_suffix_says_so(self):
        parts = self.run_case([("Corps__101010", None), ("SansSuffixe", (0, 0, 0)), ("AutreSansSuffixe", (12, 10, 14))])
        corps = parts["Corps__101010"]
        self.assertEqual(round(corps.Color.R * 255), 0x10)
        for name in ("SansSuffixe", "AutreSansSuffixe"):
            c = parts[name].Color
            self.assertGreater((c.R + c.G + c.B) / 3 * 255, 100, f"{name} ne doit pas rester noire")
            self.assertEqual(parts[name].Material, "Material.Plastic", "le métal importé par défaut est retiré")

    def test_part_without_suffix_keeps_a_normal_color(self):
        parts = self.run_case([("Pied", (90, 60, 40))])
        c = parts["Pied"].Color
        self.assertEqual((round(c.R * 255), round(c.G * 255), round(c.B * 255)), (90, 60, 40))


class TestScale(unittest.TestCase):
    TARGETS = {
        "armoire gothique": 8,
        "horloge comtoise": 8.5,
        "commode ancienne": 3.2,
        "lit double ancien": 5,
        "cheminée gothique": 7,
    }

    def setUp(self):
        self.lua, self.M = load("src/shared/ModelFit.lua")

    def t(self, *v):
        return self.lua.table_from(list(v))

    def height_after(self, name, ext, front="-Z", facing=(0, 1)):
        r = self.M.solve(name, self.t(*ext), self.t(2, 2, 2), self.t(*facing), None)
        return None if r is None else r.size[2]

    def test_table_has_the_requested_heights(self):
        for name, target in self.TARGETS.items():
            self.assertEqual(self.M.HEIGHTS[name], target, name)
        self.assertGreaterEqual(self.M.HEIGHTS["ombre rampante"], 5.5)

    def test_every_model_in_the_table_lands_within_ten_percent_of_its_height(self):
        rng = random.Random(7)
        names = [k for k in self.M.HEIGHTS.keys()]
        self.assertGreaterEqual(len(names), 30)
        for name in names:
            target = self.M.HEIGHTS[name]
            for _ in range(20):
                ext = (rng.uniform(0.2, 40), rng.uniform(0.2, 40), rng.uniform(0.2, 40))  # une mesure quelconque
                facing = rng.choice(((0, 1), (0, -1), (1, 0), (-1, 0)))
                h = self.height_after(name, ext, facing=facing)
                self.assertIsNotNone(h, name)
                self.assertAlmostEqual(h, target, delta=target * 0.1, msg=f"{name} {ext}")

    def test_scale_uses_height_even_when_the_import_is_huge_or_tiny(self):
        for ext in ((300, 1000, 400), (0.01, 0.03, 0.02), (1, 1, 1)):
            h = self.height_after("armoire gothique", ext)
            if ext[1] in (1000, 0.03):
                self.assertTrue(h is None or abs(h - 8) <= 0.8 or h > 0, ext)
            else:
                self.assertAlmostEqual(h, 8, delta=0.8)

    def test_failed_measurement_is_refused(self):
        for bad in ((0, 0, 0), (float("nan"), 1, 1), (1, float("inf"), 1), (1, -2, 1), (1, 0, 1)):
            self.assertIsNone(self.height_after("armoire gothique", bad), bad)
            self.assertIsNone(self.height_after("modèle inconnu", bad), bad)
        self.assertIsNone(self.M.scaleOf("armoire gothique", None, self.t(1, 1, 1), "fit"))

    def test_place_and_monster_refuse_when_the_measure_fails(self):
        place = read("src", "server", "ModelPlace.lua")
        self.assertIn("mesure impossible", place)
        self.assertIn("if not sol then", place)
        visual = read("src", "server", "MonsterVisual.lua")
        self.assertIn("ModelFit.scaleOf(MonsterVisual.MODEL", visual)
        self.assertIn("mesure impossible", visual)

    def test_clock_plan_uses_the_table_height(self):
        self.assertAlmostEqual(self.M.PLANS["horloge comtoise"].height, 8.5)


if __name__ == "__main__":
    unittest.main()

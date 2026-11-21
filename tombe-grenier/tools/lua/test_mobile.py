#!/usr/bin/env python3
"""Qualité mobile : budgets de Parts, lumières, particules, halos et tailles minimales d'interface."""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as base  # noqa: E402

ROOT = base.ROOT
MAX_PARTS_BARE_MAP = 1200  # carte seule (sans modèles) : les modèles ajoutent leurs pièces, plafonnées par ACCESSORIES
MAX_POINT_LIGHTS_BUILT = 60
MIN_TEXT = 14  # px de texte lisible sur téléphone
MIN_TOUCH = 44  # px, norme tactile


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


class TestMobileBudgets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base.TestRealMap.setUpClass()
        cls.root = base.TestRealMap.root
        cls.items = list(cls.root.GetDescendants(cls.root).values())

    def count(self, *names):
        return sum(1 for d in self.items if d.ClassName in names)

    def test_parts_of_the_bare_map(self):
        self.assertLessEqual(self.count("Part", "SpawnLocation", "WedgePart", "MeshPart"), MAX_PARTS_BARE_MAP)

    def test_lights_built_and_active_budget(self):
        self.assertLessEqual(self.count("PointLight", "SpotLight", "SurfaceLight"), MAX_POINT_LIGHTS_BUILT)
        budget = read("src", "shared", "RoomBudget.lua")
        self.assertRegex(budget, r"bas = \{ lights = [1-6],")
        self.assertRegex(budget, r"moyen = \{ lights = [1-9],")  # au plus 9 lueurs actives en qualité moyenne

    def test_halos_stay_under_roblox_limit(self):
        markers = read("src", "shared", "Markers.lua")
        limit = int(re.search(r"MAX_HALOS = (\d+)", markers).group(1))
        self.assertLessEqual(limit, 28)  # Roblox n'affiche qu'environ 31 halos

    def test_particles_are_light(self):
        cfg = read("src", "shared", "Config.lua")
        self.assertLessEqual(int(re.search(r"DustRate = (\d+)", cfg).group(1)), 4)
        atmosphere = read("src", "server", "Atmosphere.lua")
        self.assertEqual(atmosphere.count('Instance.new("ParticleEmitter")'), 1)  # un seul modèle d'émetteur, un par pièce
        self.assertEqual(self.count("ParticleEmitter"), 0)  # aucun émetteur dans la carte elle-même

    def test_accessories_are_capped(self):
        src = read("src", "server", "MapBuilder.lua")
        block = src[src.index("MapBuilder.ACCESSORIES = {") : src.index("local function placeAccessories")]
        self.assertLessEqual(block.count('{ "'), 40)

    def test_late_texture_budget(self):
        # Après la pose des textures (décals simulés), le nombre de Texture reste borné pour le mobile
        sys.path.insert(0, HERE)
        import test_boot_async as boot

        lua = boot.server(boot.TestLateDressing.STUB)
        lua.execute("SWALLOW = true; advance(40)")
        n = int(lua.execute('local k = 0 for _, d in ipairs(workspace.TombeMap:GetDescendants()) do if d.ClassName == "Texture" then k = k + 1 end end return k'))
        self.assertLessEqual(n, 450)
        self.assertGreater(n, 20)

    def test_trims_are_capped(self):
        src = read("src", "server", "MapBuilder.lua")
        self.assertLessEqual(int(re.search(r"TRIM_MAX = (\d+)", src).group(1)), 160)
        self.assertLessEqual(len(re.search(r"TRIM_ROOMS = \{([^}]*)\}", src).group(1).split(",")), 5)

    def test_loader_limits(self):
        cfg = read("src", "shared", "Config.lua")
        self.assertLessEqual(int(re.search(r"GlobalTimeout = (\d+)", cfg).group(1)), 12)
        self.assertLessEqual(int(re.search(r"Workers = (\d+)", cfg).group(1)), 10)


class TestMobileUi(unittest.TestCase):
    def setUp(self):
        self.client = read("src", "client", "init.client.lua")

    def test_minimum_text_size(self):
        for m in re.finditer(r"MinTextSize = (\d+)", self.client):
            self.assertGreaterEqual(int(m.group(1)), MIN_TEXT)
        for m in re.finditer(r"\bTextSize = (\d+)", self.client):
            self.assertGreaterEqual(int(m.group(1)), MIN_TEXT)

    def test_touch_buttons_scale_with_the_screen_and_never_below_44px(self):
        # Les mesures réelles (4 tailles d'écran) sont dans test_layout.py ; ici, la règle de calcul
        m = re.search(r"local scale = math\.max\(uiScaleValue\(\), ([\d.]+)\)", self.client)
        self.assertIsNotNone(m)
        self.assertGreaterEqual(54 * float(m.group(1)), MIN_TOUCH)
        self.assertGreaterEqual(110 * float(m.group(1)), MIN_TOUCH)

    def test_buttons_use_two_columns_for_landscape_phones(self):
        self.assertIn("column", self.client)


if __name__ == "__main__":
    unittest.main()

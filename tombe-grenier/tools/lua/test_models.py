#!/usr/bin/env python3
"""Modèles Blender (clé, coffret, horloge, poupée, bougie) : identifiants, chargement, échelle, orientation, repli,
halo sur le modèle, placement sans gêne. Le vrai MapBuilder tourne dans le faux Roblox avec et sans modèles.
"""

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
    "CleOr": 71927105620016,
    "CoffretAncien": 135334916682974,
    "HorlogeComtoise": 127086141131615,
    "PoupeeAncienne": 137798724739586,
    "BougieChandelier": 91265848520746,
    "Armoire": 88627357314275,
    "Commode": 116600254156058,
    "Berceau": 73900289399193,
    "ChevalBascule": 74320735179635,
    "MiroirAncien": 134489196998276,
    "Malle": 94690600145377,
    "Statuette": 107399380407320,
    "CadrePhoto": 86021806351640,
    "OmbreRampante": 101328489566505,
}
NAMES = {
    "CleOr": "clé or",
    "CoffretAncien": "coffret ancien",
    "HorlogeComtoise": "horloge comtoise",
    "PoupeeAncienne": "poupée ancienne",
    "BougieChandelier": "bougie chandelier",
    "Armoire": "armoire gothique",
    "Commode": "commode ancienne",
    "Berceau": "berceau",
    "ChevalBascule": "cheval à bascule",
    "MiroirAncien": "miroir sur pied",
    "Malle": "malle",
    "Statuette": "statuette",
    "CadrePhoto": "cadre photo",
    "OmbreRampante": "ombre rampante",
    "Cheminee": "cheminée gothique",
    "Escalier": "escalier Blender",
    "Etagere": "étagère livres",
    "Gramophone": "gramophone ancien",
    "Lustre": "lustre",
    "MachineCoudre": "machine à coudre",
    "PorteAncienne": "porte ancienne",
    "BuffetBas": "buffet bas",
    "PlacardHaut": "placard haut",
    "FauteuilOsier": "fauteuil osier",
    "TableRondePied": "table ronde pied",
    "ChaiseAccoudoirs": "chaise accoudoirs",
    "Suspension": "suspension",
    "Chandeliers": "chandeliers",
    "RenardStatuette": "renard statuette",
    "Livres": "livres",
    "TabouretBar": "tabouret de bar",
    "GueridonLampe": "guéridon lampe",
    "CageEnfant": "cage de l'enfant",
    "MatelasEnfant": "matelas de l'enfant",
    "ChaineCave": "chaîne de cave",
    "Chevet": "chevet",
    "TableBasse": "table basse",
    "MeubleTV": "meuble TV",
    "PlanTravail": "plan de travail",
    "Penderie": "penderie",
    "Gueridon": "guéridon",
    "Banc": "banc",
    "Bidon": "bidon",
    "CoffreCave": "coffre de cave",
    "Buffet": "buffet",
    "TapisRond": "tapis rond",
    "Telephone": "téléphone ancien",
    "ToileAraignee": "toile d'araignée",
    "Valise": "valise",
    "VfxCercle": "vfx cercle runique",
    "VfxAiles": "vfx ailes",
    "VfxHalo": "vfx halo",
    "VfxRayons": "vfx rayons",
    "VfxEtoile": "vfx etoile",
    "VfxCristaux": "vfx cristaux",
    "VfxOnde": "vfx onde",
    "VfxTorii": "vfx torii",
    "VfxSpirale": "vfx spirale",
    "VfxPilier": "vfx pilier lumiere",
    "VfxEtincelles": "vfx etincelles",
    "VfxCone": "vfx cone lumiere",
    "VfxBouclier": "vfx bouclier",
    "Plinthe": "plinthe bois",
    "Moulure": "moulure plafond",
    "FenetreRideaux": "fenêtre rideaux",
    "FenetreRonde": "fenêtre ronde",
    "Balustrade": "balustrade d'escalier",
    "Marche": "marche usée",
    "Encadrement": "encadrement de porte",
    "Applique": "applique murale",
    "Soupirail": "soupirail",
    "Radiateur": "radiateur fonte",
    "Chaise": "chaise ancienne",
    "TableSalle": "table de salle",
    "EtagereMurale": "étagère murale",
    "Caisses": "caisses en bois",
    "PiedLit": "pied de lit",
    "PlanteInterieur": "plante d'intérieur",
    "Console": "console d'entrée",
    "Baignoire": "baignoire sur pieds",
    "Lavabo": "lavabo",
    "WC": "WC",
    "ArmoireToilette": "armoire de toilette",
    "Barrique": "barrique",
    "Cuve": "cuve",
    "Canape": "canapé ancien",
    "Fauteuil": "fauteuil ancien",
    "Cuisiniere": "cuisinière ancienne",
    "Frigo": "frigo ancien",
    "Cercueil": "cercueil",
    "CoffreVerrouille": "coffre verrouillé",
    "CoffreJouets": "coffre à jouets",
    "Vitrine": "vitrine",
    "Portemanteau": "portemanteau",
    "Lampadaire": "lampadaire ancien",
    "LitDouble": "lit double ancien",
    "Etabli": "établi",
}
OLD_IDS = (
    128263149076283,
    80816541343966,
    121788657121996,
    114751010380157,
    118027923730609,
)


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestIdsAndLoader(unittest.TestCase):
    def test_ids_are_in_config(self):
        cfg = read("src", "shared", "Config.lua")
        for key, ident in IDS.items():
            self.assertRegex(cfg, rf"\b{key} = {ident},", key)

    def test_previous_single_block_ids_are_gone(self):
        cfg = read("src", "shared", "Config.lua")
        for old in OLD_IDS:
            self.assertNotIn(str(old), cfg)

    def test_loader_installs_each_under_its_name(self):
        loader = read("src", "server", "ModelLoader.lua")
        for key, name in NAMES.items():
            self.assertRegex(loader, rf'\b{key} = "{name}"')

    def test_loader_is_safe(self):
        loader = read("src", "server", "ModelLoader.lua")
        self.assertIn("pcall", loader)  # InsertService:LoadAsset sous pcall
        self.assertIn("Timeout", loader)  # délai maximum
        self.assertIn(
            "AssetLoad.install", loader
        )  # scripts retirés, modèle vide refusé
        self.assertIn("la pièce de remplacement reste", loader)  # repli annoncé

    def test_every_plan_names_a_loaded_model(self):
        fit = read("src", "shared", "ModelFit.lua")
        planned = set(re.findall(r'\["([^"]+)"\] = \{ mode', fit))
        self.assertEqual(
            planned, {n for n in NAMES.values() if not n.startswith("vfx ")}
        )  # un plan par modèle posé (les effets n'en ont pas)


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
        self.assertAlmostEqual(
            self.M.scaleFor(self.t(0.2, 0.9, 0.1), self.t(0.8, 0.1, 0.5), "longest"),
            0.8 / 0.9,
        )
        # coffret de 2 studs de large remplaçant 1,6
        self.assertAlmostEqual(
            self.M.scaleFor(self.t(2, 1.2, 1.4), self.t(1.6, 0.8, 1.2), "longest"), 0.8
        )

    def test_height_mode_for_clock_doll_and_candle(self):
        self.assertAlmostEqual(
            self.M.scaleFor(self.t(0.9, 2.8, 0.6), self.t(0, 6.5, 0), "height"),
            6.5 / 2.8,
        )
        self.assertAlmostEqual(
            self.M.scaleFor(self.t(0.5, 1.4, 0.4), self.t(0, 1.6, 0), "height"),
            1.6 / 1.4,
        )
        self.assertAlmostEqual(
            self.M.scaleFor(self.t(0.4, 0.75, 0.4), self.t(0, 1.0, 0), "height"),
            1.0 / 0.75,
        )

    def test_fit_mode_never_exceeds_the_box(self):
        s = self.M.scaleFor(self.t(2, 1, 1), self.t(1, 1, 1), "fit")
        self.assertAlmostEqual(s, 0.5)

    def test_invalid_measurements_give_scale_one(self):
        for ext in (
            (0, 1, 1),
            (-1, 1, 1),
            (float("nan"), 1, 1),
            (float("inf"), 1, 1),
            (1, 1, 0),
        ):
            self.assertEqual(
                self.M.scaleFor(self.t(*ext), self.t(1, 1, 1), "longest"), 1
            )
        self.assertEqual(
            self.M.scaleFor(self.t(1, 1, 1), self.t(0, 0, 0), "longest"), 1
        )

    def test_scale_is_clamped(self):
        self.assertEqual(
            self.M.scaleFor(
                self.t(0.0001, 0.0001, 0.0001), self.t(10, 10, 10), "longest"
            ),
            50,
        )
        self.assertEqual(
            self.M.scaleFor(self.t(1000, 1000, 1000), self.t(1, 1, 1), "longest"), 0.02
        )

    def test_face_toward_snaps_to_the_room_interior(self):
        self.assertEqual(
            self.vals(self.M.faceToward(self.t(60, 1.1), self.t(60, 22))), [0, 1]
        )
        self.assertEqual(
            self.vals(self.M.faceToward(self.t(1, 20), self.t(20, 22))), [1, 0]
        )
        self.assertEqual(
            self.vals(self.M.faceToward(self.t(39, 20), self.t(20, 22))), [-1, 0]
        )
        self.assertEqual(
            self.vals(self.M.faceToward(self.t(10, 43), self.t(10, 22))), [0, -1]
        )
        self.assertEqual(
            self.vals(self.M.faceToward(self.t(5, 5), self.t(5, 5))), [0, 1]
        )

    def test_yaw_turns_every_front_toward_every_direction(self):
        """Rotation Roblox autour de +Y de t : (x, z) devient (x cos t + z sin t, -x sin t + z cos t)."""
        dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for front, f in (
            (k, tuple(self.M.FRONT[k][i] for i in (1, 2)))
            for k in ("-Z", "+Z", "-X", "+X")
        ):
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
        for name in (
            "clé or",
            "coffret ancien",
            "horloge comtoise",
            "statuette",
            "cadre photo",
        ):
            self.assertIn(f"fitModelOver(", mb)
            self.assertIn(f'"{name}"', mb)
        body = mb[
            mb.index("local function fitModelOver") : mb.index("-- Repli lisible")
        ]
        # la pièce procédurale ne devient invisible qu'après la pose réussie
        self.assertLess(
            body.index("if not model then"), body.index("part.Transparency = 1")
        )
        place = read("src", "server", "ModelPlace.lua")
        self.assertIn("pcall(function()", place)
        self.assertIn("CanCollide = false", place)
        self.assertIn("WeldConstraint", place)
        self.assertIn("GetExtentsSize", place)

    def test_decor_models_have_a_readable_fallback(self):
        mb = read("src", "server", "MapBuilder.lua")
        self.assertIn("buildFallbackDecor", mb)
        self.assertIn('"poupée ancienne"', mb)
        self.assertIn("if not fitModelOver(anchor, d.model) then", mb)

    def test_halo_surrounds_the_model(self):
        self.assertIn(
            'part:FindFirstChildWhichIsA("Model") or part',
            read("src", "server", "Markers.lua"),
        )

    def test_decor_models_sit_on_furniture_without_hiding_clues(self):
        data = gm.build()
        models = data["decor_models"]
        self.assertGreaterEqual(
            len([m for m in models if m["model"] == "poupée ancienne"]), 2
        )
        self.assertGreaterEqual(
            len([m for m in models if m["model"] == "bougie chandelier"]), 2
        )
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
            self.assertTrue(
                f[1] <= x <= f[3] and f[2] <= z <= f[4], f"hors du meuble : {m}"
            )
            self.assertAlmostEqual(
                y, base_y + f[5], places=2, msg=f"pas sur le dessus : {m}"
            )
            for sx, sy, sz in slots:
                self.assertFalse(
                    abs(sx - x) < 1.0 and abs(sz - z) < 1.0 and abs(sy - y) < 1.5,
                    f"cache un emplacement ({sx},{sy},{sz}) : {m}",
                )


class TestModelColor(unittest.TestCase):
    def setUp(self):
        self.lua, self.C = pure_lua("src/shared/ModelColor.lua")

    def parse3(self, name):
        out = self.lua.eval(
            "function(m, n) local r, g, b = m.parse(n) return { r, g, b } end"
        )(self.C, name)
        return None if out[1] is None else (out[1], out[2], out[3])

    def test_hex_suffix_is_read(self):
        self.assertEqual(self.parse3("Anneau__C8A020"), (0xC8, 0xA0, 0x20))
        self.assertEqual(self.parse3("Corps__000000"), (0, 0, 0))
        self.assertEqual(self.parse3("Masque__ffffff"), (255, 255, 255))
        self.assertEqual(self.parse3("Robe__B01020"), (0xB0, 0x10, 0x20))

    def test_blender_duplicate_suffix_is_tolerated(self):
        self.assertEqual(self.parse3("Tige__C8A020.001"), (0xC8, 0xA0, 0x20))
        self.assertEqual(self.parse3("Tige__C8A020.12"), (0xC8, 0xA0, 0x20))

    def test_missing_or_malformed_suffix_keeps_the_current_color(self):
        for name in (
            "Anneau",
            "Anneau__",
            "Anneau__C8A02",
            "Anneau__C8A0200",
            "Anneau__GGGGGG",
            "Anneau_C8A020",
            "__C8A020x",
            "",
            None,
            12,
        ):
            self.assertIsNone(self.parse3(name), name)

    def test_material_by_name(self):
        m = self.C.materialKey
        for name in (
            "Anneau__C8A020",
            "Tige__C8A020",
            "Dent__C8A020",
            "Serrure__C8A020",
            "Poignee__C8A020",
            "Poignée__C8A020",
            "Cadre_Dore__C8A020",
            "Laiton__B5A642",
            "Chrome__B0B0B0",
            "Fer__404040",
            "Pics__505050",
        ):
            self.assertEqual(m(name), "metal", name)
        for name in ("Flamme__FFB040", "Yeux__FF0000", "Oeil__FF0000", "Œil"):
            self.assertIn(m(name), ("neon", "plastic"), name)
        self.assertEqual(m("Flamme__FFB040"), "neon")
        self.assertEqual(m("Yeux__FF0000"), "neon")
        self.assertEqual(m("Verre__88AACC"), "glass")
        self.assertEqual(m("Corps__202020"), "plastic")
        self.assertEqual(m(None), "plastic")

    def test_paint_applies_color_material_and_removes_collision(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
        lua.globals().EXISTS = lambda p: os.path.exists(
            os.path.join(base.ROOT, *p.split("/"))
        )
        lua.execute(base.STUB)
        result = lua.eval("""(function()
              local C = require({ __path = "src/shared/ModelColor.lua" })
              local model = Instance.new("Model")
              local function part(name, collide)
                local p = Instance.new("Part"); p.Name = name; p.CanCollide = collide; p.Parent = model
                p.Color = { R = 9, G = 9, B = 9 }
                return p
              end
              local a = part("Anneau__C8A020", true)
              local b = part("Corps__101010.001", true)
              local c = part("SansCouleur", true)
              local n = C.paint(model)
              return { n, a.Color.R, a.Color.G, a.Color.B, tostring(a.Material), tostring(b.Material), a.CanCollide, b.CanCollide, a.Anchored, c.Color.R, c.CanCollide }
            end)()""")
        n, r, g, b, mat_a, mat_b, coll_a, coll_b, anch, untouched, coll_c = [
            result[i] for i in range(1, 12)
        ]
        self.assertEqual(n, 2)
        self.assertEqual((r, g, b), (0xC8, 0xA0, 0x20))
        self.assertTrue(str(mat_a).endswith("Metal"), mat_a)
        self.assertTrue(str(mat_b).endswith("Plastic"), mat_b)
        self.assertFalse(coll_a)
        self.assertFalse(coll_b)
        self.assertTrue(anch)
        self.assertEqual(
            untouched, 9, "sans suffixe : la couleur actuelle est conservée"
        )
        self.assertTrue(coll_c, "sans suffixe : la pièce n'est pas touchée")

    def test_paint_never_raises(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
        lua.globals().EXISTS = lambda p: os.path.exists(
            os.path.join(base.ROOT, *p.split("/"))
        )
        lua.execute(base.STUB)
        n = lua.eval("""(function()
              local C = require({ __path = "src/shared/ModelColor.lua" })
              return C.paint(setmetatable({}, { __index = function() error("boom") end }))
            end)()""")
        self.assertEqual(n, 0)

    def test_loader_paints_every_loaded_container(self):
        loader = read("src", "server", "ModelLoader.lua")
        self.assertIn("ModelColor.paint", loader)
        self.assertIn("AssetLoad.install", loader)
        self.assertIn(
            "return loadAndPaint(", loader
        )  # chaque chargement parallèle passe par la peinture
        self.assertIn("ModelLoader.loadWithTimeout = loadAndPaint", loader)


def pure_lua(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestSolveAndScale(unittest.TestCase):
    """Échelle par extents pour chaque modèle de la bibliothèque, aux tailles Blender annoncées."""

    SIZES = {  # hauteur annoncée -> mesures plausibles (x, y, z)
        "armoire gothique": (1.4, 2.2, 0.8),
        "commode ancienne": (1.6, 1.0, 0.7),
        "berceau": (1.2, 1.0, 0.7),
        "cheval à bascule": (1.8, 1.3, 0.6),
        "miroir sur pied": (0.9, 2.0, 0.5),
        "malle": (1.3, 0.9, 0.8),
        "statuette": (0.5, 1.2, 0.5),
        "cadre photo": (0.1, 1.0, 0.8),
    }

    def setUp(self):
        self.lua, self.M = pure_lua("src/shared/ModelFit.lua")

    def t(self, *v):
        return self.lua.table_from(list(v))

    def solve(self, name, ext, target, facing):
        r = self.M.solve(name, self.t(*ext), self.t(*target), self.t(*facing), None)
        return r.scale, r.yaw, (r.size[1], r.size[2], r.size[3])

    def test_furniture_height_follows_the_height_table_and_footprint_stays_close_to_its_box(
        self,
    ):
        boxes = {
            "armoire gothique": (11, 8, 4),
            "commode ancienne": (8, 3, 4),
            "berceau": (8, 3, 8),
            "cheval à bascule": (8, 3, 6),
            "miroir sur pied": (2, 6, 2),
            "malle": (4, 3, 6),
        }
        for name, box in boxes.items():
            for facing in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                scale, yaw, size = self.solve(name, self.SIZES[name], box, facing)
                target = self.M.HEIGHTS[name]
                self.assertAlmostEqual(size[1], target, delta=target * 0.1, msg=name)
                for dim, limit in zip((size[0], size[2]), (box[0], box[2])):
                    self.assertLessEqual(
                        dim,
                        limit * 1.4 + 1e-6,
                        f"{name} {facing} déborde trop de sa boîte : {size} dans {box}",
                    )
                self.assertGreater(scale, 0.02)

    def test_quarter_turn_swaps_the_footprint_before_scaling(self):
        # un meuble large (2 x 1) dans une boîte étroite en x (1 x 2) : tourné d'un quart de tour il tient plein format
        box = (1, 5, 2)
        s_front, _, _ = self.solve(
            "inconnu", (2, 1, 1), box, (0, -1)
        )  # face -Z conservée : largeur 2 en x
        s_turned, _, _ = self.solve(
            "inconnu", (2, 1, 1), box, (1, 0)
        )  # quart de tour : largeur 2 en z
        self.assertGreater(s_turned, s_front)

    def test_statue_scales_to_the_game_piece_height(self):
        scale, _, size = self.solve(
            "statuette", self.SIZES["statuette"], (1, 2.2, 1), (0, 1)
        )
        self.assertAlmostEqual(size[1], 2.2, places=6)
        self.assertAlmostEqual(scale, 2.2 / 1.2, places=6)

    def test_photo_frame_matches_the_replaced_photo(self):
        scale, _, size = self.solve(
            "cadre photo", self.SIZES["cadre photo"], (1.4, 0.1, 1.0), (0, 1)
        )
        self.assertAlmostEqual(max(size), 1.4, places=6)

    def test_monster_height_comes_from_the_height_table(self):
        scale, _, size = self.solve(
            "ombre rampante", (1.0, 2.5, 0.8), (0, 5.5, 0), (0, 1)
        )
        self.assertAlmostEqual(size[1], self.M.HEIGHTS["ombre rampante"], places=6)

    def test_every_decor_model_has_a_plan_and_unknown_names_fit(self):
        r = self.M.solve(
            "inconnu", self.t(1, 1, 1), self.t(2, 2, 2), self.t(0, 1), None
        )
        self.assertAlmostEqual(r.scale, 2.0)

    def test_front_override_changes_the_yaw(self):
        a = self.M.solve(
            "armoire gothique", self.t(1, 2, 1), self.t(5, 5, 5), self.t(0, 1), None
        ).yaw
        b = self.M.solve(
            "armoire gothique", self.t(1, 2, 1), self.t(5, 5, 5), self.t(0, 1), "+Z"
        ).yaw
        self.assertNotAlmostEqual(a, b)
        self.assertAlmostEqual(b, 0)


class TestMonsterSway(unittest.TestCase):
    def setUp(self):
        self.lua, self.S = pure_lua("src/shared/MonsterSway.lua")

    def test_poses_are_bounded_and_periodic(self):
        for gait in ("immobile", "marche", "course"):
            g = self.S.GAITS[gait]
            for i in range(200):
                t = i * 0.037
                p = self.S.pose(gait, t)
                self.assertLessEqual(abs(p.roll), math.radians(g.roll) + 1e-9)
                self.assertGreaterEqual(p.bob, 0)
                self.assertLessEqual(p.bob, g.bob + 1e-9)
                self.assertAlmostEqual(p.pitch, math.radians(g.pitch))
                p2 = self.S.pose(gait, t + 1 / g.freq)
                self.assertAlmostEqual(p.roll, p2.roll, places=6)

    def test_running_is_more_inclined_and_faster_than_walking(self):
        g = self.S.GAITS
        self.assertGreater(g.course.pitch, g.marche.pitch)
        self.assertGreater(g.marche.pitch, g.immobile.pitch)
        self.assertGreater(g.course.freq, g.marche.freq)
        self.assertGreater(g.course.roll, g.marche.roll)

    def test_unknown_gait_falls_back_to_idle(self):
        a = self.S.pose("inconnu", 1.3)
        b = self.S.pose("immobile", 1.3)
        self.assertAlmostEqual(a.roll, b.roll)

    def test_visual_keeps_the_rig_logic_and_falls_back(self):
        v = read("src", "server", "MonsterVisual.lua")
        self.assertIn(
            "d.Transparency = 1", v
        )  # le rig devient invisible, sa hitbox reste
        self.assertIn(
            "CanCollide = false", v
        )  # la silhouette n'ajoute aucune collision
        self.assertIn("pcall(function()", v)
        self.assertIn("rig conservé", v)
        ai = read("src", "server", "MonsterAI.lua")
        self.assertIn("MonsterVisual.attach(model, root)", ai)
        self.assertIn("m.locoKey = key", ai)


class TestRealBuilderWithAndWithoutModels(unittest.TestCase):
    """Le vrai MapBuilder dans le faux Roblox : avec modèles présents, les trois pièces de jeu sont habillées et gardent
    leurs invites ; sans modèles ou avec un modèle défectueux, la pièce procédurale reste visible.
    """

    TEMPLATES = (
        "clé or",
        "coffret ancien",
        "horloge comtoise",
        "poupée ancienne",
        "bougie chandelier",
    )
    LIBRARY = TEMPLATES + (
        "armoire gothique",
        "commode ancienne",
        "berceau",
        "cheval à bascule",
        "miroir sur pied",
        "malle",
        "statuette",
        "cadre photo",
        "ombre rampante",
    )

    def build(self, templates, broken=(), play=False):
        lua = robust.make_capturing(roles.GAME)
        lua.execute("""
            local ss = game:GetService("ServerStorage")
            local folder = Instance.new("Folder"); folder.Name = "Decor"; folder.Parent = ss
            """)
        for name in templates:
            defect = (
                'm.PivotTo = function() error("modèle défectueux") end'
                if name in broken
                else ""
            )
            lua.execute(f"""
                local m = Instance.new("Model"); m.Name = "{name}"
                m._ext = Vector3.new(0.9, 2.8, 0.6)
                {defect}
                local p = Instance.new("Part"); p.Name = "Corps"; p.Parent = m
                m.Parent = game:GetService("ServerStorage"):FindFirstChild("Decor")
                """)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(20)")
        if play:
            # une partie commence : photos tirées, statues, monstre
            lua.execute("join(newPlayer('alice')); advance(90)")
        return lua

    def piece(self, lua, tag):
        return lua.eval(f"""(function()
              for _, p in ipairs(game:GetService("CollectionService"):GetTagged("{tag}")) do return p end
            end)()""")

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
            self.assertEqual(
                part.Transparency,
                1,
                f"{tag} : la pièce de jeu est invisible, le modèle la remplace",
            )
            self.assertTrue(
                lua.eval(
                    "function(p) return p:FindFirstChildWhichIsA('Model') ~= nil or #p:GetChildren() > 0 end"
                )(part),
                tag,
            )
        self.assertEqual(robust.errors(lua), [])

    def test_a_defective_model_falls_back_without_crash(self):
        lua = self.build(self.TEMPLATES, broken=("coffret ancien",))
        coffret = self.piece(lua, "Coffret")
        self.assertNotEqual(
            coffret.Transparency,
            1,
            "modèle défectueux : le coffret procédural reste visible",
        )
        self.assertEqual(
            self.piece(lua, "Key").Transparency,
            1,
            "les autres modèles se posent quand même",
        )
        self.assertEqual(robust.errors(lua), [])

    def test_statues_and_photo_frames_are_dressed_when_models_load(self):
        lua = self.build(self.LIBRARY, play=True)
        for tag in ("Statue", "Photo"):
            part = self.piece(lua, tag)
            self.assertIsNotNone(part, tag)
            self.assertEqual(
                part.Transparency, 1, f"{tag} : modèle posé, pièce de jeu invisible"
            )
        self.assertEqual(robust.errors(lua), [])

    def test_statues_and_photos_stay_visible_without_models(self):
        lua = self.build((), play=True)
        for tag in ("Statue", "Photo"):
            part = self.piece(lua, tag)
            self.assertNotEqual(part.Transparency, 1, f"{tag} invisible sans modèle")

    def test_blender_furniture_is_placed_in_the_decor_folder(self):
        lua = self.build(self.LIBRARY, play=True)
        found = lua.eval("""(function()
              local names = {}
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.ClassName == "Model" then names[d.Name] = true end
              end
              return names
            end)()""")
        for name in (
            "armoire gothique",
            "commode ancienne",
            "berceau",
            "cheval à bascule",
            "miroir sur pied",
            "malle",
        ):
            self.assertTrue(found[name], f"{name} absent du décor")
        self.assertEqual(robust.errors(lua), [])

    def test_monster_gets_the_shadow_silhouette_and_keeps_its_rig(self):
        lua = self.build(self.LIBRARY, play=True)
        info = lua.eval("""(function()
              local welds, silhouette = 0, false
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.ClassName == "Weld" then welds = welds + 1 end
                if d.ClassName == "Model" and d.Name == "ombre rampante" and d.Parent and d.Parent.Name == "Monster" then silhouette = true end
              end
              local hum = 0
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.ClassName == "Humanoid" and d.Parent and d.Parent.Name == "Monster" then hum = hum + 1 end
              end
              return { welds, silhouette, hum }
            end)()""")
        self.assertGreaterEqual(info[1], 1, "un Weld anime la silhouette")
        self.assertTrue(info[2], "la silhouette est dans le modèle du monstre")
        self.assertEqual(info[3], 1, "le rig (Humanoid) reste la logique et la hitbox")
        self.assertEqual(robust.errors(lua), [])

    def test_monster_keeps_its_rig_without_the_model(self):
        lua = self.build((), play=True)
        info = lua.eval("""(function()
              local silhouette = false
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.ClassName == "Model" and d.Name == "ombre rampante" then silhouette = true end
              end
              return silhouette
            end)()""")
        self.assertFalse(info)
        self.assertEqual(robust.errors(lua), [])

    def test_a_defective_monster_model_falls_back_to_the_rig(self):
        lua = self.build(self.LIBRARY, broken=("ombre rampante",), play=True)
        self.assertEqual(robust.errors(lua), [])

    def test_decor_has_fallback_pieces_when_models_are_missing(self):
        lua = self.build(())
        n = int(lua.eval("""(function()
              local c = 0
              for _, d in ipairs(workspace:GetDescendants()) do
                if d.Name == "poupée ancienne" or d.Name == "bougie chandelier" then c = c + 1 end
              end
              return c
            end)()"""))
        self.assertGreaterEqual(n, 4, "deux poupées et deux chandeliers de repli")


if __name__ == "__main__":
    unittest.main()

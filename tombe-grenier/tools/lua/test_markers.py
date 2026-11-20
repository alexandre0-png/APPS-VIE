#!/usr/bin/env python3
"""Lisibilité : chaque objet interactif a un style distinct (couleur, icône, nom) ; le décor n'en a pas."""
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


# Étiquettes qui ne portent jamais d'invite : décor, effets, repères, murs
DECOR_TAGS = {"Waypoint", "Lamp", "FlickerLight", "InvisibleWall", "Curtain", "Respire", "UVMark", "FallingObject", "Spawn"}
PROMPT_WORDS = ("ProximityPrompt", "makePrompt", "addPrompt", "prompt(")


class TestMarkers(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.M = self.lua.execute(to_lua54(read("src", "shared", "Markers.lua")))
        self.styles = [self.M.STYLES[i] for i in range(1, len(self.M.STYLES) + 1)]

    def test_each_category_is_distinct(self):
        cats = [s.category for s in self.styles]
        icons = [s.icon for s in self.styles]
        colors = [tuple(s.color[i] for i in (1, 2, 3)) for s in self.styles]
        labels = [s.label for s in self.styles]
        for name, values in (("catégorie", cats), ("icône", icons), ("couleur", colors), ("nom", labels)):
            self.assertEqual(len(values), len(set(values)), f"{name} en double")

    def test_colors_are_far_apart(self):
        colors = [tuple(s.color[i] for i in (1, 2, 3)) for s in self.styles]
        for i, a in enumerate(colors):
            for b in colors[i + 1:]:
                dist = sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
                self.assertGreater(dist, 70, f"{a} trop proche de {b}")

    def test_required_categories_exist(self):
        cats = {s.category for s in self.styles}
        for needed in ("clé", "porte", "document", "levier", "cachette", "enfant"):
            self.assertIn(needed, cats)

    def test_a_tag_has_one_style(self):
        seen = {}
        for s in self.styles:
            for i in range(1, len(s.tags) + 1):
                tag = s.tags[i]
                self.assertNotIn(tag, seen, f"{tag} dans deux catégories")
                seen[tag] = s.category

    def test_decor_tags_have_no_style(self):
        for tag in DECOR_TAGS:
            self.assertIsNone(self.M.styleForTag(tag), tag)

    def test_every_tag_with_a_prompt_is_styled(self):
        missing = set()
        for name in ("Quests.lua", "Props.lua", "Objectives.lua", "Hiding.lua", "Ambience.lua"):
            lines = read("src", "server", name).split("\n")
            for i, line in enumerate(lines):
                m = re.search(r'GetTagged\("(\w+)"\)', line)
                if not m or m.group(1) in DECOR_TAGS:
                    continue
                window = "\n".join(lines[i:i + 30])
                if any(w in window for w in PROMPT_WORDS) and self.M.styleForTag(m.group(1)) is None:
                    missing.add((name, m.group(1)))
        self.assertEqual(missing, set(), "étiquettes à invite sans style")

    def test_decor_kit_only_tags_books(self):
        kit = read("src", "server", "DecorKit.lua")
        tags = set(re.findall(r'AddTag\([^,]+,\s*"(\w+)"\)', kit))
        self.assertTrue(tags <= {"Livre"}, tags)

    def test_server_applies_halo_icon_and_name(self):
        s = read("src", "server", "Markers.lua")
        for word in ("Highlight", "BillboardGui", "ObjectText", "MaxDistance"):
            self.assertIn(word, s)
        init = read("src", "server", "init.server.lua")
        self.assertIn("Markers.apply()", init)
        self.assertGreater(init.index("Markers.apply()"), init.index("Props.setup()"))


if __name__ == "__main__":
    unittest.main()


class TestCatalogModels(unittest.TestCase):
    """Les modèles du catalogue (ModelLoader, Config.Assets) couvrent le mobilier ; les alias pointent vers un modèle chargé."""

    def test_aliases_target_loaded_models(self):
        kit = read("src", "server", "DecorKit.lua")
        loader = read("src", "server", "ModelLoader.lua")
        aliases = dict(re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]+)",', kit[kit.index("DecorKit.ALIASES"):kit.index("}", kit.index("DecorKit.ALIASES"))]))
        self.assertTrue(aliases)
        loaded = set(re.findall(r'\["([^"]+)"\]\s*=\s*\d+', loader)) | set(re.findall(r'=\s*"([^"]+)",\n', loader[loader.index("ASSET_NAMES"):]))
        for src, dst in aliases.items():
            self.assertIn(dst, loaded, f"alias {src} -> {dst} sans modèle chargé")

    def test_fallback_is_kept_when_no_model(self):
        kit = read("src", "server", "DecorKit.lua")
        self.assertIn("DecorKit.ALIASES", kit)
        self.assertIn("RECIPES[f.name]", kit)  # sans modèle : objets de substitution lisibles
        self.assertIn("furnPart.Transparency = 1", kit)  # la boîte garde la collision quand un modèle la remplace

    def test_catalog_ids_are_configured(self):
        cfg = read("src", "shared", "Config.lua")
        for key in ("ChaiseHorreur", "ChaiseAntique", "TableLongue", "Plante", "LampeHorreur"):
            self.assertRegex(cfg, rf"{key} = \d{{6,}}")


class TestUserCatalog(unittest.TestCase):
    """Les identifiants du catalogue de l'utilisateur sont déclarés, chargés par ModelLoader et placés sans bloquer."""

    IDS = {
        125943216682367, 8156800485, 80943579301021, 8995653666, 13369825696, 97314700592382, 10780850055,
        12032209888, 1452069624, 10551600237, 12470604445, 839550130, 188745055, 14953074402, 1338860741,
        130020507665878, 5680874848, 16600867704, 15078054751, 116741237427172, 131378985761907, 101176034116232,
    }

    def test_every_catalog_id_is_in_config(self):
        cfg = read("src", "shared", "Config.lua")
        block = cfg[cfg.index("Config.Assets = {"):cfg.index("Config.Hub")]
        found = {int(x) for x in re.findall(r"= (\d{6,})", block)}
        self.assertTrue(self.IDS <= found, self.IDS - found)

    def test_every_asset_key_is_loaded_by_the_loader(self):
        cfg = read("src", "shared", "Config.lua")
        block = cfg[cfg.index("Config.Assets = {"):cfg.index("Config.Hub")]
        keys = set(re.findall(r"\t(\w+) = \d{6,}", block)) - {"Monstre1", "Monstre2", "Monstre3", "HubBibliotheque"}
        loader = read("src", "server", "ModelLoader.lua")
        for key in keys:
            self.assertRegex(loader, rf"\b{key} = \"", f"{key} non chargé par ModelLoader")

    def test_room_models_name_loaded_models(self):
        kit = read("src", "server", "DecorKit.lua")
        loader = read("src", "server", "ModelLoader.lua")
        names = set(re.findall(r'= "([^"]+)",', loader[loader.index("ASSET_NAMES"):])) | set(re.findall(r'\["([^"]+)"\] = \d+', loader))
        block = kit[kit.index("DecorKit.ROOM_MODELS"):kit.index("ROOM_RECIPES")]
        for model in re.findall(r'= "([^"]+)"', block):
            self.assertIn(model, names, f"modèle de pièce inconnu : {model}")

    def test_room_models_never_block(self):
        kit = read("src", "server", "DecorKit.lua")
        self.assertIn("d.CanCollide = false", kit)  # les modèles n'ajoutent aucune collision
        self.assertIn("DecorKit.ROOM_MODELS[f.room]", kit)

    def test_new_plants_are_in_the_map(self):
        sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
        import generate_map as gm

        rooms = {rid for rid, items in gm.FURNITURE.items() for it in items if it[0] == "plante"}
        self.assertTrue({"salon", "sam", "bureau", "hall"} <= rooms)


class TestPriorityAndJournal(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.M = self.lua.execute(to_lua54(read("src", "shared", "Markers.lua")))
        self.C = self.lua.execute(to_lua54(read("src", "shared", "Chain.lua")))
        self.ids = [self.C.STEPS[i].id for i in range(1, len(self.C.STEPS) + 1)]

    def done(self, ids):
        return self.lua.table_from({i: True for i in ids})

    def test_step_tags_are_styled_and_only_known_steps(self):
        for step, tags in self.M.STEP_TAGS.items():
            self.assertIn(step, self.ids)
            for i in range(1, len(tags) + 1):
                self.assertIsNotNone(self.M.styleForTag(tags[i]), tags[i])

    def test_every_object_step_has_a_strong_halo_tag(self):
        walk = {"sous_sol", "retour"}
        for sid in self.ids:
            self.assertEqual(sid in self.M.STEP_TAGS, sid not in walk, sid)

    def test_is_current(self):
        self.assertTrue(self.M.isCurrent("key", self.lua.table_from(["Key"])))
        self.assertFalse(self.M.isCurrent("key", self.lua.table_from(["Photo"])))
        self.assertFalse(self.M.isCurrent("retour", self.lua.table_from(["Key"])))

    def test_select_keeps_current_step_first_then_nearest(self):
        entries = self.lua.table_from([
            self.lua.table_from({"dist": 5, "current": False}),
            self.lua.table_from({"dist": 90, "current": True}),
            self.lua.table_from({"dist": 2, "current": False}),
            self.lua.table_from({"dist": 40, "current": False}),
        ])
        keep = self.M.select(entries, 2)
        self.assertTrue(keep[2])  # l'objet de l'étape, même loin
        self.assertTrue(keep[3])  # puis le plus proche
        self.assertIsNone(keep[1])
        self.assertIsNone(keep[4])

    def test_select_never_exceeds_the_limit(self):
        entries = self.lua.table_from([self.lua.table_from({"dist": i, "current": i % 7 == 0}) for i in range(1, 80)])
        keep = self.M.select(entries, self.M.MAX_HALOS)
        self.assertEqual(sum(1 for i in range(1, 80) if keep[i]), self.M.MAX_HALOS)
        self.assertLess(self.M.MAX_HALOS, 31)

    def test_journal_head_is_current_step_and_hides_the_future(self):
        lines = self.C.journal(self.done(self.ids[:3]))
        rows = [lines[i] for i in range(1, len(lines) + 1)]
        self.assertTrue(rows[0].startswith("Étape active : "))
        self.assertIn(self.C.STEPS[4].objective, rows[0])
        self.assertEqual(sum(1 for r in rows if r.startswith("✓")), 3)
        self.assertTrue(rows[-1].startswith("…"))
        for later in range(5, len(self.ids) + 1):
            self.assertFalse(any(self.C.STEPS[later].objective in r for r in rows))

    def test_server_refreshes_by_step_and_client_has_journal_key(self):
        srv = read("src", "server", "Markers.lua")
        for word in ("Markers.refresh", "MarkerStyles.select", "MarkerStyles.isCurrent", "glow.Enabled"):
            self.assertIn(word, srv)
        cli = read("src", "client", "init.client.lua")
        self.assertIn("Enum.KeyCode.J", cli)
        self.assertIn('Remotes.get("Journal")', cli)
        self.assertIn('"Journal"', read("src", "shared", "Remotes.lua"))


class TestFeedbackSounds(unittest.TestCase):
    """Retours sonores : seuls des sons déjà présents dans AudioManifest sont utilisés (aucun identifiant inventé)."""

    def manifest_keys(self):
        return set(re.findall(r"^\t(\w+) = \{", read("src", "shared", "AudioManifest.lua"), re.M))

    def test_every_played_sound_exists_in_the_manifest(self):
        keys = self.manifest_keys()
        for sub in ("server", "client", "common", "shared"):
            d = os.path.join(ROOT, "src", sub)
            for f in os.listdir(d):
                if f.endswith(".lua"):
                    for key in re.findall(r'Audio\.play\("(\w+)"', read("src", sub, f)):
                        self.assertIn(key, keys, f"{sub}/{f} joue un son absent du manifeste : {key}")

    def test_doors_pickups_and_steps_give_feedback(self):
        self.assertIn('Audio.play("porte_grince", panel', read("src", "server", "Props.lua"))
        self.assertIn('Audio.play("clic_lampe", part', read("src", "server", "Objectives.lua"))
        self.assertIn('Audio.play("cachette", workspace', read("src", "server", "Quests.lua"))

    def test_initial_door_state_is_silent(self):
        props = read("src", "server", "Props.lua")
        self.assertIn("lock == nil or Locks.isOpen(lock), true)", props)

    def test_all_manifest_assets_are_real_ids(self):
        for key, asset in re.findall(r'^\t(\w+) = \{ asset = "([^"]*)"', read("src", "shared", "AudioManifest.lua"), re.M):
            self.assertRegex(asset, r"^rbxassetid://\d{6,}$", f"{key} : identifiant de son invalide")


class TestObjectiveArrow(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.M = self.lua.execute(to_lua54(read("src", "shared", "Markers.lua")))

    def test_bearing_front_right_back_left(self):
        b = self.M.bearing
        self.assertAlmostEqual(b(0, -1, 0, -5), 0, places=3)  # droit devant (regard vers -Z)
        self.assertAlmostEqual(b(0, -1, 5, 0), 90, places=3)  # à droite
        self.assertAlmostEqual(abs(b(0, -1, 0, 5)), 180, places=3)  # derrière
        self.assertAlmostEqual(b(0, -1, -5, 0), -90, places=3)  # à gauche

    def test_bearing_degenerate_inputs(self):
        self.assertIsNone(self.M.bearing(0, 0, 1, 1))
        self.assertIsNone(self.M.bearing(0, -1, 0, 0))

    def test_server_sets_target_and_current_halo_is_seen_through_walls(self):
        server = read("src", "server", "Markers.lua")
        self.assertIn('SetAttribute("ObjectiveTarget"', server)
        self.assertIn("AlwaysOnTop", server)

    def test_client_draws_the_arrow_isolated(self):
        client = read("src", "client", "init.client.lua")
        self.assertIn("FlecheObjectif", client)
        self.assertIn('safeConnect(RunService.RenderStepped, "Flèche objectif"', client)

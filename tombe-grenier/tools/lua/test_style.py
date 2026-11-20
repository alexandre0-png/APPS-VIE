#!/usr/bin/env python3
"""Style cartoon glossy, code couleur par fonction, bannières de zone, révélation d'étape, dix premières secondes."""
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as base  # noqa: E402
from check_syntax import to_lua54  # noqa: E402

ROOT = base.ROOT


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def pure(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestTheme(unittest.TestCase):
    def setUp(self):
        self.lua, self.T = pure("src/shared/Theme.lua")
        self.roles = {k: self.T.ROLES[k] for k in ("play", "save", "option", "danger", "neutral")}

    def rgb(self, c):
        return [c[1], c[2], c[3]]

    def test_roles_are_distinct_and_have_the_expected_hue(self):
        top = {k: self.rgb(v.top) for k, v in self.roles.items()}
        self.assertTrue(top["play"][1] > top["play"][0] and top["play"][1] > top["play"][2], "vert")
        self.assertTrue(top["save"][2] > top["save"][0] and top["save"][2] > top["save"][1] * 0.95, "bleu")
        self.assertTrue(top["option"][0] > top["option"][1] > top["option"][2], "orange")
        self.assertTrue(top["danger"][0] > 2 * top["danger"][1], "rouge")
        for a in top:
            for b in top:
                if a < b:
                    d = sum((x - y) ** 2 for x, y in zip(top[a], top[b])) ** 0.5
                    self.assertGreater(d, 60, f"{a} trop proche de {b}")

    def test_gradient_goes_from_light_to_dark_with_a_much_darker_outline(self):
        for name, r in self.roles.items():
            lt, lb, ls = (self.T.luminance(r.top), self.T.luminance(r.bottom), self.T.luminance(r.stroke))
            self.assertGreater(lt, lb, name)
            self.assertLess(ls, lb * 0.6 + 0.001, f"{name} : contour assez foncé")
            self.assertLess(ls, 0.03, f"{name} : contour franchement sombre")

    def test_text_is_readable_on_the_gradient(self):
        for name, r in self.roles.items():
            self.assertGreaterEqual(self.T.contrast(r.text, self.T.middle(name)), 3.0, f"{name} : texte trop pâle")

    def test_style_constants_are_thick_rounded_and_discreet(self):
        self.assertGreaterEqual(self.T.STROKE, 3)
        self.assertGreaterEqual(self.T.CORNER, 8)
        self.assertGreaterEqual(self.T.GLOSS.transparency, 0.8)

    def test_function_to_color_code(self):
        self.assertEqual(self.T.roleForButton("Quitter"), "danger")
        self.assertEqual(self.T.roleForButton("Refermer"), "danger")
        self.assertEqual(self.T.roleForButton("Rejouer"), "play")
        self.assertEqual(self.T.roleForAction("Indice"), "save")
        self.assertEqual(self.T.roleForAction("Course"), "play")
        self.assertEqual(self.T.roleForAction("Journal"), "option")
        self.assertEqual(self.T.roleForAction("inconnu"), "neutral")
        self.assertEqual(self.T.MESSAGE_ROLES.error, "danger")
        self.assertEqual(self.T.MESSAGE_ROLES.success, "play")

    def test_every_touch_action_of_the_client_has_a_role(self):
        src = read("src", "client", "init.client.lua")
        block = src[src.index("local ACTIONS = {"):src.index("local actionButtons")]
        for name in re.findall(r'name = "([^"]+)",\s*order', block):
            self.assertIn(self.T.ACTION_ROLES[name], self.roles, f"{name} sans rôle")

    def test_no_invented_image_ids_in_the_style_code(self):
        for f in ("Theme.lua", "UiStyle.lua"):
            text = read("src", "shared", f)
            self.assertNotIn("rbxassetid", text, f)
            self.assertNotIn("ImageLabel", text, f)


class TestUiStyleInFakeRoblox(unittest.TestCase):
    def make(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
        lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(base.ROOT, *p.split("/")))
        lua.execute(base.STUB)
        lua.execute('UDim = { new = function(a, b) return { Scale = a, Offset = b } end }')
        lua.execute('ColorSequence = { new = function(a, b) return { a, b } end }')
        lua.execute('Color3.new = Color3.new or function(r, g, b) return { R = r, G = g, B = b } end')
        return lua

    def test_apply_adds_outline_corners_gradient_and_gloss_once(self):
        lua = self.make()
        names = lua.eval(
            """(function()
              local Ui = require({ __path = "src/shared/UiStyle.lua" })
              local b = Instance.new("TextButton"); b.ZIndex = 5
              Ui.apply(b, "play"); Ui.apply(b, "play"); Ui.apply(b, "danger")
              local out = {}
              for _, c in ipairs(b:GetChildren()) do out[#out + 1] = c.Name end
              table.sort(out)
              return table.concat(out, ",")
            end)()"""
        )
        self.assertEqual(names, "Coins,Contour,Degrade,Reflet")

    def test_recolor_changes_the_gradient_and_outline(self):
        lua = self.make()
        ok = lua.eval(
            """(function()
              local Ui = require({ __path = "src/shared/UiStyle.lua" })
              local f = Instance.new("Frame")
              Ui.apply(f, "play")
              local before = f:FindFirstChild("Contour").Color.R
              Ui.recolor(f, "danger")
              return f:FindFirstChild("Contour").Color.R ~= before and f:FindFirstChild("Degrade").Color[1].R > 200
            end)()"""
        )
        self.assertTrue(ok)

    def test_a_style_error_never_breaks_the_button(self):
        lua = self.make()
        ok = lua.eval(
            """(function()
              local Ui = require({ __path = "src/shared/UiStyle.lua" })
              local broken = setmetatable({}, { __index = function() error("boom") end })
              local ok = pcall(Ui.apply, broken, "play")
              return ok
            end)()"""
        )
        self.assertTrue(ok, "UiStyle.apply ne propage jamais d'erreur")


class TestZones(unittest.TestCase):
    def setUp(self):
        self.lua, self.Z = pure("src/shared/Zones.lua")
        self.data = self.lua.execute(to_lua54(read("src", "shared", "MapData.lua")))

    def zone(self, x, y, z):
        return self.Z.at(self.data.rooms, self.data.base, self.data.H, x, y, z)

    def test_every_room_centre_maps_to_the_right_zone(self):
        expected = {"attic": "grenier", "first": "etage", "ground": "rez"}
        seen = set()
        for i in range(1, len(self.data.rooms) + 1):
            r = self.data.rooms[i]
            base_y = self.data.base[r.level]
            got = self.zone((r.x0 + r.x1) / 2, base_y + 3, (r.z0 + r.z1) / 2)
            if r.level in expected:
                self.assertEqual(got, expected[r.level], r.id)
            else:
                self.assertEqual(got, "cave" if r.id == "cave" else "sous_sol", r.id)
            seen.add(got)
        self.assertEqual(seen, {"grenier", "etage", "rez", "cave", "sous_sol"})

    def test_outside_and_exterior_stairs(self):
        self.assertEqual(self.zone(60, 1, 100), "jardin")
        self.assertEqual(self.zone(-40, 1, 50), "jardin")
        self.assertEqual(self.zone(103, -6, 98), "sous_sol")

    def test_every_zone_has_a_banner_text_and_a_known_role(self):
        for zid in ("grenier", "etage", "rez", "cave", "sous_sol", "jardin"):
            info = self.Z.INFO[zid]
            self.assertTrue(info.title and info.sub, zid)
            self.assertIn(info.role, ("play", "save", "option", "danger", "neutral"))

    def test_announcer(self):
        a = self.Z.newAnnouncer(1.0, 6, 45)
        self.assertIsNone(a.update("grenier", 0))
        self.assertIsNone(a.update("grenier", 0.5), "pas avant 1 s de présence")
        self.assertEqual(a.update("grenier", 1.2), "grenier")
        self.assertIsNone(a.update("grenier", 30), "jamais deux fois de suite")
        # passage éclair dans une porte : aucune annonce
        self.assertIsNone(a.update("etage", 31))
        self.assertIsNone(a.update("grenier", 31.4))
        self.assertIsNone(a.update("grenier", 33), "revenu dans la zone déjà annoncée récemment")
        # nouvelle zone stable, mais trop tôt après la précédente annonce : en attente, annoncée plus tard
        self.assertIsNone(a.update("rez", 100))
        self.assertEqual(a.update("rez", 101.2), "rez")
        self.assertIsNone(a.update("cave", 102))
        self.assertIsNone(a.update("cave", 103.5), "écart de 6 s non respecté")
        self.assertEqual(a.update("cave", 108), "cave", "annoncée dès que l'écart est respecté")

    def test_announcer_repeats_a_zone_only_after_the_delay(self):
        a = self.Z.newAnnouncer(1.0, 6, 45)
        a.update("grenier", 0)
        self.assertEqual(a.update("grenier", 1.1), "grenier")
        a.update("etage", 20)
        self.assertEqual(a.update("etage", 21.2), "etage")
        a.update("grenier", 30)
        self.assertIsNone(a.update("grenier", 31.5), "grenier annoncé il y a moins de 45 s")
        a.update("etage", 60)
        a.update("etage", 61.2)
        a.update("grenier", 70)
        self.assertEqual(a.update("grenier", 71.3), "grenier")

    def test_unknown_position_never_announces(self):
        a = self.Z.newAnnouncer(1.0, 6, 45)
        self.assertIsNone(a.update(None, 5))


class TestOpeningAndReveal(unittest.TestCase):
    def setUp(self):
        self.lua, self.O = pure("src/shared/Opening.lua")
        _, self.R = pure("src/shared/Reveal.lua")
        self.clua, self.C = pure("src/shared/Chain.lua")

    def events(self, wake):
        plan = self.O.plan(wake, None)
        return [plan[i] for i in range(1, len(plan) + 1)]

    def test_promise_is_clear_and_first(self):
        ev = self.events(8)
        self.assertEqual(ev[0].kind, "title")
        self.assertIn("GRENIER", ev[0].title)
        self.assertIn("ENFANT", ev[0].title)
        self.assertLessEqual(ev[0].at, 1.0)

    def test_first_playable_action_within_ten_seconds(self):
        for wake in (4, 6, 8):
            ev = self.events(wake)
            self.assertLessEqual(self.O.firstActionAt(self.lua.table_from(ev)), 10, f"réveil de {wake} s")
        # la durée réelle du jeu
        cfg = read("src", "shared", "Config.lua")
        wake = int(re.search(r"Config.Intro = \{\s*Duration = (\d+)", cfg).group(1))
        self.assertLessEqual(wake, 9)
        self.assertLessEqual(self.events(wake)[1].at, 10)

    def test_title_fits_inside_the_wake(self):
        for wake in (4, 8):
            ev = self.events(wake)
            self.assertLess(ev[0].at + ev[0].duration, wake, "la promesse finit avant le réveil")

    def test_action_text_names_a_concrete_action(self):
        ev = self.events(8)
        action = [e for e in ev if e.kind == "action"][0]
        self.assertIn("objet qui brille", action.text)
        self.assertIn("bouton d'action", action.text)

    def test_reveal_texts(self):
        self.assertEqual(self.R.title(3, 14), "ÉTAPE 3 SUR 14")
        self.assertIn("DERNIÈRE", self.R.title(14, 14))
        self.assertLess(self.R.duration(3, 14), self.R.duration(14, 14))
        self.assertLessEqual(self.R.duration(3, 14), 3, "brève")
        self.assertEqual(self.R.role(3, 14), "play")
        self.assertEqual(self.R.role(13, 14), "save")

    def test_chain_progress_counts_done_steps(self):
        ids = [self.C.STEPS[i].id for i in range(1, len(self.C.STEPS) + 1)]
        for k in (0, 3, len(ids)):
            done = self.clua.table_from({i: True for i in ids[:k]})
            n, total = self.C.progress(done)
            self.assertEqual((n, total), (k, len(ids)))


class TestWiring(unittest.TestCase):
    def setUp(self):
        self.client = read("src", "client", "init.client.lua")

    def test_client_uses_the_style_and_banners(self):
        for word in ("UiStyle.apply(journalLabel", "UiStyle.apply(closeButton", "UiStyle.apply(quitButton", "UiStyle.apply(restartButton",
                     "Theme.roleForAction(action.name)", "makeBanner(", "Remotes.get(\"Reveal\")", "Zones.newAnnouncer",
                     "openingSequence(", "Reveal.title("):
            self.assertIn(word, self.client)

    def test_server_sends_the_reveal_with_progress(self):
        q = read("src", "server", "Quests.lua")
        self.assertIn('Remotes.fireAll("Reveal"', q)
        self.assertIn("Chain.progress(doneSet())", q)
        self.assertIn('"Reveal"', read("src", "shared", "Remotes.lua"))

    def test_hub_uses_the_same_style_and_promise(self):
        hub = read("src", "common", "Hub.lua")
        self.assertIn("UiStyle.apply(label", hub)
        self.assertIn("Opening.PROMISE", hub)
        self.assertIn("Theme.ROLES.play.top", hub)
        self.assertIn("Theme.ROLES.save.top", hub)
        self.assertIn('"danger"', hub)

    def test_messages_do_not_cut_each_other_short(self):
        self.assertIn('lbl:GetAttribute("Token") ~= token', self.client)
        self.assertIn("Visible = false", self.client)

    def test_rules_no_longer_overlap_the_opening(self):
        self.assertIn("task.delay(15, showRules)", self.client)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Sons synthétiques : règles pures (choix du son, volumes), manifeste, repli sans erreur, rôle des clés."""
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
NEW_KEYS = (
    "ambiance_grenier", "vent_grenier", "murmure", "chuchotement", "sting_monstre", "battement_coeur", "pas_bois",
    "pas_courses", "marche_escalier", "grincement_porte", "porte_verrouillee", "cle_ramassee", "coffre_ouvre", "horloge_tic",
)


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


class TestSoundRules(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute("typeof = type")
        self.R = self.lua.execute(to_lua54(read("src", "shared", "SoundRules.lua")))

    def test_heart_volume_grows_when_the_monster_is_close(self):
        h = self.R.heartVolume
        self.assertEqual(h(None, 40, False, False), 0)
        self.assertEqual(h(60, 40, False, False), 0)
        self.assertGreater(h(5, 40, False, False), h(30, 40, False, False))
        self.assertLessEqual(h(0, 40, True, True), 0.7)
        self.assertGreater(h(None, 40, True, False), 0.3)  # poursuite : toujours audible
        self.assertGreater(h(None, 40, False, True), 0)  # sanité basse

    def test_murmur_only_when_near_and_not_chased(self):
        m = self.R.murmurVolume
        self.assertEqual(m(50, 40, False), 0)
        self.assertEqual(m(10, 40, True), 0)
        self.assertGreater(m(10, 40, False), m(30, 40, False))
        self.assertLessEqual(m(0, 40, False), 0.35)

    def test_footsteps_choice(self):
        f = self.R.footstep
        t = lambda **k: self.lua.table_from(dict(dict(speed=8, climbing=0, grounded=True, sprint=False, quiet=False, crouch=False), **k))
        self.assertEqual(f(t())[0], "pas_bois")
        self.assertEqual(f(t(sprint=True))[0], "pas_courses")
        self.assertEqual(f(t(climbing=3))[0], "marche_escalier")
        self.assertIsNone(f(t(quiet=True)))
        self.assertIsNone(f(t(crouch=True)))
        self.assertIsNone(f(t(grounded=False)))
        self.assertIsNone(f(t(speed=0.5)))
        run = f(t(sprint=True))[1]
        walk = f(t())[1]
        self.assertLess(run, walk)

    def test_scaled_volume_is_quieter_in_quiet_mode(self):
        self.assertLess(self.R.scaled(0.6, True), self.R.scaled(0.6, False))
        self.assertLessEqual(self.R.scaled(5, False), 1)

    def test_picked_up(self):
        p = self.R.pickedUp
        mk = self.lua.table_from
        self.assertTrue(p(mk({"docs": 1}), mk({"docs": 2})))
        self.assertTrue(p(mk({"smallKey": False}), mk({"smallKey": True})))
        self.assertFalse(p(mk({"docs": 2, "hasKey": True}), mk({"docs": 2, "hasKey": True})))
        self.assertFalse(p(None, mk({"docs": 1})))


class TestManifest(unittest.TestCase):
    def setUp(self):
        self.manifest = read("src", "shared", "AudioManifest.lua")

    def test_every_new_sound_is_declared_with_a_real_id(self):
        for key in NEW_KEYS:
            m = re.search(rf'\b{key} = \{{ asset = "rbxassetid://(\d{{9,}})", volume = ([\d.]+)', self.manifest)
            self.assertIsNotNone(m, key)
            vol = float(m.group(2))
            loop = f"{key} = " in self.manifest and "looped = true" in re.search(rf"\b{key} = \{{[^}}]*\}}", self.manifest).group(0)
            if loop:
                self.assertTrue(0.25 <= vol <= 0.4 or key in ("battement_coeur",), (key, vol))  # ambiances 0,25 à 0,4
            else:
                self.assertTrue(0.5 <= vol <= 0.7, (key, vol))  # effets 0,5 à 0,7

    def test_prefer_targets_exist(self):
        for target in re.findall(r'prefer = "(\w+)"', self.manifest):
            self.assertIn(f"{target} = {{", self.manifest)
            self.assertIn("new = true", re.search(rf"\b{target} = \{{[^}}]*\}}", self.manifest).group(0))

    def test_audio_is_gated_and_silent_on_failure(self):
        audio = read("src", "shared", "Audio.lua")
        self.assertIn("Config.Audio", audio)
        self.assertIn("pcall", audio)
        self.assertIn("ready[key]", audio)
        cfg = read("src", "shared", "Config.lua")
        self.assertRegex(cfg, r"Config\.Audio = \{\s*Enabled = true")


class TestAudioRuntime(unittest.TestCase):
    """Le vrai Audio.lua dans le faux Roblox : un son non chargé ne joue pas, un son chargé remplace l'ancien."""

    def make(self):
        sys.path.insert(0, HERE)
        import test_boot_async as boot

        lua = boot.server("return nil")
        lua.execute("SWALLOW = true; advance(1)")
        return lua

    def test_unloaded_new_sound_plays_nothing_and_old_sound_stays(self):
        lua = self.make()
        lua.execute('A = require({ __path = "src/shared/Audio.lua" })')
        self.assertIsNone(lua.eval('A.play("pas_bois", workspace)'))
        self.assertIsNotNone(lua.eval('A.play("porte_grince", workspace)'))  # l'ancien son joue
        self.assertEqual(lua.eval('A.play("porte_grince", workspace).SoundId'), "rbxassetid://9126144505")

    def test_loaded_new_sound_replaces_the_old_one(self):
        lua = self.make()
        lua.execute('A = require({ __path = "src/shared/Audio.lua" }); A.markReady("grincement_porte", true)')
        self.assertEqual(lua.eval('A.play("porte_grince", workspace).SoundId'), "rbxassetid://72276002070833")

    def test_channel_is_reused(self):
        lua = self.make()
        lua.execute('A = require({ __path = "src/shared/Audio.lua" }); A.markReady("pas_bois", true)')
        self.assertTrue(lua.eval('A.channel("pas_bois", workspace) == A.channel("pas_bois", workspace)'))
        self.assertIsNone(lua.eval('A.channel("pas_courses", workspace)'))  # pas prêt

    def test_disabled_audio_blocks_new_sounds(self):
        lua = self.make()
        lua.execute('A = require({ __path = "src/shared/Audio.lua" }); A.markReady("pas_bois", true); C = require({ __path = "src/shared/Config.lua" }); C.Audio.Enabled = false')
        self.assertIsNone(lua.eval('A.channel("pas_bois", workspace)'))
        self.assertIsNone(lua.eval('A.play("pas_bois", workspace)'))
        self.assertEqual(lua.eval('A.play("porte_grince", workspace).SoundId'), "rbxassetid://9126144505")


class TestWiring(unittest.TestCase):
    def test_game_points_use_the_new_sounds(self):
        self.assertIn('Audio.play("porte_verrouillee"', read("src", "server", "Props.lua"))
        self.assertIn('Audio.play("coffre_ouvre"', read("src", "server", "Quests.lua"))
        self.assertIn("MonsterDistance", read("src", "server", "MonsterAI.lua"))
        client = read("src", "client", "init.client.lua")
        for needle in ("battement_coeur", "murmure", "SoundRules.footstep", "chuchotement", "cle_ramassee"):
            self.assertIn(needle, client)
        self.assertIn("horloge_tic", read("src", "server", "init.server.lua"))

    def test_loops_are_not_started_before_the_preload(self):
        client = read("src", "client", "init.client.lua")
        self.assertIn("Audio.preloadNew", client)
        self.assertLess(client.index("Audio.preloadNew"), client.index('Audio.channel("battement_coeur"'))


if __name__ == "__main__":
    unittest.main()

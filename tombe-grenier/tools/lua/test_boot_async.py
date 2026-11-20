#!/usr/bin/env python3
"""Démarrage asynchrone : les modèles se chargent en arrière-plan, la carte et le point d'apparition existent sans eux,
la partie démarre même si chaque chargement bloque, et le script isole chaque étape (`[Boot] étape ok`)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_roles as roles  # noqa: E402

PRINTS = """
PRINTS = {}
local realPrint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(PRINTS, table.concat(t, " ")) end
"""


def server(load_asset):
    lua = roles.make(roles.GAME)
    lua.execute(PRINTS)
    lua.execute(roles.SERVER_INIT)
    lua.execute('local s = game:GetService("InsertService"); s.LoadAsset = function(self, id) %s end' % load_asset)
    first = lua.eval("runServer()")
    assert first.ok, first.err
    return lua


def prints(lua):
    return [str(lua.eval("PRINTS[%d]" % i)) for i in range(1, int(lua.eval("#PRINTS")) + 1)]


class TestAsyncModels(unittest.TestCase):
    def test_game_boots_and_player_lands_while_every_model_hangs(self):
        lua = server("while true do task.wait(1) end")
        lua.execute("SWALLOW = true; advance(30); join(newPlayer('alice')); advance(10)")
        self.assertGreaterEqual(int(lua.eval("#LOADS")), 1, "aucun personnage : le jeu a attendu les modèles")
        self.assertTrue(lua.eval("LOADS[1].usedSpawn"))

    def test_server_ready_within_one_virtual_second_with_8s_loads(self):
        lua = server("task.wait(8) return nil")
        lua.execute("SWALLOW = true; advance(1)")
        log = prints(lua)
        self.assertTrue(any("[Boot] carte ok" in l for l in log), log)
        self.assertTrue(any("[Boot] Respawn ok" in l for l in log), log)
        self.assertFalse(any("[Boot] modèles chargés" in l for l in log))

    def test_global_cap_ends_loading_even_if_all_models_hang(self):
        lua = server("while true do task.wait(1) end")
        lua.execute("SWALLOW = true; advance(40)")
        log = prints(lua)
        self.assertTrue(any("[Boot] modèles chargés" in l for l in log), log)
        self.assertTrue(any("[Boot] carte ok" in l for l in log), log)

    def test_failing_loads_do_not_stop_the_boot(self):
        lua = server('error("HTTP 403")')
        lua.execute("SWALLOW = true; advance(40); join(newPlayer('bob')); advance(10)")
        self.assertGreaterEqual(int(lua.eval("#LOADS")), 1)
        self.assertTrue(any("[Boot] habillage des modèles ok" in l for l in prints(lua)), prints(lua))

    def test_boot_steps_are_traced(self):
        lua = server("return nil")
        lua.execute("SWALLOW = true; advance(40)")
        log = "\n".join(prints(lua))
        for step in ("carte", "PlayerState", "Quests", "Respawn"):
            self.assertIn("[Boot] %s ok" % step, log)
        self.assertNotIn("ERREUR", log)


class TestStaticGuards(unittest.TestCase):
    def read(self, *p):
        return open(os.path.join(roles.base.ROOT, *p), encoding="utf-8").read()

    def test_sanitize_removes_scripts_and_remotes(self):
        s = self.read("src", "shared", "AssetLoad.lua")
        for cls in ("Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction"):
            self.assertIn(cls, s)

    def test_every_model_placement_is_deferred_when_the_model_is_not_there_yet(self):
        s = self.read("src", "server", "MapBuilder.lua")
        for name in ("horloge comtoise", "coffret ancien", "clé or"):
            i = s.index('fitModelOver(%s' % ("clock" if "horloge" in name else "casket" if "coffret" in name else "key"))
            self.assertIn("tryNow", s[i - 40 : i])
        self.assertIn("table.insert(late, function()", s)  # décor narratif : repli puis remplacement tardif

    def test_hub_script_is_isolated(self):
        s = self.read("src", "hub", "init.server.lua")
        self.assertIn("[Boot]", s)


if __name__ == "__main__":
    unittest.main()

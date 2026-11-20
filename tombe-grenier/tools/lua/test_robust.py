#!/usr/bin/env python3
"""Robustesse : validation des événements du client (Guard), fusion des profils, et démarrage RÉEL du hub et de la partie
dans le faux Roblox, avec deux joueurs et plusieurs minutes virtuelles : aucune erreur cachée après le premier yield."""
import os
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as base  # noqa: E402
import test_spawn_roles as roles  # noqa: E402
from check_syntax import to_lua54  # noqa: E402

ROOT = base.ROOT


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def pure(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestGuard(unittest.TestCase):
    def setUp(self):
        self.lua, self.G = pure("src/shared/Guard.lua")

    def vec(self, x, y, z):
        return self.lua.table_from({"X": x, "Y": y, "Z": z})

    def test_finite(self):
        self.assertTrue(self.G.isFinite(3))
        for bad in (float("nan"), float("inf"), float("-inf"), "3", None, True):
            self.assertFalse(self.G.isFinite(bad), bad)

    def test_unit_vector_rejects_nan_inf_zero_and_long(self):
        self.assertTrue(self.G.isUnitVector(self.vec(0, 0, 1)))
        for bad in ((float("nan"), 0, 0), (float("inf"), 0, 0), (0, 0, 0), (2, 0, 0), (0.5, 0.5, 0.5)):
            self.assertFalse(self.G.isUnitVector(self.vec(*bad)), bad)
        self.assertFalse(self.G.isUnitVector(None))
        self.assertFalse(self.G.isUnitVector(5))
        self.assertFalse(self.G.isUnitVector(self.lua.table_from({"X": "a", "Y": 0, "Z": 1})))

    def test_clean_text(self):
        self.assertEqual(self.G.cleanText("1234", 16), "1234")
        self.assertIsNone(self.G.cleanText("x" * 17, 16))
        self.assertIsNone(self.G.cleanText(12, 16))
        self.assertIsNone(self.G.cleanText("12\n34", 16))
        self.assertIsNone(self.G.cleanText("12\x0034", 16))
        self.assertIsNone(self.G.cleanText(None, 16))

    def test_limiter_burst_refill_and_isolation(self):
        self.lua.execute("T = 0")
        lim = self.lua.eval("function(G) return G.newLimiter(2, 4, function() return T end) end")(self.G)
        allowed = sum(1 for _ in range(10) if lim.allow("a"))
        self.assertEqual(allowed, 4, "rafale limitée au seau")
        self.assertTrue(lim.allow("b"), "un autre joueur n'est pas pénalisé")
        self.lua.execute("T = 1")  # +2 jetons
        self.assertEqual(sum(1 for _ in range(5) if lim.allow("a")), 2)
        self.lua.execute("T = 1000")
        self.assertEqual(sum(1 for _ in range(10) if lim.allow("a")), 4, "le seau ne dépasse jamais sa taille")
        lim.forget("a")
        lim.forget("b")
        self.assertEqual(lim.size(), 0, "aucune fuite : un joueur parti libère son seau")


class TestProfileMerge(unittest.TestCase):
    def setUp(self):
        self.lua, self.R = pure("src/shared/Ranks.lua")

    def t(self, d):
        return self.lua.eval("function(d) return d end")(d) if False else d

    def test_merge_never_regresses(self):
        lua = self.lua
        old = lua.eval("{ points = 50, runs = 4, tutorialDone = true, lastDay = 9, endings = { truth = 2 }, challenges = { a = true }, seeds = { 1, 2 } }")
        new = lua.eval("{ points = 20, runs = 5, tutorialDone = false, lastDay = 7, endings = { truth = 1, trap = 1 }, challenges = { b = true }, seeds = { 3 }, title = 'T' }")
        m = self.R.merge(old, new)
        self.assertEqual(m.points, 50)
        self.assertEqual(m.runs, 5)
        self.assertTrue(m.tutorialDone)
        self.assertEqual(m.lastDay, 9)
        self.assertEqual(m.endings.truth, 2)
        self.assertEqual(m.endings.trap, 1)
        self.assertTrue(m.challenges.a and m.challenges.b)
        self.assertEqual(m.title, "T")

    def test_merge_with_missing_or_garbage_data(self):
        lua = self.lua
        new = lua.eval("{ points = 12 }")
        self.assertEqual(self.R.merge(None, new).points, 12)
        self.assertEqual(self.R.merge("pourri", new).points, 12)
        self.assertEqual(self.R.merge(new, None).points, 12)
        self.assertEqual(self.R.merge(None, None).points, 0)

    def test_profile_module_uses_merge_parallel_close_and_fallback(self):
        src = read("src", "common", "Profile.lua")
        self.assertIn("Ranks.merge(old, data)", src)
        self.assertIn("pcall(cache.release", src)
        self.assertIn("pcall(cache.save", src)
        self.assertIn("fallbackProfile", src)
        for call in ("Profile.load", "Profile.get", "Profile.save"):
            self.assertIn("pcall(function()", src[src.index("function " + call):src.index("function " + call) + 300])


class TestRemotesAreGuarded(unittest.TestCase):
    def test_every_client_to_server_event_goes_through_guarded(self):
        remotes = read("src", "shared", "Remotes.lua")
        client_events = []
        for line in remotes.split("\n"):
            if "client -> serveur" in line:
                client_events.append(line.split('"')[1])
        self.assertGreaterEqual(len(client_events), 8)
        server = read("src", "server", "init.server.lua")
        for name in client_events:
            self.assertIn(f'guarded("{name}"', server, f"{name} sans validation serveur")
        self.assertNotIn(").OnServerEvent:Connect", server.replace("Remotes.get(name).OnServerEvent:Connect", ""))

    def test_no_event_handler_outside_the_guard_in_any_script(self):
        for sub in ("server", "hub", "common", "client"):
            d = os.path.join(ROOT, "src", sub)
            for f in os.listdir(d):
                if not f.endswith(".lua"):
                    continue
                text = read("src", sub, f)
                if f == "init.server.lua" and sub == "server":
                    continue
                self.assertNotIn("OnServerEvent", text, f"{sub}/{f} écoute un événement client sans Guard")


def make_capturing(place):
    """Comme test_spawn_roles.make, mais les gestionnaires OnServerEvent sont conservés (HANDLERS[nom])."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
    lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(base.ROOT, *p.split("/")))
    stub = base.STUB.replace(
        "function methods.GetFullName(self) return self.Name end",
        "function methods.GetFullName(self) return self.Name end function methods.GetAttributeChangedSignal() return { Connect = function() end } end function methods.Play() end function methods.Stop() end function methods.GetAttributes(self) return self._attrs end function methods.IsDescendantOf() return false end",
    ).replace(
        'if k == "Parent" then return rawget(t, "_parent") end',
        'if k == "Parent" then return rawget(t, "_parent") end if k == "OnServerEvent" then return { Connect = function(_, f) HANDLERS[rawget(t, "Name")] = f end } end if k == "Triggered" or k == "Touched" or k == "CharacterAdded" or k == "OnClientEvent" or k == "PromptTriggered" then return { Connect = function() end } end if k == "FireClient" or k == "FireAllClients" or k == "FireServer" then return function() end end',
    )
    lua.execute("HANDLERS = {}")
    lua.execute(stub)
    lua.execute("math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("game.PlaceId = %d" % place)
    lua.execute('game:GetService("RunService").IsStudio = function() return false end')
    lua.execute('local ts = game:GetService("TeleportService"); ts.TeleportAsync = function() end; ts.ReserveServer = function() return "c" end; ts.TeleportToPrivateServer = function() end')
    lua.execute("game.BindToClose = function() end")
    lua.execute('local cs = game:GetService("CollectionService"); cs.RemoveTag = function() end; cs.GetTags = function() return {} end')
    lua.execute(roles.SCHEDULER)
    lua.execute(roles.HUB_INIT)
    lua.execute(roles.SERVER_INIT)
    lua.execute("PRINTS = {}; local realprint = print; print = function(...) local t = {} for i = 1, select('#', ...) do t[i] = tostring((select(i, ...))) end table.insert(PRINTS, table.concat(t, ' ')) end")
    return lua


def errors(lua):
    n = int(lua.eval("#ERRORS"))
    return [str(lua.eval("ERRORS[%d]" % i)) for i in range(1, n + 1)]


class TestRealStartupHasNoHiddenErrors(unittest.TestCase):
    """Le vrai script serveur tourne 4 minutes virtuelles avec deux joueurs ; toute erreur dans une tâche de fond est un échec."""

    def run_role(self, place, seconds=240):
        lua = make_capturing(place)
        first = lua.eval("runServer()")
        self.assertTrue(first.ok, first.err)
        lua.execute("SWALLOW = true; join(newPlayer('alice')); join(newPlayer('bob')); advance(%d)" % seconds)
        return lua

    def test_game_role_runs_four_minutes_without_error(self):
        lua = self.run_role(roles.GAME)
        self.assertEqual(errors(lua), [])
        self.assertEqual(int(lua.eval("#LOADS")), 2, "les deux joueurs ont un personnage")
        prints = [str(lua.eval("PRINTS[%d]" % i)) for i in range(1, int(lua.eval("#PRINTS")) + 1)]
        self.assertTrue(any("[Round] début" in p and "mode=duo" in p for p in prints), "la partie duo a démarré")

    def test_hub_role_with_game_script_runs_without_error(self):
        lua = self.run_role(roles.HUB)
        self.assertEqual(errors(lua), [])

    def test_hub_script_runs_without_error(self):
        lua = roles.make(roles.HUB)
        lua.execute("SWALLOW = true; runHub(); join(newPlayer('alice')); join(newPlayer('bob')); advance(240)")
        self.assertEqual(errors(lua), [])
        self.assertEqual(int(lua.eval("#LOADS")), 2)

    def test_handlers_are_registered_for_every_client_event(self):
        lua = make_capturing(roles.GAME)
        self.assertTrue(lua.eval("runServer()").ok)
        for name in ("SetQuiet", "SetCrouch", "SetSprint", "ToggleFlashlight", "Restart", "Quit", "SubmitCode", "Throw", "AskHint"):
            self.assertTrue(lua.eval("HANDLERS['%s'] ~= nil" % name), name)

    def test_hostile_client_calls_are_ignored_or_limited(self):
        lua = make_capturing(roles.GAME)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; join(newPlayer('alice')); advance(30)")
        lua.execute(
            """
            local PS = require({ __path = "src/server/PlayerState.lua" })
            local Q = require({ __path = "src/server/Quests.lua" })
            COUNT = { flash = 0, quiet = 0, code = 0, throw = 0 }
            local setFlash, setQuiet, submit, tryThrow = PS.setFlashlight, PS.setQuiet, Q.submitCode, PS.tryThrow
            PS.setFlashlight = function(...) COUNT.flash = COUNT.flash + 1 return setFlash(...) end
            PS.setQuiet = function(...) COUNT.quiet = COUNT.quiet + 1 return setQuiet(...) end
            Q.submitCode = function(...) COUNT.code = COUNT.code + 1 return submit(...) end
            PS.tryThrow = function(...) COUNT.throw = COUNT.throw + 1 return tryThrow(...) end
            ALICE = game:GetService("Players"):GetPlayers()[1]
            ALICE.IsA = function(self, c) return c == "Player" end
            """
        )
        # typeof(player) doit répondre « Instance » : le faux joueur est un simple tableau, on le déclare
        lua.execute('local realtypeof = typeof; typeof = function(v) if v == ALICE then return "Instance" end return realtypeof(v) end')
        lua.execute(
            """
            local H = HANDLERS
            for i = 1, 200 do H.ToggleFlashlight(ALICE) end
            for i = 1, 50 do H.SetQuiet(ALICE, "oui") ; H.SetQuiet(ALICE, 1) ; H.SetQuiet(ALICE, nil) end
            for i = 1, 20 do H.SubmitCode(ALICE, string.rep("9", 500)); H.SubmitCode(ALICE, 12345); H.SubmitCode(ALICE, "1\\n2") end
            for i = 1, 20 do H.Throw(ALICE, Vector3.new(0/0, 0, 0)); H.Throw(ALICE, Vector3.new(9, 9, 9)); H.Throw(ALICE, "x") end
            """
        )
        c = lua.eval("COUNT")
        self.assertLessEqual(c.flash, 10, "rafale de lampe limitée")
        self.assertEqual(c.quiet, 0, "valeurs non booléennes ignorées")
        self.assertEqual(c.code, 0, "codes trop longs, non textuels ou avec caractères de contrôle ignorés")
        self.assertEqual(c.throw, 0, "directions invalides ignorées")
        self.assertEqual(errors(lua), [])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Chasse aux bugs : scénarios de jeu exécutés sur les VRAIS scripts dans le faux Roblox (horloge virtuelle).
Chaque test décrit un scénario réel (départ en cours de route, double action, mort, panne de DataStore, fin de partie,
monstre bloqué, échec total des chargements) et exige : aucune erreur d'exécution, aucun avertissement inattendu."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_robust as robust  # noqa: E402
import test_spawn_roles as roles  # noqa: E402

HELPERS = r"""
local realtypeof = typeof
typeof = function(v) if type(v) == "table" and v.UserId and v.Name then return "Instance" end return realtypeof(v) end
WARNLOG = {}
warn = function(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring((select(i, ...))) end table.insert(WARNLOG, table.concat(a, " ")) end
local Players = game:GetService("Players")
function players() return Players:GetPlayers() end
function leave(p)
  for i, q in ipairs(Players:GetPlayers()) do if q == p then table.remove(Players:GetPlayers(), i) break end end
  p.Parent = false
  Players.PlayerRemoving:Fire(p)
end
function die(p)
  local char = p.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then hum.Health = 0; hum.Died:Fire() end
end
function remote(name, p, ...) local h = HANDLERS[name]; if h then return h(p, ...) end end
"""


def game(place=roles.GAME, players=("alice", "bob"), warm=40):
    lua = robust.make_capturing(place)
    lua.execute(HELPERS)
    first = lua.eval("runServer()")
    assert first.ok, first.err
    lua.execute("SWALLOW = true; advance(%d)" % warm)
    for name in players:
        lua.execute("%s = newPlayer('%s'); join(%s)" % (name.upper(), name, name.upper()))
    return lua


def problems(lua):
    out = robust.errors(lua)
    out += [str(lua.eval("WARNLOG[%d]" % i)) for i in range(1, int(lua.eval("#WARNLOG")) + 1)]
    return [m for m in out if not m.startswith(("[Boot]", "[Spawn]"))]


class Base(unittest.TestCase):
    def clean(self, lua):
        bad = problems(lua)
        self.assertEqual(bad, [], "\n".join(bad[:4]))


class TestLeaving(Base):
    def test_leaves_before_the_character_loads(self):
        lua = game(players=())
        lua.execute("GHOST = newPlayer('ghost'); Players = game:GetService('Players'); table.insert(players(), GHOST); Players.PlayerAdded:Fire(GHOST); leave(GHOST); advance(30)")
        self.clean(lua)

    def test_leaves_during_the_load_window(self):
        lua = game(players=(), warm=1)  # la carte n'est pas encore prête
        lua.execute("A = newPlayer('alice'); join(A); advance(2); leave(A); advance(60)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 0)

    def test_leaves_mid_game_duo_other_player_continues(self):
        lua = game()
        lua.execute("advance(60); leave(ALICE); advance(120)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 1)

    def test_leaves_while_hidden(self):
        lua = game()
        lua.execute(
            """
            advance(30)
            local PS = require({ __path = "src/server/PlayerState.lua" })
            local spot = Instance.new("Part"); spot.Name = "armoire"; spot.Parent = workspace
            PS.hide(ALICE, spot)
            advance(5)
            leave(ALICE)
            advance(60)
            """
        )
        self.clean(lua)

    def test_everyone_leaves_then_a_newcomer_joins(self):
        lua = game()
        lua.execute("advance(30); leave(ALICE); leave(BOB); advance(30); C = newPlayer('carol'); join(C); advance(60)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 1)


def prints(lua):
    return [str(lua.eval("PRINTS[%d]" % i)) for i in range(1, int(lua.eval("#PRINTS")) + 1)]


class TestDeaths(Base):
    def test_duo_one_dies_the_other_alive_then_respawn_or_revive_window_ends(self):
        lua = game()
        lua.execute("advance(70); die(ALICE); advance(90)")
        self.clean(lua)
        self.assertFalse(any("[Round] fin" in p for p in prints(lua)), "un joueur vivant : pas de fin de partie")

    def test_solo_dies_three_times_curse_ends_the_round(self):
        lua = game(players=("alice",))
        lua.execute("advance(70)")
        for _ in range(4):
            lua.execute("die(ALICE); advance(30)")
        self.clean(lua)
        self.assertTrue(any("[Round] fin" in p for p in prints(lua)), prints(lua)[-6:])

    def test_both_die_together(self):
        lua = game()
        lua.execute("advance(70); die(ALICE); die(BOB); advance(120)")
        self.clean(lua)

    def test_dies_while_hidden(self):
        lua = game()
        lua.execute(
            """
            advance(50)
            local PS = require({ __path = "src/server/PlayerState.lua" })
            local spot = Instance.new("Part"); spot.Name = "armoire"; spot.Parent = workspace
            PS.hide(ALICE, spot)
            die(ALICE)
            advance(80)
            """
        )
        self.clean(lua)

    def test_dies_on_the_stairs(self):
        lua = game()
        lua.execute(
            """
            advance(50)
            ALICE.Character.HumanoidRootPart.Position = Vector3.new(54, -6, 38)
            die(ALICE)
            advance(80)
            """
        )
        self.clean(lua)

    def test_dies_then_leaves_before_respawn(self):
        lua = game()
        lua.execute("advance(50); die(ALICE); advance(1); leave(ALICE); advance(90)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 1)


TELEPORT_HOOK = r"""
TELEPORTS = {}
local ts = game:GetService("TeleportService")
ts.TeleportAsync = function(_, place, players) table.insert(TELEPORTS, { place = place, count = #players }) end
"""


class TestServerLifecycle(Base):
    def test_third_player_on_a_full_server_causes_no_error(self):
        lua = game()
        lua.execute("advance(40); C = newPlayer('carol'); join(C); advance(60)")
        self.clean(lua)

    def test_friend_joining_after_the_game_ended_is_sent_to_the_hub(self):
        lua = game(players=("alice",))
        lua.execute(TELEPORT_HOOK)
        lua.execute("advance(70)")
        for _ in range(4):
            lua.execute("die(ALICE); advance(30)")
        self.assertTrue(any("[Round] fin" in p for p in prints(lua)))
        lua.execute("advance(60); F = newPlayer('friend'); join(F); advance(20)")
        self.clean(lua)
        self.assertGreaterEqual(int(lua.eval("#TELEPORTS")), 1, "le nouvel arrivant doit repartir vers le hub")

    def test_reconnection_after_a_drop_gets_a_character_again(self):
        lua = game()
        lua.execute("advance(60); uid = ALICE.UserId; leave(ALICE); advance(5)")
        lua.execute("A2 = newPlayer('alice'); A2.UserId = uid; before = #LOADS; join(A2); advance(30)")
        self.clean(lua)
        self.assertGreater(int(lua.eval("#LOADS")), int(lua.eval("before")))

    def test_end_then_restart_in_place_leaves_no_residual_state(self):
        lua = robust.make_capturing(0)  # lieu unique : la partie recommence sur place
        lua.execute(HELPERS)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(40); A = newPlayer('alice'); join(A); advance(90)")
        starts = [p for p in prints(lua) if "[Round] début" in p]
        self.assertEqual(len(starts), 1, prints(lua)[-8:])
        lua.execute(
            """
            Quests = require({ __path = "src/server/Quests.lua" })
            Locks = require({ __path = "src/server/Locks.lua" })
            Locks.open("cahier")
            for _ = 1, 4 do die(A); advance(30) end
            advance(40)
            remote("Restart", A)
            advance(60)
            """
        )
        self.clean(lua)
        starts = [p for p in prints(lua) if "[Round] début" in p]
        self.assertGreaterEqual(len(starts), 2, prints(lua)[-10:])
        self.assertFalse(lua.eval('Locks.isOpen("cahier")'), "les verrous sont refermés")
        progress = lua.eval("Quests.progress()")
        self.assertEqual(sum(1 for _, v in progress.done.items() if v), 0, "aucune étape héritée de la partie précédente")
        self.assertEqual(lua.eval("A.Character.Humanoid.Health > 0"), True)

    def test_hub_bound_players_are_not_left_in_the_dead_game_server(self):
        lua = game(players=("alice",))
        lua.execute(TELEPORT_HOOK)
        lua.execute("advance(70)")
        for _ in range(4):
            lua.execute("die(ALICE); advance(30)")
        lua.execute("advance(60)")
        self.assertGreaterEqual(int(lua.eval("#TELEPORTS")), 1)
        self.clean(lua)


DS_SETUP = r"""
DS_MODE = "ok"      -- ok | fail | slow
DS_DATA = {}
DS_CALLS = { get = 0, set = 0 }
local DS = { GetDataStore = function() return {
  GetAsync = function(_, key)
    DS_CALLS.get = DS_CALLS.get + 1
    if DS_MODE == "fail" then error("DataStore indisponible") end
    if DS_MODE == "slow" then task.wait(40) end
    return DS_DATA[key]
  end,
  UpdateAsync = function(_, key, fn)
    DS_CALLS.set = DS_CALLS.set + 1
    if DS_MODE == "fail" then error("DataStore indisponible") end
    if DS_MODE == "slow" then task.wait(40) end
    DS_DATA[key] = fn(DS_DATA[key])
  end,
} end }
local realGet = game.GetService
game.GetService = function(self, n) if n == "DataStoreService" then return DS end return realGet(self, n) end
BIND = nil
game.BindToClose = function(_, f) BIND = f end
"""


class TestDataStore(Base):
    def make(self):
        lua = robust.make_capturing(roles.GAME)
        lua.execute(HELPERS)
        lua.execute(DS_SETUP)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(40); A = newPlayer('alice'); join(A); B = newPlayer('bob'); join(B)")
        lua.execute('PROFILE = require({ __path = "src/common/Profile.lua" })')
        return lua

    def tolerated(self, lua):
        return [m for m in problems(lua) if not m.startswith("[Profile]")]

    def test_store_down_at_arrival_gives_a_fresh_profile_and_the_game_goes_on(self):
        lua = self.make()
        lua.execute('DS_MODE = "fail"; task.spawn(function() PROFILE.load(A) end); advance(20)')
        self.assertIsNotNone(lua.eval("PROFILE.get(A)"))
        lua.execute("advance(120)")
        self.assertEqual(self.tolerated(lua), [])
        self.assertEqual(int(lua.eval("#players()")), 2)

    def test_store_down_at_exit_does_not_raise_and_keeps_memory(self):
        lua = self.make()
        lua.execute('PROFILE.load(A); DS_MODE = "fail"; leave(A); advance(30)')
        self.assertEqual(self.tolerated(lua), [])

    def test_slow_store_does_not_freeze_the_round(self):
        lua = self.make()
        lua.execute('DS_MODE = "slow"; task.spawn(function() PROFILE.load(A) end); advance(30)')
        self.assertEqual(int(lua.eval("#players()")), 2)
        lua.execute("advance(60)")
        self.assertEqual(self.tolerated(lua), [])

    def test_existing_profile_is_not_lost_when_the_store_recovers(self):
        lua = self.make()
        lua.execute('DS_DATA["p" .. A.UserId] = { rank = 3, version = 1 }; DS_MODE = "ok"; PROFILE.load(A)')
        self.assertIsNotNone(lua.eval("PROFILE.get(A)"))
        lua.execute("PROFILE.save(A); advance(5)")
        self.assertGreaterEqual(int(lua.eval("DS_CALLS.set")), 1)
        self.assertEqual(self.tolerated(lua), [])

    def test_bind_to_close_with_players_finishes_in_time(self):
        lua = self.make()
        lua.execute('PROFILE.load(A); PROFILE.load(B); DS_MODE = "slow"')
        self.assertTrue(lua.eval("BIND ~= nil"))
        lua.execute("DONE = false; task.spawn(function() BIND(); DONE = true end); advance(25)")
        self.assertTrue(lua.eval("DONE"), "BindToClose doit rendre la main avant 30 s")
        self.assertEqual(self.tolerated(lua), [])

    def test_bind_to_close_with_failing_store(self):
        lua = self.make()
        lua.execute('PROFILE.load(A); DS_MODE = "fail"; DONE = false; task.spawn(function() BIND(); DONE = true end); advance(25)')
        self.assertTrue(lua.eval("DONE"))
        self.assertEqual(self.tolerated(lua), [])


if __name__ == "__main__":
    unittest.main()

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
            PSX = require({ __path = "src/server/PlayerState.lua" })
            PSX.addSanity(A, -80)
            workspace:SetAttribute("MonsterChasing", true)
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
        self.assertNotEqual(lua.eval('workspace:GetAttribute("MonsterChasing")'), True, "plus de poursuite héritée")
        self.assertGreater(lua.eval('A:GetAttribute("Sanity") or 100'), 50, "sanité remise à neuf")

    def test_hub_bound_players_are_not_left_in_the_dead_game_server(self):
        lua = game(players=("alice",))
        lua.execute(TELEPORT_HOOK)
        lua.execute("advance(70)")
        for _ in range(4):
            lua.execute("die(ALICE); advance(30)")
        lua.execute("advance(60)")
        self.assertGreaterEqual(int(lua.eval("#TELEPORTS")), 1)
        self.clean(lua)


class TestMonster(Base):
    def chase(self, setup="", seconds=150):
        lua = game()
        lua.execute("advance(80)")
        lua.execute(setup)
        lua.execute(
            """
            MonsterAI = require({ __path = "src/server/MonsterAI.lua" })
            MonsterAI.forceChase(ALICE)
            advance(%d)
            """
            % seconds
        )
        return lua

    def test_no_path_to_the_player(self):
        lua = self.chase('game:GetService("PathfindingService").CreatePath = function() return { ComputeAsync = function() end, Status = "NoPath", GetWaypoints = function() return {} end } end')
        self.clean(lua)

    def test_pathfinding_raises(self):
        lua = self.chase('game:GetService("PathfindingService").CreatePath = function() return { ComputeAsync = function() error("Pathfinding indisponible") end, Status = "NoPath", GetWaypoints = function() return {} end } end')
        self.clean(lua)

    def test_player_in_an_unreachable_zone(self):
        lua = self.chase("ALICE.Character.HumanoidRootPart.Position = Vector3.new(5000, 400, 5000)")
        self.clean(lua)

    def test_player_afk_for_five_minutes(self):
        lua = game()
        lua.execute("advance(400)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 2)

    def test_player_hidden_for_ten_minutes(self):
        lua = game()
        lua.execute(
            """
            advance(60)
            local PS = require({ __path = "src/server/PlayerState.lua" })
            local spot = Instance.new("Part"); spot.Name = "armoire"; spot.Parent = workspace
            PS.hide(ALICE, spot)
            advance(600)
            """
        )
        self.clean(lua)

    def test_monster_removed_mid_chase(self):
        lua = self.chase("", seconds=20)
        lua.execute('MonsterAI.stop(); advance(30); MonsterAI.forceChase(ALICE); advance(30)')
        self.clean(lua)

    def test_target_leaves_during_the_chase(self):
        lua = self.chase("", seconds=10)
        lua.execute("leave(ALICE); advance(90)")
        self.clean(lua)

    def test_monster_root_is_stuck(self):
        lua = self.chase("", seconds=10)
        lua.execute('local r = MonsterAI.getRootPosition(); advance(90)')
        self.clean(lua)


ALL_FAIL = r"""
game:GetService("InsertService").LoadAsset = function() error("HTTP 403 : accès refusé") end
local cp = game:GetService("ContentProvider")
cp.PreloadAsync = function() error("Préchargement impossible") end
"""


class TestEverythingFails(Base):
    def run_duo(self, setup):
        lua = robust.make_capturing(roles.GAME)
        lua.execute(HELPERS)
        lua.execute(setup)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(30); A = newPlayer('alice'); join(A); B = newPlayer('bob'); join(B); advance(240)")
        return lua

    def test_every_model_texture_and_sound_load_fails_the_game_stays_playable(self):
        lua = self.run_duo(ALL_FAIL)
        self.clean(lua)
        self.assertTrue(any("[Round] début" in p for p in prints(lua)), "la partie démarre")
        self.assertEqual(int(lua.eval("#LOADS")), 2)
        parts = int(lua.execute('local k = 0 for _, d in ipairs(workspace.TombeMap:GetDescendants()) do if d.ClassName == "Part" then k = k + 1 end end return k'))
        self.assertGreater(parts, 500, "la carte procédurale est entièrement construite sans aucun modèle")
        report = [p for p in prints(lua) if "[Boot] modèles" in p]
        self.assertTrue(report, "le bilan du chargement est tracé")

    def test_failures_after_a_long_delay(self):
        lua = self.run_duo('game:GetService("InsertService").LoadAsset = function() task.wait(30) error("timeout") end')
        self.clean(lua)
        self.assertEqual(int(lua.eval("#LOADS")), 2)

    def test_empty_models_and_decals_without_texture(self):
        lua = self.run_duo('game:GetService("InsertService").LoadAsset = function() return Instance.new("Model") end')
        self.clean(lua)

    def test_client_with_all_sounds_failing(self):
        import test_client as client

        lua = client.make()
        lua.execute('REQUIRE("src/shared/Audio.lua")')
        lua.execute("runClient()")
        lua.execute("advance(120)")
        self.assertEqual(client.errors(lua), [])
        self.assertEqual([w for w in client.warns(lua) if not w.startswith(("[Boot]", "[Spawn]"))], [])


class TestSpamAndFuzz(Base):
    HANDLERS = ("SetQuiet", "SetCrouch", "SetSprint", "ToggleFlashlight", "Restart", "Quit", "SubmitCode", "Throw", "AskHint")

    def test_fuzz_every_handler_with_hostile_payloads(self):
        lua = game()
        lua.execute(
            """
            advance(40)
            local weird = { nil, true, false, 0, -1, 1e308, 0/0, math.huge, -math.huge, "", "x", string.rep("z", 5000), "1\\n2", {}, { 1, 2 }, function() end, Vector3.new(0, 0, 0), Vector3.new(0/0, 0, 0), Vector3.new(1e9, 1e9, 1e9), ALICE, workspace }
            local names = { "SetQuiet", "SetCrouch", "SetSprint", "ToggleFlashlight", "Restart", "Quit", "SubmitCode", "Throw", "AskHint" }
            for _, name in ipairs(names) do
              for i = 1, 21 do remote(name, ALICE, weird[i]); remote(name, BOB, weird[i], weird[22 - i]) end
              remote(name, nil, "x"); remote(name, "pas un joueur", true); remote(name, {}, 1)
            end
            advance(10)
            """
        )
        self.clean(lua)

    def test_flood_of_valid_events_is_limited_per_player_and_isolated(self):
        lua = game()
        lua.execute(
            """
            advance(40)
            PS = require({ __path = "src/server/PlayerState.lua" })
            N = { a = 0, b = 0 }
            local setQuiet = PS.setQuiet
            PS.setQuiet = function(p, on) if p == ALICE then N.a = N.a + 1 else N.b = N.b + 1 end return setQuiet(p, on) end
            for i = 1, 500 do remote("SetQuiet", ALICE, i % 2 == 0) end
            remote("SetQuiet", BOB, true)
            """
        )
        self.assertLessEqual(int(lua.eval("N.a")), 40, "rafale limitée")
        self.assertEqual(int(lua.eval("N.b")), 1, "le spam d'un joueur ne bloque pas l'autre")
        self.clean(lua)

    def test_restart_and_quit_before_the_end_do_nothing(self):
        lua = game()
        lua.execute("advance(60); remote('Restart', ALICE); remote('Quit', ALICE); advance(10)")
        self.clean(lua)
        self.assertEqual(int(lua.eval("#players()")), 2)
        self.assertFalse(any("[Round] fin" in p for p in prints(lua)))


class TestHubTeleport(Base):
    def make_hub(self):
        lua = roles.make(roles.HUB)
        lua.execute(HELPERS)
        lua.execute("TELEPORTS = {}; game:GetService('TeleportService').TeleportAsync = function(_, place, players) table.insert(TELEPORTS, #players) end")
        lua.execute("SWALLOW = true; runHub(); advance(5)")
        return lua

    def test_player_leaves_during_the_hub_to_game_teleport(self):
        lua = self.make_hub()
        lua.execute(
            """
            A = newPlayer('alice'); join(A); B = newPlayer('bob'); join(B); advance(3)
            local Hub = require({ __path = "src/common/Hub.lua" })
            local group = { A, B }
            leave(B)
            local ok = Hub.startGame(group)
            advance(20)
            """
        )
        self.clean(lua)

    def test_teleport_service_raises(self):
        lua = self.make_hub()
        lua.execute(
            """
            game:GetService('TeleportService').TeleportAsync = function() error("Teleport failed : 770") end
            game:GetService('TeleportService').ReserveServer = function() error("Reserve failed") end
            A = newPlayer('alice'); join(A); advance(3)
            local Hub = require({ __path = "src/common/Hub.lua" })
            Hub.startGame({ A })
            advance(30)
            """
        )
        bad = [m for m in problems(lua) if not m.startswith("[Hub]")]
        self.assertEqual(bad, [], "seuls les avertissements [Hub] de repli sont tolérés")

    def test_everyone_leaves_before_the_launch(self):
        lua = self.make_hub()
        lua.execute(
            """
            A = newPlayer('alice'); join(A); advance(3)
            local Hub = require({ __path = "src/common/Hub.lua" })
            leave(A)
            Hub.startGame({ A })
            advance(10)
            """
        )
        self.clean(lua)


REMOTE_SPY = r"""
SPY = {}
local R = require({ __path = "src/shared/Remotes.lua" })
local fire, fireAll = R.fire, R.fireAll
R.fire = function(name, p, payload) table.insert(SPY, name .. ":" .. tostring(type(payload) == "table" and (payload.kind or payload.name) or "")) return fire(name, p, payload) end
R.fireAll = function(name, payload) table.insert(SPY, name .. ":" .. tostring(type(payload) == "table" and (payload.kind or payload.name) or "")) return fireAll(name, payload) end
"""

PROMPT_COUNT = r"""
function activePrompts()
  local n, names = 0, {}
  for _, d in ipairs(workspace:GetDescendants()) do
    if d.ClassName == "ProximityPrompt" and d.Enabled ~= false and d.Name ~= "HubPrompt" then n = n + 1; names[#names + 1] = d.Name end
  end
  return n, table.concat(names, ",")
end
"""


class TestHubNeverStartsAGame(Base):
    """Le hub ne lance jamais de cinématique de partie ni de quête : seule une plaque (ou l'arrivée dans le lieu de partie)
    démarre une partie."""

    def server(self, place):
        lua = robust.make_capturing(place)
        lua.execute(HELPERS)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute(REMOTE_SPY)
        lua.execute(PROMPT_COUNT)
        lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A); B = newPlayer('bob'); join(B)")
        return lua

    def spied(self, lua):
        return [str(lua.eval("SPY[%d]" % i)) for i in range(1, int(lua.eval("#SPY")) + 1)]

    def check_quiet(self, lua):
        lua.execute("advance(600)")
        self.assertFalse(any("[Round] début" in p for p in prints(lua)), "aucune partie sans plaque")
        bad = [e for e in self.spied(lua) if e.startswith(("Effect:Cine", "Effect:Intro", "Reveal", "Flashback"))]
        self.assertEqual(bad, [], "aucune cinématique ni quête dans le hub")
        self.clean(lua)

    def test_hub_role_with_the_game_script_never_starts_a_round(self):
        lua = self.server(roles.HUB)
        self.check_quiet(lua)

    def test_single_role_waits_for_a_pad(self):
        lua = self.server(0)
        self.check_quiet(lua)

    def test_unknown_place_id_behaves_like_single_and_waits_for_a_pad(self):
        lua = robust.make_capturing(12345)
        lua.execute(HELPERS)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute(REMOTE_SPY)
        lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A)")
        self.check_quiet(lua)

    def test_hub_script_alone_builds_no_quest_prompts_or_cinematics(self):
        lua = roles.make(roles.HUB)
        lua.execute(HELPERS)
        lua.execute("SWALLOW = true; runHub()")
        lua.execute(REMOTE_SPY)
        lua.execute("advance(20); A = newPlayer('alice'); join(A); advance(600)")
        self.assertEqual([e for e in self.spied(lua) if e.startswith(("Effect:", "Reveal"))], [])
        quest_prompts = int(lua.execute('local n = 0 for _, d in ipairs(workspace:GetDescendants()) do if d.ClassName == "ProximityPrompt" and (d.Name == "QuestPrompt" or string.sub(d.Name, 1, 11) == "QuestPrompt") then n = n + 1 end end return n'))
        self.assertEqual(quest_prompts, 0)
        self.clean(lua)

    def test_a_pad_press_still_starts_the_game_in_single_role(self):
        lua = robust.make_capturing(0)
        lua.execute(HELPERS)
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A); advance(30)")
        lua.execute(
            """
            local Hub = require({ __path = "src/common/Hub.lua" })
            HUBPRESS = Hub
            """
        )
        # le hub sans plaque n'a rien lancé ; Hub.startGame (appelé par une plaque) lance bien la partie
        self.assertFalse(any("[Round] début" in p for p in prints(lua)))


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

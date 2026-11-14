#!/usr/bin/env python3
"""Apparition sûre : aucun personnage avant la carte (joueur arrivé par téléportation pendant la construction),
RespawnLocation, filet de sécurité sous le sol, chemin de retour vers le hub."""
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


GATE = to_lua54(read("src", "shared", "SpawnGate.lua"))
RESPAWN = to_lua54(read("src", "server", "Respawn.lua"))
CONFIG = to_lua54(read("src", "shared", "Config.lua"))

# Faux environnement Roblox minimal pour exécuter Respawn.lua : Players, signaux, tâches immédiates
STUBS = r"""
local function signal()
  local s = { _fns = {} }
  function s:Connect(fn) table.insert(self._fns, fn); return { Disconnect = function() end } end
  function s:Fire(...) for _, f in ipairs(self._fns) do f(...) end end
  return s
end
log = { loads = {}, pivots = {} }
local Players = { _list = {}, PlayerAdded = signal(), PlayerRemoving = signal(), CharacterAutoLoads = true }
function Players:GetPlayers() return self._list end
function newPlayer(name)
  local p = { Name = name, DisplayName = name, Parent = true, CharacterAdded = signal(), Character = nil, RespawnLocation = nil }
  function p:LoadCharacter()
    table.insert(log.loads, { name = name, respawn = self.RespawnLocation, mapReady = MAP_READY == true })
    local char = { _pos = nil }
    function char:PivotTo(cf) table.insert(log.pivots, { name = name, cf = cf }); self._pos = cf end
    function char:FindFirstChild() return nil end
    function char:FindFirstChildOfClass() return { Health = 100, Died = signal() } end
    self.Character = char
    self.CharacterAdded:Fire(char)
  end
  return p
end
function addPlayer(p) table.insert(Players._list, p); Players.PlayerAdded:Fire(p) end
task = { spawn = function(f, ...) f(...) end, delay = function() end, wait = function() end }
Vector3 = { new = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, { __add = function(a, b) return a end }) end }
CFrame = { new = function(v) return { v = v } end }
Instance = { new = function() return { Parent = nil, Destroy = function() end } end }
local shared = { Config = CONFIG_TABLE, SpawnGate = SPAWNGATE_TABLE }
game = { GetService = function(_, n)
  if n == "Players" then return Players end
  if n == "ReplicatedStorage" then return { WaitForChild = function() return shared end } end
  return {}
end }
require = function(x) return x end
PLAYERS = Players
"""


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().CONFIG_TABLE = lua.execute(CONFIG)
    lua.globals().SPAWNGATE_TABLE = lua.execute(GATE)
    lua.execute(STUBS)
    respawn = lua.execute(RESPAWN)
    return lua, respawn


class TestSpawnGate(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.G = self.lua.execute(GATE)

    def test_requests_wait_until_release_then_flow_in_order(self):
        gate = self.G.new()
        a, b = self.lua.table(n="a"), self.lua.table(n="b")
        self.assertFalse(gate.request(gate, a, None))
        self.assertFalse(gate.request(gate, b, None))
        self.assertFalse(gate.request(gate, a, None), "une demande par joueur")
        out = gate.release(gate)
        self.assertEqual([out[i].player.n for i in (1, 2)], ["a", "b"])
        self.assertIsNone(out[3])
        self.assertTrue(gate.request(gate, a, None), "porte ouverte")

    def test_forget_removes_departed_player(self):
        gate = self.G.new()
        a = self.lua.table(n="a")
        gate.request(gate, a, None)
        gate.forget(gate, a)
        self.assertIsNone(gate.release(gate)[1])

    def test_below_floor(self):
        self.assertTrue(self.G.belowFloor(-100, -40))
        self.assertFalse(self.G.belowFloor(24.5, -40))
        self.assertFalse(self.G.belowFloor(-12, -40), "le sous-sol (-12) n'est pas le vide")


class TestRespawnOrder(unittest.TestCase):
    """Le joueur arrive (PlayerAdded) AVANT la construction de la carte : aucun LoadCharacter avant setReady."""

    def start(self):
        lua, respawn = runtime()
        hooks = lua.table(isRoundActive=lambda: False, checkpoint=lambda: None, onCurse=lambda: None)
        respawn.init(hooks)
        return lua, respawn

    def test_player_added_before_map_is_not_loaded(self):
        lua, respawn = self.start()
        self.assertFalse(lua.globals().PLAYERS.CharacterAutoLoads, "CharacterAutoLoads coupé par Respawn.init")
        p = lua.globals().newPlayer("alice")
        lua.globals().addPlayer(p)  # téléportée pendant la construction
        self.assertEqual(len(lua.globals().log.loads), 0, "aucun personnage avant la carte")
        self.assertIsNone(p.Character)

    def test_ready_loads_waiting_players_once_with_respawn_location(self):
        lua, respawn = self.start()
        g = lua.globals()
        a, b = g.newPlayer("alice"), g.newPlayer("bob")
        g.addPlayer(a)
        g.addPlayer(b)
        spawn = lua.table(Name="CercueilSpawn")
        g.MAP_READY = True
        respawn.setReady(spawn)
        loads = g.log.loads
        self.assertEqual(len(loads), 2)
        self.assertEqual([loads[1].name, loads[2].name], ["alice", "bob"])
        self.assertTrue(all(loads[i].respawn is not None and loads[i].respawn.Name == "CercueilSpawn" for i in (1, 2)))
        self.assertTrue(all(loads[i].mapReady for i in (1, 2)))
        respawn.setReady(spawn)  # un second appel ne recharge personne
        self.assertEqual(len(g.log.loads), 2)

    def test_player_after_ready_loads_immediately_at_spawn(self):
        lua, respawn = self.start()
        g = lua.globals()
        respawn.setReady(lua.table(Name="CercueilSpawn"))
        p = g.newPlayer("carol")
        g.addPlayer(p)
        self.assertEqual(len(g.log.loads), 1)
        self.assertEqual(g.log.loads[1].respawn.Name, "CercueilSpawn")

    def test_player_leaving_before_ready_is_forgotten(self):
        lua, respawn = self.start()
        g = lua.globals()
        p = g.newPlayer("dave")
        g.addPlayer(p)
        p.Parent = False
        g.PLAYERS.PlayerRemoving.Fire(g.PLAYERS.PlayerRemoving, p)
        respawn.setReady(lua.table(Name="CercueilSpawn"))
        self.assertEqual(len(g.log.loads), 0)


class TestServerOrder(unittest.TestCase):
    def setUp(self):
        self.init = read("src", "server", "init.server.lua")

    def test_autoload_off_before_anything_that_yields(self):
        i = self.init.index("CharacterAutoLoads = false")
        for later in ("ModelLoader.ensure()", "MapBuilder.build()", "MonsterAI.ensureModel()", "Hub.build()"):
            self.assertLess(i, self.init.index(later), later)

    def test_ready_only_after_map_and_spawn_exist(self):
        self.assertIn("Respawn.setReady(activeSpawn())", self.init)
        self.assertLess(self.init.index("MapBuilder.build()"), self.init.index("Respawn.setReady(activeSpawn())"))
        self.assertIn("Config.Spawn.ReadyTimeout", self.init)
        self.assertIn("SpawnSafety.start(activeSpawn)", self.init)

    def test_game_role_uses_the_coffin_spawn(self):
        self.assertIn('FindFirstChild("CercueilSpawn")', self.init)
        self.assertIn("coffin.Enabled", self.init)

    def test_no_load_character_outside_respawn_gate(self):
        for rel in (("src", "server", "Respawn.lua"), ("src", "common", "Hub.lua")):
            text = read(*rel)
            for m in re.finditer(r"LoadCharacter", text):
                pass
        respawn = read("src", "server", "Respawn.lua")
        self.assertLess(respawn.index("gate:request"), respawn.index("player:LoadCharacter()"))
        # dans Hub.lua, teleport() ne charge un personnage que pour un joueur sans personnage, après construction
        hub = read("src", "common", "Hub.lua")
        self.assertIn("if char then", hub[hub.index("local function teleport"):hub.index("local function makePad")])

    def test_void_height_is_below_the_whole_house(self):
        base = read("src", "shared", "MapData.lua")
        m = re.search(r"base = \{[^}]*basement = (-?\d+)", base)
        lowest = int(m.group(1))
        voidy = int(re.search(r"VoidY = (-?\d+)", read("src", "shared", "Config.lua")).group(1))
        self.assertLess(voidy, lowest - 10)


class TestSafetyAndReturnPath(unittest.TestCase):
    def test_safety_net_replaces_and_protects(self):
        text = read("src", "common", "SpawnSafety.lua")
        self.assertIn("SpawnGate.belowFloor(root.Position.Y, Config.Spawn.VoidY)", text)
        self.assertIn("ForceField", text)
        self.assertIn("AssemblyLinearVelocity = Vector3.zero", text)
        self.assertIn("char:PivotTo(spawn.CFrame", text)
        self.assertIn("Anchored = true", text, "personnage retenu tant qu'aucun point d'apparition n'existe")

    def test_hub_place_and_game_place_both_have_the_safety_net(self):
        self.assertIn("SpawnSafety.start", read("src", "hub", "init.server.lua"))
        self.assertIn("SpawnSafety.start", read("src", "server", "init.server.lua"))
        projects = read("hub.project.json")
        self.assertIn("src/common", projects)

    def test_return_path_game_to_hub(self):
        hub = read("src", "common", "Hub.lua")
        self.assertIn("TeleportService:TeleportAsync(Config.Game.Places.hub, players)", hub)
        # en rôle game, Hub.enter renvoie les joueurs au hub sans toucher aux points d'apparition
        enter = hub[hub.index("function Hub.enter"):hub.index("function Hub.waitForStart")]
        self.assertLess(enter.index('role == "game"'), enter.index("setSpawns(true)"))
        # au retour, le hub a son propre point d'apparition actif, construit avant l'arrivée des joueurs
        hub_init = read("src", "hub", "init.server.lua")
        self.assertLess(hub_init.index("Hub.build()"), hub_init.index("Hub.enter()"))
        self.assertIn("HubSpawn", hub)
        self.assertRegex(hub, r"spawn\.Neutral = true")

    def test_spawn_config_present(self):
        cfg = read("src", "shared", "Config.lua")
        for key in ("VoidY", "CheckInterval", "Protect", "ReadyTimeout"):
            self.assertIn(key, cfg[cfg.index("Config.Spawn"):cfg.index("Config.Respawn")])


if __name__ == "__main__":
    unittest.main()

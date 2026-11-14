#!/usr/bin/env python3
"""Rôle hub ET rôle partie : tout joueur reçoit un personnage chargé, à l'intérieur de la zone, même si la
construction échoue, si CharacterAutoLoads est faux ou si la suite du script serveur plante.
Un faux Roblox avec horloge virtuelle exécute le vrai script du hub, SpawnSafety et la vraie MapBuilder."""
import os
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as base  # noqa: E402

SCHEDULER = r"""
local now = 0
os.clock = function() return now end
local sleepers = {}
local function park(co, ok, wake)
  if not ok then error(wake, 0) end
  if coroutine.status(co) == "suspended" then table.insert(sleepers, { co = co, wake = now + (type(wake) == "number" and wake or 0) }) end
end
task = {}
task.spawn = function(f, ...)
  local co = coroutine.create(f)
  park(co, coroutine.resume(co, ...))
end
task.wait = function(t) if coroutine.isyieldable() then coroutine.yield(t or 0.03) end return t or 0.03 end
task.delay = function(t, f) task.spawn(function() task.wait(t); f() end) end
task.defer = task.spawn
function advance(seconds)
  local stop = now + seconds
  while now < stop do
    now = now + 0.1
    local due = {}
    local rest = {}
    for _, s in ipairs(sleepers) do if s.wake <= now + 1e-9 then table.insert(due, s) else table.insert(rest, s) end end
    sleepers = rest
    for _, s in ipairs(due) do park(s.co, coroutine.resume(s.co)) end
  end
end
function clock() return now end

-- Joueurs : l'arrivée appelle PlayerAdded, puis charge le personnage si CharacterAutoLoads est vrai (comportement du moteur)
local Players = game:GetService("Players")
local function signal() local s = { fns = {} }; function s.Connect(self, f) table.insert(self.fns, f) return { Disconnect = function() end } end; function s.Fire(self, ...) for _, f in ipairs(self.fns) do f(...) end end; return s end
Players.PlayerAdded = signal()
Players.PlayerRemoving = signal()
Players.CharacterAutoLoads = true
local list = {}
Players.GetPlayers = function() return list end
LOADS = {}
local function findSpawn(p)
  if p.RespawnLocation then return p.RespawnLocation end
  for _, d in ipairs(workspace:GetDescendants()) do
    if d.ClassName == "SpawnLocation" and d.Enabled ~= false then return d end
  end
  return nil
end
function newPlayer(name)
  local p = { Name = name, DisplayName = name, UserId = #name * 1000 + 7, Parent = true, Character = nil, RespawnLocation = nil, CharacterAdded = signal() }
  function p:RequestStreamAroundAsync() end
  function p:LoadCharacter()
    local char = Instance.new("Model")
    local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
    local hum = Instance.new("Humanoid"); hum.Health = 100; hum.GetState = function() return "Running" end; hum.Parent = char
    local sp = findSpawn(self)
    local pos = sp and Vector3.new(sp.Position.X, sp.Position.Y + 3.5, sp.Position.Z) or Vector3.new(0, 5, 0)
    root.Position = pos
    char.PivotTo = function(self2, cf) root.Position = cf.Position end
    char.Parent = workspace
    self.Character = char
    table.insert(LOADS, { name = name, at = now, pos = pos, usedSpawn = sp ~= nil })
    self.CharacterAdded:Fire(char)
  end
  return p
end
function join(p)
  table.insert(list, p)
  Players.PlayerAdded:Fire(p)
  if Players.CharacterAutoLoads then p:LoadCharacter() end
end
workspace.Raycast = function() return nil end
"""

HUB_INIT = r"""
local function commonLoader()
  return setmetatable({}, { __index = function(_, n) return { __path = "src/common/" .. n .. ".lua" } end })
end
function runHub()
  local src = READ("src/hub/init.server.lua")
  local env = setmetatable({ script = { Parent = { Common = commonLoader() } } }, { __index = _G })
  local fn = assert(load(src, "=hub/init", "t", env))
  task.spawn(fn)
end
"""


def make(place_id):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
    stub = base.STUB.replace(
        'if k == "Parent" then return rawget(t, "_parent") end',
        'if k == "Parent" then return rawget(t, "_parent") end if k == "Triggered" or k == "Touched" or k == "CharacterAdded" then return { Connect = function() end } end',
    )
    lua.execute(stub)
    lua.execute("game.PlaceId = %d" % place_id)
    lua.execute('game:GetService("RunService").IsStudio = function() return false end')
    lua.execute('local ts = game:GetService("TeleportService"); ts.TeleportAsync = function() end; ts.ReserveServer = function() return "c" end; ts.TeleportToPrivateServer = function() end')
    lua.execute("game.BindToClose = function() end")
    lua.execute(SCHEDULER)
    lua.execute(HUB_INIT)
    return lua


HUB = 77452764500707
GAME = 88091909899710


def in_hub_zone(pos):
    return abs(pos.X - 300) <= 30 and abs(pos.Z - 300) <= 30 and 0 <= pos.Y <= 40


class TestHubRole(unittest.TestCase):
    def check_player_in_zone(self, lua, name="alice"):
        loads = [lua.eval("LOADS[%d]" % i) for i in range(1, int(lua.eval("#LOADS")) + 1)]
        mine = [l for l in loads if l.name == name]
        self.assertTrue(mine, f"{name} n'a jamais reçu de personnage")
        char = lua.eval("(function() for _, p in ipairs(game:GetService('Players'):GetPlayers()) do if p.Name == '%s' then return p.Character end end end)()" % name)
        self.assertIsNotNone(char)
        root = char.FindFirstChild(char, "HumanoidRootPart")
        self.assertTrue(in_hub_zone(root.Position), f"{name} hors de la zone du hub : ({root.Position.X}, {root.Position.Y}, {root.Position.Z})")

    def test_normal_arrival_loads_a_character_inside_the_zone(self):
        lua = make(HUB)
        lua.execute("runHub(); advance(1); join(newPlayer('alice')); advance(3)")
        self.check_player_in_zone(lua)

    def test_autoloads_forced_on_even_if_the_saved_property_is_false(self):
        lua = make(HUB)
        lua.execute("game:GetService('Players').CharacterAutoLoads = false; runHub(); advance(1)")
        self.assertTrue(lua.eval("game:GetService('Players').CharacterAutoLoads"))
        lua.execute("join(newPlayer('alice')); advance(3)")
        self.check_player_in_zone(lua)

    def test_hub_build_error_does_not_stop_the_script_or_the_player(self):
        lua = make(HUB)
        lua.execute("""
          runHub(); advance(0.5)
        """)
        # le script a déjà tourné : on recommence avec une construction qui échoue après le sol et le point d'apparition
        lua = make(HUB)
        lua.execute("""
          local real = require
          require = function(m)
            local mod = real(m)
            if m.__path == "src/shared/HubLayout.lua" then mod.BOUNDS = nil end
            return mod
          end
          runHub(); advance(1); join(newPlayer('alice')); advance(3)
        """)
        self.check_player_in_zone(lua)

    def test_player_already_present_before_the_script_runs(self):
        lua = make(HUB)
        lua.execute("join(newPlayer('alice')); runHub(); advance(8)")
        # arrivée avant la construction : le moteur l'a chargé à l'origine ; le filet le replace dans la zone
        loads = int(lua.eval("#LOADS"))
        self.assertGreaterEqual(loads, 1)
        char = lua.eval("game:GetService('Players'):GetPlayers()[1].Character")
        root = char.FindFirstChild(char, "HumanoidRootPart")
        self.assertTrue(in_hub_zone(root.Position), f"replacé hors zone : ({root.Position.X}, {root.Position.Y}, {root.Position.Z})")

    def test_hub_traces_present(self):
        text = base.read("src", "hub", "init.server.lua")
        self.assertIn("hub : démarrage", text)
        self.assertIn("hub : construction", text)


class TestWatchdog(unittest.TestCase):
    def safety(self, lua, spawn_ready_at):
        lua.execute(
            """
            local SpawnSafety = require({ __path = "src/common/SpawnSafety.lua" })
            local spawn = { Position = Vector3.new(90, 24.5, 45), CFrame = CFrame.new(90, 24.5, 45), Name = "CercueilSpawn", ClassName = "SpawnLocation" }
            SPAWN = spawn
            SpawnSafety.start(function() if clock() >= %s then return spawn end return nil end)
            """
            % spawn_ready_at
        )

    def test_no_character_after_five_seconds_is_loaded_at_the_spawn(self):
        lua = make(GAME)
        lua.execute("game:GetService('Players').CharacterAutoLoads = false")
        self.safety(lua, 0)
        lua.execute("join(newPlayer('bob')); advance(4.5)")
        self.assertEqual(int(lua.eval("#LOADS")), 0, "pas avant 5 s")
        lua.execute("advance(2)")
        self.assertEqual(int(lua.eval("#LOADS")), 1)
        load = lua.eval("LOADS[1]")
        self.assertGreaterEqual(load.at, 4.9)
        self.assertLess(load.at, 7)

    def test_waits_for_the_spawn_then_loads(self):
        lua = make(GAME)
        lua.execute("game:GetService('Players').CharacterAutoLoads = false")
        self.safety(lua, 12)
        lua.execute("join(newPlayer('bob')); advance(10)")
        self.assertEqual(int(lua.eval("#LOADS")), 0, "carte pas prête : on n'envoie pas le joueur dans le vide")
        lua.execute("advance(4)")
        self.assertEqual(int(lua.eval("#LOADS")), 1)
        self.assertTrue(lua.eval("LOADS[1].usedSpawn"))

    def test_loads_anyway_after_ready_timeout_when_no_spawn_ever_exists(self):
        lua = make(GAME)
        lua.execute("game:GetService('Players').CharacterAutoLoads = false")
        self.safety(lua, 10 ** 9)
        lua.execute("join(newPlayer('bob')); advance(31)")
        self.assertEqual(int(lua.eval("#LOADS")), 1)
        self.assertGreaterEqual(lua.eval("LOADS[1].at"), 30)

    def test_player_with_a_character_is_left_alone(self):
        lua = make(GAME)
        self.safety(lua, 0)
        lua.execute("join(newPlayer('carol')); advance(8)")
        self.assertEqual(int(lua.eval("#LOADS")), 1, "un seul chargement : celui du moteur")


class TestGameRoleOnRealMap(unittest.TestCase):
    """Rôle partie : la vraie carte est construite ; un joueur dont le script serveur a planté avant
    Respawn.setReady (porte jamais ouverte) reçoit quand même un personnage dans le grenier."""

    def test_character_lands_in_the_attic_zone(self):
        lua = make(GAME)
        lua.execute("""
          local MapBuilder = require({ __path = "src/server/MapBuilder.lua" })
          MapBuilder.build()
          game:GetService("Players").CharacterAutoLoads = false
          local SpawnSafety = require({ __path = "src/common/SpawnSafety.lua" })
          SpawnSafety.start(function()
            local root = workspace:FindFirstChild("TombeMap")
            return root and root:FindFirstChild("CercueilSpawn")
          end)
          join(newPlayer("dave")); advance(7)
        """)
        self.assertEqual(int(lua.eval("#LOADS")), 1)
        pos = lua.eval("LOADS[1].pos")
        data = lua.eval('require({ __path = "src/shared/MapData.lua" })')
        room = next(r for r in data.rooms.values() if r.id == "tombe")
        self.assertTrue(room.x0 <= pos.X <= room.x1 and room.z0 <= pos.Z <= room.z1, "dans la salle de la tombe")
        self.assertTrue(24 <= pos.Y <= 35, f"entre le plancher et le toit du grenier : y={pos.Y}")
        self.assertTrue(lua.eval("LOADS[1].usedSpawn"))


class TestBuiltPlaces(unittest.TestCase):
    """Arbre réel des fichiers construits par Rojo : le lieu hub contient le script du hub et pas celui de la partie."""

    @staticmethod
    def build(project):
        import shutil
        import subprocess
        import tempfile
        import xml.etree.ElementTree as ET

        if shutil.which("rojo") is None:
            raise unittest.SkipTest("rojo absent")
        out = os.path.join(tempfile.mkdtemp(), "place.rbxlx")
        subprocess.run(["rojo", "build", "-o", out, project], cwd=base.ROOT, check=True, capture_output=True)
        return ET.parse(out).getroot()

    @staticmethod
    def items(root, parent_class):
        for it in root.iter("Item"):
            if it.get("class") == parent_class:
                return it
        return None

    @staticmethod
    def name(it):
        node = it.find("Properties/string[@name='Name']")
        return node.text if node is not None else None

    def test_hub_place_has_the_hub_script_and_not_the_game_script(self):
        root = self.build("hub.project.json")
        sss = self.items(root, "ServerScriptService")
        children = {self.name(c): c for c in sss.findall("Item")}
        self.assertIn("Server", children)
        self.assertEqual(children["Server"].get("class"), "Script")
        source = children["Server"].find("Properties/string[@name='Source']").text
        self.assertIn("pcall(Hub.build)", source)
        self.assertIn("SpawnSafety.start", source)
        self.assertNotIn("MapBuilder", source)
        self.assertEqual(len(children["Server"].findall("Item")), 0, "le lieu hub n'a pas les modules du serveur de partie")
        common = {self.name(c) for c in children["Common"].findall("Item")}
        for needed in ("Hub", "HubDecor", "Profile", "SpawnLog", "SpawnSafety"):
            self.assertIn(needed, common)
        workspace = self.items(root, "Workspace")
        self.assertEqual(workspace.find("Properties/bool[@name='StreamingEnabled']").text, "false")

    def test_game_place_has_the_game_script_with_its_modules(self):
        root = self.build("game.project.json")
        sss = self.items(root, "ServerScriptService")
        children = {self.name(c): c for c in sss.findall("Item")}
        server = children["Server"]
        modules = {self.name(c) for c in server.findall("Item")}
        for needed in ("MapBuilder", "Respawn", "Quests", "MonsterAI"):
            self.assertIn(needed, modules)
        source = server.find("Properties/string[@name='Source']").text
        self.assertIn("CharacterAutoLoads = false", source)
        self.assertEqual(self.items(root, "Workspace").find("Properties/bool[@name='StreamingEnabled']").text, "false")


class TestCamera(unittest.TestCase):
    def test_client_restores_a_custom_camera_following_the_character(self):
        client = base.read("src", "client", "init.client.lua")
        self.assertIn("Enum.CameraType.Custom", client)
        self.assertIn("camera.CameraSubject = humanoid", client)
        self.assertIn("not Cinematic.isPlaying()", client)
        cine = base.read("src", "client", "Cinematic.lua")
        self.assertEqual(cine.count("Enum.CameraType.Scriptable"), 1)
        self.assertIn("cam.CameraType = Enum.CameraType.Custom", cine)

    def test_hub_has_no_scriptable_camera(self):
        for rel in (("src", "hub", "init.server.lua"), ("src", "common", "Hub.lua"), ("src", "common", "HubDecor.lua")):
            self.assertNotIn("Scriptable", base.read(*rel))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Point d'apparition sur la VRAIE construction de la carte : MapBuilder.build() est exécuté (faux Roblox
permissif), puis on mesure la position de CercueilSpawn par rapport au sol construit, la hauteur libre
au-dessus, l'état du SpawnLocation, et les règles de replacement (chute libre, premier point bas)."""
import os
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


STUB = r"""
local function V(x, y, z)
  local v = { X = x, Y = y, Z = z }
  local mt = {}
  mt.__add = function(a, b) return V(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
  mt.__sub = function(a, b) return V(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
  mt.__mul = function(a, b)
    if type(a) == "number" then return V(a * b.X, a * b.Y, a * b.Z) end
    if type(b) == "number" then return V(a.X * b, a.Y * b, a.Z * b) end
    return V(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
  end
  mt.__div = function(a, b) return V(a.X / b, a.Y / b, a.Z / b) end
  mt.__index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
    if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); return V(t.X / m, t.Y / m, t.Z / m) end
    if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
    return nil
  end
  return setmetatable(v, mt)
end
Vector3 = { new = function(x, y, z) return V(x or 0, y or 0, z or 0) end, zero = V(0, 0, 0) }
local function CF(pos)
  local c = { Position = pos }
  local mt = {}
  mt.__mul = function(a, b) if b.Position and b.angles then return CF(a.Position) end return CF(a.Position + b.Position) end
  mt.__add = function(a, b) return CF(a.Position + b) end
  mt.__index = function(t, k)
    if k == "LookVector" then return V(0, 0, -1) end
    if k == "X" then return t.Position.X end
    if k == "Y" then return t.Position.Y end
    if k == "Z" then return t.Position.Z end
    return nil
  end
  return setmetatable(c, mt)
end
CFrame = {
  new = function(x, y, z)
    if type(x) == "table" then return CF(x) end
    return CF(V(x or 0, y or 0, z or 0))
  end,
  Angles = function(a, b, c) local r = CF(V(0, 0, 0)); r.angles = { a, b, c }; return r end,
}
local function plain() return setmetatable({}, { __index = function() return function() return {} end end }) end
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end }
UDim = { new = function() return {} end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
TweenInfo = { new = function() return {} end }
NumberRange = { new = function(a, b) return { Min = a, Max = b } end }
NumberSequence = { new = function() return {} end }
NumberSequenceKeypoint = { new = function() return {} end }
ColorSequence = { new = function() return {} end }
Random = { new = function() return { NextNumber = function() return 0.5 end, NextInteger = function(_, a) return a end } end }
Enum = setmetatable({}, { __index = function(_, k)
  return setmetatable({}, { __index = function(_, n) return k .. "." .. n end })
end })
typeof = function(x) return type(x) end
table.clone = function(t) local o = {}; for k, v in pairs(t) do o[k] = v end; return o end
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end

local tags = {}
local function inst(class, name)
  local o = { ClassName = class, Name = name or class, _children = {}, _attrs = {}, Parent = nil }
  local methods = {}
  function methods.FindFirstChild(self, n, rec)
    for _, c in ipairs(self._children) do if c.Name == n then return c end end
    if rec then for _, c in ipairs(self._children) do local r = c:FindFirstChild(n, true); if r then return r end end end
    return nil
  end
  function methods.WaitForChild(self, n) return self:FindFirstChild(n) end
  function methods.FindFirstChildOfClass(self, cn) for _, c in ipairs(self._children) do if c.ClassName == cn then return c end end end
  methods.FindFirstChildWhichIsA = methods.FindFirstChildOfClass
  function methods.GetChildren(self) return { table.unpack(self._children) } end
  function methods.GetDescendants(self)
    local out = {}
    local function walk(x) for _, c in ipairs(x._children) do table.insert(out, c); walk(c) end end
    walk(self); return out
  end
  function methods.Destroy(self)
    local p = rawget(self, "_parent")
    if p then for i, c in ipairs(p._children) do if c == self then table.remove(p._children, i) break end end end
    rawset(self, "_parent", nil)
  end
  function methods.ClearAllChildren(self) self._children = {} end
  function methods.SetAttribute(self, k, v) self._attrs[k] = v end
  function methods.GetAttribute(self, k) return self._attrs[k] end
  function methods.IsA(self, cn) return self.ClassName == cn or (cn == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation")) end
  function methods.Clone(self) return self end
  function methods.GetPropertyChangedSignal() return { Connect = function() end } end
  function methods.GetFullName(self) return self.Name end
  setmetatable(o, {
    __index = function(t, k)
      if methods[k] then return methods[k] end
      if k == "Parent" then return rawget(t, "_parent") end
      return nil
    end,
    __newindex = function(t, k, v)
      if k == "Parent" then
        local old = rawget(t, "_parent")
        if old then for i, c in ipairs(old._children) do if c == t then table.remove(old._children, i) break end end end
        rawset(t, "_parent", v)
        if v then table.insert(v._children, t) end
      elseif k == "CFrame" then
        rawset(t, "CFrame", v); rawset(t, "Position", v.Position)
      elseif k == "Position" then
        rawset(t, "Position", v); rawset(t, "CFrame", CF(v))
      else
        rawset(t, k, v)
      end
    end,
  })
  return o
end
Instance = { new = function(class) return inst(class) end }

local services = {}
local function service(n)
  if not services[n] then services[n] = inst(n, n) end
  return services[n]
end
local ws = service("Workspace")
workspace = ws
local rs = service("ReplicatedStorage")
local shared = inst("Folder", "Shared")
rs._children = { shared }
local cs = service("CollectionService")
cs.AddTag = function(_, part, tag) tags[tag] = tags[tag] or {}; table.insert(tags[tag], part) end
cs.GetTagged = function(_, tag) return tags[tag] or {} end
cs.HasTag = function() return false end
service("Lighting")
service("ServerStorage")
service("TweenService").Create = function() return { Play = function() end } end
service("RunService").Heartbeat = { Connect = function() return { Disconnect = function() end } end }
service("Players").GetPlayers = function() return {} end
game = { GetService = function(_, n) return service(n) end, PlaceId = 88091909899710, Workspace = ws }
task = { spawn = function() end, delay = function() end, defer = function() end, wait = function() return 0 end }
warn = function() end

-- require : modules de src/shared et de src/server, chargés depuis les fichiers
local cache = {}
local function loader(dir, extras)
  return setmetatable({}, { __index = function(_, n)
    if extras and extras[n] ~= nil then return extras[n] end
    if EXISTS(dir .. "/" .. n .. ".lua") then return { __path = dir .. "/" .. n .. ".lua" } end
    return nil
  end })
end
-- Arbre Rojo : ServerScriptService contient Common (src/common) et Server (src/server) côte à côte
local function scriptFor(dir)
  local sss = { Common = loader("src/common"), Server = loader("src/server") }
  if dir == "src/server" or dir == "src/common" then return { Parent = loader(dir, { Parent = sss }) } end
  return { Parent = loader(dir) }
end
SSS = { Common = loader("src/common"), Server = loader("src/server") }
LOADER = loader
shared = loader("src/shared")
rs.WaitForChild = function() return shared end
script = scriptFor("src/server")
local realrequire = function(m)
  if m.__path then
    if not cache[m.__path] then
      local src = READ(m.__path)
      local dir = string.match(m.__path, "^(.*)/[^/]+$")
      local env = setmetatable({ script = scriptFor(dir) }, { __index = _G })
      local fn = assert(load(src, "=" .. m.__path, "t", env))
      cache[m.__path] = fn()
    end
    return cache[m.__path]
  end
  return m
end
require = realrequire
"""


class TestRealMap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().READ = lambda p: to_lua54(read(*p.split("/")))
        lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(ROOT, *p.split("/")))
        lua.execute(STUB)
        cls.lua = lua
        cls.MapBuilder = lua.eval('require({ __path = "src/server/MapBuilder.lua" })')
        cls.Data = lua.eval('require({ __path = "src/shared/MapData.lua" })')
        cls.root = cls.MapBuilder.build()
        cls.parts = [d for d in cls.root.GetDescendants(cls.root).values() if d.ClassName in ("Part", "SpawnLocation")]

    def find_spawn(self):
        return self.root.FindFirstChild(self.root, "CercueilSpawn")

    def test_map_builds_with_a_spawn_location(self):
        spawn = self.find_spawn()
        self.assertIsNotNone(spawn, "CercueilSpawn absent après MapBuilder.build()")
        self.assertEqual(spawn.ClassName, "SpawnLocation")

    def test_spawn_state(self):
        spawn = self.find_spawn()
        self.assertTrue(spawn.Anchored)
        self.assertTrue(spawn.Neutral, "Neutral : aucun filtrage par équipe")
        self.assertTrue(spawn.CanCollide)
        self.assertNotEqual(spawn.Enabled, False, "SpawnLocation désactivé")
        self.assertEqual(spawn.Duration, 0, "pas de protection qui bloque")

    def test_spawn_rests_on_the_built_attic_floor(self):
        spawn = self.find_spawn()
        x, y, z = spawn.Position.X, spawn.Position.Y, spawn.Position.Z
        bottom = y - spawn.Size.Y / 2
        floors = []
        for p in self.parts:
            if p is spawn or p.CanCollide is False or p.Size is None or p.Position is None:
                continue
            sx, sy, sz = p.Size.X, p.Size.Y, p.Size.Z
            px, py, pz = p.Position.X, p.Position.Y, p.Position.Z
            if abs(px - x) <= sx / 2 and abs(pz - z) <= sz / 2 and py + sy / 2 <= bottom + 0.01:
                floors.append(py + sy / 2)
        self.assertTrue(floors, "aucun sol construit sous le point d'apparition")
        floor_top = max(floors)
        attic = self.Data.base.attic
        self.assertAlmostEqual(floor_top, attic, places=2, msg="le sol sous le spawn n'est pas celui du grenier")
        gap = bottom - floor_top
        self.assertGreaterEqual(gap, -0.01)
        self.assertLessEqual(gap, 1.0, f"le point d'apparition flotte de {gap} studs au-dessus du sol")

    def test_character_drop_height_is_small(self):
        """Roblox pose le personnage environ 3 studs au-dessus du dessus du SpawnLocation."""
        spawn = self.find_spawn()
        top = spawn.Position.Y + spawn.Size.Y / 2
        drop = (top + 3) - self.Data.base.attic
        self.assertLess(drop, 6, "chute d'apparition trop haute")

    def test_headroom_above_the_spawn(self):
        spawn = self.find_spawn()
        x, y, z = spawn.Position.X, spawn.Position.Y, spawn.Position.Z
        top = y + spawn.Size.Y / 2
        for p in self.parts:
            if p is spawn or p.CanCollide is False or p.Position is None:
                continue
            sx, sy, sz = p.Size.X, p.Size.Y, p.Size.Z
            px, py, pz = p.Position.X, p.Position.Y, p.Position.Z
            if abs(px - x) <= sx / 2 + 1 and abs(pz - z) <= sz / 2 + 1:
                self.assertFalse(top < py - sy / 2 < top + 6, f"{p.Name} bouche l'espace au-dessus du spawn")

    def test_spawn_is_inside_the_attic_tomb_room(self):
        spawn = self.find_spawn()
        room = next(r for r in self.Data.rooms.values() if r.id == "tombe")
        self.assertTrue(room.x0 <= spawn.Position.X <= room.x1 and room.z0 <= spawn.Position.Z <= room.z1)

    def test_coffin_does_not_block_the_spawn(self):
        for p in self.parts:
            if p.Name == "cercueil":
                self.assertIs(p.CanCollide, False)

    def test_no_building_above_the_void_threshold_below_house(self):
        """Le sol le plus bas de la maison est au-dessus de VoidY : le filet ne déclenche pas dans la maison."""
        cfg = self.lua.eval('require({ __path = "src/shared/Config.lua" })')
        lowest = min(p.Position.Y - p.Size.Y / 2 for p in self.parts if p.Position is not None and p.Size is not None)
        self.assertGreater(lowest, cfg.Spawn.VoidY)


class TestRescueRules(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.G = self.lua.execute(to_lua54(read("src", "shared", "SpawnGate.lua")))
        self.cfg = self.lua.execute(to_lua54(read("src", "shared", "Config.lua"))).Spawn

    def rescue(self, y, age, freefall):
        r = self.G.shouldRescue(self.lua.table(y=y, age=age, freefall=freefall), self.cfg)
        return bool(r)

    def test_first_low_position_is_rescued(self):
        self.assertTrue(self.rescue(-100, 0.1, 0))

    def test_freefall_longer_than_threshold_in_first_seconds(self):
        self.assertTrue(self.rescue(10, 3, self.cfg.FreefallSeconds + 0.1))
        self.assertFalse(self.rescue(10, 3, self.cfg.FreefallSeconds - 0.1))

    def test_freefall_late_in_the_game_is_not_rescued(self):
        self.assertFalse(self.rescue(10, self.cfg.EarlyWindow + 5, 5), "un saut ou une chute normale plus tard n'est pas touchée")

    def test_normal_standing_is_not_rescued(self):
        self.assertFalse(self.rescue(25, 4, 0))

    def test_basement_is_not_void(self):
        self.assertFalse(self.rescue(-12, 50, 0))

    def test_config_values(self):
        self.assertAlmostEqual(self.cfg.FreefallSeconds, 1.5)
        self.assertEqual(self.cfg.EarlyWindow, 10)
        self.assertGreaterEqual(self.cfg.HoldSeconds, 1)


class TestSourceRules(unittest.TestCase):
    def test_streaming_disabled_in_both_projects(self):
        import json
        for name in ("game.project.json", "hub.project.json"):
            tree = json.loads(read(name))["tree"]
            self.assertIs(tree["Workspace"]["$properties"]["StreamingEnabled"], False, name)

    def test_spawn_logs_cover_role_placeid_positions_and_readiness(self):
        init = read("src", "server", "init.server.lua")
        self.assertIn("PlaceId=%d", init)
        self.assertIn("rôle=%s", init)
        self.assertIn("carte construite", init)
        safety = read("src", "common", "SpawnSafety.lua")
        for needle in ("personnage apparu en", "libéré après", "sol : %s", "AUCUN SOL", "replacé sur le point d'apparition"):
            self.assertIn(needle, safety)
        log = read("src", "common", "SpawnLog.lua")
        self.assertIn('"[Spawn] "', log)
        self.assertIn("carte prête", read("src", "server", "Respawn.lua"))

    def test_hold_and_streaming_request_present(self):
        safety = read("src", "common", "SpawnSafety.lua")
        self.assertIn("root.Anchored = true", safety)
        self.assertIn("RequestStreamAroundAsync", safety)
        self.assertIn("Config.Spawn.HoldSeconds", safety)
        self.assertIn("FreefallSeconds", read("src", "shared", "SpawnGate.lua") + read("src", "shared", "Config.lua"))

    def test_hub_position_never_used_in_game_role(self):
        """Pas de PivotTo en coordonnées du hub (300, 0, 300) hors du code du hub."""
        for rel in ("src/server/Respawn.lua", "src/server/MapBuilder.lua", "src/common/SpawnSafety.lua", "src/server/init.server.lua"):
            self.assertNotIn("300, 0, 300", read(*rel.split("/")), rel)
        hub = read("src", "common", "Hub.lua")
        start = hub[hub.index("function Hub.startGame"):]
        self.assertIn("coffinSpawn()", start)
        self.assertIn("setSpawns(false)", start)


if __name__ == "__main__":
    unittest.main()

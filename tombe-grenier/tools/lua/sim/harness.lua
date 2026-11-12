-- Environnement Roblox minimal pour exécuter Quests.lua hors Studio.
local M = {}

-- Fonctions de table propres à Luau
table.clone = function(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end
table.find = function(t, v)
  for i, x in ipairs(t) do if x == v then return i end end
  return nil
end

-- Vector3 / CFrame
local V = {}
V.__index = V
V.__sub = function(a, b) return M.v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function M.v3(x, y, z)
  local v = setmetatable({X = x, Y = y, Z = z}, V)
  v.Magnitude = math.sqrt(x * x + y * y + z * z)
  return v
end
Vector3 = { new = M.v3 }
local C = {}
C.__index = C
C.__mul = function(a, b) return setmetatable({Position = a.Position, angles = b.angles}, C) end
function M.cf(x, y, z) return setmetatable({Position = M.v3(x or 0, y or 0, z or 0)}, C) end
CFrame = { new = M.cf, Angles = function(x, y, z) return setmetatable({angles = {x, y, z}, Position = M.v3(0, 0, 0)}, C) end }
Color3 = { fromRGB = function() return {} end, new = function() return {} end }
UDim2 = { new = function() return {} end, fromOffset = function() return {} end, fromScale = function() return {} end }

-- Enum : n'importe quel chemin renvoie son nom
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
typeof = function(v)
  if type(v) == "table" and getmetatable(v) == V then return "Vector3" end
  return type(v)
end
task = { wait = function() end, spawn = function() end, delay = function() end }
warn = function(...) print("[warn]", ...) end

-- Instances
local Inst = {}
Inst.__index = Inst
local function setParent(child, parent)
  local old = rawget(child, "_parent")
  if old then
    for i, c in ipairs(old.children) do
      if c == child then table.remove(old.children, i) break end
    end
  end
  rawset(child, "_parent", parent)
  if parent then table.insert(parent.children, child) end
end
Inst.__newindex = function(t, k, v)
  if k == "Parent" then setParent(t, v) else rawset(t, k, v) end
end
Inst.__index = function(t, k)
  if k == "Parent" then return rawget(t, "_parent") end
  return Inst[k]
end
function Inst.SetAttribute(self, k, v) self.attrs[k] = v end
function Inst.GetAttribute(self, k) return self.attrs[k] end
function Inst.IsA(self, c)
  return c == self.ClassName or c == "Instance" or (c == "BasePart" and self.ClassName == "Part")
end
function Inst.GetChildren(self) local out = {} for i, c in ipairs(self.children) do out[i] = c end return out end
function Inst.FindFirstChild(self, n)
  for _, c in ipairs(self.children) do if c.Name == n then return c end end
  return nil
end
function Inst.FindFirstChildOfClass(self, cl)
  for _, c in ipairs(self.children) do if c.ClassName == cl then return c end end
  return nil
end
function Inst.Destroy(self) setParent(self, nil) end
function Inst.WaitForChild(self, n) return self:FindFirstChild(n) end

function M.inst(className, name)
  local o = setmetatable({ ClassName = className, Name = name or className, attrs = {}, children = {} }, Inst)
  rawset(o, "Position", M.v3(0, 0, 0))
  rawset(o, "CFrame", M.cf(0, 0, 0))
  if className == "ProximityPrompt" then
    rawset(o, "Triggered", { fns = {}, Connect = function(sig, fn) table.insert(sig.fns, fn) end })
  end
  return o
end
Instance = { new = function(cn) return M.inst(cn) end }

-- CollectionService
local tagged = {}
local CS = {}
function CS.AddTag(_, obj, tag)
  tagged[tag] = tagged[tag] or {}
  table.insert(tagged[tag], obj)
end
function CS.GetTagged(_, tag)
  local out = {}
  for i, o in ipairs(tagged[tag] or {}) do out[i] = o end
  return out
end
M.tagged = tagged

-- Remote : enregistre ce qui est envoyé
M.log = {}
local Remotes = {}
function Remotes.init() end
function Remotes.fire(name, player, payload) table.insert(M.log, { name = name, player = player, payload = payload }) end
function Remotes.fireAll(name, payload) table.insert(M.log, { name = name, all = true, payload = payload }) end
function Remotes.get() return M.inst("RemoteEvent") end

local function msgs(player)
  local out = {}
  for _, e in ipairs(M.log) do
    if e.name == "Message" and (e.player == player) then table.insert(out, e.payload.text) end
  end
  return out
end
M.msgs = msgs
function M.lastObjective()
  for i = #M.log, 1, -1 do
    if M.log[i].name == "Objective" then return M.log[i].payload.text end
  end
  return nil
end

local STUBS = {}
STUBS.Remotes = function() return Remotes end
STUBS.Noise = function() return { emit = function() end } end
STUBS.Gestures = function() return { tiltOpen = function() end, riseAndRemove = function() end, startLampSway = function() end, pullDrawer = function() end } end
STUBS.Objectives = function()
  return {
    snapshot = function() return { photos = 3, hasKey = false } end,
    unlockKey = function() end,
    init = function() end,
    setup = function() end,
  }
end
STUBS.PlayerState = function()
  return {
    get = function() return { hiding = nil, flashlightOn = false, log = {} } end,
    addBattery = function(p, n) M.battery = (M.battery or 0) + n end,
    addSanity = function(p, n) M.sanity = (M.sanity or 0) + n end,
    addThrows = function() end,
  }
end
STUBS.MapBuilder = function() return { powerOn = function() end, lampOff = function() end, roomAt = function() return nil end } end
STUBS.Audio = function() return { play = function() return M.inst("Sound") end } end

-- Services
local services = {}
services.ReplicatedStorage = { WaitForChild = function() return M.shared end }
services.CollectionService = setmetatable({}, { __index = function(_, k) return CS[k] end })
services.Workspace = M.inst("Workspace", "Workspace")
services.Debris = { AddItem = function() end }
services.Players = { GetPlayers = function() return M.players end }
services.RunService = { IsStudio = function() return true end }
game = { GetService = function(_, n) return services[n] or M.inst(n, n) end, PlaceId = 0 }

-- Les modules serveur et partagé
M.shared = {
  Config = { __path = "src/shared/Config.lua" },
  Remotes = { __path = "STUB:Remotes" },
  Rng = { __path = "src/shared/Rng.lua" },
  Audio = { __path = "STUB:Audio" },
}
script = { Parent = {
  Noise = { __path = "STUB:Noise" },
  Gestures = { __path = "STUB:Gestures" },
  Objectives = { __path = "STUB:Objectives" },
  PlayerState = { __path = "STUB:PlayerState" },
  MapBuilder = { __path = "STUB:MapBuilder" },
  Locks = { __path = "src/server/Locks.lua" },
} }
M.shared.Config.__path = "src/shared/Config.lua"

local cache = {}
function require(ref)
  local p = ref.__path
  if cache[p] == nil then
    if p:sub(1, 5) == "STUB:" then
      cache[p] = STUBS[p:sub(6)]()
    else
      cache[p] = __runfile(p)
    end
  end
  return cache[p]
end

-- Joueur et personnage
function M.player(name, x, y, z)
  local char = M.inst("Model", name)
  local root = M.inst("Part", "HumanoidRootPart")
  root.Position = M.v3(x, y, z)
  root.Parent = char
  local p = { Name = name, Character = char, DisplayName = name }
  p.Character = char
  return p
end

-- Déclenche la première invite portant ce nom sur une pièce
function M.trigger(part, promptName, player)
  for _, c in ipairs(part.children) do
    if c.ClassName == "ProximityPrompt" and c.Name == promptName then
      for _, fn in ipairs(c.Triggered.fns) do fn(player) end
      return true
    end
  end
  return false
end
function M.part(tag, x, y, z, name)
  local p = M.inst("Part", name or tag)
  p.Position = M.v3(x or 0, y or 0, z or 0)
  CS.AddTag(nil, p, tag)
  return p
end

function __runfile(p)
  local src = __readsrc(p)
  local f, err = load(src, "@" .. p)
  assert(f, err)
  return f()
end

return M

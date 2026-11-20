"""Faux Roblox CLIENT : exécute les vrais scripts client (init.client.lua, Cinematic) avec un joueur local, une interface,
des services, des signaux et une horloge virtuelle. Toute erreur d'exécution est collectée (ERRORS) avec sa pile.
Les valeurs absentes restent nil comme dans Roblox : un `attempt to index a nil value` du code est donc détecté."""
import os
import sys

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

ENV = r"""
ERRORS = {}
WARNS = {}
local now = 0
os.clock = function() return now end
os.time = function() return 1700000000 + math.floor(now) end
function clock() return now end

-- Planificateur à horloge virtuelle -----------------------------------------------------------------------------
local sleepers = {}
local function park(co, ok, wake)
  if not ok then
    table.insert(ERRORS, debug.traceback(co, tostring(wake)))
    return
  end
  if coroutine.status(co) == "suspended" then
    table.insert(sleepers, { co = co, wake = now + (type(wake) == "number" and wake or 0) })
  end
end
task = {}
task.spawn = function(f, ...)
  local co = coroutine.create(f)
  park(co, coroutine.resume(co, ...))
end
task.wait = function(t) if coroutine.isyieldable() then coroutine.yield(t or 0.03) end return t or 0.03 end
task.delay = function(t, f, ...) local args = { ... } task.spawn(function() task.wait(t); f(table.unpack(args)) end) end
task.defer = task.spawn
function advance(seconds)
  local stop = now + seconds
  while now < stop do
    now = now + 0.1
    local due, rest = {}, {}
    for _, s in ipairs(sleepers) do if s.wake <= now + 1e-9 then table.insert(due, s) else table.insert(rest, s) end end
    sleepers = rest
    for _, s in ipairs(due) do park(s.co, coroutine.resume(s.co)) end
    for _, f in ipairs(HEARTBEAT) do local ok, err = pcall(f, 0.1) if not ok then table.insert(ERRORS, "Heartbeat : " .. tostring(err)) end end
  end
end
function safe(f, ...)
  local ok, err = xpcall(f, function(e) return debug.traceback(tostring(e), 2) end, ...)
  if not ok then table.insert(ERRORS, err) end
  return ok
end
warn = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(WARNS, table.concat(t, " ")) end
typeof = function(v)
  if type(v) == "table" then
    local mt = getmetatable(v)
    if mt and mt.__type then return mt.__type end
    if rawget(v, "ClassName") then return "Instance" end
  end
  return type(v)
end
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
table.clone = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
unpack = table.unpack
-- Luau : string.split, Vector3 etc.
function string.split(s, sep) local out = {} for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end return out end

-- Signaux ---------------------------------------------------------------------------------------------------------
function newSignal()
  local s = { fns = {} }
  function s.Connect(self, f) table.insert(self.fns, f) return { Disconnect = function() end, Connected = true } end
  function s.Once(self, f) return self:Connect(f) end
  function s.Wait(self) return nil end
  function s.Fire(self, ...) for _, f in ipairs(self.fns) do safe(f, ...) end end
  return s
end
HEARTBEAT = {}

-- Types de valeur -------------------------------------------------------------------------------------------------
local V3mt = { __type = "Vector3" }
V3mt.__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) return Vector3.new(t.X / m, t.Y / m, t.Z / m) end return nil end
V3mt.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b) if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end }
Vector3.zero = Vector3.new(0, 0, 0)
local V2mt = { __type = "Vector2" }
V2mt.__index = function() return nil end
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2mt) end }
Vector2.zero = Vector2.new(0, 0)
local CFmt = { __type = "CFrame" }
CFmt.__index = function(t, k) if k == "LookVector" then return Vector3.new(0, 0, -1) end if k == "Position" then return rawget(t, "p") end if k == "Rotation" then return CFrame.new() end if k == "X" then return t.p.X end if k == "Y" then return t.p.Y end if k == "Z" then return t.p.Z end if k == "Inverse" then return function(self) return self end end return nil end
CFmt.__mul = function(a, b) if getmetatable(b) == V3mt then return Vector3.new(a.p.X + b.X, a.p.Y + b.Y, a.p.Z + b.Z) end return setmetatable({ p = Vector3.new(a.p.X + b.p.X, a.p.Y + b.p.Y, a.p.Z + b.p.Z) }, CFmt) end
CFmt.__add = function(a, b) return setmetatable({ p = a.p + b }, CFmt) end
CFrame = { new = function(x, y, z) if type(x) == "table" then return setmetatable({ p = x }, CFmt) end return setmetatable({ p = Vector3.new(x or 0, y or 0, z or 0) }, CFmt) end,
  Angles = function() return CFrame.new() end, lookAt = function(a) return CFrame.new(a.X, a.Y, a.Z) end }
local C3mt = { __type = "Color3" }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3mt) end,
  new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt) end }
local UDmt = { __type = "UDim" }
UDim = { new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDmt) end }
local U2mt = { __type = "UDim2" }
U2mt.__add = function(a, b) return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
U2mt.__sub = function(a, b) return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UDim2 = {
  new = function(xs, xo, ys, yo)
    if type(xs) == "table" then return setmetatable({ X = xs, Y = xo }, U2mt) end
    return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, U2mt)
  end,
  fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
  fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}
ColorSequence = { new = function(a, b) return { Keypoints = { a, b } } end }
NumberSequence = { new = function(a) return { a } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
TweenInfo = { new = function(t) return { Time = t } end }
Random = { new = function() return { NextNumber = function(_, a, b) return (a or 0) end, NextInteger = function(_, a) return a or 0 end } end }
Enum = setmetatable({}, { __index = function(_, enum) return setmetatable({}, { __index = function(_, item) return enum .. "." .. item end }) end })

-- Instances -------------------------------------------------------------------------------------------------------
local GUI_DEFAULTS = {
  Size = function() return UDim2.new(0, 100, 0, 100) end,
  Position = function() return UDim2.new(0, 0, 0, 0) end,
  AnchorPoint = function() return Vector2.new(0, 0) end,
  Visible = function() return true end,
  ZIndex = function() return 1 end,
  BackgroundTransparency = function() return 0 end,
  TextTransparency = function() return 0 end,
  TextStrokeTransparency = function() return 1 end,
  Text = function() return "" end,
  TextSize = function() return 14 end,
  Active = function() return false end,
}
local SIGNAL_PROPS = { Activated = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton1Click = true, Changed = true,
  ChildAdded = true, ChildRemoved = true, DescendantAdded = true, AncestryChanged = true, Destroying = true, FocusLost = true,
  InputBegan = true, InputEnded = true, InputChanged = true, Completed = true, Died = true, CharacterAdded = true,
  CharacterRemoving = true, OnClientEvent = true, Heartbeat = true, RenderStepped = true, Stepped = true, TextChanged = true }
local Imt
local function newInstance(class, name)
  local o = { ClassName = class, Name = name or class, _children = {}, _attrs = {}, _signals = {}, _parent = nil }
  return setmetatable(o, Imt)
end
local function setParent(o, p)
  local old = rawget(o, "_parent")
  if old then for i, c in ipairs(old._children) do if c == o then table.remove(old._children, i) break end end end
  rawset(o, "_parent", p)
  if p then table.insert(p._children, o) end
end
local methods = {}
function methods.FindFirstChild(self, n, rec)
  for _, c in ipairs(self._children) do if c.Name == n then return c end end
  if rec then for _, c in ipairs(self._children) do local r = c:FindFirstChild(n, true) if r then return r end end end
  return nil
end
function methods.FindFirstChildOfClass(self, cn) for _, c in ipairs(self._children) do if c.ClassName == cn then return c end end return nil end
methods.FindFirstChildWhichIsA = function(self, cn) for _, c in ipairs(self._children) do if c:IsA(cn) then return c end end return nil end
function methods.WaitForChild(self, n, timeout)
  local c = self:FindFirstChild(n)
  if c then return c end
  if timeout then return nil end
  -- Roblox attendrait pour toujours : ici c'est une erreur franche
  error("INFINITE YIELD : " .. self.Name .. ":WaitForChild(\"" .. tostring(n) .. "\") sans délai, l'enfant n'existe pas", 2)
end
function methods.GetChildren(self) local o = {} for i, c in ipairs(self._children) do o[i] = c end return o end
function methods.GetDescendants(self) local out = {} local function walk(x) for _, c in ipairs(x._children) do out[#out + 1] = c walk(c) end end walk(self) return out end
function methods.Destroy(self) setParent(self, nil) rawset(self, "_destroyed", true) end
function methods.ClearAllChildren(self) for _, c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods.SetAttribute(self, k, v) self._attrs[k] = v local s = self._signals["Attr:" .. k] if s then s:Fire() end end
function methods.GetAttribute(self, k) return self._attrs[k] end
function methods.GetAttributeChangedSignal(self, k) local key = "Attr:" .. k self._signals[key] = self._signals[key] or newSignal() return self._signals[key] end
function methods.GetPropertyChangedSignal(self, k) local key = "Prop:" .. k self._signals[key] = self._signals[key] or newSignal() return self._signals[key] end
function methods.IsA(self, cn)
  if self.ClassName == cn or cn == "Instance" then return true end
  if cn == "GuiObject" then return GUI[self.ClassName] == true end
  if cn == "BasePart" then return self.ClassName == "Part" or self.ClassName == "MeshPart" end
  return false
end
function methods.IsDescendantOf() return false end
function methods.Clone(self) return self end
function methods.GetFullName(self) return self.Name end
function methods.GetTags() return {} end
function methods.FireServer(self, ...) table.insert(FIRED, { name = self.Name, args = { ... } }) end
function methods.CaptureFocus() end
function methods.ReleaseFocus() end
function methods.Play() end
function methods.Stop() end
function methods.Pause() end
function methods.Resume() end
function methods.TweenSize() end
function methods.TweenPosition() end
GUI = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true }
FIRED = {}
Imt = {
  __index = function(t, k)
    local m = methods[k]
    if m then return m end
    if k == "Parent" then return rawget(t, "_parent") end
    if type(k) == "string" then
      for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
      if SIGNAL_PROPS[k] then
        local sigs = rawget(t, "_signals")
        sigs[k] = sigs[k] or newSignal()
        return sigs[k]
      end
      if GUI[rawget(t, "ClassName")] and GUI_DEFAULTS[k] then return GUI_DEFAULTS[k]() end
    end
    return nil
  end,
  __newindex = function(t, k, v)
    if k == "Parent" then setParent(t, v) return end
    if k == "Name" or k == "ClassName" then rawset(t, k, v) return end
    rawset(t, k, v)
    local s = rawget(t, "_signals")["Prop:" .. tostring(k)]
    if s then s:Fire() end
  end,
}
Instance = { new = function(class)
  local o = newInstance(class)
  if class == "RemoteEvent" then o.OnClientEvent = newSignal() end
  return o
end }

-- Services --------------------------------------------------------------------------------------------------------
local services = {}
local function service(n) if not services[n] then services[n] = newInstance(n, n) end return services[n] end
local rs = service("ReplicatedStorage")
local players = service("Players")
local playerGui = newInstance("PlayerGui", "PlayerGui")
LOCAL = newInstance("Player", "Joueur")
LOCAL.UserId = 4242
LOCAL.PlayerGui = playerGui
LOCAL.CharacterAdded = newSignal()
LOCAL.CameraMode = nil
function LOCAL.GetAttribute(self, k) return self._attrs[k] end
function LOCAL.WaitForChild(self, n, timeout) if n == "PlayerGui" then return playerGui end return methods.WaitForChild(self, n, timeout) end
function LOCAL.GetMouse() return { X = 0, Y = 0, Hit = CFrame.new(), Target = nil } end
players.LocalPlayer = LOCAL
players.PlayerAdded = newSignal()
players.PlayerRemoving = newSignal()
function players.GetPlayers() return { LOCAL } end
-- personnage du joueur
local char = newInstance("Model", "Joueur")
local hrp = newInstance("Part", "HumanoidRootPart"); hrp.Position = Vector3.new(90, 27.5, 45); hrp.CFrame = CFrame.new(90, 27.5, 45); hrp.Parent = char
local head = newInstance("Part", "Head"); head.Position = Vector3.new(90, 29, 45); head.CFrame = CFrame.new(90, 29, 45); head.Parent = char
local hum = newInstance("Humanoid", "Humanoid"); hum.Health = 100; hum.MaxHealth = 100; hum.WalkSpeed = 8; hum.Died = newSignal(); hum.Parent = char
char.Parent = nil
LOCAL.Character = char
CHAR = char

local cam = newInstance("Camera", "CurrentCamera")
cam.ViewportSize = Vector2.new(1280, 720)
cam.CFrame = CFrame.new(90, 29, 45)
cam.CameraType = "Enum.CameraType.Custom"
cam.FieldOfView = 70
cam.CameraSubject = hum
local ws = service("Workspace")
ws.CurrentCamera = cam
function ws.Raycast() return nil end
ws.Gravity = 196.2

local uis = service("UserInputService")
uis.InputBegan = newSignal(); uis.InputEnded = newSignal(); uis.InputChanged = newSignal()
uis.TouchEnabled = false; uis.KeyboardEnabled = true; uis.GamepadEnabled = false; uis.MouseEnabled = true
uis.MouseBehavior = "Enum.MouseBehavior.Default"; uis.MouseIconEnabled = true
function uis.GetLastInputType() return "Enum.UserInputType.Keyboard" end
function uis.IsKeyDown() return false end
function uis.GetMouseLocation() return Vector2.new(0, 0) end
local run = service("RunService")
run.Heartbeat = { Connect = function(_, f) table.insert(HEARTBEAT, f) return { Disconnect = function() end } end, Wait = function() task.wait(0.03) return 0.03 end }
run.RenderStepped = run.Heartbeat
run.Stepped = run.Heartbeat
function run.IsStudio() return false end
function run.IsClient() return true end
function run.IsServer() return false end
local tween = service("TweenService")
function tween.Create(_, obj, info, goals)
  return { Play = function() for k, v in pairs(goals) do rawset(obj, k, v) end end, Cancel = function() end, Completed = newSignal() }
end
local cs = service("CollectionService")
function cs.GetTagged() return {} end
function cs.GetInstanceAddedSignal() return newSignal() end
function cs.GetInstanceRemovedSignal() return newSignal() end
function cs.HasTag() return false end
local lighting = service("Lighting")
lighting.Ambient = Color3.new(0, 0, 0); lighting.Brightness = 1; lighting.ClockTime = 12
local sound = service("SoundService")
function sound.PlayLocalSound() end
local guiService = service("GuiService")
local starter = service("StarterGui")
function starter.SetCore() end
function starter.SetCoreGuiEnabled() end
local debris = service("Debris")
function debris.AddItem() end
local http = service("HttpService")
function http.GenerateGUID() return "guid" end
local ctx = service("ContextActionService")
function ctx.BindAction() end
function ctx.UnbindAction() end
local marketplace = service("MarketplaceService")
function marketplace.PromptProductPurchase() end
function marketplace.PromptGamePassPurchase() end
local tp = service("TeleportService")
game = { PlaceId = 88091909899710, JobId = "job", GetService = function(_, n) return service(n) end, Workspace = ws }
workspace = ws
function game.IsLoaded() return true end
LocalPlayerInstance = LOCAL

-- Remotes : le serveur les a créés (même liste que Remotes.init)
function createRemotes()
  local Remotes = REQUIRE("src/shared/Remotes.lua")
  Remotes.init()
end

-- Chargement des modules : les vrais fichiers, avec `script` résolu comme dans l'arbre Rojo -------------------------
local cache = {}
local sharedFolder = newInstance("Folder", "Shared")
rs._children = { sharedFolder }
local function loader(dir)
  return setmetatable({}, { __index = function(_, n)
    if EXISTS(dir .. "/" .. n .. ".lua") then return { __path = dir .. "/" .. n .. ".lua" } end
    return nil
  end })
end
function REQUIRE(path)
  if cache[path] == nil then
    local src = READ(path)
    local dir = path:match("^(.*)/[^/]+$")
    local env = setmetatable({ script = { Parent = loader(dir), Name = "script" } }, { __index = _G })
    local fn, err = load(src, "=" .. path, "t", env)
    if not fn then error("syntaxe : " .. tostring(err)) end
    cache[path] = fn()
  end
  return cache[path]
end
rs.WaitForChild = function(self, n, timeout)
  if n == "Shared" then return loader("src/shared") end
  return methods.WaitForChild(self, n, timeout)
end
require = function(m) if m.__path then return REQUIRE(m.__path) end return m end

function runClient()
  local src = READ("src/client/init.client.lua")
  local siblings = loader("src/client")
  local env = setmetatable({ script = setmetatable({ Parent = nil }, { __index = function(_, n) return siblings[n] end }) }, { __index = _G })
  local fn, err = load(src, "=client/init", "t", env)
  if not fn then error("syntaxe : " .. tostring(err)) end
  task.spawn(fn)
end

function remote(name)
  local folder = rs:FindFirstChild("Remotes")
  return folder and folder:FindFirstChild(name)
end
function serverFire(name, payload)
  local r = remote(name)
  if not r then error("remote absent : " .. name) end
  r.OnClientEvent:Fire(payload)
end
function keyDown(code, kind)
  uis.InputBegan:Fire({ KeyCode = code, UserInputType = kind or "Enum.UserInputType.Keyboard" }, false)
end
function keyUp(code)
  uis.InputEnded:Fire({ KeyCode = code, UserInputType = "Enum.UserInputType.Keyboard" }, false)
end
function findGui(name) for _, d in ipairs(playerGui:GetDescendants()) do if d.Name == name then return d end end return nil end
function guiCount() return #playerGui:GetDescendants() end
"""


def make(place_scripts=True):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().READ = lambda p: to_lua54(open(os.path.join(ROOT, *p.split("/")), encoding="utf-8").read())
    lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(ROOT, *p.split("/")))
    lua.execute(ENV)
    lua.execute("createRemotes()")
    return lua


def errors(lua):
    n = int(lua.eval("#ERRORS"))
    return [str(lua.eval("ERRORS[%d]" % i)) for i in range(1, n + 1)]


def warns(lua):
    n = int(lua.eval("#WARNS"))
    return [str(lua.eval("WARNS[%d]" % i)) for i in range(1, n + 1)]

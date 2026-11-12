-- roblox_mock.lua : mini-moteur Roblox pour exécuter réellement le code serveur ET client dans une VM Lua.
-- Objectif : détecter les erreurs d'exécution (nil, mauvais noms de fonctions, mauvais flux) sans Roblox Studio.
-- Ce n'est PAS le vrai moteur : la physique, le rendu et les contraintes d'API exactes ne sont pas reproduits.

math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local M = { errors = {}, now = 0, baseTime = 1700000000, isStudio = false }

----------------------------------------------------------------------
-- Signaux
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local function newSignal() return setmetatable({ conns = {}, waiters = {} }, Signal) end
function Signal:Connect(fn)
	local c = { fn = fn, connected = true }
	function c:Disconnect() self.connected = false end
	table.insert(self.conns, c)
	return c
end
function Signal:Once(fn)
	local c; c = self:Connect(function(...) c:Disconnect(); fn(...) end)
	return c
end
function Signal:Wait()
	local co = coroutine.running()
	table.insert(self.waiters, co)
	return coroutine.yield()
end
local function protected(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(M.errors, tostring(err) .. "\n" .. debug.traceback(co))
	end
end
function Signal:Fire(...)
	local list = {}
	for _, c in ipairs(self.conns) do if c.connected then table.insert(list, c) end end
	for _, c in ipairs(list) do protected(c.fn, ...) end
	local w = self.waiters
	self.waiters = {}
	for _, co in ipairs(w) do
		local ok, err = coroutine.resume(co, ...)
		if not ok then table.insert(M.errors, tostring(err)) end
	end
end
M.newSignal = newSignal

----------------------------------------------------------------------
-- Planificateur (temps virtuel)
----------------------------------------------------------------------
local sleepers = {}
task = {}
function task.spawn(fn, ...) protected(fn, ...) end
function task.defer(fn, ...) protected(fn, ...) end
function task.wait(t)
	t = t or 1 / 30
	local co = coroutine.running()
	assert(co and coroutine.isyieldable(), "task.wait appelé hors coroutine")
	table.insert(sleepers, { t = M.now + t, co = co })
	coroutine.yield()
	return t
end
function task.delay(t, fn, ...)
	local args = { ... }
	protected(function()
		task.wait(t)
		fn(table.unpack(args))
	end)
end
os.clock = function() return M.now end
os.time = function() return M.baseTime + math.floor(M.now) end

warn = function(...) M.warnings = M.warnings or {}; table.insert(M.warnings, table.concat({ ... }, " ")) end
local Heartbeat, RenderStepped = newSignal(), newSignal()
function M.advance(seconds, step)
	step = step or 1 / 30
	local target = M.now + seconds
	while M.now < target - 1e-9 do
		M.now = M.now + step
		Heartbeat:Fire(step)
		RenderStepped:Fire(step)
		local due = {}
		local rest = {}
		for _, s in ipairs(sleepers) do
			if s.t <= M.now + 1e-9 then table.insert(due, s) else table.insert(rest, s) end
		end
		sleepers = rest
		table.sort(due, function(a, b) return a.t < b.t end)
		for _, s in ipairs(due) do
			local ok, err = coroutine.resume(s.co)
			if not ok then table.insert(M.errors, tostring(err) .. "\n" .. debug.traceback(s.co)) end
		end
	end
end

----------------------------------------------------------------------
-- Maths : Vector3, CFrame, Color3, UDim...
----------------------------------------------------------------------
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return t end return setmetatable({ X = t.X / m, Y = t.Y / m, Z = t.Z / m }, V3) end
	return V3[k]
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
Vector3 = { new = v3, zero = v3(0, 0, 0) }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
UDim2 = {
	new = function(a, b, c, d) return { a = a, b = b, c = c, d = d } end,
	fromOffset = function(x, y) return { offset = { x, y } } end,
	fromScale = function(x, y) return { scale = { x, y } } end,
}
local C3 = {}
C3.__index = function(t, k) if k == "ToHex" then return function(self) return string.format("%02x%02x%02x", math.floor(self.R * 255 + .5), math.floor(self.G * 255 + .5), math.floor(self.B * 255 + .5)) end end return C3[k] end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end,
	fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3) end,
	fromHSV = function(h, s, v) return setmetatable({ R = v, G = v * (1 - s), B = v * (1 - s) }, C3) end,
}
NumberRange = { new = function(a, b) return { a, b } end }
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(a, b) return { a, b } end }
ColorSequence = { new = function(...) return { ... } end }
TweenInfo = { new = function(t) return { Time = t or 1 } end }
Font = {}

-- CFrame (matrice 3x3 + position)
local CF = {}
local function cf(p, r) return setmetatable({ p = p, r = r }, CF) end
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mmul(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
	end end
	return o
end
local function rot(r, v) return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
CF.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "LookVector" then return rot(t.r, v3(0, 0, -1)) end
	if k == "RightVector" then return rot(t.r, v3(1, 0, 0)) end
	if k == "UpVector" then return rot(t.r, v3(0, 1, 0)) end
	if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(a.p + rot(a.r, b.p), mmul(a.r, b.r)) end
	return a.p + rot(a.r, b) -- CFrame * Vector3
end
function CF.PointToWorldSpace(a, v) return a.p + rot(a.r, v) end
function CF.ToEulerAnglesYXZ(a)
	local r = a.r
	return math.asin(math.max(-1, math.min(1, -r[6]))), math.atan2(r[3], r[9]), math.atan2(r[4], r[5])
end
function CF.Inverse(a)
	local r = a.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	return cf(rot(rt, -a.p), rt)
end
CFrame = {
	new = function(x, y, z)
		if x == nil then return cf(v3(0, 0, 0), I3) end
		if type(x) == "table" then return cf(x, I3) end
		return cf(v3(x, y, z), I3)
	end,
	Angles = function(rx, ry, rz)
		local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
		local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
		local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
		local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
		return cf(v3(0, 0, 0), mmul(mmul(Z, Y), X))
	end,
	lookAt = function(at, target)
		local look = (target - at)
		look = look.Unit
		-- right = look x up(0,1,0) ; up = right x look
		local up = v3(0, 1, 0)
		local rx = look.Y * up.Z - look.Z * up.Y
		local ry = look.Z * up.X - look.X * up.Z
		local rz = look.X * up.Y - look.Y * up.X
		local rv = v3(rx, ry, rz)
		if rv.Magnitude < 1e-6 then rv = v3(1, 0, 0) end
		rv = rv.Unit
		local uv = v3(rv.Y * look.Z - rv.Z * look.Y, rv.Z * look.X - rv.X * look.Z, rv.X * look.Y - rv.Y * look.X)
		-- colonnes : right, up, -look
		return cf(at, { rv.X, uv.X, -look.X, rv.Y, uv.Y, -look.Y, rv.Z, uv.Z, -look.Z })
	end,
}
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.clamp = function(x, lo, hi) return math.max(lo, math.min(hi, x)) end
table.find = table.find or function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
local sunpack = table.unpack
unpack = sunpack

----------------------------------------------------------------------
-- Enum (proxy : Enum.Material.Wood -> "Material.Wood")
----------------------------------------------------------------------
Enum = setmetatable({}, { __index = function(t, k)
	local e = setmetatable({}, { __index = function(_, n) return k .. "." .. tostring(n) end })
	rawset(t, k, e)
	return e
end })

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------
local SIGNALS = {}
for _, n in ipairs({ "Touched", "TouchEnded", "Triggered", "MouseClick", "Activated", "MouseButton1Down", "MouseButton1Up", "MouseLeave", "MouseEnter",
	"InputEnded", "InputBegan", "Completed", "ChildAdded", "Changed", "OnServerEvent", "OnClientEvent", "PlayerAdded", "PlayerRemoving",
	"CharacterAdded", "PromptGamePassPurchaseFinished", "Destroying" }) do SIGNALS[n] = true end

local BASEPARTS = { Part = true, SpawnLocation = true, WedgePart = true, MeshPart = true }
local Methods = {}
local InstMT = {}
local function inst(class)
	local o = setmetatable({ __class = class, __props = {}, __children = {}, __attrs = {}, __signals = {}, __destroyed = false }, InstMT)
	o.__props.Name = class
	return o
end
InstMT.__index = function(t, k)
	local props = rawget(t, "__props")
	if k == "ClassName" then return rawget(t, "__class") end
	if k == "Parent" then return props.Parent end
	if Methods[k] then return Methods[k] end
	if props[k] ~= nil then return props[k] end
	if k == "Position" and props.CFrame then return props.CFrame.p end
	if SIGNALS[k] then
		local s = rawget(t, "__signals")
		if not s[k] then s[k] = newSignal() end
		return s[k]
	end
	for _, c in ipairs(rawget(t, "__children")) do
		if c.__props.Name == k then return c end
	end
	return nil
end
InstMT.__newindex = function(t, k, v)
	local props = rawget(t, "__props")
	if k == "Parent" then
		if rawget(t, "__destroyed") and v ~= nil then
			error("The Parent property of " .. tostring(props.Name) .. " is locked because the current thread cannot access it (instance détruite)")
		end
		local old = props.Parent
		if old then
			for i, c in ipairs(old.__children) do if c == t then table.remove(old.__children, i) break end end
		end
		props.Parent = v
		if v then table.insert(v.__children, t); if v.__signals.ChildAdded then v.__signals.ChildAdded:Fire(t) end end
	elseif k == "Position" and BASEPARTS[rawget(t, "__class")] then
		props.CFrame = CFrame.new(v)
	else
		props[k] = v
	end
end
function Methods.IsA(self, cls)
	local c = self.__class
	if c == cls then return true end
	if cls == "BasePart" then return BASEPARTS[c] == true end
	if cls == "Instance" then return true end
	return false
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(self.__children) do if c.__props.Name == name then return c end end
	if recursive then
		for _, c in ipairs(self.__children) do local r = c:FindFirstChild(name, true); if r then return r end end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(self.__children) do if c.__class == cls then return c end end
end
function Methods.FindFirstChildWhichIsA(self, cls)
	for _, c in ipairs(self.__children) do if c:IsA(cls) then return c end end
end
function Methods.WaitForChild(self, name)
	local c = self:FindFirstChild(name)
	if c then return c end
	error("WaitForChild('" .. name .. "') : enfant introuvable sous " .. tostring(self.__props.Name))
end
function Methods.GetChildren(self) local l = {}; for i, c in ipairs(self.__children) do l[i] = c end return l end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(n) for _, c in ipairs(n.__children) do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function Methods.ClearAllChildren(self)
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
end
function Methods.Destroy(self)
	self.__destroyed = true
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
	self.Parent = nil
end
function Methods.SetAttribute(self, k, v) self.__attrs[k] = v end
function Methods.GetAttribute(self, k) return self.__attrs[k] end
function Methods.GetPropertyChangedSignal(self, k) return newSignal() end
function Methods.PivotTo(self, c)
	self.__pivot = c
	local hrp = self:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = c end
end
function Methods.GetPivot(self) return self.__pivot or CFrame.new() end
function Methods.GetBoundingBox(self)
	local mn, mx
	for _, d in ipairs(self:GetDescendants()) do
		if BASEPARTS[d.__class] and d.CFrame and d.Size then
			local p, s = d.CFrame.p, d.Size
			local lo = v3(p.X - s.X / 2, p.Y - s.Y / 2, p.Z - s.Z / 2)
			local hi = v3(p.X + s.X / 2, p.Y + s.Y / 2, p.Z + s.Z / 2)
			mn = mn and v3(math.min(mn.X, lo.X), math.min(mn.Y, lo.Y), math.min(mn.Z, lo.Z)) or lo
			mx = mx and v3(math.max(mx.X, hi.X), math.max(mx.Y, hi.Y), math.max(mx.Z, hi.Z)) or hi
		end
	end
	if not mn then return CFrame.new(), v3(1, 1, 1) end
	return CFrame.new((mn + mx) / 2), mx - mn
end
function Methods.FireClient(self, player, ...) self.OnClientEvent:Fire(...) end
function Methods.FireServer(self, ...) self.OnServerEvent:Fire(M.localPlayer, ...) end
function Methods.Emit() end
function Methods.BindAction(self, name, fn) M.boundActions = M.boundActions or {} M.boundActions[name] = fn end
function Methods.Play() end

Instance = { new = function(class)
	local o = inst(class)
	if class == "Model" then o.__pivot = CFrame.new() end
	if BASEPARTS[class] then o.__props.CFrame = CFrame.new(); o.__props.Size = v3(4, 1, 2) end
	return o
end }
M.inst = inst

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
local services = {}
local function service(name) local s = inst(name); s.__props.Name = name; services[name] = s; return s end

local Players = service("Players")
Players.__players = {}
function Methods.GetPlayers(self) return { table.unpack(self.__players) } end
function Methods.GetPlayerFromCharacter(self, model)
	for _, p in ipairs(self.__players) do if p.Character == model then return p end end
end
function Methods.GetPlayerByUserId(self, id)
	for _, p in ipairs(self.__players) do if p.UserId == id then return p end end
end
function Methods.GetNameFromUserIdAsync(self, id) return "User" .. id end

local Workspace = service("Workspace")
Workspace.CurrentCamera = inst("Camera")
Workspace.CurrentCamera.__props.CFrame = CFrame.new(0, 50, 0)
Workspace.CurrentCamera.__props.ViewportSize = Vector2.new(1280, 720)
workspace = Workspace
local RS = service("ReplicatedStorage")
local SSS = service("ServerScriptService")
local SP = service("StarterPlayer")
local SPS = inst("StarterPlayerScripts"); SPS.Parent = SP
local Lighting = service("Lighting")
local TweenService = service("TweenService")
function Methods.Create(self, target, info, goal)
	local tw = { Completed = newSignal() }
	function tw:Play()
		for k, v in pairs(goal) do target[k] = v end
		task.delay(info.Time or 0.1, function() tw.Completed:Fire() end)
	end
	return tw
end
local RunService = service("RunService")
RunService.Heartbeat = Heartbeat
RunService.RenderStepped = RenderStepped
function Methods.IsStudio() return M.isStudio ~= false end
function Methods.IsServer() return true end
service("SoundService")
service("StarterGui")
function Methods.SetCoreGuiEnabled() end

-- DataStore en mémoire
local stores = {}
M.dsFail = 0
local function deep(t) if type(t) ~= "table" then return t end local c = {} for k, v in pairs(t) do c[k] = deep(v) end return c end
local function mkStore(name)
	local s = { data = {} }
	local function guard() if M.dsFail > 0 then M.dsFail = M.dsFail - 1 error("DataStore indisponible (simulé)") end end
	function s:UpdateAsync(key, fn)
		guard()
		local newv = fn(deep(self.data[key]))
		if newv ~= nil then self.data[key] = deep(newv) end
		return self.data[key]
	end
	function s:GetAsync(key) guard() return deep(self.data[key]) end
	function s:SetAsync(key, v) guard() self.data[key] = v end
	function s:GetSortedAsync(asc, n)
		local list = {}
		for k, v in pairs(self.data) do table.insert(list, { key = k, value = v }) end
		table.sort(list, function(a, b) if asc then return a.value < b.value end return a.value > b.value end)
		local page = {}
		for i = 1, math.min(n, #list) do page[i] = list[i] end
		return { GetCurrentPage = function() return page end }
	end
	return s
end
local DSS = service("DataStoreService")
function Methods.GetDataStore(self, name) stores[name] = stores[name] or mkStore(name) return stores[name] end
function Methods.GetOrderedDataStore(self, name) stores["o_" .. name] = stores["o_" .. name] or mkStore(name) return stores["o_" .. name] end
M.stores = stores

local Market = service("MarketplaceService")
Market.PromptGamePassPurchaseFinished = newSignal()
function Methods.UserOwnsGamePassAsync() return false end
function Methods.PromptGamePassPurchase(self, p, id) M.lastPrompt = { "pass", id } end
function Methods.PromptProductPurchase(self, p, id) M.lastPrompt = { "product", id } end

Random = { new = function(seed)
	local state = (seed or 42) % 2147483647
	if state <= 0 then state = 42 end
	local r = {}
	local function nextf() state = (state * 48271) % 2147483647 return state / 2147483647 end
	function r:NextNumber(a, b) local f = nextf() if a then return a + f * (b - a) end return f end
	function r:NextInteger(a, b) return a + math.floor(nextf() * (b - a + 1)) end
	return r
end }

local game_ = inst("DataModel")
game_.JobId = "job-1"
game = game_
game_.__props.JobId = "job-1"
function Methods.GetService(self, name) return services[name] or service(name) end
local closeFns = {}
function Methods.BindToClose(self, fn) table.insert(closeFns, fn) end
function M.shutdown() for _, fn in ipairs(closeFns) do protected(fn) end end
-- le DataModel doit exposer les services par nom
local gmt = getmetatable(game_)
game_.__children = {}
for n, s in pairs(services) do s.Parent = game_ end

----------------------------------------------------------------------
-- Modules : chargement et require
----------------------------------------------------------------------
function M.addFolder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end
function M.addScript(parent, name, src, class)
	local s = Instance.new(class or "ModuleScript")
	s.Name = name
	s.__src = src
	s.Parent = parent
	return s
end
local function runScript(s)
	local env = setmetatable({ script = s }, { __index = _G })
	local fn, err = load(s.__src, "=" .. s.__props.Name, "t", env)
	if not fn then error("Syntaxe : " .. tostring(err)) end
	return fn()
end
function require(s)
	if type(s) ~= "table" or not s.__src then error("require : module invalide") end
	if s.__loaded == nil then
		s.__loaded = true
		s.__result = runScript(s)
	end
	return s.__result
end
function M.runScript(s)
	protected(function() runScript(s) end)
end

-- Joueur factice
function M.newPlayer(userId, name)
	local p = Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	p.Kicked = nil
	function p:Kick(msg) p.Kicked = msg; M.leave(p) end
	p.PlayerGui = Instance.new("PlayerGui")
	p.PlayerGui.Parent = p
	p.Parent = Players
	table.insert(Players.__players, p)
	return p
end
function M.spawnCharacter(p, pos)
	local m = Instance.new("Model")
	m.Name = p.Name
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = CFrame.new(pos or v3(0, 5, 60))
	hrp.Parent = m
	local hum = Instance.new("Humanoid")
	hum.WalkSpeed = 16
	hum.Parent = m
	m.Parent = Workspace
	p.Character = m
	p.CharacterAdded:Fire(m)
	return m
end
function M.join(p) Players.PlayerAdded:Fire(p) end
function M.leave(p)
	for i, x in ipairs(Players.__players) do if x == p then table.remove(Players.__players, i) break end end
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end
M.Players = Players
M.Workspace = Workspace
M.RS = RS
M.SSS = SSS
M.SPS = SPS
M.services = services
return M

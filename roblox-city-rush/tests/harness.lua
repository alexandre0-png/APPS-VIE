-- Faux environnement Roblox minimal pour exécuter la logique serveur de CITY RUSH sous Lua (lupa).
-- Pas de rendu ni de physique : on simule Instance, services, signaux, scheduler de tâches, DataStore.
local H = {}
local ROOT = ROOT_DIR -- injecté par run.py

-- ---------------------------------------------------------------- scheduler
local now = 0
local queue = {}
local function schedule(co, at) queue[#queue + 1] = { co = co, at = at } end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then H.errors[#H.errors + 1] = tostring(err) end
end
H.errors = {}
local task = {}
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local args = table.pack(...)
	local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end)
	schedule(co, now)
end
function task.delay(t, fn, ...)
	local args = table.pack(...)
	local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end)
	schedule(co, now + (t or 0))
end
function task.wait(t)
	t = t or 0.03
	local co = coroutine.running()
	if not co then error("task.wait hors coroutine") end
	schedule(co, now + t)
	coroutine.yield()
	return t
end
function H.advance(dt, step)
	step = step or 0.05
	local target = now + dt
	while true do
		local best, bi
		for i, q in ipairs(queue) do
			if q.at <= target and (not best or q.at < best.at) then best, bi = q, i end
		end
		if not best then break end
		table.remove(queue, bi)
		if best.at > now then now = best.at end
		if coroutine.status(best.co) == "suspended" then resume(best.co) end
	end
	now = target
end
function H.now() return now end

-- ---------------------------------------------------------------- signaux
local Signal = {}
Signal.__index = Signal
local function newSignal() return setmetatable({ h = {} }, Signal) end
function Signal:Connect(fn)
	local rec = { fn = fn, on = true }
	self.h[#self.h + 1] = rec
	return { Disconnect = function() rec.on = false end, Connected = true }
end
function Signal:Once(fn) local c; c = self:Connect(function(...) c.Disconnect(); fn(...) end); return c end
function Signal:Fire(...)
	for _, r in ipairs({ table.unpack(self.h) }) do
		if r.on then task.spawn(r.fn, ...) end
	end
end
function Signal:Wait() error("Signal:Wait non simulé") end
H.newSignal = newSignal

-- ---------------------------------------------------------------- types math
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return t end; return V3.new(t.X / m, t.Y / m, t.Z / m) end
	return V3[k]
end
function V3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return V3.new(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return V3.new(a.X * b, a.Y * b, a.Z * b) end
	return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return V3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end
V3.zero = V3.new(0, 0, 0)
V3.xAxis, V3.yAxis, V3.zAxis = V3.new(1, 0, 0), V3.new(0, 1, 0), V3.new(0, 0, 1)

local CF = {}
CF.__index = function(t, k)
	if k == "Position" then return t._p end
	if k == "LookVector" then return V3.new(0, 0, -1) end
	if k == "RightVector" then return V3.new(1, 0, 0) end
	if k == "UpVector" then return V3.new(0, 1, 0) end
	return CF[k]
end
function CF.new(x, y, z)
	if type(x) == "table" then return setmetatable({ _p = x }, CF) end
	return setmetatable({ _p = V3.new(x or 0, y or 0, z or 0) }, CF)
end
function CF.lookAt(a) return CF.new(a) end
function CF.Angles() return CF.new(0, 0, 0) end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return a._p + b end
	return CF.new(a._p + (b._p or V3.zero))
end
CF.__add = function(a, v) return CF.new(a._p + v) end
CF.__sub = function(a, v) return CF.new(a._p - v) end

local function auto(name)
	local t = {}
	return setmetatable(t, {
		__index = function(_, k) return auto(tostring(name) .. "." .. tostring(k)) end,
		__call = function() return auto(tostring(name) .. "()") end,
		__tostring = function() return "<" .. tostring(name) .. ">" end,
	})
end
H.auto = auto

local Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
local Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, k2) return "Enum." .. k .. "." .. k2 end }) end })

-- ---------------------------------------------------------------- Instance
local Instance = {}
local Obj = {}
local EVENTS = { Triggered = 1, Touched = 1, Died = 1, Seated = 1, Running = 1, OnServerEvent = 1, OnClientEvent = 1, Changed = 1,
	ChildAdded = 1, PlayerAdded = 1, PlayerRemoving = 1, CharacterAdded = 1, PromptGamePassPurchaseFinished = 1, MoveToFinished = 1, Activated = 1 }
local BASEPART = { Part = 1, WedgePart = 1, SpawnLocation = 1, VehicleSeat = 1, Seat = 1, MeshPart = 1 }
function Obj.__index(t, k)
	local raw = rawget(t, "_props")[k]
	if raw ~= nil then return raw end
	if Obj[k] then return Obj[k] end
	if k == "Position" and rawget(t, "_props").CFrame then return rawget(t, "_props").CFrame._p end
	for _, c in ipairs(rawget(t, "_children")) do
		if c._props.Name == k then return c end
	end
	if EVENTS[k] then
		local s = newSignal()
		rawget(t, "_props")[k] = s
		return s
	end
	return nil
end
function Obj.__newindex(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_props").Parent
		if old then
			local ch = rawget(old, "_children")
			for i, c in ipairs(ch) do if c == t then table.remove(ch, i) break end end
		end
		rawget(t, "_props").Parent = v
		if v then table.insert(rawget(v, "_children"), t) end
		return
	end
	rawget(t, "_props")[k] = v
	local sg = rawget(t, "_sigs")
	if sg and sg[k] then sg[k]:Fire() end
end
function Instance.new(class, parent)
	local o = setmetatable({ _props = { ClassName = class, Name = class }, _children = {}, _attrs = {}, _sigs = {} }, Obj)
	if class:find("Remote") then o._props.OnServerEvent = newSignal(); o._props.OnClientEvent = newSignal(); o._fired = {} end
	if parent then o.Parent = parent end
	return o
end
function Obj:FindFirstChild(n) for _, c in ipairs(self._children) do if c._props.Name == n then return c end end end
function Obj:WaitForChild(n) return self:FindFirstChild(n) or error("WaitForChild jamais satisfait: " .. n) end
function Obj:GetChildren() return { table.unpack(self._children) } end
function Obj:GetDescendants()
	local out = {}
	local function rec(o) for _, c in ipairs(o._children) do out[#out + 1] = c; rec(c) end end
	rec(self)
	return out
end
function Obj:FindFirstChildOfClass(c) for _, ch in ipairs(self._children) do if ch._props.ClassName == c then return ch end end end
function Obj:FindFirstAncestorOfClass(c) local p = self._props.Parent; while p do if p._props.ClassName == c then return p end; p = p._props.Parent end end
function Obj:IsA(c) local cn = self._props.ClassName; return cn == c or (c == "BasePart" and BASEPART[cn] ~= nil) or (c == "Seat" and cn == "VehicleSeat") end
function Obj:Destroy() self.Parent = nil; self._props.Destroyed = true end
function Obj:SetAttribute(k, v) self._attrs[k] = v end
function Obj:GetAttribute(k) return self._attrs[k] end
function Obj:GetPropertyChangedSignal(k)
	self._sigs[k] = self._sigs[k] or newSignal()
	return self._sigs[k]
end
function Obj:FillBlock() end
function Obj:LoadAnimation()
	local tr = Instance.new("AnimationTrack")
	tr.Play = function() end
	tr.Stop = function() end
	tr.AdjustSpeed = function() end
	return tr
end
function Obj:Clone()
	local c = Instance.new(self._props.ClassName)
	for k, v in pairs(self._props) do if k ~= "Parent" then c._props[k] = v end end
	for k, v in pairs(self._attrs) do c._attrs[k] = v end
	for _, ch in ipairs(self._children) do local cc = ch:Clone(); cc.Parent = c end
	return c
end
function Obj:FireClient(player, ...) table.insert(self._fired, { player = player, args = table.pack(...) }) end
function Obj:FireAllClients(...) table.insert(self._fired, { all = true, args = table.pack(...) }) end
function Obj:FireServer(...) self._props.OnServerEvent:Fire(...) end
function Obj:PivotTo(cf)
	self._props.Pivot = cf
	local pp = self._props.PrimaryPart
	if pp then pp._props.CFrame = cf; pp._props.Position = nil else
		for _, c in ipairs(self._children) do if c._props.HumanoidRootPart == nil and c._props.Name == "HumanoidRootPart" then c._props.CFrame = cf; c._props.Position = cf._p end end
	end
end
function Obj:SetNetworkOwner() end
function Obj:Sit() end
function Obj:MoveTo() end
function Obj:ChangeState() end
function Obj:Play() end
function Obj:LoadCharacter() end
function Obj:Kick(msg) self._props.Kicked = msg; H.kicked = H.kicked or {}; H.kicked[#H.kicked + 1] = { self, msg } end
function Obj:AddItem() end
H.Instance = Instance

-- ---------------------------------------------------------------- services
local services = {}
local function service(name)
	local s = Instance.new(name)
	s.Name = name
	services[name] = s
	return s
end

local ReplicatedStorage = service("ReplicatedStorage")
local ServerScriptService = service("ServerScriptService")

-- Players
local Players = service("Players")
Players.CharacterAutoLoads = true
Players.RespawnTime = 5
H.nextUserId = 1000
function Players:GetPlayers() local out = {}; for _, c in ipairs(self._children) do if c._props.ClassName == "Player" then out[#out + 1] = c end end; return out end
function Players:GetPlayerFromCharacter(ch) for _, p in ipairs(self:GetPlayers()) do if p.Character == ch then return p end end end
function Players:GetPlayerByUserId(id) for _, p in ipairs(self:GetPlayers()) do if p.UserId == id then return p end end end
function Players:GetNameFromUserIdAsync(id) return "User" .. id end
function Players:CreateHumanoidModelFromDescription()
	local m = Instance.new("Model")
	local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Position = V3.new(0, 0, 0); hrp.AssemblyLinearVelocity = V3.zero; hrp.Parent = m
	local hum = Instance.new("Humanoid"); hum.Health = 100; hum.Parent = m
	return m
end
Players._props.PlayerAdded = newSignal()
Players._props.PlayerRemoving = newSignal()
function H.addPlayer(name)
	H.nextUserId = H.nextUserId + 1
	local p = Instance.new("Player")
	p.Name = name or ("P" .. H.nextUserId)
	p.UserId = H.nextUserId
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
function H.removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end
-- personnage minimal : HRP + Humanoid
function H.spawnCharacter(p, pos)
	local ch = Instance.new("Model")
	ch.Name = p.Name
	local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Position = pos or V3.new(0, 3, 0); hrp.CFrame = CF.new(hrp.Position); hrp.AssemblyLinearVelocity = V3.zero; hrp.Parent = ch
	local hum = Instance.new("Humanoid"); hum.Health = 100; hum.Parent = ch
	p.Character = ch
	return ch, hrp, hum
end
function H.move(p, pos) p.Character.HumanoidRootPart.Position = pos end

-- DataStore en mémoire (avec injection de pannes)
H.ds = { data = {}, failLoad = false, failSave = false, calls = 0, saves = 0 }
local store = {}
function store:UpdateAsync(key, fn)
	H.ds.calls = H.ds.calls + 1
	if H.ds.failLoad and H.ds.mode ~= "save" then error("DataStore indisponible") end
	if H.ds.failSave and H.ds.mode == "save" then error("DataStore indisponible (save)") end
	local old = H.ds.data[key]
	local new = fn(old and H.deepcopy(old) or nil)
	if new ~= nil then H.ds.data[key] = H.deepcopy(new); H.ds.saves = H.ds.saves + 1 end
	return new
end
function store:GetAsync(key) return H.ds.data[key] end
function store:SetAsync(key, v) H.ds.data[key] = v end
local DSS = service("DataStoreService")
function DSS:GetDataStore() return store end
H.ordered = {}
function DSS:GetOrderedDataStore() return { SetAsync = function(_, k, v) H.ordered[k] = v end, GetSortedAsync = function() error("non simulé") end } end

function H.deepcopy(t) if type(t) ~= "table" then return t end; local c = {}; for k, v in pairs(t) do c[k] = H.deepcopy(v) end; return c end

local RunService = service("RunService")
RunService.IsStudioValue = false
function RunService:IsStudio() return self.IsStudioValue end
RunService._props.Heartbeat = newSignal()

local MPS = service("MarketplaceService")
MPS._props.PromptGamePassPurchaseFinished = newSignal()
MPS.owned = {}
function MPS:UserOwnsGamePassAsync(uid, id) return MPS.owned[uid .. ":" .. id] == true end

local Workspace = service("Workspace")
Workspace._props.Terrain = Instance.new("Terrain")
function Workspace:GetServerTimeNow() return now end
H.rayHit = true
function Workspace:Raycast(origin, dir)
	if not H.rayHit then return nil end
	return { Position = V3.new(origin.X, 0, origin.Z), Instance = Instance.new("Part") }
end
Workspace.CurrentCamera = Instance.new("Camera")

local CollectionService = service("CollectionService")
CollectionService.tags = {}
function CollectionService:AddTag(inst, tag) CollectionService.tags[tag] = CollectionService.tags[tag] or {}; table.insert(CollectionService.tags[tag], inst) end
function CollectionService:GetTagged(tag) return CollectionService.tags[tag] or {} end

local game = Instance.new("DataModel")
game._props.JobId = "job-A"
game._props.BindToCloseFn = nil
function game:GetService(n) return services[n] or service(n) end
function game:BindToClose(fn) H.closeFn = fn end
game._props.Workspace = Workspace
H.game, H.Players, H.Workspace, H.RS, H.SSS, H.services = game, Players, Workspace, ReplicatedStorage, ServerScriptService, services

-- ---------------------------------------------------------------- arborescence src -> Instances
local function listdir(path)
	local t = PY_LIST(path)
	local out = {}
	for i = 1, #t do out[i] = t[i] end
	return out
end
local function isdir(path) return PY_ISDIR(path) end

local function build(path, parent)
	for _, name in ipairs(listdir(path)) do
		local full = path .. "/" .. name
		if isdir(full) then
			local f = Instance.new("Folder"); f.Name = name; f.Parent = parent
			build(full, f)
		elseif name:match("%.lua$") then
			local cls = name:match("%.server%.lua$") and "Script" or (name:match("%.client%.lua$") and "LocalScript" or "ModuleScript")
			local n = name:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
			local m = Instance.new(cls); m.Name = n; m._path = full; m.Parent = parent
		end
	end
end
local sharedF = Instance.new("Folder"); sharedF.Name = "Shared"; sharedF.Parent = ReplicatedStorage
build(ROOT .. "/src/ReplicatedStorage/Shared", sharedF)
build(ROOT .. "/src/ServerScriptService", ServerScriptService)
local spsF = Instance.new("Folder"); spsF.Name = "StarterPlayerScripts"; H.SPS = spsF
build(ROOT .. "/src/StarterPlayer/StarterPlayerScripts", spsF)

-- ---------------------------------------------------------------- chargeur de modules
local function preprocess(src)
	local out = {}
	for rawline in (src .. "\n"):gmatch("(.-)\n") do
		local line = rawline
		local ind, lhs, op, rhs = line:match("^(%s*)([%w_%.%[%]\"']+)%s*([%+%-%*/])=%s*(.-)%s*$")
		if ind then line = ind .. lhs .. " = " .. lhs .. " " .. op .. " (" .. rhs .. ")" end
		out[#out + 1] = line
	end
	return table.concat(out, "\n")
end

local cache = {}
local env
local function require_(inst)
	if cache[inst] ~= nil then return cache[inst] end
	local f = io.open(inst._path, "r")
	assert(f, "fichier introuvable: " .. tostring(inst._path))
	local src = preprocess(f:read("a")); f:close()
	local modenv = setmetatable({ script = inst }, { __index = env })
	local fn, err = load(src, "@" .. inst._path, "t", modenv)
	if not fn then error("Erreur de syntaxe (Lua) dans " .. inst._path .. ": " .. tostring(err), 0) end
	local res = fn()
	cache[inst] = res == nil and true or res
	return cache[inst]
end
env = setmetatable({
	game = game, workspace = Workspace, task = task, Instance = Instance, Enum = Enum, Vector3 = V3, CFrame = CF,
	Color3 = Color3, require = require_, typeof = function(v) local m = getmetatable(v); if m == V3 then return "Vector3" elseif m == CF then return "CFrame" end; return type(v) end,
	Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } },
	UDim = { new = function(a, b) return { Scale = a, Offset = b } end }, UDim2 = auto("UDim2"),
	Random = { new = function() return { NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + (b - a) * math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
	OverlapParams = { new = function() return {} end }, RaycastParams = { new = function() return {} end },
	PhysicalProperties = { new = function() return {} end }, NumberRange = { new = function() return {} end },
	NumberSequence = { new = function() return {} end }, ColorSequence = { new = function() return {} end }, TweenInfo = { new = function() return {} end },
	Rect = auto("Rect"),
	warn = function(...) H.warnings[#H.warnings + 1] = table.concat({ ... }, " ") end,
	table = setmetatable({
		find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end,
		clone = function(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end,
		create = function(n, v) local t = {}; for i = 1, n do t[i] = v end; return t end,
		unpack = table.unpack, pack = table.pack,
	}, { __index = table }),
	math = setmetatable({
		clamp = function(x, a, b) return math.max(a, math.min(b, x)) end,
		sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
	}, { __index = math }),
	os = setmetatable({ clock = function() return now end, time = function() return H.osTime or 1700000000 end }, { __index = os }),
	string = string, pairs = pairs, ipairs = ipairs, tostring = tostring, tonumber = tonumber, type = type, pcall = pcall, error = error,
	select = select, next = next, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable, print = function() end,
	utf8 = utf8, coroutine = coroutine, rawget = rawget, rawset = rawset,
}, {})
H.warnings = {}
H.require = require_
H.env = env
function H.reset()
	cache = {}
	H.errors, H.warnings = {}, {}
	H.ds.data, H.ds.failLoad, H.ds.failSave, H.ds.calls, H.ds.saves, H.ds.mode = {}, false, false, 0, 0, nil
	H.ordered = {}
	H.kicked = {}
	queue = {}
	for _, p in ipairs(Players:GetPlayers()) do p.Parent = nil end
	Players._props.PlayerAdded = newSignal()
	Players._props.PlayerRemoving = newSignal()
	local rf = ReplicatedStorage:FindFirstChild("CityRushRemotes")
	if rf then rf:Destroy() end
	CollectionService.tags = {}
	for _, c in ipairs(Workspace:GetChildren()) do
		if c._props.Name ~= "Terrain" and c._props.Name ~= "Camera" then c:Destroy() end
	end
	Workspace._attrs = {}
	H.osTime, H.rayHit = nil, true
	H.services.RunService.IsStudioValue = false
	H.services.MarketplaceService.owned = {}
end
function H.mod(name)
	local function find(o) for _, c in ipairs(o._children) do if c._props.Name == name and c._path then return c end; local r = find(c); if r then return r end end end
	local inst = find(ServerScriptService) or find(sharedF) or find(spsF)
	return H.require(inst)
end
function H.remote(name) return ReplicatedStorage:FindFirstChild("CityRushRemotes"):FindFirstChild(name) end
function H.fired(name, pred)
	local out = {}
	for _, f in ipairs(H.remote(name)._fired) do if not pred or pred(f) then out[#out + 1] = f end end
	return out
end
H.V3 = V3
return H

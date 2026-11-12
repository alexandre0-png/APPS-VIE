-- Simulation SERVEUR de Saute-Troupeau hors Roblox (fengari = machine Lua 5.3 en JavaScript).
-- Les API Roblox sont des doublures minimales : ce test exerce la logique réelle des modules serveur
-- (manches, troupeau, montée, bonds, lassos, dressage, mur de lave, résultats, boutique, sauvegarde)
-- avec des joueurs-robots. Il NE remplace PAS un test dans Roblox Studio (physique, rendu, réseau).

local SCENARIO = SCENARIO or "A"
local vt = 0
local errors = 0
local logLines = {}
local function log(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end logLines[#logLines + 1] = table.concat(t, " ") end

warn = function(...) print("(warn)", ...) end
os.clock = function() return vt end
math.clamp = function(v, a, b) if v < a then return a elseif v > b then return b end return v end
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
table.clone = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end

-- ---------------------------------------------------------------- scheduler
local sleepers, hbWaiters, hbHandlers = {}, {}, {}
local function handleResume(co, ok, a, b)
	if not ok then errors = errors + 1 print("ERREUR (tâche) : " .. tostring(a)) print(debug.traceback(co)) return end
	if coroutine.status(co) == "dead" then return end
	if a == "wait" then sleepers[#sleepers + 1] = { co = co, wake = vt + (b or 0.03) }
	elseif a == "hb" then hbWaiters[#hbWaiters + 1] = co end
end
local task = {}
function task.spawn(fn, ...) local co = coroutine.create(fn) handleResume(co, coroutine.resume(co, ...)) return co end
function task.defer(fn, ...) return task.spawn(fn, ...) end
function task.wait(t) coroutine.yield("wait", t or 0.03) return t or 0.03 end
function task.delay(t, fn, ...) local args = { ... } task.spawn(function() task.wait(t) fn(table.unpack(args)) end) end
_G.task = task

local function advance(dt)
	vt = vt + dt
	local due = {}
	local keep = {}
	for _, s in ipairs(sleepers) do if s.wake <= vt then due[#due + 1] = s else keep[#keep + 1] = s end end
	sleepers = keep
	for _, s in ipairs(due) do handleResume(s.co, coroutine.resume(s.co)) end
	for _, h in ipairs(hbHandlers) do
		local ok, err = xpcall(h, debug.traceback, dt)
		if not ok then errors = errors + 1 print("ERREUR (Heartbeat) : " .. tostring(err)) end
	end
	local waiters = hbWaiters
	hbWaiters = {}
	for _, co in ipairs(waiters) do handleResume(co, coroutine.resume(co, dt)) end
end

-- ---------------------------------------------------------------- types
local V3 = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) if m == 0 then return vec(0, 0, 0) end return vec(t.X / m, t.Y / m, t.Z / m) end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Lerp" then return function(a, b, f) return vec(a.X + (b.X - a.X) * f, a.Y + (b.Y - a.Y) * f, a.Z + (b.Z - a.Z) * f) end end
	return nil
end
V3.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end }
Vector3.zero = vec(0, 0, 0)

local CF = {}
local function cf(p) return setmetatable({ p = p }, CF) end
CF.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "Lerp" then return function(a, b, f) return cf(a.p:Lerp(b.p, f)) end end
	if k == "LookVector" then return vec(0, 0, -1) end
	return nil
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return a.p + b end
	return cf(a.p + b.p)
end
CFrame = {
	new = function(x, y, z)
		if x == nil then return cf(vec(0, 0, 0)) end
		if getmetatable(x) == V3 then return cf(x) end
		return cf(vec(x, y, z))
	end,
	lookAt = function(a, b) return cf(a) end,
	Angles = function() return cf(vec(0, 0, 0)) end,
}
local C3 = {}
local function col(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
C3.__index = function(t, k)
	if k == "Lerp" then return function(a, b, f) return col(a.R + (b.R - a.R) * f, a.G + (b.G - a.G) * f, a.B + (b.B - a.B) * f) end end
end
Color3 = { fromRGB = function(r, g, b) return col(r / 255, g / 255, b / 255) end, new = col }
local function ctorLib(...) local names = { ... } local lib = {} for _, n in ipairs(names) do lib[n] = function(...) return { ... } end end return lib end
local gen = function(...) return { ... } end
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
UDim2 = { new = gen }
UDim = { new = gen }
NumberRange = { new = gen }
NumberSequence = { new = gen }
NumberSequenceKeypoint = { new = gen }
ColorSequence = { new = gen }
ColorSequenceKeypoint = { new = gen }
TweenInfo = { new = gen }
local enumCache = {}
Enum = setmetatable({}, { __index = function(_, k)
	if not enumCache[k] then
		enumCache[k] = setmetatable({}, { __index = function(t, j)
			local item = setmetatable({ Value = 0, Name = j }, { __tostring = function() return "Enum." .. k .. "." .. j end })
			rawset(t, j, item)
			return item
		end })
	end
	return enumCache[k]
end })
Random = { new = function() return { NextNumber = function() return math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end }
function typeof(v) if getmetatable(v) == V3 then return "Vector3" end return type(v) end

-- ---------------------------------------------------------------- signaux
local function newSignal()
	local s = { handlers = {} }
	function s.Connect(self, fn) self.handlers[#self.handlers + 1] = fn return { Disconnect = function() end } end
	function s.Wait(self) coroutine.yield("hb") end
	function s.fire(self, ...) for _, h in ipairs(self.handlers) do task.spawn(h, ...) end end
	return s
end
local SIGNALS = { PromptGamePassPurchaseFinished = true, ChildRemoved = true, Activated = true, MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true, MouseButton1Click = true, OnServerEvent = true, OnClientEvent = true, CharacterAdded = true, PlayerAdded = true, PlayerRemoving = true, Died = true, Touched = true, Changed = true, DescendantAdded = true, ChildAdded = true }

-- ---------------------------------------------------------------- Instance
local M = {}
local BASEPART = { Part = true, SpawnLocation = true, WedgePart = true, MeshPart = true }
local Inst = {}
local function new(class)
	return setmetatable({ _class = class, _p = { Name = class }, _children = {}, _attrs = {}, _parent = nil, _sig = {} }, Inst)
end
Inst.__index = function(t, k)
	local m = M[k]
	if m then return m end
	if k == "Parent" then return rawget(t, "_parent") end
	if k == "ClassName" then return rawget(t, "_class") end
	if k == "Shared" and rawget(t, "_class") == "ReplicatedStorage" then return M.__nodes("shared") end
	local props = rawget(t, "_p")
	if k == "Position" and props.CFrame then return props.CFrame.p end
	if props[k] ~= nil then return props[k] end
	for _, c in ipairs(rawget(t, "_children")) do if c._p.Name == k then return c end end
	if SIGNALS[k] then
		local sig = rawget(t, "_sig")
		sig[k] = sig[k] or newSignal()
		return sig[k]
	end
	return nil
end
local function detach(t)
	local p = rawget(t, "_parent")
	if p then for i, c in ipairs(p._children) do if c == t then table.remove(p._children, i) break end end end
	rawset(t, "_parent", nil)
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		detach(t)
		if v then
			rawset(t, "_parent", v)
			v._children[#v._children + 1] = t
			if t._class == "WeldConstraint" and t._p.Part0 and t._p.Part1 then
				t._off = t._p.Part1._p.CFrame.p - t._p.Part0._p.CFrame.p
			end
		end
		return
	end
	if k == "Position" then t._p.CFrame = CFrame.new(v) return end
	t._p[k] = v
end
function M.IsA(self, cls) return self._class == cls or cls == "Instance" or (cls == "BasePart" and BASEPART[self._class] == true) or (cls == "PVInstance" and (BASEPART[self._class] or self._class == "Model")) or (cls == "Model" and self._class == "Model") end
function M.FindFirstChild(self, name, rec)
	for _, c in ipairs(self._children) do if c._p.Name == name then return c end end
	if rec then for _, c in ipairs(self._children) do local r = M.FindFirstChild(c, name, true) if r then return r end end end
	return nil
end
function M.FindFirstChildWhichIsA(self, cls, rec) for _, c in ipairs(self._children) do if c._class == cls then return c end if rec then local r = M.FindFirstChildWhichIsA(c, cls, true) if r then return r end end end return nil end
function M.FindFirstChildOfClass(self, cls) for _, c in ipairs(self._children) do if c._class == cls then return c end end return nil end
function M.WaitForChild(self, name)
	if self._class == "ReplicatedStorage" and name == "Shared" then return M.__nodes("shared") end
	return M.FindFirstChild(self, name)
end
function M.GetChildren(self) local r = {} for i, c in ipairs(self._children) do r[i] = c end return r end
function M.GetDescendants(self)
	local r = {}
	local function walk(n) for _, c in ipairs(n._children) do r[#r + 1] = c walk(c) end end
	walk(self)
	return r
end
function M.Destroy(self) self._destroyed = true detach(self) for _, c in ipairs(self._children) do c._destroyed = true end self._children = {} end
function M.ClearAllChildren(self) for _, c in ipairs(self._children) do c._destroyed = true c._parent = nil end self._children = {} end
function M.SetAttribute(self, k, v) self._attrs[k] = v end
function M.GetAttribute(self, k) return self._attrs[k] end
function M.GetAttributeChangedSignal(self, k) return newSignal() end
function M.PivotTo(self, c)
	local hrp = M.FindFirstChild(self, "HumanoidRootPart")
	if hrp then hrp._p.CFrame = c else (self._p.PrimaryPart or self)._p.CFrame = c end
end
function M.SetNetworkOwner() end
function M.Play() end
function M.ScaleTo() end
function M.Emit() end
function M.GetServerTimeNow() return vt end
function M.GetPlayers(self) return M.__players end
function M.LoadCharacter(self) M.__loadChar(self) end
function M.FireClient(self, player, ...) M.__remote(self, player, ...) end
function M.FireAllClients(self, ...) for _, p in ipairs(M.__players) do M.__remote(self, p, ...) end end
function M.FireServer(self, ...) local h = self._p._onFire if h then h(self, ...) end end
function M.GetPlayerByUserId(self, id) for _, p in ipairs(M.__players) do if p._p.UserId == id then return p end end return nil end
function M.InvokeServer() return { ok = true, msg = "ok (simulé)" } end
function M.BindToRenderStep() end
function M.Cross() end
Instance = { new = function(class) return new(class) end }

-- ---------------------------------------------------------------- nœuds de modules (require)
local nodes = {}
local sources = SOURCES
function M.__nodes(path)
	if nodes[path] then return nodes[path] end
	local node = setmetatable({ _path = path }, {
		__index = function(t, k)
			if k == "WaitForChild" or k == "FindFirstChild" then return function(self, n) return M.__nodes(path .. "/" .. n) end end
			if k == "Parent" then return M.__nodes(path:match("^(.*)/[^/]+$") or "") end
			return M.__nodes(path .. "/" .. k)
		end,
	})
	nodes[path] = node
	return node
end
local loaded = {}
function require(node)
	local path = node._path
	if loaded[path] ~= nil then return loaded[path] end
	local src = sources[path] or sources[path .. "/init"]
	if not src then error("module introuvable : " .. tostring(path)) end
	local env = setmetatable({ script = M.__nodes(path) }, { __index = _G })
	local fn, err = load(src, "=" .. path, "t", env)
	if not fn then error(err) end
	local result = fn()
	loaded[path] = result == nil and true or result
	return loaded[path]
end

-- ---------------------------------------------------------------- services
workspace = new("Workspace")
workspace._p.Name = "Workspace"
local ReplicatedStorage = new("ReplicatedStorage")
local Players = new("Players")
M.__players = {}
local Lighting = new("Lighting")
local PhysicsService = new("PhysicsService")
function PhysicsService.RegisterCollisionGroup() end
function PhysicsService.CollisionGroupSetCollidable() end

local datastore = {}
FAIL_SAVES = 0
local ordered = {}
local function dataStore() return {
	GetAsync = function(_, key) return datastore[key] end,
	UpdateAsync = function(_, key, fn) if FAIL_SAVES and FAIL_SAVES > 0 then FAIL_SAVES = FAIL_SAVES - 1 error("DataStore indisponible (simulé)") end datastore[key] = fn(datastore[key]) end,
	SetAsync = function(_, key, v) ordered[key] = v end,
} end
local DataStoreService = {
	GetDataStore = function() return dataStore() end,
	GetOrderedDataStore = function()
		local d = dataStore()
		d.GetSortedAsync = function()
			local list = {}
			for k, v in pairs(ordered) do list[#list + 1] = { key = k, value = v } end
			table.sort(list, function(a, b) return a.value > b.value end)
			return { GetCurrentPage = function() return list end }
		end
		return d
	end,
}
local RunService = {
	IsServer = function() return SCENARIO ~= "CLIENT" end,
	RenderStepped = { Connect = function(_, fn) hbHandlers[#hbHandlers + 1] = fn return { Disconnect = function() end } end },
	BindToRenderStep = function(_, name, prio, fn) hbHandlers[#hbHandlers + 1] = fn end,
	IsStudio = function() return true end,
	Heartbeat = { Connect = function(_, fn) hbHandlers[#hbHandlers + 1] = fn return { Disconnect = function() end } end, Wait = function() return coroutine.yield("hb") end },
}
local Debris = { AddItem = function() end }
local TweenService = { Create = function() return { Play = function() end } end }
local closeHandlers = {}
local purchasesLog = {}
local MarketplaceService = new("MarketplaceService")
function MarketplaceService.UserOwnsGamePassAsync(self, uid, id) return id == 114 end
function MarketplaceService.GetProductInfo(self, id) return { PriceInRobux = 99 } end
function MarketplaceService.PromptGamePassPurchase(self, p, id) purchasesLog[#purchasesLog + 1] = "pass:" .. id end
function MarketplaceService.PromptProductPurchase(self, p, id) purchasesLog[#purchasesLog + 1] = "product:" .. id end
local UserInputService = new("UserInputService")
local services = {
	UserInputService = UserInputService, MarketplaceService = MarketplaceService,
	Workspace = workspace, ReplicatedStorage = ReplicatedStorage, Players = Players, Lighting = Lighting,
	PhysicsService = PhysicsService, DataStoreService = DataStoreService, RunService = RunService,
	Debris = Debris, TweenService = TweenService,
}
game = {
	GetService = function(_, name) services[name] = services[name] or new(name) return services[name] end,
	BindToClose = function(_, fn) closeHandlers[#closeHandlers + 1] = fn end,
}

-- ---------------------------------------------------------------- joueurs-robots
local remoteLog = {}
local bots = {}
local function countLog(name, key) remoteLog[name] = remoteLog[name] or {} remoteLog[name][key] = (remoteLog[name][key] or 0) + 1 end
function M.__remote(remote, player, ...)
	local name = remote._p.Name
	local args = { ... }
	countLog(name, "total")
	local bot = bots[player]
	if name == "Status" and bot then bot.status = args[1] countLog("Status", args[1]) bot.statusAt = vt
	elseif name == "Launched" and bot then
		local hrp = player.Character._children and M.FindFirstChild(player.Character, "HumanoidRootPart")
		hrp._p.AssemblyLinearVelocity = args[1]
		bot.air = { vx = args[1].X, vz = args[1].Z }
	elseif name == "Feedback" then
		local p = args[1]
		countLog("Feedback", p and p.kind or "?")
	elseif name == "Results" then bot = bot or {} remoteLog.__results = args[1]
	elseif name == "Data" then bot = bot end
end
function M.__loadChar(player)
	local char = new("Model") char._p.Name = player._p.Name
	local hrp = new("Part") hrp._p.Name = "HumanoidRootPart" hrp._p.CFrame = CFrame.new(0, 330, -560) hrp._p.Anchored = false hrp._p.AssemblyLinearVelocity = Vector3.zero hrp.Parent = char
	local head = new("Part") head._p.Name = "Head" head._p.CFrame = CFrame.new(0, 332, -560) head.Parent = char
	local hand = new("Part") hand._p.Name = "RightHand" hand.Parent = char
	local hum = new("Humanoid") hum._p.Name = "Humanoid" hum._p.Health = 100 hum.Parent = char
	char.Parent = workspace
	player._p.Character = char
	player.CharacterAdded:fire(char)
end
local nextId = 100
local function makePlayer(name)
	local p = new("Player") p._p.Name = name p._p.DisplayName = name p._p.UserId = nextId nextId = nextId + 1
	p.Parent = Players
	M.__players[#M.__players + 1] = p
	bots[p] = { status = "Lobby", style = (#M.__players % 3), nextAct = 0 }
	return p
end

-- ---------------------------------------------------------------- physique minimale des personnages
local GRAV = 90
local function physics(dt)
	for _, p in ipairs(M.__players) do
		local char = p._p.Character
		local hrp = char and M.FindFirstChild(char, "HumanoidRootPart")
		if hrp and not hrp._destroyed then
			local weld = M.FindFirstChild(hrp, "RideWeld")
			if hrp._p.Anchored then
				-- immobile (ou déplacé par le serveur)
			elseif weld and weld._p.Part0 then
				hrp._p.CFrame = CFrame.new(weld._p.Part0._p.CFrame.p + weld._off)
			else
				local pos = hrp._p.CFrame.p
				if pos.Y < 150 then
					local v = hrp._p.AssemblyLinearVelocity or Vector3.zero
					local bot = bots[p]
					if bot.status == "Air" and bot.air then v = Vector3.new(bot.air.vx, v.Y, bot.air.vz) end
					v = Vector3.new(v.X, v.Y - GRAV * dt, v.Z)
					pos = pos + v * dt
					if pos.Y <= 3 then pos = Vector3.new(pos.X, 3, pos.Z) v = Vector3.new(0, 0, 0) end
					hrp._p.CFrame = CFrame.new(pos)
					hrp._p.AssemblyLinearVelocity = v
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- cerveau des robots
local function fire(remote, ...)
	local sig = remote._sig.OnServerEvent
	for _, h in ipairs(sig and sig.handlers or {}) do h(...) end
end

local function bot_think(state)
	if SCENARIO == "C" then
		-- joueurs passifs : ils se déclarent prêts mais ne font rien en course
		for _, p in ipairs(M.__players) do
			local bot = bots[p]
			if bot.status == "Lobby" and state.Phase == "Intermission" and not bot.readySent then
				fire(require(M.__nodes("shared/Remotes")).Ready, p, "savane", true)
				bot.readySent = state.Ready[p] == true
			elseif state.Phase == "Results" then
				bot.readySent = false
			end
		end
		return
	end
	local Remotes = require(M.__nodes("shared/Remotes"))
	for _, p in ipairs(M.__players) do
		local bot = bots[p]
		local char = p._p.Character
		local hrp = char and M.FindFirstChild(char, "HumanoidRootPart")
		local run = state.Participants[p]
		-- partir en expédition dès l'attente
		if bot.status == "Lobby" and state.Phase == "Intermission" and not bot.readySent then
			fire(Remotes.Ready, p, ZONE_PICK or "savane", true)
			bot.readySent = state.Ready[p] == true
		elseif state.Phase == "Results" then
			bot.readySent = false
		end
		if SCENARIO == "D" and bot.style == 2 and run and state.Phase == "Running" and not bot.bossForced and bot.status == "Riding" then
			for _, cr in pairs(state.Creatures) do
				if cr.boss and not cr.rider then
					bot.bossForced = true
					print(("(test) %s est placé sur le boss %s"):format(p._p.Name, cr.def.name))
					require(M.__nodes("server/Modules/RideService")).Mount(p, run, cr)
					bot.status = "Riding"
					break
				end
			end
		end
		if hrp and run and state.Phase == "Running" then
			if bot.status == "Riding" then
				local c = run.creature
				if not bot.rideStart or bot.rideStart.creature ~= c then bot.rideStart = { creature = c, t = vt, wait = ({ 1.2, 3, 7 })[bot.style + 1] + math.random() } end
				if SCENARIO == "D" and c and c.boss and (not bot.dbg or vt - bot.dbg > 1) then bot.dbg = vt print(string.format("  boss#%d t=%.1f progress=%.1f tamed=%s mountT=%.1f canCollect=%s", c.id, vt, c.progress[p] or 0, tostring(c.tamed), run.mountT, tostring(p._attrs.CanCollect))) end
				if p._attrs.CanCollect then
					fire(Remotes.Collect, p)
				elseif c and c.hearted and not c.tamed and not c.boss and vt - bot.rideStart.t < 8 and bot.style ~= 0 then
					-- attend de gagner la confiance de l'animal à cœur
				elseif c and c.boss and vt - bot.rideStart.t < 40 then
					-- le boss désarçonne : le robot le relasse quand il peut (voir plus bas)
					if vt - bot.rideStart.t > 3.4 then fire(Remotes.Launch, p) end
				elseif vt - bot.rideStart.t > bot.rideStart.wait then
					fire(Remotes.Launch, p)
				elseif math.random() < 0.05 then
					fire(Remotes.Steer, p, math.random() * 2 - 1)
				end
				-- lasso de capture sur un animal à cœur proche
				if math.random() < 0.02 and run.lasso > 0 then
					local pos = hrp._p.CFrame.p
					for id, cr in pairs(state.Creatures) do
						if cr.hearted and not cr.rider and not cr.boss and (cr.root._p.CFrame.p - pos).Magnitude < 60 then fire(Remotes.Lasso, p, id) break end
					end
				end
			elseif bot.status == "Air" or bot.status == "Down" then
				local pos = hrp._p.CFrame.p
				local best, bs = nil, 1e9
				for id, c in pairs(state.Creatures) do
					if not c.rider then
						local d = c.root._p.CFrame.p + Vector3.new(0, 3, 0) - pos
						if d.Magnitude <= 58 and d.Z >= (bot.status == "Air" and 5 or -25) then
							local sc = d.Magnitude - 0.3 * math.max(d.Z, 0) - (c.boss and (SCENARIO == "D" and bot.style == 2 and 1000 or 40) or 0) - (c.hearted and 10 or 0)
							if sc < bs then best, bs = id, sc end
						end
					end
				end
				local waitBoss = false
				if SCENARIO == "D" and bot.style == 2 then
					for _, cc in pairs(state.Creatures) do if cc.boss and not cc.rider and (cc.root._p.CFrame.p - pos).Magnitude < 90 and not (best and state.Creatures[best] == cc) then waitBoss = true end end
				end
				if best and not waitBoss then
					if SCENARIO == "D" and bot.style == 2 and (not bot.dbg2 or vt - bot.dbg2 > 0.25) then bot.dbg2 = vt local cc = state.Creatures[best] print(string.format("  hook t=%.2f cible=#%d boss=%s st=%s dist=%.0f", vt, best, tostring(cc.boss), bot.status, (cc.root._p.CFrame.p - hrp._p.CFrame.p).Magnitude)) end
					fire(Remotes.Hook, p, best)
				end
			elseif bot.status == "Dead" then
				-- un joueur sur deux « achète Continuer »
				if bot.style == 1 and not bot.revived and p._attrs.ReviveLeft and p._attrs.ReviveLeft > 0 then
					bot.revived = true
					local MS = services.MarketplaceService
					MS._p.ProcessReceipt({ PlayerId = p._p.UserId, PurchaseId = "rev-" .. vt, ProductId = 217 })
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- scénario CLIENT (interface, contrôles, caméra)
local function clientMain()
	local folder = new("Folder") folder._p.Name = "Remotes" folder.Parent = ReplicatedStorage
	for _, n in ipairs({ "Hook", "Launch", "Steer", "Collect", "Lasso", "Ready", "Prompt", "Data", "Status", "Launched", "Feedback", "Scores", "Results" }) do local r = new("RemoteEvent") r._p.Name = n r.Parent = folder end
	for _, n in ipairs({ "Buy", "Equip", "ClaimDaily", "ClaimQuest", "ZooAction" }) do local r = new("RemoteFunction") r._p.Name = n r.Parent = folder end
	local me = new("Player") me._p.Name = "Moi" me._p.UserId = 1 me._p.DisplayName = "Moi"
	local gui = new("PlayerGui") gui._p.Name = "PlayerGui" gui.Parent = me
	local char = new("Model")
	local hrp = new("Part") hrp._p.Name = "HumanoidRootPart" hrp._p.CFrame = CFrame.new(0, 330, -720) hrp._p.AssemblyLinearVelocity = Vector3.zero hrp.Parent = char
	local hum = new("Humanoid") hum._p.Name = "Humanoid" hum._p.MoveDirection = Vector3.new(1, 0, 0) hum.Parent = char
	function hum.ChangeState() end
	function hum.SetStateEnabled() end
	char.Parent = workspace
	me._p.Character = char
	me._attrs.PlotCenter = Vector3.new(0, 324, -700)
	me._attrs.ZooVisitors = 12
	Players._p.LocalPlayer = me
	local camera = new("Camera") camera._p.CFrame = CFrame.new(0, 20, -10) camera._p.ViewportSize = Vector2.new(1280, 720)
	workspace._p.CurrentCamera = camera
	local creatures = new("Folder") creatures._p.Name = "Creatures" creatures.Parent = workspace
	local zooFolder = new("Folder") zooFolder._p.Name = "ZooAnimals" zooFolder.Parent = workspace
	local function beast(id, z, ridden, heart, boss)
		local m = new("Model") m._p.Name = "Beast" .. id m._attrs = { Id = id, Ridden = ridden, BaseSpeed = 40, Heart = heart, Boss = boss or false }
		local root = new("Part") root._p.Name = "Root" root._p.Size = Vector3.new(4, 4, 8) root._p.CFrame = CFrame.new(0, 5, z) root.Parent = m
		local leg = new("Motor6D") leg._p.Name = "LegFL" leg._attrs = { Phase = 0 } leg.Parent = root
		local wing = new("Motor6D") wing._p.Name = "WingL" wing._attrs = { Side = -1 } wing.Parent = root
		m.Parent = creatures
		return m
	end
	beast(1, 40, false, true) beast(2, 80, true, false) beast(3, 30, false, true, true)
	local lighting = services.Lighting
	for _, n in ipairs({ "HHAtmosphere", "HHColor" }) do local o = new("Atmosphere") o._p.Name = n o.Parent = lighting end

	local env = setmetatable({ script = M.__nodes("client") }, { __index = _G })
	local fn, err = load(sources["client/init"], "=client/init", "t", env)
	if not fn then error(err) end
	task.spawn(fn)
	for _ = 1, 10 do advance(0.1) end

	local function findButton(root, text)
		for _, d in ipairs(M.GetDescendants(root)) do if d._class == "TextButton" and d._p.Text == text then return d end end
	end
	local function press(text) local b = findButton(gui, text) if not b then error("bouton introuvable : " .. text) end b.Activated:fire() for _ = 1, 3 do advance(0.1) end end

	local data = {
		loaded = true, persistent = true, coins = 1234, bones = 31,
		passes = { zoo = false, gold = true, life = false, lasso = false },
		store = { passes = { { key = "zoo", name = "Zoo Premium", desc = "d", available = true, price = 399 }, { key = "gold", name = "Or x2", desc = "d", available = true }, { key = "life", name = "Vie", desc = "d", available = false }, { key = "lasso", name = "Lasso", desc = "d", available = true } },
			products = { { key = "gold_s", name = "Bourse", kind = "gold", amount = 2000, available = true, price = 49 }, { key = "bones_s", name = "Os", kind = "bones", amount = 40, available = true }, { key = "boost", name = "Boost", kind = "boost", amount = 30, available = true }, { key = "revive", name = "Continuer", kind = "revive", amount = 1, available = false } } },
		bestScore = 5000, wins = 3, rounds = 12, hooks = 99, captures = 7, distance = 12345,
		animals = { boar_1 = { level = 2, copies = 3, income = 8.4, cost = 5 }, zebra_3 = { level = 1, copies = 1, income = 28.8, cost = 8 }, elephant_1 = { level = 10, copies = 1, income = 300, cost = nil } },
		completed = {}, zooUp = { slots = 1, visitors = 2, storage = 0, gift = 0, lasso = 1, hearts = 0 },
		zoo = { slots = 8, rate = 40, pending = 120, capMinutes = 20, boostLeft = 600, serverTime = os.time(), owned = 3 },
		zones = { savane = true, marais = false, desert = false, volcan = false }, zone = "savane",
		upgrades = { range = 1, taming = 0, combo = 5 },
		owned = { hats = { none = true, crown = true }, ropes = { classic = true } }, equipped = { hat = "crown", rope = "classic" },
		revives = 1,
		riddle = { text = "Je suis rose et sur une patte. Qui suis-je ?", solved = true, claimed = false, gold = 100, bones = 10 },
		daily = { claimable = true, streak = 2, reward = 75 },
		quests = { { id = "capture", label = "Récupérer 3 animaux", progress = 3, target = 3, reward = 60, claimed = false },
			{ id = "hooks", label = "Réussir 25 sauts", progress = 3, target = 25, reward = 60, claimed = false },
			{ id = "combo", label = "Atteindre un combo de 6", progress = 6, target = 6, reward = 80, claimed = true } },
		story = { index = 3, total = 11, title = "Plus de place", text = "Ton zoo est trop petit.", progress = 1, target = 1, ready = true, gold = 100, bones = 5 },
	}
	local Remotes = require(M.__nodes("shared/Remotes"))
	Remotes.Data.OnClientEvent:fire(data)
	for _ = 1, 15 do advance(0.1) end
	for _, label in ipairs({ "EXPÉDITION", "PARTIR EN EXPÉDITION", "MON ZOO", "COLLECTER", "BOUTIQUE", "CHAPEAUX", "CORDES", "ÉQUIPEMENT", "HISTOIRE", "RÉCUPÉRER", "ROBUX", "FERMER" }) do press(label) end
	for _ = 1, 20 do advance(0.1) end
	print("MENUS      expédition, zoo (caisse, animaux, améliorations), boutique (3 onglets), histoire/quêtes, Robux : OK, aucune erreur")

	-- expédition côté client
	local fired = {}
	Remotes.Launch._onFire = function() fired.launch = (fired.launch or 0) + 1 end
	Remotes.Hook._onFire = function(_, id) fired.hook = id end
	Remotes.Steer._onFire = function(_, x) fired.steer = x end
	Remotes.Collect._onFire = function() fired.collect = (fired.collect or 0) + 1 end
	Remotes.Lasso._onFire = function(_, id) fired.lasso = id end
	Remotes.Ready._onFire = function(_, zone, wants) fired.ready = tostring(zone) .. ":" .. tostring(wants) end
	workspace._attrs.Phase = "Running" workspace._attrs.PhaseEnd = vt + 100 workspace._attrs.Round = 1 workspace._attrs.StartZone = 2
	hrp._p.CFrame = CFrame.new(0, 9, 20)
	me._attrs.RunScore = 1250 me._attrs.Combo = 3 me._attrs.ComboMult = 1.6 me._attrs.ComboLeft = 0.6 me._attrs.TameProgress = 0.5 me._attrs.RideName = "Zèbre Doré" me._attrs.HookRange = 63 me._attrs.LassoRange = 70
	me._attrs.Lives = 2 me._attrs.MaxLives = 2 me._attrs.Lasso = 3 me._attrs.Captures = 1 me._attrs.RunGold = 120 me._attrs.ZoneIdx = 2 me._attrs.RideHeart = true me._attrs.CanCollect = false
	Remotes.Status.OnClientEvent:fire("Riding")
	Remotes.Scores.OnClientEvent:fire({ { n = "Moi", s = 1250, st = "Riding", id = 1 }, { n = "Bob", s = 900, st = "Air", id = 2 } })
	for _ = 1, 5 do advance(0.1) end
	for _, kind in ipairs({ "hook", "tame", "down", "out", "finish", "warn", "buck", "geyser", "event", "danger" }) do
		Remotes.Feedback.OnClientEvent:fire({ kind = kind, title = "TEST " .. kind, sub = "sous-titre" })
		advance(0.1)
	end
	-- contrôles : ESPACE en selle -> Launch ; E -> Collect si prêt ; Q -> Lasso sur l'animal à cœur ; en l'air -> lasso de saut
	local space = { KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard }
	UserInputService.InputBegan:fire(space, false)
	advance(0.1)
	UserInputService.InputEnded:fire(space)
	UserInputService.InputBegan:fire({ KeyCode = Enum.KeyCode.E, UserInputType = Enum.UserInputType.Keyboard }, false)
	advance(0.1)
	me._attrs.CanCollect = true
	for _ = 1, 3 do advance(0.1) end
	UserInputService.InputBegan:fire({ KeyCode = Enum.KeyCode.E, UserInputType = Enum.UserInputType.Keyboard }, false)
	UserInputService.InputBegan:fire({ KeyCode = Enum.KeyCode.Q, UserInputType = Enum.UserInputType.Keyboard }, false)
	for _ = 1, 3 do advance(0.1) end
	Remotes.Status.OnClientEvent:fire("Air")
	Remotes.Launched.OnClientEvent:fire(Vector3.new(0, 58, 60))
	for _ = 1, 3 do advance(0.1) end
	UserInputService.InputBegan:fire(space, false)
	for _ = 1, 4 do advance(0.1) end
	print(("CONTRÔLES  Launch=%s  Collect=%s  Lasso(id)=%s  Hook(id)=%s  Steer=%s"):format(tostring(fired.launch), tostring(fired.collect), tostring(fired.lasso), tostring(fired.hook), tostring(fired.steer)))
	-- mort et « Continuer »
	me._attrs.Lives = 0 me._attrs.ReviveLeft = 9
	Remotes.Status.OnClientEvent:fire("Dead")
	for _ = 1, 5 do advance(0.1) end
	local cont = findButton(gui, "CONTINUER (Robux)")
	print("CONTINUER  bouton présent après la mort :", tostring(cont ~= nil))
	Remotes.Results.OnClientEvent:fire({ round = 1, list = { { id = 1, n = "Moi", score = 3000, rank = 1, gold = 250, bones = 8, captures = 2, names = { "Zèbre", "Lion Doré" }, hooks = 10, dist = 3000, finish = 1, combo = 5, zone = 3 }, { id = 2, n = "Bob", score = 2000, rank = 2, gold = 120, bones = 0, captures = 0, names = {}, hooks = 5, dist = 2500, finish = 0, combo = 3, zone = 2 } } })
	Remotes.Status.OnClientEvent:fire("Lobby")
	for _ = 1, 8 do advance(0.1) end
	print("ERREURS LUA:", errors)
end

-- ---------------------------------------------------------------- scénario
local function main()
	local Config = require(M.__nodes("shared/Config"))
	if SCENARIO == "B" then
		Config.Track.FinishZ = 700
		Config.Round.Duration = 70
		Config.Round.Intermission = 4
	end
	if SCENARIO == "C" then
		-- joueurs passifs : désarçonnés puis tombés dans le sol mortel ; teste vies, mort, sortie d'un joueur, fin anticipée
		Config.Round.Intermission = 4
	end
	if SCENARIO == "D" then
		-- boss très tôt : teste son apparition, le désarçonnement répété, la progression de confiance, la capture
		Config.Zones[1].to = 400
		Config.Zones[2].from = 400
		Config.Zones[2].start = 400
		Config.Zones[2].to = 900
		Config.Zones[3].from = 900
		Config.Zones[3].start = 900
		Config.Round.Intermission = 4
		Config.Round.Duration = 120
		Config.Run.BossBuckAfter = 100
		for _, id in ipairs({ "elephant", "croc_king", "sphinx", "dragon" }) do require(M.__nodes("shared/Species")).ById[id].bossRide = 3 end
	end
	if SCENARIO == "A" then
		local m = Config.Monetization
		for i, pass in ipairs(m.GamePasses) do pass.id = 110 + i end
		for i, product in ipairs(m.Products) do product.id = 210 + i end
	end
	-- 3 joueurs présents pendant la construction de la carte
	local pa, pb, pc = makePlayer("Alice"), makePlayer("Bob"), makePlayer("Chloe")
	local serverSrc = sources["server/init"]
	local env = setmetatable({ script = M.__nodes("server") }, { __index = _G })
	local fn, err = load(serverSrc, "=server/init", "t", env)
	if not fn then error(err) end
	task.spawn(fn)

	local State = require(M.__nodes("server/Modules/State"))
	local maxCreatures, rounds, seenPhases = 0, 0, {}
	local lastPhase
	local simEnd = SCENARIO == "B" and 260 or (SCENARIO == "C" and 120 or (SCENARIO == "D" and 200 or 330))
	local removed = false
	local dt = 1 / 30
	local checkedShop = false
	local peakScore = 0
	while vt < simEnd do
		advance(dt)
		physics(dt)
		bot_think(State)
		if SCENARIO == "C" and not removed and vt > 40 and State.Phase == "Running" then
			removed = true
			Players.PlayerRemoving:fire(pb)
			for i, p in ipairs(M.__players) do if p == pb then table.remove(M.__players, i) break end end
			pb._p.Character:Destroy()
			pb.Parent = nil
			print("(test) Bob quitte la partie en pleine course")
		end
		local n = 0 for _ in pairs(State.Creatures) do n = n + 1 end
		maxCreatures = math.max(maxCreatures, n)
		if State.Phase ~= lastPhase then lastPhase = State.Phase seenPhases[#seenPhases + 1] = string.format("%s@%.0fs", State.Phase, vt) end
		for _, run in pairs(State.Participants) do peakScore = math.max(peakScore, run.score) end
		-- test de la boutique / quêtes pendant l'intermission
		if not checkedShop and State.Phase == "Intermission" and vt > 8 and vt < 30 and workspace._attrs.Waiting == false then
			checkedShop = true
			local Remotes = require(M.__nodes("shared/Remotes"))
			local Data = require(M.__nodes("server/Modules/DataService"))
			local d = Data.Get(pa)
			d.coins = 2000
			local buy = Remotes.Buy._p.OnServerInvoke
			local function step() vt = vt + 0.6 end
			local r1 = buy(pa, "upgrade", "range") step()
			local r2 = buy(pa, "hat", "crown") step()
			local r3 = buy(pa, "rope", "fire") step()
			local r4 = buy(pa, "hat", "nope") step()
			local r5 = buy(pa, "upgrade", 123) step()
			local eq = Remotes.Equip._p.OnServerInvoke(pa, "hat", "none") step()
			local eq2 = Remotes.Equip._p.OnServerInvoke(pa, "rope", "ice") step()
			local daily = Remotes.ClaimDaily._p.OnServerInvoke(pa) step()
			local daily2 = Remotes.ClaimDaily._p.OnServerInvoke(pa)
			print(("BOUTIQUE  amélioration:%s chapeau:%s corde:%s inconnu:%s type-invalide:%s | équiper:%s corde-non-possédée:%s"):format(tostring(r1.ok), tostring(r2.ok), tostring(r3.ok), tostring(r4.ok), tostring(r5.ok), tostring(eq.ok), tostring(eq2.ok)))
			print(("CADEAU     1er:%s (%s) 2e:%s (%s)"):format(tostring(daily.ok), daily.msg, tostring(daily2.ok), daily2.msg))
			print(("PIÈCES     après achats = %d (attendu 2000-150-800-300+bonus = %d)"):format(d.coins, 2000 - 150 - 800 - 300 + 50))
			print("HookRange joueur A =", pa._attrs.HookRange, "(attendu 63 : 58 + 5 niveau d'équipement) | LassoRange =", pa._attrs.LassoRange, "(attendu 85 : pass lasso possédé)")
			-- sauvegarde : 2 échecs puis succès -> les réessais doivent aboutir
			FAIL_SAVES = 2
			d.coins = d.coins + 1
			Data.MarkDirty(pa)
			local saveOk
			local co2 = coroutine.create(function() saveOk = Data.Save(pa) end)
			local okr, e = coroutine.resume(co2)
			local waited = 0
			while coroutine.status(co2) ~= "dead" and waited < 10 do vt = vt + 0.5 waited = waited + 0.5 coroutine.resume(co2) end
			print(("SAUVEGARDE 2 échecs simulés puis succès : %s (essais restants à échouer=%d)"):format(tostring(saveOk), FAIL_SAVES))
			-- achats Robux simulés
			local MS = services.MarketplaceService
			local before = d.coins
			local receipt = { PlayerId = pa._p.UserId, PurchaseId = "abc-1", ProductId = 211 }
			local r1 = MS._p.ProcessReceipt(receipt)
			local r2 = MS._p.ProcessReceipt(receipt)
			local r3 = MS._p.ProcessReceipt({ PlayerId = pa._p.UserId, PurchaseId = "abc-2", ProductId = 999 })
			local r4 = MS._p.ProcessReceipt({ PlayerId = 424242, PurchaseId = "abc-3", ProductId = 212 })
			print(("ROBUX      reçu valide=%s  même reçu rejoué=%s (or +%d, attendu +2000)  produit inconnu=%s  joueur absent=%s"):format(tostring(r1), tostring(r2), d.coins - before, tostring(r3), tostring(r4)))
			vt = vt + 2
			local Remotes2 = require(M.__nodes("shared/Remotes"))
			for _, args in ipairs({ { "product", "gold_m" }, { "pass", "gold" }, { "pass", "lasso" }, { "hack", "x" } }) do
				vt = vt + 1.1
				for _, h in ipairs(Remotes2.Prompt._sig.OnServerEvent.handlers) do h(pa, args[1], args[2]) end
			end
			print("ROBUX      invites d'achat envoyées:", table.concat(purchasesLog, ","), "(attendu product:212,pass:112 ; le pass « lasso » déjà possédé n'est pas reproposé)")
			print("PASS       lasso possédé:", pa._attrs.Pass_lasso, "| or x2:", pa._attrs.Pass_gold)
			-- zoo : caisse, amélioration d'animal, amélioration du zoo, histoire
			local Zoo = require(M.__nodes("shared/Zoo"))
			local Progress = require(M.__nodes("server/Modules/ProgressService"))
			local za = Remotes2.ZooAction._p.OnServerInvoke
			d.animals["boar_1"] = d.animals["boar_1"] or { level = 1, copies = 1 }
			d.bones = 50
			d.coins = 5000
			d.lastCollect = os.time() - 600
			d.pot = 0
			local pending = Progress.PendingGold(pa)
			vt = vt + 1
			local c1 = za(pa, "collect")
			vt = vt + 1
			local c2 = za(pa, "collect")
			vt = vt + 1
			local u1 = za(pa, "animal", "boar_1")
			vt = vt + 1
			local u2 = za(pa, "zoo", "slots")
			vt = vt + 1
			local u3 = za(pa, "zoo", "inconnu")
			vt = vt + 1
			local u4 = za(pa, "animal", "dragon_9")
			vt = vt + 1
			local u5 = za(pa, "zone", "volcan")
			print(("ZOO        caisse en attente=%d  collecte=%s (%s)  2e collecte=%s  animal niv+1=%s  zoo enclos=%s  amélioration inconnue=%s  animal inconnu=%s  zone verrouillée=%s"):format(pending, tostring(c1.ok), c1.msg, tostring(c2.ok), tostring(u1.ok), tostring(u2.ok), tostring(u3.ok), tostring(u4.ok), tostring(u5.ok)))
			print(("ZOO        animal boar_1 niveau=%s os=%d enclos=%d"):format(tostring(d.animals["boar_1"].level), d.bones, Zoo.slots(d.zooUp.slots, false)))
			vt = vt + 1
			local r0 = za(pa, "riddle")
			local day = math.floor(os.time() / 86400)
			local answer = Config.Riddles[day % #Config.Riddles + 1].answer
			Progress.RecordCapture(pa, require(M.__nodes("shared/Species")).ById[answer], 1)
			vt = vt + 1
			local r1 = za(pa, "riddle")
			vt = vt + 1
			local r2 = za(pa, "riddle")
			print(("ÉNIGME     avant capture=%s  après (%s)=%s  rejouée=%s  snapshot sans réponse=%s"):format(tostring(r0.ok), answer, tostring(r1.ok), tostring(r2.ok), tostring(Progress.Snapshot(pa).riddle.answer == nil)))
			vt = vt + 1
			local st = za(pa, "story")
			print("HISTOIRE   chapitre 1 réclamé:", tostring(st.ok), st.msg, "| index:", d.story.index)
		end
	end

	print("---- RÉSUMÉ SCÉNARIO " .. SCENARIO .. " ----")
	print("phases:", table.concat(seenPhases, " > "))
	print("créatures max simultanées:", maxCreatures)
	print("score max atteint:", math.floor(peakScore))
	for name, t in pairs(remoteLog) do
		if name ~= "__results" then
			local parts = {}
			for k, v in pairs(t) do parts[#parts + 1] = k .. "=" .. v end
			table.sort(parts)
			print(name .. ": " .. table.concat(parts, " "))
		end
	end
	if remoteLog.__results then
		print("RÉSULTATS dernière manche :")
		for _, e in ipairs(remoteLog.__results.list) do
			print(("  #%d %s score=%d or=%d os=%d captures=%d (%s) lassos=%d dist=%d zone=%d arrivée=%s"):format(e.rank, e.n, e.score, e.gold, e.bones, e.captures, table.concat(e.names, ","), e.hooks, e.dist, e.zone, tostring(e.finish)))
		end
	end
	local Data = require(M.__nodes("server/Modules/DataService"))
	for _, p in ipairs({ pa, pb, pc }) do
		local d = Data.Get(p)
		if d then print(("PROFIL %s : boss=%s or=%d os=%d manches=%d lassos=%d captures=%d animaux=%d meilleur=%d zoneMax=%d"):format(p._p.Name, (function() local t = {} for k in pairs(d.bossCaptured) do t[#t + 1] = k end return table.concat(t, "+") end)(), d.coins, d.bones, d.rounds, d.hooks, d.captures, require(M.__nodes("shared/Zoo")).countOwned(d.animals), d.bestScore, d.bestZone)) end
	end
	-- sauvegarde à l'arrêt
	for _, fn in ipairs(closeHandlers) do task.spawn(fn) end
	for _ = 1, 20 do advance(0.1) end
	local saved = 0 for _ in pairs(datastore) do saved = saved + 1 end
	print("profils sauvegardés (DataStore simulé):", saved)
	local leftover = 0 for _ in pairs(State.Creatures) do leftover = leftover + 1 end
	print("créatures restantes:", leftover, "| participants:", (function() local c = 0 for _ in pairs(State.Participants) do c = c + 1 end return c end)())
	print("ERREURS LUA:", errors)

end

local function unitMain()
	local Config = require(M.__nodes("shared/Config"))
	local Species = require(M.__nodes("shared/Species"))
	local Util = require(M.__nodes("shared/Util"))
	local Zoo = require(M.__nodes("shared/Zoo"))
	local spec = load(sources["../tests/pure.spec"], "=tests/pure.spec", "t", setmetatable({}, { __index = _G }))()
	local failures, passed = spec(Config, Species, Util, Zoo)
	print(("TESTS UNITAIRES : %d réussis, %d échecs"):format(passed, failures))
	print("ERREURS LUA:", failures)
end

local co = coroutine.create(SCENARIO == "CLIENT" and clientMain or (SCENARIO == "UNIT" and unitMain or main))
local ok, err = coroutine.resume(co)
if not ok then print("ERREUR HARNAIS: " .. tostring(err)) print(debug.traceback(co)) end

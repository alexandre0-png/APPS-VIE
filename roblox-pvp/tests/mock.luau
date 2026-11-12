--!nonstrict
-- Faux environnement Roblox partagé par les tests (voir tests/sim.luau).
local M = {}

-- ===== Faux Roblox =====
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, h in ipairs(self.handlers) do
			h(...)
		end
	end
	return s
end

local remoteLog = {}
local V3 = {}
V3.__index = V3
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end }
Vector3.zero = Vector3.new(0, 0, 0)
local Color3 = { fromHex = function() return {} end }

local Methods = {}
local InstanceMT = {
	__index = function(t, k)
		local m = Methods[k]
		if m then return m end
		return rawget(t, "_children")[k]
	end,
	__newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and v then
			rawget(v, "_children")[rawget(t, "Name")] = t
			table.insert(rawget(v, "_list"), t)
		end
	end,
}
function Methods:FindFirstChild(name) return rawget(self, "_children")[name] end
function Methods:FindFirstChildOfClass(class)
	for _, c in ipairs(rawget(self, "_list")) do
		if c.ClassName == class then return c end
	end
	return nil
end
function Methods:SetAttribute(k, v) rawget(self, "_attrs")[k] = v end
function Methods:GetAttribute(k) return rawget(self, "_attrs")[k] end
function Methods:GetAttributeChangedSignal() return Signal() end
function Methods:WaitForChild(name) return rawget(self, "_children")[name] or setmetatable({ _children = {}, _list = {}, _attrs = {}, Name = name }, InstanceMT) end
function Methods:FireClient(player, data) table.insert(remoteLog, { remote = rawget(self, "Name"), to = player, data = data }) end
function Methods:FireAllClients(data) table.insert(remoteLog, { remote = rawget(self, "Name"), all = true, data = data }) end
function Methods:Destroy()
	local parent = rawget(self, "Parent")
	if parent then
		rawget(parent, "_children")[rawget(self, "Name")] = nil
		local list = rawget(parent, "_list")
		for i, c in ipairs(list) do
			if c == self then
				table.remove(list, i)
				break
			end
		end
	end
end
local function newInstance(class)
	return setmetatable({ ClassName = class, Name = class, _children = {}, _list = {}, _attrs = {}, OnServerEvent = Signal(), CharacterAdded = Signal() }, InstanceMT)
end
local Instance = { new = newInstance }

local PlayersService = newInstance("Players")
PlayersService.PlayerRemoving = Signal()
local allPlayers = {}
function PlayersService:GetPlayers() return allPlayers end
function PlayersService:GetPlayerFromCharacter(model)
	for _, p in ipairs(allPlayers) do
		if p.Character == model then return p end
	end
	return nil
end
local services = {
	Players = PlayersService,
	ReplicatedStorage = newInstance("ReplicatedStorage"),
	RunService = { IsServer = function() return true end, IsStudio = function() return false end },
	DataStoreService = { GetDataStore = function() return { GetAsync = function() return nil end, UpdateAsync = function() end } end },
}
local game = { GetService = function(_, name) return services[name] or newInstance(name) end, BindToClose = function() end }
local script = { Parent = {} }
local workspace = newInstance("Workspace")
function workspace:GetServerTimeNow() return os.clock() end
local task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) fn(...) end,
	delay = function() end,
	wait = function() return 0 end,
}
local function warn(...) print("[warn]", ...) end


M.Signal, M.newInstance, M.remoteLog = Signal, newInstance, remoteLog
M.game, M.workspace, M.script, M.Instance, M.Vector3, M.Color3, M.task, M.warn = game, workspace, script, Instance, Vector3, Color3, task, warn
M.PlayersService, M.allPlayers = PlayersService, allPlayers
return M

-- DataService.luau : chargement / sauvegarde DataStore avec verrou de session, réessais et validation.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local DataService = {}

local store = nil
local sessions = {} -- [Player] = { data, volatile }

local IS_STUDIO = RunService:IsStudio()

function DataService.newData()
	return {
		version = Config.DataVersion,
		cash = Config.StartCash,
		fossils = Config.StartFossils,
		pending = 0,
		totalCash = 0,
		rebirths = 0,
		dinos = {},
		discovered = {},
		buildables = {},
		upgrades = { shovel = 0, luck = 0, hatch = 0, ticket = 0 },
		eggSlots = {}, -- ["1"] = { egg = "basic", finish = os.time() }
		stats = { digs = 0, hatched = 0, collected = 0, bought = 0, playTime = 0 },
		daily = { last = 0, streak = 0 },
		quests = { day = 0, list = {} },
		secrets = { bones = {}, rewarded = false },
		lastSeen = 0,
		receipts = {},
	}
end

local function sanitizeNumber(v, default, lo, hi)
	if not Util.isFinite(v) then
		return default
	end
	return Util.clamp(v, lo, hi)
end

-- Nettoie les données chargées : types, bornes, identifiants inconnus.
function DataService.sanitize(data)
	if type(data) ~= "table" then
		return DataService.newData()
	end
	data._lock = nil
	Util.reconcile(data, DataService.newData())
	data.cash = sanitizeNumber(data.cash, 0, 0, 1e18)
	data.fossils = sanitizeNumber(data.fossils, 0, 0, 1e18)
	data.pending = sanitizeNumber(data.pending, 0, 0, 1e18)
	data.totalCash = sanitizeNumber(data.totalCash, 0, 0, 1e18)
	data.rebirths = math.floor(sanitizeNumber(data.rebirths, 0, 0, Config.RebirthMax))
	data.lastSeen = sanitizeNumber(data.lastSeen, 0, 0, 4e9)

	local dinos = {}
	for key, count in pairs(data.dinos) do
		local id = string.match(tostring(key), "^([%w_]+)")
		if type(key) == "string" and Config.DinoById[id] and Util.isFinite(count) and count > 0 then
			dinos[key] = math.min(math.floor(count), 100000)
		end
	end
	data.dinos = dinos
	local disc = {}
	for id, v in pairs(data.discovered) do
		if v and Config.DinoById[id] then
			disc[id] = true
		end
	end
	for key in pairs(data.dinos) do
		local id = string.match(key, "^([%w_]+)")
		disc[id] = true
	end
	data.discovered = disc

	local b = {}
	for id, v in pairs(data.buildables) do
		if v and Config.BuildableById[id] then
			b[id] = true
		end
	end
	data.buildables = b

	for id, u in pairs(Config.Upgrades) do
		data.upgrades[id] = math.floor(sanitizeNumber(data.upgrades[id], 0, 0, u.max))
	end

	local slots = {}
	for k, v in pairs(data.eggSlots) do
		local n = tonumber(k)
		if n and n >= 1 and n <= 4 and type(v) == "table" and Config.Eggs[v.egg] and Util.isFinite(v.finish) then
			slots[tostring(math.floor(n))] = { egg = v.egg, finish = v.finish }
		end
	end
	data.eggSlots = slots

	for _, k in ipairs({ "digs", "hatched", "collected", "bought", "playTime" }) do
		data.stats[k] = sanitizeNumber(data.stats[k], 0, 0, 1e15)
	end
	data.daily.last = sanitizeNumber(data.daily.last, 0, 0, 1e7)
	data.daily.streak = math.floor(sanitizeNumber(data.daily.streak, 0, 0, 1e5))
	data.quests.day = sanitizeNumber(data.quests.day, 0, 0, 1e7)
	if type(data.quests.list) ~= "table" then
		data.quests.list = {}
	end
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	return data
end

local function keyFor(player)
	return "P_" .. player.UserId
end

local function lockIsFresh(lock)
	return type(lock) == "table" and lock.jobId ~= game.JobId and (os.time() - (lock.time or 0)) < Config.LockTimeout
end

-- Retourne data, errMessage. Dans Studio sans accès API : données volatiles (non sauvegardées).
function DataService.load(player)
	if store == nil then
		local ok, res = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStoreName)
		end)
		if ok then
			store = res
		end
	end
	local data = nil
	local volatile = false
	local lastErr = "indisponible"
	if store then
		local attempts = IS_STUDIO and 2 or 6
		for attempt = 1, attempts do
			local lockedElsewhere = false
			local loaded = nil
			local ok, err = pcall(function()
				store:UpdateAsync(keyFor(player), function(old)
					if old and lockIsFresh(old._lock) then
						lockedElsewhere = true
						return nil
					end
					old = old or {}
					old._lock = { jobId = game.JobId, time = os.time() }
					loaded = old
					return old
				end)
			end)
			if ok and loaded then
				data = loaded
				break
			elseif ok and lockedElsewhere then
				lastErr = "session ouverte sur un autre serveur"
				task.wait(3)
			else
				lastErr = tostring(err)
				task.wait(math.min(2 ^ attempt, 8))
			end
			if not player.Parent then
				return nil, "joueur parti"
			end
		end
	end
	if data == nil then
		if IS_STUDIO then
			warn("[DataService] DataStore indisponible dans Studio, données temporaires :", lastErr)
			data = DataService.newData()
			volatile = true
		else
			return nil, lastErr
		end
	end
	data = DataService.sanitize(data)
	sessions[player] = { data = data, volatile = volatile }
	return data
end

function DataService.get(player)
	local s = sessions[player]
	return s and s.data or nil
end

function DataService.isVolatile(player)
	local s = sessions[player]
	return s ~= nil and s.volatile
end

-- release = true à la déconnexion (libère le verrou)
function DataService.save(player, release)
	local s = sessions[player]
	if not s or s.volatile or not store then
		return true
	end
	s.data.lastSeen = os.time()
	local snapshot = Util.deepCopy(s.data)
	if not release then
		snapshot._lock = { jobId = game.JobId, time = os.time() }
	end
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				if old and lockIsFresh(old._lock) then
					return nil -- un autre serveur détient la session : on n'écrase pas
				end
				return snapshot
			end)
		end)
		if ok then
			return true
		end
		warn("[DataService] sauvegarde échouée (", attempt, "):", err)
		task.wait(2 ^ attempt)
	end
	return false
end

function DataService.release(player)
	local s = sessions[player]
	if s and not s.releasing then
		s.releasing = true -- évite une double sauvegarde (départ + arrêt du serveur)
		DataService.save(player, true)
		sessions[player] = nil
	end
end

function DataService.init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.SaveInterval)
			for player in pairs(sessions) do
				if player.Parent then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		local list = {}
		for player in pairs(sessions) do
			table.insert(list, player)
		end
		for _, player in ipairs(list) do
			pending = pending + 1
			task.spawn(function()
				DataService.release(player)
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService

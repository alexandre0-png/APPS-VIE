--[[
	DataService : chargement / sauvegarde des profils joueurs (DataStore).
	- Verrou de session (JobId) pour éviter la duplication entre serveurs
	- Réessais avec pcall, sauvegarde automatique, sauvegarde à la fermeture
	- Mode temporaire (Studio sans API / échec) : le joueur peut jouer, rien n'est écrasé
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = {}
DataService.Loaded = Util.newSignal() -- (player, profile)
DataService.Removing = Util.newSignal() -- (player, profile) avant sauvegarde finale

local LOCK_TIMEOUT = 120
local DEFAULT = {
	Cash = Config.StartCash,
	Level = 1,
	XP = 0,
	Owned = { citadine = true },
	Colors = {}, -- [vehicleId] = {r,g,b}
	Stats = {
		missions = 0, deliveries = 0, taxis = 0, races = 0, heists = 0,
		fiveStars = 0, busted = 0, storyDone = 0, collected = 0, studs = 0, km = 0, joins = 0, bestRace = 0,
	},
	Collected = {}, -- [tostring(id)] = true
	Achv = {},
	Daily = { day = 0, streak = 0 },
	Story = { chapter = 0, done = false },
	Seen = {}, -- cinématiques déjà vues
	PeakCash = 0,
}

local store
local board
local profiles = {} -- [player] = {data=..., temp=bool, dirty=bool}
local saving = {}

local function getStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	end
	local ok2, result2 = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.CashBoardName)
	end)
	if ok2 then
		board = result2
	end
end

local function key(player)
	return "Player_" .. player.UserId
end

local function loadData(player)
	if not store then
		return nil, "nostore"
	end
	local attempts = 0
	while attempts < 6 and player.Parent do
		attempts += 1
		local locked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(old)
				old = old or { data = nil }
				if old.job and old.job ~= game.JobId and os.time() - (old.lockTime or 0) < LOCK_TIMEOUT then
					locked = true
					return nil -- annule l'écriture
				end
				old.job = game.JobId
				old.lockTime = os.time()
				return old
			end)
		end)
		if ok and not locked and result then
			return result.data or {}, nil
		elseif ok and locked then
			task.wait(5)
		else
			if not ok then
				warn("[DataService] Chargement échoué:", result)
				if RunService:IsStudio() then
					break -- Studio sans accès API : mode temporaire immédiat
				end
			end
			task.wait(2 + attempts)
		end
	end
	return nil, "failed"
end

local function saveProfile(player, release)
	local p = profiles[player]
	if not p or p.temp or saving[player] then
		return
	end
	saving[player] = true
	local snapshot = Util.deepCopy(p.data)
	local wrote = false
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			old = old or {}
			if old.job and old.job ~= game.JobId and os.time() - (old.lockTime or 0) < LOCK_TIMEOUT then
				return nil -- un autre serveur détient le profil : on n'écrase pas
			end
			old.data = snapshot
			if release then
				old.job = nil
			else
				old.job = game.JobId
			end
			old.lockTime = os.time()
			wrote = true
			return old
		end)
	end)
	if ok and wrote then
		p.dirty = false
	elseif not ok then
		warn("[DataService] Sauvegarde échouée pour", player.Name, err)
	end
	if board and snapshot.PeakCash ~= nil then
		pcall(function()
			board:SetAsync(tostring(player.UserId), math.floor(snapshot.Cash))
		end)
	end
	saving[player] = nil
end

function DataService.get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function DataService.markDirty(player)
	local p = profiles[player]
	if p then
		p.dirty = true
	end
end

function DataService.isTemp(player)
	local p = profiles[player]
	return p ~= nil and p.temp
end

local function onPlayerAdded(player)
	if profiles[player] then
		return
	end
	local raw, reason = loadData(player)
	if not player.Parent then
		return
	end
	local temp = false
	if raw == nil then
		temp = true
		raw = {}
		if reason == "failed" and not RunService:IsStudio() then
			-- Ne pas laisser jouer avec un profil vide qui pourrait masquer la vraie progression
			player:Kick("Impossible de charger tes données. Reviens dans quelques instants !")
			return
		end
	end
	local data = Util.reconcile(raw, DEFAULT)
	data.Stats.joins += 1
	profiles[player] = { data = data, temp = temp, dirty = true }
	DataService.Loaded:Fire(player, data)
end

local function onPlayerRemoving(player)
	local p = profiles[player]
	if not p then
		return
	end
	DataService.Removing:Fire(player, p.data)
	saveProfile(player, true)
	profiles[player] = nil
end

function DataService.init()
	getStore()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Util.supervise("DataService", function()
		while true do
			task.wait(Config.SaveInterval)
			for player, p in pairs(profiles) do
				if p.dirty and player.Parent then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.2)
		end
	end)
end

function DataService.saveNow(player)
	saveProfile(player, false)
end

function DataService.getBoard()
	return board
end

return DataService

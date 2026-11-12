--!nonstrict
-- Sauvegarde des profils joueurs (DataStore) : chargement avec tentatives,
-- sauvegarde automatique, sauvegarde à la sortie et à l'arrêt du serveur.
-- Si le chargement échoue, le profil est "éphémère" et n'écrase JAMAIS les données existantes.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Lore = require(Shared.Lore)

local DataService = {}

local VERSION = 1
local profiles = {}
local saving = {}
local store = nil

local function copyList(list)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v
	end
	return out
end

function DataService.DefaultProfile()
	local owned = {}
	for _, id in ipairs(Weapons.StarterOwned) do
		owned[id] = true
	end
	return {
		Version = VERSION,
		Coins = 100,
		XP = 0,
		Level = 1,
		Kills = 0,
		Deaths = 0,
		Wins = 0,
		MatchesPlayed = 0,
		BestStreak = 0,
		Headshots = 0,
		DamageDealt = 0,
		Owned = owned,
		Loadout = copyList(Weapons.StarterLoadout),
		DailyStreak = 0,
		LastDaily = 0, -- numéro du jour UTC de la dernière récompense
		Quests = nil,
		FirstJoin = os.time(),
		Season = { Id = 0, Points = 0, Claimed = {} },
		Hero = "kael",
		Chapters = {}, -- chapitres de la Chronique déjà lus
		Receipts = {}, -- identifiants d'achats déjà traités (idempotence)
	}
end

-- Complète un profil chargé avec les champs manquants et nettoie les valeurs invalides.
function DataService.Reconcile(data)
	local default = DataService.DefaultProfile()
	if type(data) ~= "table" then
		return default
	end
	for key, value in pairs(default) do
		if data[key] == nil then
			data[key] = value
		end
	end
	for _, key in ipairs({ "Coins", "XP", "Level", "Kills", "Deaths", "Wins", "MatchesPlayed", "BestStreak", "Headshots", "DamageDealt", "DailyStreak", "LastDaily" }) do
		if type(data[key]) ~= "number" or data[key] ~= data[key] then
			data[key] = default[key]
		end
	end
	if type(data.Receipts) ~= "table" then
		data.Receipts = {}
	end
	if type(data.Season) ~= "table" or type(data.Season.Claimed) ~= "table" or type(data.Season.Points) ~= "number" or type(data.Season.Id) ~= "number" then
		data.Season = { Id = 0, Points = 0, Claimed = {} }
	end
	if type(data.Chapters) ~= "table" then
		data.Chapters = {}
	end
	if not Lore.IsHeroUnlocked(tostring(data.Hero), data.Chapters) or not Lore.Hero(tostring(data.Hero)) then
		data.Hero = "kael"
	end
	data.Level = math.clamp(math.floor(data.Level), 1, Config.MaxLevel)
	data.Coins = math.max(0, math.floor(data.Coins))
	if type(data.Owned) ~= "table" then
		data.Owned = default.Owned
	end
	for _, id in ipairs(Weapons.StarterOwned) do
		data.Owned[id] = true
	end
	for id in pairs(data.Owned) do
		if not Weapons.IsValid(id) then
			data.Owned[id] = nil
		end
	end
	-- loadout : uniquement des armes possédées, sans doublon, 3 max
	local cleaned, seen = {}, {}
	if type(data.Loadout) == "table" then
		for _, id in ipairs(data.Loadout) do
			if Weapons.IsValid(id) and data.Owned[id] and not seen[id] and #cleaned < Config.Loadout.Slots then
				seen[id] = true
				table.insert(cleaned, id)
			end
		end
	end
	if #cleaned == 0 then
		cleaned = copyList(Weapons.StarterLoadout)
	end
	data.Loadout = cleaned
	return data
end

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStore.Name)
		end)
		store = ok and result or false
	end
	return store
end

local function key(player)
	return "Player_" .. player.UserId
end

-- Charge le profil (yield). Renvoie le profil ; `profile.Ephemeral` = true si la lecture a échoué.
function DataService.Load(player)
	local profile
	local ephemeral = false
	local ds = getStore()
	if ds then
		for attempt = 1, 4 do
			local ok, result = pcall(function()
				return ds:GetAsync(key(player))
			end)
			if ok then
				profile = DataService.Reconcile(result)
				break
			end
			warn(("[DataService] Lecture échouée (%d/4) pour %s : %s"):format(attempt, player.Name, tostring(result)))
			if tostring(result):find("Studio") or tostring(result):find("API") then
				break -- accès API désactivé (Studio) : inutile de réessayer
			end
			task.wait(attempt * 1.5)
		end
	end
	if not profile then
		profile = DataService.DefaultProfile()
		ephemeral = true
	end
	profile.Ephemeral = ephemeral
	profiles[player] = profile
	return profile
end

function DataService.Get(player)
	return profiles[player]
end

-- Version sérialisable (sans champs runtime).
local function serialize(profile)
	local out = {}
	for k, v in pairs(profile) do
		if k ~= "Ephemeral" then
			out[k] = v
		end
	end
	return out
end

function DataService.Save(player)
	-- une sauvegarde déjà en cours (autosave) : on attend sa fin puis on sauvegarde l'état le plus récent
	local waited = 0
	while saving[player] and waited < 10 do
		task.wait(0.25)
		waited += 0.25
	end
	local profile = profiles[player]
	if not profile or profile.Ephemeral or saving[player] then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	saving[player] = true
	local snapshot = serialize(profile)
	local ok, err = false, nil
	for attempt = 1, 3 do
		ok, err = pcall(function()
			ds:UpdateAsync(key(player), function()
				return snapshot
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt * 1.5)
	end
	saving[player] = nil
	if not ok then
		warn(("[DataService] Sauvegarde échouée pour %s : %s"):format(player.Name, tostring(err)))
	end
	return ok
end

-- Oublie un profil sans l'écrire (joueur parti pendant le chargement).
function DataService.Discard(player)
	profiles[player] = nil
end

function DataService.Release(player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Release(player)
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.DataStore.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService

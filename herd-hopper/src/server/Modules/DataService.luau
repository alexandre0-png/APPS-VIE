-- Sauvegarde des joueurs (DataStore) + classement mondial (OrderedDataStore).
-- Règles de sécurité :
--  * si le chargement échoue, la sauvegarde est DÉSACTIVÉE pour ce joueur (on n'écrase jamais un vrai profil par un profil vide) ;
--  * sauvegarde automatique toutes les 60 s, à la sortie du joueur et à l'arrêt du serveur.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "HerdHopper_Profiles_v1"
local BOARD_NAME = "HerdHopper_BestScore_v1"
local AUTOSAVE_INTERVAL = 60

local DataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local board = DataStoreService:GetOrderedDataStore(BOARD_NAME)

local profiles = {} -- [Player] = { data, canSave, dirty, version }

local function defaultData()
	return {
		coins = 0,
		bestScore = 0,
		wins = 0,
		rounds = 0,
		hooks = 0,
		tamedTotal = 0,
		distance = 0,
		tamed = {},
		completed = {},
		upgrades = { range = 0, taming = 0, combo = 0 },
		owned = { hats = { none = true }, ropes = { classic = true } },
		equipped = { hat = "none", rope = "classic" },
		daily = { last = 0, streak = 0 },
		quests = { day = 0, list = {} },
		receipts = {},
	}
end

local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = reconcile({}, value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

function DataService.Load(player)
	local key = "P_" .. player.UserId
	local data = nil
	local ok = false
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)
		if success then
			data = result
			ok = true
			break
		end
		warn(("[Data] Chargement impossible (essai %d/3) : %s"):format(attempt, tostring(result)))
		task.wait(1.5)
	end

	if type(data) ~= "table" then
		data = defaultData()
	else
		data = reconcile(data, defaultData())
	end

	local profile = { data = data, canSave = ok, dirty = false, version = 0 }
	profiles[player] = profile
	return profile
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

function DataService.IsPersistent(player)
	local profile = profiles[player]
	return profile ~= nil and profile.canSave
end

function DataService.MarkDirty(player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
		profile.version = profile.version + 1
	end
end

function DataService.Save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not profile.dirty then
		return true
	end
	local version = profile.version
	local snapshot = deepCopy(profile.data)
	local err
	for attempt = 1, 3 do
		local ok
		ok, err = pcall(function()
			store:UpdateAsync("P_" .. player.UserId, function()
				return snapshot
			end)
		end)
		if ok then
			if profile.version == version then
				profile.dirty = false
			end
			return true
		end
		if attempt < 3 then
			task.wait(attempt * 1.5)
		end
	end
	warn("[Data] Sauvegarde échouée après 3 essais : " .. tostring(err))
	return false
end

function DataService.Release(player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.SubmitBest(player, score)
	local value = math.floor(score)
	local userId = tostring(player.UserId)
	task.spawn(function()
		local err
		for attempt = 1, 3 do
			local ok
			ok, err = pcall(function()
				board:SetAsync(userId, value)
			end)
			if ok then
				return
			end
			task.wait(attempt * 2)
		end
		warn("[Data] Classement mondial indisponible : " .. tostring(err))
	end)
end

-- Renvoie { {userId=, score=}, ... } ou nil si indisponible.
function DataService.GetTop(count)
	local ok, result = pcall(function()
		local pages = board:GetSortedAsync(false, count)
		return pages:GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local list = {}
	for _, entry in ipairs(result) do
		table.insert(list, { userId = tonumber(entry.key), score = entry.value })
	end
	return list
end

function DataService.Init()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, player)
				task.wait(0.2)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending = pending + 1
			task.spawn(function()
				DataService.Save(player)
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
	end)
end

return DataService

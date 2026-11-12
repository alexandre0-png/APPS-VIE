-- ModuleScript : ServerScriptService/Data
-- Sauvegarde DataStore. Les emplacements vides valent `false` (un tableau JSON ne supporte pas les trous).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local STORE_NAME = "ChipeOeufs_v1"
local SLOT_COUNT = 12

local Data = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
end

function Data.default()
	local d = {
		coins = 50,
		speed = 0,
		rb = 0,
		up = {},
		slots = {},
		dex = {}, -- clé = tostring(index d'espèce)
		daily = 0, -- dernier jour réclamé (os.time() // 86400)
		streak = 0,
		stolen = 0,
		hatched = 0,
		last = os.time(),
	}
	for _, u in ipairs(Config.UPGRADES) do
		d.up[u.key] = 0
	end
	for i = 1, SLOT_COUNT do
		d.slots[i] = false
	end
	d.slots[1] = { k = "e", t = 1, ends = os.time() + 6, shield = 0 } -- œuf de départ
	return d
end

local function merge(saved)
	local d = Data.default()
	if type(saved) ~= "table" then
		return d
	end
	for _, key in ipairs({ "coins", "speed", "rb", "daily", "streak", "stolen", "hatched", "last" }) do
		if type(saved[key]) == "number" then
			d[key] = saved[key]
		end
	end
	if type(saved.up) == "table" then
		for k, v in pairs(saved.up) do
			if d.up[k] ~= nil and type(v) == "number" then
				d.up[k] = v
			end
		end
	end
	if type(saved.dex) == "table" then
		d.dex = saved.dex
	end
	if type(saved.slots) == "table" then
		for i = 1, SLOT_COUNT do
			local sl = saved.slots[i]
			if type(sl) == "table" and (sl.k == "e" or sl.k == "p") then
				d.slots[i] = sl
			else
				d.slots[i] = false
			end
		end
	end
	return d
end

local function key(player)
	return "P_" .. player.UserId
end

-- Retourne (données, nePasSauvegarder). Données = nil si le DataStore est injoignable en jeu réel.
function Data.load(player)
	if not store then
		return Data.default(), true
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			return merge(result), false
		end
		warn("[Data] Chargement échoué (" .. attempt .. "/3) : " .. tostring(result))
		task.wait(1.5)
	end
	if RunService:IsStudio() then
		-- Studio sans accès API : on joue quand même, sans sauvegarder
		return Data.default(), true
	end
	return nil, true
end

function Data.save(player, d)
	if not store or not d then
		return false
	end
	d.last = os.time()
	local ok, err = pcall(function()
		store:SetAsync(key(player), d)
	end)
	if not ok then
		warn("[Data] Sauvegarde échouée pour " .. player.Name .. " : " .. tostring(err))
	end
	return ok
end

return Data

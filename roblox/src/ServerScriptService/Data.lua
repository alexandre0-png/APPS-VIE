-- ModuleScript : ServerScriptService/Data
-- Sauvegarde DataStore avec VERROU DE SESSION (un joueur ne peut pas être chargé sur 2 serveurs à la fois :
-- empêche les pertes et duplications quand on change de serveur vite) + classement global.
-- Les emplacements vides valent `false` (un tableau JSON ne supporte pas les trous).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local STORE_NAME = "ChipeOeufs_v1"
local BOARD_NAME = "ChipeOeufs_Board_v1"
local SLOT_COUNT = 12
local LOCK_TTL = 120 -- un verrou plus vieux que ça est considéré comme abandonné (crash serveur)

local Data = {}
Data.SERVER_ID = HttpService:GenerateGUID(false)

local store, board
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
	local ok2, result2 = pcall(function()
		return DataStoreService:GetOrderedDataStore(BOARD_NAME)
	end)
	if ok2 then
		board = result2
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
		equip = {}, -- indices d'emplacements dont le pet suit le joueur
		quests = {}, -- missions du jour
		qday = 0,
		receipts = {}, -- achats Robux déjà traités (anti-double crédit)
		luckUntil = 0,
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
	for _, key in ipairs({ "coins", "speed", "rb", "daily", "streak", "stolen", "hatched", "last", "qday", "luckUntil" }) do
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
	if type(saved.receipts) == "table" then
		d.receipts = saved.receipts
	end
	if type(saved.equip) == "table" then
		for _, v in ipairs(saved.equip) do
			if type(v) == "number" and #d.equip < Config.MAX_FOLLOWERS then
				d.equip[#d.equip + 1] = v
			end
		end
	end
	if type(saved.quests) == "table" then
		for _, q in ipairs(saved.quests) do
			if type(q) == "table" and type(q.t) == "string" and type(q.goal) == "number" then
				d.quests[#d.quests + 1] = { t = q.t, goal = q.goal, prog = tonumber(q.prog) or 0, rew = tonumber(q.rew) or 0, claimed = q.claimed == true }
			end
		end
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

-- Enregistrement stocké : { v = données, lock = idServeur, t = horodatage }. Les anciennes sauvegardes (données brutes) sont migrées.
local function unwrap(rec)
	if type(rec) ~= "table" then
		return nil
	end
	if rec.v ~= nil then
		return rec.v
	end
	return rec
end

local function lockedByOther(rec)
	return type(rec) == "table" and rec.lock ~= nil and rec.lock ~= Data.SERVER_ID and os.time() - (tonumber(rec.t) or 0) < LOCK_TTL
end

-- Retourne (données, nePasSauvegarder). Données = nil si impossible de charger sans risque.
function Data.load(player)
	if not store then
		return Data.default(), true
	end
	for attempt = 1, 8 do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(old)
				if lockedByOther(old) then
					lockedElsewhere = true
					return nil -- annule l'écriture
				end
				return { v = unwrap(old), lock = Data.SERVER_ID, t = os.time() }
			end)
		end)
		if ok and not lockedElsewhere then
			return merge(unwrap(result)), false
		end
		if ok then
			warn("[Data] " .. player.Name .. " est encore verrouillé sur un autre serveur (" .. attempt .. "/8)")
			task.wait(4)
		else
			warn("[Data] Chargement échoué (" .. attempt .. "/8) : " .. tostring(result))
			task.wait(1.5)
		end
	end
	if RunService:IsStudio() then
		return Data.default(), true -- Studio sans accès API : on joue sans sauvegarder
	end
	return nil, true
end

-- release = true : libère le verrou (départ du joueur). Refuse d'écrire si un autre serveur a pris le verrou.
function Data.save(player, d, release)
	if not store or not d then
		return false
	end
	d.last = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			if lockedByOther(old) then
				return nil
			end
			local rec = { v = d, t = os.time() }
			if not release then
				rec.lock = Data.SERVER_ID
			end
			return rec
		end)
	end)
	if not ok then
		warn("[Data] Sauvegarde échouée pour " .. player.Name .. " : " .. tostring(err))
	end
	return ok
end

---------------------------------------------------------------- Classement global
function Data.score(d)
	return d.rb * Config.SCORE_UNIT + math.min(d.hatched, Config.SCORE_UNIT - 1)
end

function Data.submit(player, d)
	if not board then
		return
	end
	pcall(function()
		board:SetAsync(tostring(player.UserId), math.floor(Data.score(d)))
	end)
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and n or ("Joueur " .. userId)
	return nameCache[userId]
end

-- Retourne une liste { {name=, rb=, hatched=}, ... } (peut être vide)
function Data.top(count)
	local out = {}
	if not board then
		return out
	end
	local ok, page = pcall(function()
		return board:GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok then
		return out
	end
	for _, e in ipairs(page) do
		local score = tonumber(e.value) or 0
		out[#out + 1] = {
			name = nameOf(tonumber(e.key) or 0),
			rb = score // Config.SCORE_UNIT,
			hatched = score % Config.SCORE_UNIT,
		}
	end
	return out
end

return Data

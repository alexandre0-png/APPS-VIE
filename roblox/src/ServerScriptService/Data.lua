-- ModuleScript : ServerScriptService/Data
-- Sauvegarde DataStore avec VERROU DE SESSION (un joueur ne peut pas être chargé sur 2 serveurs à la fois :
-- empêche les pertes et duplications quand on change de serveur vite) + classement global.
-- Les emplacements vides valent `false` (un tableau JSON ne supporte pas les trous).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Diag = require(script.Parent:WaitForChild("Diag"))

local STORE_NAME = "ChipeOeufs_v1"
local BOARD_NAME = "ChipeOeufs_Board_v1"
local SLOT_COUNT = 12
local LOCK_TTL = 120 -- un verrou plus vieux que ça est considéré comme abandonné (crash serveur)
local SAVE_RETRIES = 3

-- Version du schéma des données sauvegardées. À incrémenter à chaque changement de structure, avec une étape dans migrate().
-- v1 : première version (sans champ ver). v2 : + equip, quests, qday, receipts, luckUntil, ver.
-- v3 : + story { ch, prog } (histoire) et pity (compteur de pitié).
-- v4 : + puzzle { day, solved } (énigmes), ach (succès) ; un chapitre d'histoire (énigme) est inséré en position 8.
-- v5 : + cine (cinématiques déjà vues).
local VERSION = 5

-- Studio sans accès aux API (réglage « Enable Studio Access to API Services » désactivé) : détecté à la première erreur précise,
-- puis le jeu passe en mode mémoire (aucune sauvegarde, aucun classement) avec UN seul avertissement. Ne concerne pas les vrais serveurs.
local apiBlocked = false
local function markApiBlocked(err)
	if Diag.isStudioApiError(err) then
		if not apiBlocked then
			apiBlocked = true
			warn("[Data] Studio sans accès aux API : mode mémoire (rien n'est sauvegardé, pas de classement). Pour tester les sauvegardes : Game Settings > Security > Enable Studio Access to API Services.")
		end
		return true
	end
	return false
end

local Data = {}
Data.VERSION = VERSION
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
		ver = VERSION,
		coins = Config.START_COINS,
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
		story = { ch = 0, prog = 0 }, -- ch = chapitres réussis, prog = progression du chapitre en cours
		pity = 0,
		puzzle = { day = 0, solved = 0 }, -- day = dernier jour où l'énigme a été résolue
		ach = {}, -- id de succès -> palier déjà réclamé
		cine = {}, -- id de cinématique -> true une fois vue ou passée
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

-- Garde-fou contre les valeurs corrompues (NaN, infini, négatif)
local function sane(v, default)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or v < 0 then
		return default
	end
	return v
end

-- Migrations successives : chaque étape fait passer les données de la version n à n+1.
local MIGRATIONS = {
	[1] = function(_saved)
		-- v1 -> v2 : les nouveaux champs reçoivent leurs valeurs par défaut dans merge(), rien à convertir.
	end,
	[2] = function(_saved)
		-- v2 -> v3 : story et pity reçoivent leurs valeurs par défaut (histoire à reprendre au chapitre 1).
	end,
	[4] = function(_saved)
		-- v4 -> v5 : cine reçoit sa valeur par défaut (aucune cinématique vue : l'intro se jouera une fois).
	end,
	[3] = function(saved)
		-- v3 -> v4 : un nouveau chapitre (énigme) est inséré en position 8. Qui avait déjà réussi 8 chapitres ou plus
		-- garde ses acquis : on décale d'un cran pour ne pas lui faire refaire les chapitres suivants.
		if type(saved.story) == "table" and type(saved.story.ch) == "number" and saved.story.ch >= 8 then
			saved.story.ch += 1
		end
	end,
}

local function migrate(saved)
	local ver = tonumber(saved.ver) or 1
	while ver < VERSION do
		local step = MIGRATIONS[ver]
		if step then
			step(saved)
		end
		ver += 1
	end
	saved.ver = VERSION
end

-- Retourne (données, venantDUneVersionPlusRecente)
local function merge(saved)
	local d = Data.default()
	if type(saved) ~= "table" then
		return d, false
	end
	local newer = (tonumber(saved.ver) or 1) > VERSION
	if not newer then
		migrate(saved)
	end
	for _, key in ipairs({ "coins", "speed", "rb", "daily", "streak", "stolen", "hatched", "last", "qday", "luckUntil" }) do
		d[key] = sane(saved[key], d[key])
	end
	if type(saved.up) == "table" then
		for k, v in pairs(saved.up) do
			if d.up[k] ~= nil and type(v) == "number" then
				local u = Config.upgrade(k)
				d.up[k] = math.min(u and u.max or 0, math.floor(sane(v, 0)))
			end
		end
	end
	if type(saved.dex) == "table" then
		for k, e in pairs(saved.dex) do
			local idx = tonumber(k)
			if idx and Config.PETS[idx] and type(e) == "table" then
				d.dex[tostring(idx)] = { n = math.floor(sane(e.n, 0)), b = sane(e.b, 0) }
			end
		end
	end
	if type(saved.story) == "table" then
		d.story.ch = math.min(#Config.STORY, math.floor(sane(saved.story.ch, 0)))
		d.story.prog = sane(saved.story.prog, 0)
	end
	d.pity = math.min(Config.PITY_EVERY, math.floor(sane(saved.pity, 0)))
	if type(saved.puzzle) == "table" then
		d.puzzle.day = math.floor(sane(saved.puzzle.day, 0))
		d.puzzle.solved = math.floor(sane(saved.puzzle.solved, 0))
	end
	if type(saved.cine) == "table" then
		for _, id in ipairs(Config.CINE_IDS) do
			d.cine[id] = saved.cine[id] == true
		end
	end
	if type(saved.ach) == "table" then
		for _, a in ipairs(Config.ACHIEVEMENTS) do
			d.ach[a.id] = math.min(#a.goals, math.floor(sane(saved.ach[a.id], 0)))
		end
	end
	if type(saved.receipts) == "table" then
		d.receipts = saved.receipts
	end
	if type(saved.equip) == "table" then
		for _, v in ipairs(saved.equip) do
			if type(v) == "number" and v >= 1 and v <= SLOT_COUNT and v % 1 == 0 and #d.equip < Config.MAX_FOLLOWERS then
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
	return d, newer
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
	if not store or apiBlocked then
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
			local d, newer = merge(unwrap(result))
			if newer then
				warn("[Data] " .. player.Name .. " : données d'une version plus récente du jeu, sauvegarde désactivée pour ne rien écraser")
			end
			return d, newer
		end
		if ok then
			warn("[Data] " .. player.Name .. " est encore verrouillé sur un autre serveur (" .. attempt .. "/8)")
			task.wait(4)
		elseif markApiBlocked(result) then
			return Data.default(), true
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

local saving = {} -- clé -> true tant qu'une sauvegarde de cette clé est en cours (évite les écritures concurrentes)

-- release = true : libère le verrou (départ du joueur). Refuse d'écrire si un autre serveur a pris le verrou.
-- Réessaie jusqu'à SAVE_RETRIES fois. Retourne true si la sauvegarde a réussi.
function Data.save(player, d, release)
	if not store or not d or apiBlocked then
		return false
	end
	local k = key(player)
	local waited = 0
	while saving[k] and waited < 8 do
		task.wait(0.25)
		waited += 0.25
	end
	saving[k] = true
	d.last = os.time()
	d.ver = VERSION
	-- Le JSON ne supporte ni NaN ni l'infini : une seule valeur invalide rendrait la sauvegarde impossible pour toujours.
	for _, f in ipairs({ "coins", "speed" }) do
		local v = d[f]
		if type(v) ~= "number" or v ~= v or v < 0 then
			d[f] = 0
		elseif v > 1e300 then
			d[f] = 1e300
		end
	end
	local success = false
	for attempt = 1, SAVE_RETRIES do
		local abort = false
		local ok, err = pcall(function()
			store:UpdateAsync(k, function(old)
				if lockedByOther(old) then
					abort = true
					return nil
				end
				local rec = { v = d, t = os.time() }
				if not release then
					rec.lock = Data.SERVER_ID
				end
				return rec
			end)
		end)
		if ok and not abort then
			success = true
			break
		end
		if abort then
			warn("[Data] " .. player.Name .. " : verrou pris par un autre serveur, sauvegarde annulée")
			break
		end
		if markApiBlocked(err) then
			break
		end
		warn("[Data] Sauvegarde échouée pour " .. player.Name .. " (" .. attempt .. "/" .. SAVE_RETRIES .. ") : " .. tostring(err))
		task.wait(1.5 * attempt)
	end
	saving[k] = nil
	return success
end

---------------------------------------------------------------- Classement global
function Data.score(d)
	return d.rb * Config.SCORE_UNIT + math.min(d.hatched, Config.SCORE_UNIT - 1)
end

function Data.submit(player, d)
	if not board or apiBlocked then
		return
	end
	local ok, err = pcall(function()
		board:SetAsync(tostring(player.UserId), math.floor(Data.score(d)))
	end)
	if not ok then
		markApiBlocked(err)
	end
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
	if not board or apiBlocked then
		return out
	end
	local ok, page = pcall(function()
		return board:GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok then
		markApiBlocked(page)
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

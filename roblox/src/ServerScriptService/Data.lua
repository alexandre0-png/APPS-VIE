-- ModuleScript : ServerScriptService/Data
-- Sauvegarde DataStore avec VERROU DE SESSION (un joueur ne peut pas être chargé sur 2 serveurs à la fois :
-- empêche les pertes et duplications quand on change de serveur vite) + classement global.
-- Les emplacements vides valent `false` (un tableau JSON ne supporte pas les trous).
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Raven = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Raven")) -- règles pures du Corbeau (clés du journal RavenLog)
local Diag = require(script.Parent:WaitForChild("Diag"))

local STORE_NAME = "ChipeOeufs_v1"
local CASTLE_NAME = "ChipeOeufs_Castle_v1"
local BOARD_NAME = "ChipeOeufs_Board_v1"
local SLOT_COUNT = 20 -- v10 : 4 de base + 8 améliorations + 4 de maison + 4 du pass (Config.SLOTS_MAX)
local LOCK_TTL = 120 -- un verrou plus vieux que ça est considéré comme abandonné (crash serveur)
local SAVE_RETRIES = 3

-- Version du schéma des données sauvegardées. À incrémenter à chaque changement de structure, avec une étape dans migrate().
-- v1 : première version (sans champ ver). v2 : + equip, quests, qday, receipts, luckUntil, ver.
-- v3 : + story { ch, prog } (histoire) et pity (compteur de pitié).
-- v4 : + puzzle { day, solved } (énigmes), ach (succès) ; un chapitre d'histoire (énigme) est inséré en position 8.
-- v5 : + cine (cinématiques déjà vues).
-- v6 : + secrets (jour de la dernière fouille par secret de la carte).
-- v7 : + starter (pack de départ déjà acheté, achat unique).
-- v8 : + baseScore (progression de la base : points pondérés par la rareté des pets éclos).
-- v9c : + played (secondes de jeu cumulées) et newbieOff (protection débutant, lot 4) : champs facultatifs assainis, sans changement de version.
-- v9b : battle.pvp { season, trophies, wins, losses, defense = { {p,s,m} }, day, fights, claimed } (PvP asynchrone, sans changement de version : champs facultatifs assainis).
-- v10 (REFONTE lot 5) : SLOT_COUNT 12 -> 20 (les 8 nouveaux emplacements sont vides), + baseLevelFloor (plancher du niveau de maison : jamais de recul),
--   + tokens { remoteSteal }, + settings { blockFriendRavens }, puzzle étendu (step, feathers, hints, fragments) ; baseScore RECALCULÉ depuis dex avec Config.BASE_WEIGHTS2.
-- v9 : + battle { team, best, day, fights, repeats } (Arène des pets : équipe, meilleur étage de la tour, compteurs du jour).
-- v11 (LOT 9) : 10 raretés. Raretés d'œufs (slots, tapis privé, journal des vols, quêtes) remappées par Config.TIER_MIGRATE ; étage de la tour remappé
--   (5 étages par rareté de Config.TOWER.tiers) ; pets : espèce inchangée, + x = 0 (XP, lot 12) ; baseScore conservé (mêmes poids pour les raretés
--   migrées) et plancher de niveau = niveau atteint avec les seuils v10 (jamais de recul) ; + titles { oldCosmic } (Cosmique découvert),
--   + firstSeen / lastSeen (jours UTC, mesure de rétention). Pièces, reçus, jetons, énigme, temps de jeu, PvP : inchangés.
local VERSION = 11

-- Anciens poids et seuils de la progression de la base (profils v8 et v9) : servent UNIQUEMENT aux migrations (score de v8, plancher de niveau de v10).
local LEGACY_WEIGHTS = { 1, 3, 8, 20, 50, 150 }
local LEGACY_THRESHOLDS = { 0, 12, 40, 110, 260, 600, 1400, 3200 }
local function legacyLevel(score)
	local level = 1
	for i, t in ipairs(LEGACY_THRESHOLDS) do
		if score >= t then
			level = i
		end
	end
	return level
end
-- Score de base d'après la collection : somme (nombre obtenu par espèce x poids de la rareté) avec la table de poids donnée.
-- Ancien indice de rareté (1..6) d'une rareté du lot 9 (inverse de Config.TIER_MIGRATE ; une rareté nouvelle prend l'ancienne inférieure).
local oldTier = Config.oldTier
-- `legacy` : table de poids indexée par l'ANCIENNE rareté (1..6), pour les migrations antérieures à v11.
local function scoreFromDex(dex, weights, legacy)
	local score = 0
	if type(dex) == "table" then
		for k, e in pairs(dex) do
			local def = Config.PETS[tonumber(k) or 0]
			if def and type(e) == "table" and type(e.n) == "number" and e.n == e.n and e.n > 0 and e.n < 1e9 then
				local t = legacy and oldTier(def.tier) or def.tier
				score += math.floor(e.n) * weights[math.min(math.max(t, 1), #weights)]
			end
		end
	end
	return score
end
-- Seuils et conditions de rareté des niveaux de maison de la v10 (lot 5) : servent à garder le niveau atteint avant le recalibrage du lot 9.
local V10_LEVELS = { { score = 0 }, { score = 15 }, { score = 60 }, { score = 200 }, { score = 600 }, { score = 1000 }, { score = 5000, needOld = 4 }, { score = 14000, needOld = 5 } }
local V10_WEIGHTS = { 1, 4, 15, 50, 180, 700 }
local function v10Level(score, dex)
	score = (type(score) == "number" and score == score and score > 0) and score or 0
	local top = 0
	if type(dex) == "table" then
		for k, e in pairs(dex) do
			local def = Config.PETS[tonumber(k) or 0]
			if def and type(e) == "table" and type(e.n) == "number" and e.n == e.n and e.n > 0 then
				top = math.max(top, oldTier(def.tier))
			end
		end
	end
	local level = 1
	for i = 2, #V10_LEVELS do
		local lv = V10_LEVELS[i]
		if score < lv.score or (lv.needOld and top < lv.needOld) then
			break
		end
		level = i
	end
	return level
end
-- Remappe une ancienne rareté (1..6) ; nil si invalide.
local function remapTier(t)
	if type(t) == "number" and t == t and t % 1 == 0 and t >= 1 and t <= #Config.TIER_MIGRATE then
		return Config.TIER_MIGRATE[t]
	end
	return nil
end

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
Data.oldTier = oldTier
Data.SERVER_ID = HttpService:GenerateGUID(false)

local store, board, castleBoard, pvpStore, pvpBoard
do
	pcall(function()
		pvpStore = DataStoreService:GetDataStore("ChipeOeufs_Pvp_v1")
		pvpBoard = DataStoreService:GetOrderedDataStore("ChipeOeufs_PvpBoard_v1")
	end)
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
	local ok3, result3 = pcall(function()
		return DataStoreService:GetOrderedDataStore(CASTLE_NAME)
	end)
	if ok3 then
		castleBoard = result3
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
		puzzle = { day = 0, solved = 0, step = 0, feathers = 0, hints = 0, fragments = 0, pday = 0, met = false }, -- day = dernier jour résolu ; step 0..3 ; feathers = masque de bits des 4 plumes ; hints du jour ; fragments cumulés
		ach = {}, -- id de succès -> palier déjà réclamé
		cine = {}, -- id de cinématique -> true une fois vue ou passée
		baseScore = 0, -- progression de la base
		titles = { oldCosmic = false }, -- lot 9 : titre permanent « Ancien Cosmique »
		firstSeen = 0, -- lot 9 : jour UTC de la première connexion (mesure de rétention, aucune donnée personnelle)
		lastSeen = 0, -- lot 9 : jour UTC de la dernière connexion
		baseLevelFloor = 1, -- plancher du niveau de maison (migration v10 : le niveau atteint en v9 ne recule jamais)
		tokens = { remoteSteal = 0 }, -- jetons du Corbeau chipeur (vol à distance)
		settings = { blockFriendRavens = false }, -- réglages du joueur
		raven = { day = 0, n = 0, cd = 0, sh = 0, ic = 0, icDay = 0 }, -- lot 7b : ic = indemnités de corbeau reçues le jour UTC icDay (plafonnées) ; lot 7 : vols à distance réussis ce jour UTC (day, n), fin du délai de la victime (cd) et du bouclier post-vol (sh), en os.time()
		stealLog = {}, -- journal « Qui m'a volé ? » : 10 entrées { n = nom, t = rareté, at = os.time(), k = "p" (physique) | "r" (corbeau) }
		srvBuff = { g = 0, l = 0 }, -- lot 7b : fin (os.time) du tapis doré / de la pluie de chance offerts par ce joueur, écrite à la FERMETURE du serveur et rendue une fois à son retour
		pb = {}, -- œufs en attente sur le tapis privé (raretés), 3 au plus
		played = 0, -- temps de jeu cumulé en secondes (protection débutant, lot 4 : champ facultatif assaini, sans changement de version)
		newbieOff = false, -- fin anticipée de la protection débutant (action newbieOff)
		battle = { team = {}, best = 0, day = 0, fights = 0, repeats = 0, pvp = { season = 0, trophies = 0, wins = 0, losses = 0, defense = {}, day = 0, fights = 0 } }, -- Arène des pets
		pendingAway = 0, -- gains hors ligne à récupérer d'un clic (plafonnés à Config.IDLE.offlineMaxSeconds)
		starter = false, -- pack de départ déjà acheté (achat unique)
		secrets = {}, -- id de secret -> jour (os.time() // 86400) de la dernière fouille
	}
	for _, u in ipairs(Config.UPGRADES) do
		d.up[u.key] = 0
	end
	for i = 1, SLOT_COUNT do
		d.slots[i] = false
	end
	d.slots[1] = { k = "e", t = 1, ends = os.time() + Config.FIRST_EGG_SECONDS, shield = 0, rv = true } -- œuf de départ (gratuit : non indemnisable)
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
	[10] = function(saved)
		-- v10 -> v11 (lot 9) : voir l'en-tête. Aucun pet, œuf, pièce, reçu ni jeton n'est perdu ; le niveau de maison ne baisse jamais.
		if type(saved.slots) == "table" then
			for i, sl in pairs(saved.slots) do
				if type(sl) == "table" and sl.k == "e" then
					sl.t = remapTier(sl.t) or 1
				elseif type(sl) == "table" and sl.k == "p" then
					sl.x = 0
				end
				saved.slots[i] = sl
			end
		end
		if type(saved.pb) == "table" then
			for i, t in ipairs(saved.pb) do
				saved.pb[i] = remapTier(t) or 1
			end
		end
		if type(saved.stealLog) == "table" then
			for _, e in ipairs(saved.stealLog) do
				if type(e) == "table" then
					e.t = remapTier(e.t) or e.t
				end
			end
		end
		if type(saved.quests) == "table" then
			for _, q in ipairs(saved.quests) do
				if type(q) == "table" and type(q.re) == "number" and q.re > 0 then
					q.re = remapTier(math.floor(q.re)) or 0
				end
			end
		end
		if type(saved.battle) == "table" and type(saved.battle.best) == "number" and saved.battle.best == saved.battle.best and saved.battle.best >= 1 then
			local f = math.min(30, math.floor(saved.battle.best))
			local old, pos = 1 + (f - 1) // 5, (f - 1) % 5
			local idx = 1
			for i, t in ipairs(Config.TOWER.tiers) do
				if t == Config.TIER_MIGRATE[old] then
					idx = i
				end
			end
			saved.battle.best = (idx - 1) * 5 + pos + 1
		end
		-- score de maison CONSERVÉ (les poids des raretés migrées sont identiques) ; le niveau atteint avec les seuils v10 devient le plancher
		local floorBefore = math.floor(tonumber(saved.baseLevelFloor) or 1)
		saved.baseLevelFloor = math.max(floorBefore == floorBefore and floorBefore or 1, v10Level(saved.baseScore, saved.dex))
		local cosmic = false
		if type(saved.dex) == "table" then
			for k, e in pairs(saved.dex) do
				local def = Config.PETS[tonumber(k) or 0]
				if def and def.tier == Config.TIER_MIGRATE[6] and type(e) == "table" and type(e.n) == "number" and e.n > 0 then
					cosmic = true
				end
			end
		end
		saved.titles = { oldCosmic = cosmic }
	end,
	[1] = function(_saved)
		-- v1 -> v2 : les nouveaux champs reçoivent leurs valeurs par défaut dans merge(), rien à convertir.
	end,
	[2] = function(_saved)
		-- v2 -> v3 : story et pity reçoivent leurs valeurs par défaut (histoire à reprendre au chapitre 1).
	end,
	[9] = function(saved)
		-- v9 -> v10 : le niveau de maison atteint (anciens seuils) devient un plancher, puis le score est RECALCULÉ depuis la collection avec les
		-- nouveaux poids (1, 4, 15, 50, 180, 700). Aucun pet, œuf, pièce ni reçu n'est touché ; les 8 nouveaux emplacements sont créés vides par merge().
		local oldScore = (type(saved.baseScore) == "number" and saved.baseScore == saved.baseScore and saved.baseScore > 0) and saved.baseScore or 0
		saved.baseLevelFloor = math.max(legacyLevel(oldScore), math.floor(tonumber(saved.baseLevelFloor) or 1))
		saved.baseScore = scoreFromDex(saved.dex, V10_WEIGHTS, true)
	end,
	[7] = function(saved)
		-- v7 -> v8 : le score de base est reconstitué d'après la collection (nombre de pets obtenus par espèce x poids de leur rareté, ANCIENS poids :
		-- la migration v9 -> v10 le recalcule ensuite et en tire le plancher de niveau).
		saved.baseScore = scoreFromDex(saved.dex, LEGACY_WEIGHTS, true)
	end,
	[6] = function(saved)
		-- v6 -> v7 : starter vaut false (pack de départ jamais acheté).
		saved.starter = saved.starter == true
	end,
	[5] = function(_saved)
		-- v5 -> v6 : secrets reçoit sa valeur par défaut (rien fouillé).
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
		d.puzzle.step = math.min(3, math.floor(sane(saved.puzzle.step, 0)))
		d.puzzle.feathers = math.min(15, math.floor(sane(saved.puzzle.feathers, 0))) -- masque de bits : Nord 1, Est 2, Sud 4, Ouest 8
		d.puzzle.hints = math.min(99, math.floor(sane(saved.puzzle.hints, 0)))
		d.puzzle.fragments = math.min(9999, math.floor(sane(saved.puzzle.fragments, 0)))
		d.puzzle.pday = math.floor(sane(saved.puzzle.pday, 0)) -- jour de la progression intermédiaire (lot 6) : un autre jour = remise à zéro
		d.puzzle.met = saved.puzzle.met == true -- la Mère Poule a déjà fait sa présentation (une fois dans la vie du profil)
	end
	if type(saved.tokens) == "table" then
		d.tokens.remoteSteal = math.min(Config.REMOTE_STEAL.tokenMax, math.floor(sane(saved.tokens.remoteSteal, 0)))
	end
	if type(saved.raven) == "table" then
		local rv = saved.raven
		d.raven.day = math.max(0, math.floor(sane(rv.day, 0)))
		d.raven.n = math.min(Config.REMOTE_STEAL.dailyMax, math.max(0, math.floor(sane(rv.n, 0))))
		d.raven.cd = math.min(4e9, math.max(0, sane(rv.cd, 0)))
		d.raven.sh = math.min(4e9, math.max(0, sane(rv.sh, 0)))
		d.raven.icDay = math.max(0, math.floor(sane(rv.icDay, 0)))
		d.raven.ic = math.min(Config.EGG_PRICE[Config.REMOTE_STEAL.compensationCapTier], math.max(0, sane(rv.ic, 0)))
	end
	if type(saved.srvBuff) == "table" then -- champ facultatif assaini : une fin lointaine est ramenée au plafond cumulable
		local nowt = os.time()
		d.srvBuff.g = math.min(nowt + Config.BELT.golden.maxSeconds, math.floor(sane(saved.srvBuff.g, 0)))
		d.srvBuff.l = math.min(nowt + Config.SERVER_LUCK.maxSeconds, math.floor(sane(saved.srvBuff.l, 0)))
	end
	if type(saved.stealLog) == "table" then
		for _, e in ipairs(saved.stealLog) do
			if type(e) == "table" and type(e.n) == "string" and type(e.t) == "number" and e.t % 1 == 0 and e.t >= 1 and e.t <= #Config.TIERS and (e.k == "p" or e.k == "r") and #d.stealLog < Config.REMOTE_STEAL.logMax then
				d.stealLog[#d.stealLog + 1] = { n = string.sub(e.n, 1, 24), t = e.t, at = math.min(4e9, math.max(0, sane(e.at, 0))), k = e.k }
			end
		end
	end
	if type(saved.pb) == "table" then
		for _, t in ipairs(saved.pb) do
			if type(t) == "number" and t % 1 == 0 and t >= 1 and t <= #Config.TIERS and #d.pb < Config.BELT.private.pending then
				d.pb[#d.pb + 1] = t
			end
		end
	end
	if type(saved.settings) == "table" then
		d.settings.blockFriendRavens = saved.settings.blockFriendRavens == true
	end
	if type(saved.secrets) == "table" then
		for _, sct in ipairs(Config.SECRETS) do
			d.secrets[sct.id] = math.floor(sane(saved.secrets[sct.id], 0))
		end
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
	d.starter = saved.starter == true
	d.baseScore = math.max(0, math.floor(sane(saved.baseScore, 0)))
	d.baseLevelFloor = math.min(#Config.BASE_LEVELS2, math.max(1, math.floor(sane(saved.baseLevelFloor, 1))))
	d.played = math.min(1e9, sane(saved.played, 0))
	d.titles.oldCosmic = type(saved.titles) == "table" and saved.titles.oldCosmic == true
	d.firstSeen = math.min(1e6, math.floor(sane(saved.firstSeen, 0)))
	d.lastSeen = math.min(1e6, math.floor(sane(saved.lastSeen, 0)))
	d.newbieOff = saved.newbieOff == true
	d.pendingAway = math.max(0, sane(saved.pendingAway, 0))
	if type(saved.battle) == "table" then
		local b = saved.battle
		local team, seen = {}, {}
		if type(b.team) == "table" then
			for _, v in ipairs(b.team) do
				if type(v) == "number" and v == v and v % 1 == 0 and v >= 1 and v <= SLOT_COUNT and not seen[v] and #team < 3 then
					seen[v] = true
					team[#team + 1] = v
				end
			end
		end
		local pv = type(b.pvp) == "table" and b.pvp or {}
		local defense = {}
		if type(pv.defense) == "table" then
			for _, e in ipairs(pv.defense) do
				if type(e) == "table" and Data.validPet(e) and #defense < 3 then
					defense[#defense + 1] = { p = e.p, s = e.s, m = e.m }
				end
			end
		end
		d.battle = {
			pvp = {
				season = math.floor(sane(pv.season, 0)), trophies = math.min(100000, math.floor(sane(pv.trophies, 0))), wins = math.min(1e7, math.floor(sane(pv.wins, 0))),
				losses = math.min(1e7, math.floor(sane(pv.losses, 0))), defense = defense, day = math.floor(sane(pv.day, 0)), fights = math.min(1000, math.floor(sane(pv.fights, 0))),
			},
			team = team,
			best = math.min(Config.TOWER.floors, math.floor(sane(b.best, 0))),
			day = math.floor(sane(b.day, 0)),
			fights = math.min(1000, math.floor(sane(b.fights, 0))),
			repeats = math.min(1000, math.floor(sane(b.repeats, 0))),
		}
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
				d.quests[#d.quests + 1] = { t = q.t, goal = q.goal, prog = tonumber(q.prog) or 0, rew = tonumber(q.rew) or 0, re = math.floor(math.min(#Config.TIERS, math.max(0, tonumber(q.re) or 0))), rb = math.floor(math.min(3600, math.max(0, tonumber(q.rb) or 0))), claimed = q.claimed == true }
			end
		end
	end
	if type(saved.slots) == "table" then
		for i = 1, SLOT_COUNT do
			local sl = saved.slots[i]
			local okT = type(sl) == "table" and ((sl.k == "e" and type(sl.t) == "number" and sl.t == sl.t and sl.t % 1 == 0 and sl.t >= 1 and sl.t <= #Config.TIERS) or (sl.k == "p" and Data.validPet(sl)))
			if okT then
				if sl.k == "p" then
					sl.x = math.min(1e7, math.floor(sane(sl.x, 0))) -- lot 9 : XP du pet (lot 12)
				end
				-- champs facultatifs du lot 7b (assainis) : rv = œuf non indemnisable (volé par corbeau, tapis privé, bienvenue), rvAt = date du dernier vol par corbeau
				sl.rv = sl.rv == true or nil
				sl.rvAt = (type(sl.rvAt) == "number" and sl.rvAt == sl.rvAt) and math.min(4e9, math.max(0, sl.rvAt)) or nil
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

---------------------------------------------------------------- Journal serveur du Corbeau (RavenLog)
-- Une clé par jour UTC ("D<jour>") contenant au plus RAVEN_LOG_MAX entrées { thief, victim, tier, result, at } ; les clés de plus de Config.REMOTE_STEAL.logDays jours
-- sont effacées (au mieux, une fois par serveur et par jour). Tout est dans un pcall : un échec ne bloque JAMAIS le jeu.
local RAVEN_LOG_MAX = 400
local ravenLogStore, ravenPruned, ravenPruneTry = nil, nil, -1000
-- Écrit un LOT d'entrées (liste) : UpdateAsync réessayé au plus Config.REMOTE_STEAL.logTries fois (attente 2 s, 4 s...), puis abandon (retourne false : l'appelant jette le lot et prévient).
-- Le nettoyage des vieilles clés (RemoveAsync) est SÉPARÉ : son échec ne remet jamais en cause (ni ne duplique) une écriture réussie, et il est retenté au plus toutes les 5 min.
function Data.logRavenBatch(entries)
	if apiBlocked or type(entries) ~= "table" or #entries == 0 then
		return false
	end
	if not ravenLogStore then
		local okS, st = pcall(function()
			return DataStoreService:GetDataStore("RavenLog")
		end)
		if not okS then
			return false
		end
		ravenLogStore = st
	end
	local now = os.time()
	local written = false
	for attempt = 1, Config.REMOTE_STEAL.logTries do
		local ok, err = pcall(function()
			ravenLogStore:UpdateAsync(Raven.dayKey(now), function(old)
				local list = type(old) == "table" and old or {}
				for _, e in ipairs(entries) do
					list[#list + 1] = e
				end
				while #list > RAVEN_LOG_MAX do
					table.remove(list, 1)
				end
				return list
			end)
		end)
		if ok then
			written = true
			break
		end
		if markApiBlocked(err) then
			return false
		end
		warn("[RavenLog] écriture échouée (" .. attempt .. "/" .. Config.REMOTE_STEAL.logTries .. ") : " .. tostring(err))
		if attempt < Config.REMOTE_STEAL.logTries then
			task.wait(2 * attempt)
		end
	end
	if not written then
		return false
	end
	local day = Raven.day(now)
	if ravenPruned ~= day and os.clock() - ravenPruneTry >= 300 then
		ravenPruneTry = os.clock()
		local okP, errP = pcall(function()
			ravenLogStore:RemoveAsync(Raven.expiredKey(now, Config.REMOTE_STEAL.logDays))
		end)
		if okP then
			ravenPruned = day
		else
			warn("[RavenLog] nettoyage des vieilles clés échoué (retenté plus tard, l'écriture est conservée) : " .. tostring(errP))
		end
	end
	return true
end
function Data.logRaven(entry)
	if type(entry) ~= "table" then
		return false
	end
	return Data.logRavenBatch({ entry })
end

---------------------------------------------------------------- Classement global
-- Un pet { p, s, m } est-il valide (espèce, taille et mutation existantes, entiers) ?
function Data.validPet(e)
	return type(e) == "table" and type(e.p) == "number" and type(e.s) == "number" and type(e.m) == "number" and e.p % 1 == 0 and e.s % 1 == 0 and e.m % 1 == 0
		and Config.PETS[e.p] ~= nil and Config.SIZES[e.s] ~= nil and Config.MUTS[e.m] ~= nil
end

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

-- Classement des temps du mode Château : valeur = centièmes de seconde, le plus petit est le meilleur ; seul le meilleur temps d'un joueur est gardé.
function Data.castleSubmit(player, seconds)
	if not castleBoard or apiBlocked or type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return false
	end
	local value = math.max(1, math.floor(seconds * 100 + 0.5))
	local ok, err = pcall(function()
		castleBoard:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) == "number" and old <= value then
				return nil
			end
			return value
		end)
	end)
	if not ok then
		markApiBlocked(err)
	end
	return ok
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

-- Meilleurs temps du Château : liste { {name=, time=secondes}, ... } triée (peut être vide).
function Data.castleTop(count)
	local out = {}
	if not castleBoard or apiBlocked then
		return out
	end
	local ok, page = pcall(function()
		return castleBoard:GetSortedAsync(true, count):GetCurrentPage()
	end)
	if not ok then
		markApiBlocked(page)
		return out
	end
	for _, e in ipairs(page) do
		local v = type(e) == "table" and e.value
		-- entrées invalides (valeur non numérique, négative, nulle, NaN ou infinie) ignorées ; ex aequo : l'ordre du classement est conservé
		if type(v) == "number" and v == v and v > 0 and v < 1e9 then
			out[#out + 1] = { name = nameOf(tonumber(e.key) or 0), time = v / 100 }
		end
	end
	return out
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

-- PvP asynchrone : publie l'équipe de défense (écrite par le SERVEUR seul) et les trophées de la saison. Retourne true si enregistré.
function Data.pvpPublish(player, team, trophies, season)
	if not pvpStore or apiBlocked then
		return false
	end
	local ok, err = pcall(function()
		pvpStore:SetAsync("D_" .. player.UserId, { name = player.DisplayName, team = team, season = season, t = os.time() })
		if pvpBoard then
			pvpBoard:SetAsync(season .. "_" .. player.UserId, math.max(0, math.floor(trophies)))
		end
	end)
	if not ok then
		markApiBlocked(err)
	end
	return ok
end

-- Adversaire de la saison au plus près de `trophies` (hors `userId`) : { name, team = { {p,s,m} }, trophies } ou nil (le serveur prend alors un adversaire fantôme).
function Data.pvpOpponent(userId, trophies, season, salt)
	if not pvpStore or not pvpBoard or apiBlocked then
		return nil
	end
	local ok, page = pcall(function()
		return pvpBoard:GetSortedAsync(false, 100):GetCurrentPage()
	end)
	if not ok then
		markApiBlocked(page)
		return nil
	end
	local cands = {}
	local prefix = season .. "_"
	for _, e in ipairs(page) do
		local key = type(e) == "table" and tostring(e.key) or ""
		local uid = key:sub(1, #prefix) == prefix and tonumber(key:sub(#prefix + 1)) or nil
		if uid and uid ~= userId and type(e.value) == "number" then
			cands[#cands + 1] = { uid = uid, trophies = e.value, d = math.abs(e.value - trophies) }
		end
	end
	table.sort(cands, function(a, b)
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.uid < b.uid
	end)
	for k = 0, math.min(#cands - 1, 4) do -- parmi les 5 plus proches, tournant selon `salt`
		local c = cands[((k + (salt or 0)) % math.min(#cands, 5)) + 1]
		local ok2, rec = pcall(function()
			return pvpStore:GetAsync("D_" .. c.uid)
		end)
		if ok2 and type(rec) == "table" and type(rec.team) == "table" then
			local team = {}
			for _, e in ipairs(rec.team) do
				if Data.validPet(e) and #team < 3 then
					team[#team + 1] = { p = e.p, s = e.s, m = e.m }
				end
			end
			if #team > 0 then
				return { name = tostring(rec.name or ("Joueur " .. c.uid)):sub(1, 24), team = team, trophies = c.trophies }
			end
		end
	end
	return nil
end

-- Classement de la saison : { {name, trophies} } (peut être vide).
function Data.pvpTop(season, count)
	local out = {}
	if not pvpBoard or apiBlocked then
		return out
	end
	local ok, page = pcall(function()
		return pvpBoard:GetSortedAsync(false, 100):GetCurrentPage()
	end)
	if not ok then
		markApiBlocked(page)
		return out
	end
	local prefix = season .. "_"
	for _, e in ipairs(page) do
		local key = type(e) == "table" and tostring(e.key) or ""
		if key:sub(1, #prefix) == prefix and type(e.value) == "number" and #out < count then
			out[#out + 1] = { name = nameOf(tonumber(key:sub(#prefix + 1)) or 0), trophies = e.value }
		end
	end
	return out
end

return Data

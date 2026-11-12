-- Progression : or, os, zoo (animaux, niveaux, caisse), améliorations, histoire, quêtes, boutique.
-- Toutes les décisions sont prises ici (serveur) ; le client ne fait que demander.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local Zoo = require(Shared.Zoo)
local CinematicPlan = require(Shared.CinematicPlan)

local DataService = require(script.Parent.DataService)
local Cosmetics = require(script.Parent.Cosmetics)

local ProgressService = {}

-- Informations de la boutique Robux (remplies par MonetizationService : prix lus sur Roblox).
ProgressService.Store = { passes = {}, products = {} }

-- Rappel appelé quand le contenu du zoo d'un joueur change (branché par ZooService).
ProgressService.OnZooChanged = function() end

local pushScheduled = {}

local function today()
	return math.floor(os.time() / 86400)
end

-- Énigme du jour (la même pour tous les joueurs ce jour-là) ; remise à zéro quand le jour change.
local function dailyRiddle(data)
	local day = today()
	if data.riddle.day ~= day then
		data.riddle = { day = day, solved = false, claimed = false }
	end
	return Config.Riddles[day % #Config.Riddles + 1]
end

local function questDef(id)
	return Config.findById(Config.QuestPool, id)
end

function ProgressService.HasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

-- ---------------------------------------------------------------------------
-- Valeurs dérivées (vies, lassos, cœurs, revenus)
-- ---------------------------------------------------------------------------

function ProgressService.Lives(player)
	local lives = Config.Run.BaseLives
	if ProgressService.HasPass(player, "life") then
		lives = lives + Config.Monetization.LifePassBonus
	end
	local data = DataService.Get(player)
	if data and data.revives > 0 then
		lives = lives + 1 -- une pièce « Continuer » achetée et non utilisée devient une vie d'avance
	end
	return lives
end

-- Consomme un « Continuer » stocké au départ d'une expédition (voir RoundService).
function ProgressService.ConsumeStoredRevive(player)
	local data = DataService.Get(player)
	if data and data.revives > 0 then
		data.revives = data.revives - 1
		DataService.MarkDirty(player)
		return true
	end
	return false
end

function ProgressService.LassoCharges(player)
	local data = DataService.Get(player)
	local n = Config.Run.BaseLasso + (data and data.zooUp.lasso or 0)
	if ProgressService.HasPass(player, "lasso") then
		n = n + Config.Monetization.LassoPassBonus
	end
	return n
end

function ProgressService.LassoRange(player)
	local range = Config.Run.LassoRange
	if ProgressService.HasPass(player, "lasso") then
		range = range + Config.Monetization.LassoPassRange
	end
	return range
end

function ProgressService.HeartChance(player, zone)
	local data = DataService.Get(player)
	return zone.heartChance + Config.Zoo.HeartBonus * (data and data.zooUp.hearts or 0)
end

function ProgressService.ZooRate(player)
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local factor = Zoo.visitorFactor(data.zooUp.visitors, ProgressService.HasPass(player, "zoo"))
	return Zoo.baseIncome(data.animals) * factor
end

-- Or accumulé depuis le dernier calcul (au taux actuel du zoo).
local function accrued(player, data)
	return Zoo.pendingGold(
		ProgressService.ZooRate(player),
		data.lastCollect,
		os.time(),
		data.zooUp.storage,
		data.boostUntil
	)
end

function ProgressService.PendingGold(player)
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return math.floor(data.pot + accrued(player, data))
end

-- À appeler AVANT tout changement du taux (capture, amélioration) : fige l'or déjà gagné dans la caisse.
local function settle(player, data)
	data.pot = data.pot + accrued(player, data)
	data.lastCollect = os.time()
end

function ProgressService.GoldForRun(player, score)
	local data = DataService.Get(player)
	return Zoo.runGold(score, data and data.zooUp.gift or 0, ProgressService.HasPass(player, "gold"))
end

-- ---------------------------------------------------------------------------
-- Histoire
-- ---------------------------------------------------------------------------

local function totalZooLevels(data)
	local n = 0
	for _, level in pairs(data.zooUp) do
		n = n + level
	end
	return n
end

local function bossCount(data)
	local n = 0
	for _ in pairs(data.bossCaptured) do
		n = n + 1
	end
	return n
end

local function maxAnimalLevel(data)
	local best = 1
	for _, entry in pairs(data.animals) do
		best = math.max(best, entry.level or 1)
	end
	return best
end

-- Renvoie progression actuelle d'un objectif.
local function goalProgress(data, goal)
	if goal.type == "animals" then
		return Zoo.countOwned(data.animals)
	elseif goal.type == "captures" then
		return data.captures
	elseif goal.type == "zooUpgrades" then
		return totalZooLevels(data)
	elseif goal.type == "boss" then
		return bossCount(data)
	elseif goal.type == "zone" then
		return data.bestZone
	elseif goal.type == "level" then
		return maxAnimalLevel(data)
	end
	return 0
end

local function currentChapter(data)
	return Config.Story[data.story.index]
end

-- ---------------------------------------------------------------------------
-- Snapshot envoyé au client
-- ---------------------------------------------------------------------------

function ProgressService.Snapshot(player)
	local data = DataService.Get(player)
	if not data then
		return { loaded = false }
	end

	local quests = {}
	for index, q in ipairs(data.quests.list) do
		local def = questDef(q.id)
		if def then
			quests[index] = {
				id = q.id,
				label = string.format(def.label, def.target),
				progress = math.min(q.progress, def.target),
				target = def.target,
				reward = def.reward,
				claimed = q.claimed,
			}
		end
	end

	local streak = data.daily.streak
	local claimable = data.daily.last ~= today()
	local nextStreak = streak
	if claimable then
		nextStreak = (data.daily.last == today() - 1) and (streak + 1) or 1
	end
	local rewardStreak = math.min(nextStreak, Config.DailyReward.MaxStreak)

	local hats = {}
	for id in pairs(data.owned.hats) do
		hats[id] = true
	end
	for _, def in ipairs(Config.Hats) do
		if def.pass and ProgressService.HasPass(player, def.pass) then
			hats[def.id] = true
		end
	end
	local passes = {}
	for _, def in ipairs(Config.Monetization.GamePasses) do
		passes[def.key] = ProgressService.HasPass(player, def.key)
	end

	-- animaux du zoo avec revenu et coût d'amélioration
	local animals = {}
	for key, entry in pairs(data.animals) do
		local def, variant = Zoo.parseKey(key)
		if def then
			animals[key] = {
				level = entry.level or 1,
				copies = entry.copies or 1,
				income = Zoo.animalIncome(def, variant, entry.level or 1),
				cost = Zoo.upgradeCost(def, variant, entry.level or 1),
			}
		end
	end

	local zones = {}
	for _, zone in ipairs(Config.Zones) do
		zones[zone.key] = Zoo.zoneUnlocked(zone, data.animals)
	end

	-- chapitre d'histoire en cours
	local story = nil
	local chapter = currentChapter(data)
	if chapter then
		local progress = goalProgress(data, chapter.goal)
		story = {
			index = data.story.index,
			total = #Config.Story,
			title = chapter.title,
			text = chapter.text,
			progress = math.min(progress, chapter.goal.n),
			target = chapter.goal.n,
			ready = progress >= chapter.goal.n,
			gold = chapter.reward.gold,
			bones = chapter.reward.bones,
		}
	end

	local riddle = dailyRiddle(data)
	local hasZoo = ProgressService.HasPass(player, "zoo")
	return {
		loaded = true,
		seen = data.seen,
		bossCaptured = data.bossCaptured,
		riddle = {
			text = riddle.text,
			solved = data.riddle.solved,
			claimed = data.riddle.claimed,
			gold = Config.RiddleReward.gold,
			bones = Config.RiddleReward.bones,
		},
		passes = passes,
		store = ProgressService.Store,
		persistent = DataService.IsPersistent(player),
		coins = data.coins,
		bones = data.bones,
		bestScore = data.bestScore,
		wins = data.wins,
		rounds = data.rounds,
		hooks = data.hooks,
		captures = data.captures,
		distance = math.floor(data.distance),
		animals = animals,
		completed = data.completed,
		zooUp = data.zooUp,
		zoo = {
			slots = Zoo.slots(data.zooUp.slots, hasZoo),
			rate = ProgressService.ZooRate(player),
			pending = ProgressService.PendingGold(player),
			capMinutes = Zoo.storageMinutes(data.zooUp.storage),
			boostLeft = math.max(0, data.boostUntil - os.time()),
			serverTime = os.time(),
			owned = Zoo.countOwned(data.animals),
		},
		zones = zones,
		zone = data.zone,
		upgrades = data.upgrades,
		owned = { hats = hats, ropes = data.owned.ropes },
		equipped = data.equipped,
		revives = data.revives,
		daily = {
			claimable = claimable,
			streak = streak,
			reward = Config.DailyReward.Base + Config.DailyReward.PerStreak * (rewardStreak - 1),
		},
		quests = quests,
		story = story,
	}
end

function ProgressService.Push(player)
	if pushScheduled[player] then
		return
	end
	pushScheduled[player] = true
	task.delay(0.15, function()
		pushScheduled[player] = nil
		if player.Parent then
			Remotes.Data:FireClient(player, ProgressService.Snapshot(player))
		end
	end)
end

function ProgressService.RefreshAttributes(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("HookRange", Config.Ride.HookBaseRange + Config.Ride.HookRangePerLevel * data.upgrades.range)
	player:SetAttribute("LassoRange", ProgressService.LassoRange(player))
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("ZooOwned", Zoo.countOwned(data.animals))
	player:SetAttribute(
		"ZooVisitors",
		math.min(
			30,
			2
				+ math.floor(
					Zoo.countOwned(data.animals)
						* Zoo.visitorFactor(data.zooUp.visitors, ProgressService.HasPass(player, "zoo"))
				)
		)
	)
end

-- ---------------------------------------------------------------------------
-- Quêtes
-- ---------------------------------------------------------------------------

function ProgressService.EnsureDaily(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day = today()
	if data.quests.day == day and #data.quests.list > 0 then
		return
	end
	local rng = Random.new(day)
	local pool = {}
	for _, def in ipairs(Config.QuestPool) do
		table.insert(pool, def)
	end
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local list = {}
	for i = 1, 3 do
		list[i] = { id = pool[i].id, progress = 0, claimed = false }
	end
	data.quests = { day = day, list = list }
	DataService.MarkDirty(player)
end

function ProgressService.AddQuest(player, id, amount)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local def = questDef(id)
	for _, q in ipairs(data.quests.list) do
		if q.id == id and def and not q.claimed then
			if def.mode == "max" then
				if amount > q.progress then
					q.progress = amount
				end
			else
				q.progress = q.progress + amount
			end
		end
	end
	DataService.MarkDirty(player)
	ProgressService.Push(player)
end

-- ---------------------------------------------------------------------------
-- Or, os, zoo
-- ---------------------------------------------------------------------------

function ProgressService.AddCoins(player, amount)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.coins = data.coins + math.floor(amount)
	DataService.MarkDirty(player)
	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
end

function ProgressService.AddBones(player, amount)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.bones = data.bones + math.floor(amount)
	DataService.MarkDirty(player)
	ProgressService.Push(player)
end

-- Enregistre un animal récupéré. Renvoie { new, bones, gold, complete }.
function ProgressService.RecordCapture(player, def, variantIdx)
	local data = DataService.Get(player)
	local result = { new = false, bones = 0, gold = 0, complete = false }
	if not data then
		return result
	end
	local key = Zoo.key(def.id, variantIdx)
	local entry = data.animals[key]
	local variantMult = Zoo.variantMult(def, variantIdx)
	local gold = Config.Rewards.CaptureGold * def.value * variantMult

	settle(player, data)
	if entry then
		entry.copies = (entry.copies or 1) + 1
		result.bones = Zoo.duplicateBones(def, variantIdx)
		data.bones = data.bones + result.bones
	else
		result.new = true
		data.animals[key] = { level = 1, copies = 1 }
		gold = gold + Config.Rewards.NewDiscovery
	end

	if def.boss then
		data.bossCaptured[def.id] = true
	end
	if dailyRiddle(data).answer == def.id then
		data.riddle.solved = true
	end

	if result.new and not data.completed[def.id] and not def.boss then
		local all = true
		for v = 1, #Config.Variants do
			if not data.animals[Zoo.key(def.id, v)] then
				all = false
				break
			end
		end
		if all then
			data.completed[def.id] = true
			result.complete = true
			gold = gold + Config.Rewards.SpeciesComplete
		end
	end

	result.gold = math.floor(gold)
	data.coins = data.coins + result.gold
	data.captures = data.captures + 1
	DataService.MarkDirty(player)

	ProgressService.AddQuest(player, "capture", 1)
	if variantIdx > 1 then
		ProgressService.AddQuest(player, "rare", 1)
	end
	ProgressService.RefreshAttributes(player)
	ProgressService.OnZooChanged(player)
	ProgressService.Push(player)
	return result
end

-- Zone la plus lointaine atteinte (appelé pendant l'expédition).
function ProgressService.NoteZone(player, zoneIndex)
	local data = DataService.Get(player)
	if data and zoneIndex > data.bestZone then
		data.bestZone = zoneIndex
		DataService.MarkDirty(player)
		ProgressService.Push(player)
	end
	ProgressService.AddQuest(player, "zone", zoneIndex)
end

function ProgressService.SetZone(player, key)
	local data = DataService.Get(player)
	local zone = Config.zoneByKey(key)
	if data and zone and Zoo.zoneUnlocked(zone, data.animals) then
		data.zone = key
		DataService.MarkDirty(player)
		return true
	end
	return false
end

function ProgressService.GetRopeStyle(player)
	local data = DataService.Get(player)
	local rope = data and Config.findById(Config.Ropes, data.equipped.rope)
	rope = rope or Config.Ropes[1]
	return rope.color, rope.neon
end

function ProgressService.GetUpgradeLevel(player, id)
	local data = DataService.Get(player)
	return data and data.upgrades[id] or 0
end

function ProgressService.ApplyCosmetics(player)
	local data = DataService.Get(player)
	local character = player.Character
	if data and character then
		Cosmetics.applyHat(character, data.equipped.hat)
	end
end

-- Achats Robux : renvoie true si le produit a été accordé.
function ProgressService.GrantProduct(player, product)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if product.kind == "gold" then
		data.coins = data.coins + product.amount
	elseif product.kind == "bones" then
		data.bones = data.bones + product.amount
	elseif product.kind == "boost" then
		settle(player, data) -- le boost ne s'applique qu'à partir de maintenant
		local now = os.time()
		data.boostUntil = math.max(data.boostUntil, now) + product.amount * 60
	elseif product.kind == "revive" then
		data.revives = data.revives + product.amount
	else
		return false
	end
	DataService.MarkDirty(player)
	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
	return true
end

-- ---------------------------------------------------------------------------
-- Actions demandées par le client (RemoteFunctions)
-- ---------------------------------------------------------------------------

local function result(ok, message)
	return { ok = ok, msg = message }
end

local function handleBuy(player, kind, id)
	if not Util.allow(player, "Buy", 0.25) then
		return result(false, "Trop rapide.")
	end
	if type(kind) ~= "string" or type(id) ~= "string" then
		return result(false, "Requête invalide.")
	end
	local data = DataService.Get(player)
	if not data then
		return result(false, "Profil en cours de chargement.")
	end

	if kind == "upgrade" then
		local def = Config.findById(Config.Upgrades, id)
		if not def then
			return result(false, "Amélioration inconnue.")
		end
		local level = data.upgrades[id] or 0
		if level >= def.max then
			return result(false, "Niveau maximum atteint.")
		end
		local price = def.costs[level + 1]
		if data.coins < price then
			return result(false, "Pas assez d'or.")
		end
		data.coins = data.coins - price
		data.upgrades[id] = level + 1
	elseif kind == "hat" or kind == "rope" then
		local list = kind == "hat" and Config.Hats or Config.Ropes
		local ownedSet = kind == "hat" and data.owned.hats or data.owned.ropes
		local def = Config.findById(list, id)
		if not def then
			return result(false, "Objet inconnu.")
		end
		if def.pass then
			return result(false, "Cet objet est réservé au pass " .. def.pass:upper() .. ".")
		end
		if ownedSet[id] then
			return result(false, "Déjà possédé.")
		end
		if data.coins < def.price then
			return result(false, "Pas assez d'or.")
		end
		data.coins = data.coins - def.price
		ownedSet[id] = true
		if kind == "hat" then
			data.equipped.hat = id
		else
			data.equipped.rope = id
		end
	else
		return result(false, "Type inconnu.")
	end

	DataService.MarkDirty(player)
	ProgressService.RefreshAttributes(player)
	ProgressService.ApplyCosmetics(player)
	ProgressService.Push(player)
	return result(true, "Achat réussi !")
end

local function handleEquip(player, kind, id)
	if not Util.allow(player, "Equip", 0.25) then
		return result(false, "Trop rapide.")
	end
	if type(kind) ~= "string" or type(id) ~= "string" then
		return result(false, "Requête invalide.")
	end
	local data = DataService.Get(player)
	if not data then
		return result(false, "Profil en cours de chargement.")
	end
	local hatDef = kind == "hat" and Config.findById(Config.Hats, id) or nil
	if
		kind == "hat"
		and (data.owned.hats[id] or (hatDef and hatDef.pass and ProgressService.HasPass(player, hatDef.pass)))
	then
		data.equipped.hat = id
	elseif kind == "rope" and data.owned.ropes[id] then
		data.equipped.rope = id
	else
		return result(false, "Tu ne possèdes pas cet objet.")
	end
	DataService.MarkDirty(player)
	ProgressService.ApplyCosmetics(player)
	ProgressService.Push(player)
	return result(true, "Équipé.")
end

local function handleDaily(player)
	if not Util.allow(player, "Daily", 0.5) then
		return result(false, "Trop rapide.")
	end
	local data = DataService.Get(player)
	if not data then
		return result(false, "Profil en cours de chargement.")
	end
	local day = today()
	if data.daily.last == day then
		return result(false, "Déjà récupéré aujourd'hui.")
	end
	if data.daily.last == day - 1 then
		data.daily.streak = data.daily.streak + 1
	else
		data.daily.streak = 1
	end
	data.daily.last = day
	local streak = math.min(data.daily.streak, Config.DailyReward.MaxStreak)
	local reward = Config.DailyReward.Base + Config.DailyReward.PerStreak * (streak - 1)
	data.coins = data.coins + reward
	DataService.MarkDirty(player)
	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
	return result(true, ("+%d or (série de %d jour(s))"):format(reward, data.daily.streak))
end

local function handleQuest(player, index)
	if not Util.allow(player, "Quest", 0.3) then
		return result(false, "Trop rapide.")
	end
	if type(index) ~= "number" or index % 1 ~= 0 then
		return result(false, "Requête invalide.")
	end
	local data = DataService.Get(player)
	local q = data and data.quests.list[index]
	if not q then
		return result(false, "Quête introuvable.")
	end
	local def = questDef(q.id)
	if not def then
		return result(false, "Quête inconnue.")
	end
	if q.claimed then
		return result(false, "Déjà récupérée.")
	end
	if q.progress < def.target then
		return result(false, "Quête non terminée.")
	end
	q.claimed = true
	data.coins = data.coins + def.reward
	DataService.MarkDirty(player)
	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
	return result(true, ("+%d or"):format(def.reward))
end

-- Actions du zoo : "collect" (caisse), "animal" (monter un animal avec des os), "zoo" (amélioration d'or),
-- "story" (récompense du chapitre), "zone" (zone de départ préférée).
local function handleZoo(player, action, key)
	if not Util.allow(player, "Zoo", 0.25) then
		return result(false, "Trop rapide.")
	end
	if type(action) ~= "string" then
		return result(false, "Requête invalide.")
	end
	local data = DataService.Get(player)
	if not data then
		return result(false, "Profil en cours de chargement.")
	end

	if action == "collect" then
		local gold = ProgressService.PendingGold(player)
		if gold <= 0 then
			return result(false, "La caisse est vide.")
		end
		data.coins = data.coins + gold
		data.pot = 0
		data.lastCollect = os.time()
		DataService.MarkDirty(player)
		ProgressService.RefreshAttributes(player)
		ProgressService.Push(player)
		return result(true, ("+%s or collectés"):format(Util.formatNumber(gold)))
	elseif action == "animal" then
		local def, variant = Zoo.parseKey(key)
		local entry = def and data.animals[key]
		if not entry then
			return result(false, "Animal introuvable dans ton zoo.")
		end
		local cost = Zoo.upgradeCost(def, variant, entry.level or 1)
		if not cost then
			return result(false, "Niveau maximum atteint.")
		end
		if data.bones < cost then
			return result(false, "Pas assez d'os.")
		end
		settle(player, data)
		data.bones = data.bones - cost
		entry.level = (entry.level or 1) + 1
		DataService.MarkDirty(player)
		ProgressService.OnZooChanged(player)
		ProgressService.Push(player)
		return result(true, ("%s niveau %d !"):format(def.name, entry.level))
	elseif action == "zoo" then
		local def = type(key) == "string" and Config.findById(Config.ZooUpgrades, key) or nil
		if not def then
			return result(false, "Amélioration inconnue.")
		end
		local level = data.zooUp[def.id] or 0
		if level >= def.max then
			return result(false, "Niveau maximum atteint.")
		end
		local price = def.costs[level + 1]
		if data.coins < price then
			return result(false, "Pas assez d'or.")
		end
		settle(player, data)
		data.coins = data.coins - price
		data.zooUp[def.id] = level + 1
		DataService.MarkDirty(player)
		ProgressService.RefreshAttributes(player)
		ProgressService.OnZooChanged(player)
		ProgressService.Push(player)
		return result(true, ("%s niveau %d !"):format(def.name, level + 1))
	elseif action == "story" then
		local chapter = currentChapter(data)
		if not chapter then
			return result(false, "Histoire terminée. Bravo !")
		end
		if goalProgress(data, chapter.goal) < chapter.goal.n then
			return result(false, "Objectif pas encore atteint.")
		end
		data.coins = data.coins + chapter.reward.gold
		data.bones = data.bones + chapter.reward.bones
		data.story.index = data.story.index + 1
		DataService.MarkDirty(player)
		ProgressService.RefreshAttributes(player)
		ProgressService.Push(player)
		return result(true, ("Chapitre terminé : +%d or, +%d os"):format(chapter.reward.gold, chapter.reward.bones))
	elseif action == "seen" then
		-- cinématique vue ou passée : on ne retient que des clés connues (aucune donnée libre du client)
		if not CinematicPlan.validKey(key) then
			return result(false, "Cinématique inconnue.")
		end
		if not data.seen[key] then
			data.seen[key] = true
			DataService.MarkDirty(player)
			ProgressService.Push(player)
		end
		return result(true, "Vue.")
	elseif action == "riddle" then
		dailyRiddle(data)
		if not data.riddle.solved then
			return result(false, "Récupère d'abord l'animal de l'énigme.")
		end
		if data.riddle.claimed then
			return result(false, "Déjà récupérée aujourd'hui.")
		end
		data.riddle.claimed = true
		data.coins = data.coins + Config.RiddleReward.gold
		data.bones = data.bones + Config.RiddleReward.bones
		DataService.MarkDirty(player)
		ProgressService.RefreshAttributes(player)
		ProgressService.Push(player)
		return result(true, ("Bravo ! +%d or, +%d os"):format(Config.RiddleReward.gold, Config.RiddleReward.bones))
	elseif action == "zone" then
		if ProgressService.SetZone(player, key) then
			ProgressService.Push(player)
			return result(true, "Zone de départ choisie.")
		end
		return result(false, "Zone verrouillée.")
	end
	return result(false, "Action inconnue.")
end

function ProgressService.Init()
	Remotes.Buy.OnServerInvoke = handleBuy
	Remotes.Equip.OnServerInvoke = handleEquip
	Remotes.ClaimDaily.OnServerInvoke = handleDaily
	Remotes.ClaimQuest.OnServerInvoke = handleQuest
	Remotes.ZooAction.OnServerInvoke = handleZoo

	Players.PlayerRemoving:Connect(function(player)
		pushScheduled[player] = nil
		Util.forget(player)
	end)
end

return ProgressService

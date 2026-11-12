-- Progression : pièces, boutique, améliorations, bestiaire, quêtes quotidiennes, cadeau du jour.
-- Toutes les décisions sont prises ici (serveur) ; le client ne fait que demander.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Cosmetics = require(script.Parent.Cosmetics)

local ProgressService = {}

-- Informations de la boutique Robux (remplies par MonetizationService : prix lus sur Roblox).
ProgressService.Store = { passes = {}, products = {} }

function ProgressService.HasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

function ProgressService.CoinMultiplier(player)
	return ProgressService.HasPass(player, "double") and 2 or 1
end

local pushScheduled = {}

local function today()
	return math.floor(os.time() / 86400)
end

local function questDef(id)
	return Config.findById(Config.QuestPool, id)
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

	return {
		loaded = true,
		passes = passes,
		store = ProgressService.Store,
		persistent = DataService.IsPersistent(player),
		coins = data.coins,
		bestScore = data.bestScore,
		wins = data.wins,
		rounds = data.rounds,
		hooks = data.hooks,
		tamedTotal = data.tamedTotal,
		distance = math.floor(data.distance),
		tamed = data.tamed,
		completed = data.completed,
		upgrades = data.upgrades,
		owned = { hats = hats, ropes = data.owned.ropes },
		equipped = data.equipped,
		daily = {
			claimable = claimable,
			streak = streak,
			reward = Config.DailyReward.Base + Config.DailyReward.PerStreak * (rewardStreak - 1),
		},
		quests = quests,
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
	local range = Config.Ride.HookBaseRange + Config.Ride.HookRangePerLevel * data.upgrades.range
	if ProgressService.HasPass(player, "rope") then
		range = range + Config.Monetization.RopeBonus
	end
	player:SetAttribute("HookRange", range)
	player:SetAttribute("Coins", data.coins)
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
-- Pièces et dressage
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

-- Enregistre un dressage. Renvoie { first = bool, complete = bool, coins = number }.
function ProgressService.RecordTame(player, def, variantIdx)
	local data = DataService.Get(player)
	local result = { first = false, complete = false, coins = 0 }
	if not data then
		return result
	end
	local variant = Config.Variants[variantIdx]
	local key = def.id .. "_" .. variantIdx
	result.first = (data.tamed[key] or 0) == 0
	data.tamed[key] = (data.tamed[key] or 0) + 1
	data.tamedTotal = data.tamedTotal + 1

	local coins = Config.Rewards.TameCoins * def.value * variant.mult
	if result.first then
		coins = coins + Config.Rewards.NewDiscovery
	end

	if not data.completed[def.id] then
		local all = true
		for v = 1, #Config.Variants do
			if (data.tamed[def.id .. "_" .. v] or 0) == 0 then
				all = false
				break
			end
		end
		if all then
			data.completed[def.id] = true
			result.complete = true
			coins = coins + Config.Rewards.SpeciesComplete
		end
	end

	result.coins = math.floor(coins * ProgressService.CoinMultiplier(player))
	data.coins = data.coins + result.coins
	DataService.MarkDirty(player)

	ProgressService.AddQuest(player, "tame", 1)
	if variantIdx > 1 then
		ProgressService.AddQuest(player, "rare", 1)
	end
	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
	return result
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
			return result(false, "Pas assez de pièces.")
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
			return result(false, "Pas assez de pièces.")
		end
		data.coins = data.coins - def.price
		ownedSet[id] = true
		-- équipement automatique à l'achat
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
	return result(true, ("+%d pièces (série de %d jour(s))"):format(reward, data.daily.streak))
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
	return result(true, ("+%d pièces"):format(def.reward))
end

function ProgressService.Init()
	Remotes.Buy.OnServerInvoke = handleBuy
	Remotes.Equip.OnServerInvoke = handleEquip
	Remotes.ClaimDaily.OnServerInvoke = handleDaily
	Remotes.ClaimQuest.OnServerInvoke = handleQuest

	Players.PlayerRemoving:Connect(function(player)
		pushScheduled[player] = nil
		Util.forget(player)
	end)
end

return ProgressService

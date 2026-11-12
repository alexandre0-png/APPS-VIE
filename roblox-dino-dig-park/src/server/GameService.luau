-- GameService.luau : cœur du jeu côté serveur (autorité unique sur toutes les données du joueur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Leaderboard = require(script.Parent.Leaderboard)

local GameService = {}
GameService.Monetization = nil -- injecté par Main

local sessions = {}
local rng = Random.new()
local function rand()
	return rng:NextNumber()
end

----------------------------------------------------------------------
-- Utilitaires
----------------------------------------------------------------------
local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, { text = text, kind = kind or "info" })
end
GameService.notify = notify

local function fx(player, payload)
	Remotes.Fx:FireClient(player, payload)
end

function GameService.getSession(player)
	return sessions[player]
end

local function flagsFor(s)
	local now = os.time()
	return {
		doubleCash = s.passes.doubleCash == true,
		autoDig = s.passes.autoDig == true,
		fastHatch = s.passes.fastHatch == true,
		boost = (s.boostUntil > now) and 2 or nil,
	}
end

local function applySpeed(player, s)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = s.passes.turbo and Config.TurboWalkSpeed or 16
	end
end

local function markDirty(s)
	s.dirty = true
end

local function rootPosition(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

----------------------------------------------------------------------
-- Quêtes
----------------------------------------------------------------------
local function generateQuests(player, s)
	local data = s.data
	local today = Util.dayNumber(os.time())
	local r = Random.new(today * 7919 + player.UserId % 100003)
	local pool = {}
	for i = 1, #Config.QuestTypes do
		pool[i] = i
	end
	-- mélange déterministe
	for i = #pool, 2, -1 do
		local j = r:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local income = Economy.incomePerSecond(data, {})
	local list = {}
	for n = 1, Config.QuestCount do
		local qt = Config.QuestTypes[pool[n]]
		local tier = r:NextInteger(1, 3)
		local target = qt.targets[tier]
		if qt.scaled then
			target = math.max(300, math.floor(income * 240 * tier))
		end
		table.insert(list, { id = qt.id, tier = tier, target = target, progress = 0, claimed = false })
	end
	data.quests = { day = today, list = list }
end

local function questProgress(s, id, amount)
	local data = s.data
	for _, q in ipairs(data.quests.list) do
		if q.id == id and not q.claimed then
			q.progress = math.min(q.target, q.progress + amount)
		end
	end
end

----------------------------------------------------------------------
-- Actions de jeu
----------------------------------------------------------------------
local function addDino(data, key)
	data.dinos[key] = (data.dinos[key] or 0) + 1
	local id = Economy.parseKey(key)
	local isNew = not data.discovered[id]
	data.discovered[id] = true
	return isNew
end

-- Détecte une montée de niveau (portes qui s'ouvrent) et offre une récompense
local function checkLevel(player, s)
	local data = s.data
	local level = Economy.parkLevel(data)
	if level > data.level then
		local reward = 100 * level
		data.level = level
		data.fossils = data.fossils + reward
		PlotService.refresh(player, data)
		notify(player, "⭐ Niveau " .. level .. " ! De nouvelles portes s'ouvrent (+" .. reward .. " 🦴)", "good")
		fx(player, { t = "levelup", level = level })
	end
end

local function grantEgg(player, s, eggId)
	local key = Economy.rollEgg(eggId, s.data, rand)
	local isNew = addDino(s.data, key)
	s.data.stats.hatched = s.data.stats.hatched + 1
	checkLevel(player, s)
	PlotService.refresh(player, s.data)
	fx(player, { t = "hatch", key = key, new = isNew, egg = eggId })
	return key, isNew
end

function GameService.dig(player, auto)
	local s = sessions[player]
	if not s then
		return
	end
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local now = os.clock()
	if not auto and now - s.lastDig < Config.DigCooldown then
		return
	end
	local pos = rootPosition(player)
	if not pos then
		return
	end
	local center = plot.refs.digCenter.Position
	local flat = Vector3.new(pos.X - center.X, 0, pos.Z - center.Z)
	if flat.Magnitude > Config.DigRadius + 14 then
		return
	end
	s.lastDig = now
	local data = s.data
	local amount = Economy.digAmount(data)
	local crit = rand() < Economy.critChance(data)
	if crit then
		amount = amount * Config.CritMultiplier
	end
	data.fossils = data.fossils + amount
	data.stats.digs = data.stats.digs + 1
	questProgress(s, "dig", 1)
	fx(player, { t = "dig", amount = amount, crit = crit })
	markDirty(s)
end

function GameService.collect(player)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	if data.pending < 1 then
		return
	end
	local amount = math.floor(data.pending)
	data.pending = data.pending - amount
	data.cash = data.cash + amount
	data.totalCash = data.totalCash + amount
	data.stats.collected = data.stats.collected + amount
	questProgress(s, "collect", amount)
	fx(player, { t = "collect", amount = amount })
	markDirty(s)
end

function GameService.buy(player, id)
	local s = sessions[player]
	if not s then
		return
	end
	local now = os.clock()
	if now - (s.lastBuy[id] or 0) < 0.6 then
		return
	end
	local data = s.data
	local ok, why = Economy.canBuy(data, id)
	if not ok then
		if now - s.lastPoor > 2.5 then
			if why == "pas assez de pièces" then
				s.lastPoor = now
				notify(player, "Pas assez de pièces !", "bad")
			elseif why == "niveau" then
				s.lastPoor = now
				notify(player, "🔒 Niveau " .. Config.BuildableById[id].level .. " requis : découvre plus de dinos !", "bad")
			end
		end
		return
	end
	s.lastBuy[id] = now
	local def = Config.BuildableById[id]
	data.cash = data.cash - def.cost
	data.buildables[id] = true
	data.stats.bought = data.stats.bought + 1
	questProgress(s, "buy", 1)
	PlotService.refresh(player, data)
	fx(player, { t = "buy", id = id })
	notify(player, def.name .. " débloqué !", "good")
	markDirty(s)
end

local function buyUpgrade(player, payload)
	local s = sessions[player]
	local id = type(payload) == "table" and payload.id
	local def = type(id) == "string" and Config.Upgrades[id]
	if not s or not def then
		return
	end
	local data = s.data
	local lvl = data.upgrades[id]
	if lvl >= def.max then
		return
	end
	local cost = Economy.upgradeCost(id, lvl)
	local currency = def.currency
	if data[currency] < cost then
		notify(player, "Pas assez de ressources !", "bad")
		return
	end
	data[currency] = data[currency] - cost
	data.upgrades[id] = lvl + 1
	questProgress(s, "upgrade", 1)
	fx(player, { t = "upgrade", id = id })
	markDirty(s)
end

local function startHatch(player, payload)
	local s = sessions[player]
	if not s or type(payload) ~= "table" then
		return
	end
	local slot, eggId = payload.slot, payload.egg
	if type(slot) ~= "number" or slot % 1 ~= 0 or type(eggId) ~= "string" then
		return
	end
	local data = s.data
	local egg = Config.Eggs[eggId]
	if not egg or slot < 1 or slot > Economy.incubatorCount(data) then
		return
	end
	if data.eggSlots[tostring(slot)] then
		return
	end
	local plot = PlotService.getPlot(player)
	local stand = plot and plot.stands[slot]
	local pos = rootPosition(player)
	if not stand or not pos or (stand.socle.Position - pos).Magnitude > 45 then
		return
	end
	if not Economy.eggUnlocked(data, eggId) then
		notify(player, "🔒 Cet œuf demande le niveau " .. egg.level .. ".", "bad")
		return
	end
	if data.fossils < egg.cost then
		notify(player, "Pas assez de fossiles !", "bad")
		return
	end
	data.fossils = data.fossils - egg.cost
	data.eggSlots[tostring(slot)] = { egg = eggId, finish = os.time() + Economy.hatchTime(eggId, data, flagsFor(s)) }
	PlotService.tick(player, data, os.time(), data.pending, Economy.boothCap(data, flagsFor(s)))
	markDirty(s)
end

local function collectHatch(player, slot)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	local info = data.eggSlots[tostring(slot)]
	if not info then
		return
	end
	if os.time() < info.finish then
		notify(player, "Cet œuf n'est pas encore prêt.", "info")
		return
	end
	data.eggSlots[tostring(slot)] = nil
	questProgress(s, "hatch", 1)
	local key = grantEgg(player, s, info.egg)
	local id = Economy.parseKey(key)
	local d = Config.DinoById[id]
	if Config.RarityById[d.rarity].order >= 5 then
		notify(player, "✨ " .. d.name .. " (" .. Config.RarityById[d.rarity].name .. ") !", "good")
	end
	markDirty(s)
end

local function standTriggered(player, slot)
	local s = sessions[player]
	if not s then
		return
	end
	local info = s.data.eggSlots[tostring(slot)]
	if not info then
		fx(player, { t = "openEggs", slot = slot })
	elseif os.time() >= info.finish then
		collectHatch(player, slot)
	else
		notify(player, "Éclosion dans " .. Util.formatTime(info.finish - os.time()), "info")
	end
end

local function sellReserve(player)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	local _, reserve = Economy.displayAndReserve(data)
	local total, count = 0, 0
	for key, n in pairs(reserve) do
		total = total + Economy.sellValue(key) * n
		count = count + n
		local left = data.dinos[key] - n
		if left <= 0 then
			data.dinos[key] = nil
		else
			data.dinos[key] = left
		end
	end
	if count == 0 then
		notify(player, "Aucun dino en réserve.", "info")
		return
	end
	data.cash = data.cash + total
	PlotService.refresh(player, data)
	notify(player, count .. " dino(s) vendu(s) : +" .. Util.formatNumber(total) .. " 💰", "good")
	markDirty(s)
end

local function claimDaily(player)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	local today = Util.dayNumber(os.time())
	if data.daily.last == today then
		notify(player, "Récompense déjà récupérée aujourd'hui.", "info")
		return
	end
	local streak = (data.daily.last == today - 1) and (data.daily.streak + 1) or 1
	local idx = ((streak - 1) % #Config.DailyRewards) + 1
	local r = Config.DailyRewards[idx]
	data.daily.last = today
	data.daily.streak = streak
	if r.kind == "fossils" then
		data.fossils = data.fossils + r.amount
		notify(player, "+" .. r.amount .. " 🦴", "good")
	elseif r.kind == "cash" then
		local inc = Economy.incomePerSecond(data, flagsFor(s))
		local amount = math.max(500, math.floor(inc * 60 * r.minutes))
		data.cash = data.cash + amount
		notify(player, "+" .. Util.formatNumber(amount) .. " 💰", "good")
	elseif r.kind == "egg" then
		grantEgg(player, s, r.egg)
	end
	markDirty(s)
end

local function claimQuest(player, payload)
	local s = sessions[player]
	local i = type(payload) == "table" and payload.index
	if not s or type(i) ~= "number" then
		return
	end
	local q = s.data.quests.list[i]
	if not q or q.claimed or q.progress < q.target then
		return
	end
	local data = s.data
	local qt
	for _, t in ipairs(Config.QuestTypes) do
		if t.id == q.id then
			qt = t
		end
	end
	q.claimed = true
	if qt.reward.fossils then
		local f = math.floor(qt.reward.fossils * q.tier * (1 + data.upgrades.shovel * 0.5) * Economy.fossilMultiplier(data))
		data.fossils = data.fossils + f
		notify(player, "Quête terminée : +" .. Util.formatNumber(f) .. " 🦴", "good")
	else
		local inc = Economy.incomePerSecond(data, flagsFor(s))
		local c = math.max(300 * q.tier, math.floor(inc * 60 * qt.reward.minutes * q.tier / 2))
		data.cash = data.cash + c
		notify(player, "Quête terminée : +" .. Util.formatNumber(c) .. " 💰", "good")
	end
	markDirty(s)
end

local function claimStory(player)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	local idx, value, target = Economy.storyCurrent(data)
	if not idx or value < target then
		return
	end
	local ch = Config.Story[idx]
	data.story.claimed = idx
	local r = ch.reward
	if r.fossils then
		data.fossils = data.fossils + r.fossils
		notify(player, "📖 " .. ch.title .. " : +" .. r.fossils .. " 🦴", "good")
	elseif r.cashMinutes then
		local inc = Economy.incomePerSecond(data, flagsFor(s))
		local amount = math.max(500, math.floor(inc * 60 * r.cashMinutes))
		data.cash = data.cash + amount
		notify(player, "📖 " .. ch.title .. " : +" .. Util.formatNumber(amount) .. " 💰", "good")
	elseif r.egg then
		notify(player, "📖 " .. ch.title .. " : un œuf offert !", "good")
		grantEgg(player, s, r.egg)
	end
	fx(player, { t = "story" })
	markDirty(s)
end

local function rebirth(player)
	local s = sessions[player]
	if not s then
		return
	end
	local data = s.data
	if data.rebirths >= Config.RebirthMax then
		return
	end
	local cost = Economy.rebirthCost(data.rebirths)
	if data.cash < cost then
		notify(player, "Il te faut " .. Util.formatNumber(cost) .. " 💰 pour une renaissance.", "bad")
		return
	end
	data.rebirths = data.rebirths + 1
	data.cash = 0
	data.pending = 0
	data.fossils = Config.StartFossils
	data.buildables = {}
	data.upgrades = { shovel = 0, luck = 0, hatch = 0, ticket = 0 }
	data.eggSlots = {}
	PlotService.refresh(player, data)
	PlotService.teleport(player)
	notify(player, "🌟 Nouvelle ère ! Revenus +" .. math.floor(Config.RebirthIncomeBonus * 100) .. "% définitivement.", "good")
	fx(player, { t = "rebirth" })
	grantEgg(player, s, "cosmic")
	markDirty(s)
end

local function findBone(player, id)
	local s = sessions[player]
	if not s or type(id) ~= "number" or id < 1 or id > Config.GoldBoneCount then
		return
	end
	local bones = s.data.secrets.bones
	local key = tostring(id)
	if bones[key] then
		notify(player, "Tu as déjà trouvé cet os doré.", "info")
		return
	end
	bones[key] = true
	local n = Util.count(bones)
	notify(player, "🦴 Os doré trouvé ! (" .. n .. "/" .. Config.GoldBoneCount .. ")", "good")
	if n >= Config.GoldBoneCount and not s.data.secrets.rewarded then
		s.data.secrets.rewarded = true
		local isNew = addDino(s.data, Config.SecretDinoId)
		PlotService.refresh(player, s.data)
		fx(player, { t = "hatch", key = Config.SecretDinoId, new = isNew, egg = "cosmic" })
		notify(player, "🌌 Dino secret débloqué : Aurore !", "good")
	end
	markDirty(s)
end

-- Boost temporaire (météores)
function GameService.addBoost(player, seconds, cap)
	local s = sessions[player]
	if not s then
		return
	end
	local now = os.time()
	s.boostUntil = math.min(now + (cap or 300), math.max(s.boostUntil, now) + seconds)
	markDirty(s)
end

function GameService.giveEgg(player, eggId)
	local s = sessions[player]
	if s and Config.Eggs[eggId] then
		grantEgg(player, s, eggId)
		markDirty(s)
	end
end

function GameService.addFossils(player, amount)
	local s = sessions[player]
	if not s then
		return
	end
	s.data.fossils = s.data.fossils + amount
	markDirty(s)
end

function GameService.grantCash(player, amount)
	local s = sessions[player]
	if not s then
		return
	end
	s.data.cash = s.data.cash + amount
	s.data.totalCash = s.data.totalCash + amount
	markDirty(s)
end

function GameService.computeIncome(player)
	local s = sessions[player]
	if not s then
		return 0
	end
	return Economy.incomePerSecond(s.data, flagsFor(s))
end

function GameService.setPass(player, key, value)
	local s = sessions[player]
	if s then
		s.passes[key] = value
		applySpeed(player, s)
		markDirty(s)
	end
end

----------------------------------------------------------------------
-- État envoyé au client
----------------------------------------------------------------------
local function buildState(player, s)
	local d = s.data
	local flags = flagsFor(s)
	local displayed, reserve = Economy.displayAndReserve(d)
	local mult = Economy.multipliers(d, flags)
	local base = Economy.baseIncome(displayed)
	local today = Util.dayNumber(os.time())
	local reserveValue = 0
	for key, n in pairs(reserve) do
		reserveValue = reserveValue + Economy.sellValue(key) * n
	end
	local configuredPasses = {}
	for k, p in pairs(Config.Passes) do
		configuredPasses[k] = { id = p.id, owned = s.passes[k] == true }
	end
	return {
		now = os.time(),
		cash = d.cash,
		fossils = d.fossils,
		pending = d.pending,
		cap = Economy.boothCap(d, flags),
		income = base * mult.total,
		baseIncome = base,
		mult = mult,
		dinos = d.dinos,
		reserve = reserve,
		discovered = d.discovered,
		buildables = d.buildables,
		upgrades = d.upgrades,
		eggSlots = d.eggSlots,
		incubators = Economy.incubatorCount(d),
		slots = Economy.slotCount(d),
		displayedCount = #displayed,
		rebirths = d.rebirths,
		rebirthCost = Economy.rebirthCost(d.rebirths),
		quests = d.quests.list,
		daily = { streak = d.daily.streak, canClaim = d.daily.last ~= today, last = d.daily.last },
		flags = flags,
		passes = configuredPasses,
		boostUntil = s.boostUntil,
		digAmount = Economy.digAmount(d),
		critChance = Economy.critChance(d),
		autoDigRate = Economy.autoDigRate(d),
		reserveValue = reserveValue,
		bones = Util.count(d.secrets.bones),
		level = Economy.parkLevel(d),
		levelHave = Economy.discoveredCount(d),
		levelNeed = Config.LevelThresholds[Economy.parkLevel(d)],
		storyClaimed = d.story.claimed,
		storyValue = (select(2, Economy.storyCurrent(d))),
		storyTarget = (select(3, Economy.storyCurrent(d))),
		stats = d.stats,
		volatile = DataService.isVolatile(player),
	}
end

local function pushState(player, s)
	s.dirty = false
	Remotes.State:FireClient(player, buildState(player, s))
end

----------------------------------------------------------------------
-- Cycle de vie des joueurs
----------------------------------------------------------------------
local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local inc = Instance.new("IntValue")
	inc.Name = "Revenus/s"
	inc.Parent = folder
	local ages = Instance.new("IntValue")
	ages.Name = "Ères"
	ages.Parent = folder
	folder.Parent = player
	return inc, ages
end

local function onPlayerAdded(player)
	local data, err = DataService.load(player)
	if not player.Parent then
		if data then
			DataService.release(player)
		end
		return
	end
	if not data then
		player:Kick("Impossible de charger ta progression (" .. tostring(err) .. "). Réessaie dans un instant.")
		return
	end
	local plot = PlotService.claim(player)
	if not plot then
		player:Kick("Le serveur est complet. Rejoins un autre serveur !")
		DataService.release(player)
		return
	end

	local s = {
		data = data,
		passes = {},
		boostUntil = 0,
		lastDig = 0,
		lastPoor = 0,
		lastBuy = {},
		lastAction = {},
		dirty = true,
		actionWindow = os.clock(),
		actionCount = 0,
		lastQuestCheck = 0,
	}
	s.incValue, s.agesValue = setupLeaderstats(player)
	sessions[player] = s

	if GameService.Monetization then
		GameService.Monetization.loadPasses(player, s.passes)
	end

	-- gains hors ligne
	local now = os.time()
	if data.lastSeen > 0 then
		local away = math.min(now - data.lastSeen, Economy.offlineCap(data))
		if away >= 120 then
			local inc = Economy.incomePerSecond(data, flagsFor(s))
			local gain = math.floor(inc * away * Config.OfflineEfficiency)
			if gain > 0 then
				data.cash = data.cash + gain
				data.totalCash = data.totalCash + gain
				task.delay(4, function()
					if player.Parent then
						notify(player, "Pendant ton absence, ton parc a rapporté " .. Util.formatNumber(gain) .. " 💰", "good")
					end
				end)
			end
		end
	end
	if data.quests.day ~= Util.dayNumber(now) or #data.quests.list == 0 then
		generateQuests(player, s)
	end

	PlotService.refresh(player, data)
	PlotService.tick(player, data, now, data.pending, Economy.boothCap(data, flagsFor(s)))

	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		PlotService.teleport(player)
		applySpeed(player, s)
	end)
	if player.Character then
		task.spawn(PlotService.teleport, player)
	end
	pushState(player, s)
end

local function onPlayerRemoving(player)
	sessions[player] = nil
	PlotService.release(player)
end

----------------------------------------------------------------------
-- Boucle principale (1 Hz)
----------------------------------------------------------------------
local function tickPlayer(player, s, dt)
	local data = s.data
	local flags = flagsFor(s)
	local now = os.time()
	local inc = Economy.incomePerSecond(data, flags)
	local cap = Economy.boothCap(data, flags)

	if data.buildables.helipad then
		local g = inc * dt
		data.cash = data.cash + g
		data.totalCash = data.totalCash + g
		data.stats.collected = data.stats.collected + g
		questProgress(s, "collect", g)
	else
		data.pending = math.min(cap, data.pending + inc * dt)
	end

	local rate = Economy.autoDigRate(data)
	if rate > 0 then
		data.fossils = data.fossils + rate * dt
	end
	data.stats.playTime = data.stats.playTime + dt

	if flags.autoDig then
		for _ = 1, 2 do
			GameService.dig(player, true)
		end
	end

	if now - s.lastQuestCheck >= 30 then
		s.lastQuestCheck = now
		if data.quests.day ~= Util.dayNumber(now) then
			generateQuests(player, s)
		end
	end

	checkLevel(player, s)
	PlotService.tick(player, data, now, data.pending, cap)
	s.incValue.Value = math.floor(inc)
	s.agesValue.Value = data.rebirths
	Leaderboard.submit(player, data.totalCash)
	markDirty(s)
end

local ACTION_COOLDOWN = {
	Rebirth = 2,
	SellReserve = 0.5,
	ClaimDaily = 1,
	StartHatch = 0.15,
	Upgrade = 0.1,
	ClaimQuest = 0.3,
	ClaimStory = 0.5,
}

local ACTIONS = {
	Upgrade = buyUpgrade,
	StartHatch = startHatch,
	CollectHatch = function(player, payload)
		local slot = type(payload) == "table" and payload.slot
		if type(slot) == "number" and slot >= 1 and slot <= 4 and slot % 1 == 0 then
			collectHatch(player, slot)
		end
	end,
	SellReserve = function(player)
		sellReserve(player)
	end,
	ClaimDaily = function(player)
		claimDaily(player)
	end,
	ClaimQuest = claimQuest,
	Rebirth = function(player)
		rebirth(player)
	end,
	ClaimStory = function(player)
		claimStory(player)
	end,
	Dig = function(player)
		GameService.dig(player, false)
	end,
	Collect = function(player)
		-- le joueur doit être près du kiosque
		local plot = PlotService.getPlot(player)
		local pos = rootPosition(player)
		if plot and pos and (plot.refs.boothPad.Position - pos).Magnitude < 40 then
			GameService.collect(player)
		end
	end,
	RequestState = function(player)
		local s = sessions[player]
		if s then
			markDirty(s)
		end
	end,
	BuyPass = function(player, payload)
		if GameService.Monetization and type(payload) == "table" then
			GameService.Monetization.prompt(player, payload.kind, payload.key)
		end
	end,
}

function GameService.init()
	PlotService.handlers.dig = function(player)
		GameService.dig(player, false)
	end
	PlotService.handlers.collect = GameService.collect
	PlotService.handlers.buy = GameService.buy
	PlotService.handlers.stand = standTriggered
	PlotService.handlers.bone = findBone

	Remotes.Action.OnServerEvent:Connect(function(player, name, payload)
		local s = sessions[player]
		if not s or type(name) ~= "string" then
			return
		end
		local now = os.clock()
		if now - s.actionWindow > 1 then
			s.actionWindow = now
			s.actionCount = 0
		end
		s.actionCount = s.actionCount + 1
		if s.actionCount > 30 then
			return
		end
		local handler = ACTIONS[name]
		-- actions lourdes : un délai minimal par action et par joueur
		local minGap = ACTION_COOLDOWN[name]
		if minGap then
			if now - (s.lastAction[name] or -1e9) < minGap then
				return
			end
			s.lastAction[name] = now
		end
		if handler then
			local ok, err = pcall(handler, player, payload)
			if not ok then
				warn("[GameService] erreur action", name, err)
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- tick principal
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local t = os.clock()
			local dt = math.min(t - last, 3)
			last = t
			for player, s in pairs(sessions) do
				if player.Parent then
					local ok, err = pcall(tickPlayer, player, s, dt)
					if not ok then
						warn("[GameService] erreur tick", err)
					end
				end
			end
		end
	end)

	-- envoi d'état groupé (4 Hz max)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, s in pairs(sessions) do
				if s.dirty and player.Parent then
					local ok, err = pcall(pushState, player, s)
					if not ok then
						warn("[GameService] erreur pushState", err)
						s.dirty = false
					end
				end
			end
		end
	end)
end

return GameService

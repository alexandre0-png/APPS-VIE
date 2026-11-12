-- Economy.luau : toute la logique d'équilibrage, pure et testable hors Roblox.
-- Utilisée par le serveur (autorité) et le client (affichage uniquement).

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local Economy = {}

-- "raptor:g" -> "raptor", true
function Economy.parseKey(key)
	local id = string.match(key, "^([%w_]+):g$")
	if id then
		return id, true
	end
	return key, false
end

function Economy.makeKey(id, golden)
	if golden then
		return id .. ":g"
	end
	return id
end

function Economy.dinoIncome(key)
	local id, golden = Economy.parseKey(key)
	local d = Config.DinoById[id]
	if not d then
		return 0
	end
	local inc = Config.RarityById[d.rarity].income
	if golden then
		inc = inc * Config.GoldenMultiplier
	end
	return inc
end

local function ownedCount(data, kind)
	local n = 0
	for id in pairs(data.buildables) do
		local b = Config.BuildableById[id]
		if b and b.kind == kind then
			n = n + 1
		end
	end
	return n
end
Economy.ownedCount = ownedCount

function Economy.slotCount(data)
	return Config.BaseSlots + Config.SlotsPerPen * ownedCount(data, "pen")
end

function Economy.incubatorCount(data)
	return 1 + ownedCount(data, "incubator")
end

function Economy.diggerCount(data)
	return ownedCount(data, "digger")
end

function Economy.discoveredCount(data)
	local n = 0
	for id, v in pairs(data.discovered) do
		if v and Config.DinoById[id] then
			n = n + 1
		end
	end
	return n
end

-- Liste triée (meilleurs d'abord) de toutes les clés possédées, développées par quantité.
function Economy.sortedOwned(data)
	local keys = {}
	for key, count in pairs(data.dinos) do
		if type(count) == "number" and count > 0 and Config.DinoById[(Economy.parseKey(key))] then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local ia, ib = Economy.dinoIncome(a), Economy.dinoIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	local list = {}
	for _, key in ipairs(keys) do
		for _ = 1, data.dinos[key] do
			table.insert(list, key)
		end
	end
	return list
end

-- Retourne displayed (liste de clés exposées dans les enclos) et reserve ({clé=quantité})
function Economy.displayAndReserve(data)
	local list = Economy.sortedOwned(data)
	local slots = Economy.slotCount(data)
	local displayed = {}
	local reserve = {}
	for i, key in ipairs(list) do
		if i <= slots then
			table.insert(displayed, key)
		else
			reserve[key] = (reserve[key] or 0) + 1
		end
	end
	return displayed, reserve
end

function Economy.baseIncome(displayed)
	local total = 0
	for _, key in ipairs(displayed) do
		total = total + Economy.dinoIncome(key)
	end
	return total
end

-- flags : { doubleCash = bool, boost = number|nil }
function Economy.multipliers(data, flags)
	flags = flags or {}
	local m = {}
	m.collection = 1 + Config.CollectionBonus * Economy.discoveredCount(data)
	m.rebirth = 1 + Config.RebirthIncomeBonus * data.rebirths
	m.ticket = 1 + 0.10 * data.upgrades.ticket
	local b = 0
	for id in pairs(data.buildables) do
		local def = Config.BuildableById[id]
		if def and def.bonus then
			b = b + def.bonus
		end
	end
	m.buildings = 1 + b
	m.pass = flags.doubleCash and 2 or 1
	m.boost = flags.boost or 1
	m.total = m.collection * m.rebirth * m.ticket * m.buildings * m.pass * m.boost
	return m
end

-- Revenu par seconde total
function Economy.incomePerSecond(data, flags)
	local displayed = Economy.displayAndReserve(data)
	return Economy.baseIncome(displayed) * Economy.multipliers(data, flags).total
end

function Economy.boothCap(data, flags)
	local inc = Economy.incomePerSecond(data, flags)
	return math.max(50, inc * Config.BoothSeconds)
end

function Economy.offlineCap(data)
	local secs = Config.OfflineMaxSeconds
	if data.buildables.helipad then
		secs = secs * 2
	end
	return secs
end

-- Fossiles
function Economy.fossilMultiplier(data)
	return 1 + Config.RebirthFossilBonus * data.rebirths
end

function Economy.digAmount(data)
	return math.floor((1 + data.upgrades.shovel) * Economy.fossilMultiplier(data))
end

function Economy.critChance(data)
	return Util.clamp(0.05 + 0.02 * data.upgrades.luck, 0, 0.6)
end

function Economy.autoDigRate(data)
	return Economy.diggerCount(data) * 0.6 * (1 + 0.25 * data.upgrades.shovel) * Economy.fossilMultiplier(data)
end

-- Oeufs
function Economy.hatchTime(eggId, data, flags)
	local egg = Config.Eggs[eggId]
	local f = math.max(0.4, 1 - 0.04 * data.upgrades.hatch)
	if flags and flags.fastHatch then
		f = f * 0.5
	end
	return math.max(3, math.floor(egg.time * f))
end

-- Bonus de chance : décale les poids des raretés supérieures
function Economy.eggWeights(eggId, data)
	local egg = Config.Eggs[eggId]
	local w = {}
	local luck = 1 + 0.05 * data.upgrades.luck
	for rid, weight in pairs(egg.weights) do
		local order = Config.RarityById[rid].order
		if order >= 3 then
			w[rid] = weight * luck
		else
			w[rid] = weight
		end
	end
	return w
end

-- Tire un dino. rng : fonction () -> [0,1)
function Economy.rollEgg(eggId, data, rng)
	local rid = Util.weightedPick(Economy.eggWeights(eggId, data), rng)
	local pool = Config.DinosByRarity[rid]
	local dino = pool[math.floor(rng() * #pool) + 1] or pool[#pool]
	local golden = rng() < (Config.GoldenChance + 0.002 * data.upgrades.luck)
	return Economy.makeKey(dino.id, golden), dino, golden
end

function Economy.upgradeCost(id, level)
	local u = Config.Upgrades[id]
	return math.floor(u.base * (u.growth ^ level))
end

function Economy.sellValue(key)
	return Economy.dinoIncome(key) * 120
end

function Economy.rebirthCost(rebirths)
	return math.floor(Config.RebirthBaseCost * (Config.RebirthGrowth ^ rebirths))
end

-- Niveau du parc : dépend du nombre de dinos différents découverts (ne s'achète pas)
function Economy.parkLevel(data)
	local n = Economy.discoveredCount(data)
	local level = 1
	for _, t in ipairs(Config.LevelThresholds) do
		if n >= t then
			level = level + 1
		end
	end
	return level
end

-- retourne niveau, dinos découverts, seuil du niveau suivant (nil au niveau max)
function Economy.levelProgress(data)
	local level = Economy.parkLevel(data)
	return level, Economy.discoveredCount(data), Config.LevelThresholds[level]
end

function Economy.eggUnlocked(data, eggId)
	local egg = Config.Eggs[eggId]
	return egg ~= nil and Economy.parkLevel(data) >= egg.level
end

-- Valeur actuelle pour une condition d'aventure
function Economy.storyValue(data, cond)
	local t = cond.type
	if t == "digs" then
		return data.stats.digs
	elseif t == "hatched" then
		return data.stats.hatched
	elseif t == "collected" then
		return data.stats.collected
	elseif t == "buildable" then
		return data.buildables[cond.id] and 1 or 0
	elseif t == "discovered" then
		return Economy.discoveredCount(data)
	elseif t == "level" then
		return Economy.parkLevel(data)
	elseif t == "bones" then
		return Util.count(data.secrets.bones)
	elseif t == "rebirths" then
		return data.rebirths
	end
	return 0
end

function Economy.storyTarget(cond)
	return cond.target or 1
end

-- Chapitre en cours : index, valeur, cible (nil si l'aventure est terminée)
function Economy.storyCurrent(data)
	local idx = data.story.claimed + 1
	local ch = Config.Story[idx]
	if not ch then
		return nil
	end
	return idx, Economy.storyValue(data, ch.cond), Economy.storyTarget(ch.cond)
end

function Economy.canBuy(data, id)
	local b = Config.BuildableById[id]
	if not b then
		return false, "inconnu"
	end
	if data.buildables[id] then
		return false, "déjà acheté"
	end
	if b.requires and not data.buildables[b.requires] then
		return false, "verrouillé"
	end
	if Economy.parkLevel(data) < b.level then
		return false, "niveau"
	end
	if data.cash < b.cost then
		return false, "pas assez de pièces"
	end
	return true
end

return Economy

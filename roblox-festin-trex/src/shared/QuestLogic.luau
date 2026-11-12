--!nonstrict
-- Logique des quêtes quotidiennes et de la série de connexion (pure).

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local QuestLogic = {}

local function findDef(kind: string): any?
	for _, d in ipairs(Config.Quests) do
		if d.Kind == kind then
			return d
		end
	end
	return nil
end
QuestLogic.findDef = findDef

-- Génère les quêtes du jour : déterministe pour (jour, joueur).
function QuestLogic.generate(day: number, userId: number): { any }
	local rnd = Util.lcg(day * 7919 + (userId % 100003) + 17)
	local pool = {}
	for _, d in ipairs(Config.Quests) do
		table.insert(pool, d)
	end
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local idx = math.floor(rnd() * #pool) + 1
		local def = table.remove(pool, idx)
		local tier = math.floor(rnd() * #def.Targets) + 1
		table.insert(list, {
			kind = def.Kind,
			target = def.Targets[tier],
			coins = def.BaseCoins * tier,
			eggs = if tier == #def.Targets then 1 else 0,
			progress = 0,
			claimed = false,
		})
	end
	return list
end

-- Régénère les quêtes si le jour a changé. Retourne true si changement.
function QuestLogic.ensure(data: any, day: number, userId: number): boolean
	if data.quests.day == day and #data.quests.list > 0 then
		return false
	end
	data.quests.day = day
	data.quests.list = QuestLogic.generate(day, userId)
	return true
end

-- Applique une progression. Retourne true si au moins une quête a changé.
function QuestLogic.progress(data: any, kind: string, amount: number): boolean
	local def = findDef(kind)
	if not def then
		return false
	end
	local changed = false
	for _, q in ipairs(data.quests.list) do
		if q.kind == kind and not q.claimed and q.progress < q.target then
			local before = q.progress
			if def.Mode == "max" then
				q.progress = math.min(q.target, math.max(q.progress, amount))
			else
				q.progress = math.min(q.target, q.progress + amount)
			end
			if q.progress ~= before then
				changed = true
			end
		end
	end
	return changed
end

-- Réclame une quête terminée. Retourne coins, eggs ou nil, raison.
function QuestLogic.claim(data: any, index: number): (number?, number?, string?)
	local q = data.quests.list[index]
	if not q then
		return nil, nil, "Quête introuvable"
	end
	if q.claimed then
		return nil, nil, "Déjà réclamée"
	end
	if q.progress < q.target then
		return nil, nil, "Quête non terminée"
	end
	q.claimed = true
	local mult = 1 + data.rebirths * Config.RebirthBonus
	return math.floor(q.coins * mult), q.eggs, nil
end

-- Série de connexion : retourne (peutRéclamer, prochainJourDeSérie)
function QuestLogic.dailyStatus(data: any, today: number): (boolean, number)
	local s = data.streak
	if s.last == today then
		return false, (s.count % #Config.Daily) + 1
	end
	if s.last == today - 1 then
		return true, (s.count % #Config.Daily) + 1
	end
	return true, 1
end

function QuestLogic.claimDaily(data: any, today: number): (number?, number?, number?, string?)
	local can, nextDay = QuestLogic.dailyStatus(data, today)
	if not can then
		return nil, nil, nil, "Déjà réclamé aujourd'hui"
	end
	local reward = Config.Daily[nextDay]
	data.streak.last = today
	data.streak.count = nextDay
	local mult = 1 + data.rebirths * Config.RebirthBonus
	return math.floor(reward.Coins * mult), reward.Eggs, nextDay, nil
end

return QuestLogic

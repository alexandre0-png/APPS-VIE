--!nonstrict
-- Calculs d'économie et de statistiques (purs, testables hors Studio).

local Config = require(script.Parent.Config)

local Economy = {}

export type Stats = {
	range: number,
	cooldown: number,
	capacity: number,
	assist: number,
	walkSpeed: number,
	coinMult: number,
	petMult: number,
	petSlots: number,
}

local function upgradeLevel(data: any, id: string): number
	local lvl = data.upgrades[id]
	if type(lvl) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(lvl))
end

function Economy.findFood(id: string): any?
	for _, f in ipairs(Config.Foods) do
		if f.Id == id then
			return f
		end
	end
	return nil
end

function Economy.findUpgrade(id: string): any?
	for _, u in ipairs(Config.Upgrades) do
		if u.Id == id then
			return u
		end
	end
	return nil
end

function Economy.findPet(id: string): any?
	for _, p in ipairs(Config.Pets) do
		if p.Id == id then
			return p
		end
	end
	return nil
end

-- Coût du prochain niveau d'une amélioration (level = niveau actuel).
function Economy.upgradeCost(def: any, level: number): number
	return math.floor(def.BaseCost * (def.Growth ^ level))
end

function Economy.rebirthCost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * (Config.RebirthCostGrowth ^ rebirths))
end

function Economy.rebirthMult(rebirths: number): number
	return 1 + Config.RebirthBonus * rebirths
end

function Economy.petSlots(data: any): number
	return Config.PetSlots + (if data.rebirths >= 5 then 1 else 0) + (if data.passes and data.passes.nest then 1 else 0)
end

-- Somme des bonus des compagnons équipés (ignore les ids invalides ou non possédés).
function Economy.petBonus(data: any): number
	local total = 0
	local seen: { [string]: boolean } = {}
	local slots = Economy.petSlots(data)
	for i, id in ipairs(data.equipped) do
		if i > slots then
			break
		end
		if type(id) == "string" and not seen[id] and (data.pets[id] or 0) > 0 then
			local def = Economy.findPet(id)
			if def then
				total += def.Mult
				seen[id] = true
			end
		end
	end
	return total
end

function Economy.stats(data: any): Stats
	local T = Config.Throw
	local power = upgradeLevel(data, "power")
	local rate = upgradeLevel(data, "rate")
	local basket = upgradeLevel(data, "basket")
	local greed = upgradeLevel(data, "greed")
	local aim = upgradeLevel(data, "aim")
	local boots = upgradeLevel(data, "boots")
	local petMult = Economy.petBonus(data)
	return {
		range = T.BaseRange + T.RangePerLevel * power,
		cooldown = math.max(T.MinCooldown, T.BaseCooldown - T.CooldownPerLevel * rate),
		capacity = T.BaseCapacity + T.CapacityPerLevel * basket,
		assist = (T.BaseAssist + T.AssistPerLevel * aim) * (if data.passes and data.passes.aim then 2 else 1),
		walkSpeed = T.BaseWalkSpeed + T.WalkPerLevel * boots,
		coinMult = (1 + 0.1 * greed + petMult) * Economy.rebirthMult(data.rebirths) * (if data.passes and data.passes.vip then 1.5 else 1),
		petMult = petMult,
		petSlots = Economy.petSlots(data),
	}
end

function Economy.comboMult(combo: number): number
	return 1 + Config.Combo.PerStep * math.min(combo, Config.Combo.Max)
end

function Economy.hitReward(foodValue: number, combo: number, isFav: boolean, hungry: boolean, eventMult: number, coinMult: number): number
	local fav = if isFav then Config.FavoriteMult else 1
	local hunger = if hungry then Config.HungryMult else 1
	local v = foodValue * Economy.comboMult(combo) * fav * hunger * eventMult * coinMult
	return math.max(1, math.floor(v + 0.5))
end

-- Niveau « gourmet » : fonction de la nourriture totale donnée.
function Economy.level(totalFed: number): (number, number, number)
	local level = math.min(99, math.floor(math.sqrt(math.max(0, totalFed) / 12)) + 1)
	local cur = (level - 1) ^ 2 * 12
	local nxt = level ^ 2 * 12
	local progress = if level >= 99 then 1 else (totalFed - cur) / (nxt - cur)
	return level, math.clamp(progress, 0, 1), math.floor(nxt)
end

function Economy.feastCoins(stageIndex: number, share: number, rebirths: number): number
	local base = Config.Feast.BaseCoins * stageIndex
	return math.floor(base * (0.4 + 1.6 * share) * Economy.rebirthMult(rebirths))
end

-- Tirage d'un compagnon : retourne l'id. rnd1 choisit la rareté, rnd2 le compagnon dans la rareté.
function Economy.rollPet(eggKind: string, rnd1: number, rnd2: number): string
	local egg = Config.Eggs[eggKind]
	local items = {}
	for _, r in ipairs(Config.Rarities) do
		table.insert(items, { id = r.Id, weight = egg.Odds[r.Id] or 0 })
	end
	local total = 0
	for _, it in ipairs(items) do
		total += it.weight
	end
	local target = rnd1 * total
	local acc = 0
	local rarity = items[#items].id
	for _, it in ipairs(items) do
		acc += it.weight
		if target < acc then
			rarity = it.id
			break
		end
	end
	local pool = {}
	for _, p in ipairs(Config.Pets) do
		if p.Rarity == rarity then
			table.insert(pool, p)
		end
	end
	return pool[math.min(#pool, math.floor(rnd2 * #pool) + 1)].Id
end

return Economy

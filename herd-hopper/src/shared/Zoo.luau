-- Formules du zoo (pures, sans API Roblox : testées avec Lune).
-- Un animal du zoo est identifié par "<espèce>_<variante>" (ex. "boar_2" = Phacochère Cristal).

local Config = require(script.Parent.Config)
local Species = require(script.Parent.Species)

local Zoo = {}

function Zoo.key(speciesId, variantIdx)
	return speciesId .. "_" .. variantIdx
end

-- Renvoie def, variantIdx pour une clé de zoo, ou nil.
function Zoo.parseKey(key)
	if type(key) ~= "string" then
		return nil, nil
	end
	local id, v = key:match("^(.+)_(%d+)$")
	local def = id and Species.ById[id]
	local variant = tonumber(v)
	if not def or not variant or not Config.Variants[variant] then
		return nil, nil
	end
	if def.boss and variant ~= 1 then
		return nil, nil
	end
	return def, variant
end

function Zoo.variantMult(def, variantIdx)
	if def.boss then
		return 1
	end
	return Config.Variants[variantIdx].mult
end

-- Revenu d'un animal par minute (avant visiteurs et boost).
function Zoo.animalIncome(def, variantIdx, level)
	local z = Config.Zoo
	return z.IncomePerMinute * def.value * Zoo.variantMult(def, variantIdx) * (1 + z.LevelBonus * (level - 1))
end

-- Coût en os pour passer de `level` à `level + 1` ; nil si niveau maximum.
function Zoo.upgradeCost(def, variantIdx, level)
	local z = Config.Zoo
	if level >= z.MaxAnimalLevel then
		return nil
	end
	local factor = def.boss and 3 or z.BoneCostByVariant[variantIdx]
	return math.ceil(z.BoneCostBase * z.BoneCostGrowth ^ (level - 1) * factor)
end

-- Os gagnés quand on récupère un animal déjà possédé.
function Zoo.duplicateBones(def, variantIdx)
	if def.boss then
		return Config.Zoo.BossBones
	end
	return Config.Zoo.DuplicateBones * Config.Variants[variantIdx].mult
end

-- animals = { [key] = { level = n } } ; renvoie le revenu total par minute avant visiteurs.
function Zoo.baseIncome(animals)
	local total = 0
	for key, entry in pairs(animals) do
		local def, variant = Zoo.parseKey(key)
		if def then
			total = total + Zoo.animalIncome(def, variant, entry.level or 1)
		end
	end
	return total
end

function Zoo.visitorFactor(visitorLevel, hasZooPass)
	local factor = 1 + Config.Zoo.VisitorBonus * visitorLevel
	if hasZooPass then
		factor = factor * Config.Zoo.PassVisitorFactor
	end
	return factor
end

function Zoo.slots(slotLevel, hasZooPass)
	local n = Config.Zoo.BaseSlots + Config.Zoo.SlotsPerLevel * slotLevel
	if hasZooPass then
		n = n + Config.Zoo.PassSlots
	end
	return math.min(n, Config.Zoo.MaxSlots)
end

function Zoo.storageMinutes(storageLevel)
	return Config.Zoo.StorageBaseMinutes + Config.Zoo.StoragePerLevel * storageLevel
end

-- Or en attente dans la caisse : revenu par seconde × temps écoulé, plafonné par la capacité.
-- `boostUntil` : instant (os.time) de fin du boost ; le boost ne compte que pendant sa durée.
function Zoo.pendingGold(ratePerMinute, lastCollect, now, storageLevel, boostUntil)
	local capSeconds = Zoo.storageMinutes(storageLevel) * 60
	local elapsed = math.clamp(now - lastCollect, 0, math.min(capSeconds, Config.Zoo.MaxOfflineMinutes * 60))
	local boosted = 0
	if boostUntil and boostUntil > lastCollect then
		boosted = math.clamp(math.min(boostUntil, now) - lastCollect, 0, elapsed)
	end
	local seconds = elapsed + boosted * (Config.Zoo.BoostFactor - 1)
	return math.floor(ratePerMinute / 60 * seconds)
end

-- Or d'une expédition : points × coefficient, bonus boutique de souvenirs et pass.
function Zoo.runGold(score, giftLevel, hasGoldPass)
	local gold = score * Config.Rewards.ScoreToCoins * (1 + Config.Zoo.GiftBonus * giftLevel)
	if hasGoldPass then
		gold = gold * Config.Monetization.GoldPassFactor
	end
	return math.floor(gold)
end

-- Nombre d'animaux différents possédés (clés valides).
function Zoo.countOwned(animals)
	local n = 0
	for key in pairs(animals) do
		if Zoo.parseKey(key) then
			n = n + 1
		end
	end
	return n
end

function Zoo.zoneUnlocked(zone, animals)
	return Zoo.countOwned(animals) >= zone.unlock
end

return Zoo

-- ModuleScript : ServerScriptService/Rules
-- Règles de jeu PURES (aucun service Roblox) : tirages, revenus, durées, capacités.
-- Config est injectée (Rules.new(Config)) pour que ces règles se testent hors de Roblox (Lune, voir tests/run.luau).
local Rules = {}

function Rules.new(Config)
	local R = {}

	-- Plafond (en %) de la part « rareté supérieure » : garantit que le poids « identique » ne devient jamais négatif
	-- (niveau 10 du Trèfle + événement + Pass Chance + Potion donnaient 87 % + 22 % de « plus bas » = poids négatif).
	R.MAX_UP = 70

	-- Tirage pondéré. `rnd` retourne un nombre dans [0, 1). Les poids négatifs sont traités comme 0.
	-- Ne retourne jamais un index de poids nul (sauf si tous les poids sont nuls : dernier index).
	function R.wpick(weights, rnd)
		local total, last = 0, #weights
		for i, w in ipairs(weights) do
			if w > 0 then
				total += w
				last = i
			end
		end
		if total <= 0 then
			return #weights
		end
		local r = rnd() * total
		for i, w in ipairs(weights) do
			if w > 0 then
				r -= w
				if r < 0 then
					return i
				end
			end
		end
		return last
	end

	-- Points de « rareté supérieure » (en %) selon les bonus actifs.
	function R.upPoints(luckLevel, luckEvent, passLucky, potionActive)
		local up = 12 + 3 * luckLevel
		if luckEvent then
			up += 10
		end
		if passLucky then
			up += 10
		end
		if potionActive then
			up += Config.LUCK_POTION_BONUS
		end
		return up
	end

	-- Poids { plus bas, identique, plus haut } pour un œuf de rareté `tier`.
	function R.tierWeights(tier, upPoints)
		local down = tier > 1 and 22 or 0
		local up = tier < #Config.TIERS and math.min(math.max(upPoints, 0), R.MAX_UP) or 0
		return { down, 100 - down - up, up }
	end

	function R.pickTier(tier, upPoints, rnd)
		return tier + R.wpick(R.tierWeights(tier, upPoints), rnd) - 2
	end

	function R.mutWeights(alienBoost)
		local w = {}
		for i, m in ipairs(Config.MUTS) do
			w[i] = m.weight
			if alienBoost and m.name == "Alien" then
				w[i] = m.weight * 5
			end
		end
		return w
	end

	function R.sizeWeights()
		local w = {}
		for i, z in ipairs(Config.SIZES) do
			w[i] = z.weight
		end
		return w
	end

	-- Tire un pet : { p = index d'espèce, s = index de taille, m = index de mutation }.
	function R.rollPet(eggTier, upPoints, alienBoost, rnd)
		local tier = R.pickTier(eggTier, upPoints, rnd)
		local ids = {}
		for i, p in ipairs(Config.PETS) do
			if p.tier == tier then
				ids[#ids + 1] = i
			end
		end
		local pick = ids[math.min(#ids, math.floor(rnd() * #ids) + 1)]
		return { p = pick, s = R.wpick(R.sizeWeights(), rnd), m = R.wpick(R.mutWeights(alienBoost), rnd) }
	end

	function R.multiplier(rebirths, foodLevel, goldEvent, pass2x)
		local m = (1 + 0.5 * rebirths) * (1 + 0.2 * foodLevel)
		if goldEvent then
			m *= 2
		end
		if pass2x then
			m *= 2
		end
		return m
	end

	function R.capacity(up)
		return 4 + up.slots
	end

	function R.carryCapacity(up)
		return 1 + up.bag
	end

	function R.hatchTime(tier, incLevel)
		return Config.HATCH[tier] * 0.9 ^ incLevel
	end

	function R.shieldTime(lockLevel)
		return Config.SHIELD_BASE + Config.SHIELD_PER_LEVEL * lockLevel
	end

	-- Revenu par seconde : somme des pets présents sur les emplacements débloqués, multipliée par `mult`.
	function R.income(slots, capacity, mult)
		local total = 0
		for i = 1, capacity do
			local sl = slots[i]
			if sl and sl.k == "p" then
				total += Config.petIncome(sl.p, sl.s, sl.m)
			end
		end
		return total * mult
	end

	return R
end

return Rules

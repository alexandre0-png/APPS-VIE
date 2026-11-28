-- ModuleScript : ServerScriptService/Rules
-- Règles de jeu PURES (aucun service Roblox) : tirages, revenus, durées, capacités.
-- Config est injectée (Rules.new(Config)) pour que ces règles se testent hors de Roblox (Lune, voir tests/run.luau).
local Rules = {}

function Rules.new(Config)
	local R = {}

	-- Plafond (en %) de la part « rareté supérieure » : garantit que le poids « identique » ne devient jamais négatif
	-- (niveau 10 du Trèfle + événement + Pass Chance + Potion donnaient 87 % + 22 % de « plus bas » = poids négatif).
	R.MAX_UP = Config.UPGRADE.maxUp or 70

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
	-- lot 16 : passLucky2 = passe « Chance +10 % II » (+10, compte dans les bonus payants plafonnés). La Double chance est appliquée par le serveur APRÈS (x2, 70 au plus).
	function R.upPoints(luckLevel, luckEvent, passLucky, potionActive, serverLuck, passLucky2)
		local up = Config.UPGRADE.base + luckLevel -- 5 % de base : UNE chance d'amélioration d'un cran (jamais de rétrogradation)
		if luckEvent then
			up += Config.UPGRADE.event
		end
		-- lot 9 (BOOST_CAP) : les bonus PAYANTS (pass Chance, potion, pluie de chance) sont plafonnés ensemble à Config.BOOST_CAP.paidUp points
		local paid = 0
		if passLucky then
			paid += Config.UPGRADE.pass
		end
		if passLucky2 then
			paid += Config.UPGRADE.pass
		end
		if potionActive then
			paid += Config.LUCK_POTION_BONUS
		end
		if serverLuck then
			paid += Config.SERVER_LUCK.bonus -- pluie de chance offerte au serveur (lot 7) : valeur fixe, jamais cumulée avec elle-même
		end
		local capPaid = Config.BOOST_CAP and Config.BOOST_CAP.paidUp
		if type(capPaid) == "number" then
			paid = math.min(paid, capPaid)
		end
		return up + paid
	end

	-- Poids { plus bas, identique, plus haut } pour un œuf de rareté `tier`. Lot 9 : « plus haut » = rareté PUBLIÉE suivante (Config.nextLiveTier),
	-- seulement pour un œuf <= Config.UPGRADE.maxEggTier (Mythique) : Ultra Rare, Secret, Exclusif et Divin ont une rareté fixe.
	function R.tierWeights(tier, upPoints)
		local down = 0 -- l'œuf annoncé fixe la rareté : jamais de rareté inférieure
		local up = Config.eggUpShare(tier, math.min(math.max(type(upPoints) == "number" and upPoints or 0, 0), R.MAX_UP))
		return { down, 100 - down - up, up }
	end

	function R.pickTier(tier, upPoints, rnd)
		local k = R.wpick(R.tierWeights(tier, upPoints), rnd)
		if k == 3 then
			return Config.nextLiveTier(tier) or tier
		end
		return tier
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
	-- `guaranteed` : tirage de pitié, le pet est forcément d'une rareté au-dessus de l'œuf (sauf œuf de rareté maximale).
	-- `open` (A5) : fenêtres d'événement / de saison ouvertes ({ [étiquette] = true }, Rewards.openSpeciesEvents) ; nil = aucune. Une espèce marquée `event`
	-- n'est tirée que si sa fenêtre est ouverte ; une rareté sans espèce tirable (œuf Exclusif hors fenêtre) donne la rareté inférieure (Config.poolTier).
	function R.rollPet(eggTier, upPoints, alienBoost, rnd, guaranteed, open)
		local tier
		eggTier = Config.poolTier(Config.liveEggTier(eggTier), open) -- rareté sans espèce publiée (A.3) ou sans espèce tirable maintenant (A5) : celle juste en dessous
		if guaranteed and eggTier <= Config.UPGRADE.maxEggTier and Config.nextLiveTier(eggTier) then
			tier = Config.nextLiveTier(eggTier)
		else
			tier = R.pickTier(eggTier, upPoints, rnd)
		end
		tier = Config.poolTier(tier, open)
		local ids = Config.speciesPool(tier, open)
		local pick = ids[math.min(#ids, math.floor(rnd() * #ids) + 1)]
		return { p = pick, s = R.wpick(R.sizeWeights(), rnd), m = R.wpick(R.mutWeights(alienBoost), rnd), tier = tier }
	end

	function R.multiplier(rebirths, foodLevel, goldEvent, pass2x, collectionBonus)
		local m = (1 + 0.5 * rebirths) * (1 + 0.2 * foodLevel) * (collectionBonus or 1)
		if goldEvent then
			m *= 2
		end
		if pass2x then
			m *= 2
		end
		return m
	end

	-- Capacité d'une base (REFONTE lot 5) : 4 + améliorations (0..8) + bonus du niveau de maison (Config.levelSlots, 0..4) + pass ExtraSlots (4) = 20 au plus.
	-- `level` et `passExtra` sont facultatifs (appels historiques : 4 + améliorations).
	function R.capacity(up, level, passExtra)
		local n = 4 + up.slots + (level and Config.levelSlots(level) or 0) + (passExtra and Config.PASS_EXTRA_SLOTS or 0)
		return math.min(n, Config.SLOTS_MAX)
	end

	-- Multiplicateur de revenu de la maison (1 + bonus du niveau).
	function R.levelMul(level)
		return Config.levelIncomeMul(level or 1)
	end

	function R.carryCapacity(up)
		return 1 + up.bag
	end

	function R.hatchTime(tier, incLevel, fastPass)
		return Config.HATCH[tier] * 0.9 ^ incLevel * (fastPass and 0.75 or 1)
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
				total += Config.petIncome(sl.p, sl.s, sl.m, sl.f) -- idée 2 : forme 2 (sl.f = 2) x Config.EVOLUTION.incomeMul
			end
		end
		return total * mult
	end

	return R
end

return Rules

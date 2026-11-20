-- ModuleScript : ReplicatedStorage/Shared/Reveal
-- Probabilité EXACTE d'un tirage et texte « 1 sur N » de la révélation d'œuf. Pur (Rules est injecté) et testé : la probabilité affichée
-- est celle que Rules.rollPet applique réellement (même poids de rareté, d'espèce, de taille, de mutation ; tirage de pitié inclus).
local Reveal = {}

-- Probabilité d'obtenir exactement (espèce p, taille s, mutation m) d'un œuf de rareté eggTier. guaranteed = tirage de pitié.
function Reveal.probability(Config, Rules, eggTier, upPoints, alienBoost, p, s, m, guaranteed)
	local def = Config.PETS[p]
	if not def or not Config.SIZES[s] or not Config.MUTS[m] then
		return 0
	end
	local pTier
	if guaranteed and eggTier < #Config.TIERS then
		pTier = def.tier == eggTier + 1 and 1 or 0
	else
		local w = Rules.tierWeights(eggTier, upPoints)
		local total = w[1] + w[2] + w[3]
		local idx = def.tier - eggTier + 2
		pTier = (idx >= 1 and idx <= 3 and total > 0) and (math.max(w[idx], 0) / total) or 0
	end
	if pTier == 0 then
		return 0
	end
	local species = 0
	for _, q in ipairs(Config.PETS) do
		if q.tier == def.tier then
			species = species + 1
		end
	end
	local function share(weights, index)
		local total = 0
		for _, x in ipairs(weights) do
			total = total + math.max(x, 0)
		end
		return total > 0 and math.max(weights[index], 0) / total or 0
	end
	return pTier * (1 / species) * share(Rules.sizeWeights(), s) * share(Rules.mutWeights(alienBoost), m)
end

-- « 1 sur N » : N = 1 / probabilité (math.huge si impossible).
function Reveal.oneIn(Config, Rules, eggTier, upPoints, alienBoost, p, s, m, guaranteed)
	local pr = Reveal.probability(Config, Rules, eggTier, upPoints, alienBoost, p, s, m, guaranteed)
	return pr > 0 and 1 / pr or math.huge
end

-- Style de la révélation selon la rareté du pet et la probabilité réelle. Un tirage plus rare que Config.REVEAL.secret.oneInAtLeast
-- déclenche l'effet « œuf secret ». reduced = option mobile (moins de rayons, de particules et de secousse).
function Reveal.style(Config, petTier, oneIn, reduced)
	local R = Config.REVEAL
	local base = R.tiers[math.min(math.max(petTier, 1), #R.tiers)]
	local st = {}
	for k, v in pairs(base) do
		st[k] = v
	end
	st.secret = oneIn ~= nil and oneIn >= R.secret.oneInAtLeast
	if st.secret then
		for k, v in pairs(R.secret) do
			st[k] = v
		end
	end
	st.color = st.secret and R.secret.color or Config.TIERS[math.min(math.max(petTier, 1), #Config.TIERS)].color
	st.banner = Config.rarityBanner(petTier, st.secret)
	if reduced then
		local k = R.reducedFactor
		st.rays = math.max(4, math.floor(st.rays * k))
		st.particles = math.floor(st.particles * k)
		st.shake = st.shake * k
		st.rings = math.max(1, math.floor(st.rings * k + 0.5))
	end
	return st
end

return Reveal

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
	eggTier = Config.liveEggTier(eggTier)
	local nxt = Config.nextLiveTier(eggTier)
	if guaranteed and eggTier <= Config.UPGRADE.maxEggTier and nxt then
		pTier = def.tier == nxt and 1 or 0
	else
		local w = Rules.tierWeights(eggTier, upPoints)
		local total = w[1] + w[2] + w[3]
		local idx = def.tier == eggTier and 2 or (def.tier == nxt and 3 or 0)
		pTier = (idx >= 1 and total > 0) and (math.max(w[idx], 0) / total) or 0
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

-- Écran de tirage « machine à sous » : plan PUR des 3 colonnes. Chaque colonne est un anneau de symboles ; la position (continue, base 1) part de 1, tourne
-- `loops` tours puis ralentit (sortie en puissance 4) et s'arrête EXACTEMENT sur le résultat réel. fast : durées courtes (tirage banal ou mobile).
function Reveal.slotPlan(Config, petTier, sizeIdx, mutIdx, fast)
	local S = Config.REVEAL.slot
	local stops = fast and S.fastStops or S.stops
	local function column(title, symbols, final, k)
		local n = #symbols
		local f = math.min(math.max(math.floor(tonumber(final) or 1), 1), n)
		return { title = title, symbols = symbols, final = f, stop = stops[k], travel = n * S.loops[k] + (f - 1) }
	end
	local tiers, sizes, muts = {}, {}, {}
	for i, t in ipairs(Config.TIERS) do
		tiers[i] = { text = t.name, color = t.color }
	end
	for i, z in ipairs(Config.SIZES) do
		sizes[i] = { text = z.name } -- couleur nil : blanc côté client
	end
	for i, m in ipairs(Config.MUTS) do
		muts[i] = { text = m.name == "" and "Normal" or m.name, color = m.color }
	end
	local cols = { column("RARETÉ", tiers, petTier, 1), column("TAILLE", sizes, sizeIdx, 2), column("MUTATION", muts, mutIdx, 3) }
	return { columns = cols, duration = cols[3].stop + S.hold, hold = S.hold, tier = math.min(math.max(math.floor(tonumber(petTier) or 1), 1), #Config.TIERS) }
end

-- Position continue de la colonne `col` à l'instant t (s) : croît sans jamais reculer, ralentit, vaut exactement 1 + travel à l'arrêt.
function Reveal.slotPos(col, t)
	local u = math.min(math.max(t / col.stop, 0), 1)
	return 1 + col.travel * (1 - (1 - u) ^ 4)
end

-- Indice (1..n) du symbole centré à la position pos.
function Reveal.slotIndex(col, pos)
	local n = #col.symbols
	return (math.floor(pos + 0.5) - 1) % n + 1
end

return Reveal

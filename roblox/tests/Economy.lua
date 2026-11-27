-- Simulation d'économie (pure, sans Roblox) : un joueur-robot « raisonnable » joue `minutes` minutes de JEU ACTIF avec les règles réelles
-- (Config.EGG_PRICE, Config.HATCH, Config.UPGRADES, Rules.rollPet / income / hatchTime, Config.sellValue, Config.BELT, Config.BASE_LEVELS).
-- Sert de garde-fou d'équilibrage : tests/run.luau vérifie le rythme (lot 9 : cibles du recalibrage, de 13 s à plusieurs semaines de jeu actif) et
-- tools/sim_economy.py affiche le détail et calcule Config.PRICING (temps de gain en pièces, 3 profils).
-- Ne simule NI le vol, NI les quêtes, NI l'histoire, NI les événements : c'est le rythme de base boutique + tapis, sans récompense.
-- Lot 9 : pas de temps ADAPTATIF (1 s pendant les 2 premières heures, 10 s jusqu'à 48 h, 60 s au-delà : les jalons longs se mesurent à la minute
-- près), tapis traité œuf par œuf à l'intérieur d'un pas (heure d'arrivée exacte), tapis privé, potion et pass Chance permanents (pire cas),
-- `projected` = espèces VIRTUELLES pour les raretés sans espèce publiée (3 par rareté, revenus dans Config.INCOME_RANGE) : projection du lot 11.
-- Hypothèses du joueur-robot au tapis (inchangées depuis le lot 8A) :
--   T1  il voit chaque œuf du tapis ; d'autres joueurs en prennent : il n'obtient un œuf qu'il veut qu'avec la probabilité `beltShare` (0,5) ;
--   T2  il achète un œuf du tapis si son prix <= 70 % de ses pièces, qu'un emplacement est libre et que sa rareté est >= celle qu'il achèterait en
--       boutique (même rareté 40 % moins chère, ou rareté supérieure, seule source des raretés > SHOP_MAX_TIER) ;
--   T3  porter l'œuf à sa base prend `carrySeconds` (15 s) pendant lesquels il n'achète rien au tapis ; règles anti-monopole respectées
--       (1 achat / buyCooldown, 1 œuf de rareté >= TIER_GATE.belt2s / 60 s) ; l'œuf est posé à l'arrivée s'il reste une place, sinon perdu.
-- opts : seed, sellPets, belt (true par défaut), golden (tapis doré permanent), private (pass tapis privé), potion (potion permanente), lucky (pass Chance),
-- beltShare, carrySeconds, sellAvg, coinsAt = { [t] = pièces }, starter (pack de départ à 2 s), coinPackEvery (un sac de pièces toutes les N s),
-- projected, afford = { coûts } (premier instant où les pièces GAGNÉES depuis `affordFrom` s atteignent chaque coût), affordFrom.
local Economy = {}

-- Espèces virtuelles (projection du lot 11) : 3 par rareté sans espèce (1 pour l'Exclusif), revenus répartis dans Config.INCOME_RANGE.
function Economy.projectedPets(Config)
	local out = {}
	for _, p in ipairs(Config.PETS) do
		out[#out + 1] = p
	end
	for t = 1, #Config.TIERS do
		if not Config.tierLive(t) then
			local r = Config.INCOME_RANGE[t]
			local n = (t == 9) and 1 or 3
			for k = 1, n do
				local f = n == 1 and 0.5 or (k - 1) / (n - 1)
				out[#out + 1] = { tier = t, emoji = "?", name = "Projection " .. t .. "." .. k, inc = r[1] + (r[2] - r[1]) * f, projected = true }
			end
		end
	end
	return out
end

function Economy.simulate(Config, Rules, minutes, opts)
	opts = opts or {}
	if opts.projected then
		local real = Config.PETS
		Config.PETS = Economy.projectedPets(Config)
		local ok, res = pcall(Economy.run, Config, Rules, minutes, opts)
		Config.PETS = real
		if not ok then
			error(res)
		end
		return res
	end
	return Economy.run(Config, Rules, minutes, opts)
end

function Economy.run(Config, Rules, minutes, opts)
	local seed = opts.seed or 12345
	local function rnd()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	-- Lot 16 : second flux (Park-Miller 48271, produit < 2^47) pour la décision « T1 » (beltShare) des œufs Secret et plus. Avec le flux unique, un
	-- tirage Divin (rnd >= 1 - 5e-5) est TOUJOURS suivi d'un rnd > 0,16 (x 16807, sans repli modulo) : « 1 - 16807 d / M » ; sous 0,002 % de poids,
	-- le robot n'achetait JAMAIS un œuf Divin (artefact du générateur, pas de l'économie). Le flux principal est consommé comme avant : les raretés
	-- <= Ultra Rare gardent exactement les mêmes tirages (mesures du lot 9 inchangées sans projection).
	local seed2 = ((opts.seed or 12345) * 7919 + 13) % 2147483647
	if seed2 == 0 then
		seed2 = 1
	end
	local function rnd2()
		seed2 = (seed2 * 48271) % 2147483647
		return seed2 / 2147483647
	end
	local up = {}
	for _, u in ipairs(Config.UPGRADES) do
		up[u.key] = 0
	end
	local coins, hatched, pity = Config.START_COINS or 50, 0, 0
	local earned = 0 -- pièces gagnées depuis le début (revenu + reventes), pour les temps de gain
	local slots = { { k = "e", t = 1, ends = Config.FIRST_EGG_SECONDS or 6 } } -- œuf de départ gratuit (Data.default)
	local log = { marks = {}, firstEggTier = {}, firstUp = {}, spent = {}, firstPetTier = {}, baseLevelAt = {}, afford = {}, earnedAt = {} }
	local baseScore = 0
	local dex, species = {}, 0
	local dexN = {}
	local level = 1
	local function cap()
		return Rules.capacity(up, level)
	end
	local function income()
		local mult = Rules.multiplier(0, up.food, false, false, Config.collectionBonus(species)) * Rules.levelMul(level)
		return Rules.income(slots, cap(), mult)
	end
	local function freeSlot()
		for i = 1, cap() do
			if not slots[i] then
				return i
			end
		end
	end
	local function weakest()
		local wi, wv
		for i = 1, cap() do
			local sl = slots[i]
			if sl and sl.k == "p" then
				local v = Config.petIncome(sl.p, sl.s, sl.m)
				if not wv or v < wv then
					wi, wv = i, v
				end
			end
		end
		return wi, wv
	end
	local sellPets = opts.sellPets ~= false
	local useBelt = opts.belt ~= false
	local BELT = Config.BELT
	local rawW = opts.golden and BELT.weights.golden or BELT.weights.normal
	local beltW = opts.projected and rawW or Config.foldWeights(rawW)
	local beltEvery = opts.golden and BELT.golden.interval or BELT.interval
	local beltShare = opts.beltShare or 0.5
	local carrySeconds = opts.carrySeconds or 15
	local shopMax = Config.SHOP_MAX_TIER or #Config.TIERS
	local gateLeg = Config.TIER_GATE.belt2s
	local upPts = Rules.upPoints(0, false, opts.lucky == true, opts.potion == true, false)
	local beltBusy, lastLegBelt, carrying = 0, -1e9, nil
	log.beltBought, log.beltLost, log.privateEggs = 0, 0, 0
	log.affordBelt = {}
	local RARE_BELT = { 8, 10 }
	local function pickTier(w)
		local tot = 0
		for _, x in ipairs(w) do
			tot = tot + x
		end
		local r = rnd() * tot
		local last = #w
		for i, x in ipairs(w) do
			if x > 0 then
				last = i
				r = r - x
				if r < 0 then
					return i
				end
			end
		end
		return last
	end
	-- Lot 16 : tirage du tapis. Le flux principal décide comme avant si l'œuf est d'une rareté >= Ultra Rare (même probabilité totale, mêmes
	-- tirages pour toutes les raretés inférieures) ; le partage entre Ultra Rare, Secret, Exclusif et Divin se fait sur le second flux. Avec le seul
	-- flux principal, un Secret / Divin exige rnd >= 1 - 1e-6 et la structure de Park-Miller (16807) faisait sortir ces valeurs bien plus souvent
	-- qu'attendu dans la suite de tirages du robot (4 graines sur 5 avaient un Divin vers 20 jours pour une attente moyenne de 58 jours).
	local RARE_SPLIT = 7
	local function pickBelt(w)
		local bt = pickTier(w)
		if bt < RARE_SPLIT then
			return bt
		end
		local tot = 0
		for i = RARE_SPLIT, #w do
			tot = tot + w[i]
		end
		local r = rnd2() * tot
		for i = RARE_SPLIT, #w do
			if w[i] > 0 then
				r = r - w[i]
				if r < 0 then
					return i
				end
			end
		end
		return bt
	end
	local SELL_AVG = opts.sellAvg or 2 -- lot 9 : 2 (le robot remplace un pet sous 2 fois la moyenne de la rareté visée ; 1 au lot 8A)
	local hatchHappy = opts.hatchHappy ~= false
	local avgInc, nInc = {}, {}
	for _, def in ipairs(Config.PETS) do
		avgInc[def.tier] = (avgInc[def.tier] or 0) + def.inc
		nInc[def.tier] = (nInc[def.tier] or 0) + 1
	end
	for t, v in pairs(avgInc) do
		avgInc[t] = v / nInc[t]
	end
	local function sellBelow(tier)
		local rk = Config.tierRank(tier) -- rang parmi les raretés publiées (= ancien indice pour les 18 espèces historiques)
		return math.max(Config.PETS[1].inc * 6 * (rk ^ 2), SELL_AVG * (avgInc[tier] or 0))
	end
	local function makeRoom(tier, doSell, price)
		local i = freeSlot()
		if not i and sellPets then
			local wi, wv = weakest()
			-- lot 9 : le robot continue d'éclore (comme un joueur réel qui fait grandir sa maison) : il revend son pet le plus faible si ce pet rapporte
			-- moins que le seuil, OU s'il est d'une rareté inférieure à celle de l'œuf, OU (dès Mythique) de la même rareté quand l'œuf coûte moins de 0,5 % de ses pièces
			-- (le joueur riche continue d'éclore pour une meilleure taille ou mutation ; opts.hatchHappy, vrai par défaut)
			if wi and (wv < sellBelow(tier) or (hatchHappy and (Config.PETS[slots[wi].p].tier < tier or (Config.PETS[slots[wi].p].tier == tier and tier >= Config.TIER_GATE.pillar and (price or math.huge) <= 0.005 * coins)))) then
				if doSell then
					local v = Config.sellValue(slots[wi].p, slots[wi].s, slots[wi].m)
					coins = coins + v
					earned = earned + v
					slots[wi] = false
				end
				i = wi
			end
		end
		return i
	end
	local function shopBest()
		for tier = shopMax, 1, -1 do
			if Config.tierLive(tier) and Config.EGG_PRICE[tier] > 0 and Config.EGG_PRICE[tier] <= coins * 0.7 then
				return tier
			end
		end
		return 0
	end
	local priv = { acc = 0, queue = {} }
	local horizon = minutes * 60
	local t = 0
	local lastIncomeGain = 0
	local bestInc = 0
	local nextMark = 60
	local afford = opts.afford
	local affordFrom = opts.affordFrom or 0
	local earnedFrom = nil
	while t < horizon do
		local dt = (t < 7200 and 1) or (t < 172800 and 10) or 60
		local t0 = t
		t = t + dt
		local inc = income()
		coins = coins + inc * dt
		earned = earned + inc * dt
		if earnedFrom == nil and t >= affordFrom then
			earnedFrom = earned
		end
		if afford and earnedFrom then
			for k, c in ipairs(afford) do
				if log.afford[k] == nil and earned - earnedFrom >= c then
					log.afford[k] = t - affordFrom
				end
			end
		end
		if opts.coinsAt and opts.coinsAt[t] then
			coins = coins + opts.coinsAt[t]
		end
		if opts.starter and t == 2 then
			coins = coins + Config.STARTER_PACK.coins
			for _ = 1, Config.STARTER_PACK.eggs do
				local i = freeSlot()
				if i then
					slots[i] = { k = "e", t = Config.STARTER_PACK.eggTier, ends = t + Rules.hatchTime(Config.STARTER_PACK.eggTier, up.inc, false) }
				end
			end
		end
		if opts.coinPackEvery and math.floor(t / opts.coinPackEvery) > math.floor(t0 / opts.coinPackEvery) then
			local gift = math.max(Config.COIN_PACK_MIN, income() * 60 * Config.COIN_PACK_MINUTES)
			coins = coins + gift
			log.coinPacks = (log.coinPacks or 0) + 1
		end
		-- tapis privé (pass) : un œuf gratuit toutes les `interval` s d'activité, `pending` en attente au plus, table standard ; le robot le prend
		-- dès qu'il a une place (aller-retour négligé : le tapis est dans sa base)
		if opts.private then
			local P = BELT.private
			if #priv.queue < P.pending then
				priv.acc = priv.acc + dt
				if priv.acc >= P.interval then
					priv.acc = priv.acc - P.interval
					-- rareté tirée À LA CRÉATION (comme Belt.privateStep) : le robot ne peut pas « relancer » en attendant une place
					priv.queue[#priv.queue + 1] = pickBelt(opts.projected and BELT.weights.normal or Config.foldWeights(BELT.weights.normal))
				end
			end
			while #priv.queue > 0 do
				local pt = priv.queue[1]
				local i = makeRoom(pt, true)
				if not i then
					break
				end
				table.remove(priv.queue, 1)
				slots[i] = { k = "e", t = pt, ends = t + Rules.hatchTime(pt, up.inc, false) }
				log.privateEggs = log.privateEggs + 1
			end
		end
		-- tapis roulant (T1 à T3) : chaque arrivée du pas, à son heure exacte
		if useBelt then
			local k0 = math.floor(t0 / beltEvery) + 1
			local k1 = math.floor(t / beltEvery)
			for k = k0, k1 do
				local ta = k * beltEvery
				if carrying and ta >= carrying.at then
					local i = makeRoom(carrying.t, true)
					if i then
						slots[i] = { k = "e", t = carrying.t, ends = carrying.at + Rules.hatchTime(carrying.t, up.inc, false) }
					else
						log.beltLost = log.beltLost + 1
					end
					carrying = nil
				end
				-- lot 16 : premier passage du tapis où le robot POURRAIT acheter un œuf Secret / Divin (prix <= 70 % de ses pièces) ; sert à l'espérance
				-- du premier Secret / Divin (tests/run.luau : ce moment + attente moyenne d'une apparition achetée, beltEvery / (poids x beltShare))
				for _, rt in ipairs(RARE_BELT) do
					if log.affordBelt[rt] == nil and beltW[rt] > 0 and Config.EGG_PRICE[rt] > 0 and math.floor(Config.EGG_PRICE[rt] * BELT.priceRatio) <= coins * 0.7 then
						log.affordBelt[rt] = ta
					end
				end
				local bt = pickBelt(beltW)
				local price = math.floor(Config.EGG_PRICE[bt] * BELT.priceRatio)
				local isLeg = bt >= gateLeg
				local wants = price > 0 and not carrying and ta >= beltBusy and price <= coins * 0.7 and makeRoom(bt, false, price) ~= nil and bt >= shopBest() and (not isLeg or ta - lastLegBelt >= 60)
				local share = wants and rnd() or 1
				if wants and bt >= 8 then
					share = rnd2()
				end
				if wants and share < beltShare then
					coins = coins - price
					carrying = { t = bt, at = ta + carrySeconds }
					beltBusy = ta + math.max(carrySeconds, BELT.buyCooldown)
					if isLeg then
						lastLegBelt = ta
					end
					log.beltBought = log.beltBought + 1
					log.firstEggTier[bt] = log.firstEggTier[bt] or ta
					log.spentBelt = (log.spentBelt or 0) + price
				end
			end
			if carrying and t >= carrying.at then
				local i = makeRoom(carrying.t, true)
				if i then
					slots[i] = { k = "e", t = carrying.t, ends = carrying.at + Rules.hatchTime(carrying.t, up.inc, false) }
				else
					log.beltLost = log.beltLost + 1
				end
				carrying = nil
			end
		end
		-- éclosions
		for i = 1, cap() do
			local sl = slots[i]
			if sl and sl.k == "e" and t >= sl.ends then
				hatched = hatched + 1
				pity = pity + 1
				log.firstHatch = log.firstHatch or t
				local guaranteed = Config.PITY_ENABLED and pity >= Config.PITY_EVERY and sl.t <= Config.UPGRADE.maxEggTier
				local r = Rules.rollPet(sl.t, Config.effectiveUp(sl.t, upPts + up.luck, Config.dexTopTier(dexN)), false, rnd, guaranteed)
				if r.tier > sl.t then
					pity = 0
				end
				slots[i] = { k = "p", p = r.p, s = r.s, m = r.m }
				log.firstPetTier[r.tier] = log.firstPetTier[r.tier] or t
				baseScore = baseScore + Config.baseGain(r.tier)
				local key = tostring(r.p)
				dexN[key] = { n = (dexN[key] and dexN[key].n or 0) + 1 }
				local lv = Config.baseLevel(baseScore, dexN, nil)
				level = math.max(level, lv)
				for l = 2, lv do
					log.baseLevelAt[l] = log.baseLevelAt[l] or t
				end
				if not dex[r.p] then
					dex[r.p] = true
					species = species + 1
				end
			end
		end
		-- achats : améliorations d'abord si elles coûtent moins de 80 % des pièces, puis le meilleur œuf abordable
		local acted = true
		while acted do
			acted = false
			local bestU, bestUCost
			for _, key in ipairs({ "slots", "food", "inc", "luck" }) do
				local u = Config.upgrade(key)
				if up[key] < u.max then
					local c = u.cost(up[key])
					if c <= coins and c <= coins * 0.8 and (not bestUCost or c < bestUCost) then
						bestU, bestUCost = key, c
					end
				end
			end
			if bestU and (bestU ~= "luck" or coins > 3000) then
				coins = coins - bestUCost
				up[bestU] = up[bestU] + 1
				log.firstUp[bestU .. up[bestU]] = log.firstUp[bestU .. up[bestU]] or t
				acted = true
			else
				local bestT = shopBest()
				if bestT > 0 then
					local i = makeRoom(bestT, true, Config.EGG_PRICE[bestT])
					if i then
						coins = coins - Config.EGG_PRICE[bestT]
						slots[i] = { k = "e", t = bestT, ends = t + Rules.hatchTime(bestT, up.inc, false) }
						log.firstEggTier[bestT] = log.firstEggTier[bestT] or t
						acted = true
					end
				end
			end
		end
		inc = income()
		if inc > bestInc * 1.0001 then
			bestInc = inc
			lastIncomeGain = t
		end
		if t <= 7200 then
			log.maxStall = math.max(log.maxStall or 0, t - lastIncomeGain) -- blocage mesuré sur les 2 premières heures (au-delà, les paliers sont longs par conception)
		end
		if t >= nextMark then
			log.marks[nextMark] = { coins = coins, income = inc, hatched = hatched, score = baseScore, slots = cap(), food = up.food, inc = up.inc, species = species, level = level, earned = earned }
			nextMark = nextMark < 3600 and nextMark + 60 or (nextMark < 172800 and nextMark + 1800 or nextMark + 21600)
		end
		if not log.firstIncome10 and inc >= 10 then
			log.firstIncome10 = t
		end
		if not log.firstIncome100 and inc >= 100 then
			log.firstIncome100 = t
		end
		if not log.firstIncome1000 and inc >= 1000 then
			log.firstIncome1000 = t
		end
	end
	log.final = { coins = coins, income = income(), hatched = hatched, up = up, species = species, level = level, score = baseScore, cap = cap(), earned = earned }
	return log
end

return Economy

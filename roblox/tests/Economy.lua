-- Simulation d'économie (pure, sans Roblox) : un joueur-robot « raisonnable » joue `minutes` minutes avec les règles réelles
-- (Config.EGG_PRICE, Config.HATCH, Config.UPGRADES, Rules.rollPet / income / hatchTime, Config.sellValue). Sert de garde-fou d'équilibrage :
-- tests/run.luau vérifie le rythme (premiers achats, revenus à 5/10/20/30 min, absence de blocage) et le détail se lit avec tools/sim_economy.py.
-- Ne simule NI le vol, NI les quêtes, NI l'histoire, NI les événements : c'est le rythme de base de la boutique, sans bonus de récompense.
-- Lot 8A : intègre le TAPIS ROULANT (Config.BELT : un œuf toutes les `interval` s, table standard ou dorée, prix x priceRatio, rareté visible avant
-- l'achat), le revenu de la maison (Rules.levelMul) et les 20 emplacements (Rules.capacity, plafond SLOTS_MAX). Hypothèses du joueur-robot au tapis :
--   T1  il voit chaque œuf du tapis ; d'autres joueurs en prennent : il n'obtient un œuf qu'il veut qu'avec la probabilité `beltShare` (0,5) ;
--   T2  il achète un œuf du tapis si son prix <= 70 % de ses pièces, qu'un emplacement est libre et que sa rareté est >= celle qu'il achèterait en
--       boutique (même rareté 40 % moins chère, ou rareté supérieure, seule source de Mythique / Cosmique quand SHOP_MAX_TIER = 4) ;
--   T3  porter l'œuf à sa base prend `carrySeconds` (15 s) pendant lesquels il n'achète rien au tapis ; règles anti-monopole respectées
--       (1 achat / 3 s, 1 œuf Légendaire+ / 60 s) ; l'œuf est posé à l'arrivée s'il reste une place, sinon perdu (cas rare, compté).
-- opts : seed, sellPets, belt (true par défaut), golden (tapis doré permanent), beltShare, carrySeconds, sellAvg, coinsAt = { [t] = pièces },
-- starter (pack de départ à 2 s), coinPackEvery (un sac de pièces toutes les N s).
local Economy = {}

function Economy.simulate(Config, Rules, minutes, opts)
	opts = opts or {}
	local seed = opts.seed or 12345
	local function rnd()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local up = {}
	for _, u in ipairs(Config.UPGRADES) do
		up[u.key] = 0
	end
	local coins, hatched, pity = Config.START_COINS or 50, 0, 0
	local slots = {} -- [i] = { k = "e", t, ends } | { k = "p", p, s, m }
	local log = { marks = {}, firstEggTier = {}, firstUp = {}, spent = {}, firstPetTier = {}, baseLevelAt = {} }
	local baseScore = 0
	local dex, species = {}, 0
	local dexN = {} -- dex au format du profil (clé = indice d'espèce en texte) : conditions de rareté des niveaux 7 et 8
	local level = 1
	local function cap()
		return Rules.capacity(up, level) -- lot 5 : 4 + améliorations + bonus de la maison (sans le pass)
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
	local beltW = opts.golden and BELT.weights.golden or BELT.weights.normal
	local beltEvery = opts.golden and BELT.golden.interval or BELT.interval
	local beltShare = opts.beltShare or 0.5
	local carrySeconds = opts.carrySeconds or 15
	local shopMax = Config.SHOP_MAX_TIER or #Config.TIERS
	local beltBusy, lastLegBelt, carrying = 0, -1e9, nil
	log.beltBought, log.beltLost = 0, 0
	local function beltTier()
		local tot = 0
		for _, w in ipairs(beltW) do
			tot = tot + w
		end
		local r = rnd() * tot
		for i, w in ipairs(beltW) do
			r = r - w
			if r < 0 then
				return i
			end
		end
		return #beltW
	end
	-- seuil de revente (lot 8A) : un pet est remplacé s'il rapporte moins que l'ancien seuil 6 x rareté^2 OU que la moitié du revenu moyen d'un pet
	-- de la rareté visée (sans ce second seuil, un robot plein de Légendaires ne remplaçait plus rien : blocage de plus de 1 h 30 en fin de partie)
	local SELL_AVG = opts.sellAvg or 1
	local avgInc = {}
	for _, def in ipairs(Config.PETS) do
		avgInc[def.tier] = (avgInc[def.tier] or 0) + def.inc / 3
	end
	local function sellBelow(tier)
		return math.max(Config.PETS[1].inc * 6 * (tier ^ 2), SELL_AVG * (avgInc[tier] or 0))
	end
	-- emplacement pour un œuf de rareté `tier` : libre, ou (si doSell) le plus faible pet revendu s'il rapporte moins que sellBelow(tier)
	local function makeRoom(tier, doSell)
		local i = freeSlot()
		if not i and sellPets then
			local wi, wv = weakest()
			if wi and wv < sellBelow(tier) then
				if doSell then
					coins = coins + Config.sellValue(slots[wi].p, slots[wi].s, slots[wi].m)
					slots[wi] = false
				end
				i = wi
			end
		end
		return i
	end
	local function shopBest()
		for tier = shopMax, 1, -1 do
			if Config.EGG_PRICE[tier] <= coins * 0.7 then
				return tier
			end
		end
		return 0
	end
	local checkpoints = { [60] = true, [180] = true, [300] = true, [600] = true, [900] = true, [1200] = true, [1500] = true, [1800] = true, [2700] = true, [3600] = true, [7200] = true, [10800] = true, [14400] = true, [18000] = true, [21600] = true }
	local horizon = minutes * 60
	local t = 0
	local lastIncomeGain = 0
	local bestInc = 0
	while t < horizon do
		t = t + 1
		coins = coins + income()
		if opts.coinsAt and opts.coinsAt[t] then
			coins = coins + opts.coinsAt[t]
		end
		if opts.starter and t == 2 then -- pack de départ (Robux, une fois) : pièces + œufs Rares posés dans les places libres
			coins = coins + Config.STARTER_PACK.coins
			for _ = 1, Config.STARTER_PACK.eggs do
				local i = freeSlot()
				if i then
					slots[i] = { k = "e", t = Config.STARTER_PACK.eggTier, ends = t + Rules.hatchTime(Config.STARTER_PACK.eggTier, up.inc, false) }
				end
			end
		end
		if opts.coinPackEvery and t % opts.coinPackEvery == 0 then -- sac de pièces (Robux) : max(plancher, revenu de COIN_PACK_MINUTES min)
			local gift = math.max(Config.COIN_PACK_MIN, income() * 60 * Config.COIN_PACK_MINUTES)
			coins = coins + gift
			log.coinPacks = (log.coinPacks or 0) + 1
		end
		-- tapis roulant (T1 à T3)
		if useBelt then
			if carrying and t >= carrying.at then
				local i = makeRoom(carrying.t, true)
				if i then
					slots[i] = { k = "e", t = carrying.t, ends = t + Rules.hatchTime(carrying.t, up.inc, false) }
				else
					log.beltLost = log.beltLost + 1
				end
				carrying = nil
			end
			if t % beltEvery == 0 then
				local bt = beltTier()
				local price = math.floor(Config.EGG_PRICE[bt] * BELT.priceRatio)
				local wants = not carrying and t >= beltBusy and price <= coins * 0.7 and makeRoom(bt, false) ~= nil and bt >= shopBest() and (bt < 4 or t - lastLegBelt >= 60)
				if wants and rnd() < beltShare then
					coins = coins - price
					carrying = { t = bt, at = t + carrySeconds }
					beltBusy = t + math.max(carrySeconds, BELT.buyCooldown)
					if bt >= 4 then
						lastLegBelt = t
					end
					log.beltBought = log.beltBought + 1
					log.firstEggTier[bt] = log.firstEggTier[bt] or t
					log.spentBelt = (log.spentBelt or 0) + price
				end
			end
		end
		-- éclosions
		for i = 1, cap() do
			local sl = slots[i]
			if sl and sl.k == "e" and t >= sl.ends then
				hatched = hatched + 1
				pity = pity + 1
				log.firstHatch = log.firstHatch or t
				local guaranteed = Config.PITY_ENABLED and pity >= Config.PITY_EVERY and sl.t < #Config.TIERS
				local r = Rules.rollPet(sl.t, Rules.upPoints(up.luck, false, false, false), false, rnd, guaranteed)
				if r.tier > sl.t then
					pity = 0
				end
				slots[i] = { k = "p", p = r.p, s = r.s, m = r.m }
				log.firstPetTier[r.tier] = log.firstPetTier[r.tier] or t
				baseScore = baseScore + Config.baseGain(r.tier)
				local k = tostring(r.p)
				dexN[k] = { n = (dexN[k] and dexN[k].n or 0) + 1 }
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
		-- achats : améliorations d'abord si elles coûtent moins de 40 % des pièces, puis le meilleur œuf abordable
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
				if bestT == 0 then
					bestT = nil
				end
				if bestT then
					local i = makeRoom(bestT, true)
					if i then
						coins = coins - Config.EGG_PRICE[bestT]
						slots[i] = { k = "e", t = bestT, ends = t + Rules.hatchTime(bestT, up.inc, false) }
						log.firstEggTier[bestT] = log.firstEggTier[bestT] or t
						acted = true
					end
				end
			end
		end
		local inc = income()
		if inc > bestInc then
			bestInc = inc
			lastIncomeGain = t
		end
		log.maxStall = math.max(log.maxStall or 0, t - lastIncomeGain)
		if checkpoints[t] then
			log.marks[t] = { coins = coins, income = inc, hatched = hatched, score = baseScore, slots = cap(), food = up.food, inc = up.inc, species = species }
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
	log.final = { coins = coins, income = income(), hatched = hatched, up = up, species = species, level = level, score = baseScore, cap = cap() }
	return log
end

return Economy

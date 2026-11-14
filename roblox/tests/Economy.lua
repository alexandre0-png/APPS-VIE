-- Simulation d'économie (pure, sans Roblox) : un joueur-robot « raisonnable » joue `minutes` minutes avec les règles réelles
-- (Config.EGG_PRICE, Config.HATCH, Config.UPGRADES, Rules.rollPet / income / hatchTime, Config.sellValue). Sert de garde-fou d'équilibrage :
-- tests/run.luau vérifie le rythme (premiers achats, revenus à 5/10/20/30 min, absence de blocage) et le détail se lit avec tools/sim_economy.py.
-- Ne simule NI le vol, NI les quêtes, NI l'histoire, NI les événements : c'est le rythme de base de la boutique, sans bonus de récompense.
local Economy = {}

function Economy.simulate(Config, Rules, minutes, opts)
	opts = opts or {}
	local seed = opts.seed or 12345
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local up = {}
	for _, u in ipairs(Config.UPGRADES) do
		up[u.key] = 0
	end
	local coins, hatched, pity = Config.START_COINS or 50, 0, 0
	local slots = {} -- [i] = { k = "e", t, ends } | { k = "p", p, s, m }
	local log = { marks = {}, firstEggTier = {}, firstUp = {}, spent = {} }
	local dex, species = {}, 0
	local function income()
		local mult = Rules.multiplier(0, up.food, false, false, Config.collectionBonus(species))
		return Rules.income(slots, Rules.capacity(up), mult)
	end
	local function freeSlot()
		for i = 1, Rules.capacity(up) do
			if not slots[i] then
				return i
			end
		end
	end
	local function weakest()
		local wi, wv
		for i = 1, Rules.capacity(up) do
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
	local checkpoints = { [60] = true, [180] = true, [300] = true, [600] = true, [900] = true, [1200] = true, [1500] = true, [1800] = true, [2700] = true, [3600] = true }
	local horizon = minutes * 60
	local t = 0
	local lastIncomeGain = 0
	local bestInc = 0
	while t < horizon do
		t = t + 1
		coins = coins + income()
		-- éclosions
		for i = 1, Rules.capacity(up) do
			local sl = slots[i]
			if sl and sl.k == "e" and t >= sl.ends then
				hatched = hatched + 1
				pity = pity + 1
				local guaranteed = pity >= Config.PITY_EVERY and sl.t < #Config.TIERS
				local r = Rules.rollPet(sl.t, Rules.upPoints(up.luck, false, false, false), false, rnd, guaranteed)
				if r.tier > sl.t then
					pity = 0
				end
				slots[i] = { k = "p", p = r.p, s = r.s, m = r.m }
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
				local bestT
				for tier = #Config.TIERS, 1, -1 do
					if Config.EGG_PRICE[tier] <= coins * 0.7 then
						bestT = tier
						break
					end
				end
				if bestT then
					local i = freeSlot()
					if not i and sellPets then
						local wi, wv = weakest()
						-- on libère un emplacement seulement si le pet vendu rapporte moins que l'œuf visé ne promet
						if wi and wv < Config.PETS[1].inc * 6 * (bestT ^ 2) then
							coins = coins + Config.sellValue(slots[wi].p, slots[wi].s, slots[wi].m)
							slots[wi] = false
							i = wi
						end
					end
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
			log.marks[t] = { coins = coins, income = inc, hatched = hatched, slots = Rules.capacity(up), food = up.food, inc = up.inc, species = species }
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
	log.final = { coins = coins, income = income(), hatched = hatched, up = up, species = species }
	return log
end

return Economy

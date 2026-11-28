-- ModuleScript : ReplicatedStorage/Shared/Npc
-- LOT 15 (F) : logique PURE des PNJ qui interpellent le joueur (aucun service Roblox). Le SERVEUR génère l'offre, la range dans un carnet (`book`), la lie au userId, la fait
-- expirer après 60 s et ne l'accepte qu'une fois ; le client ne renvoie que l'identifiant et « accepter ». Jamais de Robux, jamais d'échange entre joueurs.
-- Config attendu : TIERS, EGG_PRICE, PETS, SIZES, MUTS (existants) + NPCS, NPC_ENCOUNTER, NPC_RULES, DIALOGUES, TYPE_WEAK (bloc « LOT 15 » de Config.lua). Toute rareté passe par Config.TIERS (noms).
-- État de profil `npc` : day (jour UTC des compteurs), trades / fights (rencontres du jour), enc (rencontres du jour, alternance), nextAt (secondes UNIX absolues),
-- off (« Ne plus être interpellé »), champ (semaine du dernier Champion errant), refuse / gone (refus de suite et PNJ partis pour la journée, par clé de PNJ).
-- Style : pas de `+=`, pas de `continue`, valeurs douteuses gardées par type avant toute comparaison.
-- Inventaire fourni par le serveur à chaque appel (`inv`) : { coins, pets = { { slot, p, s, m, follower, team, defense } }, seen = { [p] = true }, typeOf = fn(p) -> type, avgLevel, teamTiers = { rareté } }.
local Npc = {}

local function isnum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function int(v, lo, hi, def)
	if not isnum(v) then
		return def
	end
	v = math.floor(v)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end
Npc.int = int

local function rint(rng, a, b)
	return a + math.floor(rng() * (b - a + 1))
end

-- Indice d'une rareté d'après son NOM dans Config.TIERS (nil si absente : tout ce qui en dépend est alors refusé).
function Npc.tierIdx(Config, name)
	for i, t in ipairs(Config.TIERS) do
		if t.name == name then
			return i
		end
	end
	return nil
end

local function listIdx(list, name)
	for i, e in ipairs(list or {}) do
		if e.name == name then
			return i
		end
	end
	return nil
end

-- Une rareté sans espèce publiée n'apparaît jamais : un œuf donné prend la rareté publiée inférieure (Config.tierLive du lot 9 si présent).
local function liveTier(Config, t)
	if type(Config.tierLive) ~= "function" then
		return t
	end
	while t > 1 and not Config.tierLive(t) do
		t = t - 1
	end
	return t
end
Npc.liveTier = liveTier

local function forbiddenTier(Config, t)
	local name = Config.TIERS[t] and Config.TIERS[t].name
	for _, n in ipairs(Config.FORBIDDEN_GIFT_TIERS or {}) do
		if n == name then
			return true
		end
	end
	return false
end
Npc.forbiddenTier = forbiddenTier

---------------------------------------------------------------- Temps (UTC, jour = os.time() // 86400)
-- 0 = dimanche. Le 1er janvier 1970 (jour 0) était un jeudi.
function Npc.dow(day)
	return (math.floor(day) + 4) % 7
end

-- Numéro de semaine (lundi UTC = début).
function Npc.weekOf(day)
	return math.floor((math.floor(day) + 3) / 7)
end

---------------------------------------------------------------- État du profil
function Npc.newState()
	return { day = 0, trades = 0, fights = 0, enc = 0, nextAt = 0, off = false, champ = 0, refuse = {}, gone = {} }
end

local function cleanMap(saved, isBool)
	local out, n = {}, 0
	if type(saved) == "table" then
		for k, v in pairs(saved) do
			if type(k) == "string" and #k <= 16 and n < 12 then
				if isBool then
					if v == true then
						out[k] = true
						n = n + 1
					end
				elseif isnum(v) then
					out[k] = int(v, 0, 99, 0)
					n = n + 1
				end
			end
		end
	end
	return out
end

-- Assainit un `npc` lu du profil (absent, corrompu ou d'une autre forme = état neuf ; que des entiers bornés).
function Npc.sanitize(saved)
	local s = Npc.newState()
	if type(saved) ~= "table" then
		return s
	end
	s.day = int(saved.day, 0, 1e6, 0)
	s.trades = int(saved.trades, 0, 99, 0)
	s.fights = int(saved.fights, 0, 99, 0)
	s.enc = int(saved.enc, 0, 99, 0)
	s.nextAt = int(saved.nextAt, 0, 4e9, 0)
	s.off = saved.off == true
	s.champ = int(saved.champ, 0, 1e6, 0)
	s.refuse = cleanMap(saved.refuse, false)
	s.gone = cleanMap(saved.gone, true)
	return s
end

-- Remet à zéro les compteurs du jour au changement de jour UTC (nextAt, off et champ survivent : se reconnecter ne relance rien).
function Npc.rollDay(npc, today)
	if npc.day ~= today then
		npc.day = today
		npc.trades = 0
		npc.fights = 0
		npc.enc = 0
		npc.refuse = {}
		npc.gone = {}
	end
end

---------------------------------------------------------------- Conditions de rencontre (F.2)
-- ctx : { sessionStart, carrying, chased, inDuel, inCastle, inCinematic, flying, inTerritory, pending, lastRevealAt, lastRevealTier }.
-- Retourne true ou (false, code) : off, pending, carrying, chased, duel, castle, cine, flying, territory, early, reveal, wait.
function Npc.canSpawn(Config, npc, now, today, ctx)
	local E, R = Config.NPC_ENCOUNTER, Config.NPC_RULES
	ctx = type(ctx) == "table" and ctx or {}
	if npc.off == true then
		return false, "off"
	end
	if ctx.pending then
		return false, "pending"
	end
	if ctx.carrying then
		return false, "carrying"
	elseif ctx.chased then
		return false, "chased"
	elseif ctx.inDuel then
		return false, "duel"
	elseif ctx.inCastle then
		return false, "castle"
	elseif ctx.inCinematic then
		return false, "cine"
	elseif ctx.flying then
		return false, "flying"
	elseif ctx.inTerritory then
		return false, "territory"
	end
	if not isnum(now) then
		return false, "wait"
	end
	local started = isnum(ctx.sessionStart) and ctx.sessionStart or now
	if now - started < E.firstAfterMinutes * 60 then
		return false, "early"
	end
	local quietTier = Npc.tierIdx(Config, R.revealQuietTier)
	if isnum(ctx.lastRevealAt) and isnum(ctx.lastRevealTier) and quietTier and ctx.lastRevealTier >= quietTier and now - ctx.lastRevealAt < R.revealQuietSeconds then
		return false, "reveal"
	end
	if now < npc.nextAt then
		return false, "wait"
	end
	return true
end

---------------------------------------------------------------- Règles de pets (F.4 point 3)
-- Nombre d'exemplaires de chaque espèce possédés (tous pets, équipés ou non).
local function speciesCounts(inv)
	local c = {}
	for _, pet in ipairs(inv.pets or {}) do
		c[pet.p] = (c[pet.p] or 0) + 1
	end
	return c
end

-- Un pet peut-il être DEMANDÉ par un PNJ ? (indépendamment du nombre d'exemplaires, voir `giveable`.)
function Npc.petAllowed(Config, pet)
	local R = Config.NPC_RULES
	if type(pet) ~= "table" or type(pet.p) ~= "number" or Config.PETS[pet.p] == nil then
		return false
	end
	if pet.follower or pet.team or pet.defense then
		return false
	end
	local maxTier = Npc.tierIdx(Config, R.giveMaxTier)
	local mutFrom = listIdx(Config.MUTS, R.forbidMutFrom)
	local sizeFrom = listIdx(Config.SIZES, R.forbidSizeFrom)
	if not maxTier or not mutFrom or not sizeFrom then
		return false -- configuration incomplète : on refuse (pas de repli permissif)
	end
	if Config.PETS[pet.p].tier > maxTier or forbiddenTier(Config, Config.PETS[pet.p].tier) then
		return false
	end
	if type(pet.m) ~= "number" or pet.m >= mutFrom or type(pet.s) ~= "number" or pet.s >= sizeFrom then
		return false
	end
	return true
end

-- Pets que le joueur peut donner, groupés par rareté : giveable[r] = liste de pets (du moins précieux au plus précieux) en respectant « jamais le dernier exemplaire ».
local function giveableByTier(Config, inv)
	local counts = speciesCounts(inv)
	local bySpecies = {}
	for _, pet in ipairs(inv.pets or {}) do
		if Npc.petAllowed(Config, pet) then
			local l = bySpecies[pet.p]
			if not l then
				l = {}
				bySpecies[pet.p] = l
			end
			l[#l + 1] = pet
		end
	end
	local out = {}
	for p, list in pairs(bySpecies) do
		table.sort(list, function(a, b)
			local va, vb = a.m * 10 + a.s, b.m * 10 + b.s
			if va ~= vb then
				return va < vb
			end
			return (a.slot or 0) < (b.slot or 0)
		end)
		local allowed = math.min(#list, counts[p] - 1) -- au moins un exemplaire reste (doublon = au moins 2)
		local r = Config.PETS[p].tier
		for i = 1, allowed do
			out[r] = out[r] or {}
			out[r][#out[r] + 1] = list[i]
		end
	end
	for _, l in pairs(out) do
		table.sort(l, function(a, b)
			local va, vb = a.m * 10 + a.s, b.m * 10 + b.s
			if va ~= vb then
				return va < vb
			end
			return (a.slot or 0) < (b.slot or 0)
		end)
	end
	return out
end

---------------------------------------------------------------- Valeurs d'échange exactes (F.4 point 2)
function Npc.buyPrice(Config, r)
	local R = Config.NPC_RULES
	return math.floor(Config.EGG_PRICE[r] * R.buyDiscountNum / R.buyDiscountDen)
end

function Npc.speciesFee(Config, r)
	local R = Config.NPC_RULES
	return math.floor(Config.EGG_PRICE[r] * R.speciesFeeNum / R.speciesFeeDen)
end

---------------------------------------------------------------- Carnet d'offres (serveur, un par joueur)
function Npc.newBook()
	return { offers = {}, used = {}, usedOrder = {}, seq = 0, current = nil }
end

local function remember(book, id)
	book.used[id] = true
	book.usedOrder[#book.usedOrder + 1] = id
	while #book.usedOrder > 64 do
		local old = table.remove(book.usedOrder, 1)
		book.used[old] = nil
	end
end

local function newId(book, userId, rng)
	book.seq = book.seq + 1
	return string.format("%d-%d-%08x", math.floor(userId), book.seq, math.floor(rng() * 4294967296))
end

-- Retire les offres expirées (le PNJ repart sans pénalité). Retourne le nombre retiré.
function Npc.sweep(book, now)
	local n = 0
	for id, o in pairs(book.offers) do
		local limit = o.state == "accepted" and o.resultBy or o.expires
		if now >= limit then
			book.offers[id] = nil
			if book.current == id then
				book.current = nil
			end
			n = n + 1
		end
	end
	return n
end

---------------------------------------------------------------- Construction des offres
local function tierName(Config, t)
	return Config.TIERS[t] and Config.TIERS[t].name or "?"
end

local function newOffer(Config, book, npcKey, kind, userId, now, rng)
	local E = Config.NPC_ENCOUNTER
	return {
		id = newId(book, userId, rng), userId = math.floor(userId), npc = npcKey, kind = kind, created = now, expires = now + E.offerSeconds, state = "open",
		take = {}, price = 0,
	}
end

-- Pip : (A) œuf contre pièces à 80 % du prix, ou (B) 3 doublons de rareté r (r <= 4) contre 1 œuf r+1 (jamais un gain nul).
local function makePip(Config, book, userId, inv, now, rng, give)
	local R = Config.NPC_RULES
	local buyMax = Npc.tierIdx(Config, R.buyMaxTier)
	local dupMax = Npc.tierIdx(Config, R.dupesMaxTier)
	local options = {}
	if buyMax then
		options[#options + 1] = "buy"
	end
	if dupMax then
		for r = 1, math.min(dupMax, #Config.TIERS - 1) do
			local gain = liveTier(Config, r + 1)
			if gain > r and not forbiddenTier(Config, gain) and give[r] and #give[r] >= R.dupesNeeded then
				options[#options + 1] = "dupes"
				break
			end
		end
	end
	if #options == 0 then
		return nil
	end
	local pick = options[rint(rng, 1, #options)]
	local o = newOffer(Config, book, "pip", "trade", userId, now, rng)
	if pick == "buy" then
		local coins = isnum(inv.coins) and inv.coins or 0
		local candidates = {}
		for r = 1, buyMax do
			local t = liveTier(Config, r)
			if t == r and Config.EGG_PRICE[r] > 0 and Npc.buyPrice(Config, r) <= coins then
				candidates[#candidates + 1] = r
			end
		end
		local r = #candidates > 0 and candidates[rint(rng, 1, #candidates)] or liveTier(Config, 1)
		o.sub = "buy"
		o.price = Npc.buyPrice(Config, r)
		o.getEgg = r
	else
		local choices = {}
		for r = 1, math.min(dupMax, #Config.TIERS - 1) do
			local gain = liveTier(Config, r + 1)
			if gain > r and not forbiddenTier(Config, gain) and give[r] and #give[r] >= R.dupesNeeded then
				choices[#choices + 1] = r
			end
		end
		local r = choices[rint(rng, 1, #choices)]
		o.sub = "dupes"
		o.dupeTier = r
		o.getEgg = liveTier(Config, r + 1)
		for i = 1, R.dupesNeeded do
			local pet = give[r][i]
			o.take[#o.take + 1] = { slot = pet.slot, p = pet.p, s = pet.s, m = pet.m }
		end
	end
	return o
end

-- Nora : espèce manquante (rareté <= 5, jamais vue) contre 1 doublon de même rareté + 20 % du prix de l'œuf.
local function makeNora(Config, book, userId, inv, now, rng, give)
	local R = Config.NPC_RULES
	local maxTier = Npc.tierIdx(Config, R.speciesMaxTier)
	local normal = listIdx(Config.SIZES, R.speciesSize)
	if not maxTier or not normal then
		return nil
	end
	local seen = inv.seen or {}
	local cands = {}
	for p, sp in ipairs(Config.PETS) do
		local r = sp.tier
		if r <= maxTier and not seen[p] and sp.published ~= false and sp.hidden ~= true and not forbiddenTier(Config, r) and give[r] and #give[r] >= 1 and Config.EGG_PRICE[r] > 0 then
			cands[#cands + 1] = p
		end
	end
	if #cands == 0 then
		return nil
	end
	local p = cands[rint(rng, 1, #cands)]
	local r = Config.PETS[p].tier
	local pet = give[r][1]
	local o = newOffer(Config, book, "nora", "trade", userId, now, rng)
	o.sub = "species"
	o.price = Npc.speciesFee(Config, r)
	o.getSpecies = { p = p, s = normal, m = 1 }
	o.take[1] = { slot = pet.slot, p = pet.p, s = pet.s, m = pet.m }
	return o
end

-- Équipe adverse : 3 espèces EXISTANTES (types du PNJ si `inv.typeOf` est fourni, sinon toutes), niveau = niveau moyen du joueur, puissance = équipe du joueur x U(0,9 ; 1,1).
local function makeFight(Config, book, npcKey, userId, inv, now, rng, champion)
	local R = Config.NPC_RULES
	local def = Config.NPCS[npcKey]
	local o = newOffer(Config, book, npcKey, champion and "champion" or "fight", userId, now, rng)
	local maxPlayer = 1
	local sum, n = 0, 0
	for _, t in ipairs(inv.teamTiers or {}) do
		if isnum(t) then
			maxPlayer = math.max(maxPlayer, t)
			sum = sum + t
			n = n + 1
		end
	end
	local pool, fallback = {}, {}
	for p, sp in ipairs(Config.PETS) do
		if sp.published ~= false and sp.hidden ~= true and sp.tier <= maxPlayer then
			fallback[#fallback + 1] = p
			if type(inv.typeOf) ~= "function" or not def.types then
				pool[#pool + 1] = p
			else
				local ty = inv.typeOf(p)
				for _, want in ipairs(def.types) do
					if ty == want then
						pool[#pool + 1] = p
						break
					end
				end
			end
		end
	end
	if #pool == 0 then
		pool = fallback
	end
	if #pool == 0 then
		for p in ipairs(Config.PETS) do
			pool[#pool + 1] = p
		end
	end
	local lvl = int(inv.avgLevel, 1, 999, 1)
	local bag = {}
	for _, p in ipairs(pool) do
		bag[#bag + 1] = p
	end
	o.team = {}
	for _ = 1, 3 do
		local i = #bag > 0 and rint(rng, 1, #bag) or nil
		local p
		if i then
			p = bag[i]
			table.remove(bag, i)
		else
			p = pool[rint(rng, 1, #pool)]
		end
		o.team[#o.team + 1] = { p = p, lvl = lvl }
	end
	o.powerMul = (R.powerMin + rng() * (R.powerMax - R.powerMin)) * (champion and R.champPowerMul or 1)
	o.cardPct = champion and R.champCardPct or R.cardPct
	o.rewardMul = champion and 1 or R.fightRewardMul
	if champion then
		o.guaranteedEgg = liveTier(Config, Npc.tierIdx(Config, R.champEgg) or 1)
	else
		local cap = Npc.tierIdx(Config, R.fightEggCap) or 1
		local avg = n > 0 and math.floor(sum / n) or 1
		o.cardEgg = math.max(1, math.min(cap, liveTier(Config, math.max(1, avg))))
	end
	return o
end

---------------------------------------------------------------- Rencontre complète (spawn)
-- Tente une rencontre : conditions F.2, alternance échange / combat (rencontre n impaire = combat), quotas du jour, Kaï le lundi (1 fois par semaine, hors quota), puis offre.
-- Toute la mutation (compteurs, nextAt, carnet) n'a lieu qu'en cas de succès : un échec ne consomme rien. Retourne l'offre ou (nil, code).
-- Codes en plus de canSpawn : quota (plus de PNJ ce jour), noOffer (rien à proposer).
function Npc.encounter(Config, npc, book, userId, now, today, ctx, inv, rng)
	local E = Config.NPC_ENCOUNTER
	if not isnum(userId) or not isnum(today) then
		return nil, "args"
	end
	Npc.rollDay(npc, today)
	local ok, why = Npc.canSpawn(Config, npc, now, today, ctx)
	if not ok then
		return nil, why
	end
	local give = giveableByTier(Config, inv)
	local tradeLeft = npc.trades < E.tradesPerDay
	local fightLeft = npc.fights < E.fightsPerDay
	local week = Npc.weekOf(today)
	local order = {}
	if Npc.dow(today) == 1 and npc.champ ~= week and E.weeklyChampion >= 1 and not npc.gone.kai then
		order[#order + 1] = "champion"
	end
	local wantFight = (npc.enc + 1) % 2 == 1
	local first, second = "trade", "fight"
	if wantFight then
		first, second = "fight", "trade"
	end
	if (first == "trade" and tradeLeft) or (first == "fight" and fightLeft) then
		order[#order + 1] = first
	end
	if (second == "trade" and tradeLeft) or (second == "fight" and fightLeft) then
		order[#order + 1] = second
	end
	if #order == 0 then
		return nil, "quota"
	end
	local offer
	for _, kind in ipairs(order) do
		if kind == "champion" then
			offer = makeFight(Config, book, "kai", userId, inv, now, rng, true)
		elseif kind == "trade" then
			if not npc.gone.nora and rng() < 0.4 then
				offer = makeNora(Config, book, userId, inv, now, rng, give)
			end
			if not offer and not npc.gone.pip then
				offer = makePip(Config, book, userId, inv, now, rng, give)
			end
		else
			local names = {}
			for key, def in pairs(Config.NPCS) do
				if def.role == "fight" and not npc.gone[key] then
					names[#names + 1] = key
				end
			end
			table.sort(names)
			if #names > 0 then
				offer = makeFight(Config, book, names[rint(rng, 1, #names)], userId, inv, now, rng, false)
			end
		end
		if offer then
			break
		end
	end
	if not offer then
		return nil, "noOffer"
	end
	if offer.kind == "champion" then
		npc.champ = week
	elseif offer.kind == "fight" then
		npc.fights = npc.fights + 1
		npc.enc = npc.enc + 1
	else
		npc.trades = npc.trades + 1
		npc.enc = npc.enc + 1
	end
	npc.nextAt = math.max(npc.nextAt, now + rint(rng, E.gapMinutes[1] * 60, E.gapMinutes[2] * 60))
	book.offers[offer.id] = offer
	book.current = offer.id
	return offer
end

---------------------------------------------------------------- Accepter, refuser, résoudre
local function lookup(book, id, userId, now)
	if type(id) ~= "string" then
		return nil, "unknown"
	end
	local o = book.offers[id]
	if not o then
		if book.used[id] then
			return nil, "used"
		end
		return nil, "unknown"
	end
	if o.userId ~= userId then
		return nil, "owner"
	end
	return o
end

-- Contrôle une offre d'échange contre l'inventaire ACTUEL du joueur (le serveur ne fait jamais confiance au moment où l'offre a été faite).
local function revalidate(Config, o, inv)
	local mine = {}
	for _, pet in ipairs(inv.pets or {}) do
		mine[pet.slot] = pet
	end
	local counts = speciesCounts(inv)
	local given = {}
	for _, t in ipairs(o.take) do
		local pet = mine[t.slot]
		if not pet or pet.p ~= t.p or pet.s ~= t.s or pet.m ~= t.m or not Npc.petAllowed(Config, pet) then
			return false
		end
		given[pet.p] = (given[pet.p] or 0) + 1
	end
	for p, n in pairs(given) do
		if counts[p] - n < 1 then
			return false
		end
	end
	return true
end

-- Accepte une offre. opts.confirm2 : seconde confirmation (obligatoire si l'offre donne un pet de rareté >= 4).
-- Trade -> (true, effet) ; effet = { coins = -prix, take = { emplacements }, egg = rareté, species = { p, s, m }, npc, quest = "npcTrade" } à appliquer par le serveur en une fois.
-- Combat -> (true, offre acceptée) : le résultat doit ensuite être déclaré par `Npc.resolve` (le serveur le connaît, pas le client).
-- Refus : unknown, owner, used, expired, state, coins, changed, confirm2.
function Npc.accept(Config, book, id, userId, now, inv, opts)
	local o, why = lookup(book, id, userId, now)
	if not o then
		return false, why
	end
	if o.state ~= "open" then
		return false, "state"
	end
	if now >= o.expires then
		book.offers[id] = nil
		if book.current == id then
			book.current = nil
		end
		return false, "expired"
	end
	if o.kind == "trade" then
		local coins = isnum(inv.coins) and inv.coins or 0
		if o.price > coins then
			return false, "coins"
		end
		if #o.take > 0 and not revalidate(Config, o, inv) then
			return false, "changed"
		end
		if Npc.needsConfirm2(Config, o) and not (type(opts) == "table" and opts.confirm2 == true) then
			return false, "confirm2"
		end
		book.offers[id] = nil
		if book.current == id then
			book.current = nil
		end
		remember(book, id)
		local slots = {}
		for _, t in ipairs(o.take) do
			slots[#slots + 1] = t.slot
		end
		return true, { coins = -o.price, take = slots, egg = o.getEgg, species = o.getSpecies, npc = o.npc, quest = "npcTrade" }
	end
	o.state = "accepted"
	o.resultBy = now + Config.NPC_RULES.resultSeconds
	return true, o
end

-- Refus (« Pas maintenant ») : pas d'autre PNJ pendant 10 min ; 3 refus de suite du même PNJ : il ne revient plus ce jour-là. Un refus ne coûte rien d'autre.
function Npc.decline(Config, npc, book, id, userId, now)
	local o, why = lookup(book, id, userId, now)
	if not o then
		return false, why
	end
	if o.state ~= "open" then
		return false, "state"
	end
	book.offers[id] = nil
	if book.current == id then
		book.current = nil
	end
	remember(book, id)
	npc.nextAt = math.max(npc.nextAt, now + Config.NPC_ENCOUNTER.snoozeMinutes * 60)
	npc.refuse[o.npc] = math.min(99, (npc.refuse[o.npc] or 0) + 1)
	local gone = false
	if npc.refuse[o.npc] >= Config.NPC_RULES.maxRefusals then
		npc.gone[o.npc] = true
		gone = true
	end
	return true, { gone = gone, npc = o.npc }
end

-- Un échange accepté remet à zéro les refus de suite du PNJ concerné.
function Npc.noteAccepted(npc, npcKey)
	npc.refuse[npcKey] = 0
end

-- Résultat d'un combat accepté (déclaré par le serveur, une seule fois). Victoire : cartes D.5 à `cardPct` % (Kaï : Œuf garanti + carte à 100 %), valeurs x0,6 ;
-- défaite : rien n'est perdu, +5 XP. Retourne (true, issue) ou (false, code : unknown, owner, used, state, expired).
function Npc.resolve(Config, book, id, userId, now, won)
	local o, why = lookup(book, id, userId, now)
	if not o then
		return false, why
	end
	if o.state ~= "accepted" then
		return false, "state"
	end
	if now >= o.resultBy then
		book.offers[id] = nil
		if book.current == id then
			book.current = nil
		end
		return false, "expired"
	end
	book.offers[id] = nil
	if book.current == id then
		book.current = nil
	end
	remember(book, id)
	local out = { won = won == true, npc = o.npc, champion = o.kind == "champion", ratio = true }
	if won == true then
		out.cardPct = o.cardPct
		out.rewardMul = o.rewardMul
		out.cardEgg = o.cardEgg
		out.egg = o.guaranteedEgg
		out.xp = 0
	else
		out.xp = Config.NPC_RULES.lossXp
	end
	return true, out
end

---------------------------------------------------------------- Confirmation, vue et dialogues
-- 2e confirmation si un pet de rareté >= 4 (« Épique ») est donné.
function Npc.needsConfirm2(Config, o)
	local from = Npc.tierIdx(Config, Config.NPC_RULES.confirm2FromTier)
	for _, t in ipairs(o.take or {}) do
		local sp = Config.PETS[t.p]
		if sp and (not from or sp.tier >= from) then
			return true
		end
	end
	return false
end

-- Vue pour l'écran de confirmation (les deux objets côte à côte). `Odds` facultatif (module du lot 10) : compteur « 1 sur N » ; valeur de revente via Config.eggSellValue si présente.
function Npc.view(Config, o, Odds)
	local give, get = {}, {}
	for _, t in ipairs(o.take or {}) do
		local sp = Config.PETS[t.p]
		local odds
		if Odds and Odds.value and Odds.label and sp then
			odds = Odds.label(Odds.value(Config, sp.tier, t.s, t.m))
		end
		give[#give + 1] = { kind = "pet", p = t.p, name = sp and sp.name or "?", tier = sp and sp.tier, odds = odds }
	end
	if o.price and o.price > 0 then
		give[#give + 1] = { kind = "coins", amount = o.price }
	end
	if o.getEgg then
		get[#get + 1] = { kind = "egg", tier = o.getEgg, name = tierName(Config, o.getEgg), sell = type(Config.eggSellValue) == "function" and Config.eggSellValue(o.getEgg) or nil }
	end
	if o.getSpecies then
		local sp = Config.PETS[o.getSpecies.p]
		local odds
		if Odds and Odds.value and Odds.label and sp then
			odds = Odds.label(Odds.value(Config, sp.tier, o.getSpecies.s, o.getSpecies.m))
		end
		get[#get + 1] = { kind = "pet", p = o.getSpecies.p, name = sp and sp.name or "?", tier = sp and sp.tier, odds = odds }
	end
	return { npc = o.npc, name = Config.NPCS[o.npc].name, give = give, get = get, confirm2 = Npc.needsConfirm2(Config, o), expires = o.expires }
end

-- Texte d'un dialogue : `which` = approach, offer1, offer2, offer, win, lose, refuse, gone ; {variables} remplacées par `vars`.
function Npc.say(Config, npcKey, which, vars)
	local d = Config.DIALOGUES[npcKey]
	local text = d and d[which]
	if type(text) ~= "string" then
		return ""
	end
	return (string.gsub(text, "{(%w+)}", function(k)
		local v = vars and vars[k]
		if v == nil then
			return "{" .. k .. "}"
		end
		return tostring(v)
	end))
end

-- Astuce de défaite (types de l'équipe adverse). `weak` = { typeAdverse = typeQuiLeBat } (défaut Config.TYPE_WEAK).
function Npc.tip(Config, o, weak)
	weak = weak or Config.TYPE_WEAK or {}
	local def = Config.NPCS[o.npc]
	local ty = def and def.types and def.types[1]
	local against = ty and weak[ty]
	if not against then
		return "observe bien les types de l'équipe adverse."
	end
	return "le type " .. ty .. " craint le type " .. against .. "."
end

-- Contrôle indépendant d'une offre : retourne la liste des violations de F.4 (vide = conforme). Sert aux 10 000 offres des tests et peut servir de garde du serveur.
function Npc.violations(Config, o, inv, userId)
	local R = Config.NPC_RULES
	local bad = {}
	local function no(msg)
		bad[#bad + 1] = msg
	end
	if o.userId ~= userId then
		no("offre non liée au userId")
	end
	if type(o.id) ~= "string" or o.id == "" then
		no("identifiant absent")
	end
	if o.expires - o.created ~= Config.NPC_ENCOUNTER.offerSeconds then
		no("durée de validité")
	end
	for k in pairs(o) do
		local lk = string.lower(tostring(k))
		if string.find(lk, "robux") or string.find(lk, "product") or string.find(lk, "gamepass") or string.find(lk, "target") or string.find(lk, "other") then
			no("champ interdit : " .. tostring(k))
		end
	end
	local counts = speciesCounts(inv)
	local mine = {}
	for _, pet in ipairs(inv.pets or {}) do
		mine[pet.slot] = pet
	end
	local given = {}
	local seenSlot = {}
	for _, t in ipairs(o.take or {}) do
		local pet = mine[t.slot]
		if not pet then
			no("pet demandé absent de l'inventaire")
		else
			if seenSlot[t.slot] then
				no("même emplacement demandé deux fois")
			end
			seenSlot[t.slot] = true
			local tier = Config.PETS[pet.p].tier
			if tier > Npc.tierIdx(Config, R.giveMaxTier) then
				no("pet de rareté trop haute demandé")
			end
			if pet.follower or pet.team or pet.defense then
				no("pet équipé, d'équipe ou de défense demandé")
			end
			if pet.m >= listIdx(Config.MUTS, R.forbidMutFrom) then
				no("pet muté Arc-en-ciel ou mieux demandé")
			end
			if pet.s >= listIdx(Config.SIZES, R.forbidSizeFrom) then
				no("pet Géant ou Colossal demandé")
			end
			given[pet.p] = (given[pet.p] or 0) + 1
		end
	end
	for p, n in pairs(given) do
		if counts[p] - n < 1 then
			no("dernier exemplaire d'une espèce demandé")
		end
	end
	if o.sub == "buy" then
		if #o.take ~= 0 then
			no("achat d'œuf : aucun pet ne doit être demandé")
		end
		if o.getEgg > Npc.tierIdx(Config, R.buyMaxTier) or o.price ~= math.floor(Config.EGG_PRICE[o.getEgg] * R.buyDiscountNum / R.buyDiscountDen) then
			no("prix ou rareté de l'achat")
		end
	elseif o.sub == "dupes" then
		if #o.take ~= R.dupesNeeded then
			no("nombre de doublons")
		end
		if o.dupeTier > Npc.tierIdx(Config, R.dupesMaxTier) or o.price ~= 0 or o.getEgg <= o.dupeTier then
			no("règle des doublons")
		end
		for _, t in ipairs(o.take) do
			if Config.PETS[t.p].tier ~= o.dupeTier then
				no("doublon d'une autre rareté")
			end
		end
	elseif o.sub == "species" then
		local sp = Config.PETS[o.getSpecies.p]
		if #o.take ~= 1 or sp.tier > Npc.tierIdx(Config, R.speciesMaxTier) or inv.seen[o.getSpecies.p] then
			no("règle de l'espèce manquante")
		elseif Config.PETS[o.take[1].p].tier ~= sp.tier or o.price ~= math.floor(Config.EGG_PRICE[sp.tier] * R.speciesFeeNum / R.speciesFeeDen) then
			no("rareté ou complément de l'espèce manquante")
		end
	elseif o.kind == "trade" then
		no("sous-type d'échange inconnu")
	end
	if o.getEgg and forbiddenTier(Config, o.getEgg) then
		no("œuf de rareté interdite offert")
	end
	if o.kind == "trade" and o.price < 0 then
		no("prix négatif")
	end
	return bad
end

return Npc

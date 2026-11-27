-- ModuleScript : ReplicatedStorage/Shared/Shop (LOT 16, boutique PURE : aucune dépendance Roblox, Config / ShopInfo injectés par paramètre)
-- Catégories, tri, état « Possédé », règle de mise à niveau (palier inférieur déjà possédé -> seul le complément est visible), prix effectif, visibilité
-- (id renseigné, PolicyService, espèces publiées), contrôle de place AVANT paiement, débordement, texte des probabilités et reçus (un crédit par reçu).
-- Décision utilisateur : PLUS DE PLAFOND D'ACHAT. Seuls les achats uniques (`once`, passes, poses) et le passe de saison (une fois par saison) sont limités.
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2 (compatibilité lupa).
-- Profil attendu (forme minimale, le serveur adapte) :
--   { coins, income (pièces / s), slots = {...}, cap, eggBag = { tier... }, overflow = { ["tier"] = n }, passes = { Cle = true }, once = { Cle = true },
--     season = { cur = n, premium = n|nil, plus = n|nil, bonusTiers = n }, receipts = { [id] = true }, timers = { luck, double } (secondes), tokens = { arena, raven, streak, catchup } }
local Shop = {}

Shop.OWNED_LABEL = "Possédé"
Shop.MSG_ROOM = "Fais de la place : ta base et ton sac d'œufs sont pleins."
Shop.DOUBLE_LUCK_CAP = 70 -- points de chance (puissance) : seule garde conservée de H.2

Shop.CATEGORIES = {
	{ key = "eggs", title = "Œufs", icon = "egg_r3" },
	{ key = "luck", title = "Chance & boosts", icon = "r_potion_chance" },
	{ key = "coins", title = "Pièces", icon = "r_coins_m" },
	{ key = "base", title = "Base & confort", icon = "ui_bouclier" },
	{ key = "combat", title = "Combat & vol", icon = "ui_epee" },
	{ key = "season", title = "Passe de combat", icon = "ui_trophee" },
	{ key = "packs", title = "Packs", icon = "r_coffre" },
	{ key = "cosmetics", title = "Cosmétiques", icon = "r_cosmetique_traine" },
}
local CAT_INDEX = {}
for i, c in ipairs(Shop.CATEGORIES) do
	CAT_INDEX[c.key] = i
end
function Shop.categoryTitle(key)
	local i = CAT_INDEX[key]
	return i and Shop.CATEGORIES[i].title or nil
end

-- Points de chance avec « Double chance » : x2 puis plafond de 70 points. Entrée invalide : 0.
function Shop.doubleLuckCap(points)
	if type(points) ~= "number" or points ~= points or points < 0 then
		return 0
	end
	return math.min(points * 2, Shop.DOUBLE_LUCK_CAP)
end
-- Total de chance quelle que soit la source (jamais au-dessus de 70).
function Shop.luckTotal(points, doubled)
	local p = type(points) == "number" and points == points and points > 0 and points or 0
	if doubled then
		return Shop.doubleLuckCap(p)
	end
	return math.min(p, Shop.DOUBLE_LUCK_CAP)
end

---------------------------------------------------------------- Contenu des achats (données de reçu)
-- eggs = { { tier, n } } (n œufs de rareté FIXE), coins = { minutes, min } (sac) ou nombre fixe, luck / double (secondes), server = effet pour tout le serveur.
local function eggs(list)
	return list
end
Shop.EFFECTS = {
	StarterPack = { coins = 20000, eggs = eggs({ { 3, 3 } }), luck = { points = 25, seconds = 900 }, onceMark = true },
	BundleLegend = { eggs = eggs({ { 7, 1 }, { 5, 3 } }), doubleSeconds = 3600 },
	BundleRoyal = { eggs = eggs({ { 7, 2 }, { 6, 3 } }), premium = true },
	BundleRoyalNoPass = { eggs = eggs({ { 7, 2 }, { 6, 3 } }), needsPremium = true },
	SeasonPremium = { premium = true },
	SeasonUpgradePlus = { plus = true, needsPremium = true },
	SeasonPremiumPlus = { premium = true, plus = true },
	LuckPotionMini = { luck = { points = 25, seconds = 300 } },
	LuckPotion = { luck = { points = 25, seconds = 900 } },
	DoubleLuck = { doubleSeconds = 1800 },
	ServerLuck = { server = { luckPoints = 5, seconds = 600 } },
	GoldenBelt = { server = { beltSeconds = 600 } },
	CoinPackS = { coinPack = { minutes = 5, min = 1000 } },
	CoinPack = { coinPack = { minutes = 20, min = 5000 } },
	ArenaTickets = { tokens = { arena = 5 } },
	RemoteSteal = { tokens = { raven = 1 } },
	RemoteStealPack = { tokens = { raven = 3 } },
	StreakRestore = { tokens = { streak = 1 } },
	CalendarCatchup = { tokens = { catchup = 1 } },
	InstantHatch = { instantHatch = true },
	Revive = { revive = true },
}
for _, t in ipairs({ { "EggR2", 2 }, { "EggR3", 3 }, { "EggR4", 4 }, { "EggR5", 5 }, { "ExclusiveEgg", 6 }, { "EggR7", 7 }, { "EggSecret", 8 }, { "EggExclusive", 9 }, { "EggDivine", 10 } }) do
	Shop.EFFECTS[t[1]] = { eggs = { { t[2], 1 } } }
end
for n = 1, 6 do
	Shop.EFFECTS["EmoteVictory" .. n] = { onceMark = true }
end

-- Œufs contenus dans un achat : liste { tier, n } (vide si aucun).
function Shop.eggsOf(key)
	local fx = Shop.EFFECTS[key]
	local out = {}
	if fx and fx.eggs then
		for _, e in ipairs(fx.eggs) do
			out[#out + 1] = { tier = e[1], n = e[2] }
		end
	end
	return out
end

---------------------------------------------------------------- Catalogue, possession, prix
local function isId(id)
	return type(id) == "number" and id == id and id > 0 and id % 1 == 0
end

-- Catalogue : toutes les entrées de Config.PRODUCTS / Config.PASSES qui portent une catégorie (ShopData.merge). Triées par catégorie puis prix croissant puis clé.
function Shop.catalog(config)
	local list = {}
	for _, bagName in ipairs({ "PRODUCTS", "PASSES" }) do
		local bag = type(config) == "table" and config[bagName]
		if type(bag) == "table" then
			for key, def in pairs(bag) do
				if type(def) == "table" and CAT_INDEX[def.cat] then
					list[#list + 1] = {
						key = key, kind = bagName == "PASSES" and "pass" or "product", id = def.id, price = def.robux, cat = def.cat,
						random = def.random == true, once = def.once == true, perSeason = def.season == true, eggTier = def.eggTier,
						permanent = bagName == "PASSES" or def.once == true,
					}
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.cat ~= b.cat then
			return CAT_INDEX[a.cat] < CAT_INDEX[b.cat]
		end
		local pa, pb = type(a.price) == "number" and a.price or 0, type(b.price) == "number" and b.price or 0
		if pa ~= pb then
			return pa < pb
		end
		return a.key < b.key
	end)
	return list
end

local function season(profil)
	local s = type(profil) == "table" and profil.season
	return type(s) == "table" and s or {}
end
function Shop.hasPremium(profil)
	local s = season(profil)
	return type(s.cur) == "number" and s.premium == s.cur
end
function Shop.hasPlus(profil)
	local s = season(profil)
	return type(s.cur) == "number" and s.plus == s.cur
end

-- Possession d'un achat (passe, achat unique, passe de saison de la saison EN COURS).
function Shop.owned(profil, offre)
	local key = type(offre) == "table" and offre.key or offre
	if type(profil) ~= "table" or type(key) ~= "string" then
		return false
	end
	if key == "SeasonPremium" then
		return Shop.hasPremium(profil)
	end
	if key == "SeasonUpgradePlus" or key == "SeasonPremiumPlus" then
		return Shop.hasPlus(profil)
	end
	if type(profil.passes) == "table" and profil.passes[key] == true then
		return true
	end
	return type(profil.once) == "table" and profil.once[key] == true
end

-- Règle de mise à niveau : "owned" / "buy" / "hidden" d'après la seule possession (aucun prix ici).
local function ownership(profil, key)
	local prem = Shop.hasPremium(profil)
	if key == "SeasonUpgradePlus" then
		if not prem then
			return "hidden", "needPremium"
		end
		return Shop.hasPlus(profil) and "owned" or "buy"
	elseif key == "SeasonPremiumPlus" then
		return prem and "hidden" or "buy", "hasPremium"
	elseif key == "BundleRoyal" then
		return prem and "hidden" or "buy", "hasPremium"
	elseif key == "BundleRoyalNoPass" then
		return prem and "buy" or "hidden", "needPremium"
	end
	return Shop.owned(profil, key) and "owned" or "buy"
end

-- Prix effectivement facturé : `offre` (fiche du catalogue) -> R$, ou nil si l'offre n'est pas achetable (masquée par la règle de mise à niveau ou déjà possédée).
function Shop.priceFor(profil, offre)
	if type(offre) ~= "table" or type(offre.price) ~= "number" then
		return nil
	end
	local st = ownership(profil, offre.key)
	if st ~= "buy" then
		return nil
	end
	return offre.price
end

-- État complet : "buy" | "owned" | "hidden" (+ motif). restricted : résultat de PolicyService (nil / true = restreint, false = autorisé).
function Shop.status(profil, config, offre, restricted)
	if type(offre) ~= "table" or not isId(offre.id) then
		return "hidden", "noId"
	end
	if offre.random and restricted ~= false then
		return "hidden", "policy"
	end
	if type(offre.eggTier) == "number" and type(config.tierLive) == "function" and not config.tierLive(offre.eggTier) then
		return "hidden", "notLive"
	end
	local st, why = ownership(profil, offre.key)
	return st, st ~= "buy" and why or nil
end

-- Offres visibles regroupées par catégorie (ordre imposé), triées par prix croissant. Chaque achat est dans EXACTEMENT une catégorie.
-- Retourne { { key, title, icon, offers = { { key, price, owned, label, permanent, random, seeAlso = { clés de catégories } } } } } (les 8 catégories, éventuellement vides).
function Shop.visibleOffers(profil, config, restricted, info)
	local out = {}
	for i, c in ipairs(Shop.CATEGORIES) do
		out[i] = { key = c.key, title = c.title, icon = c.icon, offers = {} }
	end
	for _, o in ipairs(Shop.catalog(config)) do
		local st = Shop.status(profil, config, o, restricted)
		if st ~= "hidden" then
			local also = info and info[o.key] and info[o.key].also or {}
			local row = {
				key = o.key, kind = o.kind, price = o.price, owned = st == "owned", label = st == "owned" and Shop.OWNED_LABEL or nil,
				permanent = o.permanent, perSeason = o.perSeason, random = o.random, eggTier = o.eggTier, seeAlso = also,
			}
			local list = out[CAT_INDEX[o.cat]].offers
			list[#list + 1] = row
		end
	end
	return out
end

-- Contrôle serveur AVANT PromptProductPurchase : ok, motif, prix. Refuse : inconnu, masqué (id / PolicyService / rareté), possédé, mise à niveau impossible,
-- base + sac pleins pour un achat qui contient des œufs.
function Shop.canBuy(profil, config, key, restricted)
	local found
	for _, o in ipairs(Shop.catalog(config)) do
		if o.key == key then
			found = o
		end
	end
	if not found then
		return false, "unknown"
	end
	local st, why = Shop.status(profil, config, found, restricted)
	if st == "hidden" then
		return false, why or "hidden"
	end
	if st == "owned" then
		return false, "owned"
	end
	if #Shop.eggsOf(key) > 0 then
		local ok = Shop.canBuyEgg(profil, config, 1)
		if not ok then
			return false, "faisDeLaPlace"
		end
	end
	return true, nil, Shop.priceFor(profil, found)
end

---------------------------------------------------------------- Place et débordement
local function freeSlots(profil)
	local n = 0
	local cap = type(profil.cap) == "number" and profil.cap or 0
	local slots = type(profil.slots) == "table" and profil.slots or {}
	for i = 1, cap do
		if slots[i] == nil or slots[i] == false then
			n = n + 1
		end
	end
	return n
end
local function bagRoom(profil, config)
	local size = type(config.EGG_BAG) == "table" and config.EGG_BAG.size or 10
	local used = type(profil.eggBag) == "table" and #profil.eggBag or 0
	return math.max(size - used, 0)
end
-- Peut-on ranger `n` (1 par défaut) œufs dans la base puis le sac ? Sinon (false, "faisDeLaPlace", message) : à appeler AVANT le paiement.
function Shop.canBuyEgg(profil, config, n)
	local need = type(n) == "number" and n >= 1 and math.floor(n) or 1
	if type(profil) ~= "table" then
		return false, "faisDeLaPlace", Shop.MSG_ROOM
	end
	if freeSlots(profil) + bagRoom(profil, config) >= need then
		return true
	end
	return false, "faisDeLaPlace", Shop.MSG_ROOM
end
-- Débordement après paiement (course) : coffre de débordement sans limite, jamais de perte. Clés en texte (DataStore).
function Shop.overflowAdd(profil, tier, n)
	local count = type(n) == "number" and n >= 1 and math.floor(n) or 1
	if type(tier) ~= "number" or tier < 1 or tier % 1 ~= 0 then
		return false
	end
	profil.overflow = profil.overflow or {}
	local k = tostring(tier)
	profil.overflow[k] = (profil.overflow[k] or 0) + count
	return true
end
function Shop.overflowCount(profil)
	local total = 0
	if type(profil.overflow) == "table" then
		for _, v in pairs(profil.overflow) do
			if type(v) == "number" then
				total = total + v
			end
		end
	end
	return total
end

-- Range un œuf : base, puis sac, puis débordement. Retourne "slot" | "bag" | "overflow".
local function placeEgg(profil, config, tier)
	profil.slots = profil.slots or {}
	local cap = type(profil.cap) == "number" and profil.cap or 0
	for i = 1, cap do
		if profil.slots[i] == nil or profil.slots[i] == false then
			profil.slots[i] = { k = "e", t = tier }
			return "slot"
		end
	end
	profil.eggBag = profil.eggBag or {}
	if bagRoom(profil, config) > 0 then
		profil.eggBag[#profil.eggBag + 1] = tier
		return "bag"
	end
	Shop.overflowAdd(profil, tier, 1)
	return "overflow"
end

---------------------------------------------------------------- Probabilités affichées
local function pctText(x)
	local r = math.floor(x * 10 + 0.5) / 10
	if r % 1 == 0 then
		return tostring(math.floor(r))
	end
	return (string.format("%.1f", r):gsub("%.", ","))
end
local function weightsText(list, none)
	local total = 0
	for _, x in ipairs(list) do
		total = total + x.weight
	end
	local out = {}
	for _, x in ipairs(list) do
		out[#out + 1] = string.format("%s %s %%", x.name == "" and none or x.name, pctText(x.weight / total * 100))
	end
	return table.concat(out, ", ")
end
local function speciesCount(config, tier)
	local n = 0
	for _, p in ipairs(config.PETS) do
		if p.tier == tier then
			n = n + 1
		end
	end
	return n
end

-- Texte de probabilités d'un achat qui contient des œufs (sinon ""). Rareté FIXE affichée, table de contenu (Config.eggContentText avec les points d'amélioration
-- du joueur, `upPoints`, 5 par défaut), espèces, tailles et mutations. Les lignes sont séparées par « \n ».
function Shop.eggContentText(config, key, upPoints)
	local list = Shop.eggsOf(key)
	if #list == 0 then
		return ""
	end
	local up = type(upPoints) == "number" and upPoints or (config.UPGRADE and config.UPGRADE.base) or 0
	local lines = {}
	for _, e in ipairs(list) do
		local t = config.TIERS[e.tier]
		if t then
			local head = e.n > 1 and string.format("%d x Œuf %s", e.n, t.name) or ("Œuf " .. t.name)
			lines[#lines + 1] = string.format("%s, rareté fixe %s", head, t.name)
			lines[#lines + 1] = "Contenu : " .. config.eggContentText(e.tier, up)
			if e.tier == 9 then
				lines[#lines + 1] = "Espèce : celle de l'événement en cours (affichée avant l'achat)."
			else
				local n = speciesCount(config, e.tier)
				if n > 0 then
					lines[#lines + 1] = string.format("%d espèce%s possible%s, chacune %s %% (espèce tirée au sort dans la rareté).", n, n > 1 and "s" or "", n > 1 and "s" or "", pctText(100 / n))
				end
			end
		end
	end
	lines[#lines + 1] = "Tailles : " .. weightsText(config.SIZES, "Normal") .. "."
	lines[#lines + 1] = "Mutations : " .. weightsText(config.MUTS, "Aucune") .. "."
	return table.concat(lines, "\n")
end

-- Fiche complète d'un achat pour l'écran (kiosque et offres à l'écran : même fiche) ; nil si inconnu.
function Shop.card(config, info, profil, key, restricted)
	local i = info and info[key]
	if not i then
		return nil
	end
	local offre
	for _, o in ipairs(Shop.catalog(config)) do
		if o.key == key then
			offre = o
		end
	end
	if not offre then
		return nil
	end
	local st = Shop.status(profil, config, offre, restricted)
	local also = {}
	for _, c in ipairs(i.also or {}) do
		also[#also + 1] = Shop.categoryTitle(c)
	end
	return {
		key = key, title = i.title, def = i.def, detail = i.detail, notDo = i.notDo, chance = i.chance, limit = i.limit, icon = i.icon,
		price = Shop.priceFor(profil, offre) or offre.price, state = st, owned = st == "owned", label = st == "owned" and Shop.OWNED_LABEL or nil,
		odds = offre.random and Shop.eggContentText(config, key) or "", seeAlso = also,
	}
end

---------------------------------------------------------------- Reçus (un crédit par reçu)
local function rate(config)
	local ref = type(config.PRICING_REF) == "table" and config.PRICING_REF.secondsPerRobux
	return type(ref) == "number" and ref > 0 and ref or 12.1
end
-- Pièces de compensation pour `robux` R$ payés en double : revenu de (robux x secondsPerRobux) secondes, au moins le plancher du Sac de pièces.
local function compensation(profil, config, robux)
	local income = type(profil.income) == "number" and profil.income > 0 and profil.income or 0
	local floorCoins = type(config.COIN_PACK_MIN) == "number" and config.COIN_PACK_MIN or 5000
	return math.floor(math.max(floorCoins, income * robux * rate(config)))
end

local function addTokens(profil, tokens)
	profil.tokens = profil.tokens or {}
	for k, v in pairs(tokens) do
		profil.tokens[k] = (profil.tokens[k] or 0) + v
	end
end
local function addTimer(profil, which, seconds)
	profil.timers = profil.timers or {}
	profil.timers[which] = (profil.timers[which] or 0) + seconds -- durées cumulables sans limite
end

-- Octroie UN produit pour le reçu `receiptId` et retourne { ok, dup, delta } (delta = ce qui a été ajouté au profil et aux effets serveur).
-- Idempotent : rejouer le même reçu ne crédite rien (dup = true). Inconnu : { ok = false, reason }. Les achats déjà possédés (course) sont compensés en pièces.
function Shop.grant(profil, key, receiptId, config)
	if type(profil) ~= "table" or type(key) ~= "string" then
		return { ok = false, reason = "args" }
	end
	local rt = type(receiptId)
	if not ((rt == "string" and #receiptId > 0) or (rt == "number" and receiptId == receiptId)) then
		return { ok = false, reason = "receipt" }
	end
	local fx = Shop.EFFECTS[key]
	if not fx then
		return { ok = false, reason = "unknown" }
	end
	profil.receipts = profil.receipts or {}
	if profil.receipts[receiptId] then
		return { ok = true, dup = true }
	end
	local def = (config.PRODUCTS and config.PRODUCTS[key]) or {}
	local price = type(def.robux) == "number" and def.robux or 0
	local delta = { key = key }
	local prem = Shop.hasPremium(profil)
	local plus = Shop.hasPlus(profil)
	local s = season(profil)
	profil.season = type(profil.season) == "table" and profil.season or { cur = 0 }
	local cur = type(profil.season.cur) == "number" and profil.season.cur or 0
	local comp = 0 -- R$ payés pour quelque chose déjà possédé

	-- Pièces
	if fx.coinPack then
		local minutes = fx.coinPack.minutes
		if key == "CoinPack" and type(config.COIN_PACK_MINUTES) == "number" then
			minutes = config.COIN_PACK_MINUTES
		end
		local income = type(profil.income) == "number" and profil.income > 0 and profil.income or 0
		delta.coins = math.floor(math.max(fx.coinPack.min, income * minutes * 60))
	elseif fx.coins then
		delta.coins = fx.coins
	end

	-- Achat unique déjà possédé : compensation, pas de second octroi
	if fx.onceMark then
		profil.once = profil.once or {}
		if profil.once[key] then
			comp = price
			delta.coins = nil
			fx = {}
		end
	end

	-- Passe de saison
	if key == "SeasonPremium" and prem then
		comp = price
		fx = {}
	elseif key == "SeasonUpgradePlus" and plus then
		comp = price
		fx = {}
	elseif key == "SeasonPremiumPlus" then
		if plus then
			comp = price
			fx = {}
		elseif prem then
			comp = (config.PRODUCTS.SeasonPremium and config.PRODUCTS.SeasonPremium.robux) or 399
		end
	elseif key == "BundleRoyal" and prem then
		comp = (config.PRODUCTS.SeasonPremium and config.PRODUCTS.SeasonPremium.robux) or 399
	end
	local race = false
	if fx.needsPremium and not prem then
		race = true -- payé sans le premium (course) : on lui donne le premium en plus, il a payé
	end

	if fx.eggs then
		local placed = { slot = 0, bag = 0, overflow = 0 }
		delta.eggs = {}
		for _, e in ipairs(fx.eggs) do
			for _ = 1, e[2] do
				local where = placeEgg(profil, config, e[1])
				placed[where] = placed[where] + 1
				delta.eggs[#delta.eggs + 1] = e[1]
			end
		end
		delta.placed = placed
	end
	if delta.coins and delta.coins > 0 then
		profil.coins = (type(profil.coins) == "number" and profil.coins or 0) + delta.coins
	end
	if fx.luck then
		delta.luck = { points = fx.luck.points, seconds = fx.luck.seconds }
		addTimer(profil, "luck", fx.luck.seconds)
	end
	if fx.doubleSeconds then
		delta.doubleSeconds = fx.doubleSeconds
		delta.doubleCap = Shop.DOUBLE_LUCK_CAP
		addTimer(profil, "double", fx.doubleSeconds)
	end
	if fx.server then
		delta.server = fx.server
	end
	if fx.tokens then
		delta.tokens = fx.tokens
		addTokens(profil, fx.tokens)
	end
	if fx.instantHatch then
		delta.instantHatch = true
	end
	if fx.revive then
		delta.revive = true
	end
	if fx.premium or race then
		if not (prem and not race) then
			profil.season.premium = cur
			delta.premium = true
			delta.creditReached = true -- le module de saison crédite UNE fois les paliers déjà atteints
		end
	end
	if fx.plus then
		profil.season.plus = cur
		profil.season.premium = cur
		profil.season.bonusTiers = (profil.season.bonusTiers or 0) + 10
		delta.plus = true
		delta.bonusTiers = 10
	end
	if race then
		delta.upgradedFromRace = true
	end
	if fx.onceMark then
		profil.once[key] = true
		delta.once = true
	end
	if comp > 0 then
		local coins = compensation(profil, config, comp)
		profil.coins = (type(profil.coins) == "number" and profil.coins or 0) + coins
		delta.compensation = { robux = comp, coins = coins }
	end
	profil.receipts[receiptId] = true
	if s ~= nil and s.cur == nil then
		profil.season.cur = cur
	end
	return { ok = true, dup = false, delta = delta }
end

-- Passe permanent (Game Pass) : pose idempotente.
function Shop.grantPass(profil, key)
	if type(profil) ~= "table" or type(key) ~= "string" then
		return false
	end
	profil.passes = profil.passes or {}
	local had = profil.passes[key] == true
	profil.passes[key] = true
	return not had
end

return Shop

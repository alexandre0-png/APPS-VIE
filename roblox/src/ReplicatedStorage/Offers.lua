-- ModuleScript : ReplicatedStorage/Shared/Offers
-- LOT 16 : OFFRES CONTEXTUELLES à l'écran, logique PURE (aucun service Roblox, aucune instance, aucun hasard). Une offre à la fois, 3 par session, 300 s d'écart,
-- jamais pendant une action, jamais juste après un achat, jamais ce que le joueur possède ou ce qui est indisponible. Le client affiche la carte (bouton Fermer toujours
-- visible) et ouvre la MEME fiche que le kiosque ; le serveur reste seul juge de l'achat. Style : pas de `+=`, pas de `continue`, gardes de type partout.
--   Offers.newState(joinedAt)                        -> state (un par joueur et par session ; jamais enregistré)
--   Offers.pick(state, profil, now, ctx)             -> offre | nil     (PURE : ne modifie ni state, ni profil, ni ctx)
--   Offers.onShown(state, offer, now) / onClosed(state, now) / onBought(state, keyOrOffer, now)
--   Offers.shouldHide(state, ctx) / expired(state, now)
-- profil = { owned = { [clé] = true }, passes = { [clé] = true }, dayNumber = 1.., bestTier = palier le plus haut obtenu, hatchedTotal = éclosions }
-- ctx    = { Config (requis : PRODUCTS, PASSES, TIERS), restricted (PolicyService : doit valoir false pour les offres à hasard), calm,
--            baseFull, bagFull, firstLegend, streakAtRisk, towerQuotaExhausted,
--            flying, cinematic, inCombat, carrying, chased, hatching, castleTimer, menuOpen }
-- offre  = { id, key, kind, title, text, robux, random, tier }
local Offers = {}

local function loadData(ctx)
	if type(ctx) == "table" and type(ctx.data) == "table" then
		return ctx.data
	end
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("OffersData"))
end

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Offers.newState(joinedAt)
	return { joinedAt = isNum(joinedAt) and joinedAt or 0, shown = 0, lastShownAt = nil, lastBuyAt = nil, seen = {}, current = nil, currentAt = nil }
end

local function limits(Config, D)
	local o = type(Config.OFFERS) == "table" and Config.OFFERS or {}
	return isNum(o.max) and o.max or D.MAX, isNum(o.gap) and o.gap or D.GAP, isNum(o.graceSeconds) and o.graceSeconds or D.GRACE
end

local function busy(ctx, D)
	for _, f in ipairs(D.BUSY) do
		if ctx[f] == true then
			return true
		end
	end
	return false
end

local function owns(profil, key)
	if type(profil) ~= "table" then
		return false
	end
	for _, field in ipairs({ "owned", "passes", "purchased" }) do
		local set = profil[field]
		if type(set) == "table" and set[key] then
			return true
		end
	end
	return false
end

local function defOf(Config, key, kind)
	local list = kind == "pass" and Config.PASSES or Config.PRODUCTS
	if type(list) == "table" and type(list[key]) == "table" then
		return list[key]
	end
	return nil
end

-- Achat vendable à CE joueur : id entier > 0, rareté publiée, hasard seulement si PolicyService a confirmé « non restreint ».
local function visible(Config, def, restricted)
	if type(def) ~= "table" or not isNum(def.id) or def.id <= 0 or def.id % 1 ~= 0 then
		return false
	end
	if isNum(def.eggTier) and type(Config.tierLive) == "function" then
		local ok, live = pcall(Config.tierLive, def.eggTier)
		if not ok or live ~= true then
			return false
		end
	end
	if def.random == true and restricted ~= false then
		return false
	end
	return true
end

-- Rareté interdite en offre contextuelle : noms de Config.FORBIDDEN_GIFT_TIERS (Secret, Exclusif, Divin) ou au-delà du plafond de l'offre d'œuf.
local function forbiddenTier(Config, D, t)
	if not isNum(t) or t > D.EGG_MAX_TIER or t < D.EGG_MIN_TIER then
		return true
	end
	local tier = type(Config.TIERS) == "table" and Config.TIERS[t] or nil
	if type(tier) ~= "table" then
		return true
	end
	local list = type(Config.FORBIDDEN_GIFT_TIERS) == "table" and Config.FORBIDDEN_GIFT_TIERS or { "Secret", "Exclusif", "Divin" }
	for _, n in ipairs(list) do
		if tier.name == n then
			return true
		end
	end
	return false
end

-- Clé de l'achat d'œuf de la rareté t : « EggR<t> » sinon le moins cher des achats dont eggTier == t.
local function eggKeyFor(Config, t)
	local products = type(Config.PRODUCTS) == "table" and Config.PRODUCTS or {}
	local direct = "EggR" .. tostring(t)
	if type(products[direct]) == "table" then
		return direct
	end
	local best, bestPrice
	for k, def in pairs(products) do
		if type(def) == "table" and def.eggTier == t then
			local price = isNum(def.robux) and def.robux or 1e9
			if bestPrice == nil or price < bestPrice or (price == bestPrice and tostring(k) < tostring(best)) then
				best, bestPrice = k, price
			end
		end
	end
	return best
end

local function make(entry, key, kind, def, title, text, tier)
	return { id = entry.id, key = key, kind = kind, title = title, text = text, robux = isNum(def.robux) and def.robux or nil, random = def.random == true, tier = tier }
end

-- Choisit l'offre à afficher maintenant, ou nil. PURE.
function Offers.pick(state, profil, now, ctx)
	if type(state) ~= "table" or type(ctx) ~= "table" or type(ctx.Config) ~= "table" or not isNum(now) then
		return nil
	end
	local Config = ctx.Config
	local D = loadData(ctx)
	if type(profil) ~= "table" then
		profil = {}
	end
	local max, gap, grace = limits(Config, D)
	if state.current ~= nil or not isNum(state.shown) or state.shown >= max then
		return nil
	end
	if now - state.joinedAt < grace then
		return nil
	end
	if isNum(state.lastShownAt) and now - state.lastShownAt < gap then
		return nil
	end
	if isNum(state.lastBuyAt) and now - state.lastBuyAt < D.AFTER_BUY then
		return nil
	end
	if busy(ctx, D) then
		return nil
	end
	local day = isNum(profil.dayNumber) and profil.dayNumber or nil
	local flags = { starterDays = day ~= nil and day <= D.STARTER_DAYS }
	for _, entry in ipairs(D.LIST) do
		local trigger = ctx[entry.when] == true or flags[entry.when] == true
		if trigger and (entry.calm ~= true or ctx.calm == true) and state.seen[entry.id] ~= true and not owns(profil, entry.key) then
			local def = defOf(Config, entry.key, entry.kind)
			if visible(Config, def, ctx.restricted) then
				return make(entry, entry.key, entry.kind, def, entry.title, entry.text, nil)
			end
		end
	end
	-- petite offre d'œuf adaptée au palier du joueur
	local egg = D.EGG
	local hatched = isNum(profil.hatchedTotal) and profil.hatchedTotal or 0
	if ctx.calm == true and hatched >= D.EGG_MIN_HATCHED and ctx.baseFull ~= true and ctx.bagFull ~= true and state.seen[egg.id] ~= true then
		local best = isNum(profil.bestTier) and math.floor(profil.bestTier) or 1
		local t = math.min(D.EGG_MAX_TIER, math.max(D.EGG_MIN_TIER, best))
		if not forbiddenTier(Config, D, t) then
			local key = eggKeyFor(Config, t)
			local def = key ~= nil and defOf(Config, key, "product") or nil
			if def ~= nil and not owns(profil, key) and visible(Config, def, ctx.restricted) then
				local tname = tostring(Config.TIERS[t].name)
				local text = string.format(D.EGG_TEXT, tname)
				return make(egg, key, "product", def, "Œuf " .. tname, text, t)
			end
		end
	end
	return nil
end

-- L'offre est affichée : compte une offre, ne reviendra plus dans la session, ouvre la fenêtre d'écart.
function Offers.onShown(state, offer, now)
	if type(state) ~= "table" or type(offer) ~= "table" or not isNum(now) then
		return false
	end
	state.shown = state.shown + 1
	state.lastShownAt = now
	state.current = offer.id
	state.currentAt = now
	state.seen[offer.id] = true
	return true
end

-- Fermeture (geste du joueur ou carte rangée) : jamais de pénalité, la même offre ne revient pas.
function Offers.onClosed(state, now)
	if type(state) ~= "table" then
		return false
	end
	state.current = nil
	state.currentAt = nil
	return true
end

-- Achat de n'importe quoi (carte ou kiosque) : ferme la carte et coupe les offres pendant OffersData.AFTER_BUY.
function Offers.onBought(state, keyOrOffer, now)
	if type(state) ~= "table" or not isNum(now) then
		return false
	end
	state.lastBuyAt = now
	state.current = nil
	state.currentAt = nil
	if type(keyOrOffer) == "table" and type(keyOrOffer.id) == "string" then
		state.seen[keyOrOffer.id] = true
	end
	return true
end

-- Une action démarre pendant que la carte est ouverte : il faut la ranger.
function Offers.shouldHide(state, ctx)
	if type(state) ~= "table" or state.current == nil or type(ctx) ~= "table" then
		return false
	end
	return busy(ctx, loadData(ctx))
end

-- La carte ouverte s'est rangée d'elle-même (durée invisible, aucun compte à rebours affiché) ?
function Offers.expired(state, now, ctx)
	if type(state) ~= "table" or state.current == nil or not isNum(state.currentAt) or not isNum(now) then
		return false
	end
	return now - state.currentAt >= loadData(ctx).TTL
end

return Offers

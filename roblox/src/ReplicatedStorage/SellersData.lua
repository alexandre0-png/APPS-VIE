-- ModuleScript : ReplicatedStorage/Shared/SellersData
-- LOT 16 : DONNEES PURES des 8 vendeurs PNJ du hub (un par catégorie de la boutique du kiosque). Aucun service Roblox, aucune instance : testé hors de Roblox
-- (tests/sellers.luau). Source unique pour ServerScriptService/Sellers (construction, prompts, validation serveur) et pour le client (onglet à ouvrir).
-- Repères : Nord = -Z, Est = +X. Le « devant » d'un vendeur (étiquette, comptoir) regarde le kiosque central.
-- Les vendeurs ne bougent pas et n'interpellent jamais (aucune bulle d'appel, aucun son) : ils se laissent aborder.
local SellersData = {}

SellersData.MODEL_NAME = "Sellers" -- dossier parent de tous les vendeurs (idempotence : détruit puis recréé)
SellersData.ASSET_GROUP = "hub" -- Config.Assets.models.hub.<key> (préchargé par le module Assets, voir SELLERS notes d'intégration)
SellersData.LABEL_PART, SellersData.LIGHT_PART = "Etiquette", "Lueur"
SellersData.WIDTH, SellersData.DEPTH, SellersData.HEIGHT = 6.4, 5.5, 8.1 -- mesures du modèle Blender (X, profondeur, hauteur)
SellersData.RADIUS = 4.4 -- rayon d'emprise (demi-diagonale 6,4 x 5,5 arrondie) utilisé pour contrôler les obstacles
SellersData.GROUND_Y = 0.52 -- dessus du dallage de la place (comme KioskData.GROUND_Y)
SellersData.MAX_PARTS = 80 -- au-delà, le modèle est refusé (repli procédural) : 8 vendeurs restent sous 640 Parts
SellersData.SIZE_TOLERANCE = 0.25 -- largeur mesurée à +-25 % de WIDTH, sinon une mise à l'échelle puis refus
SellersData.RING = { 16, 18, 20, 22, 14.5 } -- rayons essayés d'abord autour du kiosque (studs, spec 14 à 22) ; 14,5 = dernier recours
-- ECART DE SPEC : le kiosque (14, 22) est cerné par le tapis, les routes B1/B3/B4/B5 et les étals : mesuré, 4 vendeurs au plus tiennent entre 14 et 22 studs.
-- Les suivants prennent les rayons ci-dessous, du plus proche au plus lointain (toujours en cercle autour du kiosque, face au centre).
SellersData.RING_FAR = { 24, 26, 28, 30, 32, 35, 38, 42 }
SellersData.MARGIN = 2 -- marge libre exigée autour de chaque obstacle (studs)
SellersData.SPACING = 1.5 -- espace libre minimal entre deux vendeurs (en plus de leurs deux rayons)
SellersData.START_ANGLE = 20 -- degrés : angle idéal du premier vendeur autour du kiosque (les autres tous les 45 degrés)

-- Prompt : distance d'activation (client) et portée de contrôle serveur (plus large : latence et marche), pause entre deux demandes d'un même joueur.
SellersData.PROMPT = { hold = 0.15, distance = 9, requiresLineOfSight = false, action = "Parler" }
SellersData.SERVER_RANGE = 16
SellersData.COOLDOWN = 0.8

-- Étiquette flottante lisible sur mobile : visible jusqu'à 60 studs, taille fixe en pixels.
SellersData.BILLBOARD = { maxDistance = 60, width = 280, height = 132, offsetY = 3.4 }

-- Les 8 vendeurs, dans l'ordre d'affichage des onglets de la boutique. `tab` = identifiant de l'onglet à ouvrir (= id de la catégorie) ;
-- `asset` = id du modèle Blender (clé Config.Assets.models.hub.<key>) ; `keys` = achats (Config.PRODUCTS / Config.PASSES) de la catégorie ;
-- `lines` = 2 exemples courts (sans prix, sans urgence). Les prix affichés sont calculés sur les achats réellement disponibles (id > 0).
SellersData.VENDORS = {
	{ id = "eggs", tab = "eggs", key = "vendor_eggs", asset = 138633300069014, emoji = "🥚", title = "Œufs", color = { 255, 214, 120 },
		lines = { "Œufs de rareté fixe", "Espèce tirée au sort, probabilités affichées" },
		keys = { "EggR2", "EggR3", "EggR4", "EggR5", "ExclusiveEgg", "EggR7", "EggSecret", "EggExclusive", "EggDivine" } },
	{ id = "luck", tab = "luck", key = "vendor_luck", asset = 137414127061497, emoji = "🍀", title = "Chance & boosts", color = { 120, 220, 120 },
		lines = { "Potions, tapis doré, passes de chance", "Aucun pet n'est garanti" },
		keys = { "LuckPotionMini", "LuckPotion", "GoldenBelt", "ServerLuck", "DoubleLuck", "Lucky", "Fast", "Speed", "PrivateBelt", "Lucky2" } },
	{ id = "coins", tab = "coins", key = "vendor_coins", asset = 82919202214027, emoji = "🪙", title = "Pièces", color = { 255, 200, 60 },
		lines = { "Sacs de pièces", "Revenus x2 pour toujours" },
		keys = { "CoinPackS", "CoinPack", "Coins2x" } },
	{ id = "base", tab = "base", key = "vendor_base", asset = 79064954843258, emoji = "🏠", title = "Base & confort", color = { 150, 200, 255 },
		lines = { "Emplacements, sac d'œufs, calendrier", "Du confort pour ta base" },
		keys = { "StreakRestore", "CalendarCatchup", "InstantHatch", "EggBagPlus", "ExtraSlots", "Collector", "VipBase" } },
	{ id = "combat", tab = "combat", key = "vendor_combat", asset = 105059296701916, emoji = "⚔️", title = "Combat & vol", color = { 255, 140, 110 },
		lines = { "Tickets d'arène, relance, corbeaux", "Aucune force n'est vendue" },
		keys = { "ArenaTickets", "Revive", "RemoteSteal", "RemoteStealPack" } },
	{ id = "pass", tab = "pass", key = "vendor_pass", asset = 72959276245033, emoji = "🏅", title = "Passe de combat", color = { 200, 150, 255 },
		lines = { "Piste gratuite et piste premium", "30 paliers par saison" },
		keys = { "SeasonPremium", "SeasonUpgradePlus", "SeasonPremiumPlus" } },
	{ id = "packs", tab = "packs", key = "vendor_packs", asset = 80912619819088, emoji = "🎁", title = "Packs", color = { 255, 170, 90 },
		lines = { "Pack de départ, Pack Légende", "Coffre royal" },
		keys = { "StarterPack", "BundleLegend", "BundleRoyalNoPass", "BundleRoyal" } },
	{ id = "cosmetics", tab = "cosmetics", key = "vendor_cosmetics", asset = 82243751363820, emoji = "🎭", title = "Cosmétiques", color = { 255, 150, 200 },
		lines = { "Poses de victoire", "Purement visuel" },
		keys = { "EmoteVictory1", "EmoteVictory2", "EmoteVictory3", "EmoteVictory4", "EmoteVictory5", "EmoteVictory6" } },
}

-- Prix de référence (R$) de ACHATS_DEFINITIONS, utilisés seulement si Config ne porte pas de prix (passes : le code n'en porte pas) ou si aucun Config n'est fourni.
SellersData.PRICES = {
	EggR2 = 15, EggR3 = 25, EggR4 = 49, EggR5 = 99, ExclusiveEgg = 249, EggR7 = 799, EggSecret = 1499, EggExclusive = 3499, EggDivine = 6999,
	LuckPotionMini = 29, LuckPotion = 99, GoldenBelt = 99, ServerLuck = 129, DoubleLuck = 149, Lucky = 149, Fast = 149, Speed = 149, PrivateBelt = 299, Lucky2 = 349,
	CoinPackS = 19, CoinPack = 99, Coins2x = 199,
	StreakRestore = 29, CalendarCatchup = 29, InstantHatch = 49, EggBagPlus = 149, ExtraSlots = 249, Collector = 249, VipBase = 399,
	ArenaTickets = 19, Revive = 49, RemoteSteal = 79, RemoteStealPack = 199,
	SeasonPremium = 399, SeasonUpgradePlus = 400, SeasonPremiumPlus = 799,
	StarterPack = 99, BundleLegend = 999, BundleRoyalNoPass = 1100, BundleRoyal = 1499,
	EmoteVictory1 = 39, EmoteVictory2 = 39, EmoteVictory3 = 39, EmoteVictory4 = 39, EmoteVictory5 = 39, EmoteVictory6 = 39,
}

SellersData.ACTIONS = { eggs = true, luck = true, coins = true, base = true, combat = true, pass = true, packs = true, cosmetics = true }

function SellersData.vendor(id)
	if type(id) ~= "string" then
		return nil
	end
	for _, v in ipairs(SellersData.VENDORS) do
		if v.id == id then
			return v
		end
	end
	return nil
end

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- 1499 -> "1 499" (espace simple : lisible partout).
function SellersData.fmtR(n)
	if not isNum(n) then
		return "?"
	end
	local s = tostring(math.floor(n + 0.5))
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		if count > 0 and count % 3 == 0 then
			out = " " .. out
		end
		out = string.sub(s, i, i) .. out
		count = count + 1
	end
	return out
end

-- Prix en R$ d'un achat : champ `robux` de la définition du Config, sinon prix de référence ci-dessus.
local function priceOf(Config, key)
	local def
	if type(Config) == "table" then
		if type(Config.PRODUCTS) == "table" and type(Config.PRODUCTS[key]) == "table" then
			def = Config.PRODUCTS[key]
		elseif type(Config.PASSES) == "table" and type(Config.PASSES[key]) == "table" then
			def = Config.PASSES[key]
		end
	end
	if def ~= nil and isNum(def.robux) then
		return def.robux, def
	end
	return SellersData.PRICES[key], def
end

-- Plus petit et plus grand prix des achats DISPONIBLES (id > 0) de la catégorie. Sans Config : tous les prix de référence. Retourne (min, max, nombre).
function SellersData.priceRange(vendor, Config)
	local lo, hi, n = nil, nil, 0
	if type(vendor) ~= "table" then
		return nil, nil, 0
	end
	for _, key in ipairs(vendor.keys) do
		local price, def = priceOf(Config, key)
		local available = true
		if type(Config) == "table" then
			available = def ~= nil and type(def.id) == "number" and def.id > 0 and def.id % 1 == 0
			if available and type(def.eggTier) == "number" and type(Config.tierLive) == "function" and not Config.tierLive(def.eggTier) then
				available = false -- lot 16 (intégration) : œuf d'une rareté sans espèce publiée = masqué en boutique, donc hors de la ligne de prix
			end
		end
		if available and isNum(price) then
			n = n + 1
			if lo == nil or price < lo then
				lo = price
			end
			if hi == nil or price > hi then
				hi = price
			end
		end
	end
	return lo, hi, n
end

-- Ligne de prix de l'étiquette : « Œufs : de 15 à 6 999 R$ » ; un seul prix : « Pièces : 19 R$ » ; rien d'ouvert : « Bientôt disponible » (aucune urgence).
function SellersData.priceLine(vendor, Config)
	local lo, hi, n = SellersData.priceRange(vendor, Config)
	if n == 0 or lo == nil then
		return vendor.title .. " : bientôt disponible"
	end
	if lo == hi then
		return vendor.title .. " : " .. SellersData.fmtR(lo) .. " R$"
	end
	return vendor.title .. " : de " .. SellersData.fmtR(lo) .. " à " .. SellersData.fmtR(hi) .. " R$"
end

-- Texte complet de l'étiquette (SurfaceGui de la planche) : emoji + titre.
function SellersData.labelText(vendor)
	return vendor.emoji .. " " .. vendor.title
end

---------------------------------------------------------------- placement (pur)

local function deg2rad(d)
	return d * math.pi / 180
end

-- Distance d'un point (cx, cz) à un rectangle { x0, x1, z0, z1 }.
local function rectDist(cx, cz, x0, x1, z0, z1)
	local nx, nz = math.max(x0, math.min(cx, x1)), math.max(z0, math.min(cz, z1))
	return math.sqrt((cx - nx) ^ 2 + (cz - nz) ^ 2)
end

-- Obstacles supplémentaires du décor : bancs et lampadaires (DecorData.existing) et rectangle du tapis élargi (DecorData.plaza.beltPad). Aucun obstacle si decor = nil.
local function decorHit(Map2, decor, x, z, r, margin)
	if type(decor) ~= "table" then
		return false
	end
	if type(decor.existing) == "table" then
		for _, e in ipairs(decor.existing) do
			if math.sqrt((x - e[1]) ^ 2 + (z - e[2]) ^ 2) < e[3] + r + margin then
				return true, "décor existant"
			end
		end
	end
	local pad = type(decor.plaza) == "table" and decor.plaza.beltPad or nil
	local b = Map2.belt
	if type(pad) == "table" and type(b) == "table" then
		if rectDist(x, z, b.x0 - pad.x0, b.bin.x + pad.x1, -(b.width / 2 + pad.z0), b.width / 2 + pad.z1) < r + margin then
			return true, "emprise du tapis"
		end
	end
	return false
end

-- Place les 8 vendeurs en cercle autour du centre du kiosque (Map2.kiosk ou K.CENTER), à 14 à 22 studs, face au centre. Pur et déterministe.
--   K = KioskData (overlap, angle, RADIUS, CENTER) ; opts = { decor = DecorData (facultatif), center = { x, z } (facultatif) }
-- Retourne { list = { { id, x, z, r, ring, angle, faceX, faceZ } ... }, missing = { ids non placés }, center }.
local layoutCache = setmetatable({}, { __mode = "k" }) -- lot 16 (intégration) : calcul coûteux mémorisé par carte (Main et Builder le demandent tous deux)
function SellersData.layout(Map2, K, opts)
	opts = opts or {}
	local memo = type(Map2) == "table" and layoutCache[Map2] or nil
	local ckey = tostring(K) .. "|" .. tostring(opts.decor) .. "|" .. tostring(opts.center and opts.center.x) .. "|" .. tostring(opts.center and opts.center.z)
	if memo and memo.key == ckey then
		return memo.value
	end
	local result = SellersData.computeLayout(Map2, K, opts)
	if type(Map2) == "table" then
		layoutCache[Map2] = { key = ckey, value = result }
	end
	return result
end
function SellersData.computeLayout(Map2, K, opts)
	local center = opts.center or (type(Map2.kiosk) == "table" and Map2.kiosk) or K.CENTER
	local cx, cz = center.x, center.z
	local VR = SellersData.RADIUS
	local list, missing = {}, {}
	local kioskR = type(K.RADIUS) == "number" and K.RADIUS or 7.7
	-- ordre de recherche des angles : écart croissant autour de l'angle idéal (0, +2,5, -2,5, +5, -5, ...)
	local offsets = { 0 }
	for k = 1, 72 do
		offsets[#offsets + 1] = k * 2.5
		offsets[#offsets + 1] = -k * 2.5
	end
	for i, v in ipairs(SellersData.VENDORS) do
		local ideal = SellersData.START_ANGLE + (i - 1) * 45
		local placed
		for _, rings in ipairs({ SellersData.RING, SellersData.RING_FAR }) do
		for _, off in ipairs(offsets) do
			for _, ring in ipairs(rings) do
				if placed == nil then
					local a = deg2rad(ideal + off)
					local x, z = cx + ring * math.cos(a), cz + ring * math.sin(a)
					local ok = ring >= kioskR + VR + SellersData.MARGIN
					if ok then
						local hit = K.overlap(Map2, x, z, VR, SellersData.MARGIN)
						ok = hit == false
					end
					if ok then
						ok = decorHit(Map2, opts.decor, x, z, VR, SellersData.MARGIN) == false
					end
					if ok then
						for _, p in ipairs(list) do
							if math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) < 2 * VR + SellersData.SPACING then
								ok = false
							end
						end
					end
					if ok then
						placed = { id = v.id, x = x, z = z, r = VR, ring = ring, angle = ideal + off, faceX = cx, faceZ = cz }
					end
				end
			end
		end
		end
		if placed ~= nil then
			list[#list + 1] = placed
		else
			missing[#missing + 1] = v.id
		end
	end
	return { list = list, missing = missing, center = { x = cx, z = cz } }
end

-- Emprises { x, z, r } des vendeurs placés (r = rayon + marge) : à ajouter aux exclusions du décor (Decor.lua ne lit que le disque Map2.kiosk).
function SellersData.footprints(layout)
	local out = {}
	if type(layout) == "table" and type(layout.list) == "table" then
		for _, p in ipairs(layout.list) do
			out[#out + 1] = { x = p.x, z = p.z, r = p.r + SellersData.MARGIN }
		end
	end
	return out
end

return SellersData

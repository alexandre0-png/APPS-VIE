-- ModuleScript : ReplicatedStorage/Shared/ShopData (LOT 16, boutique pure : DONNÉES, aucun service Roblox)
-- Ids, prix (R$), catégories et drapeaux de TOUS les achats de la boutique. L'intégrateur appelle `ShopData.merge(Config)` à la fin de Config.lua (ou copie ces champs
-- dans Config.PRODUCTS / Config.PASSES) : les champs existants (name, emoji, desc, eggTier...) sont conservés, id / robux / cat / random / once / season / eggTier sont posés ici.
-- Drapeaux : random = achat masqué et refusé si PolicyService restreint ; once = achat unique à vie ; season = achat unique PAR saison (season.premium = n) ;
-- eggTier = rareté FIXE de l'œuf vendu. Aucun plafond d'achat : seuls `once` et `season` limitent.
local D = {}

local function P(id, robux, cat, extra)
	local e = { kind = "product", id = id, robux = robux, cat = cat }
	for k, v in pairs(extra or {}) do
		e[k] = v
	end
	return e
end
local function G(id, robux, cat, extra)
	local e = P(id, robux, cat, extra)
	e.kind = "pass"
	e.once = true
	return e
end

D.ENTRIES = {
	-- Œufs
	EggR2 = P(3736703563, 15, "eggs", { random = true, eggTier = 2 }),
	EggR3 = P(3736703571, 25, "eggs", { random = true, eggTier = 3 }),
	EggR4 = P(3736703588, 49, "eggs", { random = true, eggTier = 4 }),
	EggR5 = P(3736703667, 99, "eggs", { random = true, eggTier = 5 }),
	ExclusiveEgg = P(3734229320, 249, "eggs", { random = true, eggTier = 6 }),
	EggR7 = P(3736703695, 799, "eggs", { random = true, eggTier = 7 }),
	EggSecret = P(3736452048, 1499, "eggs", { random = true, eggTier = 8 }),
	EggExclusive = P(3736452061, 3499, "eggs", { random = true, eggTier = 9 }),
	EggDivine = P(3736452072, 6999, "eggs", { random = true, eggTier = 10 }),
	-- Chance & boosts
	LuckPotionMini = P(3736703579, 29, "luck", { random = true }),
	LuckPotion = P(3734229337, 99, "luck", { random = true }),
	GoldenBelt = P(3736121227, 99, "luck", { random = true }),
	ServerLuck = P(3736121217, 129, "luck", { random = true }),
	DoubleLuck = P(3736703673, 149, "luck", { random = true }),
	Lucky = G(2093447290, 149, "luck", { random = true }),
	Fast = G(2097173053, 149, "luck"),
	Speed = G(2092253306, 149, "luck"),
	PrivateBelt = G(2098265697, 299, "luck", { random = true }),
	Lucky2 = G(2102045961, 349, "luck", { random = true }),
	-- Pièces
	CoinPackS = P(3736703557, 19, "coins"),
	CoinPack = P(3734229339, 99, "coins"),
	Coins2x = G(2093291260, 199, "coins"),
	-- Base & confort
	StreakRestore = P(3736703610, 29, "base"),
	CalendarCatchup = P(3736695392, 29, "base"),
	InstantHatch = P(3734229329, 49, "base"),
	EggBagPlus = G(2099454839, 149, "base"),
	ExtraSlots = G(2098181699, 249, "base"),
	Collector = G(2099556764, 249, "base"),
	VipBase = G(2094209172, 399, "base"),
	-- Combat & vol
	ArenaTickets = P(3736703606, 19, "combat"),
	Revive = P(3734229323, 49, "combat"),
	RemoteSteal = P(3736121232, 79, "combat"),
	RemoteStealPack = P(3736121238, 199, "combat"),
	-- Passe de combat (revendu à chaque saison : season = true)
	SeasonPremium = P(3736703683, 399, "season", { season = true }),
	SeasonUpgradePlus = P(3736704000, 400, "season", { season = true }),
	SeasonPremiumPlus = P(3736703689, 799, "season", { season = true }),
	-- Packs
	StarterPack = P(3734229313, 99, "packs", { random = true, once = true }),
	BundleLegend = P(3736703706, 999, "packs", { random = true }),
	BundleRoyalNoPass = P(3736704205, 1100, "packs", { random = true }),
	BundleRoyal = P(3736703714, 1499, "packs", { random = true }),
	-- Cosmétiques
	EmoteVictory1 = P(3736703619, 39, "cosmetics", { once = true }),
	EmoteVictory2 = P(3736703629, 39, "cosmetics", { once = true }),
	EmoteVictory3 = P(3736703634, 39, "cosmetics", { once = true }),
	EmoteVictory4 = P(3736703641, 39, "cosmetics", { once = true }),
	EmoteVictory5 = P(3736703649, 39, "cosmetics", { once = true }),
	EmoteVictory6 = P(3736703657, 39, "cosmetics", { once = true }),
}

-- Fusionne ces données dans Config.PRODUCTS / Config.PASSES (idempotent). `info` (ShopInfo) fournit name / desc des entrées nouvelles.
function D.merge(config, info)
	config.PRODUCTS = config.PRODUCTS or {}
	config.PASSES = config.PASSES or {}
	for key, e in pairs(D.ENTRIES) do
		local bag = e.kind == "pass" and config.PASSES or config.PRODUCTS
		local def = bag[key] or {}
		bag[key] = def
		for _, f in ipairs({ "id", "robux", "cat", "random", "once", "season", "eggTier" }) do
			def[f] = e[f]
		end
		if info and info[key] then
			def.name = def.name or info[key].title
			def.desc = def.desc or info[key].def
		end
	end
	return config
end

return D

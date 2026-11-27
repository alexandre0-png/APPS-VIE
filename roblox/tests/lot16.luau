--!nocheck
-- Tests du lot 16 (intégration, partie PURE) : catalogue de Config = ShopData (ids réels, aucun id 0), 8 catégories, passe de combat (Config.SEASON = SeasonData),
-- PolicyService pour tout achat à hasard, œufs Secret / Exclusif / Divin, règle de mise à niveau, Double chance <= 70, Chance +10 % II, textes sans « plafond »,
-- tapis doré aligné (4 s), télémétrie 6 types <= 1 événement / s / joueur, vendeurs hors du décor de carte, aucun produit qui touche Battle.STATS / slot.x / boucliers.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs } (tests/run.luau). Style : pas de `+=`, pas de `continue`, pas de math.atan2.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", C3)
	local Shop = load("roblox/src/ReplicatedStorage/Shop.lua", "Shop")
	local ShopData = load("roblox/src/ReplicatedStorage/ShopData.lua", "ShopData")
	local Info = load("roblox/src/ReplicatedStorage/ShopInfo.lua", "ShopInfo")
	local SD = load("roblox/src/ReplicatedStorage/SeasonData.lua", "SeasonData")
	local Season = load("roblox/src/ReplicatedStorage/Season.lua", "Season")
	local OffersData = load("roblox/src/ReplicatedStorage/OffersData.lua", "OffersData")
	local Telemetry = load("roblox/src/ServerScriptService/Telemetry.lua", "Telemetry")
	local Rules = load("roblox/src/ServerScriptService/Rules.lua", "Rules").new(Config)
	local function has(s, w)
		return string.find(string.lower(s), string.lower(w), 1, true) ~= nil
	end

	---------------------------------------------------------------- 1. Catalogue
	suite("Lot 16 : catalogue de Config = ShopData (46 achats, ids réels, aucun id 0)")
	T.bad = {}
	for key, e in pairs(ShopData.ENTRIES) do
		local def = (e.kind == "pass" and Config.PASSES or Config.PRODUCTS)[key]
		if type(def) ~= "table" then
			T.bad[#T.bad + 1] = key .. " absent"
		else
			for _, f in ipairs({ "id", "robux", "cat", "random", "once", "season", "eggTier" }) do
				if def[f] ~= e[f] then
					T.bad[#T.bad + 1] = key .. "." .. f
				end
			end
		end
	end
	T.n = 0
	for key in pairs(Config.SHOP) do
		T.n = T.n + 1
		if not ShopData.ENTRIES[key] then
			T.bad[#T.bad + 1] = key .. " en trop"
		end
	end
	check("Config.SHOP / PRODUCTS / PASSES = ShopData.ENTRIES (mêmes clés, ids, prix, catégories, drapeaux) " .. table.concat(T.bad, ","), #T.bad == 0 and T.n == 46)
	T.zero = {}
	for _, bag in ipairs({ Config.PRODUCTS, Config.PASSES }) do
		for key, def in pairs(bag) do
			if not Config.purchasable(def) then
				T.zero[#T.zero + 1] = key
			end
		end
	end
	check("Aucun achat à id 0 ou invalide (" .. table.concat(T.zero, ",") .. ")", #T.zero == 0)
	T.ids = { CoinPackS = 3736703557, EggR2 = 3736703563, EggR3 = 3736703571, LuckPotionMini = 3736703579, EggR4 = 3736703588, ArenaTickets = 3736703606, StreakRestore = 3736703610,
		EmoteVictory1 = 3736703619, EmoteVictory2 = 3736703629, EmoteVictory3 = 3736703634, EmoteVictory4 = 3736703641, EmoteVictory5 = 3736703649, EmoteVictory6 = 3736703657,
		EggR5 = 3736703667, DoubleLuck = 3736703673, SeasonPremium = 3736703683, SeasonPremiumPlus = 3736703689, EggR7 = 3736703695, BundleLegend = 3736703706, BundleRoyal = 3736703714,
		SeasonUpgradePlus = 3736704000, BundleRoyalNoPass = 3736704205, CalendarCatchup = 3736695392, EggSecret = 3736452048, EggExclusive = 3736452061, EggDivine = 3736452072 }
	T.idBad = {}
	for k, id in pairs(T.ids) do
		if not (Config.PRODUCTS[k] and Config.PRODUCTS[k].id == id) then
			T.idBad[#T.idBad + 1] = k
		end
	end
	check("Ids des achats du lot 16 branchés exactement (" .. table.concat(T.idBad, ",") .. ")", #T.idBad == 0 and Config.PASSES.EggBagPlus.id == 2099454839 and Config.PASSES.Collector.id == 2099556764 and Config.PASSES.Lucky2.id == 2102045961)
	check("Œufs Secret / Exclusif / Divin VENDUS : rareté fixe 8 / 9 / 10, 1 499 / 3 499 / 6 999 R$, random = true", Config.PRODUCTS.EggSecret.eggTier == 8 and Config.PRODUCTS.EggExclusive.eggTier == 9 and Config.PRODUCTS.EggDivine.eggTier == 10
		and Config.PRODUCTS.EggSecret.robux == 1499 and Config.PRODUCTS.EggExclusive.robux == 3499 and Config.PRODUCTS.EggDivine.robux == 6999 and Config.PRODUCTS.EggSecret.random and Config.PRODUCTS.EggExclusive.random and Config.PRODUCTS.EggDivine.random)
	T.catOk = #Config.SHOP_CATEGORIES == 8
	for i, c in ipairs(Shop.CATEGORIES) do
		local k = Config.SHOP_CATEGORIES[i]
		T.catOk = T.catOk and k ~= nil and k.key == c.key and k.title == c.title and k.icon == c.icon
	end
	check("8 catégories, ordre fixe identique (Config.SHOP_CATEGORIES = Shop.CATEGORIES), passe de combat en 6e", T.catOk and Config.SHOP_CATEGORIES[6].key == "season")
	T.infoBad = {}
	for key in pairs(Config.SHOP) do
		local i = Info[key]
		if not i or i.cat ~= Config.SHOP[key].cat then
			T.infoBad[#T.infoBad + 1] = key
		end
	end
	check("Chaque achat a sa fiche ShopInfo (même catégorie) " .. table.concat(T.infoBad, ","), #T.infoBad == 0)
	T.cap = {}
	local function scan(where, txt)
		if type(txt) == "string" and (has(txt, "plafond") or has(txt, "par jour)") or has(txt, "jusqu'à 30 min")) then
			T.cap[#T.cap + 1] = where
		end
	end
	for key, i in pairs(Info) do
		for _, f in ipairs({ "title", "def", "detail", "notDo", "chance", "limit" }) do
			scan(key .. "." .. f, i[f])
		end
	end
	for key, def in pairs(Config.PRODUCTS) do
		scan(key .. ".desc", def.desc)
	end
	for _, o in ipairs(OffersData.LIST) do
		scan(o.id, o.text)
	end
	check("Aucun texte d'achat ne parle de « plafond » d'achat (" .. table.concat(T.cap, ",") .. ")", #T.cap == 0)
	check("Tapis doré : une seule valeur d'intervalle (BELT.golden.interval = 4 s) et le texte dit 4 s ; durées cumulables sans plafond d'achat",
		Config.BELT.golden.interval == 4 and has(Config.PRODUCTS.GoldenBelt.desc, "4 s") and not has(Config.PRODUCTS.GoldenBelt.desc, "3 s") and Config.BELT.golden.maxSeconds >= 86400 and Config.SERVER_LUCK.maxSeconds >= 86400)
	check("Config.SEASON = SeasonData.SEASON (début, 60 jours, 30 paliers, grâce, plafond/jour), Config.BUILD renseigné",
		Config.SEASON.start == SD.SEASON.start and Config.SEASON.days == 60 and SD.SEASON.days == 60 and Config.SEASON.tiers == SD.SEASON.tiers and Config.SEASON.graceDays == SD.SEASON.graceDays and Config.SEASON.dailyCap == SD.SEASON.dailyCap and type(Config.BUILD) == "string" and #Config.BUILD > 0)
	T.vend = true
	for _, k in ipairs({ "vendor_eggs", "vendor_luck", "vendor_coins", "vendor_base", "vendor_combat", "vendor_pass", "vendor_packs", "vendor_cosmetics" }) do
		T.vend = T.vend and type(Config.Assets.models.hub[k]) == "number" and Config.Assets.models.hub[k] > 0
	end
	check("Modèles des 8 vendeurs (lot 30) dans Config.Assets.models.hub", T.vend and Config.Assets.models.hub.vendor_eggs == 138633300069014 and Config.Assets.models.hub.vendor_cosmetics == 82243751363820)
	check("Œuf Exclusif : fiche honnête (aucune « espèce de l'événement » tant que le lot 11 n'existe pas)", not has(Info.EggExclusive.detail .. Info.EggExclusive.def, "événement") and has(Info.EggExclusive.detail, "tirée au sort"))

	---------------------------------------------------------------- 2. PolicyService, raretés, mise à niveau
	suite("Lot 16 : PolicyService pour tout achat à hasard, raretés publiées, règle de mise à niveau")
	local Full = load("roblox/src/ReplicatedStorage/Config.lua", "Config", C3)
	for t = 1, #Full.TIERS do
		if not Full.tierLive(t) then
			Full.PETS[#Full.PETS + 1] = { tier = t, emoji = "?", name = "Factice" .. t, inc = 1 }
		end
	end
	local function prof(extra)
		local p = { cap = 4, slots = { false, false, false, false }, eggBag = {}, passes = {}, once = {}, season = { cur = 2, premium = 0, plus = 0 } }
		for k, v in pairs(extra or {}) do
			p[k] = v
		end
		return p
	end
	T.pol = {}
	for key, e in pairs(Config.SHOP) do
		if e.random then
			for _, r in ipairs({ true, "nil" }) do
				local ok, why = Shop.canBuy(prof(), Full, key, r == true or nil)
				if ok or why ~= "policy" then
					T.pol[#T.pol + 1] = key
				end
			end
		end
	end
	check("Chaque achat random est masqué et refusé AVANT paiement si PolicyService restreint OU inconnu/en échec (" .. table.concat(T.pol, ",") .. ")", #T.pol == 0)
	T.okRand = Shop.canBuy(prof(), Full, "EggDivine", false)
	T.okReal = Shop.canBuy(prof(), Config, "EggSecret", false)
	T.okNoRand = Shop.canBuy(prof(), Config, "CoinPackS", true)
	check("Divin achetable quand l'espèce existe et PolicyService autorise ; Secret refusé tant qu'aucune espèce n'est publiée ; pièces achetables même restreint", T.okRand == true and (T.okReal == false or Config.tierLive(8)) and T.okNoRand == true)
	local function vis(p, key)
		for _, g in ipairs(Shop.visibleOffers(p, Full, false, Info)) do
			for _, o in ipairs(g.offers) do
				if o.key == key then
					return o.owned and "owned" or "buy"
				end
			end
		end
		return "hidden"
	end
	T.p0 = prof()
	T.pP = prof({ season = { cur = 2, premium = 2, plus = 0 } })
	check("Mise à niveau : sans premium -> premium, premium+ et Coffre royal visibles ; complément et « sans passe » cachés", vis(T.p0, "SeasonPremium") == "buy" and vis(T.p0, "SeasonPremiumPlus") == "buy" and vis(T.p0, "BundleRoyal") == "buy" and vis(T.p0, "SeasonUpgradePlus") == "hidden" and vis(T.p0, "BundleRoyalNoPass") == "hidden")
	check("Mise à niveau : premium possédé -> « Possédé », seuls le complément (400) et le coffre sans passe (1 100) restent achetables", vis(T.pP, "SeasonPremium") == "owned" and vis(T.pP, "SeasonUpgradePlus") == "buy" and vis(T.pP, "SeasonPremiumPlus") == "hidden" and vis(T.pP, "BundleRoyal") == "hidden" and vis(T.pP, "BundleRoyalNoPass") == "buy")
	T.pre = prof({ season = { cur = 0, premium = 0, plus = 0 } })
	check("Avant la saison 1 (cur = 0) : passe de combat et coffres royaux masqués (rien à créditer)", vis(T.pre, "SeasonPremium") == "hidden" and vis(T.pre, "BundleRoyal") == "hidden" and select(2, Shop.canBuy(T.pre, Full, "SeasonPremium", false)) == "noseason")
	T.full = prof({ slots = { 1, 1, 1, 1 } })
	for i = 1, Full.EGG_BAG.size do
		T.full.eggBag[i] = 1
	end
	check("Base ET sac pleins : tout achat qui contient un œuf est refusé AVANT paiement (« fais de la place »), un achat sans œuf reste possible",
		select(2, Shop.canBuy(T.full, Full, "EggR3", false)) == "faisDeLaPlace" and select(2, Shop.canBuy(T.full, Full, "BundleLegend", false)) == "faisDeLaPlace" and Shop.canBuy(T.full, Full, "CoinPack", false) == true)
	T.bagPlus = setmetatable({ EGG_BAG = { size = Full.EGG_BAG.sizePlus } }, { __index = Full })
	check("Passe Sac d'œufs +10 : avec 10 œufs dans le sac, il reste de la place (20 places)", Shop.canBuy(T.full, T.bagPlus, "EggR3", false) == true and Full.EGG_BAG.sizePlus == 20)
	check("Achats uniques : poses et Pack de départ « Possédé » puis refusés ; passes possédés refusés", select(2, Shop.canBuy(prof({ once = { EmoteVictory3 = true } }), Full, "EmoteVictory3", false)) == "owned"
		and select(2, Shop.canBuy(prof({ once = { StarterPack = true } }), Full, "StarterPack", false)) == "owned" and select(2, Shop.canBuy(prof({ passes = { Lucky2 = true } }), Full, "Lucky2", false)) == "owned")
	T.rep = true
	for _ = 1, 50 do
		T.rep = T.rep and Shop.canBuy(prof(), Full, "EggR4", false) == true and Shop.canBuy(prof(), Full, "BundleRoyal", false) == true
	end
	check("Plus aucun plafond d'achat : 50 contrôles successifs du même œuf / du Coffre royal restent acceptés", T.rep)

	---------------------------------------------------------------- 3. Chance
	suite("Lot 16 : Double chance <= 70, Chance +10 % II dans les bonus payants plafonnés")
	check("Double chance : x2 puis 70 au plus (5 -> 10, 30 -> 60, 50 -> 70) ; sans elle, 70 au plus", Shop.luckTotal(5, true) == 10 and Shop.luckTotal(30, true) == 60 and Shop.luckTotal(50, true) == 70 and Shop.luckTotal(90, false) == 70)
	check("Chance +10 % II : +10 points payants (5 -> 15), cumul pass + pass II + potion plafonné à 30 points payants (lot 9)", Rules.upPoints(0, false, false, false, false, true) == 15 and Rules.upPoints(0, false, true, true, false, true) == 5 + Config.BOOST_CAP.paidUp and Rules.upPoints(0, false, false, false, false) == 5)

	---------------------------------------------------------------- 4. Télémétrie
	suite("Lot 16 : télémétrie I.2 (6 types d'événements, <= 1 / s / joueur, version Config.BUILD)")
	T.calls = {}
	local svc = {}
	for _, m in ipairs({ "LogCustomEvent", "LogEconomyEvent", "LogFunnelStepEvent", "LogOnboardingFunnelStepEvent", "LogProgressionCompleteEvent" }) do
		svc[m] = function(_, ...)
			T.calls[#T.calls + 1] = { m = m, args = { ... } }
		end
	end
	T.clock = 0
	local tele = Telemetry.new(svc, function()
		return T.clock
	end)
	local pl = {}
	check("6 types acceptés (custom, economy, funnel, onboarding, progression, version), type ou étape inconnus refusés",
		tele.event(pl, "custom", "puzzle_solved") and tele.event(pl, "economy", "Source", 500, 1000, "Gameplay", "belt") and tele.event(pl, "funnel", "shop_view", "f1") and tele.event(pl, "onboarding", "join")
		and tele.event(pl, "progression", "season", 4) and tele.event(pl, "version", Config.BUILD) and not tele.event(pl, "bidon", 1) and not tele.event(pl, "funnel", "inconnu") and not tele.event(pl, "version", "a b"))
	for _ = 1, 20 do
		tele.step()
	end
	check("Débit : 20 pas dans la même seconde = 1 seul envoi", #T.calls == 1)
	for i = 1, 10 do
		T.clock = i
		tele.step()
	end
	T.kinds = {}
	for _, c in ipairs(T.calls) do
		T.kinds[c.m] = true
	end
	check("Les 6 événements partent à 1 par seconde (5 méthodes AnalyticsService, version = LogCustomEvent « version_<BUILD> »)", #T.calls == 6 and T.kinds.LogEconomyEvent and T.kinds.LogFunnelStepEvent and T.kinds.LogOnboardingFunnelStepEvent and T.kinds.LogProgressionCompleteEvent and T.calls[6].args[2] == "version_" .. Config.BUILD)

	---------------------------------------------------------------- 5. Passe de combat (données) et vendeurs / décor
	suite("Lot 16 : passe de combat (60 jours), vendeurs hors du décor de carte")
	local S = Season.new(Config, SD)
	local p = { seasonXp = 777 }
	S.migrate(p, SD.SEASON.start + 10)
	S.migrate(p, SD.SEASON.start + 20)
	check("Migration : l'ancien seasonXp du lot 15 est versé UNE fois dans season.xp (idempotent)", p.season.xp == 777 and p.seasonXp == 0 and p.season.n == 1)
	check("Saison n+1 commence exactement 60 jours après (aucun chevauchement)", S.currentSeason(SD.SEASON.start + 60 * 86400 - 1).n == 1 and S.currentSeason(SD.SEASON.start + 60 * 86400).n == 2)
	local MapGeo = load("roblox/src/ReplicatedStorage/MapGeo.lua", "MapGeo")
	local Placement = load("roblox/src/ReplicatedStorage/Placement.lua", "Placement")
	local DecorData = load("roblox/src/ReplicatedStorage/DecorData.lua", "DecorData")
	local Decor = load("roblox/src/ServerScriptService/Decor.lua", "Decor")
	local KioskData = load("roblox/src/ReplicatedStorage/KioskData.lua", "KioskData")
	local SellersData = load("roblox/src/ReplicatedStorage/SellersData.lua", "SellersData")
	local lay = SellersData.layout(Config.Map2, KioskData, { decor = DecorData })
	local fp = SellersData.footprints(lay)
	local plan = Decor.plan(MapGeo.new(Config), Config, DecorData, { placement = Placement.new(Config, MapGeo), occupied = fp })
	T.hits = 0
	for _, sl in ipairs(plan.slots) do
		for _, f in ipairs(fp) do
			if not sl.anchor and math.sqrt((sl.x - f.x) ^ 2 + (sl.z - f.z) ^ 2) < f.r + (sl.r or 0) then
				T.hits = T.hits + 1
			end
		end
	end
	T.near = 0
	for _, v in ipairs(lay.list) do
		local d = math.sqrt((v.x - Config.Map2.kiosk.x) ^ 2 + (v.z - Config.Map2.kiosk.z) ^ 2)
		if d >= 14 and d <= 22 then
			T.near = T.near + 1
		end
	end
	check("8 vendeurs placés (" .. T.near .. " à 14-22 studs, écart accepté), aucun exemplaire du décor de carte dans leurs emprises (" .. T.hits .. ")", #lay.list == 8 and #lay.missing == 0 and T.hits == 0 and #fp == 8)

	---------------------------------------------------------------- 6. Aucun produit ne touche les stats de combat, l'XP des pets, les boucliers, les trophées
	suite("Lot 16 : aucun achat ne vend de force, d'XP de pet, de protection ou de trophées")
	local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	local a = string.find(main, "Lot 16 : boutique en 8 catégories", 1, true)
	local b = string.find(main, "---------------------------------------------------------------- Game Passes", 1, true)
	local blk = (a and b) and string.sub(main, a, b) or ""
	blk = blk:gsub("%-%-[^\n]*", "") -- commentaires retirés : seul le code compte
	check("Bloc lot 16 de Main : ni Battle.STATS, ni slot.x, ni bouclier (shield), ni trophées, ni défense écrits", #blk > 1000 and not blk:find("STATS", 1, true) and not blk:find("%.x%s*=") and not blk:find("shield", 1, true) and not blk:find("trophies", 1, true) and not blk:find("defense", 1, true))
	T.forb = {}
	for key, i in pairs(Info) do
		local all = string.lower(i.title .. " " .. i.def)
		if all:find("xp de pet", 1, true) or all:find("protection", 1, true) or all:find("trophée", 1, true) or all:find("+%d+ attaque") then
			T.forb[#T.forb + 1] = key
		end
	end
	check("Aucune fiche ne vend XP de pet, stats, protection ou trophées (" .. table.concat(T.forb, ",") .. ")", #T.forb == 0)
end

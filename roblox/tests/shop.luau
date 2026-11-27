--!nocheck
-- Tests du lot 16, partie boutique PURE (Shop, ShopData, ShopInfo). Forme : `return function(env) ... end`, env = { check, suite, luau, fs } (tests/run_shop.py).
-- Config : le VRAI Config.lua (Color3 simulé), puis ShopData.merge (ce que fera l'intégrateur). Variante « full » : 10 raretés publiées (espèces factices).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de math.random (Park-Miller 48271 mod 2^31-1).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name })()
	end
	local Shop = load("roblox/src/ReplicatedStorage/Shop.lua", "Shop")
	local Data = load("roblox/src/ReplicatedStorage/ShopData.lua", "ShopData")
	local Info = load("roblox/src/ReplicatedStorage/ShopInfo.lua", "ShopInfo")

	local function loadConfig(full)
		local chunk = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), {
			debugName = "Config",
			environment = { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } },
		})
		local C = chunk()
		if full then
			for t = 1, #C.TIERS do
				if not C.tierLive(t) then
					C.PETS[#C.PETS + 1] = { tier = t, emoji = "?", name = "Factice" .. t, inc = 1 }
				end
			end
		end
		Data.merge(C, Info)
		return C
	end
	local Real = loadConfig(false)
	local Full = loadConfig(true)

	local function keysOf(t)
		local out = {}
		for k in pairs(t) do
			out[#out + 1] = k
		end
		table.sort(out)
		return out
	end
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	local function has(s, w)
		return string.find(string.lower(s), string.lower(w), 1, true) ~= nil
	end
	local function newProfil(extra)
		local p = { coins = 0, income = 0, slots = {}, cap = 4, eggBag = {}, passes = {}, once = {}, season = { cur = 3 }, receipts = {} }
		for k, v in pairs(extra or {}) do
			p[k] = v
		end
		return p
	end
	local function rng(seed)
		local x = seed % 2147483647
		if x <= 0 then
			x = x + 2147483646
		end
		return function()
			x = (x * 48271) % 2147483647
			return x / 2147483647
		end
	end
	local function offerOf(list, key)
		for _, c in ipairs(list) do
			for _, o in ipairs(c.offers) do
				if o.key == key then
					return o, c.key
				end
			end
		end
		return nil
	end
	local function countKey(list, key)
		local n = 0
		for _, c in ipairs(list) do
			for _, o in ipairs(c.offers) do
				if o.key == key then
					n = n + 1
				end
			end
		end
		return n
	end

	------------------------------------------------------------ Fiches
	suite("Boutique pure : fiches (ShopInfo)")
	check("46 achats dans ShopData", count(Data.ENTRIES) == 46)
	check("une fiche par achat, pas une de plus", count(Info) == 46)
	local allFiche = true
	for k in pairs(Data.ENTRIES) do
		if not Info[k] then
			allFiche = false
		end
	end
	check("chaque achat de ShopData a sa fiche", allFiche)
	local LIMITS = { ["achat unique"] = true, ["aucune limite"] = true, ["achat unique par saison"] = true }
	local FIELDS = { "title", "def", "detail", "notDo", "chance", "limit", "icon", "cat" }
	local bad = {}
	for k, f in pairs(Info) do
		for _, fld in ipairs(FIELDS) do
			if type(f[fld]) ~= "string" or #f[fld] < 3 then
				bad[#bad + 1] = k .. "." .. fld
			end
		end
		if type(f.also) ~= "table" then
			bad[#bad + 1] = k .. ".also"
		end
		if utf8.len(f.title) > 28 then
			bad[#bad + 1] = k .. " titre > 28"
		end
		if utf8.len(f.def) > 90 then
			bad[#bad + 1] = k .. " définition > 90 (" .. utf8.len(f.def) .. ")"
		end
		if Real.ICONS[f.icon] == nil then
			bad[#bad + 1] = k .. " icône inconnue " .. tostring(f.icon)
		end
		if not LIMITS[f.limit] then
			bad[#bad + 1] = k .. " limite : " .. tostring(f.limit)
		end
		local e = Data.ENTRIES[k]
		if e and e.cat ~= f.cat then
			bad[#bad + 1] = k .. " catégorie différente ShopData / ShopInfo"
		end
		if e then
			local expect = (e.once or e.kind == "pass") and "achat unique" or (e.season and "achat unique par saison" or "aucune limite")
			if f.limit ~= expect then
				bad[#bad + 1] = k .. " limite incohérente avec ShopData : " .. f.limit
			end
		end
	end
	check("aucun champ vide, titres <= 28, définitions <= 90, icônes réelles, limites cohérentes : " .. table.concat(bad, " | "), #bad == 0)

	local ANY = { "plafond", "limite d'achat", "limite d’achat", "limite par jour", "limite quotidienne", "plus fort", "plus forts", "plus puissant", "invincible", "imbattable", "à coup sûr", "tu vas obtenir", "tu obtiendras", "dernière chance", "stock limité", "offre limitée", "protège totalement", "gagnant" }
	local NOTDO_OK_ONLY = { "force", "garanti" } -- promesses : permises seulement dans « ne fait PAS » (négation)
	local found = {}
	for k, f in pairs(Info) do
		for _, fld in ipairs({ "title", "def", "detail", "chance", "notDo", "limit" }) do
			for _, w in ipairs(ANY) do
				if has(f[fld], w) then
					found[#found + 1] = k .. "." .. fld .. " : " .. w
				end
			end
		end
		for _, fld in ipairs({ "title", "def", "detail", "chance", "limit" }) do
			for _, w in ipairs(NOTDO_OK_ONLY) do
				if has(f[fld], w) then
					found[#found + 1] = k .. "." .. fld .. " : " .. w
				end
			end
		end
		-- « ne fait PAS » doit être une négation
		if not (has(f.notDo, "ne ") or has(f.notDo, "n'") or has(f.notDo, "aucun")) then
			found[#found + 1] = k .. ".notDo n'est pas une négation"
		end
	end
	check("aucun mot « plafond / limite d'achat », aucune promesse de force, de gain ou de protection : " .. table.concat(found, " | "), #found == 0)

	local alsoOk = true
	for k, f in pairs(Info) do
		for _, c in ipairs(f.also) do
			if Shop.categoryTitle(c) == nil or c == f.cat then
				alsoOk = false
			end
		end
	end
	check("« voir aussi » pointe vers une autre catégorie existante", alsoOk)
	local rb = Info.EggR2.detail .. Info.EggSecret.detail
	check("les fiches d'œufs annoncent le refus AVANT paiement et le coffre de débordement", has(rb, "avant paiement") and has(rb, "débordement"))
	check("Double chance : 70 points annoncés sans le mot plafond", has(Info.DoubleLuck.detail, "70 points") and not has(Info.DoubleLuck.detail, "plafond"))

	------------------------------------------------------------ Données (ids, prix)
	suite("Boutique pure : ids et prix (ShopData)")
	local EXPECT = {
		CoinPackS = { 3736703557, 19 }, EggR2 = { 3736703563, 15 }, EggR3 = { 3736703571, 25 }, LuckPotionMini = { 3736703579, 29 }, EggR4 = { 3736703588, 49 },
		ArenaTickets = { 3736703606, 19 }, StreakRestore = { 3736703610, 29 }, EmoteVictory1 = { 3736703619, 39 }, EmoteVictory2 = { 3736703629, 39 },
		EmoteVictory3 = { 3736703634, 39 }, EmoteVictory4 = { 3736703641, 39 }, EmoteVictory5 = { 3736703649, 39 }, EmoteVictory6 = { 3736703657, 39 },
		EggR5 = { 3736703667, 99 }, DoubleLuck = { 3736703673, 149 }, SeasonPremium = { 3736703683, 399 }, SeasonPremiumPlus = { 3736703689, 799 },
		EggR7 = { 3736703695, 799 }, BundleLegend = { 3736703706, 999 }, BundleRoyal = { 3736703714, 1499 }, SeasonUpgradePlus = { 3736704000, 400 },
		BundleRoyalNoPass = { 3736704205, 1100 }, EggBagPlus = { 2099454839, 149 }, Collector = { 2099556764, 249 }, Lucky2 = { 2102045961, 349 },
		CalendarCatchup = { 3736695392, 29 }, EggSecret = { 3736452048, 1499 }, EggExclusive = { 3736452061, 3499 }, EggDivine = { 3736452072, 6999 },
	}
	local badId = {}
	for k, e in pairs(EXPECT) do
		local d = Data.ENTRIES[k]
		if not d or d.id ~= e[1] or d.robux ~= e[2] then
			badId[#badId + 1] = k
		end
	end
	check("ids et prix de la liste de la gestion : " .. table.concat(badId, ","), #badId == 0)
	local seen, dup, zero = {}, 0, 0
	for _, d in pairs(Data.ENTRIES) do
		if seen[d.id] then
			dup = dup + 1
		end
		seen[d.id] = true
		if type(d.id) ~= "number" or d.id <= 0 then
			zero = zero + 1
		end
	end
	check("aucun id à 0, aucun id en double", dup == 0 and zero == 0)
	check("complément de saison : 399 + 400 = 799", Data.ENTRIES.SeasonPremium.robux + Data.ENTRIES.SeasonUpgradePlus.robux == Data.ENTRIES.SeasonPremiumPlus.robux)
	check("complément du coffre : 399 + 1 100 = 1 499", Data.ENTRIES.SeasonPremium.robux + Data.ENTRIES.BundleRoyalNoPass.robux == Data.ENTRIES.BundleRoyal.robux)
	check("merge : StreakRestore a son id réel dans Config.PRODUCTS", Real.PRODUCTS.StreakRestore.id == 3736703610 and Real.PASSES.Lucky2.id == 2102045961)
	check("merge : champs d'origine conservés (nom, description)", Real.PRODUCTS.CoinPack.name == "Sac de pièces" and type(Real.PRODUCTS.EggR3.name) == "string")
	local again = loadConfig(false)
	Data.merge(again, Info)
	check("merge idempotent", again.PRODUCTS.EggR3.id == Real.PRODUCTS.EggR3.id and again.PRODUCTS.EggR3.robux == 25)
	check("passes : permanents, une seule fois", Data.ENTRIES.Lucky.kind == "pass" and Data.ENTRIES.Lucky.once == true and Data.ENTRIES.EmoteVictory3.once == true and Data.ENTRIES.StarterPack.once == true)
	local capField = false
	for _, d in pairs(Data.ENTRIES) do
		if d.buys ~= nil or d.cap ~= nil or d.daily ~= nil or d.weekly ~= nil or d.monthly ~= nil then
			capField = true
		end
	end
	check("aucun champ de plafond d'achat (jour / semaine / mois) dans les données", not capField)

	------------------------------------------------------------ Catégories et tri
	suite("Boutique pure : catégories, tri, passes et consommables")
	local names = {}
	for _, c in ipairs(Shop.CATEGORIES) do
		names[#names + 1] = c.title
	end
	check("ordre imposé des catégories", table.concat(names, "|") == "Œufs|Chance & boosts|Pièces|Base & confort|Combat & vol|Passe de combat|Packs|Cosmétiques")
	local cat = Shop.catalog(Full)
	check("catalogue : 46 achats", #cat == 46)
	local list = Shop.visibleOffers(newProfil(), Full, false, Info)
	check("8 catégories rendues", #list == 8)
	local once, total = true, 0
	for k in pairs(Data.ENTRIES) do
		local want = (k == "SeasonUpgradePlus" or k == "BundleRoyalNoPass") and 0 or 1 -- compléments : visibles seulement avec le premium
		if countKey(list, k) ~= want then
			once = false
		end
		total = total + 1
	end
	check("chaque achat dans EXACTEMENT une catégorie (profil neuf, tout autorisé ; compléments cachés)", once and total == 46)
	local rightCat = true
	for k, d in pairs(Data.ENTRIES) do
		local o, c = offerOf(list, k)
		if o and (c ~= d.cat or c ~= Info[k].cat) then
			rightCat = false
		end
	end
	check("catégorie rendue = catégorie des données", rightCat)
	local sorted = true
	for _, c in ipairs(list) do
		for i = 2, #c.offers do
			if c.offers[i - 1].price > c.offers[i].price then
				sorted = false
			end
		end
	end
	check("tri par prix croissant dans chaque catégorie", sorted)
	local eggsCat = list[1].offers
	check("Œufs : 15, 25, 49, 99, 249, 799, 1 499, 3 499, 6 999", #eggsCat == 9 and eggsCat[1].key == "EggR2" and eggsCat[9].key == "EggDivine" and eggsCat[6].price == 799)
	local perm = true
	for _, c in ipairs(list) do
		for _, o in ipairs(c.offers) do
			local d = Data.ENTRIES[o.key]
			if o.permanent ~= (d.kind == "pass" or d.once == true) then
				perm = false
			end
		end
	end
	check("passes permanents / consommables distingués", perm)
	local sea = list[6].offers
	check("Passe de combat : 399, 400 (si premium seulement)... profil neuf : 399, 799", #sea == 2 and sea[1].key == "SeasonPremium" and sea[2].key == "SeasonPremiumPlus")
	local seeAlso = offerOf(list, "BundleRoyal")
	check("renvoi « voir aussi » présent", #seeAlso.seeAlso == 2)
	local noId = loadConfig(true)
	for _, d in pairs(noId.PRODUCTS) do
		if d.cat then
			d.id = 0
		end
	end
	for _, d in pairs(noId.PASSES) do
		if d.cat then
			d.id = 0
		end
	end
	local emptyList = Shop.visibleOffers(newProfil(), noId, false, Info)
	local none = true
	for _, c in ipairs(emptyList) do
		if #c.offers > 0 then
			none = false
		end
	end
	check("id absent (0) : aucune offre affichée", none)

	------------------------------------------------------------ Possession et mises à niveau
	suite("Boutique pure : possession, mise à niveau, aucun double paiement")
	local function state(profil)
		return Shop.visibleOffers(profil, Full, false, Info)
	end
	local function show(list2, key)
		local o = offerOf(list2, key)
		if not o then
			return "absent"
		end
		return o.owned and "possédé" or tostring(o.price)
	end
	local function row(profil)
		local l = state(profil)
		return table.concat({ show(l, "SeasonPremium"), show(l, "SeasonUpgradePlus"), show(l, "SeasonPremiumPlus"), show(l, "BundleRoyal"), show(l, "BundleRoyalNoPass") }, "|")
	end
	check("rien : 399 | absent | 799 | 1499 | absent", row(newProfil()) == "399|absent|799|1499|absent")
	check("premium : possédé | 400 | absent | absent | 1100", row(newProfil({ season = { cur = 3, premium = 3 } })) == "possédé|400|absent|absent|1100")
	check("premium + : possédé | possédé | absent | absent | 1100", row(newProfil({ season = { cur = 3, premium = 3, plus = 3 } })) == "possédé|possédé|absent|absent|1100")
	local royal = newProfil({ cap = 10 })
	Shop.grant(royal, "BundleRoyal", "r1", Full)
	check("coffre royal acheté : le passe premium est possédé", Shop.hasPremium(royal) and not Shop.hasPlus(royal))
	check("après le coffre : possédé | 400 | absent | absent | 1100", row(royal) == "possédé|400|absent|absent|1100")
	check("nouvelle saison : tout redevient achetable une fois", row(newProfil({ season = { cur = 4, premium = 3, plus = 3 } })) == "399|absent|799|1499|absent")
	local prem = newProfil({ season = { cur = 3, premium = 3 } })
	local none2 = newProfil()
	check("priceFor : complément 400 pour qui a le premium", Shop.priceFor(prem, { key = "SeasonUpgradePlus", price = 400 }) == 400)
	check("priceFor : complément refusé sans premium", Shop.priceFor(none2, { key = "SeasonUpgradePlus", price = 400 }) == nil)
	check("priceFor : 799 refusé si premium possédé", Shop.priceFor(prem, { key = "SeasonPremiumPlus", price = 799 }) == nil and Shop.priceFor(none2, { key = "SeasonPremiumPlus", price = 799 }) == 799)
	check("priceFor : coffre 1 499 sans premium, 1 100 avec", Shop.priceFor(none2, { key = "BundleRoyal", price = 1499 }) == 1499 and Shop.priceFor(prem, { key = "BundleRoyalNoPass", price = 1100 }) == 1100)
	check("priceFor : entrée invalide", Shop.priceFor(none2, nil) == nil and Shop.priceFor(none2, {}) == nil)
	local ok1, why1 = Shop.canBuy(prem, Full, "SeasonPremiumPlus", false)
	local ok2, why2 = Shop.canBuy(none2, Full, "SeasonUpgradePlus", false)
	local ok3, why3 = Shop.canBuy(prem, Full, "BundleRoyal", false)
	local ok4, why4 = Shop.canBuy(none2, Full, "BundleRoyalNoPass", false)
	local ok5, why5 = Shop.canBuy(prem, Full, "SeasonPremium", false)
	check("canBuy refuse les doublons et compléments sans palier", not ok1 and not ok2 and not ok3 and not ok4 and not ok5 and why5 == "owned" and why2 == "needPremium" and why4 == "needPremium" and why1 == "hasPremium" and why3 == "hasPremium")
	local ok6, _, p6 = Shop.canBuy(prem, Full, "SeasonUpgradePlus", false)
	check("canBuy accepte le complément à 400", ok6 and p6 == 400)
	-- chemins d'achat : pas de double paiement, toujours le même total
	local pathA = Data.ENTRIES.SeasonPremiumPlus.robux
	local pathB = Data.ENTRIES.SeasonPremium.robux + Data.ENTRIES.SeasonUpgradePlus.robux
	check("deux chemins vers le premium + : même total (799)", pathA == pathB and pathA == 799)
	-- passes et achats uniques possédés
	local owned = newProfil({ passes = { Lucky = true, EggBagPlus = true }, once = { StarterPack = true, EmoteVictory2 = true } })
	local lo = state(owned)
	check("passes et achats uniques possédés : « Possédé »", show(lo, "Lucky") == "possédé" and show(lo, "EggBagPlus") == "possédé" and show(lo, "StarterPack") == "possédé" and show(lo, "EmoteVictory2") == "possédé" and show(lo, "EmoteVictory1") == "39")
	local okL, whyL = Shop.canBuy(owned, Full, "Lucky", false)
	check("canBuy refuse un passe déjà possédé", not okL and whyL == "owned")
	check("produit consommable jamais « possédé »", show(lo, "CoinPack") == "99" and show(lo, "LuckPotion") == "99")
	local ok7 = Shop.canBuy(newProfil(), Full, "Inconnu", false)
	check("clé inconnue refusée", not ok7)
	check("libellé Possédé", offerOf(lo, "Lucky").label == "Possédé")

	------------------------------------------------------------ PolicyService et espèces publiées
	suite("Boutique pure : PolicyService et raretés publiées")
	local function randomVisible(l)
		local n = 0
		for _, c in ipairs(l) do
			for _, o in ipairs(c.offers) do
				if o.random then
					n = n + 1
				end
			end
		end
		return n
	end
	check("restreint (true) : aucune offre aléatoire", randomVisible(Shop.visibleOffers(newProfil(), Full, true, Info)) == 0)
	check("PolicyService en échec (nil) : repli prudent, aucune offre aléatoire", randomVisible(Shop.visibleOffers(newProfil(), Full, nil, Info)) == 0)
	check("autorisé (false) : offres aléatoires visibles", randomVisible(Shop.visibleOffers(newProfil(), Full, false, Info)) >= 20)
	local restrictedList = Shop.visibleOffers(newProfil(), Full, true, Info)
	check("restreint : œufs masqués, pièces et poses restent", #restrictedList[1].offers == 0 and offerOf(restrictedList, "CoinPack") ~= nil and offerOf(restrictedList, "EmoteVictory1") ~= nil)
	local okP, whyP = Shop.canBuy(newProfil(), Full, "EggSecret", true)
	check("canBuy refuse un œuf aléatoire si restreint", not okP and whyP == "policy")
	local okQ, whyQ = Shop.canBuy(newProfil(), Full, "EggSecret", nil)
	check("canBuy refuse si l'appel PolicyService a échoué", not okQ and whyQ == "policy")
	local realList = Shop.visibleOffers(newProfil(), Real, false, Info)
	check("Secret / Exclusif / Divin / Peu commun masqués tant qu'aucune espèce n'est publiée", offerOf(realList, "EggSecret") == nil and offerOf(realList, "EggExclusive") == nil and offerOf(realList, "EggDivine") == nil and offerOf(realList, "EggR2") == nil)
	check("œufs des raretés publiées visibles (Rare, Épique, Légendaire, Mythique, Ultra Rare)", offerOf(realList, "EggR3") ~= nil and offerOf(realList, "EggR4") ~= nil and offerOf(realList, "EggR5") ~= nil and offerOf(realList, "ExclusiveEgg") ~= nil and offerOf(realList, "EggR7") ~= nil)
	local okR, whyR = Shop.canBuy(newProfil(), Real, "EggDivine", false)
	check("canBuy refuse un œuf dont la rareté n'a pas d'espèce", not okR and whyR == "notLive")
	local okS = Shop.canBuy(newProfil(), Full, "EggDivine", false)
	check("canBuy accepte le Divin quand les espèces existent", okS)

	------------------------------------------------------------ Place avant paiement, débordement
	suite("Boutique pure : place avant paiement et débordement")
	local fullP = newProfil({ cap = 4, slots = { { k = "e", t = 1 }, { k = "e", t = 1 }, { k = "e", t = 1 }, { k = "e", t = 1 } } })
	for i = 1, Full.EGG_BAG.size do
		fullP.eggBag[i] = 1
	end
	local canE, whyE, msgE = Shop.canBuyEgg(fullP, Full)
	check("base + sac pleins : refus avant paiement avec message", not canE and whyE == "faisDeLaPlace" and has(msgE, "fais de la place"))
	local okF, whyF = Shop.canBuy(fullP, Full, "EggR3", false)
	check("canBuy œuf refusé si tout est plein", not okF and whyF == "faisDeLaPlace")
	local okG = Shop.canBuy(fullP, Full, "BundleRoyal", false)
	check("canBuy coffre (œufs) refusé si tout est plein", not okG)
	local okH = Shop.canBuy(fullP, Full, "CoinPack", false)
	check("un achat sans œuf reste possible base pleine", okH)
	fullP.eggBag[#fullP.eggBag] = nil
	check("une place libre dans le sac suffit", Shop.canBuyEgg(fullP, Full) == true and Shop.canBuy(fullP, Full, "EggR3", false))
	local half = newProfil({ cap = 4, slots = { { k = "e", t = 1 }, false, nil, { k = "e", t = 1 } } })
	check("emplacement false / nil = libre", Shop.canBuyEgg(half, Full, 2) == true and Shop.canBuyEgg(half, Full, 12) == true and Shop.canBuyEgg(half, Full, 13) == false)
	check("profil invalide : refus sûr", Shop.canBuyEgg(nil, Full) == false)
	-- course : payé alors que tout est plein
	local race = newProfil({ cap = 1, slots = { { k = "e", t = 1 } } })
	for i = 1, Full.EGG_BAG.size do
		race.eggBag[i] = 2
	end
	local g = Shop.grant(race, "EggR4", "race1", Full)
	check("course après paiement : l'œuf va au débordement, rien n'est perdu", g.ok and g.delta.placed.overflow == 1 and Shop.overflowCount(race) == 1 and race.overflow["4"] == 1)
	local pack = newProfil({ cap = 1 })
	local gp = Shop.grant(pack, "BundleRoyal", "pk1", Full)
	local placed = gp.delta.placed
	check("coffre de 5 œufs : 1 base + 10 sac max, le reste en débordement, total 5", placed.slot + placed.bag + placed.overflow == 5 and placed.slot == 1 and placed.bag == 4)
	local pack2 = newProfil({ cap = 0 })
	for i = 1, Full.EGG_BAG.size - 1 do
		pack2.eggBag[i] = 1
	end
	local gp2 = Shop.grant(pack2, "BundleRoyal", "pk2", Full)
	check("sac presque plein : 1 au sac, 4 au débordement", gp2.delta.placed.bag == 1 and gp2.delta.placed.overflow == 4 and Shop.overflowCount(pack2) == 4)
	check("overflowAdd valide ses entrées", Shop.overflowAdd(pack2, "x", 1) == false and Shop.overflowAdd(pack2, 0, 1) == false and Shop.overflowAdd(pack2, 3, 2) == true and pack2.overflow["3"] == 2)

	------------------------------------------------------------ Reçus
	suite("Boutique pure : reçus (un crédit par reçu)")
	local p = newProfil({ cap = 20, income = 10 })
	local first = Shop.grant(p, "CoinPack", "rid-1", Full)
	check("premier reçu crédité (20 min de revenu, minimum 5 000)", first.ok and not first.dup and first.delta.coins == 12000 and p.coins == 12000)
	local replays = 0
	for _ = 1, 10000 do
		local r = Shop.grant(p, "CoinPack", "rid-1", Full)
		if r.ok and r.dup then
			replays = replays + 1
		end
	end
	check("10 000 reçus rejoués = 1 seul crédit", replays == 10000 and p.coins == 12000)
	local pe = newProfil({ cap = 20 })
	for _ = 1, 10000 do
		Shop.grant(pe, "EggR4", 987654, Full)
	end
	local eggs = 0
	for _, s in pairs(pe.slots) do
		if s then
			eggs = eggs + 1
		end
	end
	check("10 000 reçus rejoués d'un œuf = 1 œuf (reçu numérique)", eggs == 1 and #pe.eggBag == 0 and Shop.overflowCount(pe) == 0)
	local second = Shop.grant(p, "CoinPack", "rid-2", Full)
	check("deux reçus distincts = deux crédits", second.ok and not second.dup and p.coins == 24000)
	local bad1 = Shop.grant(p, "CoinPack", nil, Full)
	local bad2 = Shop.grant(p, "CoinPack", "", Full)
	local bad3 = Shop.grant(p, "Inconnu", "z", Full)
	local bad4 = Shop.grant(nil, "CoinPack", "z", Full)
	check("reçu invalide / produit inconnu / profil nul : refus sans crédit", not bad1.ok and not bad2.ok and not bad3.ok and not bad4.ok and p.coins == 24000)
	local small = Shop.grant(newProfil(), "CoinPackS", "s1", Full)
	check("petit sac : minimum 1 000 pièces", small.delta.coins == 1000)
	local pi = newProfil({ income = 100 })
	check("petit sac : 5 min de revenu", Shop.grant(pi, "CoinPackS", "s2", Full).delta.coins == 30000)
	local ex = Shop.grant(newProfil(), "ExclusiveEgg", "x1", Full)
	check("œuf Mythique : un seul œuf de rareté 6", #ex.delta.eggs == 1 and ex.delta.eggs[1] == 6)
	local st = newProfil({ cap = 10 })
	local sp = Shop.grant(st, "StarterPack", "st1", Full)
	check("Pack de départ : 20 000 pièces, 3 œufs Rares, potion de chance", st.coins == 20000 and #sp.delta.eggs == 3 and sp.delta.eggs[1] == 3 and sp.delta.luck.seconds == 900 and st.once.StarterPack == true)
	local sp2 = Shop.grant(st, "StarterPack", "st2", Full)
	check("Pack de départ payé deux fois (course) : un seul octroi + compensation en pièces", st.coins == 20000 + sp2.delta.compensation.coins and sp2.delta.eggs == nil and sp2.delta.compensation.coins >= 5000 and #st.slots == 3)
	local em = newProfil()
	local e1 = Shop.grant(em, "EmoteVictory3", "e1", Full)
	local e2 = Shop.grant(em, "EmoteVictory3", "e2", Full)
	check("pose de victoire : une fois, la seconde est compensée", e1.delta.once == true and e2.delta.once == nil and e2.delta.compensation ~= nil and em.once.EmoteVictory3 == true)
	local sx = newProfil({ cap = 4 })
	Shop.grant(sx, "SeasonPremium", "sp1", Full)
	local sy = Shop.grant(sx, "SeasonPremium", "sp2", Full)
	check("premium payé deux fois : un seul premium, compensation 399", Shop.hasPremium(sx) and sy.delta.premium == nil and sy.delta.compensation.robux == 399)
	local sz = Shop.grant(sx, "SeasonUpgradePlus", "up1", Full)
	check("complément : +10 paliers, plus possédé", sz.delta.plus and sz.delta.bonusTiers == 10 and Shop.hasPlus(sx) and sx.season.bonusTiers == 10)
	local sw = Shop.grant(sx, "SeasonUpgradePlus", "up2", Full)
	check("complément payé deux fois : pas de paliers en plus", sx.season.bonusTiers == 10 and sw.delta.compensation.robux == 400)
	local sv = Shop.grant(sx, "SeasonPremiumPlus", "pp1", Full)
	check("799 payé avec le passe plus déjà possédé : compensation", sx.season.bonusTiers == 10 and sv.delta.compensation.robux == 799)
	local prem2 = newProfil({ season = { cur = 3, premium = 3 } })
	local pp = Shop.grant(prem2, "SeasonPremiumPlus", "pp2", Full)
	check("799 payé avec le premium déjà possédé (course) : 10 paliers + compensation de 399", pp.delta.bonusTiers == 10 and pp.delta.compensation.robux == 399)
	local fresh = newProfil({ cap = 10 })
	local sn = Shop.grant(fresh, "SeasonPremiumPlus", "pp3", Full)
	check("799 sans rien : premium + 10 paliers, les paliers atteints crédités une seule fois (creditReached)", sn.delta.premium and sn.delta.plus and sn.delta.creditReached and fresh.season.bonusTiers == 10)
	local nop = newProfil({ cap = 10 })
	local np = Shop.grant(nop, "BundleRoyalNoPass", "np1", Full)
	check("coffre sans passe payé sans premium (course) : œufs + premium offert", np.delta.upgradedFromRace and Shop.hasPremium(nop) and #np.delta.eggs == 5)
	local rp = newProfil({ cap = 10, season = { cur = 3, premium = 3 } })
	local rg = Shop.grant(rp, "BundleRoyal", "rg1", Full)
	check("coffre royal payé avec le premium déjà possédé : œufs + compensation de 399", #rg.delta.eggs == 5 and rg.delta.premium == nil and rg.delta.compensation.robux == 399)
	local lg = newProfil({ cap = 10 })
	local bl = Shop.grant(lg, "BundleLegend", "bl1", Full)
	check("Pack Légende : 1 Ultra Rare + 3 Légendaires + Double chance 60 min", #bl.delta.eggs == 4 and bl.delta.eggs[1] == 7 and bl.delta.eggs[2] == 5 and bl.delta.doubleSeconds == 3600 and lg.timers.double == 3600)
	Shop.grant(lg, "BundleLegend", "bl2", Full)
	check("durées de Double chance cumulables sans limite", lg.timers.double == 7200)
	local tk = newProfil()
	Shop.grant(tk, "ArenaTickets", "t1", Full)
	Shop.grant(tk, "ArenaTickets", "t2", Full)
	Shop.grant(tk, "RemoteStealPack", "t3", Full)
	Shop.grant(tk, "RemoteSteal", "t4", Full)
	Shop.grant(tk, "StreakRestore", "t5", Full)
	Shop.grant(tk, "CalendarCatchup", "t6", Full)
	check("jetons : 10 combats de tour, 4 corbeaux, 1 sauvetage, 1 rattrapage (sans limite d'achat)", tk.tokens.arena == 10 and tk.tokens.raven == 4 and tk.tokens.streak == 1 and tk.tokens.catchup == 1)
	local gl = Shop.grant(newProfil(), "GoldenBelt", "g1", Full)
	local sl = Shop.grant(newProfil(), "ServerLuck", "g2", Full)
	check("effets serveur : tapis doré 10 min, pluie de chance +5 pendant 10 min", gl.delta.server.beltSeconds == 600 and sl.delta.server.luckPoints == 5 and sl.delta.server.seconds == 600)
	check("passe permanent : pose idempotente", Shop.grantPass(tk, "Lucky") == true and Shop.grantPass(tk, "Lucky") == false and tk.passes.Lucky == true and Shop.owned(tk, "Lucky"))
	-- Achats sans plafond : 50 achats distincts d'un même œuf sont tous crédités
	local many = newProfil({ cap = 4 })
	local credited = 0
	for i = 1, 50 do
		local r = Shop.grant(many, "EggR3", "m" .. i, Full)
		if r.ok and not r.dup then
			credited = credited + 1
		end
	end
	check("aucun plafond d'achat : 50 œufs Rares achetés = 50 crédits (4 base, 10 sac, 36 débordement)", credited == 50 and Shop.overflowCount(many) == 36 and #many.eggBag == 10)

	------------------------------------------------------------ Double chance et neutralité
	suite("Boutique pure : Double chance <= 70, aucun avantage de combat")
	check("Double chance : 5 -> 10, 15 -> 30", Shop.doubleLuckCap(5) == 10 and Shop.doubleLuckCap(15) == 30)
	check("Double chance : 35 -> 70, 40 -> 70, 1000 -> 70", Shop.doubleLuckCap(35) == 70 and Shop.doubleLuckCap(40) == 70 and Shop.doubleLuckCap(1000) == 70)
	check("Double chance : entrées invalides = 0", Shop.doubleLuckCap(-5) == 0 and Shop.doubleLuckCap(nil) == 0 and Shop.doubleLuckCap(0 / 0) == 0 and Shop.doubleLuckCap("9") == 0)
	local r1 = rng(12345)
	local over = 0
	for _ = 1, 5000 do
		local pts = r1() * 200
		if Shop.luckTotal(pts, true) > 70 or Shop.luckTotal(pts, false) > 70 or Shop.doubleLuckCap(pts) > 70 then
			over = over + 1
		end
	end
	check("5 000 tirages de points : jamais au-dessus de 70", over == 0 and Shop.DOUBLE_LUCK_CAP == 70 and Full.UPGRADE.maxUp == 70)
	local dl = Shop.grant(newProfil(), "DoubleLuck", "d1", Full)
	check("reçu Double chance : 30 min, plafond 70 inscrit dans le delta", dl.delta.doubleSeconds == 1800 and dl.delta.doubleCap == 70)
	local ALLOWED = { key = 1, coins = 1, eggs = 1, placed = 1, luck = 1, doubleSeconds = 1, doubleCap = 1, server = 1, tokens = 1, instantHatch = 1, revive = 1, premium = 1, creditReached = 1, plus = 1, bonusTiers = 1, upgradedFromRace = 1, once = 1, compensation = 1 }
	local leak = {}
	for k in pairs(Data.ENTRIES) do
		local pr = newProfil({ cap = 30, income = 5 })
		if k == "BundleRoyalNoPass" then
			pr.season = { cur = 3, premium = 3 }
		end
		local r = Shop.grant(pr, k, "leak-" .. k, Full)
		if r.ok and r.delta then
			for f in pairs(r.delta) do
				if not ALLOWED[f] then
					leak[#leak + 1] = k .. "." .. f
				end
			end
			if r.delta.stats or r.delta.xp or r.delta.shield or r.delta.battle then
				leak[#leak + 1] = k .. " touche au combat"
			end
		end
	end
	check("aucun reçu ne touche stats, XP de pet, bouclier ni combat : " .. table.concat(leak, ","), #leak == 0)
	local noEffect = {}
	for k in pairs(Data.ENTRIES) do
		if Data.ENTRIES[k].kind == "product" and Shop.EFFECTS[k] == nil then
			noEffect[#noEffect + 1] = k
		end
	end
	check("chaque produit a un effet de reçu : " .. table.concat(noEffect, ","), #noEffect == 0)

	------------------------------------------------------------ Table de probabilités
	suite("Boutique pure : texte des probabilités")
	local t3 = Shop.eggContentText(Full, "EggR3")
	check("œuf Rare : rareté fixe et table de contenu de Config", has(t3, "rareté fixe rare") and has(t3, Full.eggContentText(3, Full.UPGRADE.base)))
	check("tailles et mutations affichées depuis Config", has(t3, "mini 20 %") and has(t3, "géant 3,5 %") and has(t3, "colossal 0,5 %") and has(t3, "aucune 81,9 %") and has(t3, "céleste 0,1 %") and has(t3, "arc-en-ciel 2,6 %"))
	local n7 = 0
	for _, pet in ipairs(Full.PETS) do
		if pet.tier == 7 then
			n7 = n7 + 1
		end
	end
	local t7 = Shop.eggContentText(Full, "EggR7")
	check("Ultra Rare : 100 % fixe, nombre d'espèces affiché", has(t7, "100%") and has(t7, n7 .. " espèces possibles"))
	local t8 = Shop.eggContentText(Full, "EggSecret")
	check("Secret : rareté fixe affichée, aucune amélioration", has(t8, "rareté fixe secret") and has(t8, "secret : 100% secret"))
	check("Exclusif : espèce de l'événement affichée", has(Shop.eggContentText(Full, "EggExclusive"), "événement"))
	local tb = Shop.eggContentText(Full, "BundleRoyal")
	check("Coffre royal : 2 Ultra Rares et 3 Mythiques détaillés", has(tb, "2 x Œuf Ultra Rare") and has(tb, "3 x Œuf Mythique"))
	check("achat sans œuf : pas de table d'œuf", Shop.eggContentText(Full, "CoinPack") == "" and Shop.eggContentText(Full, "Inconnu") == "")
	check("points d'amélioration du joueur pris en compte", has(Shop.eggContentText(Full, "EggR3", 30), Full.eggContentText(3, 30)))
	local cardsOk, cardBad = true, {}
	for k in pairs(Data.ENTRIES) do
		local c = Shop.card(Full, Info, newProfil(), k, false)
		if not c or c.title == "" or c.def == "" or c.detail == "" or c.notDo == "" or type(c.price) ~= "number" then
			cardsOk = false
			cardBad[#cardBad + 1] = k
		elseif Data.ENTRIES[k].random and #Shop.eggsOf(k) > 0 and c.odds == "" then
			cardsOk = false
			cardBad[#cardBad + 1] = k .. " sans probabilités"
		end
	end
	check("fiche d'écran complète pour les 46 achats, probabilités pour les œufs : " .. table.concat(cardBad, ","), cardsOk)
	local cs = Shop.card(Full, Info, newProfil({ season = { cur = 3, premium = 3 } }), "SeasonUpgradePlus", false)
	check("fiche du complément : prix 400", cs.price == 400 and cs.state == "buy")
	check("fiche : « Possédé »", Shop.card(Full, Info, newProfil({ passes = { Lucky = true } }), "Lucky", false).label == "Possédé")
	check("fiche inconnue : nil", Shop.card(Full, Info, newProfil(), "Zzz", false) == nil)

	------------------------------------------------------------ Simulation aléatoire
	suite("Boutique pure : 3 000 opérations aléatoires, invariants")
	local rr = rng(2026)
	local sim = newProfil({ cap = 6, income = 3 })
	local keys = keysOf(Data.ENTRIES)
	local unique, eggsGranted, coinsMin = {}, 0, 0
	local broke = false
	local rids = {}
	for i = 1, 3000 do
		local key = keys[math.floor(rr() * #keys) + 1]
		local rid = "sim-" .. math.floor(rr() * 600)
		if Data.ENTRIES[key].kind == "product" then
			local before = sim.coins
			local ok = true
			local fresh2 = not sim.receipts[rid]
			local g2 = Shop.grant(sim, key, rid, Full)
			if g2.ok and not g2.dup then
				unique[rid] = true
				eggsGranted = eggsGranted + (g2.delta.eggs and #g2.delta.eggs or 0)
			end
			if g2.ok and g2.dup and fresh2 then
				broke = true
			end
			if sim.coins < before then
				broke = true
			end
		end
		rids[#rids + 1] = rid
	end
	local stored = 0
	for _, s in pairs(sim.slots) do
		if s then
			stored = stored + 1
		end
	end
	stored = stored + #sim.eggBag + Shop.overflowCount(sim)
	check("un reçu = un crédit : nombre de reçus mémorisés = reçus distincts crédités", count(sim.receipts) == count(unique) and not broke)
	check("aucun œuf perdu : base + sac + débordement = œufs octroyés", stored == eggsGranted)
	check("pièces jamais négatives, base <= cap, sac <= taille", sim.coins >= 0 and #sim.eggBag <= Full.EGG_BAG.size)
end

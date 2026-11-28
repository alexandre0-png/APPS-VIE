--!nocheck
-- Tests du lot 16 : offres contextuelles (OffersData, Offers : logique pure).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } fournis par tests/run_offers.py (ou par run.luau une fois branché).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, aucun hasard.
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name, environment = RT.env })()
	end
	local D = load("roblox/src/ReplicatedStorage/OffersData.lua", "OffersData")
	local Offers = load("roblox/src/ReplicatedStorage/Offers.lua", "Offers")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config")

	-- Config de test : produits et passes réels + les achats du lot 16 (ids factices), tous visibles.
	local function copy(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	local function testConfig(mut)
		local C = copy(Config)
		C.PRODUCTS, C.PASSES = copy(Config.PRODUCTS), copy(Config.PASSES)
		C.tierLive = function(t) -- espèces du lot 11 supposées publiées jusqu'à Ultra Rare ; Secret, Exclusif, Divin masqués
			return type(t) == "number" and t <= 7
		end
		local function add(key, price, tier, random)
			C.PRODUCTS[key] = { id = 100 + price, robux = price, name = key, eggTier = tier, random = random }
		end
		add("EggR2", 15, 2, true)
		add("EggR3", 25, 3, true)
		add("EggR4", 49, 4, true)
		add("EggR5", 99, 5, true)
		C.PRODUCTS.DoubleLuck = { id = 3736703673, robux = 149, name = "Double chance", random = true }
		C.PRODUCTS.StreakRestore = { id = 3736703610, robux = 29, name = "Sauvetage" }
		C.PRODUCTS.ArenaTickets = { id = 3736703606, robux = 19, name = "Ticket" }
		if mut then
			mut(C)
		end
		return C
	end
	local C = testConfig()
	local function ctx(extra)
		local c = { data = D, Config = C, restricted = false, calm = false }
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	local function profil(extra)
		local p = { owned = {}, passes = {}, dayNumber = 10, bestTier = 3, hatchedTotal = 20 }
		for k, v in pairs(extra or {}) do
			p[k] = v
		end
		return p
	end
	local T0 = 1000
	local function state()
		return Offers.newState(T0)
	end
	local NOW = T0 + 600
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end

	suite("Offres : déclencheurs")
	check("Config réel : TIERS à 10 raretés et OFFERS 3 / 300 s", #Config.TIERS == 10 and Config.OFFERS.max == 3 and Config.OFFERS.gap == 300)
	local o = Offers.pick(state(), profil(), NOW, ctx({ baseFull = true }))
	check("Base pleine : +4 emplacements (passe ExtraSlots)", o ~= nil and o.key == "ExtraSlots" and o.kind == "pass" and o.id == "baseFull")
	o = Offers.pick(state(), profil(), NOW, ctx({ firstLegend = true }))
	check("Première éclosion Légendaire : Double chance", o ~= nil and o.key == "DoubleLuck" and o.kind == "product")
	o = Offers.pick(state(), profil(), NOW, ctx({ streakAtRisk = true }))
	check("Série en danger : Sauvetage de série", o ~= nil and o.key == "StreakRestore")
	o = Offers.pick(state(), profil(), NOW, ctx({ towerQuotaExhausted = true }))
	check("Quota de tour épuisé : Ticket d'arène", o ~= nil and o.key == "ArenaTickets")
	o = Offers.pick(state(), profil({ dayNumber = 2 }), NOW, ctx({ calm = true }))
	check("3 premiers jours, moment calme : Pack de départ", o ~= nil and o.key == "StarterPack")
	o = Offers.pick(state(), profil({ dayNumber = 3 }), NOW, ctx({ calm = true }))
	check("Jour 3 : Pack de départ encore proposé", o ~= nil and o.key == "StarterPack")
	check("Jour 4 : plus de Pack de départ", (function()
		local x = Offers.pick(state(), profil({ dayNumber = 4 }), NOW, ctx({ calm = true }))
		return x == nil or x.key ~= "StarterPack"
	end)())
	check("Pack de départ pas en pleine action (hors moment calme)", Offers.pick(state(), profil({ dayNumber = 1 }), NOW, ctx()) == nil)
	check("Sans déclencheur : aucune offre", Offers.pick(state(), profil(), NOW, ctx()) == nil)
	check("Base pleine l'emporte sur série en danger (priorité)", Offers.pick(state(), profil(), NOW, ctx({ baseFull = true, streakAtRisk = true })).key == "ExtraSlots")

	suite("Offres : offre d'œuf adaptée au palier, jamais Secret / Exclusif / Divin")
	local okTier = true
	local seenKeys = {}
	for best = 1, 10 do
		local e = Offers.pick(state(), profil({ bestTier = best }), NOW, ctx({ calm = true, dayNumber = 10 }))
		if e == nil then
			okTier = false
		else
			seenKeys[e.key] = true
			local name = Config.TIERS[e.tier].name
			if e.tier < 2 or e.tier > 4 or name == "Secret" or name == "Exclusif" or name == "Divin" or e.key == "EggSecret" or e.key == "EggExclusive" or e.key == "EggDivine" then
				okTier = false
			end
			if e.robux == nil or e.robux > 49 then
				okTier = false
			end
		end
	end
	check("Palier 1 à 10 du joueur : toujours un œuf Peu commun à Épique (15 à 49 R$)", okTier)
	check("Palier 3 : œuf Rare (EggR3)", Offers.pick(state(), profil({ bestTier = 3 }), NOW, ctx({ calm = true })).key == "EggR3")
	check("Palier 1 relevé à Peu commun", Offers.pick(state(), profil({ bestTier = 1 }), NOW, ctx({ calm = true })).key == "EggR2")
	check("Palier 9 plafonné à Épique", Offers.pick(state(), profil({ bestTier = 9 }), NOW, ctx({ calm = true })).key == "EggR4")
	check("Pas d'offre d'œuf si la base ou le sac est plein (achat refusé avant paiement)", Offers.pick(state(), profil(), NOW, ctx({ calm = true, bagFull = true })) == nil)
	check("Pas d'offre d'œuf pour un joueur qui a fait moins de 5 éclosions", Offers.pick(state(), profil({ hatchedTotal = 2 }), NOW, ctx({ calm = true })) == nil)
	check("Offre d'œuf aléatoire : masquée si PolicyService restreint ou muet", Offers.pick(state(), profil(), NOW, ctx({ calm = true, restricted = true })) == nil and Offers.pick(state(), profil(), NOW, ctx({ calm = true, restricted = "inconnu" })) == nil)
	check("Offre d'œuf sans achat dans le catalogue : nil", Offers.pick(state(), profil(), NOW, { Config = testConfig(function(c)
		c.PRODUCTS.EggR2, c.PRODUCTS.EggR3, c.PRODUCTS.EggR4, c.PRODUCTS.EggR5 = nil, nil, nil, nil
	end), data = D, restricted = false, calm = true }) == nil)
	check("Rareté sans espèce publiée (tierLive faux) : pas d'offre d'œuf", Offers.pick(state(), profil({ bestTier = 3 }), NOW, { data = D, Config = testConfig(function(c)
		c.tierLive = function()
			return false
		end
	end), restricted = false, calm = true }) == nil)
	check("Texte de l'offre d'œuf nomme la rareté fixe", (function()
		local e = Offers.pick(state(), profil({ bestTier = 4 }), NOW, ctx({ calm = true }))
		return string.find(e.text, "Épique", 1, true) ~= nil and string.find(e.title, "Épique", 1, true) ~= nil
	end)())

	suite("Offres : jamais ce qui est possédé, indisponible ou masqué")
	check("Possède déjà ExtraSlots : pas d'offre +4 emplacements", Offers.pick(state(), profil({ passes = { ExtraSlots = true } }), NOW, ctx({ baseFull = true })) == nil)
	check("Possède déjà (champ owned) : pas d'offre", Offers.pick(state(), profil({ owned = { ExtraSlots = true } }), NOW, ctx({ baseFull = true })) == nil)
	check("Pack de départ déjà acheté : pas d'offre", Offers.pick(state(), profil({ dayNumber = 1, owned = { StarterPack = true } }), NOW, ctx({ calm = true, bagFull = true })) == nil)
	check("Possédé : passe à l'offre suivante possible", (function()
		local x = Offers.pick(state(), profil({ passes = { ExtraSlots = true } }), NOW, ctx({ baseFull = true, streakAtRisk = true }))
		return x ~= nil and x.key == "StreakRestore"
	end)())
	local C0 = testConfig(function(c)
		c.PRODUCTS.StreakRestore.id = 0
		c.PASSES.ExtraSlots = { id = 0, name = "x" }
	end)
	check("Id = 0 : jamais proposé", Offers.pick(state(), profil(), NOW, { data = D, Config = C0, restricted = false, streakAtRisk = true }) == nil and Offers.pick(state(), profil(), NOW, { data = D, Config = C0, restricted = false, baseFull = true }) == nil)
	local CN = testConfig(function(c)
		c.PRODUCTS.ArenaTickets.id = nil
	end)
	check("Id absent : jamais proposé", Offers.pick(state(), profil(), NOW, { data = D, Config = CN, restricted = false, towerQuotaExhausted = true }) == nil)
	check("Id non entier : jamais proposé", (function()
		local CF = testConfig(function(c)
			c.PRODUCTS.ArenaTickets.id = 12.5
		end)
		return Offers.pick(state(), profil(), NOW, { data = D, Config = CF, restricted = false, towerQuotaExhausted = true }) == nil
	end)())
	check("Double chance (hasard) masquée si PolicyService restreint", Offers.pick(state(), profil(), NOW, ctx({ firstLegend = true, restricted = true })) == nil)
	check("Double chance masquée si PolicyService n'a pas répondu (nil)", Offers.pick(state(), profil(), NOW, ctx({ firstLegend = true, restricted = "inconnu" })) == nil)
	check("Sauvetage de série (sans hasard) reste proposé si PolicyService restreint", Offers.pick(state(), profil(), NOW, ctx({ streakAtRisk = true, restricted = true })) ~= nil)
	check("Entrées invalides : nil sans erreur", Offers.pick(nil, nil, NOW, ctx()) == nil and Offers.pick(state(), nil, NOW, nil) == nil and Offers.pick(state(), profil(), "x", ctx()) == nil and Offers.pick(state(), 5, NOW, ctx({ baseFull = true })) ~= nil and Offers.pick(state(), profil(), NOW, { Config = 3 }) == nil)

	suite("Offres : jamais pendant une action")
	local busyOk = true
	for _, f in ipairs(D.BUSY) do
		local c = ctx({ baseFull = true })
		c[f] = true
		if Offers.pick(state(), profil(), NOW, c) ~= nil then
			busyOk = false
		end
	end
	check("Aucune offre : vol, cinématique, combat, œuf porté, poursuite, éclosion, chrono de château, menu ouvert", busyOk and #D.BUSY == 8)
	check("Les 5 situations interdites de la spec y sont", (function()
		local set = {}
		for _, f in ipairs(D.BUSY) do
			set[f] = true
		end
		return set.flying and set.cinematic and set.inCombat and set.carrying and set.chased
	end)())
	local sOpen = state()
	local offOpen = Offers.pick(sOpen, profil(), NOW, ctx({ baseFull = true }))
	Offers.onShown(sOpen, offOpen, NOW)
	check("Carte ouverte puis vol : shouldHide = vrai ; calme : faux", Offers.shouldHide(sOpen, ctx({ flying = true })) == true and Offers.shouldHide(sOpen, ctx()) == false and Offers.shouldHide(state(), ctx({ flying = true })) == false)

	suite("Offres : 3 par session, 300 s d'écart, une à la fois, aucune relance")
	check("Pas d'offre pendant les 90 premières secondes", Offers.pick(state(), profil(), T0 + 89, ctx({ baseFull = true })) == nil and Offers.pick(state(), profil(), T0 + 90, ctx({ baseFull = true })) ~= nil)
	local s = state()
	local t = NOW
	local shownIds = {}
	local function cycle(extra)
		local off = Offers.pick(s, profil(), t, ctx(extra))
		if off ~= nil then
			Offers.onShown(s, off, t)
			shownIds[#shownIds + 1] = off.id
			Offers.onClosed(s, t + 5)
		end
		return off
	end
	local a = cycle({ baseFull = true })
	check("1re offre affichée", a ~= nil and s.shown == 1)
	t = t + 100
	check("100 s plus tard : aucune offre (écart de 300 s)", cycle({ streakAtRisk = true }) == nil)
	t = NOW + 299
	check("299 s : encore aucune", cycle({ streakAtRisk = true }) == nil)
	t = NOW + 300
	local b = cycle({ streakAtRisk = true })
	check("300 s : 2e offre", b ~= nil and b.id == "streak" and s.shown == 2)
	t = t + 300
	local c3 = cycle({ towerQuotaExhausted = true })
	check("3e offre", c3 ~= nil and c3.id == "quota" and s.shown == 3)
	t = t + 10000
	check("4e offre : refusée (3 par session) même longtemps après", cycle({ firstLegend = true }) == nil and s.shown == 3)
	local s2 = state()
	local first = Offers.pick(s2, profil(), NOW, ctx({ baseFull = true }))
	Offers.onShown(s2, first, NOW)
	check("Une offre ouverte : aucune autre (une à la fois)", Offers.pick(s2, profil(), NOW + 1000, ctx({ streakAtRisk = true })) == nil)
	Offers.onClosed(s2, NOW + 10)
	check("Fermée : l'offre refusée ne revient pas dans la session", Offers.pick(s2, profil(), NOW + 1000, ctx({ baseFull = true })) == nil)
	check("Fermée : une autre offre reste possible après l'écart", Offers.pick(s2, profil(), NOW + 1000, ctx({ streakAtRisk = true })) ~= nil)
	local s3 = state()
	Offers.onBought(s3, "ExtraSlots", NOW)
	check("Juste après un achat : aucune offre (pas de relance)", Offers.pick(s3, profil(), NOW + 60, ctx({ baseFull = true })) == nil and Offers.pick(s3, profil(), NOW + D.AFTER_BUY - 1, ctx({ streakAtRisk = true })) == nil)
	check("Longtemps après un achat : de nouveau possible", Offers.pick(s3, profil(), NOW + D.AFTER_BUY + 1, ctx({ streakAtRisk = true })) ~= nil)
	local s4 = state()
	local off4 = Offers.pick(s4, profil(), NOW, ctx({ baseFull = true }))
	Offers.onShown(s4, off4, NOW)
	Offers.onBought(s4, off4, NOW + 5)
	check("Achat depuis la carte : la carte se ferme, l'offre est marquée vue", s4.current == nil and s4.seen.baseFull == true and s4.shown == 1)
	check("onShown / onBought / onClosed refusent les entrées invalides", Offers.onShown(nil, off4, 1) == false and Offers.onShown(s4, nil, 1) == false and Offers.onBought(nil, "x", 1) == false and Offers.onClosed(nil, 1) == false)
	check("La carte se range après TTL, sans minuteur affiché", (function()
		local sx = state()
		Offers.onShown(sx, first, NOW)
		return Offers.expired(sx, NOW + D.TTL - 1, ctx()) == false and Offers.expired(sx, NOW + D.TTL, ctx()) == true and Offers.expired(state(), NOW, ctx()) == false
	end)())
	check("Limites lues dans Config.OFFERS si présentes", (function()
		local CX = testConfig(function(c)
			c.OFFERS = { max = 1, gap = 10, graceSeconds = 0 }
		end)
		local sx = Offers.newState(NOW)
		local f1 = Offers.pick(sx, profil(), NOW, { data = D, Config = CX, restricted = false, baseFull = true })
		Offers.onShown(sx, f1, NOW)
		Offers.onClosed(sx, NOW + 1)
		return f1 ~= nil and Offers.pick(sx, profil(), NOW + 500, { data = D, Config = CX, restricted = false, streakAtRisk = true }) == nil
	end)())

	suite("Offres : pureté et textes")
	local sP = state()
	local pP = profil({ passes = { Lucky = true } })
	local snapS = count(sP) + count(sP.seen)
	local snapP = count(pP) + count(pP.passes)
	local cP = ctx({ baseFull = true })
	local snapC = count(cP)
	local allBefore = #RT.all
	for _ = 1, 50 do
		Offers.pick(sP, pP, NOW, cP)
	end
	check("pick ne modifie ni state, ni profil, ni ctx, ne crée aucune instance", sP.shown == 0 and sP.current == nil and count(sP) + count(sP.seen) == snapS and count(pP) + count(pP.passes) == snapP and count(cP) == snapC and #RT.all == allBefore)
	check("pick est déterministe (mêmes entrées, même offre)", (function()
		local x1 = Offers.pick(state(), profil(), NOW, ctx({ calm = true }))
		local x2 = Offers.pick(state(), profil(), NOW, ctx({ calm = true }))
		return x1 ~= nil and x2 ~= nil and x1.key == x2.key and x1.id == x2.id
	end)())
	local textOk, urgencyOk, idsOk = true, true, true
	for _, e in ipairs(D.LIST) do
		if #e.title > D.TITLE_MAX * 4 or #e.title == 0 or #e.text == 0 then -- octets UTF-8 : bornes larges, longueur en caractères testée ensuite
			textOk = false
		end
		if utf8 ~= nil and utf8.len ~= nil then
			if utf8.len(e.title) > D.TITLE_MAX or utf8.len(e.text) > D.TEXT_MAX then
				textOk = false
			end
		end
		local low = string.lower(e.title .. " " .. e.text)
		for _, w in ipairs(D.FORBIDDEN_WORDS) do
			if string.find(low, w, 1, true) ~= nil then
				urgencyOk = false
			end
		end
		if string.find(e.text, "❗", 1, true) or string.find(e.text, "!", 1, true) or string.find(e.text, "%d+ ?s ") then
			urgencyOk = false
		end
		if e.key == "EggSecret" or e.key == "EggExclusive" or e.key == "EggDivine" then
			idsOk = false
		end
	end
	check("Titres (28) et textes (90 caractères) non vides et bornés", textOk and #D.LIST == 5)
	check("Aucune fausse urgence, aucun point d'exclamation, aucun chiffre de durée dans les textes", urgencyOk)
	check("Aucune offre fixe sur un œuf Secret / Exclusif / Divin", idsOk)
	check("Texte de l'offre d'œuf sans urgence", (function()
		local low = string.lower(string.format(D.EGG_TEXT, "Rare"))
		for _, w in ipairs(D.FORBIDDEN_WORDS) do
			if string.find(low, w, 1, true) ~= nil then
				return false
			end
		end
		return true
	end)())
	check("Chaque offre fixe pointe un achat de Config (ou du lot 16 attendu)", (function()
		local expected = { ExtraSlots = true, DoubleLuck = true, StreakRestore = true, ArenaTickets = true, StarterPack = true }
		for _, e in ipairs(D.LIST) do
			if not expected[e.key] then
				return false
			end
		end
		return Config.PASSES.ExtraSlots ~= nil and Config.PRODUCTS.StarterPack ~= nil
	end)())

	suite("Offres : 2000 sessions sans fuite")
	local before = #RT.all
	local shownTotal, maxShown = 0, 0
	for i = 1, 2000 do
		local st = Offers.newState(i)
		local tt = i + 100
		for k = 1, 20 do
			local off = Offers.pick(st, profil(), tt, ctx({ baseFull = (k % 2 == 0), streakAtRisk = (k % 3 == 0), towerQuotaExhausted = (k % 5 == 0), calm = true }))
			if off ~= nil then
				Offers.onShown(st, off, tt)
				Offers.onClosed(st, tt + 1)
				shownTotal = shownTotal + 1
			end
			tt = tt + 301
		end
		if st.shown > maxShown then
			maxShown = st.shown
		end
	end
	check("2000 sessions : jamais plus de 3 offres, aucune instance créée", maxShown == 3 and shownTotal == 6000 and #RT.all == before)
end

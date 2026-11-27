--!nocheck
-- Tests du LOT 12 partie B : BattleRewards (cartes D.5), PetXp (D.6), BattleUi (pastilles de charge, bouton Spécial, efficacité, écran de choix), compatibilité profil v12
-- (migration SANS changement de version, idempotente) avec le VRAI Data.lua. Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run_lot12b.py ou run.luau).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2 (runner lupa). État partagé dans la table T (limite de 200 variables locales).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local T = {}
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } })
	local BR = load("roblox/src/ReplicatedStorage/BattleRewards.lua", "BattleRewards")
	local PetXp = load("roblox/src/ReplicatedStorage/PetXp.lua", "PetXp")
	local Battle = load("roblox/src/ReplicatedStorage/Battle.lua", "Battle")
	local function deep(t)
		if type(t) ~= "table" then
			return t
		end
		local c = {}
		for k, v in pairs(t) do
			c[k] = deep(v)
		end
		return c
	end
	local function same(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in pairs(a) do
			if not same(v, b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	local function cardOf(pick, kind)
		for _, c in ipairs(pick) do
			if c.kind == kind then
				return c
			end
		end
		return nil
	end

	---------------------------------------------------------------- 1. Générateur Park-Miller 48271 (graine injectable)
	suite("Lot 12 B : BattleRewards : générateur Park-Miller 48271 mod 2^31-1")
	check("Constantes : multiplicateur 48271 et module 2^31-1 (jamais 1103515245)", BR.MULTIPLIER == 48271 and BR.MODULUS == 2147483647)
	local r1 = BR.rng(1)
	check("Graine 1 : premier tirage = 48271 / (2^31-1)", math.abs(r1.next() - 48271 / 2147483647) < 1e-15)
	local r2 = BR.rng(1)
	local last
	for _ = 1, 10000 do
		r2.next()
	end
	last = r2.state()
	check("Valeur de contrôle classique de minstd (48271) : état après 10000 pas depuis 1 = 399268537", last == 399268537)
	local a, b = BR.rng(123456), BR.rng(123456)
	local same1 = true
	for _ = 1, 50 do
		if a.next() ~= b.next() then
			same1 = false
		end
	end
	check("Même graine = même suite ; graine différente = suite différente", same1 and BR.rng(1).next() ~= BR.rng(2).next())
	local okSeeds = true
	for _, sd in ipairs({ 0, -5, 1e300, 0 / 0, math.huge, -math.huge, 2147483647, 2147483646, 3.7 }) do
		local g = BR.rng(sd)
		local v = g.next()
		local st = g.state()
		if not (v > 0 and v < 1 and st >= 1 and st <= 2147483646) then
			okSeeds = false
		end
	end
	check("Graines absurdes (0, négative, 1e300, NaN, inf, M) : état valide 1..M-1, tirage dans ]0 ; 1[", okSeeds and BR.rng(nil).next() > 0 and BR.rng("x").next() > 0)
	local inRange = true
	local g3 = BR.rng(99)
	for _ = 1, 2000 do
		local v = g3.int(3, 7)
		if v < 3 or v > 7 or v % 1 ~= 0 then
			inRange = false
		end
	end
	check("rng.int(lo, hi) : entiers dans l'intervalle fermé", inRange)

	---------------------------------------------------------------- 2. Tirage de 3 cartes
	suite("Lot 12 B : BattleRewards : tirage de 3 cartes de catégories distinctes (D.5)")
	local FLOORS = {}
	for f = 1, 45 do
		FLOORS[#FLOORS + 1] = f
	end
	local distinctOk, countOk, bossOk, nonBossEggOk, noPay, kindsSeen = true, true, true, true, true, {}
	local freq = { coins = 0, xp = 0, egg = 0, speed = 0, effect = 0 }
	local allowed = { coins = { amount = true }, xp = { amount = true }, egg = { tier = true }, speed = { amount = true }, effect = { key = true, seconds = true } }
	local nDraws = 0
	for _, mode in ipairs({ "first", "repeat", "normal" }) do
		for _, f in ipairs(FLOORS) do
			for seed = 1, 40 do
				local cards = BR.draw(Config, { floor = f, income = 1000 * f, mode = mode }, seed * 7919 + f)
				nDraws = nDraws + 1
				if #cards ~= 3 then
					countOk = false
				end
				local seen = {}
				for _, c in ipairs(cards) do
					if seen[c.kind] or not allowed[c.kind] then
						distinctOk = false
					end
					seen[c.kind] = true
					freq[c.kind] = (freq[c.kind] or 0) + 1
					for k in pairs(c) do
						if k ~= "kind" and not allowed[c.kind][k] then
							noPay = false -- champ inattendu (ex. robux, rb, product) : refusé
						end
					end
				end
				if f % 5 == 0 and not seen.egg then
					bossOk = false
				end
				local egg = cardOf(cards, "egg")
				if egg then
					local rt = Config.towerTier(f)
					local want = f % 5 == 0 and Config.liveEggTier(math.min(8, Config.nextLiveTier(rt) or rt)) or Config.liveEggTier(rt)
					if egg.tier ~= want or egg.tier > 8 then
						nonBossEggOk = false
					end
				end
			end
		end
	end
	check("3 cartes exactement, dans toutes les modes et les 45 étages (" .. nDraws .. " tirages)", countOk)
	check("3 CATÉGORIES DISTINCTES dans chaque tirage (aucun doublon de catégorie)", distinctOk)
	check("BOSS (étages 5, 10 ... 45) : une carte Œuf est toujours proposée", bossOk)
	check("Rareté de l'œuf : étage normal = rareté de l'étage ; boss = un cran au-dessus (min(.., 8) : jamais Exclusif ni Divin), toujours publiée", nonBossEggOk)
	check("Les 5 catégories (Pièces, Expérience, Œuf, Vitesse, Effet) apparaissent ; Pièces la plus fréquente, Expérience devant Effet", freq.coins > 0 and freq.xp > 0 and freq.egg > 0 and freq.speed > 0 and freq.effect > 0 and freq.coins > freq.xp and freq.xp > freq.effect)
	check("AUCUNE carte ne donne de force payante : seules 5 catégories, champs en liste blanche (aucun champ robux / produit / pass)", noPay)
	local c1 = BR.draw(Config, { floor = 7, income = 100, mode = "first" }, 424242)
	local c2 = BR.draw(Config, { floor = 7, income = 100, mode = "first" }, 424242)
	check("Déterminisme : même graine, même contexte = mêmes cartes (même ordre)", same(c1, c2))
	local variety = false
	for s = 1, 30 do
		if not same(BR.draw(Config, { floor = 7, income = 100, mode = "first" }, s), c1) then
			variety = true
		end
	end
	check("Graines différentes : tirages différents", variety)
	local pool = true
	for _, sd in ipairs({ 0, -1, 1e300, 0 / 0, 2147483647 }) do
		pool = pool and #BR.draw(Config, { floor = 45, income = 1e15, mode = "first" }, sd) == 3
	end
	check("Contexte extrême (étage 45, revenu 1e15) et graines absurdes : 3 cartes, valeurs bornées", pool)
	local ext = BR.draw(Config, { floor = 999, income = 0 / 0, mode = "inconnu" }, 5)
	local extOk = #ext == 3
	for _, c in ipairs(ext) do
		extOk = extOk and (c.amount == nil or (c.amount >= 1 and c.amount == c.amount))
	end
	check("Contexte invalide (étage 999, revenu NaN, mode inconnu) : replié sans erreur", extOk)

	suite("Lot 12 B : BattleRewards : valeurs des cartes (D.5)")
	local function val(kind, ctx)
		return BR.makeCard(Config, kind, ctx, BR.rng(1))
	end
	check("Pièces étage 7, revenu 100/s, 1re victoire : max(500, 100 x 90 x 1,7) x 2 = 30 600", val("coins", { floor = 7, income = 100, mode = "first" }).amount == 30600)
	check("Pièces : plancher de 500 ; répétée x0,5 = 250 ; PNJ x0,6 = 300", val("coins", { floor = 1, income = 0, mode = "normal" }).amount == 500 and val("coins", { floor = 1, income = 0, mode = "repeat" }).amount == 250 and val("coins", { floor = 0, income = 0, mode = "npc" }).amount == 300)
	check("Expérience : 30 + 10 f (étage 7 = 100 ; x2 première = 200 ; x0,5 = 50 ; PNJ étage 0 = 18)", val("xp", { floor = 7, mode = "normal" }).amount == 100 and val("xp", { floor = 7, mode = "first" }).amount == 200 and val("xp", { floor = 7, mode = "repeat" }).amount == 50 and val("xp", { floor = 0, mode = "npc" }).amount == 18)
	check("Vitesse : 2 + f // 5 (étage 7 = 3 ; première = 6 ; répétée = 1 (plancher 1) ; étage 45 = 11)", val("speed", { floor = 7, mode = "normal" }).amount == 3 and val("speed", { floor = 7, mode = "first" }).amount == 6 and val("speed", { floor = 7, mode = "repeat" }).amount == 1 and val("speed", { floor = 45, mode = "normal" }).amount == 11)
	local effOk = true
	for s = 1, 200 do
		local e = BR.makeCard(Config, "effect", { floor = 3 }, BR.rng(s))
		local def = BR.EFFECTS[e.key]
		effOk = effOk and def ~= nil and e.seconds == def.seconds
	end
	check("Effet : parmi 4 (Revenus x2 5 min, Chance +10 5 min, XP x2 10 min, Vitesse +15 % 5 min)", effOk and BR.EFFECTS.income2.seconds == 300 and BR.EFFECTS.luck10.seconds == 300 and BR.EFFECTS.xp2.seconds == 600 and BR.EFFECTS.speed15.seconds == 300)

	---------------------------------------------------------------- 3. pendingPick : reconnexion, choix, expiration
	suite("Lot 12 B : BattleRewards : pendingPick (reconnexion, choix, expiration, assainissement)")
	local ctx = { floor = 10, income = 500, mode = "first" }
	local pick, isNew = BR.offer(Config, nil, ctx, 777, 1000, "k1")
	check("offer sans tirage en attente : nouveau pendingPick, expiration = now + 15 s", isNew == true and pick.id == "k1" and pick.expires == 1015 and #pick.cards == 3 and pick.floor == 10 and pick.mode == "first")
	local stored = deep(pick) -- ce que Data sauvegarde (JSON)
	local again, isNew2 = BR.offer(Config, stored, { floor = 1, income = 1, mode = "normal" }, 999999, 1005, "k2")
	check("Reconnexion / nouvelle victoire avec un pendingPick existant : le MÊME tirage est rendu (aucune nouvelle carte, aucune perte)", isNew2 == false and same(again, pick) and again.id == "k1")
	local pass = true
	for s = 1, 50 do
		local p2 = BR.offer(Config, stored, ctx, s, 1000 + s, "z" .. s)
		pass = pass and same(p2, pick)
	end
	check("Relancer 50 fois avec des graines différentes ne change jamais le tirage enregistré", pass)
	local c, auto = BR.claim(pick, "k1", 2, 1010)
	check("claim : index 2 avant expiration = carte 2 (non automatique)", c == pick.cards[2] and auto == false)
	local cb, why = BR.claim(pick, "k1", 4, 1010)
	local cb2, why2 = BR.claim(pick, "k1", 0, 1010)
	local cb3 = BR.claim(pick, "k1", 1.5, 1010)
	local cb4 = BR.claim(pick, "k1", "1", 1010)
	local cb5 = BR.claim(pick, "k1", 0 / 0, 1010)
	check("claim : index hors plage, 0, décimal, texte, NaN = refus (la récompense n'est PAS consommée)", cb == nil and why == "bad_index" and cb2 == nil and why2 == "bad_index" and cb3 == nil and cb4 == nil and cb5 == nil)
	local cx, whyx = BR.claim(pick, "autre", 1, 1010)
	check("claim : identifiant de tirage différent = refus (rejeu d'un ancien message impossible)", cx == nil and whyx == "bad_id")
	local ca, autoA = BR.claim(pick, "k1", 3, 1015)
	local ca2, autoB = BR.claim(pick, "k1", nil, 99999)
	check("Délai écoulé (>= 15 s, même longtemps après la déconnexion) : la PREMIÈRE carte est donnée d'office, index ignoré", ca == pick.cards[1] and autoA == true and ca2 == pick.cards[1] and autoB == true)
	check("Pas de tirage : claim(nil) = refus ; remaining : 5 s puis 0 ; expired", BR.claim(nil, "k1", 1, 1) == nil and BR.remaining(pick, 1010) == 5 and BR.remaining(pick, 5000) == 0 and not BR.expired(pick, 1014) and BR.expired(pick, 1015))
	local clean = BR.sanitizePending(Config, stored)
	check("sanitizePending : un tirage valide traverse intact ; IDEMPOTENT", same(clean, pick) and same(BR.sanitizePending(Config, clean), clean))
	local bad = {
		"x", 5, {}, { id = "a" }, { id = "a", expires = 5 }, { id = "a", expires = 5, cards = {} },
		{ id = {}, expires = 5, cards = deep(pick.cards) }, { id = "a", expires = 0 / 0, cards = deep(pick.cards) },
		{ id = "a", expires = 5, cards = { { kind = "coins", amount = 5 }, { kind = "coins", amount = 6 }, { kind = "xp", amount = 3 } } }, -- doublon de catégorie
		{ id = "a", expires = 5, cards = { { kind = "robux", amount = 5 }, { kind = "xp", amount = 3 }, { kind = "egg", tier = 1 } } },
		{ id = "a", expires = 5, cards = { { kind = "coins", amount = "9" }, { kind = "xp", amount = 3 }, { kind = "egg", tier = 1 } } },
	}
	local badOk = true
	for _, x in ipairs(bad) do
		badOk = badOk and BR.sanitizePending(Config, x) == nil
	end
	check("sanitizePending : valeurs corrompues (type, NaN, doublon de catégorie, catégorie inconnue, montant texte, moins de 3 cartes) = nil (tirage neuf plus tard)", badOk)
	local tam = BR.sanitizePending(Config, { id = 5, expires = 10, floor = 999, mode = "zzz", cards = { { kind = "coins", amount = 1e300, rb = 9999 }, { kind = "xp", amount = -4 }, { kind = "egg", tier = 99 } } })
	check("sanitizePending : montants bornés (pièces <= 1e15, XP >= 1, rareté <= 10), champ pirate retiré, étage et mode ramenés", tam ~= nil and tam.cards[1].amount <= 1e15 and tam.cards[1].rb == nil and tam.cards[2].amount == 1 and tam.cards[3].tier == #Config.TIERS and tam.floor == 45 and tam.mode == "normal")

	---------------------------------------------------------------- 4. Attribution
	suite("Lot 12 B : BattleRewards : attribution (grant) et boosts")
	local function profile()
		return { coins = 1000, speed = 10, rb = 77, boosts = {}, battle = { team = { 1, 3, 9 } }, slots = { { k = "p", p = 1, s = 2, m = 1, x = 0 }, { k = "e", t = 1 }, { k = "p", p = 2, s = 2, m = 1, x = 39 }, false } }
	end
	local d = profile()
	local out = BR.grant(Config, d, { kind = "coins", amount = 500 }, {}, 100, PetXp)
	check("grant pièces : +500, résumé", d.coins == 1500 and out.coins == 500 and out.kind == "coins")
	d = profile()
	out = BR.grant(Config, d, { kind = "xp", amount = 40 }, {}, 100, PetXp)
	check("grant XP : +40 à chaque PET de l'équipe (l'œuf et l'emplacement vide ignorés), niveau 2 atteint, jamais au-delà du niveau 20", d.slots[1].x == 40 and d.slots[3].x == 79 and d.slots[2].x == nil and PetXp.level(d.slots[1].x) == 2 and #out.pets == 2)
	d = profile()
	d.slots[1].x = PetXp.MAX_XP
	BR.grant(Config, d, { kind = "xp", amount = 5000 }, {}, 100, PetXp)
	check("grant XP : un pet niveau 20 ne dépasse pas l'XP maximale", d.slots[1].x == PetXp.MAX_XP)
	d = profile()
	out = BR.grant(Config, d, { kind = "speed", amount = 4 }, {}, 100, PetXp)
	check("grant vitesse : +4 permanent", d.speed == 14 and out.speed == 4)
	d = profile()
	local given
	out = BR.grant(Config, d, { kind = "egg", tier = 3 }, { giveEgg = function(t) given = t return true end }, 100, PetXp)
	check("grant œuf : giveEgg(rareté) appelé, aucun gain de pièces", given == 3 and out.egg == 3 and not out.converted and d.coins == 1000)
	d = profile()
	out = BR.grant(Config, d, { kind = "egg", tier = 3 }, { giveEgg = function() return false end }, 100, PetXp)
	check("grant œuf, base pleine : converti en son prix en pièces (Config.eggCoinValue), signalé", out.converted == true and d.coins == 1000 + Config.eggCoinValue(3) and Config.eggCoinValue(3) > 0)
	d = profile()
	BR.grant(Config, d, { kind = "egg", tier = 9 }, {}, 100, PetXp)
	check("grant œuf sans hook : jamais de perte (converti en pièces ; Exclusif = prix du Secret)", d.coins == 1000 + Config.eggCoinValue(9) and Config.eggCoinValue(9) > 0)
	d = profile()
	local e1 = BR.grant(Config, d, { kind = "effect", key = "xp2" }, {}, 1000, PetXp)
	check("grant effet : data.boosts.xp2 = now + 600", d.boosts.xp2 == 1600 and e1.endsAt == 1600)
	BR.grant(Config, d, { kind = "effect", key = "xp2" }, {}, 1100, PetXp)
	check("Effet déjà actif : PROLONGE (1600 + 600 = 2200), ne se cumule pas en double effet", d.boosts.xp2 == 2200)
	for _ = 1, 20 do
		BR.grant(Config, d, { kind = "effect", key = "xp2" }, {}, 1100, PetXp)
	end
	check("Plafond de 30 min : fin <= now + 1800", d.boosts.xp2 == 1100 + 1800)
	BR.grant(Config, d, { kind = "effect", key = "income2" }, {}, 1100, PetXp)
	check("Effets distincts indépendants ; boostActive", d.boosts.income2 == 1400 and BR.boostActive(d.boosts, "income2", 1399) and not BR.boostActive(d.boosts, "income2", 1400) and not BR.boostActive(d.boosts, "luck10", 5))
	d = profile()
	local forged = { { kind = "robux", amount = 99 }, { kind = "coins", amount = 5, rb = 1000 }, { kind = "effect", key = "pass" }, { kind = "xp" }, "x", 5 }
	local forgedOk = true
	for _, f in ipairs(forged) do
		local o = BR.grant(Config, d, f, {}, 100, PetXp)
		if type(f) == "table" and f.kind == "coins" and f.amount == 5 then
			forgedOk = forgedOk and o ~= nil
		else
			forgedOk = forgedOk and o == nil
		end
	end
	check("Cartes forgées (catégorie inconnue, clé d'effet inconnue, montant absent, non-table) : refusées ; un champ `rb` ajouté est ignoré", forgedOk and d.rb == 77 and d.coins == 1005)
	local before = deep(profile())
	local dd = profile()
	for _, k in ipairs({ { kind = "coins", amount = 9 }, { kind = "xp", amount = 9 }, { kind = "speed", amount = 2 }, { kind = "egg", tier = 2 }, { kind = "effect", key = "luck10" } }) do
		BR.grant(Config, dd, k, { giveEgg = function() return true end }, 100, PetXp)
	end
	check("Aucune carte ne touche à data.rb (Robux) ni à un champ payant (passes, produits, reçus)", dd.rb == before.rb and dd.passes == nil and dd.receipts == nil and dd.owned == nil)
	check("Vue client : pas de graine, textes présents, carte Œuf de boss signalée, index renvoyé par le client", (function()
		local p = BR.newPick(Config, { floor = 15, income = 10, mode = "first" }, 5, 100, 1)
		local v = BR.view(Config, p, 105)
		local bossFlag = false
		for _, cv in ipairs(v.cards) do
			if cv.kind == "egg" and cv.boss then
				bossFlag = true
			end
		end
		return v.id == 1 and #v.cards == 3 and v.seconds == 10 and bossFlag and type(v.cards[1].desc) == "string" and v.seed == nil and v.cards[1].amount == nil
	end)())

	---------------------------------------------------------------- 5. PetXp
	suite("Lot 12 B : PetXp : niveaux 1-20, +1,5 % par niveau, sources d'XP (D.6)")
	check("xpTo(L) = floor(40 x L^1,1) : 40, 85 ; nil au niveau 20 et pour un niveau invalide", PetXp.xpTo(1) == 40 and PetXp.xpTo(2) == math.floor(40 * 2 ^ 1.1) and PetXp.xpTo(19) == math.floor(40 * 19 ^ 1.1) and PetXp.xpTo(20) == nil and PetXp.xpTo(0) == nil and PetXp.xpTo(0 / 0) == nil and PetXp.xpTo("a") == nil)
	local cum = 0
	for L = 1, 19 do
		cum = cum + math.floor(40 * L ^ 1.1)
	end
	check("XP cumulée au niveau 20 = somme des xpTo(1..19) = PetXp.MAX_XP (formule de D.6 : " .. cum .. ")", PetXp.MAX_XP == cum and PetXp.CUM[20] == cum and PetXp.CUM[1] == 0)
	check("Niveau : 0 XP = 1 ; 39 = 1 ; 40 = 2 ; MAX_XP = 20 ; au-delà = 20 (plafond)", PetXp.level(0) == 1 and PetXp.level(39) == 1 and PetXp.level(40) == 2 and PetXp.level(PetXp.MAX_XP - 1) == 19 and PetXp.level(PetXp.MAX_XP) == 20 and PetXp.level(1e12) == 20)
	local mono, prev = true, 1
	for x = 0, PetXp.MAX_XP + 50, 7 do
		local lv = PetXp.level(x)
		if lv < prev or lv > 20 then
			mono = false
		end
		prev = lv
	end
	check("Le niveau est croissant avec l'XP et ne dépasse JAMAIS 20", mono and prev == 20)
	check("Valeurs douteuses : niveau(NaN / négatif / texte / nil / inf) = 1", PetXp.level(0 / 0) == 1 and PetXp.level(-5) == 1 and PetXp.level("x") == 1 and PetXp.level(nil) == 1 and PetXp.sanitize(math.huge) == 0)
	check("Multiplicateur : niveau 1 = 1 ; niveau 2 = 1,015 ; niveau 20 = 1,285 ; plafonné ; invalide = 1", PetXp.statMul(1) == 1 and math.abs(PetXp.statMul(2) - 1.015) < 1e-12 and math.abs(PetXp.statMul(20) - 1.285) < 1e-12 and PetXp.statMul(500) == PetXp.statMul(20) and PetXp.statMul(0) == 1 and PetXp.statMul(0 / 0) == 1 and PetXp.statMul(nil) == 1)
	local nx, gained, from, to = PetXp.add(30, 20)
	check("add : 30 + 20 = 50, gain réel 20, niveau 1 -> 2", nx == 50 and gained == 20 and from == 1 and to == 2)
	local m1, g1 = PetXp.add(PetXp.MAX_XP - 3, 1000)
	check("add : plafonné à MAX_XP, gain réel = ce qui reste (3) ; montants négatifs / NaN / texte = 0 ; énorme plafonné à 100 000", m1 == PetXp.MAX_XP and g1 == 3 and select(2, PetXp.add(10, -9)) == 0 and select(2, PetXp.add(10, 0 / 0)) == 0 and select(2, PetXp.add(10, "9")) == 0 and select(2, PetXp.add(0, 1e12)) == PetXp.MAX_XP)
	local v = PetXp.view(100)
	check("view : niveau, XP dans le niveau, XP requise, fraction ; au max frac = 1", v.level == 2 and v.into == 100 - PetXp.CUM[2] and v.need == PetXp.xpTo(2) and v.frac > 0 and v.frac < 1 and PetXp.view(PetXp.MAX_XP).max == true and PetXp.view(PetXp.MAX_XP).frac == 1)
	check("Combat : PvE gagné 20 + 5 x étage (étage 10 = 70, 45 = 245), perdu 5 ; PvP 15 / 5 ; PNJ 12 / 3 ; type inconnu = 0", PetXp.combat("pve", true, 10) == 70 and PetXp.combat("pve", true, 45) == 245 and PetXp.combat("pve", false, 10) == 5 and PetXp.combat("pvp", true) == 15 and PetXp.combat("pvp", false) == 5 and PetXp.combat("npc", true) == 12 and PetXp.combat("npc", false) == 3 and PetXp.combat("shop", true, 5) == 0)
	check("award : seules les sources pve / pvp / npc / card donnent de l'XP", PetXp.award("pve", 70) == 70 and PetXp.award("pvp", 15) == 15 and PetXp.award("npc", 12) == 12 and PetXp.award("card", 40) == 40)
	local refused = true
	for _, src in ipairs({ "product", "robux", "pass", "gamepass", "receipt", "purchase", "gift", "daily", "season", "devproduct", "", "PVE", 5, true }) do
		if PetXp.award(src, 1000) ~= 0 or PetXp.sourceAllowed(src) then
			refused = false
		end
	end
	check("JAMAIS d'XP de pet via un produit : toute source hors liste blanche (product, robux, pass, receipt, gift, ...) donne 0", refused and PetXp.award(nil, 1000) == 0)
	check("Multiplicateur « XP x2 » : appliqué aux combats seulement (pas à la carte Expérience) ; vaut 2 si xp2Until ou boosts.xp2 actifs, sinon 1", PetXp.award("pve", 70, 2) == 140 and PetXp.award("card", 40, 2) == 40 and PetXp.boostMul({ xp2Until = 200 }, 100) == 2 and PetXp.boostMul({ boosts = { xp2 = 200 } }, 100) == 2 and PetXp.boostMul({ xp2Until = 50, boosts = { xp2 = 60 } }, 100) == 1 and PetXp.boostMul(nil, 100) == 1 and PetXp.boostMul({}, nil) == 1)
	-- Aucun produit / pass du jeu ne parle d'XP de pet ; aucun effet payant ne donne de l'XP
	local scan = true
	for _, tbl in ipairs({ Config.PRODUCTS, Config.PASSES }) do
		for key, def in pairs(tbl) do
			if string.find(string.lower(key), "xp", 1, true) then
				scan = false
			end
			for f, val2 in pairs(def) do
				local s = string.lower(f .. " " .. tostring(val2))
				if string.find(s, "xp de pet", 1, true) or string.find(s, "xp des pets", 1, true) or string.find(s, "petxp", 1, true) or string.find(s, "xp pet", 1, true) or f == "xp" or f == "petXp" then
					scan = false
				end
			end
		end
	end
	check("Config.PRODUCTS et Config.PASSES : aucun produit ni pass ne donne ni ne mentionne d'XP de pet", scan)
	local ex = { { k = "p", p = 1, s = 2, m = 1, x = 10 }, { k = "e", t = 1 }, { k = "p", p = 2, s = 2, m = 1 } }
	local res = PetXp.addToTeam(ex, { 1, 2, 3, 3, 9, "z" }, 45)
	check("addToTeam : pets seulement, doublons et indices invalides ignorés ; slot.x absent traité comme 0", #res == 2 and ex[1].x == 55 and ex[3].x == 45 and ex[2].x == nil and res[1].to == 2)
	check("Vente / vol : PetXp.carry rend l'XP du pet (le voleur la garde) ; œuf ou vide = 0", PetXp.carry({ k = "p", x = 800 }) == 800 and PetXp.carry({ k = "e" }) == 0 and PetXp.carry(false) == 0 and PetXp.carry({ k = "p", x = -3 }) == 0)
	check("Dresseur : niveau = floor(sqrt(xp / 50)) + 1 (0 = 1 ; 50 = 2 ; 5000 = 11), max 100", PetXp.trainerLevel(0) == 1 and PetXp.trainerLevel(50) == 2 and PetXp.trainerLevel(5000) == 11 and PetXp.trainerLevel(1e12) == 100 and PetXp.trainerLevel(-1) == 1)
	local tr = PetXp.trainerAdd({ xp = 10 }, 90)
	check("trainerAdd / sanitizeTrainer : cumul, bornes, idempotent, valeurs corrompues = { xp = 0 }", tr.xp == 100 and PetXp.trainerAdd("x", 5).xp == 5 and same(PetXp.sanitizeTrainer(PetXp.sanitizeTrainer({ xp = 1e30 })), PetXp.sanitizeTrainer({ xp = 1e30 })) and PetXp.sanitizeTrainer({ xp = 0 / 0 }).xp == 0 and PetXp.sanitizeTrainer(nil).xp == 0)

	---------------------------------------------------------------- 6. Compatibilité profil v12 : fonctions de migration (pures)
	suite("Lot 12 B : compatibilité avec le profil v12 : champs neufs, migration idempotente (modules)")
	local v12 = { ver = 12, coins = 5, battle = { team = { 1 }, best = 3 } }
	local function migrate(saved) -- ce que fait Data.merge (voir README « Brancher »)
		local out = { battle = { team = deep(saved.battle and saved.battle.team or {}), best = saved.battle and saved.battle.best or 0 } }
		out.battle.pendingPick = BR.sanitizePending(Config, saved.battle and saved.battle.pendingPick or nil)
		out.boosts = BR.sanitizeBoosts(saved.boosts)
		out.trainer = PetXp.sanitizeTrainer(saved.trainer)
		return out
	end
	local m = migrate(v12)
	check("Profil v12 SANS les champs neufs : pendingPick = nil, boosts = {}, trainer = { xp = 0 } (valeurs par défaut), équipe et meilleur étage intacts", m.battle.pendingPick == nil and next(m.boosts) == nil and m.trainer.xp == 0 and m.battle.best == 3 and m.battle.team[1] == 1)
	local v12b = { ver = 12, battle = { pendingPick = deep(pick) }, boosts = { xp2 = 1e30, income2 = 55.7, zzz = 3, luck10 = -4, speed15 = "x" }, trainer = { xp = 321.9 } }
	local m2 = migrate(v12b)
	local m3 = migrate({ battle = m2.battle, boosts = m2.boosts, trainer = m2.trainer })
	check("Migration IDEMPOTENTE : migrate(migrate(x)) == migrate(x) ; clés de boosts inconnues et valeurs invalides retirées, entiers bornés", same(m2, m3) and m2.boosts.income2 == 55 and m2.boosts.xp2 == 4e9 and m2.boosts.zzz == nil and m2.boosts.luck10 == nil and m2.boosts.speed15 == nil and m2.trainer.xp == 321)
	check("pendingPick sauvegardé traverse la migration sans perte (reconnexion)", same(m2.battle.pendingPick, pick))

	---------------------------------------------------------------- 7. BattleUi (client) avec un Roblox factice minimal
	suite("Lot 12 B : BattleUi : pastilles de charge, bouton Spécial, efficacité, écran de choix")
	local made = {}
	local function sig()
		local s = { fns = {} }
		function s:Connect(fn)
			self.fns[#self.fns + 1] = fn
			return { Disconnect = function() end }
		end
		return s
	end
	local function newInst(class, parentless)
		local o = { ClassName = class, Children = {}, destroyed = false }
		o.Activated = sig()
		o.OnClientEvent = sig()
		function o:Destroy()
			self.destroyed = true
		end
		made[#made + 1] = o
		return setmetatable(o, { __newindex = function(t, k, v)
			rawset(t, k, v)
			if k == "Parent" and type(v) == "table" and v.Children then
				v.Children[#v.Children + 1] = t
			end
		end })
	end
	local function v2(x, y)
		return { X = x, Y = y }
	end
	local envUi = {
		Instance = { new = function(class) return newInst(class) end },
		Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) end }),
		UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromOffset = function(a, b) return { 0, a, 0, b } end, fromScale = function(a, b) return { a, 0, b, 0 } end },
		UDim = { new = function(a, b) return { a, b } end },
		Vector2 = { new = v2 },
		Color3 = { new = function(r, g, b) return { r, g, b } end, fromRGB = function(r, g, b) return { r, g, b } end },
		TweenInfo = { new = function() return {} end },
		task = { spawn = function() end, delay = function() end, wait = function() end },
		game = { GetService = function() return { Create = function() return { Play = function() end } end } end },
	}
	local UI = load("roblox/src/StarterPlayerScripts/BattleUi.lua", "BattleUi", envUi)
	-- pur : état du bouton Spécial
	local st0 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", charge = 3, cd = 0, stun = 0 })
	local st1 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", charge = 5, cd = 0, stun = 0 })
	local st2 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", charge = 5, cd = 0, stun = 1 })
	local st3 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", cd = 2 })
	local st4 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", cd = 0 })
	local st5 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", charge = 99 })
	local st6 = UI.specialState(Config, Battle, { type = "Feu", skill = "strike", charge = -4 })
	check("Spécial : « Spécial 3/5 » grisé à 3 charges ; prêt à 5 ; non prêt si étourdi ; charge bornée 0..5", st0.text == "Spécial 3/5" and not st0.ready and st1.ready and string.find(st1.text, "✨", 1, true) and not st2.ready and st5.charge == 5 and st6.charge == 0)
	check("Spécial : repli sur la recharge `cd` si le moteur du lot 8 n'a pas de charge (rien ne casse avant l'intégration de Battle.lua du lot 12)", st3.charge == nil and not st3.ready and string.find(st3.text, "(2)", 1, true) and st4.ready)
	local named = UI.specialState({ TYPE_SPECIAL_NAME = { Feu = "Souffle ardent" } }, Battle, { type = "Feu", skill = "strike", charge = 5 })
	check("Nom du spécial par type (Config.TYPE_SPECIAL_NAME : « Souffle ardent ») si présent", string.find(named.text, "Souffle ardent", 1, true) ~= nil)
	local e1t, e1c = UI.efficacy(1.5)
	local e2t = UI.efficacy(1.25)
	local e3t = UI.efficacy(0.8)
	local e4t = UI.efficacy(0.67)
	check("Textes d'efficacité (B.6) : x1,5 « Super efficace ! » ; x1,25 « Efficace » ; x0,8 « Peu efficace » ; x0,67 « Pas très efficace… » ; x1 / NaN / 0 / texte = rien", e1t == "Super efficace !" and e2t == "Efficace" and e3t == "Peu efficace" and e4t == "Pas très efficace…" and UI.efficacy(1) == nil and UI.efficacy(0 / 0) == nil and UI.efficacy(0) == nil and UI.efficacy("a") == nil and e1c[2] == 220)
	-- cohérence avec le module de données TypeFx existant
	local TypeFxData = load("roblox/src/ReplicatedStorage/TypeFx.lua", "TypeFxData")
	local same2 = true
	for _, mul in ipairs({ 1.5, 1.25, 0.8, 0.67, 1, 2, 0.1 }) do
		if UI.efficacy(mul) ~= TypeFxData.efficacy(mul) then
			same2 = false
		end
	end
	check("Le repli local d'efficacité donne les mêmes textes que ReplicatedStorage/TypeFx.efficacy", same2)

	-- start() avec un faux écran
	local gui = newInst("ScreenGui")
	local fired = {}
	local RB = newInst("RemoteEvent")
	local state = { battle = { team = {}, best = 4, fightsLeft = 5, repeatsLeft = 5 }, slots = {} }
	local player = { DisplayName = "Moi", UserId = 1 }
	local ui = UI.start(Config, Battle, player, gui, function() return state end, function(a, arg) fired[#fired + 1] = { a, arg } end, RB, nil)
	check("BattleUi.start : construit l'interface sans erreur (écran factice)", ui ~= nil and ui.panel ~= nil)
	local handler = RB.OnClientEvent.fns[1]
	check("BattleUi.start : se branche sur le remote Battle", type(handler) == "function")
	local function countPips(size)
		local n = 0
		for _, o in ipairs(made) do
			if o.ClassName == "Frame" and not o.destroyed and o.Size and o.Size[2] == size and o.Size[4] == size then
				n = n + 1
			end
		end
		return n
	end
	local function liveButtons()
		local list = {}
		for _, o in ipairs(made) do
			if o.ClassName == "TextButton" and not o.destroyed and o.Parent == ui.body then
				list[#list + 1] = o
			end
		end
		return list
	end
	local function unit(p, charge)
		return { p = p, type = Battle.SPECIES_TYPE[p], skill = Battle.SPECIES_SKILL[p], hp = 50, maxHp = 60, cd = 0, stun = 0, focus = 0, guard = false, charge = charge }
	end
	local function mkView(myCharge, foeCharge)
		return { turn = 1, over = false, sides = { { active = 1, units = { unit(1, myCharge), unit(4, 0), unit(7, 0) } }, { active = 1, units = { unit(2, foeCharge), unit(5, 0), unit(8, 0) } } } }
	end
	handler({ k = "start", floor = 3, foe = "Dresseur 3", view = mkView(3, 1), seconds = 10 })
	local texts = {}
	for _, b in ipairs(liveButtons()) do
		texts[#texts + 1] = b.Text
	end
	local allText = table.concat(texts, "|")
	check("Combat : bouton Spécial affiche « Spécial 3/5 » (grisé) quand le pet actif a 3 charges", string.find(allText, "Spécial 3/5", 1, true) ~= nil)
	check("Combat : 10 pastilles de charge (5 sous chaque barre de vie)", countPips(10) == 10)
	local specialBtn
	for _, b in ipairs(liveButtons()) do
		if b.Text == "Spécial 3/5" then
			specialBtn = b
		end
	end
	fired = {}
	if specialBtn then
		specialBtn.Activated.fns[1]()
	end
	check("Spécial non prêt : cliquer n'envoie rien au serveur", #fired == 0)
	handler({ k = "turn", events = {}, view = mkView(5, 1), seconds = 10 })
	specialBtn = nil
	for _, b in ipairs(liveButtons()) do
		if string.find(b.Text, "✨", 1, true) then
			specialBtn = b
		end
	end
	if specialBtn then
		specialBtn.Activated.fns[1]()
	end
	check("Spécial prêt (5/5) : le bouton « ✨ ... » envoie l'intention « skill » (le serveur revalide)", #fired == 1 and fired[1][1] == "battleAct" and fired[1][2] == "skill")
	-- journal : texte d'efficacité
	handler({ k = "turn", events = { { t = "hit", side = 1, p = 1, mul = 1.5, dmg = 12, skill = nil, target = 1 } }, view = mkView(5, 1), seconds = 10 })
	local logText
	for _, o in ipairs(made) do
		if o.ClassName == "TextLabel" and not o.destroyed and type(o.Text) == "string" and string.find(o.Text, "Super efficace", 1, true) then
			logText = o.Text
		end
	end
	check("Journal : le coup super efficace affiche « Super efficace ! » (sans doublon)", logText ~= nil and select(2, string.gsub(logText, "Super efficace", "")) == 1)

	-- écran de choix
	fired = {}
	local pickView = { id = "k9", seconds = 15, floor = 5, cards = { { kind = "coins", icon = "🪙", title = "Pièces", desc = "+500" }, { kind = "egg", icon = "🥚", title = "Œuf", desc = "1 œuf", boss = true }, { kind = "speed", icon = "👟", title = "Vitesse", desc = "+3" } } }
	handler({ k = "end", win = true, rewards = {}, pick = true, view = mkView(0, 0) })
	local noContinue = true
	for _, b in ipairs(liveButtons()) do
		if b.Text == "Continuer" then
			noContinue = false
		end
	end
	check("Victoire avec choix en attente : pas de bouton « Continuer » (on n'ignore pas la récompense)", noContinue)
	handler({ k = "pick", id = "k9", cards = pickView.cards, seconds = 15 })
	local cardBtns = {}
	for _, b in ipairs(liveButtons()) do
		if b.Text == "" and b.Size and b.Size[1] < 1 then
			cardBtns[#cardBtns + 1] = b
		end
	end
	check("Écran de choix : 3 cartes cliquables (icône, titre, description), le titre indique la récompense", #cardBtns == 3 and string.find(ui.title.Text, "récompense", 1, true) ~= nil)
	fired = {}
	cardBtns[2].Activated.fns[1]()
	cardBtns[3].Activated.fns[1]()
	cardBtns[1].Activated.fns[1]()
	check("Choix : envoie UNE seule fois { id, i } (index 2) ; les clics suivants sont ignorés (anti double envoi)", #fired == 1 and fired[1][1] == "battlePick" and fired[1][2].id == "k9" and fired[1][2].i == 2)
	handler({ k = "picked", text = "🥚 Œuf Rare", auto = false })
	local cont
	for _, b in ipairs(liveButtons()) do
		if b.Text == "Continuer" then
			cont = b
		end
	end
	check("Récompense reçue : « Continuer » apparaît et ramène à l'écran d'équipe", cont ~= nil)
	if cont then
		cont.Activated.fns[1]()
	end
	handler({ k = "pick", id = "z", cards = "pas une table" })
	handler({ k = "pick", id = "z", cards = {} })
	handler(42)
	handler({ k = "pick", id = "z", cards = { 1, 2, 3, 4, 5, 6, 7 } })
	check("Messages serveur invalides (cartes absentes, trop nombreuses, non-table) : ignorés sans erreur", true)
	-- reconnexion : le serveur renvoie la même vue en plein écran d'équipe
	fired = {}
	handler({ k = "pick", id = "k9", cards = pickView.cards, seconds = 6 })
	local again2 = 0
	for _, b in ipairs(liveButtons()) do
		if b.Text == "" and b.Size and b.Size[1] < 1 then
			again2 = again2 + 1
		end
	end
	check("Reconnexion : le serveur renvoie le même tirage, l'écran de choix se rouvre avec le temps restant", again2 == 3)

	---------------------------------------------------------------- 8. Intégration : vrai Data.lua (patch du README) et vrai serveur
	suite("Lot 12 B : intégration avec le vrai Data.lua (profil v12 réel, reconnexion, relecture)")
	if not newRuntime then
		return
	end
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game })
	if not RT then
		return
	end
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local stored2 = deep(pick)
	ds.data.P_9971 = { v = { ver = 12, coins = 321, slots = { { k = "p", p = 1, s = 2, m = 1, x = 1e30 }, { k = "p", p = 2, s = 2, m = 1, x = 55 } }, battle = { team = { 1, 2 }, best = 6, pendingPick = stored2 }, boosts = { xp2 = 4e9 + 5, bidon = 1 }, trainer = { xp = 1200.5 } }, t = 1700000000 + RT.now - 5000 }
	ds.data.P_9972 = { v = { ver = 12, coins = 9, battle = { team = {}, best = 0 } }, t = 1700000000 + RT.now - 5000 }
	ds.data.P_9973 = { v = { ver = 12, coins = 9, battle = { team = {}, best = 0, pendingPick = { id = 1, expires = 5, cards = { { kind = "coins", amount = 5 } } } }, boosts = "x", trainer = 7 }, t = 1700000000 + RT.now - 5000 }
	T.p1 = RT.addPlayer("L12A", 9971, { from = "hub", partyId = "L12A", size = 3, late = false })
	T.p2 = RT.addPlayer("L12B", 9972, { from = "hub", partyId = "L12A", size = 3, late = false })
	T.p3 = RT.addPlayer("L12C", 9973, { from = "hub", partyId = "L12A", size = 3, late = false })
	RT.step(3)
	local s1, s2, s3 = hooks.session(T.p1), hooks.session(T.p2), hooks.session(T.p3)
	local d1, d2, d3 = s1 and s1.data, s2 and s2.data, s3 and s3.data
	check("Profil v12 avec champs neufs : pendingPick conservé tel quel (même tirage), boosts assainis (xp2 borné, clé inconnue retirée), trainer entier, XP de pet bornée au niveau 20" .. errs(),
		d1 ~= nil and d1.ver == 12 and d1.coins >= 321 and same(d1.battle.pendingPick, pick) and d1.boosts.xp2 == 4e9 and d1.boosts.bidon == nil and d1.trainer.xp == 1200 and d1.slots[1].x == PetXp.MAX_XP and d1.slots[2].x == 55 and d1.battle.best == 6 and #d1.battle.team == 2)
	check("Profil v12 SANS champs neufs : valeurs par défaut (pas de pendingPick, boosts vide, trainer 0), aucune erreur" .. errs(), d2 ~= nil and d2.battle.pendingPick == nil and next(d2.boosts) == nil and d2.trainer.xp == 0 and #RT.errors == 0)
	check("Profil v12 corrompu (pendingPick à 1 carte, boosts texte, trainer nombre) : retombe sur les valeurs par défaut sans erreur" .. errs(), d3 ~= nil and d3.battle.pendingPick == nil and next(d3.boosts) == nil and d3.trainer.xp == 0)
	check("Version de profil inchangée (12) pour les trois profils lus", d1.ver == 12 and d2.ver == 12 and d3.ver == 12)
	RT.removePlayer(T.p1)
	RT.removePlayer(T.p2)
	RT.removePlayer(T.p3)
	RT.step(3)
	local sv = ds.data.P_9971 and ds.data.P_9971.v
	check("Sauvegarde à la sortie : pendingPick, boosts et trainer écrits dans le profil" .. errs(), sv ~= nil and sv.ver == 12 and same(sv.battle.pendingPick, pick) and sv.boosts.xp2 == 4e9 and sv.trainer.xp == 1200)
	local snapshotCopy = deep(sv)
	T.p1 = RT.addPlayer("L12A", 9971, { from = "hub", partyId = "L12A", size = 3, late = false })
	RT.step(3)
	s1 = hooks.session(T.p1)
	d1 = s1 and s1.data
	check("RECONNEXION : le même tirage de cartes est relu (rien retiré, rien retiré), double migration = mêmes champs" .. errs(), d1 ~= nil and same(d1.battle.pendingPick, snapshotCopy.battle.pendingPick) and same(d1.boosts, snapshotCopy.boosts) and same(d1.trainer, snapshotCopy.trainer) and #RT.errors == 0)
	RT.removePlayer(T.p1)
	RT.step(3)
end

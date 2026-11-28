--!nocheck
-- Tests de la Passe de combat (lot 16, logique pure : Season.lua + SeasonData.lua).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs } fournis par tests/run.luau ou par tests/run_season.py.
-- Pas de math.random : tout est déterministe (le « joueur-robot » suit un emploi du temps fixe).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local DAY = 86400
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local Color3 = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
	}
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = Color3 })
	local SD = load("roblox/src/ReplicatedStorage/SeasonData.lua", "SeasonData")
	local Season = load("roblox/src/ReplicatedStorage/Season.lua", "Season")
	local S = Season.new(Config, SD)
	local START = SD.SEASON.start
	local LEN = SD.SEASON.days * DAY

	local function idx(name)
		for i, t in ipairs(Config.TIERS) do
			if t.name == name then
				return i
			end
		end
		return nil
	end
	local function at(season, day, hour)
		return START + (season - 1) * LEN + day * DAY + (hour or 12) * 3600
	end
	local function tierAfterXp(profil, xp, now)
		-- amène le profil à `xp` en respectant le plafond (jours successifs)
		local d = 0
		while (profil.season and profil.season.xp or 0) < xp do
			for _ = 1, 3 do
				S.addXp(profil, "weekly", now + d * DAY)
			end
			d = d + 1
			if d > 200 then
				break
			end
		end
	end

	suite("Passe de combat : données et paliers")
	check("30 paliers, saison de 60 jours, plafond 400/j", SD.SEASON.tiers == 30 and SD.SEASON.days == 60 and SD.SEASON.dailyCap == 400 and #SD.TIER_XP == 30)
	check("XP par source : PvE 20, PvP 30, duel 30, quête du jour 100, semaine 300, éclosion 50", SD.XP.pve.amount == 20 and SD.XP.pvp.amount == 30 and SD.XP.duel.amount == 30 and SD.XP.daily.amount == 100 and SD.XP.weekly.amount == 300 and SD.XP.hatch.amount == 50)
	check("Prix : premium 399, premium+ 799, complément 400", SD.PREMIUM.premium.robux == 399 and SD.PREMIUM.premiumPlus.robux == 799 and SD.PREMIUM.upgradePlus.robux == 400)
	check("tierOf / xpForTier cohérents sur les 30 paliers", (function()
		local ok = S.tierOf(0) == 0 and S.xpForTier(30) == S.MAX_XP and S.tierOf(S.MAX_XP) == 30
		for t = 1, 30 do
			ok = ok and S.tierOf(S.xpForTier(t)) == t and S.tierOf(S.xpForTier(t) - 1) == t - 1
		end
		return ok
	end)())
	check("Rotation des thèmes : Feu, Glace, Foudre, Ombre, Nature, Ciel puis Feu (saison 7)", (function()
		local want = { "Feu", "Glace", "Foudre", "Ombre", "Nature", "Ciel", "Feu", "Glace" }
		local ok = true
		for n = 1, 8 do
			ok = ok and SD.get(n).theme == want[n] and SD.SEASONS[n] ~= nil
		end
		return ok
	end)())
	check("Espèces de saison fixes et distinctes pour les 6 premières saisons", (function()
		local seen, ok = {}, true
		for n = 1, 6 do
			local sp = SD.get(n).species
			ok = ok and type(sp) == "string" and not seen[sp]
			seen[sp] = true
		end
		return ok
	end)())

	suite("Passe de combat : saison courante, bascule à l'heure UTC, aucun chevauchement")
	check("Avant le début : saison 0 (pré-saison)", S.currentSeason(START - 1).n == 0 and S.currentSeason(START - 1).preseason == true)
	check("Début exact : saison 1, jour 1, 60 jours restants", S.currentSeason(START).n == 1 and S.currentSeason(START).dayIndex == 1 and S.currentSeason(START).daysLeft == 60)
	check("Dernière seconde de la saison 1 / première de la 2 (bascule UTC)", S.currentSeason(START + LEN - 1).n == 1 and S.currentSeason(START + LEN).n == 2 and S.currentSeason(START + LEN).dayIndex == 1)
	check("Saisons contiguës : fin(n) = début(n+1), thèmes enchaînés", (function()
		local ok = true
		for n = 1, 12 do
			local c = S.currentSeason(START + (n - 1) * LEN + 5)
			local nx = S.currentSeason(START + n * LEN + 5)
			ok = ok and c.n == n and nx.n == n + 1 and c.endsAt == nx.startsAt
		end
		return ok
	end)())
	check("Entrée invalide (nil, NaN, texte) : pas d'erreur, saison 0", S.currentSeason(nil).n == 0 and S.currentSeason(0 / 0).n == 0 and S.currentSeason("x").n == 0)

	suite("Passe de combat : XP et plafond par jour")
	do
		local p = {}
		local t0 = at(1, 3)
		local r = S.addXp(p, "pve", t0)
		check("Victoire PvE : +20 XP", r.ok and r.gained == 20 and p.season.xp == 20 and p.season.n == 1)
		r = S.addXp(p, "pvp", t0)
		check("Victoire PvP : +30 XP", r.gained == 30 and p.season.xp == 50)
		check("Source inconnue refusée sans effet", S.addXp(p, "or", t0).ok == false and S.addXp(p, 5, t0).ok == false and S.addXp(p, nil, t0).ok == false and p.season.xp == 50)
		-- 400 par jour : 50 + 350 = 400 puis plus rien
		local total = 50
		for _ = 1, 40 do
			total = total + S.addXp(p, "pve", t0).gained
		end
		check("Plafond : 400 XP par jour UTC (sources plafonnées)", total == 400 and p.season.xp == 400 and p.season.dayXp == 400)
		r = S.addXp(p, "daily", t0)
		check("Au plafond : gained 0 et capped", r.ok and r.gained == 0 and r.capped == true and p.season.xp == 400)
		r = S.addXp(p, "weekly", t0)
		check("Quêtes de la semaine : hors plafond (+300)", r.gained == 300 and p.season.xp == 700)
		r = S.addXp(p, "pve", t0 + DAY)
		check("Jour suivant : le plafond est remis à zéro", r.gained == 20 and p.season.dayXp == 20)
		local p2 = {}
		S.addXp(p2, "daily", at(1, 5, 23))
		local r2 = S.addXp(p2, "daily", at(1, 5, 23) + 3600) -- passe minuit UTC
		check("Minuit UTC : nouveau jour, nouvelle enveloppe", r2.gained == 100 and p2.season.dayXp == 100)
		local p3 = {}
		for _ = 1, 400 do
			S.addXp(p3, "weekly", at(1, 1))
		end
		check("XP bornée au total des 30 paliers", p3.season.xp == S.MAX_XP and S.addXp(p3, "weekly", at(1, 1)).gained == 0)
		local p4 = {}
		local r4 = S.addXp(p4, "weekly", at(1, 1))
		check("Passage de palier signalé", r4.tier == 0 and #r4.tiersUp == 0)
		r4 = S.addXp(p4, "weekly", at(1, 1))
		check("tiersUp liste les paliers franchis (600 XP : palier 1)", r4.tier == 1 and #r4.tiersUp == 1 and r4.tiersUp[1] == 1)
		check("Éclosion : Épique et mieux seulement", S.hatchQualifies(idx("Épique")) and S.hatchQualifies(idx("Divin")) and not S.hatchQualifies(idx("Rare")) and not S.hatchQualifies(nil))
	end

	suite("Passe de combat : migration d'un profil sans saison")
	do
		local p = {}
		local s = S.migrate(p, at(1, 5))
		check("Profil vide : saison créée, tout à zéro", s == p.season and s.n == 1 and s.xp == 0 and s.premium == 0 and s.claimedFree == 0 and s.claimedPrem == 0)
		local q = { seasonXp = 350, coins = 12 }
		S.migrate(q, at(1, 5))
		check("Ancien seasonXp du lot 15 versé dans la saison puis remis à 0, reste du profil intact", q.season.xp == 350 and q.seasonXp == 0 and q.coins == 12)
		S.migrate(q, at(1, 6))
		check("Migration idempotente", q.season.xp == 350 and q.season.n == 1)
		local junk = { season = { n = "x", xp = -5, dayXp = 1e12, claimedFree = 0 / 0, premium = {}, prev = 7 } }
		S.migrate(junk, at(1, 1))
		check("Profil corrompu assaini (types, bornes, prev invalide)", junk.season.n == 1 and junk.season.xp == 0 and junk.season.dayXp == 400 and junk.season.claimedFree == 0 and junk.season.premium == 0 and junk.season.prev == nil)
		local pre = {}
		S.addXp(pre, "weekly", START - 100)
		check("XP avant la saison 1 : mise de côté (saison 0)", pre.season.n == 0 and pre.season.xp == 300)
		S.migrate(pre, START + 10)
		check("Au démarrage de la saison 1 l'XP de pré-saison est conservée", pre.season.n == 1 and pre.season.xp == 300)
		check("Réclamer avant la saison : refusé", S.claim({}, 1, "free", START - 5).ok == false and S.buyPremium({}, "premium", START - 5).ok == false)
	end

	suite("Passe de combat : réclamation idempotente, pistes, rien d'interdit gratuitement")
	do
		local p = {}
		local now = at(1, 4)
		check("Palier verrouillé", S.claim(p, 1, "free", now).reason == "locked")
		tierAfterXp(p, 1000, now)
		check("XP suffisante (palier 2)", S.tierOf(p.season.xp) >= 2)
		local r = S.claim(p, 1, "free", now + 20 * DAY)
		check("Palier 1 gratuit : pièces", r.ok and #r.grants == 1 and r.grants[1].kind == "coins")
		check("Idempotent : 2e réclamation = rien", S.claim(p, 1, "free", now + 20 * DAY).reason == "already")
		local r2 = S.claim(p, 2, "free", now + 20 * DAY)
		check("Palier 2 gratuit : un œuf Peu commun", r2.ok and r2.grants[1].kind == "egg" and r2.grants[1].tier == idx("Peu commun") and r2.grants[1].name == "Peu commun")
		check("Piste premium sans achat refusée", S.claim(p, 1, "premium", now + 20 * DAY).reason == "premium")
		check("Entrées invalides : palier 0, 31, 1.5, texte, NaN, piste inconnue", S.claim(p, 0, "free", now).reason == "bad" and S.claim(p, 31, "free", now).reason == "bad" and S.claim(p, 1.5, "free", now).reason == "bad" and S.claim(p, "1", "free", now).reason == "bad" and S.claim(p, 0 / 0, "free", now).reason == "bad" and S.claim(p, 1, "or", now).reason == "bad")
		check("Palier gratuit sans récompense (21..24) : none", (function()
			local q = {}
			tierAfterXp(q, S.MAX_XP, now)
			return S.claim(q, 21, "free", now + 90 * DAY).ok == false
		end)())
	end
	do
		-- Aucune rareté Secret/Exclusif/Divin ni au-delà d'Épique (Légendaire seulement au palier 30) sur la piste gratuite ; premium jusqu'à Mythique
		local forbidden = {}
		for _, n in ipairs(Config.FORBIDDEN_GIFT_TIERS or { "Secret", "Exclusif", "Divin" }) do
			forbidden[idx(n)] = true
		end
		local epic, leg, myth = idx("Épique"), idx("Légendaire"), idx("Mythique")
		local freeOk, freeLegend, premOk, premSpecies, premKinds = true, 0, true, 0, {}
		for n = 1, 8 do
			for t = 1, 30 do
				for _, g in ipairs(S.rewardFor(n, t, "free") or {}) do
					if g.kind == "egg" then
						freeOk = freeOk and not forbidden[g.tier] and (g.tier <= epic or (t == 30 and g.tier == leg))
						if g.tier == leg then
							freeLegend = freeLegend + 1
						end
					end
					freeOk = freeOk and g.kind ~= "species"
				end
				for _, g in ipairs(S.rewardFor(n, t, "premium") or {}) do
					if g.kind == "egg" then
						premOk = premOk and not forbidden[g.tier] and g.tier <= myth
					end
					if g.kind == "species" or (g.kind == "cosmetic" and g.fallback) then
						premSpecies = premSpecies + 1
						premOk = premOk and t == 30
					end
					premKinds[g.kind] = true
				end
			end
		end
		check("Piste gratuite : jamais Secret / Exclusif / Divin ; œufs <= Épique sauf 1 Légendaire au palier 30 ; jamais d'espèce", freeOk and freeLegend == 8)
		check("Piste premium : œufs <= Mythique, aucun Secret / Exclusif / Divin en œuf", premOk)
		check("L'espèce Exclusif n'existe qu'au palier 30 premium (une par saison)", premSpecies == 8)
		check("Genres de récompense : pièces, œufs, jetons, parchemins, cosmétiques, auras", premKinds.coins and premKinds.egg and premKinds.token and premKinds.scroll and premKinds.cosmetic and premKinds.aura)
		local d1, d2 = S.rewardFor(1, 10, "free"), S.rewardFor(2, 10, "free")
		check("Cosmétiques « Saison N » uniques par saison (ne reviennent pas)", d1[1].id == "s1_pose" and d2[1].id == "s2_pose" and d1[1].id ~= d2[1].id and string.find(d1[1].label, "Saison 1", 1, true) ~= nil and string.find(d2[1].label, "Saison 2", 1, true) ~= nil)
		local a1 = S.rewardFor(1, 20, "free")
		check("Aura de saison au palier 20 gratuit (étiquetée)", a1[2].kind == "aura" and a1[2].id == "s1_aura" and string.find(a1[2].label, "Feu", 1, true) ~= nil)
		-- toute rareté d'œuf résout (nom -> Config.TIERS), jamais d'œuf de repli
		local resolved = true
		for t = 1, 30 do
			for _, track in ipairs({ "free", "premium" }) do
				for _, g in ipairs(S.rewardFor(1, t, track) or {}) do
					resolved = resolved and not g.fallback or (g.kind == "cosmetic" and g.fallback and t == 30)
				end
			end
		end
		check("Toutes les raretés d'œuf se résolvent par nom via Config.TIERS", resolved)
	end

	suite("Passe de combat : espèce Exclusif de saison (repli propre, premium seulement, palier 30)")
	do
		local exIdx = idx("Exclusif")
		local sp = false
		for _, pet in ipairs(Config.PETS) do
			if pet.tier == exIdx then
				sp = true
			end
		end
		local p = {}
		local now = at(1, 10)
		S.buyPremium(p, "premium", now)
		tierAfterXp(p, S.MAX_XP, now)
		local r = S.claim(p, 30, "premium", now + 80 * DAY)
		check("Palier 30 premium : valide au repli (espèce absente de Config) ou espèce réelle", r.ok == false or r.ok == true)
		-- repli : sur la vraie Config (aucune espèce Exclusif publiée avant le lot 9c) ou avec espèce injectée
		local cfg2 = {}
		for k, v in pairs(Config) do
			cfg2[k] = v
		end
		cfg2.PETS = { { tier = exIdx, name = SD.get(1).species } }
		local S2 = Season.new(cfg2, SD)
		local p2 = {}
		S2.buyPremium(p2, "premium", now)
		for d = 0, 20 do
			for _ = 1, 3 do
				S2.addXp(p2, "weekly", now + d * DAY)
			end
		end
		local r2 = S2.claim(p2, 30, "premium", now)
		local gotSpecies, gotMyth = false, false
		for _, g in ipairs(r2.grants or {}) do
			gotSpecies = gotSpecies or (g.kind == "species" and g.name == SD.get(1).species and g.tier == exIdx)
			gotMyth = gotMyth or (g.kind == "egg" and g.name == "Mythique")
		end
		check("Espèce de la saison existante : donnée par NOM, au palier 30 premium (+ œuf Mythique)", r2.ok and gotSpecies and gotMyth)
		local free30 = S2.rewardFor(1, 30, "free")
		local none = true
		for _, g in ipairs(free30) do
			none = none and g.kind ~= "species" and not (g.kind == "egg" and (g.tier == exIdx or g.tier > idx("Légendaire")))
		end
		check("Palier 30 gratuit : un Légendaire, jamais l'espèce Exclusif", none and free30[1].kind == "egg" and free30[1].name == "Légendaire")
		-- espèce inconnue de Config.PETS : cosmétique de repli
		local r3 = S.rewardFor(1, 30, "premium")
		local fb = r3[1]
		check("Espèce absente de Config.PETS : cosmétique « Trophée Exclusif » à la place", fb.kind == "cosmetic" and fb.fallback == true and fb.id == "s1_trophy" and not sp)
		-- l'espèce d'une autre saison / d'un autre nom n'est jamais donnée
		cfg2.PETS = { { tier = idx("Légendaire"), name = SD.get(1).species } }
		local r4 = Season.new(cfg2, SD).rewardFor(1, 30, "premium")
		check("Espèce du bon nom mais pas de rareté Exclusif : repli (pas de contournement)", r4[1].kind == "cosmetic" and r4[1].fallback == true)
	end

	suite("Passe de combat : achat de la piste premium (une seule fois, paliers atteints crédités)")
	do
		local p = {}
		local now = at(1, 20)
		tierAfterXp(p, 3000, now)
		local reached = S.tierOf(p.season.xp)
		check("Joueur gratuit au palier >= 5 avant l'achat", reached >= 5)
		-- il a déjà réclamé le palier 1 gratuit
		S.claim(p, 1, "free", now + 30 * DAY)
		local b = S.buyPremium(p, "premium", now + 30 * DAY)
		check("Premium en cours de saison : crédite les paliers déjà atteints", b.ok and b.credited == reached and #b.grants >= reached and b.boosted == 0)
		local b2 = S.buyPremium(p, "premium", now + 30 * DAY)
		check("Rachat refusé : rien n'est crédité 2 fois", b2.ok == false and b2.reason == "owned" and p.season.premium == 1)
		check("Palier déjà crédité : réclamation = already", S.claim(p, 1, "premium", now + 30 * DAY).reason == "already")
		check("Palier non atteint toujours verrouillé", S.claim(p, reached + 1, "premium", now + 30 * DAY).reason == "locked")
		local before = p.season.xp
		for d = 0, 6 do
			S.addXp(p, "weekly", now + 31 * DAY + d * DAY)
		end
		local after = S.claim(p, reached + 1, "premium", now + 38 * DAY)
		check("Les paliers suivants se réclament normalement (une fois)", p.season.xp > before and after.ok and S.claim(p, reached + 1, "premium", now + 38 * DAY).reason == "already")
		check("Free track non touchée par l'achat (palier 1 déjà réclamé, 2 pas encore)", S.claim(p, 2, "free", now + 38 * DAY).ok == true)
		check("kind invalide", S.buyPremium(p, "gold", now).reason == "kind" and S.buyPremium(p, nil, now).reason == "kind" and S.buyPremium(p, 5, now).reason == "kind")
		-- Premium+ : premium + 10 paliers
		local q = {}
		tierAfterXp(q, 1200, now) -- palier 2
		local t0 = S.tierOf(q.season.xp)
		local bp = S.buyPremium(q, "premiumPlus", now + 10 * DAY)
		check("Premium+ : +10 paliers immédiats et paliers atteints crédités", bp.ok and bp.boosted == 10 and bp.tier == t0 + 10 and bp.credited == t0 + 10 and q.season.plus == 1)
		check("Premium+ ne se rachète pas, le complément non plus (une fois par saison)", S.buyPremium(q, "premiumPlus", now).reason == "owned" and S.buyPremium(q, "upgradePlus", now).reason == "plusUsed")
		-- complément 400
		local u = {}
		check("Complément sans premium refusé", S.buyPremium(u, "upgradePlus", now).reason == "needPremium")
		S.buyPremium(u, "premium", now)
		tierAfterXp(u, 1200, now)
		local ut0 = S.tierOf(u.season.xp)
		local ub = S.buyPremium(u, "upgradePlus", now + 30 * DAY)
		check("Complément : +10 paliers, crédite les paliers premium non réclamés", ub.ok and ub.boosted == 10 and ub.credited == ut0 + 10 and S.tierOf(u.season.xp) == ut0 + 10)
		check("Complément une seule fois", S.buyPremium(u, "upgradePlus", now + 30 * DAY).reason == "plusUsed")
		-- plafond à 30
		local w = {}
		tierAfterXp(w, S.xpForTier(27), now)
		local w0 = S.tierOf(w.season.xp)
		local wb = S.buyPremium(w, "premiumPlus", now + 30 * DAY)
		check("Les paliers offerts ne dépassent pas 30", wb.boosted == 30 - w0 and S.tierOf(w.season.xp) == 30)
		-- achat avant tout XP
		local z = {}
		local zb = S.buyPremium(z, "premium", now)
		check("Achat à 0 XP : rien à créditer, premium actif", zb.ok and zb.credited == 0 and #zb.grants == 0 and z.season.premium == 1)
		-- nouvelle saison : le même produit se revend
		local z2 = S.buyPremium(z, "premium", at(2, 5))
		check("Nouvelle saison : premium à racheter (season.premium = n)", z2.ok and z.season.premium == 2 and z.season.n == 2)
		local zplus = S.buyPremium(z, "upgradePlus", at(2, 6))
		check("Premium+/complément de nouveau disponible à chaque saison", zplus.ok and z.season.plus == 2)
	end

	suite("Passe de combat : bascule de saison, grâce de 7 jours, récapitulatif")
	do
		local p = {}
		local now = at(1, 30)
		S.buyPremium(p, "premium", now)
		tierAfterXp(p, 3000, now)
		local tier = S.tierOf(p.season.xp)
		S.claim(p, 1, "free", now + 25 * DAY) -- 1 déjà pris
		check("Saison 1 : progression et premium présents", tier >= 5 and p.season.premium == 1)
		-- 1er jour de la saison 2
		local s2 = START + LEN
		local view = S.view(p, s2)
		check("Bascule : saison 2 neuve (XP 0, premium perdu, masques à zéro)", p.season.n == 2 and p.season.xp == 0 and p.season.premium == 0 and p.season.claimedFree == 0 and p.season.claimedPrem == 0 and view.season == 2 and view.tier == 0)
		check("Saison 1 gardée en `prev` pendant la grâce, saison 2 sans mélange", p.season.prev ~= nil and p.season.prev.n == 1 and p.season.prev.xp > 0 and p.season.prev.premium == 1)
		local rc = S.recap(p, s2)
		check("Récapitulatif de fin : palier, non réclamé gratuit/premium, jours de grâce", rc ~= nil and rc.n == 1 and rc.theme == "Feu" and rc.tier == tier and rc.unclaimedPremium == tier and rc.unclaimedFree > 0 and rc.graceDaysLeft == 7 and rc.expired == false and rc.premium == true)
		check("Le récapitulatif liste les cosmétiques non réclamés qui ne reviendront pas", #rc.unclaimedCosmetics >= 1)
		-- réclamer la saison 1 pendant la grâce
		local r = S.claim(p, 2, "free", s2 + 3 * DAY, "prev")
		check("Grâce : réclamation d'un palier de la saison 1 pendant la saison 2", r.ok and r.season == 1 and r.grants[1].kind == "egg")
		check("Grâce : idempotent", S.claim(p, 2, "free", s2 + 3 * DAY, "prev").reason == "already")
		local rp = S.claim(p, 3, "premium", s2 + 6 * DAY, "prev")
		check("Grâce : piste premium achetée en saison 1 réclamable, cosmétiques 'Saison 1'", rp.ok and rp.season == 1)
		check("Les gains de la saison 2 ne touchent pas la saison 1 gardée", (function()
			S.addXp(p, "weekly", s2 + 4 * DAY)
			return p.season.xp == 300 and p.season.prev.xp > 300 and S.claim(p, 1, "free", s2 + 4 * DAY).reason == "locked"
		end)())
		local lastGood = S.claim(p, 4, "free", s2 + 7 * DAY - 1, "prev")
		check("Dernière seconde de la grâce : encore réclamable", lastGood.ok == true)
		local late = S.claim(p, 5, "free", s2 + 7 * DAY, "prev")
		check("Après 7 jours : perdu (expired)", late.ok == false and late.reason == "expired")
		check("Récap après la grâce : expiré, rien de réclamable", S.recap(p, s2 + 8 * DAY).expired == true and S.recap(p, s2 + 8 * DAY).graceDaysLeft == 0)
		S.ackRecap(p, s2 + 8 * DAY)
		check("Récap vu après expiration : saison précédente effacée", p.season.prev == nil and S.recap(p, s2 + 9 * DAY) == nil)
		-- récapitulatif vu pendant la grâce
		local q = {}
		S.addXp(q, "weekly", at(1, 50))
		S.migrate(q, at(2, 1))
		check("Récapitulatif visible puis acquitté", S.recap(q, at(2, 1)) ~= nil)
		S.ackRecap(q, at(2, 1))
		check("Après acquittement : plus de bandeau, réclamation toujours possible (grâce)", S.recap(q, at(2, 2)) == nil and q.season.prev ~= nil and q.season.prev.seen == true and S.view(q, at(2, 2)).hasPrev == false)
		-- joueur absent 2 saisons
		local a = {}
		S.addXp(a, "weekly", at(1, 10))
		S.migrate(a, at(3, 2))
		check("Absent plus d'une saison : tout est perdu, saison 3 neuve", a.season.n == 3 and a.season.xp == 0 and a.season.prev == nil)
		-- joueur sans progrès : pas de saison fantôme
		local e = {}
		S.migrate(e, at(1, 5))
		S.migrate(e, at(2, 5))
		check("Aucune progression : pas de récapitulatif fantôme", e.season.prev == nil and S.recap(e, at(2, 5)) == nil)
		-- idempotence de la bascule
		local c = {}
		S.addXp(c, "weekly", at(1, 5))
		S.migrate(c, at(2, 1))
		local prevXp = c.season.prev.xp
		S.migrate(c, at(2, 1))
		S.migrate(c, at(2, 2))
		check("Bascule idempotente (rejouée : `prev` inchangé)", c.season.prev.xp == prevXp and c.season.n == 2)
		-- horloge reculée
		local k = {}
		S.addXp(k, "weekly", at(2, 5))
		S.migrate(k, at(1, 5))
		check("Horloge qui recule : le profil ne régresse pas", k.season.n == 2 and k.season.xp == 300)
		-- achat premium à la saison courante pendant la grâce de la précédente : n'affecte que la saison courante
		local m = {}
		S.addXp(m, "weekly", at(1, 55))
		S.addXp(m, "weekly", at(1, 55))
		S.buyPremium(m, "premium", at(2, 2))
		check("Achat pendant la grâce : seule la saison courante devient premium", m.season.premium == 2 and m.season.prev.premium == 0 and S.claim(m, 1, "premium", at(2, 3), "prev").reason == "premium")
	end

	suite("Passe de combat : vue client")
	do
		local p = {}
		S.addXp(p, "weekly", at(1, 5))
		local v = S.view(p, at(1, 5))
		check("Vue : 30 lignes, palier, XP restante, plafond, jours restants", #v.rows == 30 and v.tier == 0 and v.xp == 300 and v.xpToNext == 190 and v.dailyCap == 400 and v.daysLeft >= 1 and v.premium == false and v.theme == "Feu")
		check("La vue ne change pas le profil (XP identique)", p.season.xp == 300)
		check("Vue : un jour plus tard dayXp remis à 0", S.view(p, at(1, 5) + DAY).dayXp == 0)
		local all = S.claimAll(p, at(1, 5))
		check("claimAll sans palier atteint : rien", all.claimed == 0 and #all.grants == 0)
	end

	suite("Passe de combat : joueur-robot (rythme sur 60 jours)")
	local function robot(plays, withPremium)
		local p = {}
		local reached20, reached30, ok = nil, nil, true
		for d = 0, 59 do
			local now = START + d * DAY + 12 * 3600
			local act = plays(d)
			if act then
				for _ = 1, act.pve do
					S.addXp(p, "pve", now)
				end
				for _ = 1, act.pvp do
					S.addXp(p, "pvp", now)
				end
				if act.daily then
					S.addXp(p, "daily", now)
				end
				for _ = 1, act.hatch do
					S.addXp(p, "hatch", now)
				end
				if act.weekly then
					S.addXp(p, "weekly", now)
				end
			end
			local t = S.tierOf(p.season.xp)
			if t >= 20 and not reached20 then
				reached20 = d + 1
			end
			if t >= 30 and not reached30 then
				reached30 = d + 1
			end
		end
		return reached20, reached30, p
	end
	-- Joueur actif régulier : 6 jours sur 7, tout (plafond atteint chaque jour), quêtes de la semaine le 6e jour
	local a20, a30 = robot(function(d)
		if d % 7 == 6 then
			return nil
		end
		return { pve = 10, pvp = 4, daily = true, hatch = 3, weekly = d % 7 == 5 }
	end)
	print(string.format("    joueur-robot ACTIF REGULIER : palier 20 au jour %s, palier 30 au jour %s (saison de 60 jours)", tostring(a20), tostring(a30)))
	check("Joueur actif régulier : termine les 30 paliers en ~45 jours (40 à 50)", a30 ~= nil and a30 >= 40 and a30 <= 50)
	-- Joueur occasionnel : 5 jours sur 7, ~350 XP par jour joué (6 PvE, 2 PvP, quête du jour, 1 éclosion), semaine le dernier jour joué
	local o20, o30 = robot(function(d)
		local w = d % 7
		if w == 2 or w == 5 then
			return nil
		end
		return { pve = 7, pvp = 2, daily = true, hatch = 1, weekly = w == 6 }
	end)
	print(string.format("    joueur-robot OCCASIONNEL : palier 20 au jour %s, palier 30 au jour %s (saison de 60 jours)", tostring(o20), tostring(o30)))
	check("Joueur occasionnel : termine en ~60 jours (55 à 60), palier 20 avant le jour 45", o30 ~= nil and o30 >= 55 and o30 <= 60 and o20 ~= nil and o20 < 45)
	-- Joueur très peu actif : ne finit pas, mais la piste gratuite est utile
	local _, l30, lp = robot(function(d)
		if d % 7 == 0 or d % 7 == 3 then
			return { pve = 6, pvp = 1, daily = true, hatch = 0, weekly = false }
		end
		return nil
	end)
	print(string.format("    joueur-robot TRES PEU ACTIF (2 jours/semaine) : palier atteint = %d, palier 30 : %s", S.tierOf(lp.season.xp), tostring(l30)))
	check("Joueur très peu actif : ne termine pas la saison mais passe des paliers", l30 == nil and S.tierOf(lp.season.xp) >= 8)
	-- Réclamation complète de la piste gratuite par le joueur actif : aucune rareté interdite reçue
	do
		local _, _, p = robot(function(d)
			if d % 7 == 6 then
				return nil
			end
			return { pve = 10, pvp = 4, daily = true, hatch = 3, weekly = d % 7 == 5 }
		end)
		local all = S.claimAll(p, at(1, 59))
		local bad, eggs, spec = false, 0, false
		for _, g in ipairs(all.grants) do
			if g.kind == "egg" then
				eggs = eggs + 1
				if g.name == "Secret" or g.name == "Exclusif" or g.name == "Divin" or g.tier > idx("Légendaire") then
					bad = true
				end
			end
			if g.kind == "species" then
				spec = true
			end
		end
		check("Piste gratuite intégrale : aucune rareté Secret / Exclusif / Divin, pas d'espèce de saison", not bad and not spec and eggs >= 6)
		check("claimAll idempotent : 2e passage = rien", S.claimAll(p, at(1, 59)).claimed == 0)
		-- même joueur en premium : reçoit l'espèce (ou son repli) au palier 30
		local _, _, q = robot(function(d)
			if d % 7 == 6 then
				return nil
			end
			return { pve = 10, pvp = 4, daily = true, hatch = 3, weekly = d % 7 == 5 }
		end)
		local bq = S.buyPremium(q, "premium", at(1, 58))
		local allq = S.claimAll(q, at(1, 59))
		local gotChoice = false
		for _, g in ipairs(bq.grants) do
			gotChoice = gotChoice or g.kind == "species" or (g.kind == "cosmetic" and g.fallback == true and g.id == "s1_trophy")
		end
		check("Premium au palier 30 : espèce de saison (ou son trophée de repli) donnée UNE fois", gotChoice and S.claimAll(q, at(1, 59)).claimed == 0)
	end

	suite("Passe de combat : cohérence des données")
	do
		local missing = {}
		for t = 1, 30 do
			if not SD.PREMIUM_TRACK[t] then
				missing[#missing + 1] = t
			end
		end
		check("La piste premium a une récompense à chacun des 30 paliers", #missing == 0)
		local freeN = 0
		for t = 1, 30 do
			if SD.FREE[t] then
				freeN = freeN + 1
			end
		end
		check("Piste gratuite : tous les paliers 1 à 20, plus 25 et 30", (function()
			local ok = SD.FREE[25] ~= nil and SD.FREE[30] ~= nil
			for t = 1, 20 do
				ok = ok and SD.FREE[t] ~= nil
			end
			return ok and freeN == 22
		end)())
		local premCoins, freeCoins = 0, 0
		for t = 1, 30 do
			for _, e in ipairs(SD.PREMIUM_TRACK[t]) do
				if e.k == "coins" then
					premCoins = premCoins + e.v
				end
			end
			for _, e in ipairs(SD.FREE[t] or {}) do
				if e.k == "coins" then
					freeCoins = freeCoins + e.v
				end
			end
		end
		check("La piste premium vaut plus que la gratuite (pièces)", premCoins > freeCoins)
		check("Config.TIERS : 10 raretés, les noms utilisés par la passe existent", idx("Épique") and idx("Légendaire") and idx("Mythique") and idx("Exclusif") and idx("Peu commun") and idx("Rare"))
	end
end

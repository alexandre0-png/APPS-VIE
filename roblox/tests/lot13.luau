--!nocheck
-- Tests du lot 13 (duel local, ligues, ratio d'intro). Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime }.
-- Charge ReplicatedStorage/Duel.lua et IntroPlan.lua (lot 10). Config.DUEL / Config.LEAGUES sont lus dans le texte de Config.lua s'ils y sont (patch 01 appliqué), sinon valeurs de la spec.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name })()
	end
	local Duel = load("roblox/src/ReplicatedStorage/Duel.lua", "Duel")
	local IntroPlan = load("roblox/src/ReplicatedStorage/IntroPlan.lua", "IntroPlan")
	local CFG = { range = 30, requestTimeout = 20, sameTargetCooldown = 120, rewardedPerDay = 10, samePairRewardedPerDay = 3, turnSeconds = 10, afkTurnsToForfeit = 2, coinsWinMins = 1, coinsLoseMins = 0.25 }
	local LEAGUES = { { name = "Bronze", icon = "B", min = 0 }, { name = "Argent", icon = "A", min = 300 }, { name = "Or", icon = "O", min = 600 }, { name = "Diamant", icon = "D", min = 1000 }, { name = "Champion", icon = "C", min = 1500 } }

	local function flags(id, o)
		local t = { userId = id, carryingEgg = false, chased = false, inDialogue = false, inCastle = false, newbie = false, busy = false }
		for k, v in pairs(o or {}) do
			t[k] = v
		end
		return t
	end
	local function ctx(a, b, dist)
		return { a = a or flags(1), b = b or flags(2), distance = dist or 10 }
	end

	suite("Lot 13 : Config (patch 01) si présent")
	local cfgText = fs.readFile("roblox/src/ReplicatedStorage/Config.lua")
	local patched = cfgText:find("Config.LEAGUES = {", 1, true) ~= nil
	if patched then
		local block = cfgText:match("Config%.LEAGUES = (%b{})")
		local mins = {}
		for m in block:gmatch("min = (%d+)") do
			mins[#mins + 1] = tonumber(m)
		end
		check("Config.LEAGUES : 5 ligues, seuils 0 300 600 1000 1500", #mins == 5 and mins[1] == 0 and mins[2] == 300 and mins[3] == 600 and mins[4] == 1000 and mins[5] == 1500)
		local d = cfgText:match("Config%.DUEL = (%b{})")
		local ok = d ~= nil
		for k, v in pairs(CFG) do
			if ok and not d:find(k .. " = " .. tostring(v):gsub("%.", "%%."), 1) then
				ok = false
			end
		end
		check("Config.DUEL : valeurs de E.2 (range 30, 20 s, 120 s, 10/jour, 3/paire, tours 10 s, 2 forfaits, 1 min / 0,25 min)", ok)
		check("Config.LEAGUE_SEASON : 5 paliers de récompense, dernier à 1500 avec titre", cfgText:match("Config%.LEAGUE_SEASON = (%b{})"):find('title = "Champion', 1, true) ~= nil)
		local ls = cfgText:match("Config%.LEAGUE_SEASON = (%b{})")
		check("Palier 1500 (décision utilisateur) : œuf Mythique désigné par son NOM, potion 30 min, aucune pièce, plus de montant inventé", ls:find('trophies = 1500, coins = 0, eggName = "Mythique", potionSeconds = 30 * 60', 1, true) ~= nil and ls:find("1000000", 1, true) == nil and ls:find("eggTier = 7", 1, true) == nil)
	else
		check("Config.lua non patché : tests de données Config ignorés (valeurs de la spec utilisées)", true)
	end

	suite("Lot 13 : défi refusé dans chacun des 6 cas de E.2")
	check("Cas de base : deux joueurs libres à 10 studs -> accepté", Duel.canChallenge(ctx(), CFG) == true)
	local cases = {
		{ "1 distance > 30 studs", ctx(nil, nil, 30.5), "range" },
		{ "2 le défieur porte un œuf", ctx(flags(1, { carryingEgg = true })), "egg" },
		{ "2b le défié porte un œuf", ctx(nil, flags(2, { carryingEgg = true })), "egg" },
		{ "3 poursuivi (défieur)", ctx(flags(1, { chased = true })), "chased" },
		{ "3b poursuivi (défié)", ctx(nil, flags(2, { chased = true })), "chased" },
		{ "4 en dialogue", ctx(nil, flags(2, { inDialogue = true })), "dialogue" },
		{ "4b en dialogue (défieur)", ctx(flags(1, { inDialogue = true })), "dialogue" },
		{ "5 mode Château", ctx(flags(1, { inCastle = true })), "castle" },
		{ "5b mode Château (défié)", ctx(nil, flags(2, { inCastle = true })), "castle" },
		{ "6 protection débutant active", ctx(nil, flags(2, { newbie = true })), "newbie" },
		{ "6b protection débutant (défieur)", ctx(flags(1, { newbie = true })), "newbie" },
		{ "extra : soi-même", ctx(flags(1), flags(1)), "self" },
		{ "extra : déjà en combat", ctx(nil, flags(2, { busy = true })), "busy" },
	}
	for i = 1, #cases do
		local c = cases[i]
		local ok, why = Duel.canChallenge(c[2], CFG)
		check("Refus " .. c[1] .. " -> " .. c[3], ok == false and why == c[3])
	end
	check("Distance exactement 30 studs : accepté ; négative ou NaN : refusé", Duel.canChallenge(ctx(nil, nil, 30), CFG) == true and Duel.canChallenge(ctx(nil, nil, -1), CFG) == false and Duel.canChallenge(ctx(nil, nil, 0 / 0), CFG) == false)
	check("Côté fautif renvoyé (défieur / défié)", select(3, Duel.canChallenge(ctx(flags(1, { chased = true })), CFG)) == "a" and select(3, Duel.canChallenge(ctx(nil, flags(2, { chased = true })), CFG)) == "b")
	check("Entrées invalides : jamais d'erreur", Duel.canChallenge(nil) == false and Duel.canChallenge({}) == false and Duel.canChallenge({ a = {}, b = {}, distance = "x" }) == false)

	suite("Lot 13 : carnet des défis (délai, cooldown, un seul accepté)")
	local book = Duel.newBook()
	check("Défi 1 -> 2 envoyé", Duel.request(book, ctx(flags(1), flags(2)), 100, CFG) == true)
	local okAgain, whyAgain = Duel.request(book, ctx(flags(1), flags(2)), 105, CFG)
	check("Même défi renvoyé trop tôt : refusé", okAgain == false and (whyAgain == "cooldown" or whyAgain == "pendingOut"))
	check("Délai de 20 s : réponse à 121 s -> expiré, aucun duel", select(1, Duel.answer(book, 2, 1, true, 121, CFG)) == false and book.pending[1] == nil and next(book.active) == nil)
	local okCd, whyCd = Duel.request(book, ctx(flags(1), flags(2)), 150, CFG)
	check("Cooldown même cible 120 s : 50 s après -> refusé", okCd == false and whyCd == "cooldown")
	check("Cooldown écoulé (221 s) -> accepté", Duel.request(book, ctx(flags(1), flags(2)), 221, CFG) == true)

	local b2 = Duel.newBook()
	check("Deux défis simultanés vers la même cible B : les deux envoyés", Duel.request(b2, ctx(flags(1), flags(2)), 10, CFG) == true and Duel.request(b2, ctx(flags(3), flags(2)), 11, CFG) == true)
	local ok1, id1, cancelled = Duel.answer(b2, 2, 1, true, 12, CFG)
	check("B accepte A : un duel démarre, l'autre défi est annulé", ok1 == true and type(id1) == "number" and #cancelled == 1 and cancelled[1].from == 3 and b2.pending[3] == nil)
	local ok3, why3 = Duel.answer(b2, 2, 3, true, 13, CFG)
	check("B ne peut plus accepter C (un seul défi accepté)", ok3 == false and (why3 == "none" or why3 == "busy") and b2.active[3] == nil)
	local okBusy, whyBusy = Duel.request(b2, ctx(flags(3), flags(1)), 14, CFG)
	check("Pendant le duel, nouveau défi vers un joueur actif refusé (busy)", okBusy == false and whyBusy == "busy")
	Duel.finish(b2, 1)
	check("Fin du duel : les deux libérés", b2.active[1] == nil and b2.active[2] == nil)
	-- Simultané inverse : A défie B pendant que B défie A
	local b3 = Duel.newBook()
	Duel.request(b3, ctx(flags(1), flags(2)), 0, CFG)
	Duel.request(b3, ctx(flags(2), flags(1)), 1, CFG)
	local okx, idx, canx = Duel.answer(b3, 2, 1, true, 2, CFG)
	check("Défis croisés A->B et B->A : un seul duel, l'autre annulé", okx == true and #canx == 1 and b3.pending[2] == nil)
	local b4 = Duel.newBook()
	Duel.request(b4, ctx(flags(1), flags(2)), 0, CFG)
	check("Refus : défi retiré, aucun duel ; mauvaise cible ignorée", Duel.answer(b4, 9, 1, true, 1, CFG) == false and b4.pending[1] ~= nil and Duel.answer(b4, 2, 1, false, 1, CFG) == false and b4.pending[1] == nil and next(b4.active) == nil)
	local b5 = Duel.newBook()
	Duel.request(b5, ctx(flags(1), flags(2)), 0, CFG)
	check("État relu à l'acceptation : défié devenu poursuivi -> refusé", Duel.answer(b5, 2, 1, true, 1, CFG, ctx(flags(1), flags(2, { chased = true }))) == false and next(b5.active) == nil)
	local b6 = Duel.newBook()
	Duel.request(b6, ctx(flags(1), flags(2)), 0, CFG)
	Duel.request(b6, ctx(flags(5), flags(2)), 0, CFG)
	Duel.request(b6, ctx(flags(6), flags(2)), 0, CFG)
	check("Plafond de 3 défis en attente par cible", Duel.request(b6, ctx(flags(7), flags(2)), 0, CFG) == false)
	local gone = Duel.expire(b6, 30, CFG)
	check("expire() retire les défis > 20 s", #gone == 3 and next(b6.pending) == nil)
	Duel.request(b6, ctx(flags(1), flags(2)), 1000, CFG)
	Duel.prune(b6, 1200, CFG)
	check("prune() vide les cooldowns périmés (pas de croissance)", next(b6.last) == nil)
	Duel.request(b6, ctx(flags(8), flags(2)), 2000, CFG)
	Duel.finish(b6, 8)
	check("Joueur qui quitte : son défi en attente est retiré", b6.pending[8] == nil)

	suite("Lot 13 : 2 tours inactifs = forfait")
	local m = Duel.newMatch(1, 2)
	check("Tour 1 : A inactif -> on continue", Duel.noteTurn(m, false, true, CFG) == "continue" and m.afkA == 1)
	check("Tour 2 : A inactif de nouveau -> forfait de A, B gagne", Duel.noteTurn(m, false, true, CFG) == "forfeitA" and m.over and m.winner == "b")
	local m2 = Duel.newMatch(1, 2)
	Duel.noteTurn(m2, false, true, CFG)
	Duel.noteTurn(m2, true, true, CFG)
	check("Une action entre deux remet le compteur à 0 (pas de forfait)", m2.afkA == 0 and Duel.noteTurn(m2, false, true, CFG) == "continue")
	local m3 = Duel.newMatch(1, 2)
	Duel.noteTurn(m3, true, false, CFG)
	check("Forfait de B : A gagne", Duel.noteTurn(m3, true, false, CFG) == "forfeitB" and m3.winner == "a")
	local m4 = Duel.newMatch(1, 2)
	Duel.noteTurn(m4, false, false, CFG)
	check("Les deux inactifs 2 tours : annulé, pas de vainqueur", Duel.noteTurn(m4, false, false, CFG) == "cancelled" and m4.winner == nil)
	check("Match fini : noteTurn n'a plus d'effet", Duel.noteTurn(m, true, true, CFG) == "continue" and m.turns == 2)
	local oa, ob = Duel.outcomes(m)
	local na, nb = Duel.outcomes(m4)
	check("Issues : forfait A = loss/win ; annulé = draw/draw", oa == "loss" and ob == "win" and na == "draw" and nb == "draw")
	check("Seuil configurable : 3 tours", (function()
		local mm = Duel.newMatch(1, 2)
		local c3 = { afkTurnsToForfeit = 3 }
		return Duel.noteTurn(mm, false, true, c3) == "continue" and Duel.noteTurn(mm, false, true, c3) == "continue" and Duel.noteTurn(mm, false, true, c3) == "forfeitA"
	end)())

	suite("Lot 13 : valeurs par défaut du module = E.2")
	local md = Duel.newMatch(1, 2)
	Duel.noteTurn(md, false, true)
	local sd = Duel.cleanState({}, 20000)
	local nd = 0
	for _ = 1, 5 do
		if Duel.settle(sd, 9, "win", 86400 * 20000, 10).rewarded then
			nd = nd + 1
		end
	end
	check("Sans cfg : forfait au 2e tour inactif, 3 récompenses par paire, 100 studs refusé, 30 accepté", Duel.noteTurn(md, false, true) == "forfeitA" and nd == 3 and Duel.canChallenge(ctx(nil, nil, 31)) == false and Duel.canChallenge(ctx(nil, nil, 30)) == true)
	check("cfg invalide (texte, NaN) ignorée : valeurs par défaut", Duel.canChallenge(ctx(nil, nil, 31), { range = "x" }) == false and Duel.canChallenge(ctx(nil, nil, 31), { range = 0 / 0 }) == false and Duel.canChallenge(ctx(nil, nil, 31), { range = 40 }) == true)

	suite("Lot 13 : récompenses 10/jour, 3/paire, ratio V/D")
	local DAY = 86400 * 20000
	local st = Duel.cleanState({}, 20000)
	local r1 = Duel.settle(st, 77, "win", DAY + 10, 100, CFG)
	check("Victoire : récompense = revenus de 1 min (100/s -> 6000)", r1.rewarded and r1.coins == 6000 and st.w == 1 and st.n == 1)
	local r2 = Duel.settle(st, 77, "loss", DAY + 20, 100, CFG)
	check("Défaite : revenus de 15 s (1500)", r2.rewarded and r2.coins == 1500 and st.l == 1 and st.n == 2)
	local r3 = Duel.settle(st, 77, "win", DAY + 30, 100, CFG)
	local r4 = Duel.settle(st, 77, "win", DAY + 40, 100, CFG)
	check("3 duels contre la même paire récompensés, le 4e non (pairCap) mais compté au ratio", r3.rewarded and r4.rewarded == false and r4.reason == "pairCap" and r4.coins == 0 and st.w == 3 and st.n == 3)
	local other = Duel.settle(st, 88, "win", DAY + 50, 100, CFG)
	check("Autre adversaire : encore récompensé", other.rewarded == true and st.n == 4)
	-- quota 10/jour : adversaires différents
	local st2 = Duel.cleanState({}, 20000)
	local rewarded, last = 0, nil
	for i = 1, 14 do
		last = Duel.settle(st2, 1000 + i, "win", DAY + i, 50, CFG)
		if last.rewarded then
			rewarded = rewarded + 1
		end
	end
	check("14 duels contre 14 adversaires : 10 récompensés, 4 refusés (dayCap), 14 victoires au ratio", rewarded == 10 and last.reason == "dayCap" and st2.w == 14 and st2.n == 10)
	local before = st2.n
	local nextDay = Duel.settle(st2, 1001, "win", DAY + 86400 + 5, 50, CFG)
	check("Jour suivant (UTC) : compteurs remis à zéro, paires aussi", nextDay.rewarded and st2.n == 1 and st2.day == 20001 and before == 10 and next(st2.pairs) == "1001" and st2.w == 15)
	local st3 = Duel.cleanState({ w = 5, l = 2, day = 20000, n = 4, pairs = { ["9"] = 3 } }, 20000)
	check("cleanState conserve le jour courant, jette les paires d'un ancien jour", st3.n == 4 and st3.pairs["9"] == 3 and Duel.cleanState({ w = 5, day = 19999, n = 9, pairs = { ["9"] = 3 } }, 20000).n == 0 and next(Duel.cleanState({ day = 19999, pairs = { ["9"] = 3 } }, 20000).pairs) == nil)
	local st4 = { w = 0, l = 0, day = 20000, n = 0, pairs = {} }
	local dr = Duel.settle(st4, 5, "draw", DAY, 100, CFG)
	check("Annulé/nul : ni ratio, ni récompense, ni quota", dr.rewarded == false and st4.w == 0 and st4.l == 0 and st4.n == 0)
	check("Revenu invalide (négatif, NaN, texte) : 0 pièce sans erreur", Duel.coins(-5, 1) == 0 and Duel.coins(0 / 0, 1) == 0 and Duel.coins("x", 1) == 0 and Duel.coins(10, 0) == 0)
	check("Plafond de pièces", Duel.coins(1e15, 1) == 1e12)
	check("settle avec état nil/invalide : pas d'erreur", pcall(Duel.settle, nil, 1, "win", DAY, 10, CFG) and pcall(Duel.settle, "x", nil, "win", nil, nil, nil))
	-- ratio exact
	check("Ratio 124 V / 37 D = 77 %", Duel.record(124, 37) == "124 V / 37 D (77 %)" and Duel.percent(124, 37) == 77)
	check("Ratio arrondi : 1/3 -> 33, 2/3 -> 67, 1/2 -> 50, 1/8 -> 13 (12,5 arrondi vers le haut)", Duel.percent(1, 2) == 33 and Duel.percent(2, 1) == 67 and Duel.percent(1, 1) == 50 and Duel.percent(1, 7) == 13)
	check("Ratio 0/0 = 0 % ; invalides = 0", Duel.percent(0, 0) == 0 and Duel.record(nil, "x") == "0 V / 0 D (0 %)" and Duel.percent(-3, 0 / 0) == 0)
	local same = true
	for w = 0, 60 do
		for l = 0, 60 do
			if Duel.percent(w, l) ~= IntroPlan.percent(w, l) or Duel.record(w, l) ~= IntroPlan.record(w, l) then
				same = false
			end
		end
	end
	check("Duel.percent/record identiques à IntroPlan (3721 couples)", same)
	check("Ratio : 100 % si aucune défaite, jamais > 100", Duel.percent(50, 0) == 100 and Duel.percent(1e12, 0) <= 100)

	suite("Lot 13 : aucun trophée en duel local")
	local battle = { pvp = { season = 3, trophies = 250, wins = 10, losses = 4, defense = {}, day = 1, fights = 2 }, duel = { w = 0, l = 0, day = 20000, n = 0, pairs = {} } }
	local snapshot = { battle.pvp.season, battle.pvp.trophies, battle.pvp.wins, battle.pvp.losses, battle.pvp.day, battle.pvp.fights }
	local res = Duel.settle(battle.duel, 42, "win", DAY, 100, CFG)
	Duel.settle(battle.duel, 42, "loss", DAY, 100, CFG)
	local same2 = snapshot[1] == battle.pvp.season and snapshot[2] == battle.pvp.trophies and snapshot[3] == battle.pvp.wins and snapshot[4] == battle.pvp.losses and snapshot[5] == battle.pvp.day and snapshot[6] == battle.pvp.fights
	check("Un duel gagné et perdu ne modifie ni trophées, ni V/D classé, ni combats du jour", same2 and battle.duel.w == 1 and battle.duel.l == 1)
	local noTrophy = true
	for k in pairs(res) do
		if tostring(k):lower():find("troph") or tostring(k):lower():find("pvp") then
			noTrophy = false
		end
	end
	check("Le résultat de settle n'a aucun champ trophée", noTrophy and res.coins ~= nil)
	local dw, dl = Duel.recordFor("duel", battle)
	local pw, pl = Duel.recordFor("pvp", battle)
	check("Ratios séparés : duel 1/1, classé 10/4", dw == 1 and dl == 1 and pw == 10 and pl == 4)

	suite("Lot 13 : ligues et saison (E.4)")
	local function lg(t)
		return (Duel.league(LEAGUES, t)).name
	end
	check("Seuils : 0 Bronze, 299 Bronze, 300 Argent, 599 Argent, 600 Or, 999 Or, 1000 Diamant, 1499 Diamant, 1500 Champion, 99999 Champion",
		lg(0) == "Bronze" and lg(299) == "Bronze" and lg(300) == "Argent" and lg(599) == "Argent" and lg(600) == "Or" and lg(999) == "Or" and lg(1000) == "Diamant" and lg(1499) == "Diamant" and lg(1500) == "Champion" and lg(99999) == "Champion")
	check("Trophées négatifs, NaN, nil -> Bronze ; liste invalide -> nil sans erreur", lg(-50) == "Bronze" and lg(0 / 0) == "Bronze" and lg(nil) == "Bronze" and Duel.league(nil, 5) == nil and Duel.leagueText(nil, 5) == "")
	check("Texte de ligue pour l'intro (icône + nom, <= 16 caractères)", Duel.leagueText(LEAGUES, 700) == "O Or" and #Duel.leagueText(LEAGUES, 1600) <= 16)
	check("Index de ligue renvoyé", select(2, Duel.league(LEAGUES, 650)) == 3)
	check("Remise de saison : <= 300 inchangé ; 301 -> 300 ; 1000 -> 600 ; 1500 -> 900 ; jamais sous 300 au-delà", Duel.seasonReset(0) == 0 and Duel.seasonReset(300) == 300 and Duel.seasonReset(301) == 300 and Duel.seasonReset(1000) == 600 and Duel.seasonReset(1500) == 900 and Duel.seasonReset(-4) == 0 and Duel.seasonReset(0 / 0) == 0)
	local rewards = { { trophies = 100, coins = 5000 }, { trophies = 300, coins = 25000 }, { trophies = 600, coins = 100000 }, { trophies = 1000, coins = 400000 }, { trophies = 1500, coins = 1000000, title = "T" } }
	check("Récompense de saison : 99 -> aucune ; 100 -> 5000 ; 599 -> 25000 ; 1500 -> titre", Duel.seasonReward(rewards, 99) == nil and Duel.seasonReward(rewards, 100).coins == 5000 and Duel.seasonReward(rewards, 599).coins == 25000 and Duel.seasonReward(rewards, 1500).title == "T" and Duel.seasonReward(nil, 5) == nil)

	suite("Lot 13 : intro de combat (B.4) avec IntroPlan du lot 10")
	local battleP = { pvp = { wins = 100, losses = 30 }, live = { w = 24, l = 7 }, duel = { w = 3, l = 1 }, pve = { w = 9, l = 1 }, best = 12 }
	local w1, l1 = Duel.recordFor("pvp", battleP)
	check("Ratio classé = pvp + live (124 V / 37 D)", w1 == 124 and l1 == 37 and Duel.record(w1, l1) == "124 V / 37 D (77 %)")
	local w2, l2 = Duel.recordFor("duel", battleP)
	local w3, l3 = Duel.recordFor("pve", battleP)
	local w4, l4 = Duel.recordFor("tower", battleP)
	local w5, l5 = Duel.recordFor("npc", { wins = 312, losses = 140 })
	check("Ratios duel 3/1, pve 9/1, tour 12/0, PNJ 312/140", w2 == 3 and l2 == 1 and w3 == 9 and l3 == 1 and w4 == 12 and l4 == 0 and w5 == 312 and l5 == 140)
	local wz, lz = Duel.recordFor("inconnu", nil)
	local wy, ly = Duel.recordFor("pvp", { pvp = "x", live = 5 })
	check("Mode inconnu ou profil invalide : 0/0 sans erreur", wz == 0 and lz == 0 and wy == 0 and ly == 0)
	local me = Duel.introSide("duel", battleP, { name = "Moi", userId = 7, trophies = 650, pets = { { type = "Feu", odds = 100, tier = 2 } } }, LEAGUES)
	local foe = Duel.introSide("npc", { wins = 312, losses = 140 }, { name = "Lina" }, LEAGUES)
	local plan = IntroPlan.plan({ mode = "duel", countdown = true, advantage = 1.5, me = me, foe = foe }, {})
	check("IntroPlan reçoit le ratio de duel, la ligue et les trophées du joueur", plan.left.record == "3 V / 1 D (75 %)" and plan.left.league == "O Or" and plan.left.trophies == 650 and plan.left.userId == 7)
	check("PNJ : ratio fictif fixe « 312 V / 140 D (69 %) »", plan.right.record == "312 V / 140 D (69 %)" and plan.right.name == "Lina")
	check("Plan cohérent (3 s max, prises dans la durée)", select(1, IntroPlan.check(plan)) == true and plan.duration <= 3 and plan.arrow ~= nil)
	check("Intro sans profil : pas d'erreur", pcall(Duel.introSide, "pvp", nil, nil, nil) and pcall(IntroPlan.plan, { me = Duel.introSide("pvp", nil, nil, nil) }, {}))

	suite("Lot 13 (intégration) : vol / éclosion refusés, vues en miroir, intention du client, pièces après départ")
	do
		local okF, whyF, sideF = Duel.canChallenge(ctx(flags(1, { flying = true })), CFG)
		local okC, whyC, sideC = Duel.canChallenge(ctx(nil, flags(2, { inCinematic = true })), CFG)
		check("Vol d'œuf (défieur) et grande éclosion (défié) : refusés avec leur raison et le bon côté", okF == false and whyF == "flying" and sideF == "a" and okC == false and whyC == "cinematic" and sideC == "b")
		local v = { turn = 3, over = true, winner = 1, sides = { { active = 1, units = { { p = 1 } } }, { active = 2, units = { { p = 9 } } } } }
		local m = Duel.mirrorView(v)
		check("mirrorView : camps inversés, vainqueur inversé, original intact", m.sides[1].units[1].p == 9 and m.sides[2].units[1].p == 1 and m.winner == 2 and m.turn == 3 and v.sides[1].units[1].p == 1 and v.winner == 1)
		check("mirrorView : nul (winner nil) reste nil ; entrée invalide renvoyée telle quelle", Duel.mirrorView({ sides = { 1, 2 } }).winner == nil and Duel.mirrorView(nil) == nil and Duel.mirrorView(5) == 5)
		local ev = Duel.mirrorEvents({ { t = "hit", side = 1, dmg = 5 }, { t = "turn", n = 2 }, { t = "ko", side = 2 } })
		check("mirrorEvents : côtés 1 <-> 2, autres champs gardés, événement sans côté intact", ev[1].side == 2 and ev[1].dmg == 5 and ev[2].side == nil and ev[2].n == 2 and ev[3].side == 1 and #Duel.mirrorEvents(nil) == 0)
		local a1, a2, a3 = Duel.parseAction("attack"), Duel.parseAction("skill"), Duel.parseAction("swap2")
		check("parseAction : attack / skill / swapN ; tout le reste refusé", a1.kind == "attack" and a2.kind == "skill" and a3.kind == "swap" and a3.to == 2 and Duel.parseAction("swap") == nil and Duel.parseAction("heal") == nil and Duel.parseAction(3) == nil and Duel.parseAction(nil) == nil and Duel.parseAction("swap2xxxxx") == nil)
		local res = { rewarded = true, coins = 600 }
		check("payable : fin normale payée ; départ / abandon avant 3 tours = 0 ; après 3 tours payé ; non récompensé = 0", Duel.payable(res, 1, false, 3) == 600 and Duel.payable(res, 2, true, 3) == 0 and Duel.payable(res, 3, true, 3) == 600 and Duel.payable({ rewarded = false, coins = 600 }, 9, false) == 0 and Duel.payable(nil) == 0)
		check("REASONS liste les 10 refus (6 de E.2 + soi-même, distance, vol, éclosion)", #Duel.REASONS == 10)
	end
end

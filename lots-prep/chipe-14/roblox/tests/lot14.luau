--!nocheck
-- Tests du lot 14 (classé en direct : file MemoryStore, apparieur élu, serveur réservé « ranked », trophées, ligues, anti-abus, plafonds).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs } fournis par tests/run_lot14.py (lupa) ou tests/run.luau (Lune).
-- Partie 1 : règles pures (ReplicatedStorage/Ranked.lua). Partie 2 : transport réel (ServerScriptService/PvpLive.lua) avec un FAUX NUAGE :
-- MemoryStore en mémoire (expirations en temps virtuel, copies profondes comme une sérialisation, pannes et lectures périmées injectables),
-- TeleportService enregistré, plusieurs serveurs simulés, serveur d'arène créé à la réservation. Rien n'est testé en ligne.
-- Style : pas de `+=`, pas de `continue` (compatibilité lupa).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name })()
	end
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), {
		debugName = "Config",
		environment = { Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		} },
	})()
	local Ranked = load("roblox/src/ReplicatedStorage/Ranked.lua", "Ranked")
	local Battle = load("roblox/src/ReplicatedStorage/Battle.lua", "Battle")
	local PvpLive = load("roblox/src/ServerScriptService/PvpLive.lua", "PvpLive")

	local function clone(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	local function deep(v)
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, x in pairs(v) do
			c[k] = deep(x)
		end
		return c
	end
	local function mkRng(seed)
		local x = (seed * 1103515245 + 12345) % 2147483647
		if x <= 0 then
			x = x + 2147483646
		end
		return function()
			x = (x * 48271) % 2147483647
			return x / 2147483647
		end
	end
	local P = Config.PVP_LIVE
	local cfg = clone(P)
	cfg.enabled = true
	local On = clone(Config)
	On.PVP_LIVE = cfg
	local NOW = 20000 * 86400 + 3600 -- un jour UTC fixe, 01:00

	---------------------------------------------------------------- 1. Configuration
	suite("Lot 14 : configuration PVP_LIVE et LEAGUES")
	check("PVP_LIVE.enabled = false par défaut (interrupteur maître)", P.enabled == false)
	check("PVP_LIVE.minCCU = 60 (décision : file fermée sous 60 joueurs simultanés)", P.minCCU == 60)
	check(
		"Valeurs du cahier K : queueTtl 90, refresh 10, leaderTtl 10, pollTicket 2, waitArena 25, fallbackAfter 45, dailyFights 15",
		P.queueTtl == 90 and P.refresh == 10 and P.leaderTtl == 10 and P.pollTicket == 2 and P.waitArena == 25 and P.fallbackAfter == 45 and P.dailyFights == 15
	)
	check(
		"Fenêtre E.3 : 100 + 50 par 10 s, max 400 ; puissance [0,75 ; 1,33] puis [0,6 ; 1,67] après 30 s",
		P.trophyWindow.base == 100
			and P.trophyWindow.step == 50
			and P.trophyWindow.every == 10
			and P.trophyWindow.max == 400
			and P.power.lo == 0.75
			and P.power.hi == 1.33
			and P.power.wideAfter == 30
			and P.power.wideLo == 0.6
			and P.power.wideHi == 1.67
	)
	check("Plafond de trophées par jour défini (> 0) et forfait minimal défini", P.dailyTrophyCap > 0 and P.minTurnsForGain >= 1)
	check("Le délai de file (90 s) couvre deux rafraîchissements manqués", P.queueTtl > 2 * P.refresh and P.leaderTtl > P.leaderEvery)
	local LG = Config.LEAGUES
	check(
		"5 ligues E.4 (Bronze 0, Argent 300, Or 600, Diamant 1000, Champion 1500)",
		#LG == 5 and LG[1].min == 0 and LG[2].min == 300 and LG[3].min == 600 and LG[4].min == 1000 and LG[5].min == 1500 and LG[1].name == "Bronze" and LG[5].name == "Champion"
	)

	---------------------------------------------------------------- 2. Ouverture de la file (seuil 60)
	suite("Lot 14 : file fermée sous 60 joueurs simultanés")
	check("Désactivée (enabled = false) même à 500 joueurs", Ranked.liveOpen(P, { n = 500, t = NOW }, NOW) == false)
	local o1, r1 = Ranked.liveOpen(cfg, { n = 59, t = NOW }, NOW)
	check("59 joueurs : fermée (low_ccu)", o1 == false and r1 == "low_ccu")
	local o2 = Ranked.liveOpen(cfg, { n = 60, t = NOW }, NOW)
	check("60 joueurs : ouverte", o2 == true)
	local o3, r3 = Ranked.liveOpen(cfg, { n = 200, t = NOW - cfg.ccuTtl - 1 }, NOW)
	check("Comptage périmé : fermée (échec = fermé)", o3 == false and r3 == "unknown")
	local o4, r4 = Ranked.liveOpen(cfg, nil, NOW)
	check("Comptage absent : fermée", o4 == false and r4 == "unknown")
	check("Comptage invalide (chaîne) : fermée", Ranked.liveOpen(cfg, { n = "999", t = NOW }, NOW) == false)
	check("Comptage daté du futur : fermée", Ranked.liveOpen(cfg, { n = 99, t = NOW + 60 }, NOW) == false)
	local sum, srv =
		Ranked.ccuSum({ { n = 5, t = NOW }, { n = 4, t = NOW - 10 }, { n = 5, t = NOW - 999 }, { n = "x", t = NOW }, { n = 9999, t = NOW }, "bad", { value = { n = 3, t = NOW } } }, NOW, cfg.ccuTtl)
	check("ccuSum : comptes frais seulement, invalides et aberrants ignorés (5 + 4 + 3 = 12, 3 serveurs)", sum == 12 and srv == 3)

	---------------------------------------------------------------- 3. Entrée en file
	suite("Lot 14 : entrée en file (canQueue)")
	local team1 = { { p = 1 }, { p = 2 }, { p = 3 } }
	local fresh = Ranked.sanitizeLive(nil, cfg)
	local function ctx(over)
		local c = { open = true, busy = false, serverMode = "arena", team = team1, live = fresh }
		for k, v in pairs(over or {}) do
			c[k] = v
		end
		return c
	end
	check("Ouverte, libre, équipe : accepté", Ranked.canQueue(cfg, ctx()) == true)
	check("Fermée : « closed » (Main bascule sur l'asynchrone)", select(2, Ranked.canQueue(cfg, ctx({ open = false }))) == "closed")
	check("Occupé (combat, œuf porté, château) : refusé", select(2, Ranked.canQueue(cfg, ctx({ busy = true }))) == "busy")
	check(
		"Depuis un serveur d'arène ou de château : refusé",
		select(2, Ranked.canQueue(cfg, ctx({ serverMode = "ranked" }))) == "mode" and select(2, Ranked.canQueue(cfg, ctx({ serverMode = "castle" }))) == "mode"
	)
	check("Sans équipe : refusé", select(2, Ranked.canQueue(cfg, ctx({ team = {} }))) == "team")
	local tired = Ranked.sanitizeLive({ day = 1, fights = cfg.dailyFights, gained = 0 }, cfg)
	check("15 combats en direct aujourd'hui : refusé (« fights »)", select(2, Ranked.canQueue(cfg, ctx({ live = tired }))) == "fights")
	local capped = Ranked.sanitizeLive({ day = 1, fights = 2, gained = cfg.dailyTrophyCap }, cfg)
	check("Plafond de trophées du jour atteint : refusé (« cap »)", select(2, Ranked.canQueue(cfg, ctx({ live = capped }))) == "cap")
	local lv = Ranked.sanitizeLive({ day = Ranked.day(NOW) - 1, fights = 15, gained = 300, w = 3 }, cfg)
	Ranked.liveDay(lv, NOW)
	check("Nouveau jour UTC : combats et trophées du jour remis à 0, victoires gardées", lv.fights == 0 and lv.gained == 0 and lv.w == 3 and lv.day == Ranked.day(NOW))

	---------------------------------------------------------------- 4. Appariement
	suite("Lot 14 : appariement (trophées, puissance, élargissement, anti-abus)")
	check(
		"Fenêtre de trophées : 100 à 0 s, 150 à 10 s, 250 à 35 s, 400 (plafond) à 60 s et 600 s",
		Ranked.trophyWindow(cfg, 0) == 100
			and Ranked.trophyWindow(cfg, 10) == 150
			and Ranked.trophyWindow(cfg, 35) == 250
			and Ranked.trophyWindow(cfg, 60) == 400
			and Ranked.trophyWindow(cfg, 600) == 400
	)
	local function E(u, tr, pow, t, extra)
		local e = { u = u, tr = tr, pow = pow, t = t, r = NOW, job = "J" .. u, team = team1, peers = {}, opp = {} }
		for k, v in pairs(extra or {}) do
			e[k] = v
		end
		return e
	end
	check("Δ 120 trophées à 0 s : refusé", Ranked.compatible(cfg, E(1, 100, 1000, NOW), E(2, 220, 1000, NOW), NOW) == false)
	check("Δ 120 trophées après 10 s d'attente des deux : accepté", Ranked.compatible(cfg, E(1, 100, 1000, NOW - 10), E(2, 220, 1000, NOW - 10), NOW) == true)
	check("La plus courte attente décide : un joueur arrivé à l'instant ne voit que ±100", Ranked.compatible(cfg, E(1, 100, 1000, NOW - 60), E(2, 220, 1000, NOW), NOW) == false)
	check("Δ 400 jamais dépassé, même après 10 min", Ranked.compatible(cfg, E(1, 0, 1000, NOW - 600), E(2, 401, 1000, NOW - 600), NOW) == false)
	check("Puissance x1,5 refusée avant 30 s", Ranked.compatible(cfg, E(1, 100, 1500, NOW - 20), E(2, 100, 1000, NOW - 20), NOW) == false)
	check("Puissance x1,5 acceptée après 30 s (bornes élargies)", Ranked.compatible(cfg, E(1, 100, 1500, NOW - 30), E(2, 100, 1000, NOW - 30), NOW) == true)
	check("Puissance x1,8 toujours refusée", Ranked.compatible(cfg, E(1, 100, 1800, NOW - 300), E(2, 100, 1000, NOW - 300), NOW) == false)
	check("Puissance /1,8 toujours refusée (symétrique)", Ranked.compatible(cfg, E(1, 100, 1000, NOW - 300), E(2, 100, 1800, NOW - 300), NOW) == false)
	check("Même serveur (JobId) : refusé", select(2, Ranked.compatible(cfg, E(1, 100, 1000, NOW), E(2, 100, 1000, NOW, { job = "J1" }), NOW)) == "same_server")
	check(
		"Ont partagé un serveur il y a < 10 min (peers) : refusé, dans les deux sens",
		select(2, Ranked.compatible(cfg, E(1, 100, 1000, NOW, { peers = { 2 } }), E(2, 100, 1000, NOW), NOW)) == "peers"
			and select(2, Ranked.compatible(cfg, E(1, 100, 1000, NOW), E(2, 100, 1000, NOW, { peers = { 1 } }), NOW)) == "peers"
	)
	check(
		"Même adversaire récent (rematch) : refusé, dans les deux sens",
		select(2, Ranked.compatible(cfg, E(1, 100, 1000, NOW, { opp = { 2 } }), E(2, 100, 1000, NOW), NOW)) == "rematch"
			and select(2, Ranked.compatible(cfg, E(1, 100, 1000, NOW), E(2, 100, 1000, NOW, { opp = { 1 } }), NOW)) == "rematch"
	)
	check(
		"Soi-même et entrée déjà réservée : refusés",
		Ranked.compatible(cfg, E(1, 100, 1000, NOW), E(1, 100, 1000, NOW, { job = "X" }), NOW) == false
			and Ranked.compatible(cfg, E(1, 100, 1000, NOW, { m = "M" }), E(2, 100, 1000, NOW), NOW) == false
	)

	local pr = Ranked.pairUp(cfg, { E(3, 100, 1000, NOW - 5), E(1, 120, 1000, NOW - 20), E(2, 300, 1000, NOW - 20), E(4, 110, 1000, NOW - 1) }, NOW)
	check("pairUp : le plus ancien (u1) d'abord, avec le plus proche en trophées (u4, Δ 10)", #pr == 1 and pr[1].a.u == 1 and pr[1].b.u == 4)
	local stale = E(5, 100, 1000, NOW - 10)
	stale.r = NOW - cfg.queueTtl - 1
	local bad = { u = "6", tr = 100 }
	local pr2 = Ranked.pairUp(cfg, { stale, bad, E(7, 100, 1000, NOW), E(7, 100, 1000, NOW, { job = "Jdup" }) }, NOW)
	check("pairUp : entrée périmée, invalide ou en double (même joueur) ignorée", #pr2 == 0)
	local worst, total = 0, 0
	for seed = 1, 6 do
		local rnd = mkRng(seed)
		local list = {}
		for i = 1, 200 do
			list[#list + 1] = E(
				i,
				math.floor(rnd() * 900),
				800 + math.floor(rnd() * 600),
				NOW - math.floor(rnd() * 80),
				{ job = "J" .. math.floor(rnd() * 40), peers = { math.floor(rnd() * 200) + 1 }, opp = { math.floor(rnd() * 200) + 1 } }
			)
		end
		local seen, dup = {}, 0
		for _, p in ipairs(Ranked.pairUp(cfg, list, NOW)) do
			total = total + 1
			for _, e in ipairs({ p.a, p.b }) do
				if seen[e.u] then
					dup = dup + 1
				end
				seen[e.u] = true
			end
			if not Ranked.compatible(cfg, p.a, p.b, NOW) then
				dup = dup + 1
			end
		end
		worst = math.max(worst, dup)
	end
	check("pairUp : 6 × 200 entrées aléatoires, aucun joueur apparié deux fois, toutes les paires compatibles (" .. total .. " paires)", worst == 0 and total > 100)

	---------------------------------------------------------------- 5. Transformations atomiques
	suite("Lot 14 : bail d'apparieur, réservations, tickets")
	local lock = nil
	local function tryLead(job, t)
		local v = Ranked.leaderTransform(lock, job, t, cfg.leaderTtl)
		if v ~= nil then
			lock = v
		end
		return Ranked.isLeader(v, job, t)
	end
	local a1, b1 = tryLead("A", NOW), tryLead("B", NOW)
	check("Deux serveurs : un seul leader (A), B refusé", a1 == true and b1 == false)
	check("A renouvelle son bail", tryLead("A", NOW + 3) == true and tryLead("B", NOW + 4) == false)
	check("Bail expiré (A muet 10 s) : B prend la main, A refusé ensuite", tryLead("B", NOW + 13) == true and tryLead("A", NOW + 14) == false)
	local entry = E(1, 100, 1000, NOW)
	local c1 = Ranked.claimTransform(entry, "M1")
	check("Réservation : première réussie, seconde (autre match) refusée", c1 and c1.m == "M1" and Ranked.claimTransform(c1, "M2") == nil and entry.m == nil)
	check("Réservation d'une entrée disparue (annulée/expirée) : refusée", Ranked.claimTransform(nil, "M1") == nil)
	check("Libération : seulement par le même match", Ranked.releaseTransform(c1, "M2") == nil and Ranked.releaseTransform(c1, "M1").m == nil)
	check("Rafraîchissement : n'écrase jamais une entrée réservée", Ranked.refreshTransform(c1, entry, NOW + 10) == nil and Ranked.refreshTransform(entry, entry, NOW + 10).r == NOW + 10)
	local mt = Ranked.newMatch(cfg, "M1", E(1, 100, 1000, NOW, { name = "Ana", party = "P1" }), E(2, 90, 1000, NOW, { name = "Bob" }), "CODE", "PSID", 7, NOW)
	local ta, tb = Ranked.newTicket(cfg, mt, "a", NOW), Ranked.newTicket(cfg, mt, "b", NOW)
	check("Tickets : chacun voit le nom de l'autre", ta.opp == "Bob" and tb.opp == "Ana" and ta.code == "CODE" and ta.match == "M1")
	check("Ticket valide avant expiration, ignoré après (expiré)", Ranked.ticketValid(ta, NOW + 1) == true and Ranked.ticketValid(ta, NOW + cfg.ticketTtl) == false)
	check(
		"Ticket malformé ignoré",
		Ranked.ticketValid({ match = 5, code = "C", exp = NOW + 9, side = "a" }, NOW) == false and Ranked.ticketValid({ match = "M", code = "C", exp = NOW + 9, side = "z" }, NOW) == false
	)
	check("Arène : joueurs du match admis (côtés a/b)", Ranked.arenaAdmit(mt, 1, "PSID", NOW) == "a" and Ranked.arenaAdmit(mt, 2, "PSID", NOW) == "b")
	check(
		"Arène : intrus, autre serveur réservé, match expiré : refusés",
		Ranked.arenaAdmit(mt, 3, "PSID", NOW) == nil
			and select(2, Ranked.arenaAdmit(mt, 1, "AUTRE", NOW)) == "wrong_server"
			and select(2, Ranked.arenaAdmit(mt, 1, "PSID", NOW + cfg.matchTtl)) == "expired"
			and select(2, Ranked.arenaAdmit(nil, 1, "PSID", NOW)) == "no_match"
	)

	---------------------------------------------------------------- 6. Arène, résultat, trophées
	suite("Lot 14 : arène, forfait, trophées, plafonds")
	local A = Ranked.arenaNew(mt, NOW)
	Ranked.arenaArrive(A, "a")
	check("Un seul présent : on attend jusqu'à 25 s", Ranked.arenaTick(cfg, A, NOW + 24) == "wait")
	check("Un seul présent à 25 s : match ANNULÉ (aucun trophée sans les deux joueurs)", Ranked.arenaTick(cfg, A, NOW + 25) == "void")
	Ranked.arenaArrive(A, "b")
	check("Les deux présents : départ", Ranked.arenaTick(cfg, A, NOW + 5) == "start")
	check("Départ pendant l'attente = absent ; pendant le combat = forfait", Ranked.arenaLeave(A, "b") == "absent" and A.present.b == nil)
	A.phase = "fight"
	check("Arrivée refusée après le départ du combat", Ranked.arenaArrive(A, "b") == false and Ranked.arenaLeave(A, "a") == "forfeit")
	local function side(tr, gained)
		return { trophies = tr, live = Ranked.sanitizeLive({ gained = gained or 0 }, cfg) }
	end
	local out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "a", turns = 8, a = side(100), b = side(160) })
	check("Victoire : gain = Config.pvpGain (25 + 6 = 31), défaite = -15", out.a == Config.pvpGain(100, 160) and out.a == 31 and out.b == -15)
	out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "b", turns = 8, a = side(10), b = side(0) })
	check("Défaite à 10 trophées : -10 seulement (jamais négatif)", out.a == -10 and out.b == Config.pvpGain(0, 10))
	out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "a", turns = 8, a = side(100, cfg.dailyTrophyCap - 7), b = side(100) })
	check("Plafond du jour : gain rogné au reste du plafond (7), marqué « capped »", out.a == 7 and out.capped.a == true and out.b == -15)
	out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "a", turns = 8, a = side(100, cfg.dailyTrophyCap), b = side(100) })
	check("Plafond atteint : 0 gain (la défaite de l'autre compte quand même)", out.a == 0 and out.b == -15)
	out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "a", forfeit = true, turns = 1, a = side(100), b = side(100) })
	check("Déconnexion au tour 1 = forfait : le partant perd 15, le gagnant ne gagne rien (anti-nourrissage)", out.a == 0 and out.b == -15 and out.fed == true)
	out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, { winner = "b", forfeit = true, turns = cfg.minTurnsForGain, a = side(100), b = side(100) })
	check("Déconnexion après " .. cfg.minTurnsForGain .. " tours = forfait : gain normal pour le restant", out.b == 25 and out.a == -15 and not out.fed)
	local pv, lv2 = { trophies = 100, wins = 0, losses = 0 }, Ranked.sanitizeLive(nil, cfg)
	Ranked.apply(pv, lv2, 31, true)
	Ranked.apply(pv, lv2, -15, false)
	check(
		"apply : trophées, victoires/défaites et trophées gagnés du jour (pertes non comptées)",
		pv.trophies == 116 and pv.wins == 1 and pv.losses == 1 and lv2.gained == 31 and lv2.w == 1 and lv2.l == 1
	)
	check("canFight : refusé à 15 combats", Ranked.canFight(cfg, tired) == false and Ranked.canFight(cfg, fresh) == true)

	---------------------------------------------------------------- 7. Profil, adversaires récents, ligues
	suite("Lot 14 : profil battle.live, adversaires récents, ligues, saison")
	local s0 = Ranked.sanitizeLive({ day = "x", fights = -4, gained = 1 / 0, w = 0 / 0, recent = { { u = 5, t = NOW }, { u = "6", t = NOW }, { u = 7.5, t = NOW }, "x" } }, cfg)
	check("sanitizeLive : valeurs invalides remplacées, adversaires invalides retirés", s0.day == 0 and s0.fights == 0 and s0.gained == 0 and s0.w == 0 and #s0.recent == 1 and s0.recent[1].u == 5)
	check("sanitizeLive(nil) = valeurs neuves ; idempotent", Ranked.sanitizeLive(nil, cfg).fights == 0 and Ranked.sanitizeLive(Ranked.sanitizeLive(s0, cfg), cfg).recent[1].u == 5)
	local big = { recent = {} }
	for i = 1, 50 do
		big.recent[i] = { u = i, t = NOW }
	end
	check("sanitizeLive : liste d'adversaires bornée à recentMax", #Ranked.sanitizeLive(big, cfg).recent == cfg.recentMax)
	local lr = Ranked.sanitizeLive(nil, cfg)
	Ranked.recordOpponent(cfg, lr, 42, NOW)
	Ranked.recordOpponent(cfg, lr, 42, NOW + 10)
	Ranked.recordOpponent(cfg, lr, 43, NOW + 20)
	local ro = Ranked.recentOpponents(cfg, lr, NOW + 30)
	check("recordOpponent : sans doublon, le plus récent gardé", #ro == 2 and lr.recent[1].u == 42 and lr.recent[1].t == NOW + 10)
	check("Adversaire libéré après rematchCooldown (1 h)", #Ranked.recentOpponents(cfg, lr, NOW + 10 + cfg.rematchCooldown) == 1)
	check(
		"Ligues : 0 Bronze, 299 Bronze, 300 Argent, 999 Or, 1000 Diamant, 1500 Champion, invalide Bronze",
		Ranked.league(LG, 0).name == "Bronze"
			and Ranked.league(LG, 299).name == "Bronze"
			and Ranked.league(LG, 300).name == "Argent"
			and Ranked.league(LG, 999).name == "Or"
			and Ranked.league(LG, 1000).name == "Diamant"
			and Ranked.league(LG, 1500).name == "Champion"
			and Ranked.league(LG, 0 / 0).name == "Bronze"
	)
	check("Remise de saison (optionnelle) : 250 -> 250, 400 -> 300, 1000 -> 600", Ranked.seasonReset(250) == 250 and Ranked.seasonReset(400) == 300 and Ranked.seasonReset(1000) == 600)

	---------------------------------------------------------------- 8. Téléport, repli, retour, vues
	suite("Lot 14 : téléportation, repli, retour, vues en miroir, actions")
	check(
		"Échec de téléport : 2 nouvelles tentatives à 3 s puis remise en file",
		Ranked.teleportPlan(cfg, 1).retry == 3 and Ranked.teleportPlan(cfg, 2).retry == 3 and Ranked.teleportPlan(cfg, 3).requeue == true
	)
	check("Repli vers l'asynchrone à 45 s, pas avant", Ranked.shouldFallback(cfg, NOW, NOW + 44) == false and Ranked.shouldFallback(cfg, NOW, NOW + 45) == true)
	local reg = { open = true, code = "PCODE", members = { 1, 9 }, count = 2, size = 5 }
	check("Retour vers la partie d'origine si elle existe (registre)", Ranked.returnPlan(Config.Game, "P1", reg, 1).place == "party" and Ranked.returnPlan(Config.Game, "P1", reg, 1).code == "PCODE")
	check("Retour vers le hub si la partie n'existe plus", Ranked.returnPlan(Config.Game, "P1", nil, 1).place == "hub")
	check(
		"Retour vers le hub si le joueur n'en est plus membre, si elle est fermée, ou sans partie",
		Ranked.returnPlan(Config.Game, "P1", reg, 3).place == "hub"
			and Ranked.returnPlan(Config.Game, "P1", { open = false, code = "C", members = { 1 }, count = 1, size = 5 }, 1).place == "hub"
			and Ranked.returnPlan(Config.Game, nil, reg, 1).place == "hub"
	)
	local st = Battle.new(3, { Battle.unit(Config, { p = 1 }) }, { Battle.unit(Config, { p = 2 }), Battle.unit(Config, { p = 3 }) })
	local v = Battle.view(st)
	local mv = Ranked.mirrorView(v)
	check("Vue en miroir : les camps sont échangés (le joueur B se voit en camp 1)", #mv.sides[1].units == 2 and #mv.sides[2].units == 1 and #v.sides[1].units == 1)
	local evs = Battle.turn(st, { kind = "attack" }, { kind = "attack" })
	local mev = Ranked.mirrorEvents(evs)
	local okMirror = #mev == #evs
	for i, e in ipairs(evs) do
		if e.side and mev[i].side ~= 3 - e.side then
			okMirror = false
		end
	end
	check("Événements en miroir : side 1 <-> 2, original intact", okMirror)
	st.over, st.winner = true, 1
	check("Vainqueur en miroir", Ranked.mirrorView(Battle.view(st)).winner == 2)
	check(
		"Actions client : attack, skill, swap2 ; le reste refusé",
		Ranked.parseAction("attack").kind == "attack"
			and Ranked.parseAction("swap2").to == 2
			and Ranked.parseAction("swap") == nil
			and Ranked.parseAction(5) == nil
			and Ranked.parseAction("drop table") == nil
	)

	---------------------------------------------------------------- 9. Pas de Robux, quotas
	suite("Lot 14 : aucun Robux dans le classement ; quotas MemoryStore")
	local srcR = fs.readFile("roblox/src/ReplicatedStorage/Ranked.lua")
	local srcL = fs.readFile("roblox/src/ServerScriptService/PvpLive.lua")
	local function noPay(src)
		local code = src:gsub("%-%-[^\n]*", "") -- commentaires exclus
		for _, w in ipairs({ "PRODUCTS", "PASSES", "Marketplace", "ProcessReceipt", "boostUnits", "luck", "passOn", "robux", "Robux" }) do
			if code:find(w, 1, true) then
				return false, w
			end
		end
		return true
	end
	check("Ranked.lua : aucune référence à un produit, pass, boost ou Robux", noPay(srcR))
	check("PvpLive.lua : aucune référence à un produit, pass, boost ou Robux", noPay(srcL))
	local tA = { { p = 4, s = "L", m = "gold", boost = 99 } }
	local san = Ranked.sanitizeTeam(Config, tA)
	check("Équipe figée : seuls p/s/m passent (aucun champ bonus)", #san == 1 and san[1].boost == nil and san[1].p == 4)
	check("Équipe : espèce inconnue ou 4e pet retirés", #Ranked.sanitizeTeam(Config, { { p = 9999 }, { p = 1 }, { p = 2 }, { p = 3 }, { p = 4 } }) == 3)
	local u4 = Battle.unit(Config, { p = 4 })
	check("Puissance d'équipe = stats brutes de Battle.unit", Ranked.teamPower(Battle, Config, { { p = 4 } }) == Battle.power({ hp = u4.maxHp, atk = u4.atk, spd = u4.spd }))
	local q60 = Ranked.quotaPerMinute(cfg, 12, 10, 4)
	local q1000 = Ranked.quotaPerMinute(cfg, 200, 100, 30)
	check("Quotas à 60 joueurs (12 serveurs, 10 en file) : " .. math.floor(q60) .. " req/min, < 15 % de la limite (" .. Ranked.quotaLimit(60) .. ")", q60 < 0.15 * Ranked.quotaLimit(60))
	check("Quotas à 1 000 joueurs (200 serveurs, 100 en file) : " .. math.floor(q1000) .. " req/min, < 15 % de la limite", q1000 < 0.15 * Ranked.quotaLimit(1000))

	---------------------------------------------------------------- 10. Transport : faux nuage multi-serveurs
	local function newCloud(seed)
		local C = { now = NOW, maps = {}, failRate = 0, rnd = mkRng(seed or 1), reserves = 0, guid = 0, teleports = {}, psidOf = {}, stale = false, snap = {}, ops = 0 }
		local function map(name)
			C.maps[name] = C.maps[name] or {}
			return C.maps[name]
		end
		local function fail(op)
			C.ops = C.ops + 1
			if C.failRate > 0 and C.rnd() < C.failRate then
				error("MemoryStore indisponible (" .. op .. ")")
			end
		end
		local function alive(m, k)
			local e = m[k]
			if e and e.exp <= C.now then
				m[k] = nil
				return nil
			end
			return e
		end
		function C.hash(name)
			return {
				set = function(k, val, ttl)
					fail("set")
					map(name)[k] = { v = deep(val), exp = C.now + ttl }
				end,
				get = function(k)
					fail("get")
					local e = alive(map(name), k)
					return e and deep(e.v)
				end,
				remove = function(k)
					fail("remove")
					map(name)[k] = nil
				end,
				update = function(k, fn, ttl)
					fail("update")
					local e = alive(map(name), k)
					local new = fn(e and deep(e.v))
					if new == nil then
						return nil
					end
					map(name)[k] = { v = deep(new), exp = C.now + ttl, sk = e and e.sk }
					return deep(new)
				end,
			}
		end
		function C.sorted(name)
			local h = C.hash(name)
			return {
				set = function(k, val, ttl, sk)
					fail("set")
					map(name)[k] = { v = deep(val), exp = C.now + ttl, sk = sk or 0 }
				end,
				update = function(k, fn, ttl)
					local r = h.update(k, fn, ttl)
					if r ~= nil and type(r.tr) == "number" then
						map(name)[k].sk = r.tr
					end
					return r
				end,
				remove = h.remove,
				range = function(n)
					fail("range")
					local items = {}
					for k in pairs(map(name)) do
						local e = alive(map(name), k)
						if e then
							items[#items + 1] = { k = k, sk = e.sk or 0, v = e.v }
						end
					end
					table.sort(items, function(x, y)
						if x.sk ~= y.sk then
							return x.sk < y.sk
						end
						return x.k < y.k
					end)
					local out = {}
					for i = 1, math.min(n, #items) do
						out[i] = deep(items[i].v)
					end
					if C.stale then -- latence : la lecture rend l'état de l'appel précédent (2 s plus tôt ou plus)
						local prev = C.snap[name]
						C.snap[name] = out
						return prev or {}
					end
					return out
				end,
			}
		end
		return C
	end

	local function newServer(C, job, psid)
		local S = { job = job, sessions = {}, sent = {}, notes = {}, kicked = {}, saves = 0 }
		S.rt = {
			now = function()
				return C.now
			end,
			job = job,
			psid = psid or "",
			places = Config.Game.Places,
			guid = function()
				C.guid = C.guid + 1
				return "M" .. C.guid
			end,
			seed = function()
				return 4242
			end,
			queue = C.sorted(cfg.queueName),
			ccu = C.sorted(cfg.ccuName),
			lock = C.hash(cfg.lockName),
			tickets = C.hash(cfg.ticketName),
			matches = C.hash(cfg.matchName),
			registry = C.hash(Config.Game.RegistryName),
			reserve = function()
				if C.reserveFail then
					error("réservation refusée")
				end
				C.reserves = C.reserves + 1
				local code, ps = "CODE" .. C.reserves, "PSID" .. C.reserves
				C.psidOf[code] = ps
				return code, ps
			end,
			teleport = function(players, place, code, data)
				if C.teleportFail then
					error(C.teleportFail)
				end
				for _, p in ipairs(players) do
					C.teleports[#C.teleports + 1] = { from = job, uid = p.UserId, player = p, place = place, code = code, data = deep(data) }
				end
			end,
			save = function()
				S.saves = S.saves + 1
				return not C.saveFail
			end,
			send = function(p, msg)
				S.sent[p.UserId] = S.sent[p.UserId] or {}
				table.insert(S.sent[p.UserId], msg)
			end,
			notify = function(p, text)
				S.notes[p.UserId] = text
			end,
			kick = function(p)
				S.kicked[p.UserId] = true
			end,
			log = function() end,
		}
		S.L = PvpLive.new(On, Ranked, Battle, S.rt)
		return S
	end
	local function mkSession(uid, trophies, pets)
		local slots = {}
		local team = {}
		for i, p in ipairs(pets or { 4, 5, 6 }) do
			slots[i] = { k = "p", p = p }
			team[i] = i
		end
		return {
			player = { UserId = uid, DisplayName = "J" .. uid, Name = "J" .. uid },
			data = { slots = slots, battle = { team = team, pvp = { trophies = trophies, wins = 0, losses = 0, season = 1, defense = {} }, live = Ranked.sanitizeLive(nil, cfg) } },
			carry = {},
		}
	end
	local function lastMsg(S, uid, k)
		for i = #(S.sent[uid] or {}), 1, -1 do
			if S.sent[uid][i].k == k then
				return S.sent[uid][i]
			end
		end
		return nil
	end
	local CTX = { busy = false, serverMode = "arena" }
	local function seedCcu(C, n)
		C.maps[cfg.ccuName] = C.maps[cfg.ccuName] or {}
		C.maps[cfg.ccuName]["filler"] = { v = { n = n, t = C.now }, exp = C.now + 10000, sk = n }
	end

	-- Monde : serveurs d'origine + serveurs d'arène créés à la volée par les téléportations (comme Roblox à l'arrivée d'un code réservé).
	local function newWorld(seed, nServers)
		local W = { C = newCloud(seed), servers = {}, arenas = {}, done = 0, home = {}, arrived = {} }
		for i = 1, nServers do
			W.servers[i] = newServer(W.C, "JOB" .. i)
		end
		function W.add(i, s)
			W.servers[i].sessions[s.player] = s
			return s
		end
		function W.where(uid)
			for _, S in ipairs(W.servers) do
				for p, s in pairs(S.sessions) do
					if p.UserId == uid then
						return S, s
					end
				end
			end
			for _, S in pairs(W.arenas) do
				for p, s in pairs(S.sessions) do
					if p.UserId == uid then
						return S, s
					end
				end
			end
			return nil
		end
		function W.processTeleports()
			while W.done < #W.C.teleports do
				W.done = W.done + 1
				local t = W.C.teleports[W.done]
				local S, s = W.where(t.uid)
				if S and not (W.blockArrival and W.blockArrival[t.uid]) then
					S.L.onLeave(s) -- comme Main : PlayerRemoving -> Live.onLeave AVANT la sauvegarde
					S.sessions[s.player] = nil
					if t.data.mode == "ranked" then
						local AS = W.arenas[t.code]
						if not AS then
							AS = newServer(W.C, "ARENA-" .. t.code, W.C.psidOf[t.code])
							W.arenas[t.code] = AS
						end
						W.arrived[t.uid] = W.arrived[t.uid] or {}
						W.arrived[t.uid][t.data.match] = true
						local s2 = { player = s.player, data = deep(s.data), carry = {} }
						AS.sessions[s.player] = s2
						AS.L.arenaJoin(s2, t.data)
					else
						W.home[t.uid] = t
					end
				end
			end
		end
		function W.tick(seconds, before)
			for _ = 1, seconds do
				W.C.now = W.C.now + 1
				if before then
					before()
				end
				for _, S in ipairs(W.servers) do
					S.L.step(S.sessions, W.C.now)
				end
				for _, S in pairs(W.arenas) do
					S.L.step(S.sessions, W.C.now)
				end
				W.processTeleports()
			end
		end
		return W
	end

	suite("Lot 14 (transport) : file fermée sous 60 joueurs")
	do
		local W = newWorld(1, 2)
		local s1 = W.add(1, mkSession(101, 100))
		W.add(2, mkSession(102, 120))
		seedCcu(W.C, 57) -- 57 + 1 + 1 = 59 joueurs simultanés
		W.tick(cfg.ccuPublish + 1)
		local ok1, why1 = W.servers[1].L.enqueue(s1, CTX)
		check("59 joueurs : entrée refusée « closed » (Main lance le classé asynchrone)", ok1 == false and why1 == "closed")
		check("59 joueurs : aucune écriture dans la file", next(W.C.maps[cfg.queueName] or {}) == nil)
		seedCcu(W.C, 58)
		W.tick(cfg.ccuPublish + 1)
		local ok2 = W.servers[1].L.enqueue(s1, CTX)
		check("60 joueurs : entrée acceptée (après le comptage suivant)", ok2 == true and s1.pvpPending == true)
		check("Double entrée refusée", W.servers[1].L.enqueue(s1, CTX) == false)
		local Woff = newWorld(2, 1)
		Woff.servers[1].L = PvpLive.new(Config, Ranked, Battle, Woff.servers[1].rt) -- vrai Config : enabled = false
		local so = Woff.add(1, mkSession(103, 0))
		seedCcu(Woff.C, 500)
		Woff.tick(40)
		check("Interrupteur maître à false : fermée à 500 joueurs, aucune requête MemoryStore", Woff.servers[1].L.enqueue(so, CTX) == false and Woff.C.ops == 0)
	end

	suite("Lot 14 (transport) : match complet entre 2 serveurs, trophées, retour, pas de revanche")
	do
		local W = newWorld(3, 2)
		local sA = W.add(1, mkSession(201, 100, { 4, 5, 6 }))
		local sB = W.add(2, mkSession(202, 140, { 4, 5, 6 }))
		W.C.maps[Config.Game.RegistryName] = { P1 = { v = { open = true, code = "PARTY1", members = { 201 }, count = 1, size = 5 }, exp = NOW + 99999 } }
		seedCcu(W.C, 100)
		W.tick(cfg.ccuPublish + 1)
		check("Entrées acceptées sur deux serveurs", W.servers[1].L.enqueue(sA, { busy = false, serverMode = "arena", party = "P1" }) and W.servers[2].L.enqueue(sB, CTX))
		W.tick(8)
		local nA = 0
		for code, AS in pairs(W.arenas) do
			nA = nA + 1
			W.arenaCode = code
		end
		check(
			"Apparieur unique : un match, un serveur réservé, les deux joueurs téléportés avec sauvegarde préalable",
			nA == 1 and W.C.reserves == 1 and W.servers[1].saves >= 1 and W.servers[2].saves >= 1
		)
		check("La file est vidée et les tickets consommés", next(W.C.maps[cfg.queueName] or {}) == nil and next(W.C.maps[cfg.ticketName] or {}) == nil)
		local AS = W.arenas[W.arenaCode]
		local aA, aB = select(2, W.where(201)), select(2, W.where(202))
		check("Les deux joueurs sont dans l'arène (côtés a/b)", aA and aB and aA.liveSide and aB.liveSide and aA.liveSide ~= aB.liveSide)
		W.tick(1)
		check(
			"Combat lancé dès que les deux sont là : 1 combat consommé chacun, adversaire mémorisé",
			AS.L.arena.phase == "fight" and aA.data.battle.live.fights == 1 and aB.data.battle.live.fights == 1 and aA.data.battle.live.recent[1].u == 202 and aB.data.battle.live.recent[1].u == 201
		)
		local stB = lastMsg(AS, 202, "start")
		check("Le joueur B reçoit la vue en miroir (son équipe en camp 1)", stB and stB.live == true and stB.view.sides[1].units[1].p == AS.L.arena.st.sides[2].units[1].p)
		local turns = 0
		while AS.L.arena.phase == "fight" and turns < 60 do
			AS.L.act(aA, "attack")
			AS.L.act(aB, "attack")
			turns = turns + 1
		end
		check("Les deux joueurs agissent : le tour est résolu sans attendre le délai, combat terminé", AS.L.arena.phase == "done" and turns <= Battle.MAX_TURNS)
		local winA = AS.L.arena.st.winner == (aA.liveSide == "a" and 1 or 2)
		local gA, gB = aA.data.battle.pvp.trophies - 100, aB.data.battle.pvp.trophies - 140
		check(
			"Trophées : gagnant + Config.pvpGain, perdant -15 (" .. gA .. " / " .. gB .. ")",
			(winA and gA == Config.pvpGain(100, 140) and gB == -15) or (not winA and gB == Config.pvpGain(140, 100) and gA == -15)
		)
		W.tick(8)
		check(
			"Retour : A vers sa partie d'origine (registre), B vers le hub (aucune partie)",
			W.home[201] and W.home[201].code == "PARTY1" and W.home[201].data.partyId == "P1" and W.home[202] and W.home[202].place == Config.Game.Places.hub
		)
		-- revanche : les deux reviennent dans des serveurs différents avec leur profil, et refont la file
		local rA, rB = mkSession(201, 0), mkSession(202, 0)
		rA.data, rB.data = deep(aA.data), deep(aB.data)
		W.add(1, rA)
		W.add(2, rB)
		W.tick(1)
		W.servers[1].L.enqueue(rA, CTX)
		W.servers[2].L.enqueue(rB, CTX)
		W.tick(cfg.fallbackAfter + 1)
		check(
			"Pas de revanche : jamais réappariés dans l'heure, repli proposé à 45 s",
			W.C.reserves == 1 and lastMsg(W.servers[1], 201, "liveFallback") ~= nil and lastMsg(W.servers[2], 202, "liveFallback") ~= nil
		)
		check("Après le repli : plus en file, verrou de combat levé", rA.pvpPending == nil and next(W.C.maps[cfg.queueName] or {}) == nil)
	end

	suite("Lot 14 (transport) : un seul joueur arrive = match annulé ; échec de téléport = remise en file")
	do
		local W = newWorld(4, 2)
		local sA = W.add(1, mkSession(301, 200))
		local sB = W.add(2, mkSession(302, 210))
		seedCcu(W.C, 100)
		W.tick(cfg.ccuPublish + 1)
		W.blockArrival = { [302] = true } -- B : TeleportAsync accepté mais il n'arrive jamais (échec silencieux)
		W.servers[1].L.enqueue(sA, CTX)
		W.servers[2].L.enqueue(sB, CTX)
		W.tick(6)
		local AS = next(W.arenas) and W.arenas[next(W.arenas)]
		local aA = select(2, W.where(301))
		check("A est seul dans l'arène", AS ~= nil and aA ~= nil and AS.L.arena.phase == "wait")
		W.tick(cfg.waitArena + 1)
		check(
			"25 s sans B : match annulé, A garde ses 200 trophées et son quota de combats",
			AS.L.arena.phase == "void" and aA.data.battle.pvp.trophies == 200 and aA.data.battle.live.fights == 0 and lastMsg(AS, 301, "liveVoid") ~= nil
		)
		check("B (absent) ne perd rien", sB.data.battle.pvp.trophies == 210 and sB.data.battle.live.fights == 0)
		W.tick(8)
		check("A renvoyé chez lui (hub)", W.home[301] ~= nil)
		local requeued, sec = false, 0
		while not requeued and sec < 150 do
			W.tick(1)
			sec = sec + 1
			local q = W.servers[2].L.queued[302]
			requeued = q ~= nil and q.state == "queued"
		end
		local tries = 0
		for _, t in ipairs(W.C.teleports) do
			if t.uid == 302 then
				tries = tries + 1
			end
		end
		check(
			"B : toujours là 30 s après TeleportAsync = échec ; 2 nouvelles tentatives (3 téléports) puis remise en file, priorité gardée (" .. tries .. ")",
			requeued and tries == 1 + cfg.teleportRetries and W.servers[2].L.queued[302].entry.t <= NOW + cfg.ccuPublish + 2 and W.C.maps[cfg.queueName]["u302"] ~= nil
		)
		check("B arrivé en retard dans une arène annulée : il serait renvoyé (arrivée refusée hors attente)", Ranked.arenaArrive(AS.L.arena, "b") == false)
		-- échec franc de TeleportAsync
		local W2 = newWorld(5, 2)
		local tA = W2.add(1, mkSession(311, 50))
		local tB = W2.add(2, mkSession(312, 60))
		seedCcu(W2.C, 100)
		W2.tick(cfg.ccuPublish + 1)
		W2.C.teleportFail = "TeleportInitFailed"
		W2.servers[1].L.enqueue(tA, CTX)
		W2.servers[2].L.enqueue(tB, CTX)
		local sawRetry, back, sec2 = false, false, 0
		while not back and sec2 < 40 do
			W2.tick(1)
			sec2 = sec2 + 1
			local q = W2.servers[1].L.queued[311]
			if q and q.state == "teleporting" and q.attempts >= 1 then
				sawRetry = true
			end
			back = sawRetry and q ~= nil and q.state == "queued"
		end
		check("Ticket reçu puis TeleportAsync en erreur : nouvelle tentative programmée", sawRetry)
		check("Après 3 échecs : remis en file avec un message, aucune téléportation enregistrée", back and #W2.C.teleports == 0 and W2.servers[1].notes[311] ~= nil)
		check("Entrée de nouveau dans la file MemoryStore", W2.C.maps[cfg.queueName]["u311"] ~= nil)
		W2.C.teleportFail = nil
		W2.C.saveFail = true
		local W3 = newWorld(6, 2)
		local vA = W3.add(1, mkSession(321, 50))
		local vB = W3.add(2, mkSession(322, 60))
		seedCcu(W3.C, 100)
		W3.tick(cfg.ccuPublish + 1)
		W3.C.saveFail = true
		W3.servers[1].L.enqueue(vA, CTX)
		W3.servers[2].L.enqueue(vB, CTX)
		W3.tick(15)
		check("Sauvegarde en échec : JAMAIS de téléportation (profil non écrit = pas de départ)", #W3.C.teleports == 0)
		check(
			"Annulation par le joueur pendant l'attente : retiré de la file",
			(function()
				local W4 = newWorld(7, 1)
				local x = W4.add(1, mkSession(331, 10))
				seedCcu(W4.C, 100)
				W4.tick(cfg.ccuPublish + 1)
				W4.servers[1].L.enqueue(x, CTX)
				W4.tick(3)
				local okc = W4.servers[1].L.cancel(x)
				return okc and x.pvpPending == nil and next(W4.C.maps[cfg.queueName] or {}) == nil
			end)()
		)
	end

	suite("Lot 14 (transport) : déconnexion en cours de match = forfait")
	do
		local function startMatch(seed, trA, trB)
			local W = newWorld(seed, 2)
			local sA = W.add(1, mkSession(401, trA))
			local sB = W.add(2, mkSession(402, trB))
			seedCcu(W.C, 100)
			W.tick(cfg.ccuPublish + 1)
			W.servers[1].L.enqueue(sA, CTX)
			W.servers[2].L.enqueue(sB, CTX)
			W.tick(7)
			local AS = W.arenas[next(W.arenas)]
			return W, AS, select(2, W.where(401)), select(2, W.where(402))
		end
		local W, AS, aA, aB = startMatch(8, 100, 100)
		check("Match en cours", AS and AS.L.arena.phase == "fight")
		for _ = 1, cfg.minTurnsForGain do
			AS.L.act(aA, "attack")
			AS.L.act(aB, "attack")
		end
		local over = AS.L.arena.phase ~= "fight"
		AS.L.onLeave(aB) -- PlayerRemoving de B (Main sauvegarde ensuite le profil, déjà débité)
		AS.sessions[aB.player] = nil
		check(
			"B se déconnecte après " .. cfg.minTurnsForGain .. " tours : forfait, B -15, A +25",
			over or (aB.data.battle.pvp.trophies == 85 and aA.data.battle.pvp.trophies == 125 and aB.data.battle.pvp.losses == 1)
		)
		check("A reçoit la fin du combat (forfait)", over or (lastMsg(AS, 401, "end") and lastMsg(AS, 401, "end").rewards.forfeit == true and lastMsg(AS, 401, "end").win == true))
		local W2, AS2, bA, bB = startMatch(9, 100, 100)
		AS2.L.onLeave(bA) -- départ immédiat (tour 0)
		AS2.sessions[bA.player] = nil
		check("Départ au tour 0 : le partant perd 15, le restant ne gagne rien (anti-nourrissage)", bA.data.battle.pvp.trophies == 85 and bB.data.battle.pvp.trophies == 100)
		local W3, AS3, cA, cB = startMatch(10, 100, 100)
		AS3.L.quit(cA)
		check("Abandon volontaire (battleQuit) = forfait", cA.data.battle.pvp.trophies == 85 and AS3.L.arena.phase == "done")
		local W4, AS4, dA, dB = startMatch(11, 100, 100)
		W4.tick(cfg.turnSeconds + 1)
		check("10 s sans action : tour joué avec l'attaque par défaut", AS4.L.arena.turns >= 1)
		check("Action d'un tiers ou invalide : ignorée", AS4.L.act({ player = { UserId = 999 } }, "attack") == false and AS4.L.act(dA, "swap9") == true and AS4.L.arena.acts.a == nil)
		local _ = W, W2, W3, dB
	end

	suite("Lot 14 (transport) : plafond journalier en direct")
	do
		local W = newWorld(12, 2)
		local sA = W.add(1, mkSession(501, 100))
		local sB = W.add(2, mkSession(502, 100))
		sA.data.battle.live = Ranked.sanitizeLive({ day = Ranked.day(NOW), fights = 3, gained = cfg.dailyTrophyCap - 10 }, cfg)
		sB.data.battle.live = Ranked.sanitizeLive({ day = Ranked.day(NOW), fights = 3, gained = cfg.dailyTrophyCap - 10 }, cfg)
		seedCcu(W.C, 100)
		W.tick(cfg.ccuPublish + 1)
		W.servers[1].L.enqueue(sA, CTX)
		W.servers[2].L.enqueue(sB, CTX)
		W.tick(7)
		local AS = W.arenas[next(W.arenas)]
		local aA, aB = select(2, W.where(501)), select(2, W.where(502))
		local n = 0
		while AS.L.arena.phase == "fight" and n < 60 do
			AS.L.act(aA, "attack")
			AS.L.act(aB, "attack")
			n = n + 1
		end
		local win = aA.data.battle.pvp.trophies > 100 and aA or aB
		local endMsg = lastMsg(AS, win.player.UserId, "end")
		check(
			"Gain rogné au reste du plafond (+10 au lieu de +25), signalé au client",
			win.data.battle.pvp.trophies == 110 and win.data.battle.live.gained == cfg.dailyTrophyCap and endMsg.rewards.capped == true
		)
		local back = mkSession(win.player.UserId, 0)
		back.data = deep(win.data)
		W.add(1, back)
		W.tick(1)
		local okq, why = W.servers[1].L.enqueue(back, CTX)
		check("Plafond atteint : nouvelle entrée en file refusée (« cap »)", okq == false and why == "cap")
		back.data.battle.live.day = Ranked.day(NOW) - 1
		back.liveOpAt = nil
		check("Le lendemain (jour UTC suivant) : de nouveau autorisé", W.servers[1].L.enqueue(back, CTX) == true)
	end

	suite("Lot 14 (transport) : 8 serveurs, 40 joueurs, pannes 20 % et lectures périmées")
	do
		local W = newWorld(13, 8)
		local rnd = mkRng(77)
		local all = {}
		for i = 1, 40 do
			local s = W.add(((i - 1) % 8) + 1, mkSession(1000 + i, math.floor(rnd() * 500), { 1 + (i % 18), 1 + ((i + 5) % 18), 1 + ((i + 11) % 18) }))
			all[#all + 1] = s
		end
		seedCcu(W.C, 100)
		W.tick(cfg.ccuPublish + 1)
		W.C.failRate, W.C.stale = 0.2, true
		local accepted = 0
		for i, s in ipairs(all) do -- (entrées acceptées malgré 20 % de pannes)
			local S = W.servers[((i - 1) % 8) + 1]
			local ok = S.L.enqueue(s, CTX)
			if not ok then -- panne à l'écriture : le joueur réessaie
				s.liveOpAt = nil
				ok = S.L.enqueue(s, CTX)
			end
			if ok then
				accepted = accepted + 1
			end
		end
		local maxLeaders = 0
		W.tick(80, function()
			local n = 0
			for _, S in ipairs(W.servers) do
				if S.L.isLeader then
					n = n + 1
				end
			end
			maxLeaders = math.max(maxLeaders, n)
		end)
		local dupMatch, fought = 0, 0 -- un joueur entré dans deux arènes (matchs distincts) ; un match annulé faute d'adversaire ne compte pas comme combat
		for _, set in pairs(W.arrived) do
			local n = 0
			for _ in pairs(set) do
				n = n + 1
			end
			if n > 1 then
				dupMatch = dupMatch + 1
			end
		end
		for _, AS in pairs(W.arenas) do
			if AS.L.arena and AS.L.arena.st then
				fought = fought + 1
			end
		end
		local tele, dupTele = {}, 0
		for _, t in ipairs(W.C.teleports) do
			if t.data.mode == "ranked" then
				if tele[t.uid] then
					dupTele = dupTele + 1
				end
				tele[t.uid] = true
			end
		end
		check("Jamais plus d'un leader à la fois (" .. maxLeaders .. ")", maxLeaders <= 1)
		check(
			"Aucun joueur apparié deux fois : jamais entré dans deux arènes (" .. W.C.reserves .. " réservations, " .. fought .. " combats, " .. accepted .. " entrées)",
			dupMatch == 0 and fought >= 5
		)
		check("Aucun joueur téléporté deux fois vers une arène", dupTele == 0)
		local lost = 0
		for _, s in ipairs(all) do
			local uid = s.player.UserId
			local S = W.where(uid)
			local fellBack = false
			for _, SS in ipairs(W.servers) do
				if lastMsg(SS, uid, "liveFallback") then
					fellBack = true
				end
			end
			-- état final admis : téléporté vers une arène, encore en file sur son serveur, ou repli proposé ; sinon il n'est jamais entré en file (panne
			-- à l'écriture deux fois de suite : le client garde le bouton, aucune perte)
			local okState = tele[uid] or (S ~= nil and (S.L.queued[uid] ~= nil or fellBack or not s.pvpPending))
			if not okState or (S == nil and not tele[uid]) then
				lost = lost + 1
			end
		end
		check("Aucun joueur perdu : chacun est en arène, encore en file ou a reçu le repli", lost == 0)
		W.C.failRate, W.C.stale = 0, false
		W.tick(40)
		local stuck = 0
		for _, AS in pairs(W.arenas) do
			if AS.L.arena and AS.L.arena.phase == "wait" then
				stuck = stuck + 1
			end
		end
		check("Toute arène finit par démarrer ou être annulée (aucune attente infinie)", stuck == 0)
	end
end

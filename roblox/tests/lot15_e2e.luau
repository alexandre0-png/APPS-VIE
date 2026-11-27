--!nocheck
-- Tests de bout en bout du lot 15 avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice, tests/FakeRuntime.lua) : migration v11 -> v12
-- (anciens profils, corrompus, double migration), rencontres de PNJ (conditions F.2, offre liée au joueur, combat résolu par le serveur, rejeu refusé,
-- reconnexion sans nouvelle rencontre), série de 7 jours (grâce, sauvetage, sac d'œufs), calendrier du 9b avec sac, quêtes bonus / semaine, plumes, réglage npc.off.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run_lot15.py ou tests/run.luau).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2 (runner lupa). État dans une table (limite de 200 variables locales).
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	suite("Lot 15 : intégration (vrai Main.server.lua + Data.lua) : migration v12, PNJ, série, sac d'œufs, quêtes, plumes")
	local Cfg0 = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } } })()
	T.RT = newRuntime({ fs = fs, luau = luau, placeId = Cfg0.Game.Places.game })
	if not T.RT then
		return
	end
	local RT = T.RT
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local cfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local function utc()
		return math.floor((1700000000 + math.floor(RT.now)) / 86400)
	end
	local function lastFired(name, p, from, pred)
		for i = #RT.fired, from or 1, -1 do
			local f = RT.fired[i]
			if f[1] == name and f[2] == p and (pred == nil or pred(f[3])) then
				return f[3], i
			end
		end
		return nil
	end
	local function act(p, a, arg)
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.15)
	end
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function eggCount(d)
		local n = 0
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "e" then
				n = n + 1
			end
		end
		return n + #d.eggBag
	end
	check("Lot 15 : remote serveur -> client « Npc » créé, aucune erreur au démarrage" .. errs(), RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Npc") ~= nil and #RT.errors == 0)

	---------------------------------------------------------------- 1. Migration v11 -> v12 : ancien profil, champs corrompus, double migration
	ds.data.P_9951 = { v = { ver = 11, coins = 7777, played = 9000, daily = utc() - 1, streak = 12, hatched = 40,
		slots = { { k = "p", p = 1, s = 2, m = 1 }, { k = "p", p = 1, s = 2, m = 1 }, { k = "e", t = 3, ends = 0 + 4e9, shield = 0 } },
		cal = { start = 0 }, plumes = 7, npc = "corrompu", grace = { week = "x", used = 9, weeks = -3 }, weekly = { w = 1e99, prog = { 999, "a" } }, event = { p = 1e9, k = 5 }, eggBag = { 3, 0, 99, "x", 4.7 },
	}, t = 1700000000 + RT.now - 5000 }
	T.p1 = RT.addPlayer("L15A", 9951, { from = "hub", partyId = "L15A", size = 2, late = false })
	RT.step(3)
	local s = hooks.session(T.p1)
	local d = s and s.data
	check("Migration v11 -> v12 : pièces, série, éclosions, pets et œufs conservés ; champs du lot 15 assainis (npc neuf, grâce bornée, semaine bornée, plumes bornées, sac filtré)" .. errs(),
		d ~= nil and d.ver == 13 and d.coins >= 7777 and d.streak == 12 and d.hatched == 40 and d.slots[1].k == "p" and d.slots[3].k == "e" and d.plumes == 7
		and type(d.npc) == "table" and d.npc.off == false and d.npc.trades == 0 and d.grace.used <= 1 and d.grace.weeks == 0 and d.grace.week == 0
		and type(d.weekly.prog) == "table" and d.weekly.prog[1] <= cfg.QUESTS.weekly.themes[1].goal and d.event.p <= cfg.PLUMES.balanceCap and d.event.k == ""
		and #d.eggBag == 2 and d.eggBag[1] == 3 and d.eggBag[2] == 4 and d.xp2Until == 0 and d.seasonXp == 0 and type(d.season) == "table" and #RT.errors == 0)
	local snap = lastFired("State", T.p1)
	check("Synchronisation : la vue du lot 15 (série, 7 jours, sac, quêtes, événements, réglage PNJ) est envoyée au client", snap ~= nil and type(snap.l15) == "table" and type(snap.l15.streak) == "table" and #snap.l15.days == 7 and snap.l15.bag == 2 and snap.l15.bagMax == 10 and type(snap.l15.weekly.themes) == "table" and #snap.l15.weekly.themes == 7 and snap.l15.npcOff == false and snap.dailyReady == true)
	RT.removePlayer(T.p1)
	RT.step(3)
	local r1 = ds.data.P_9951 and ds.data.P_9951.v
	check("Sauvegarde : le profil porte la version courante (13 au lot 16) et les champs npc, grace, weekly, event, eggBag", r1 ~= nil and r1.ver == 13 and type(r1.npc) == "table" and type(r1.grace) == "table" and type(r1.weekly) == "table" and type(r1.event) == "table" and type(r1.eggBag) == "table")
	-- double migration : relire le profil v12 ne change rien aux champs du lot 15
	local copyNpc = { trades = r1.npc.trades, nextAt = r1.npc.nextAt, off = r1.npc.off, day = r1.npc.day }
	T.p1 = RT.addPlayer("L15A", 9951, { from = "hub", partyId = "L15A", size = 2, late = false })
	RT.step(3)
	s = hooks.session(T.p1)
	d = s and s.data
	check("Relecture d'un profil v12 (double migration) : champs du lot 15 inchangés, sac identique, aucune erreur" .. errs(),
		d ~= nil and d.ver == 13 and d.npc.trades == copyNpc.trades and d.npc.nextAt == copyNpc.nextAt and d.npc.off == copyNpc.off and #d.eggBag == 2 and d.eggBag[2] == 4 and d.streak == 12 and #RT.errors == 0)
	-- profil plus récent (v14 depuis le lot 16) : lecture seule, rien n'est écrit
	ds.data.P_9952 = { v = { ver = 14, coins = 42, npc = { off = true } }, t = 1700000000 + RT.now - 5000 }
	T.p2 = RT.addPlayer("L15B", 9952, { from = "hub", partyId = "L15A", size = 2, late = false })
	RT.step(3)
	RT.removePlayer(T.p2)
	RT.step(3)
	check("Profil d'une version plus récente (v14) : jamais écrasé (garde « version plus récente »)", ds.data.P_9952.v.ver == 14 and ds.data.P_9952.v.coins == 42)

	---------------------------------------------------------------- 2. Série de 7 jours (vrai serveur) : réclamation, refus du doublon, grâce, sauvetage, sac
	d.daily, d.streak = utc() - 1, 3
	local before = eggCount(d)
	act(T.p1, "daily")
	check("Série : jour 4 réclamé (œuf Épique, pièces), daily = aujourd'hui, streak = 4" .. errs(), d.daily == utc() and d.streak == 4 and eggCount(d) == before + 1)
	local coins0 = d.coins
	act(T.p1, "daily")
	check("Série : seconde réclamation le même jour refusée (aucune pièce, aucun œuf)", d.streak == 4 and d.coins == coins0 and eggCount(d) == before + 1)
	-- un jour manqué : grâce gratuite (1 par semaine)
	d.daily, d.streak = utc() - 2, 4
	d.grace.week, d.grace.used = 0, 0
	act(T.p1, "daily")
	check("Série : un jour manqué -> jour de grâce consommé, la série continue (streak 5)", d.streak == 5 and d.grace.used == 1 and d.daily == utc())
	-- deux jours manqués : sauvetage ; « product » envoyé par le client est ignoré (seul le reçu le déclenche)
	d.daily, d.streak = utc() - 3, 5
	act(T.p1, "daily", { how = "product" })
	check("Série : 2 jours manqués -> sauvetage requis ; « product » venant du client est refusé (rien n'est réclamé)", d.daily == utc() - 3 and d.streak == 5)
	act(T.p1, "daily", { how = "quest" })
	check("Série : sauvetage gratuit refusé tant que les 3 missions du jour ne sont pas terminées", d.daily == utc() - 3)
	act(T.p1, "daily", { how = "reset" })
	check("Série : repartir du jour 1 (streak = 1)", d.daily == utc() and d.streak == 1)
	-- base pleine : l'œuf va dans le sac ; base ET sac pleins : réclamation refusée, rien n'est perdu
	for i = 1, cfg.SLOTS_MAX do
		if not d.slots[i] then
			d.slots[i] = { k = "p", p = 2, s = 2, m = 1 }
		end
	end
	d.daily, d.streak = utc() - 1, 1
	local bag0 = #d.eggBag
	act(T.p1, "daily")
	check("Série : base pleine -> l'œuf du jour 2 est rangé dans le sac d'œufs (jamais perdu)", #d.eggBag == bag0 + 1 and d.streak == 2)
	while #d.eggBag < cfg.EGG_BAG.size do
		d.eggBag[#d.eggBag + 1] = 1
	end
	d.daily, d.streak = utc() - 1, 3 -- jour 4 : un œuf
	local c1 = d.coins
	act(T.p1, "daily")
	check("Série : base ET sac pleins -> réclamation refusée sans rien modifier (ni pièces, ni série)", d.streak == 3 and d.coins == c1 and #d.eggBag == cfg.EGG_BAG.size)
	-- poser un œuf du sac : refusé base pleine, accepté avec une place libre
	act(T.p1, "bagPlace")
	check("Sac : poser un œuf avec la base pleine est refusé (le sac garde ses 10 œufs)", #d.eggBag == cfg.EGG_BAG.size)
	local freeI = 1 -- un pet de la base (emplacement 1, toujours dans la capacité)
	d.slots[freeI] = false
	act(T.p1, "bagPlace")
	check("Sac : avec une place libre, l'œuf le plus ancien est posé (incubation et bouclier), le sac perd exactement 1 œuf" .. errs(), #d.eggBag == cfg.EGG_BAG.size - 1 and d.slots[freeI] and d.slots[freeI].k == "e" and type(d.slots[freeI].ends) == "number" and type(d.slots[freeI].shield) == "number")

	---------------------------------------------------------------- 3. Calendrier du 9b : base pleine -> sac d'œufs (au lieu du refus)
	for i = 1, cfg.SLOTS_MAX do
		if not d.slots[i] then
			d.slots[i] = { k = "p", p = 2, s = 2, m = 1 }
		end
	end
	while #d.eggBag > 5 do
		table.remove(d.eggBag)
	end
	d.played = 99999
	d.cal = d.cal or {}
	T.calDay = nil
	for day = 1, cfg.CALENDAR.days do
		if cfg.CALENDAR.rewards[day].egg and not T.calDay then
			T.calDay = day
		end
	end
	RT.step(1.2) -- CalSys.tick démarre le cycle du joueur éligible
	if d.cal.start > 0 then
		d.cal.start = utc() - (T.calDay - 1) -- le jour du calendrier qui donne un œuf est aujourd'hui
	end
	local bagC = #d.eggBag
	act(T.p1, "calClaim", { day = T.calDay, how = "today" })
	RT.step(0.5)
	check("Calendrier (lot 9b réutilisé) : base pleine -> l'œuf du jour " .. tostring(T.calDay) .. " est rangé dans le sac (plus de refus)" .. errs(), #d.eggBag == bagC + 1 and #RT.errors == 0)

	---------------------------------------------------------------- 4. PNJ : conditions, offre liée au joueur, combat résolu par le serveur, rejeu refusé
	for i = 1, cfg.SLOTS_MAX do
		d.slots[i] = false
	end
	d.slots[1] = { k = "p", p = 4, s = 2, m = 1 }
	d.slots[2] = { k = "p", p = 4, s = 2, m = 1 }
	d.slots[3] = { k = "p", p = 4, s = 2, m = 1 }
	d.slots[4] = { k = "p", p = 5, s = 2, m = 1 }
	d.battle.team = { 4 }
	d.npc.nextAt, d.npc.off = 0, false
	local root = T.p1.Character and T.p1.Character:FindFirstChild("HumanoidRootPart")
	if root then
		rawget(root, "__props").Position = RT.vec(0, 3, 30) -- sur la place, hors de tout territoire
	end
	s.npcStart = 1700000000 + math.floor(RT.now) - 60 -- session commencée il y a 1 min : trop tôt
	local n0 = #RT.fired + 1
	RT.step(6)
	check("PNJ : aucune rencontre pendant les 8 premières minutes de la session", lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end) == nil)
	s.npcStart = 1700000000 + math.floor(RT.now) - 9 * 60
	s.carry = { { t = 1 } }
	n0 = #RT.fired + 1
	RT.step(6)
	check("PNJ : aucune rencontre en portant un œuf", lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end) == nil)
	s.carry = {}
	n0 = #RT.fired + 1
	RT.step(6)
	local offer = lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end)
	check("PNJ : après 8 min, hors états interdits, une rencontre est proposée (identifiant, 60 s, dialogue, position à 25 studs)" .. errs(),
		offer ~= nil and type(offer.id) == "string" and offer.seconds == 60 and type(offer.approach) == "string" and offer.approach ~= "" and type(offer.x) == "number" and #RT.errors == 0)
	T.offer = offer
	if offer then
		local dx, dz = offer.x - 0, offer.z - 30
		check("PNJ : point d'apparition à 25 studs du joueur, dans la zone de la place (jamais dans un territoire)", math.abs(math.sqrt(dx * dx + dz * dz) - 25) < 0.01 and cfg.zoneAt(offer.x, offer.z) == "arena")
		local txt = string.lower(offer.approach .. " " .. tostring(offer.text))
		check("PNJ : aucun Robux ni produit dans le dialogue", string.find(txt, "robux", 1, true) == nil and string.find(txt, "r$", 1, true) == nil)
		check("PNJ : première rencontre = combat (alternance F.2), comptée dès l'apparition (quota persistant)", (offer.kind == "fight" or offer.kind == "champion") and (d.npc.fights == 1 or d.npc.champ > 0))
		-- un autre joueur ne peut pas répondre à cette offre
		T.p3 = RT.addPlayer("L15C", 9953, { from = "hub", partyId = "L15A", size = 2, late = false })
		RT.step(3)
		local s3 = hooks.session(T.p3)
		act(T.p3, "npcAnswer", { id = offer.id, action = "accept" })
		check("PNJ : l'offre est liée au userId (un autre joueur ne peut pas l'accepter)", s3 ~= nil and s3.battle == nil and s.battle == nil)
		-- type de charge utile invalide : ignoré sans erreur
		act(T.p1, "npcAnswer", "x")
		act(T.p1, "npcAnswer", { id = 5, action = "accept" })
		act(T.p1, "npcAnswer", { id = string.rep("a", 200), action = "accept" })
		check("PNJ : charges utiles invalides ignorées sans erreur" .. errs(), s.battle == nil and #RT.errors == 0)
		-- accepter : combat lancé par le serveur
		act(T.p1, "npcAnswer", { id = offer.id, action = "accept" })
		check("PNJ : accepter lance un combat PvE contre l'équipe du PNJ (3 adversaires)" .. errs(), s.battle ~= nil and s.battle.npc ~= nil and #s.battle.st.sides[2].units == 3)
		local coinsB = d.coins
		act(T.p1, "battleQuit")
		local res = lastFired("Npc", T.p1, n0, function(m)
			return type(m) == "table" and m.k == "said"
		end)
		check("PNJ : abandon = défaite résolue par le serveur (aucune pièce, +5 XP, dialogue de défaite)" .. errs(), s.battle == nil and d.coins == coinsB and (d.slots[4].x or 0) == cfg.NPC_RULES.lossXp and res ~= nil)
		act(T.p1, "npcAnswer", { id = offer.id, action = "accept" })
		check("PNJ : rejouer l'identifiant d'une offre déjà résolue est refusé (aucun combat)", s.battle == nil)
	end
	-- échange (rencontre paire) : offre appliquée en une fois, rejeu refusé ; puis refus « Pas maintenant » (10 min de calme)
	d.npc.enc, d.npc.nextAt = 1, 0
	d.coins = 1e7
	d.dex = { ["4"] = { n = 3, b = 1 }, ["5"] = { n = 1, b = 1 } }
	n0 = #RT.fired + 1
	RT.step(6)
	local tr = lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end)
	check("PNJ : deuxième rencontre = échange (Pip ou Nora), vue « tu donnes / tu reçois » envoyée" .. errs(), tr ~= nil and tr.kind == "trade" and type(tr.view) == "table" and type(tr.view.give) == "table" and type(tr.view.get) == "table")
	if tr then
		local pets0, eggs0, coins0b = 0, eggCount(d), d.coins
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "p" then
				pets0 = pets0 + 1
			end
		end
		act(T.p1, "npcAnswer", { id = tr.id, action = "accept", confirm2 = true })
		local pets1 = 0
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "p" then
				pets1 = pets1 + 1
			end
		end
		local price = 0
		for _, g in ipairs(tr.view.give) do
			if g.kind == "coins" then
				price = g.amount
			end
		end
		local gotEgg, gotPet, gavePets = false, false, 0
		for _, g in ipairs(tr.view.get) do
			gotEgg = gotEgg or g.kind == "egg"
			gotPet = gotPet or g.kind == "pet"
		end
		for _, g in ipairs(tr.view.give) do
			if g.kind == "pet" then
				gavePets = gavePets + 1
			end
		end
		check("PNJ : échange appliqué exactement (pièces - prix, pets donnés retirés, œuf ou pet reçu, rien de plus)" .. errs(),
			d.coins == coins0b - price and eggCount(d) == eggs0 + (gotEgg and 1 or 0) and pets1 == pets0 - gavePets + (gotPet and 1 or 0) and #RT.errors == 0)
		local coins2 = d.coins
		act(T.p1, "npcAnswer", { id = tr.id, action = "accept", confirm2 = true })
		check("PNJ : rejouer un échange déjà conclu est refusé (aucune pièce débitée, aucun œuf ajouté)", d.coins == coins2 and eggCount(d) == eggs0 + (gotEgg and 1 or 0))
		check("PNJ : quête de la semaine « PNJ » avancée par les rencontres terminées", d.weekly.prog[7] >= 2)
	end
	d.npc.nextAt = 0
	n0 = #RT.fired + 1
	RT.step(6)
	local o3 = lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end)
	if o3 then
		local tnow = 1700000000 + math.floor(RT.now)
		act(T.p1, "npcAnswer", { id = o3.id, action = "decline" })
		check("PNJ : « Pas maintenant » -> aucun autre PNJ pendant 10 min, refus compté pour ce PNJ", d.npc.nextAt >= tnow + cfg.NPC_ENCOUNTER.snoozeMinutes * 60 and (d.npc.refuse[o3.npc] or 0) >= 1)
	else
		check("PNJ : une troisième rencontre a lieu (quota 4 + 4 non atteint)", false)
	end
	-- réglage « Ne plus être interpellé »
	act(T.p1, "npcOff", true)
	d.npc.nextAt = 0
	n0 = #RT.fired + 1
	RT.step(6)
	check("PNJ : npc.off = true -> plus aucune rencontre", d.npc.off == true and lastFired("Npc", T.p1, n0, function(m)
		return type(m) == "table" and m.k == "offer"
	end) == nil)
	act(T.p1, "npcOff", "oui")
	check("PNJ : réglage npcOff refuse une valeur non booléenne", d.npc.off == true)
	act(T.p1, "npcOff", false)
	-- reconnexion : les compteurs et nextAt du profil empêchent une nouvelle rencontre immédiate
	local fights = d.npc.fights
	d.npc.nextAt = 1700000000 + math.floor(RT.now) + 300
	RT.removePlayer(T.p1)
	RT.step(3)
	T.p1 = RT.addPlayer("L15A", 9951, { from = "hub", partyId = "L15A", size = 2, late = false })
	RT.step(3)
	s = hooks.session(T.p1)
	d = s and s.data
	if s then
		s.npcStart = 1700000000 + math.floor(RT.now) - 20 * 60
	end
	n0 = #RT.fired + 1
	RT.step(6)
	check("PNJ : reconnexion (ou autre serveur) : compteurs du jour et nextAt relus du profil, aucune nouvelle rencontre avant nextAt" .. errs(),
		d ~= nil and d.npc.fights == fights and d.npc.nextAt > 1700000000 + math.floor(RT.now) and lastFired("Npc", T.p1, n0, function(m)
			return type(m) == "table" and m.k == "offer"
		end) == nil and #RT.errors == 0)

	---------------------------------------------------------------- 5. Quêtes bonus et de la semaine, plumes
	act(T.p1, "weeklyClaim", 6)
	act(T.p1, "weeklyClaim", 5)
	check("Semaine : palier invalide ignoré ; palier 5/7 refusé tant que les quêtes ne sont pas faites", d.weekly.c5 == false)
	for i, th in ipairs(cfg.QUESTS.weekly.themes) do
		d.weekly.prog[i] = th.goal
	end
	local e0 = eggCount(d)
	T.sx0 = d.season.xp
	act(T.p1, "weeklyClaim", 5)
	act(T.p1, "weeklyClaim", 5)
	act(T.p1, "weeklyClaim", 7)
	check("Semaine : 5/7 puis 7/7 réclamés une fois chacun (2 œufs, 300 XP de passe de combat : lot 16, season.xp)" .. errs(), d.weekly.c5 == true and d.weekly.c7 == true and eggCount(d) == e0 + 2 and d.seasonXp == 0 and d.season.xp == T.sx0 + 300)
	act(T.p1, "bonusClaim")
	check("Quête bonus : refusée tant qu'elle n'est pas terminée", eggCount(d) == e0 + 2)
	act(T.p1, "plumeBuy")
	check("Plumes : achat de l'Œuf Exclusif refusé hors événement / sans plumes (rien n'est débité)", eggCount(d) == e0 + 2 and d.event.x == 0)
	RT.removePlayer(T.p1)
	if T.p3 then
		RT.removePlayer(T.p3)
	end
	RT.step(3)
	check("Lot 15 (intégration) : aucune erreur serveur" .. errs(), #RT.errors == 0)
end

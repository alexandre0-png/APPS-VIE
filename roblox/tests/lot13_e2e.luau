--!nocheck
-- Tests de bout en bout du lot 13 avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice, tests/FakeRuntime.lua) : défi envoyé / refusé / expiré / accepté,
-- validations serveur (soi-même, équipe vide, réglage « refuser », occupé, cooldown, arguments invalides), duel complet sur le sable (vue en miroir pour le défié,
-- tours à deux, forfait d'inactivité, récompense en pièces plafonnée, aucun trophée), spectateurs, abandon, départ en plein duel (défaite sauvegardée, aucune fuite),
-- remise de saison max(300, floor(t x 0,6)) et paliers de ligue, ratio PvE après un combat de la tour.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime }. Style : pas de `+=`, pas de `continue`, état dans une table T.
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	suite("Lot 13 : intégration (vrai Main.server.lua + Data.lua) : défis, duel sur le sable, spectateurs, départ, saison, ligues, ratio PvE")
	local Cfg0 = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } } })()
	T.RT = newRuntime and newRuntime({ fs = fs, luau = luau, placeId = Cfg0.Game.Places.game }) or nil
	if not T.RT then
		check("Lot 13 e2e : runtime factice disponible", newRuntime == nil)
		return
	end
	local RT = T.RT
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function act(p, a, arg)
		RT.now = RT.now + 1.1
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.2)
	end
	local function notified(p, frag, from)
		for i = #RT.fired, from or 1, -1 do
			local f = RT.fired[i]
			if f[1] == "Notify" and f[2] == p and type(f[3]) == "string" and f[3]:find(frag, 1, true) then
				return true
			end
		end
		return false
	end
	local function battleMsg(p, k, from) -- dernier message RBattle de type k reçu par p depuis l'indice `from`
		for i = #RT.fired, from or 1, -1 do
			local f = RT.fired[i]
			if f[1] == "Battle" and f[2] == p and type(f[3]) == "table" and f[3].k == k then
				return f[3]
			end
		end
		return nil
	end
	local function root(p)
		return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	end
	local function setPos(p, x, z)
		local r = root(p)
		if r then
			rawget(r, "__props").Position = RT.vec(x, 4, z)
		end
	end
	local function ready(p, pet)
		local s = hooks.session(p)
		local d = s.data
		d.newbieOff, s.graceUntil = true, 0
		d.slots[1] = { k = "p", p = pet or 1, s = 2, m = 1 }
		d.slots[2] = { k = "p", p = 2, s = 2, m = 1 }
		d.battle.team = { 1, 2 }
		return s
	end
	local function duelCount()
		local n = 0
		for _ in pairs(hooks.duel().matches) do
			n = n + 1
		end
		return n
	end
	check("Démarrage sans erreur, état des duels exposé aux tests" .. errs(), #RT.errors == 0 and type(hooks.duel) == "function" and type(hooks.duel().book) == "table")

	T.A = RT.addPlayer("DuelA", 13001, { from = "hub", partyId = "L13", size = 3, late = false })
	T.B = RT.addPlayer("DuelB", 13002, { from = "hub", partyId = "L13", size = 3, late = false })
	T.C = RT.addPlayer("DuelC", 13003, { from = "hub", partyId = "L13", size = 3, late = false })
	RT.step(3)
	T.sA, T.sB, T.sC = ready(T.A), ready(T.B, 3), ready(T.C)
	check("Profils neufs : battle.duel = 0 V / 0 D, battle.pve présent, réglage duelOff faux" .. errs(), T.sA.data.battle.duel.w == 0 and T.sA.data.battle.duel.l == 0 and type(T.sA.data.battle.pve) == "table" and T.sA.data.settings.duelOff == false)

	---------------------------------------------------------------- 1. Validations serveur
	T.f0 = #RT.fired + 1
	act(T.A, "duelChallenge", 13001)
	act(T.A, "duelChallenge", "13002")
	act(T.A, "duelChallenge", 0 / 0)
	act(T.A, "duelChallenge", 1.5)
	act(T.A, "duelChallenge", 99999)
	check("Soi-même refusé ; texte, NaN, décimal, joueur absent ignorés (aucune demande envoyée)", notified(T.A, "toi-même", T.f0) and battleMsg(T.B, "duelAsk", T.f0) == nil and errs() == "")
	T.sA.data.battle.team = {}
	act(T.A, "duelChallenge", 13002)
	check("Équipe de pets vide : défi refusé", notified(T.A, "équipe de pets", T.f0) and battleMsg(T.B, "duelAsk", T.f0) == nil)
	T.sA.data.battle.team = { 1, 2 }
	T.sA.carry[1] = 3
	act(T.A, "duelChallenge", 13002)
	T.sA.carry[1] = nil
	check("Œuf porté : défi refusé (cas E.2)", notified(T.A, "œuf dans les mains", T.f0) and battleMsg(T.B, "duelAsk", T.f0) == nil)
	setPos(T.B, 0, 120)
	act(T.A, "duelChallenge", 13002)
	setPos(T.B, 0, 40)
	check("Distance > 30 studs : défi refusé", notified(T.A, "Trop loin", T.f0) and battleMsg(T.B, "duelAsk", T.f0) == nil)
	act(T.B, "duelOff", true)
	act(T.A, "duelChallenge", 13002)
	check("Réglage « refuser automatiquement » du défié : défi refusé, réglage sauvegardé dans le profil", notified(T.A, "refuse les duels", T.f0) and battleMsg(T.B, "duelAsk", T.f0) == nil and T.sB.data.settings.duelOff == true)
	act(T.B, "duelOff", "oui")
	check("duelOff : valeur non booléenne ignorée", T.sB.data.settings.duelOff == true)
	act(T.B, "duelOff", false)

	---------------------------------------------------------------- 2. Défi refusé puis cooldown
	T.f1 = #RT.fired + 1
	act(T.A, "duelChallenge", 13002)
	T.ask = battleMsg(T.B, "duelAsk", T.f1)
	check("Défi valide : le défié reçoit duelAsk { from, fromId, seconds = 20 }", T.ask ~= nil and T.ask.fromId == 13001 and T.ask.from == "DuelA" and T.ask.seconds == 20)
	act(T.B, "duelAnswer", { from = 13001, accept = false })
	check("Refus : le défieur est prévenu, aucun duel", notified(T.A, "a refusé", T.f1) and duelCount() == 0 and T.sA.battle == nil)
	act(T.A, "duelChallenge", 13002)
	check("Même cible juste après : cooldown de 120 s", notified(T.A, "attends un peu", T.f1))
	act(T.B, "duelAnswer", { from = 13001, accept = true })
	check("Réponse à un défi inexistant : aucun duel", duelCount() == 0 and T.sB.battle == nil)

	---------------------------------------------------------------- 3. Défi expiré
	T.f2 = #RT.fired + 1
	act(T.C, "duelChallenge", 13002)
	check("C défie B : demande reçue", battleMsg(T.B, "duelAsk", T.f2) ~= nil)
	act(T.C, "duelChallenge", 13001)
	check("Un seul défi sortant en attente à la fois", notified(T.C, "encore en attente", T.f2))
	RT.now = RT.now + 21
	RT.step(1.2)
	check("20 s sans réponse : défi expiré, le défieur est prévenu, la fenêtre du défié est fermée (duelAskEnd)", notified(T.C, "expiré", T.f2) and battleMsg(T.B, "duelAskEnd", T.f2) ~= nil)
	act(T.B, "duelAnswer", { from = 13003, accept = true })
	check("Accepter un défi expiré : aucun duel", duelCount() == 0 and T.sB.battle == nil)

	---------------------------------------------------------------- 4. Duel accepté : sable, vue en miroir, occupé, spectateur
	RT.now = RT.now + 125
	RT.step(0.6)
	T.coinsA0, T.coinsB0, T.trA0, T.trB0 = T.sA.data.coins, T.sB.data.coins, T.sA.data.battle.pvp.trophies, T.sB.data.battle.pvp.trophies
	T.f3 = #RT.fired + 1
	act(T.A, "duelChallenge", 13002)
	act(T.C, "duelChallenge", 13002)
	act(T.B, "duelAnswer", { from = 13001, accept = true })
	T.stA, T.stB = battleMsg(T.A, "start", T.f3), battleMsg(T.B, "start", T.f3)
	check("Duel accepté : les deux reçoivent start (duel, intro, colisée) et sont occupés" .. errs(), T.stA ~= nil and T.stB ~= nil and T.stA.duel == true and T.stB.duel == true and T.sA.battle ~= nil and T.sA.battle.duel ~= nil and T.sB.battle ~= nil and duelCount() == 1)
	check("Vue en miroir : chacun voit SON équipe en camp 1 (A : pet 1, B : pet 3)", T.stA and T.stA.view.sides[1].units[1].p == 1 and T.stB.view.sides[1].units[1].p == 3 and T.stB.view.sides[2].units[1].p == 1)
	check("Intro B.4 : ratio de duel, ligue et trophées des deux côtés", T.stA and T.stA.intro.me.name == "DuelA" and T.stA.intro.foe.name == "DuelB" and type(T.stA.intro.me.league) == "string" and T.stA.intro.me.league ~= "" and T.stA.intro.me.wins == 0)
	check("Sur le sable : personnages figés, placés à ±10 du centre du colisée", root(T.A).Anchored == true and root(T.B).Anchored == true and math.abs(root(T.A).CFrame.X - (cfg.Map2.arena.x - 10)) < 0.01 and math.abs(root(T.B).CFrame.X - (cfg.Map2.arena.x + 10)) < 0.01)
	check("Défi croisé de C vers B annulé à l'acceptation (C prévenu)", notified(T.C, "déjà en duel", T.f3))
	act(T.C, "duelChallenge", 13001)
	check("Défier un joueur en duel : « Un combat est déjà en cours »", notified(T.C, "déjà en cours", T.f3))
	act(T.A, "towerStart", 1)
	act(T.A, "pvpStart")
	act(T.A, "setTeam", { 2 })
	check("Pendant le duel : tour, classé et changement d'équipe bloqués", T.sA.battle.duel ~= nil and #T.sA.data.battle.team == 2)
	setPos(T.C, cfg.Map2.arena.x + 30, cfg.Map2.arena.z + 20)

	---------------------------------------------------------------- 5. Tours à deux
	T.f4 = #RT.fired + 1
	act(T.A, "battleAct", "attack")
	check("Une seule action : le tour attend l'adversaire", battleMsg(T.A, "turn", T.f4) == nil)
	act(T.A, "battleAct", "attack")
	act(T.B, "battleAct", "swap9")
	act(T.B, "battleAct", "attack")
	T.tA, T.tB = battleMsg(T.A, "turn", T.f4), battleMsg(T.B, "turn", T.f4)
	check("Les deux ont choisi : tour résolu tout de suite, envoyé aux deux (vue en miroir pour B)" .. errs(), T.tA ~= nil and T.tB ~= nil and T.tA.view.turn == 1 and T.tB.view.sides[1].units[1].p == 3 and T.tA.view.sides[1].units[1].p == 1)
	check("Action invalide (swap9) refusée sans casser le tour", notified(T.B, "Action impossible", T.f4))
	T.w = battleMsg(T.C, "duelWatch", T.f4)
	check("Spectateur proche du colisée : bandeau duelWatch (noms, vue, tour)", T.w ~= nil and T.w.a == "DuelA" and T.w.b == "DuelB" and T.w.view.turn == 1)
	check("Joueur loin du colisée : rien reçu", battleMsg(T.A, "duelWatch", T.f4) == nil)

	---------------------------------------------------------------- 6. Forfait d'inactivité (A ne joue plus 2 tours) : B gagne, pièces plafonnées, aucun trophée
	T.f5 = #RT.fired + 1
	T.over = false
	for _ = 1, 2 do
		if hooks.duel().matches and duelCount() == 1 then
			act(T.B, "battleAct", "attack")
		end
		RT.now = RT.now + 11
		RT.step(0.6)
	end
	T.endA, T.endB = battleMsg(T.A, "end", T.f5), battleMsg(T.B, "end", T.f5)
	T.koOrForfeit = T.endB ~= nil and T.endB.win == true
	check("Fin du duel (forfait ou KO) : les deux reçoivent end, duel libéré" .. errs(), T.endA ~= nil and T.endB ~= nil and duelCount() == 0 and T.sA.battle == nil and T.sB.battle == nil)
	check("Vainqueur B : ratio 1 V / 0 D pour B, 0 V / 1 D pour A", T.koOrForfeit and T.sB.data.battle.duel.w == 1 and T.sA.data.battle.duel.l == 1 and T.sA.data.battle.duel.w == 0)
	check("Récompense : B +1 min de revenus (pièces), A +15 s ; jamais de trophée", type(T.endB.rewards.coins) == "number" and T.endB.rewards.coins > 0 and type(T.endA.rewards.coins) == "number" and T.endA.rewards.coins < T.endB.rewards.coins and T.sB.data.coins > T.coinsB0 and T.sA.data.battle.pvp.trophies == T.trA0 and T.sB.data.battle.pvp.trophies == T.trB0)
	check("Quotas du jour comptés (1 duel récompensé, paire notée)", T.sB.data.battle.duel.n == 1 and T.sB.data.battle.duel.pairs["13001"] == 1)
	check("Personnages libérés après le duel", root(T.A).Anchored == false and root(T.B).Anchored == false)
	check("Spectateur : bandeau final avec le vainqueur", (function()
		local w = battleMsg(T.C, "duelWatch", T.f5)
		return w ~= nil and w.over == true and w.winner == "DuelB"
	end)())

	---------------------------------------------------------------- 7. Plafond par paire : 4e duel contre le même joueur = pas de pièces
	T.sB.data.battle.duel.pairs["13001"] = 3
	RT.now = RT.now + 125
	T.f6 = #RT.fired + 1
	act(T.A, "duelChallenge", 13002)
	act(T.B, "duelAnswer", { from = 13001, accept = true })
	check("Nouveau duel A contre B accepté", duelCount() == 1)
	T.coinsB1 = T.sB.data.coins
	act(T.A, "battleQuit")
	check("Abandon = forfait : B gagne ; plafond de paire atteint et abandon au 1er tour : aucune pièce pour B" .. errs(), duelCount() == 0 and T.sB.data.battle.duel.w == 2 and (battleMsg(T.B, "end", T.f6) or {}).rewards.coins == nil and T.sB.data.coins - T.coinsB1 < 20 and T.sA.data.battle.duel.l == 2)

	---------------------------------------------------------------- 8. Départ en plein duel
	RT.now = RT.now + 125
	setPos(T.C, 0, 40)
	act(T.C, "duelChallenge", 13002)
	act(T.B, "duelAnswer", { from = 13003, accept = true })
	check("Duel C contre B accepté", duelCount() == 1 and T.sC.battle ~= nil)
	T.f7 = #RT.fired + 1
	T.coinsB2 = T.sB.data.coins
	RT.removePlayer(T.C)
	RT.step(3)
	T.saved = ds.data.P_13003 and ds.data.P_13003.v
	T.endL = battleMsg(T.B, "end", T.f7)
	check("C quitte : forfait, B gagne (sans pièces : départ au 1er tour), B libéré, aucune erreur" .. errs(), duelCount() == 0 and T.sB.battle == nil and T.sB.data.battle.duel.w == 3 and T.endL ~= nil and T.endL.rewards.coins == nil and T.endL.win == true)
	check("La défaite de C est écrite dans le profil sauvegardé au départ", T.saved ~= nil and type(T.saved.battle) == "table" and type(T.saved.battle.duel) == "table" and T.saved.battle.duel.l == 1)
	check("Aucun défi ni duel actif ne reste en mémoire pour C", hooks.duel().book.active[13003] == nil and hooks.duel().book.pending[13003] == nil)

	---------------------------------------------------------------- 9. Relecture du profil (ancien profil sans battle.duel) et remise de saison
	T.season = cfg.pvpSeason(1700000000 + math.floor(RT.now))
	ds.data.P_13004 = { v = { ver = 13, coins = 100, battle = { team = {}, best = 0, pvp = { season = T.season - 1, trophies = 1000, wins = 4, losses = 2, defense = {} } } }, t = 1700000000 + RT.now - 5000 }
	ds.data.P_13005 = { v = { ver = 13, coins = 100, battle = { team = {}, best = 0, pvp = { season = T.season - 1, trophies = 250, wins = 1, losses = 0, defense = {} } } }, t = 1700000000 + RT.now - 5000 }
	ds.data.P_13006 = { v = { ver = 13, coins = 100, battle = { team = {}, best = 0, pvp = { season = T.season - 1, trophies = 1600, wins = 1, losses = 0, defense = {} } } }, t = 1700000000 + RT.now - 5000 }
	T.f8 = #RT.fired + 1
	T.D = RT.addPlayer("Saison1000", 13004, { from = "hub", partyId = "L13", size = 3, late = false })
	T.E = RT.addPlayer("Saison250", 13005, { from = "hub", partyId = "L13", size = 3, late = false })
	T.F = RT.addPlayer("Saison1600", 13006, { from = "hub", partyId = "L13", size = 3, late = false })
	RT.step(3)
	T.dD, T.dE, T.dF = hooks.session(T.D).data, hooks.session(T.E).data, hooks.session(T.F).data
	check("Ancien profil sans battle.duel / pve relu sans erreur (0 / 0)" .. errs(), T.dD.battle.duel.w == 0 and T.dD.battle.duel.l == 0 and T.dD.battle.pve.w == 0)
	check("Remise de saison : 1000 -> 600, 250 inchangé, 1600 -> 960", T.dD.battle.pvp.trophies == 600 and T.dE.battle.pvp.trophies == 250 and T.dF.battle.pvp.trophies == 960 and T.dD.battle.pvp.season == T.season)
	T.myth = cfg.tierIndexByName("Mythique")
	T.mythCount = function(d)
		local n = 0
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "e" and d.slots[i].t == T.myth then
				n = n + 1
			end
		end
		for _, t in ipairs(d.eggBag or {}) do
			if t == T.myth then
				n = n + 1
			end
		end
		return n + ((d.overflow or {})[tostring(T.myth)] or 0)
	end
	T.nowT = 1700000000 + math.floor(RT.now)
	check("Récompense de saison : palier 1000 = 400 000 pièces ; palier 1500 = 1 œuf Mythique (un seul) + potion de chance 30 min + titre, AUCUNE pièce",
		T.dD.coins >= 400100 and T.myth ~= nil and T.mythCount(T.dF) == 1 and T.dF.coins < 1000 and T.dF.luckUntil >= T.nowT + 1800 - 10 and T.dF.luckUntil <= T.nowT + 1800 + 10 and notified(T.F, "Champion de la saison", T.f8) and notified(T.F, "Mythique", T.f8) and notified(T.F, "30 min", T.f8))
	T.f9 = #RT.fired + 1
	T.sF = hooks.session(T.F)
	for i = 1, cfg.SLOTS_MAX do
		if not T.dF.slots[i] then
			T.dF.slots[i] = { k = "e", t = 1, ends = 1700000000 + RT.now + 1e6, shield = 0 }
		end
	end
	while #T.dF.eggBag < cfg.EGG_BAG.size do
		T.dF.eggBag[#T.dF.eggBag + 1] = 1
	end
	T.ov0 = T.dF.overflow[tostring(T.myth)] or 0
	T.dF.battle.pvp.season, T.dF.battle.pvp.trophies = T.season - 1, 1600
	act(T.F, "pvpDefense")
	check("Palier 1500 avec base ET sac pleins : l'œuf Mythique va dans le coffre de débordement (jamais perdu, un seul crédit)" .. errs(), (T.dF.overflow[tostring(T.myth)] or 0) == T.ov0 + 1 and notified(T.F, "coffre de débordement", T.f9) and T.dF.battle.pvp.season == T.season)
	check("Paliers PvP historiques inchangés (Config.pvpSeasonReward)", cfg.pvpSeasonReward(1600).coins == 400000)

	---------------------------------------------------------------- 10. Ligue dans l'état envoyé au client, ratio PvE après la tour
	T.snap = nil
	for i = #RT.fired, T.f8, -1 do
		local f = RT.fired[i]
		if f[1] == "State" and f[2] == T.D and type(f[3]) == "table" and type(f[3].battle) == "table" then
			T.snap = f[3]
			break
		end
	end
	check("État client : ligue (« 🥇 Or » à 600 trophées), ratios duel et PvE, réglage duelOff", T.snap ~= nil and T.snap.battle.league == "🥇 Or" and type(T.snap.battle.duel) == "table" and type(T.snap.battle.pve) == "table" and T.snap.settings.duelOff == false)
	T.pve0 = T.sA.data.battle.pve.l
	act(T.A, "towerStart", 1)
	act(T.A, "battleQuit")
	check("Combat de la tour abandonné : battle.pve.l + 1 (ratio PvE de l'intro)", T.sA.data.battle.pve.l == T.pve0 + 1 and T.sA.battle == nil)
	check("Aucune erreur serveur sur tout le scénario" .. errs(), #RT.errors == 0)
end

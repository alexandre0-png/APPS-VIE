--!nocheck
-- Tests de bout en bout du lot 14 avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice, tests/FakeRuntime.lua) :
-- (1) interface désactivée par défaut : `liveQueue` lance le classé enregistré, AUCUNE requête MemoryStore de file ; profil `battle.live` assaini ;
-- (2) serveur « ranked » : un seul joueur du match arrive = match annulé à 25 s, aucun trophée ni combat consommé ; intrus renvoyé ; pas de duel local ;
-- (3) serveur « ranked » : les deux arrivent, combat à deux par `battleAct` (vue en miroir pour B), abandon = forfait (avant 3 tours : 0 pour le gagnant, -15 pour le perdant).
-- Le match est injecté dans le MemoryStore factice (HashMap PvpMatch_v1), comme l'écrirait l'apparieur. Rien n'est testé en ligne.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime }. Style : pas de `+=`, pas de `continue`, état dans une table T.
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	suite("Lot 14 : intégration (vrai Main.server.lua + Data.lua) : interface désactivée, serveur « ranked », match annulé, combat à deux")
	if not newRuntime then
		check("Lot 14 e2e : runtime factice disponible", true)
		return
	end
	local Cfg0 = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } } })()
	check("Config.PVP_LIVE.enabled = false dans la source (activer seulement après le test réel à 2 comptes)", Cfg0.PVP_LIVE.enabled == false and Cfg0.PVP_LIVE.minCCU == 60)
	local function boot(memory)
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Cfg0.Game.Places.game })
		if not RT then
			return nil
		end
		RT.memory = memory
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
		return {
			RT = RT, cfg = RT.require(Shared:FindFirstChild("Config")),
			hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks,
			RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action"),
		}
	end
	local function errs(W)
		return #W.RT.errors == 0 and "" or (" : " .. tostring(W.RT.errors[1]))
	end
	local function act(W, p, a, arg)
		W.RT.now = W.RT.now + 1.1
		W.RT.fire(W.RAction, "OnServerEvent", p, a, arg)
		W.RT.step(0.3)
	end
	local function battleMsg(W, p, k, from)
		for i = #W.RT.fired, from or 1, -1 do
			local f = W.RT.fired[i]
			if f[1] == "Battle" and f[2] == p and type(f[3]) == "table" and f[3].k == k then
				return f[3]
			end
		end
		return nil
	end
	local function notified(W, p, frag, from)
		for i = #W.RT.fired, from or 1, -1 do
			local f = W.RT.fired[i]
			if f[1] == "Notify" and f[2] == p and type(f[3]) == "string" and f[3]:find(frag, 1, true) then
				return true
			end
		end
		return false
	end
	local function ready(W, p)
		local s = W.hooks.session(p)
		s.data.newbieOff, s.graceUntil = true, 0
		s.data.slots[1] = { k = "p", p = 1, s = 2, m = 1 }
		s.data.slots[2] = { k = "p", p = 2, s = 2, m = 1 }
		s.data.battle.team = { 1, 2 }
		s.data.battle.pvp.defense = { { p = 1, s = 2, m = 1 } }
		return s
	end
	local function count(t)
		local n = 0
		for _ in pairs(t or {}) do
			n = n + 1
		end
		return n
	end

	---------------------------------------------------------------- 1. Serveur normal : interface désactivée par défaut
	T.N = boot({})
	if not T.N then
		return
	end
	local N = T.N
	check("Démarrage du serveur normal sans erreur (PvpLive créé, désactivé)" .. errs(N), #N.RT.errors == 0)
	T.a = N.RT.addPlayer("LiveA", 14001, { from = "hub", partyId = "L14", size = 2, late = false })
	N.RT.step(3)
	T.sa = ready(N, T.a)
	check("Profil neuf : battle.live assaini (compteurs du jour à 0, adversaires récents vides)", type(T.sa.data.battle.live) == "table" and (T.sa.data.battle.live.fights or 0) == 0 and (T.sa.data.battle.live.gained or 0) == 0)
	T.f0 = #N.RT.fired + 1
	act(N, T.a, "liveQueue")
	N.RT.step(2)
	check("liveQueue avec la file désactivée : le classé ENREGISTRÉ démarre directement (aucune attente)" .. errs(N), battleMsg(N, T.a, "liveQueued", T.f0) == nil and battleMsg(N, T.a, "start", T.f0) ~= nil and battleMsg(N, T.a, "start", T.f0).pvp == true and battleMsg(N, T.a, "start", T.f0).live == nil)
	N.RT.step(35)
	check("Désactivé : aucune requête MemoryStore de file, de comptage ni de bail (cartes absentes du MemoryStore factice)", N.RT.memory[N.cfg.PVP_LIVE.queueName] == nil and N.RT.memory[N.cfg.PVP_LIVE.lockName] == nil and N.RT.memory[N.cfg.PVP_LIVE.ccuName] == nil and N.RT.memory[N.cfg.PVP_LIVE.ticketName] == nil)
	act(N, T.a, "battleQuit")
	act(N, T.a, "liveCancel")
	act(N, T.a, "battleAct", "attack")
	check("liveCancel / battleAct hors combat en direct : sans effet ni erreur" .. errs(N), #N.RT.errors == 0 and T.sa.battle == nil)

	---------------------------------------------------------------- 1 bis. Télémétrie : joueurs connectés simultanément (Telemetry.ccu)
	do
		local Tm = luau.load(fs.readFile("roblox/src/ServerScriptService/Telemetry.lua"), { debugName = "Telemetry" })()
		local sent, clock = {}, 0
		local svc = { LogCustomEvent = function(_, pl, name, value)
			sent[#sent + 1] = { pl = pl, name = name, value = value, t = clock }
		end }
		local Tl = Tm.new(svc, function()
			return clock
		end)
		local p1, p2, p3 = { id = 1 }, { id = 2 }, { id = 3 }
		for k = 1, 20 do
			Tl.log(p1, "hatch_tier", 1, "_r" .. (k % 10 + 1)) -- le porteur a déjà une file chargée : le débit par joueur doit tenir
		end
		local queued = 0
		for t = 0, 299 do
			clock = t
			for _ = 1, 3 do -- appels répétés dans la même seconde : plafond
				if Tl.ccu({ p1, p2, p3 }, t < 150 and "arena" or "ranked") then
					queued = queued + 1
				end
			end
			Tl.step()
		end
		local ccu, perSec, maxPerSec, names = {}, {}, 0, {}
		for _, e in ipairs(sent) do
			local key = tostring(e.pl.id) .. "@" .. e.t
			perSec[key] = (perSec[key] or 0) + 1
			if perSec[key] > maxPerSec then
				maxPerSec = perSec[key]
			end
			if e.name:sub(1, 11) == "ccu_sample_" then
				ccu[#ccu + 1] = e
				names[e.name] = true
			end
		end
		check("Télémétrie ccu : 1 échantillon / 60 s sur 300 s malgré 900 appels (5 mis en file, 5 envoyés), valeur = 3 joueurs, mode dans le nom",
			queued == 5 and #ccu == 5 and ccu[1].value == 3 and names.ccu_sample_arena and names.ccu_sample_ranked)
		check("Télémétrie ccu : jamais plus d'un événement par seconde et par joueur (file partagée du lot 16), porteur = un joueur présent", maxPerSec == 1 and ccu[1].pl == p1)
		local gapOk = true
		for i = 2, #ccu do
			if ccu[i].t - ccu[i - 1].t < 1 then
				gapOk = false
			end
		end
		check("Télémétrie ccu : échantillons espacés, file du porteur bornée (16)", gapOk and #(Tl.queues[p1] or {}) <= Tm.QUEUE_MAX)
		local before = 0
		for _ in pairs(Tl.queues) do
			before = before + 1
		end
		clock = 1000
		check("Télémétrie ccu : aucun joueur = aucun échantillon et aucune file créée ; mode inconnu ramené à « arena »", Tl.ccu({}, "arena") == false and Tl.ccu(nil, "arena") == false and (function()
			local n = 0
			for _ in pairs(Tl.queues) do
				n = n + 1
			end
			return n == before
		end)() and Tl.ccu({ p2 }, "bidon") == true and Tl.queues[p2][#Tl.queues[p2]].name == "ccu_sample_arena")
		Tl.flush(p1)
		Tl.flush(p2)
		Tl.flush(p3)
		check("Télémétrie ccu : après le départ des joueurs (ou l'arrêt), plus aucune file ni horodatage par joueur (seul ccuAt, un nombre, reste)", next(Tl.queues) == nil and next(Tl.last) == nil and type(Tl.ccuAt) == "number")
		check("Télémétrie ccu : hors des 16 métriques par joueur (liste séparée SERVER_METRICS)", Tm.METRICS.ccu_sample == nil and type(Tm.SERVER_METRICS.ccu_sample) == "string" and Tm.CCU_EVERY == 60)
		local tl = N.hooks.tele()
		local c0 = tl.ccuSent or 0
		N.RT.step(125)
		check("Vrai Main : échantillons de fréquentation à la cadence de 60 s (2 ou 3 en 125 s)" .. errs(N), (tl.ccuSent or 0) - c0 >= 2 and (tl.ccuSent or 0) - c0 <= 3)
	end

	---------------------------------------------------------------- 2. Serveur « ranked » : un seul joueur arrive
	T.now0 = 1700000000
	T.match = { id = "M-1", a = 14011, b = 14012, na = "ArenaA", nb = "ArenaB", ta = { { p = 1, s = 2, m = 1 }, { p = 2, s = 2, m = 1 } }, tb = { { p = 3, s = 2, m = 1 } }, seed = 12345, t = T.now0, exp = T.now0 + 300 }
	T.R = boot({ PvpMatch_v1 = { ["M-1"] = T.match } })
	local R = T.R
	check("Démarrage du serveur d'arène sans erreur" .. errs(R), #R.RT.errors == 0)
	T.A = R.RT.addPlayer("ArenaA", 14011, { mode = "ranked", match = "M-1", from = "ranked" })
	R.RT.step(3)
	T.sA = R.hooks.session(T.A)
	T.tr0 = T.sA and T.sA.data.battle.pvp.trophies
	check("Premier arrivé du match : serveur en mode « ranked », message liveArena, joueur occupé" .. errs(R), T.sA ~= nil and battleMsg(R, T.A, "liveArena") ~= nil and T.sA.pvpPending == true)
	T.X = R.RT.addPlayer("Intrus", 14099, { mode = "ranked", match = "M-1", from = "ranked" })
	R.RT.step(2)
	check("Intrus (pas dans le match) : « Ce combat classé n'existe plus », renvoyé chez lui", notified(R, T.X, "n'existe plus"))
	T.sX = R.hooks.session(T.X)
	if T.sX then
		ready(R, T.X)
		ready(R, T.A)
		T.sA.pvpPending = true
		act(R, T.X, "duelChallenge", 14011)
		check("Serveur « ranked » : aucun duel local possible", notified(R, T.X, "déjà en cours") and R.hooks.duel().book.pending[14099] == nil)
	end
	T.f1 = #R.RT.fired + 1
	R.RT.step(27)
	T.void = battleMsg(R, T.A, "liveVoid", T.f1)
	check("25 s sans l'adversaire : match ANNULÉ (liveVoid + message), trophées inchangés, aucun combat en direct consommé" .. errs(R), T.void ~= nil and notified(R, T.A, "pas arrivé", T.f1) and T.sA.data.battle.pvp.trophies == T.tr0 and (T.sA.data.battle.live.fights or 0) == 0 and T.sA.data.battle.live.w == 0 and T.sA.data.battle.live.l == 0)
	R.RT.step(10)
	check("Après l'annulation : retour lancé (téléportation vers sa partie / le hub, ou expulsion propre), aucune erreur" .. errs(R), #R.RT.errors == 0 and (#R.RT.teleports > 0 or #R.RT.warns > 0))

	---------------------------------------------------------------- 3. Serveur « ranked » : les deux arrivent, combat à deux, abandon
	T.match2 = { id = "M-2", a = 14021, b = 14022, na = "DuoA", nb = "DuoB", ta = { { p = 1, s = 2, m = 1 } }, tb = { { p = 3, s = 2, m = 1 }, { p = 2, s = 2, m = 1 } }, seed = 777, t = T.now0, exp = T.now0 + 300 }
	T.D = boot({ PvpMatch_v1 = { ["M-2"] = T.match2 } })
	local D = T.D
	T.P = D.RT.addPlayer("DuoA", 14021, { mode = "ranked", match = "M-2", from = "ranked" })
	T.Q = D.RT.addPlayer("DuoB", 14022, { mode = "ranked", match = "M-2", from = "ranked" })
	D.RT.step(3)
	T.sP, T.sQ = D.hooks.session(T.P), D.hooks.session(T.Q)
	T.sP.data.battle.pvp.trophies, T.sQ.data.battle.pvp.trophies = 200, 210
	D.RT.step(2)
	T.stP, T.stQ = battleMsg(D, T.P, "start"), battleMsg(D, T.Q, "start")
	check("Les deux joueurs du match sont là : start (live, pvp) pour les deux ; B voit SON équipe en camp 1" .. errs(D), T.stP ~= nil and T.stQ ~= nil and T.stP.live == true and T.stP.view.sides[1].units[1].p == 1 and T.stQ.view.sides[1].units[1].p == 3)
	check("Combat en direct consommé une fois par joueur, adversaire noté (pas de revanche 1 h)", T.sP.data.battle.live.fights == 1 and T.sQ.data.battle.live.fights == 1)
	T.f3 = #D.RT.fired + 1
	act(D, T.P, "battleAct", "attack")
	act(D, T.Q, "battleAct", "attack")
	check("battleAct routé vers le combat en direct : le tour se joue quand les deux ont choisi" .. errs(D), battleMsg(D, T.P, "turn", T.f3) ~= nil and battleMsg(D, T.Q, "turn", T.f3) ~= nil)
	T.f4 = #D.RT.fired + 1
	act(D, T.Q, "battleQuit")
	D.RT.step(1)
	T.eP, T.eQ = battleMsg(D, T.P, "end", T.f4), battleMsg(D, T.Q, "end", T.f4)
	check("Abandon de B = forfait : A gagne, B perd" .. errs(D), T.eP ~= nil and T.eQ ~= nil and T.eP.win == true and T.eQ.win == false and T.eP.live == true)
	check("Forfait avant 3 tours : 0 trophée pour le gagnant (anti-nourrissage), -15 pour le perdant", T.sP.data.battle.pvp.trophies == 200 and T.sQ.data.battle.pvp.trophies == 195 and T.eQ.rewards.trophies == -15 and T.eP.rewards.trophies == 0)
	check("Aucune erreur serveur sur les trois scénarios" .. errs(N) .. errs(R) .. errs(D), #N.RT.errors == 0 and #R.RT.errors == 0 and #D.RT.errors == 0)
	check("Fin du match : plus aucun joueur en file ni en combat en direct sur le serveur d'arène", T.sP.battle == nil and T.sQ.battle == nil and type(D.hooks.live) == "function" and count(D.hooks.live().queued) == 0 and D.hooks.live().arena ~= nil and D.hooks.live().arena.phase == "done")
end

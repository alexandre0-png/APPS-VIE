-- ModuleScript : ServerScriptService/PvpLive
-- LOT 14 : transport du classé en direct. Toutes les décisions sont dans ReplicatedStorage/Shared/Ranked (pur) ; ce module ne fait que
-- les appliquer avec un RUNTIME INJECTÉ (tests : faux runtime de tests/lot14.luau ; jeu : PvpLive.robloxRuntime, MemoryStore + TeleportService).
-- Aucun yield ici en dehors des appels au runtime ; chaque appel réseau est dans un pcall (une panne MemoryStore = un tour sans effet,
-- jamais une erreur qui remonte dans Main). Pas d'attente active : Main appelle L.step(now) toutes les secondes.
--
-- Runtime attendu (toutes les fonctions peuvent lever une erreur) :
--   now() -> secondes (os.time) ; job, psid (game.JobId, game.PrivateServerId) ; places = { game, hub } ; guid() ; seed() -> entier
--   queue    : set(key, value, ttl, sortKey) / update(key, fn, ttl) -> valeur écrite|nil / remove(key) / range(n) -> { valeur }
--   lock     : update(key, fn, ttl) -> valeur écrite|nil / get(key)            (HashMap PvpLock_v1 : bail "leader", comptage "ccu")
--   tickets  : set(key, value, ttl) / get(key) / remove(key)                (HashMap PvpTicket_v1, clé "u"..userId)
--   matches  : set(key, value, ttl) / get(key)                               (HashMap PvpMatch_v1, clé = id du match)
--   ccu      : set(key, value, ttl, sortKey) / range(n) -> { valeur }       (SortedMap PvpCcu_v1, clé = JobId)
--   registry : get(partyId)                                                  (HashMap ChipeParties du hub)
--   reserve(placeId) -> code, privateServerId ; teleport(players, placeId, code|nil, data) ; save(player, data) -> bool
--   send(player, msg) (Remote Battle) ; notify(player, text, sfx) ; kick(player, text) ; log(text) ; players() -> nombre de joueurs du serveur
local PvpLive = {}

local function key(uid)
	return "u" .. tostring(uid)
end

function PvpLive.new(Config, Ranked, Battle, rt)
	local cfg = Config.PVP_LIVE
	local L = { queued = {}, peersSeen = {}, ccuRec = nil, arena = nil, home = {}, stats = { matches = 0, claimsLost = 0, errors = 0 } }
	local nextCcu, nextLeader, nextPresence = 0, 0, 0

	local function try(fn, ...)
		local ok, a, b = pcall(fn, ...)
		if not ok then
			L.stats.errors = L.stats.errors + 1
			if rt.log then
				pcall(rt.log, "[PvpLive] " .. tostring(a))
			end
			return false
		end
		return true, a, b
	end
	local function send(s, msg)
		try(rt.send, s.player, msg)
	end
	local function notify(s, text, sfx)
		try(rt.notify, s.player, text, sfx)
	end

	local function liveOf(s)
		local b = s.data.battle
		if type(b.live) ~= "table" then
			b.live = Ranked.sanitizeLive(nil, cfg) -- profil sans le patch Data : valeurs neuves (jamais d'erreur)
		end
		return Ranked.liveDay(b.live, rt.now())
	end

	-- Équipe figée à l'entrée : pets de battle.team lus dans les emplacements du profil, assainis (p, s, m seulement).
	local function teamOf(s)
		local raw = {}
		for _, idx in ipairs(s.data.battle.team or {}) do
			local sl = type(idx) == "number" and s.data.slots[idx]
			if type(sl) == "table" and sl.k == "p" then
				raw[#raw + 1] = { p = sl.p, s = sl.s, m = sl.m }
			end
		end
		return Ranked.sanitizeTeam(Config, raw, Config.TOWER.teamSize)
	end

	---------------------------------------------------------------- ouverture
	function L.open(now)
		return Ranked.liveOpen(cfg, L.ccuRec, now or rt.now())
	end

	-- Joueurs ayant partagé ce serveur dans la fenêtre cfg.peerWindow (anti-arrangement).
	function L.notePresence(sessions, now)
		local uids = {}
		for _, s in pairs(sessions) do
			uids[#uids + 1] = s.player.UserId
		end
		for _, u in ipairs(uids) do
			local seen = L.peersSeen[u] or {}
			L.peersSeen[u] = seen
			for _, o in ipairs(uids) do
				if o ~= u then
					seen[o] = now
				end
			end
			for o, t in pairs(seen) do
				if now - t > cfg.peerWindow then
					seen[o] = nil
				end
			end
		end
		for u, seen in pairs(L.peersSeen) do -- joueurs partis : la table disparaît quand plus personne n'y est récent
			if next(seen) == nil then
				L.peersSeen[u] = nil
			end
		end
	end
	local function peersOf(uid)
		local out = {}
		for o in pairs(L.peersSeen[uid] or {}) do
			out[#out + 1] = o
		end
		table.sort(out)
		return out
	end

	---------------------------------------------------------------- file d'attente (serveur du joueur)
	-- ctx = { busy, serverMode, party } calculés par Main. Retourne (true) ou (false, raison) ; "closed" = Main bascule sur l'asynchrone.
	function L.enqueue(s, ctx)
		local now = rt.now()
		local uid = s.player.UserId
		if L.queued[uid] then
			return false, "already"
		end
		if now - (s.liveOpAt or -100) < 2 then
			return false, "rate"
		end
		s.liveOpAt = now
		local open = L.open(now)
		local live = liveOf(s)
		local team = teamOf(s)
		local ok, why = Ranked.canQueue(cfg, { open = open, busy = ctx.busy, serverMode = ctx.serverMode, team = team, live = live })
		if not ok then
			return false, why
		end
		local entry = Ranked.makeEntry(cfg, {
			uid = uid,
			trophies = s.data.battle.pvp.trophies,
			power = Ranked.teamPower(Battle, Config, team),
			job = rt.job,
			party = ctx.party,
			since = now,
			now = now,
			team = team,
			peers = peersOf(uid),
			opp = Ranked.recentOpponents(cfg, live, now),
			name = s.player.DisplayName,
		})
		if not try(rt.queue.set, key(uid), entry, cfg.queueTtl, entry.tr) then
			return false, "store"
		end
		L.queued[uid] = { s = s, entry = entry, fbSince = now, nextRefresh = now + cfg.refresh, nextPoll = now + cfg.pollTicket, state = "queued", attempts = 0 }
		s.pvpPending = true -- bloque tour, PvP asynchrone, château et rencontres PNJ pendant l'attente (champ existant de Main)
		send(s, { k = "liveQueued", seconds = cfg.fallbackAfter })
		return true
	end

	local function drop(uid, removeEntry)
		local q = L.queued[uid]
		if not q then
			return
		end
		L.queued[uid] = nil
		if removeEntry then
			try(rt.queue.remove, key(uid))
		end
		if q.s.pvpPending then
			q.s.pvpPending = nil
		end
	end

	-- Annulation par le joueur : impossible une fois la téléportation lancée. Retourne bool.
	function L.cancel(s)
		local q = L.queued[s.player.UserId]
		if not q or q.state ~= "queued" then
			return false
		end
		drop(s.player.UserId, true)
		send(s, { k = "liveCancel" })
		return true
	end

	local function requeue(q, now, why)
		q.state, q.ticket, q.attempts = "queued", nil, 0
		q.entry.r = now
		q.fbSince = now -- nouveau délai de repli ; `since` (entry.t) inchangé : le joueur garde sa priorité (« en tête de file »)
		q.nextRefresh, q.nextPoll = now + cfg.refresh, now + cfg.pollTicket
		try(rt.queue.set, key(q.s.player.UserId), q.entry, cfg.queueTtl, q.entry.tr)
		notify(q.s, why or "⚔️ Adversaire indisponible : tu restes en file.", "refuse")
		send(q.s, { k = "liveQueued", seconds = cfg.fallbackAfter, again = true })
	end

	local function teleportFail(q, now)
		q.attempts = q.attempts + 1
		local plan = Ranked.teleportPlan(cfg, q.attempts)
		if plan.retry then
			q.state, q.nextTry = "teleporting", now + plan.retry
		else
			requeue(q, now, "⚔️ Téléportation vers l'arène impossible : tu restes en file.")
		end
	end

	function L.teleportFailed(player) -- TeleportService.TeleportInitFailed
		local q = L.queued[player.UserId]
		if q and q.state == "sent" then
			teleportFail(q, rt.now())
		end
	end

	local function queueStep(q, now)
		local s, uid = q.s, q.s.player.UserId
		if q.state == "queued" then
			if now >= q.nextPoll then
				q.nextPoll = now + cfg.pollTicket
				local ok, t = try(rt.tickets.get, key(uid))
				if ok and Ranked.ticketValid(t, now) then
					try(rt.tickets.remove, key(uid)) -- consommé une fois
					try(rt.queue.remove, key(uid)) -- plus proposé à l'apparieur (sinon ignoré après 30 s sans rafraîchissement)
					q.state, q.ticket, q.attempts, q.nextTry = "teleporting", t, 0, now
					send(s, { k = "liveFound", opp = tostring(t.opp or "?") })
				end
			end
			if q.state == "queued" and Ranked.shouldFallback(cfg, q.fbSince, now) then
				drop(uid, true)
				send(s, { k = "liveFallback" }) -- « Aucun adversaire en ligne de ton niveau. Combattre une équipe enregistrée ? » -> pvpStart
				return
			end
			if q.state == "queued" and now >= q.nextRefresh then
				q.nextRefresh = now + cfg.refresh
				try(rt.queue.update, key(uid), function(old)
					return Ranked.refreshTransform(old, q.entry, now)
				end, cfg.queueTtl)
			end
		end
		if q.state == "teleporting" and now >= q.nextTry then
			local okS, saved = try(rt.save, s.player, s.data) -- la sauvegarde est TERMINÉE avant la téléportation (risque L.4)
			if not (okS and saved) then
				return teleportFail(q, now)
			end
			local t = q.ticket
			if try(rt.teleport, { s.player }, rt.places.game, t.code, { mode = "ranked", match = t.match, from = "ranked" }) then
				q.state, q.sentAt = "sent", now
			else
				teleportFail(q, now)
			end
		elseif q.state == "sent" and now - q.sentAt > cfg.ticketTtl then
			teleportFail(q, now) -- toujours là longtemps après TeleportAsync : échec silencieux
		end
	end

	---------------------------------------------------------------- apparieur (un seul serveur à la fois)
	local function leaderWork(now)
		local okR, list = try(rt.queue.range, cfg.scan)
		if not okR or type(list) ~= "table" then
			return
		end
		for _, p in ipairs(Ranked.pairUp(cfg, list, now)) do
			local id = rt.guid()
			local function claim(e)
				local ok, v = try(rt.queue.update, key(e.u), function(old)
					return Ranked.claimTransform(old, id)
				end, cfg.queueTtl)
				return ok and type(v) == "table" and v.m == id
			end
			local function release(e)
				try(rt.queue.update, key(e.u), function(old)
					return Ranked.releaseTransform(old, id)
				end, cfg.queueTtl)
			end
			if not claim(p.a) then
				L.stats.claimsLost = L.stats.claimsLost + 1
			elseif not claim(p.b) then
				L.stats.claimsLost = L.stats.claimsLost + 1
				release(p.a)
			else
				local okRes, code, psid = try(rt.reserve, rt.places.game)
				local match = okRes and type(code) == "string" and Ranked.newMatch(cfg, id, p.a, p.b, code, tostring(psid or ""), rt.seed(), now) or nil
				local done = match ~= nil and try(rt.matches.set, id, match, cfg.matchTtl)
				done = done and try(rt.tickets.set, key(p.a.u), Ranked.newTicket(cfg, match, "a", now), cfg.ticketTtl)
				done = done and try(rt.tickets.set, key(p.b.u), Ranked.newTicket(cfg, match, "b", now), cfg.ticketTtl)
				if done then
					try(rt.queue.remove, key(p.a.u))
					try(rt.queue.remove, key(p.b.u))
					L.stats.matches = L.stats.matches + 1
				else
					try(rt.tickets.remove, key(p.a.u))
					try(rt.tickets.remove, key(p.b.u))
					release(p.a)
					release(p.b)
				end
			end
		end
	end

	local function networkStep(sessions, now)
		if now >= nextCcu then
			nextCcu = now + cfg.ccuPublish
			local n = 0
			for _ in pairs(sessions) do
				n = n + 1
			end
			try(rt.ccu.set, rt.job, { n = n, t = now }, cfg.ccuTtl, n)
			local ok, rec = try(rt.lock.get, "ccu")
			if ok then
				L.ccuRec = rec
			end
		end
		if now >= nextLeader then
			nextLeader = now + cfg.leaderEvery
			local ok, v = try(rt.lock.update, "leader", function(old)
				return Ranked.leaderTransform(old, rt.job, now, cfg.leaderTtl)
			end, cfg.leaderTtl)
			if ok and Ranked.isLeader(v, rt.job, now) then
				L.isLeader = true
				if now >= (L.nextCcuSum or 0) then
					L.nextCcuSum = now + cfg.ccuPublish
					local okC, list = try(rt.ccu.range, 200)
					if okC then
						local total = Ranked.ccuSum(list, now, cfg.ccuTtl)
						local rec = { n = total, t = now }
						if try(rt.lock.update, "ccu", function()
							return rec
						end, cfg.ccuTtl) then
							L.ccuRec = rec
						end
					end
				end
				leaderWork(now)
			else
				L.isLeader = false
			end
		end
	end

	---------------------------------------------------------------- serveur d'arène
	local function sideIdx(side)
		return side == "a" and 1 or 2
	end
	local function other(side)
		return side == "a" and "b" or "a"
	end
	local function sendSide(A, side, msg, mirrorable)
		local s = A.sess[side]
		if not s then
			return
		end
		if side == "b" and mirrorable then
			msg = table.clone(msg)
			if msg.view then
				msg.view = Ranked.mirrorView(msg.view)
			end
			if msg.events then
				msg.events = Ranked.mirrorEvents(msg.events)
			end
		end
		send(s, msg)
	end

	local function goHome(s, now)
		L.home[s] = { at = now + 6, tries = 0 }
	end

	-- Joueur arrivé avec TeleportData.mode == "ranked". Retourne true si c'est bien un joueur du match (sinon il est renvoyé chez lui).
	function L.arenaJoin(s, joinData)
		local now = rt.now()
		local uid = s.player.UserId
		local matchId = type(joinData) == "table" and type(joinData.match) == "string" and #joinData.match <= 64 and joinData.match or nil
		local A = L.arena
		if not A and matchId then
			local ok, rec = try(rt.matches.get, matchId)
			if ok and Ranked.arenaAdmit(rec, uid, rt.psid, now) then
				A = Ranked.arenaNew(rec, now)
				A.sess = {}
				L.arena = A
			end
		end
		local side = A and matchId == A.match.id and Ranked.arenaAdmit(A.match, uid, rt.psid, now) or nil
		if not side or not Ranked.arenaArrive(A, side) then
			notify(s, "⚔️ Ce combat classé n'existe plus.", "refuse")
			goHome(s, now - 5)
			return false
		end
		A.sess[side] = s
		s.liveSide = side
		s.pvpPending = true
		send(s, { k = "liveArena", seconds = cfg.waitArena })
		return true
	end

	local function finish(A, winner, forfeit)
		A.phase = "done"
		local now = rt.now()
		local ctx = { winner = winner, forfeit = forfeit, turns = A.turns }
		for _, side in ipairs({ "a", "b" }) do
			local s = A.sess[side]
			ctx[side] = { trophies = s.data.battle.pvp.trophies, live = liveOf(s) }
		end
		local out = Ranked.outcome(cfg, Config.pvpGain, Config.PVP.loss, ctx)
		for _, side in ipairs({ "a", "b" }) do
			local s = A.sess[side]
			local win = side == winner
			Ranked.apply(s.data.battle.pvp, s.data.battle.live, out[side], win)
			local rewards = { trophies = out[side], total = s.data.battle.pvp.trophies, capped = out.capped[side] or nil, forfeit = forfeit or nil, fed = (win and out.fed) or nil }
			sendSide(A, side, { k = "end", win = win, rewards = rewards, floor = 0, pvp = true, live = true, foe = side == "a" and A.match.nb or A.match.na, view = Battle.view(A.st) }, true)
			if rt.sync then
				try(rt.sync, s) -- état (trophées) renvoyé au client
			end
			goHome(s, now)
		end
		A.result = out
	end

	local function resolve(A)
		local acts = A.acts
		local events = Battle.turn(A.st, acts.a or { kind = "attack" }, acts.b or { kind = "attack" })
		A.turns = A.turns + 1
		A.acts = {}
		A.deadline = rt.now() + cfg.turnSeconds
		for _, side in ipairs({ "a", "b" }) do
			sendSide(A, side, { k = "turn", events = events, view = Battle.view(A.st), seconds = (not A.st.over) and cfg.turnSeconds or nil }, true)
		end
		if A.st.over then
			finish(A, A.st.winner == 1 and "a" or "b", false)
		end
	end

	local function void(A, now, text)
		A.phase = "void"
		for _, side in ipairs({ "a", "b" }) do
			local s = A.sess[side]
			if s then
				notify(s, text, "refuse")
				send(s, { k = "liveVoid" })
				goHome(s, now)
			end
		end
	end

	local function arenaStep(now)
		local A = L.arena
		if not A then
			return
		end
		local d = Ranked.arenaTick(cfg, A, now)
		if d == "start" then
			local sa, sb = A.sess.a, A.sess.b
			local ta, tb = Ranked.sanitizeTeam(Config, A.match.ta), Ranked.sanitizeTeam(Config, A.match.tb)
			if not (sa and sb) then
				return void(A, now, "⚔️ Ton adversaire n'est pas arrivé : aucun trophée gagné ni perdu.")
			end
			if not (Ranked.canFight(cfg, liveOf(sa)) and Ranked.canFight(cfg, liveOf(sb))) or #ta == 0 or #tb == 0 then
				return void(A, now, "⚔️ Combat annulé (limite du jour ou équipe invalide) : aucun trophée gagné ni perdu.")
			end
			local ua, ub = {}, {}
			for _, e in ipairs(ta) do
				ua[#ua + 1] = Battle.unit(Config, e) -- stats brutes : aucun boost ni produit
			end
			for _, e in ipairs(tb) do
				ub[#ub + 1] = Battle.unit(Config, e)
			end
			A.st = Battle.new(A.match.seed or 1, ua, ub)
			A.phase, A.acts, A.deadline = "fight", {}, now + cfg.turnSeconds
			for _, side in ipairs({ "a", "b" }) do
				local s = A.sess[side]
				local live = liveOf(s)
				live.fights = live.fights + 1 -- consommé seulement quand les deux sont là
				Ranked.recordOpponent(cfg, live, side == "a" and A.match.b or A.match.a, now)
				sendSide(
					A,
					side,
					{ k = "start", floor = 0, live = true, pvp = true, foe = "🏆 " .. tostring(side == "a" and A.match.nb or A.match.na), view = Battle.view(A.st), seconds = cfg.turnSeconds },
					true
				)
			end
		elseif d == "void" then
			void(A, now, "⚔️ Ton adversaire n'est pas arrivé : aucun trophée gagné ni perdu.")
		elseif d == "fight" and now >= A.deadline then
			resolve(A) -- 10 s sans action : attaque par défaut
		end
	end

	-- Action de combat (Main : actions.battleAct). Retourne true si le joueur est dans un combat en direct (l'action est consommée ici).
	function L.act(s, arg)
		local A = L.arena
		local side = s.liveSide
		if not (A and side and A.sess[side] == s) then
			return false
		end
		if A.phase ~= "fight" or A.acts[side] then
			return true
		end
		local act = Ranked.parseAction(arg)
		if not act or Battle.validate(A.st, sideIdx(side), act) then
			notify(s, "⚔️ Action impossible.", "refuse")
			return true
		end
		A.acts[side] = act
		if A.acts[other(side)] then
			resolve(A)
		end
		return true
	end

	-- Abandon volontaire (Main : actions.battleQuit) = forfait.
	function L.quit(s)
		local A = L.arena
		local side = s.liveSide
		if not (A and side and A.sess[side] == s) then
			return false
		end
		if A.phase == "fight" then
			finish(A, other(side), true)
		end
		return true
	end

	-- Départ du serveur (Main : PlayerRemoving, AVANT Data.save) : retrait de la file, forfait si combat en cours (la défaite est écrite dans le
	-- profil qui est sauvegardé juste après).
	function L.onLeave(s)
		local uid = s.player.UserId
		if L.queued[uid] then
			local q = L.queued[uid]
			drop(uid, q.state == "queued")
		end
		local A = L.arena
		local side = s.liveSide
		if A and side and A.sess[side] == s then
			local r = Ranked.arenaLeave(A, side)
			if r == "forfeit" then
				finish(A, other(side), true)
			end
			A.sess[side] = nil
			if r == "absent" then
				s.liveSide = nil
			end
		end
		L.home[s] = nil -- après finish (qui le programme) : il est déjà parti
	end

	local function homeStep(now)
		for s, h in pairs(L.home) do
			if now >= h.at then
				h.tries = h.tries + 1
				local player, uid = s.player, s.player.UserId
				local partyId = nil
				local A = L.arena
				if A and s.liveSide then
					partyId = s.liveSide == "a" and A.match.pa or A.match.pb
				end
				local okS, saved = try(rt.save, player, s.data)
				if not (okS and saved) and h.tries < 3 then
					h.at = now + 5 -- DataStore lent : on réessaie avant de partir (PlayerRemoving sauvegarde de toute façon)
				else
					local entry = nil
					if partyId then
						local okG, e = try(rt.registry.get, partyId)
						entry = okG and e or nil
					end
					local plan = Ranked.returnPlan(Config.Game, partyId, entry, uid)
					local sent = false
					if plan.place == "party" then
						sent = try(rt.teleport, { player }, rt.places.game, plan.code, { from = "hub", partyId = plan.partyId, late = true, mode = "arena", via = "ranked" })
					end
					if not sent then
						sent = try(rt.teleport, { player }, rt.places.hub, nil, { from = "game", partyId = plan.partyId, reason = "ranked" })
					end
					if sent then
						L.home[s] = nil
					elseif h.tries >= 4 then
						L.home[s] = nil
						try(rt.kick, player, "Retour impossible depuis l'arène : ta progression est sauvegardée, reconnecte-toi.")
					else
						h.at = now + 5
					end
				end
			end
		end
	end

	---------------------------------------------------------------- pas principal (Main : une fois par seconde)
	function L.step(sessions, now)
		now = now or rt.now()
		if now >= nextPresence then
			nextPresence = now + 5
			L.notePresence(sessions, now)
		end
		if cfg.enabled then
			networkStep(sessions, now)
		end
		for uid, q in pairs(L.queued) do
			if sessions[q.s.player] ~= q.s then
				L.queued[uid] = nil
			else
				queueStep(q, now)
			end
		end
		arenaStep(now)
		homeStep(now)
	end

	return L
end

---------------------------------------------------------------- runtime réel (non testé hors Roblox : voir README « À tester dans Studio »)
-- hooks = { save(player, data) -> bool, send(player, msg), notify(player, text, sfx), sync(s), log(text) }
function PvpLive.robloxRuntime(Config, hooks)
	local cfg = Config.PVP_LIVE
	local MSS = game:GetService("MemoryStoreService")
	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local rng = Random.new()
	local maps = {}
	local function hash(name)
		maps[name] = maps[name] or MSS:GetHashMap(name)
		return maps[name]
	end
	local function sorted(name)
		maps[name] = maps[name] or MSS:GetSortedMap(name)
		return maps[name]
	end
	local function hashApi(name)
		return {
			set = function(k, v, ttl)
				return hash(name):SetAsync(k, v, ttl)
			end,
			get = function(k)
				return hash(name):GetAsync(k)
			end,
			remove = function(k)
				return hash(name):RemoveAsync(k)
			end,
			update = function(k, fn, ttl)
				return hash(name):UpdateAsync(k, fn, ttl)
			end,
		}
	end
	local function sortedApi(name)
		return {
			set = function(k, v, ttl, sortKey)
				return sorted(name):SetAsync(k, v, ttl, sortKey)
			end,
			update = function(k, fn, ttl)
				return sorted(name):UpdateAsync(k, function(old)
					local new = fn(old)
					if new == nil then
						return nil
					end
					return new, type(new.tr) == "number" and new.tr or nil
				end, ttl)
			end,
			remove = function(k)
				return sorted(name):RemoveAsync(k)
			end,
			range = function(n)
				local items = sorted(name):GetRangeAsync(Enum.SortDirection.Ascending, n)
				local out = {}
				for _, it in ipairs(items) do
					out[#out + 1] = it.value
				end
				return out
			end,
		}
	end
	return {
		now = os.time,
		job = game.JobId,
		psid = game.PrivateServerId,
		places = Config.Game.Places,
		guid = function()
			return HttpService:GenerateGUID(false)
		end,
		seed = function()
			return rng:NextInteger(1, 2147483000)
		end,
		queue = sortedApi(cfg.queueName),
		ccu = sortedApi(cfg.ccuName),
		lock = hashApi(cfg.lockName),
		tickets = hashApi(cfg.ticketName),
		matches = hashApi(cfg.matchName),
		registry = hashApi(Config.Game.RegistryName),
		reserve = function(placeId)
			return TeleportService:ReserveServerAsync(placeId)
		end,
		teleport = function(players, placeId, code, data)
			local opts = Instance.new("TeleportOptions")
			if code then
				opts.ReservedServerAccessCode = code
			end
			opts:SetTeleportData(data)
			TeleportService:TeleportAsync(placeId, players, opts)
		end,
		save = hooks.save,
		send = hooks.send,
		notify = hooks.notify,
		sync = hooks.sync,
		log = hooks.log or warn,
		kick = function(player, text)
			player:Kick(text)
		end,
		players = function()
			return #Players:GetPlayers()
		end,
	}
end

return PvpLive

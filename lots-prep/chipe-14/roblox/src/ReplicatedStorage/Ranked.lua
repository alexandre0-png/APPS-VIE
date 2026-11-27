-- ModuleScript : ReplicatedStorage/Shared/Ranked
-- LOT 14 : classé EN DIRECT (file MemoryStore, serveur réservé « ranked »). Logique PURE : aucune API Roblox, aucun yield, aucune erreur levée
-- sur une entrée invalide (valeurs de retour). Testé par tests/lot14.luau (Lune ou lupa). Le transport (MemoryStore, TeleportService) est dans
-- ServerScriptService/PvpLive.lua, qui n'appelle ces règles qu'à travers des fonctions de transformation (UpdateAsync) et des décisions.
--
-- Décisions (cahier LOTS_9_PLUS E.3 / E.4 / K « Lot 14 », décision utilisateur) :
--   * la file en direct est FERMÉE tant que les joueurs simultanés de l'expérience sont < cfg.minCCU (60) ou que cfg.enabled = false ;
--     elle est aussi fermée si le comptage est inconnu ou périmé (échec = fermé) : le classé reste alors sur le mode asynchrone existant ;
--   * aucun trophée ne bouge si les deux joueurs ne sont pas présents dans le serveur d'arène au départ (match annulé, quota rendu) ;
--   * déconnexion ou abandon pendant le combat = FORFAIT : le partant perd ; le restant gagne, sauf forfait avant cfg.minTurnsForGain tours
--     (anti-« nourrissage » entre deux comptes : 0 trophée pour le gagnant, le partant perd quand même) ;
--   * jamais le même adversaire deux fois en cfg.rematchCooldown secondes, jamais deux comptes ayant partagé un serveur dans les cfg.peerWindow
--     dernières secondes, jamais deux entrées du même serveur ;
--   * gains plafonnés à cfg.dailyTrophyCap trophées par jour UTC (pertes non plafonnées, bornées par le solde), cfg.dailyFights combats par jour ;
--   * rien d'achetable n'entre ici : ni Robux, ni pass, ni boost (la puissance d'équipe vient des stats brutes de Battle.unit).
local Ranked = {}

local function num(v, default)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return v
end

local function int(v, default, lo, hi)
	local n = math.floor(num(v, default))
	if lo and n < lo then
		n = lo
	end
	if hi and n > hi then
		n = hi
	end
	return n
end

local function isUid(v)
	return type(v) == "number" and v == v and v % 1 == 0 and v > 0 and v < 2 ^ 53
end
Ranked.isUid = isUid

local function contains(list, v)
	if type(list) ~= "table" then
		return false
	end
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- jour, ligues
function Ranked.day(now)
	return math.floor(num(now, 0) / 86400)
end

-- Ligue d'un nombre de trophées (Config.LEAGUES trié par `min` croissant) : retourne (ligue, indice). Valeur invalide = première ligue.
function Ranked.league(leagues, trophies)
	local t = num(trophies, 0)
	local best, idx = leagues[1], 1
	for i, l in ipairs(leagues) do
		if t >= l.min then
			best, idx = l, i
		end
	end
	return best, idx
end

-- Remise partielle de saison (E.4, OPTIONNELLE : non branchée par les patchs, le jeu garde `trophées // 4`) : au-delà de `floorAt`,
-- trophées = floor(trophées × keep), sans jamais redescendre sous `floorAt`.
function Ranked.seasonReset(trophies, keep, floorAt)
	local t = math.max(0, math.floor(num(trophies, 0)))
	floorAt = floorAt or 300
	if t <= floorAt then
		return t
	end
	return math.max(floorAt, math.floor(t * (keep or 0.6)))
end

---------------------------------------------------------------- ouverture de la file (seuil de joueurs simultanés)
-- Somme des comptes publiés par les serveurs (SortedMap PvpCcu_v1 : { n, t }) encore frais. Entrées invalides ignorées.
function Ranked.ccuSum(entries, now, ttl)
	local total, servers = 0, 0
	if type(entries) ~= "table" then
		return 0, 0
	end
	for _, e in ipairs(entries) do
		local v = type(e) == "table" and (e.value or e) or nil
		if type(v) == "table" and type(v.n) == "number" and type(v.t) == "number" and now - v.t <= ttl and v.n >= 0 and v.n <= 200 then
			total = total + math.floor(v.n)
			servers = servers + 1
		end
	end
	return total, servers
end

-- La file en direct est-elle ouverte ? rec = { n = joueurs simultanés, t = date du comptage } écrit par l'apparieur. Retourne (bool, raison).
function Ranked.liveOpen(cfg, rec, now)
	if not cfg or cfg.enabled ~= true then
		return false, "disabled"
	end
	if type(rec) ~= "table" or type(rec.n) ~= "number" or type(rec.t) ~= "number" or now - rec.t > cfg.ccuTtl or rec.t > now + 5 then
		return false, "unknown" -- comptage absent ou périmé : fermé (jamais de file vide qui frustre)
	end
	if rec.n < cfg.minCCU then
		return false, "low_ccu"
	end
	return true, "open"
end

---------------------------------------------------------------- profil : champ battle.live
-- battle.live = { day, fights, gained, w, l, recent = { { u = userId, t = date } } } : compteurs du jour UTC et derniers adversaires.
function Ranked.sanitizeLive(v, cfg)
	local maxRecent = (cfg and cfg.recentMax) or 20
	local out = { day = 0, fights = 0, gained = 0, w = 0, l = 0, recent = {} }
	if type(v) ~= "table" then
		return out
	end
	out.day = int(v.day, 0, 0, 1e7)
	out.fights = int(v.fights, 0, 0, 1000)
	out.gained = int(v.gained, 0, 0, 1e6)
	out.w = int(v.w, 0, 0, 1e7)
	out.l = int(v.l, 0, 0, 1e7)
	if type(v.recent) == "table" then
		for _, r in ipairs(v.recent) do
			if #out.recent >= maxRecent then
				break
			end
			if type(r) == "table" and isUid(r.u) and type(r.t) == "number" and r.t == r.t then
				out.recent[#out.recent + 1] = { u = r.u, t = math.floor(r.t) }
			end
		end
	end
	return out
end

-- Remet les compteurs du jour à zéro si le jour UTC a changé. Retourne live (modifié en place).
function Ranked.liveDay(live, now)
	local d = Ranked.day(now)
	if live.day ~= d then
		live.day, live.fights, live.gained = d, 0, 0
	end
	return live
end

-- Adversaires récents encore bloqués (liste d'userId) ; nettoie la liste au passage.
function Ranked.recentOpponents(cfg, live, now)
	local keep, out = {}, {}
	for _, r in ipairs(live.recent or {}) do
		if now - r.t < cfg.rematchCooldown then
			keep[#keep + 1] = r
			out[#out + 1] = r.u
		end
	end
	live.recent = keep
	return out
end

function Ranked.recordOpponent(cfg, live, uid, now)
	if not isUid(uid) then
		return
	end
	Ranked.recentOpponents(cfg, live, now)
	local keep = {}
	for _, r in ipairs(live.recent) do
		if r.u ~= uid then
			keep[#keep + 1] = r
		end
	end
	keep[#keep + 1] = { u = uid, t = math.floor(now) }
	while #keep > cfg.recentMax do
		table.remove(keep, 1)
	end
	live.recent = keep
end

---------------------------------------------------------------- équipe figée et puissance
-- Équipe { {p,s,m} } assainie contre Config.PETS (espèce connue, 3 pets au plus). Seuls p, s, m sont gardés : aucun bonus ne passe.
function Ranked.sanitizeTeam(Config, team, size)
	local out = {}
	size = size or 3
	if type(team) ~= "table" then
		return out
	end
	for _, e in ipairs(team) do
		if #out >= size then
			break
		end
		if type(e) == "table" and type(e.p) == "number" and e.p % 1 == 0 and Config.PETS[e.p] then
			local s = (type(e.s) == "string" and #e.s <= 16) and e.s or nil
			local m = (type(e.m) == "string" and #e.m <= 16) and e.m or nil
			out[#out + 1] = { p = e.p, s = s, m = m }
		end
	end
	return out
end

-- Puissance d'équipe : somme de Battle.power des unités BRUTES (Battle.unit sans échelle ni boost hebdomadaire).
function Ranked.teamPower(Battle, Config, team)
	local total = 0
	for _, e in ipairs(team) do
		local u = Battle.unit(Config, e)
		total = total + Battle.power({ hp = u.maxHp, atk = u.atk, spd = u.spd })
	end
	return total
end

---------------------------------------------------------------- entrée en file
-- Le joueur peut-il entrer en file en direct ? ctx (calculé par le SERVEUR) :
--   { open, busy, serverMode, team (assainie), live (assaini, jour courant), trophies, hasDefense }
-- Retourne (true) ou (false, raison) ; raison = "closed" | "busy" | "mode" | "team" | "fights" | "cap".
function Ranked.canQueue(cfg, ctx)
	if not ctx.open then
		return false, "closed"
	end
	if ctx.busy then
		return false, "busy"
	end
	if ctx.serverMode == "ranked" or ctx.serverMode == "castle" then
		return false, "mode"
	end
	if type(ctx.team) ~= "table" or #ctx.team == 0 then
		return false, "team"
	end
	if ctx.live.fights >= cfg.dailyFights then
		return false, "fights"
	end
	if ctx.live.gained >= cfg.dailyTrophyCap then
		return false, "cap"
	end
	return true
end

-- Entrée écrite dans la SortedMap (clé "u"..uid, clé de tri = trophées). `since` = première entrée (gardée lors d'une remise en file).
function Ranked.makeEntry(cfg, a)
	local function ids(list, max)
		local out = {}
		for _, v in ipairs(type(list) == "table" and list or {}) do
			if isUid(v) and #out < max then
				out[#out + 1] = v
			end
		end
		return out
	end
	return {
		u = a.uid,
		tr = int(a.trophies, 0, 0, 100000),
		pow = math.max(1, num(a.power, 1)),
		job = tostring(a.job or ""),
		party = type(a.party) == "string" and a.party or nil,
		t = a.since,
		r = a.now,
		team = a.team,
		peers = ids(a.peers, cfg.peersMax),
		opp = ids(a.opp, cfg.recentMax),
		name = tostring(a.name or "?"):sub(1, 24),
	}
end

-- Entrée lue depuis la file : forme minimale vérifiée (le contenu est écrit par nos serveurs, mais la file est partagée : on reste prudent).
-- Une entrée non rafraîchie depuis 3 rafraîchissements (30 s) est ignorée même si le MemoryStore ne l'a pas encore effacée (90 s) :
-- un joueur parti, déjà en téléportation ou dont le serveur est tombé n'est plus proposé.
function Ranked.validEntry(cfg, e, now)
	return type(e) == "table"
		and isUid(e.u)
		and type(e.tr) == "number"
		and type(e.pow) == "number"
		and e.pow > 0
		and type(e.t) == "number"
		and type(e.r) == "number"
		and now - e.r <= math.min(cfg.queueTtl, 3 * cfg.refresh)
		and type(e.job) == "string"
		and type(e.team) == "table"
		and #e.team > 0
end

---------------------------------------------------------------- appariement
-- Fenêtre de trophées après `waited` secondes : base + step × floor(waited / every), plafonnée à max.
function Ranked.trophyWindow(cfg, waited)
	local w = cfg.trophyWindow
	return math.min(w.max, w.base + w.step * math.floor(math.max(0, waited) / w.every))
end

-- Bornes du rapport de puissance (élargies après power.wideAfter secondes).
function Ranked.powerBounds(cfg, waited)
	local p = cfg.power
	if waited >= p.wideAfter then
		return p.wideLo, p.wideHi
	end
	return p.lo, p.hi
end

-- Deux entrées peuvent-elles s'affronter ? Les DEUX doivent accepter : on prend la plus courte attente (la fenêtre la plus étroite).
-- Retourne (bool, raison).
function Ranked.compatible(cfg, a, b, now)
	if a.u == b.u then
		return false, "self"
	end
	if a.m or b.m then
		return false, "taken"
	end
	if a.job ~= "" and a.job == b.job then
		return false, "same_server"
	end
	if contains(a.peers, b.u) or contains(b.peers, a.u) then
		return false, "peers"
	end
	if contains(a.opp, b.u) or contains(b.opp, a.u) then
		return false, "rematch"
	end
	local waited = math.min(now - a.t, now - b.t)
	if math.abs(a.tr - b.tr) > Ranked.trophyWindow(cfg, waited) then
		return false, "trophies"
	end
	local lo, hi = Ranked.powerBounds(cfg, waited)
	local ratio = a.pow / b.pow
	if ratio < lo or ratio > hi then
		return false, "power"
	end
	return true
end

-- Paires { {a, b} } depuis une liste d'entrées : le plus ancien en file d'abord ; pour lui, l'adversaire compatible le plus proche en trophées
-- (égalité : le plus ancien, puis le plus petit userId). Chaque joueur apparaît au plus UNE fois. Entrées invalides ou périmées ignorées.
function Ranked.pairUp(cfg, entries, now)
	local list, seen = {}, {}
	for _, e in ipairs(entries) do
		if Ranked.validEntry(cfg, e, now) and not e.m and not seen[e.u] then
			seen[e.u] = true
			list[#list + 1] = e
		end
	end
	table.sort(list, function(x, y)
		if x.t ~= y.t then
			return x.t < y.t
		end
		return x.u < y.u
	end)
	local used, pairs_ = {}, {}
	for i, a in ipairs(list) do
		if not used[a.u] then
			local best, bestD
			for j = i + 1, #list do
				local b = list[j]
				if not used[b.u] and Ranked.compatible(cfg, a, b, now) then
					local d = math.abs(a.tr - b.tr)
					if not best or d < bestD then
						best, bestD = b, d
					end
				end
			end
			if best then
				used[a.u], used[best.u] = true, true
				pairs_[#pairs_ + 1] = { a = a, b = best }
			end
		end
	end
	return pairs_
end

---------------------------------------------------------------- transformations UpdateAsync (atomiques côté MemoryStore)
-- Bail de l'apparieur : pris si libre, expiré ou déjà à nous. Retourne la nouvelle valeur, ou nil (= ne rien écrire).
function Ranked.leaderTransform(old, job, now, ttl)
	if type(old) ~= "table" or type(old.exp) ~= "number" or old.exp <= now or old.job == job then
		return { job = job, exp = now + ttl }
	end
	return nil
end

function Ranked.isLeader(value, job, now)
	return type(value) == "table" and value.job == job and type(value.exp) == "number" and value.exp > now
end

-- Réserve une entrée de file pour un match : échoue (nil) si l'entrée a disparu (annulée, expirée) ou est déjà prise.
function Ranked.claimTransform(old, matchId)
	if type(old) ~= "table" or old.m ~= nil then
		return nil
	end
	local new = table.clone(old)
	new.m = matchId
	return new
end

-- Annule la réservation (réservation de serveur ratée, second joueur indisponible) : seulement si c'est la nôtre.
function Ranked.releaseTransform(old, matchId)
	if type(old) ~= "table" or old.m ~= matchId then
		return nil
	end
	local new = table.clone(old)
	new.m = nil
	return new
end

-- Rafraîchissement par le serveur du joueur : ne réécrit JAMAIS une entrée déjà réservée par l'apparieur (le ticket arrive).
function Ranked.refreshTransform(old, entry, now)
	if type(old) == "table" and old.m ~= nil then
		return nil
	end
	local new = table.clone(entry)
	new.r = now
	return new
end

---------------------------------------------------------------- match, ticket, serveur d'arène
-- Enregistrement de match (HashMap PvpMatch_v1[id]) : seule source de vérité du serveur d'arène (le TeleportData n'est qu'un indice).
function Ranked.newMatch(cfg, id, a, b, code, psid, seed, now)
	return {
		id = id,
		a = a.u,
		b = b.u,
		na = a.name,
		nb = b.name,
		ta = a.team,
		tb = b.team,
		pa = a.party,
		pb = b.party,
		code = code,
		psid = psid,
		seed = seed,
		t = now,
		exp = now + cfg.matchTtl,
	}
end

function Ranked.newTicket(cfg, match, side, now)
	local mine = side == "a"
	return { match = match.id, code = match.code, opp = mine and match.nb or match.na, side = side, exp = now + cfg.ticketTtl }
end

-- Ticket utilisable par ce serveur pour ce joueur ? (forme, expiration).
function Ranked.ticketValid(t, now)
	return type(t) == "table"
		and type(t.match) == "string"
		and #t.match > 0
		and #t.match <= 64
		and type(t.code) == "string"
		and #t.code > 0
		and type(t.exp) == "number"
		and t.exp > now
		and (t.side == "a" or t.side == "b")
end

-- Admission dans le serveur d'arène : le match existe, n'a pas expiré, a été réservé pour CE serveur (PrivateServerId) et le joueur en fait partie.
-- Retourne (side "a"|"b") ou (nil, raison).
function Ranked.arenaAdmit(match, uid, psid, now)
	if type(match) ~= "table" or type(match.exp) ~= "number" then
		return nil, "no_match"
	end
	if match.exp <= now then
		return nil, "expired"
	end
	if type(match.psid) == "string" and match.psid ~= "" and match.psid ~= psid then
		return nil, "wrong_server"
	end
	if uid == match.a then
		return "a"
	elseif uid == match.b then
		return "b"
	end
	return nil, "not_member"
end

-- État du serveur d'arène. phase : "wait" (attente des deux joueurs) -> "fight" -> "done" ; ou "void" (annulé : personne ne gagne ni ne perd).
function Ranked.arenaNew(match, now)
	return { match = match, phase = "wait", t0 = now, present = {}, turns = 0 }
end

function Ranked.arenaArrive(A, side)
	if A.phase ~= "wait" or (side ~= "a" and side ~= "b") then
		return false
	end
	A.present[side] = true
	return true
end

-- Décision : "start" (les deux là), "void" (délai dépassé avec un absent), "wait" ; hors attente : "fight" pendant le combat, sinon "idle"
-- (un match annulé ou terminé ne redéclenche jamais rien).
function Ranked.arenaTick(cfg, A, now)
	if A.phase ~= "wait" then
		return A.phase == "fight" and "fight" or "idle"
	end
	if A.present.a and A.present.b then
		return "start"
	end
	if now - A.t0 >= cfg.waitArena then
		return "void"
	end
	return "wait"
end

-- Un joueur part. Pendant l'attente : il n'est plus présent (le match sera annulé au délai). Pendant le combat : forfait.
-- Retourne "absent" | "forfeit" | "none".
function Ranked.arenaLeave(A, side)
	if A.phase == "wait" then
		A.present[side] = nil
		return "absent"
	elseif A.phase == "fight" then
		return "forfeit"
	end
	return "none"
end

---------------------------------------------------------------- résultat et trophées
-- Résultat d'un match en direct (les deux joueurs étaient présents au départ, sinon cette fonction n'est jamais appelée).
-- r = { winner = "a"|"b", forfeit = bool, turns = n, a = { trophies, live }, b = { trophies, live } } ; gainFn = Config.pvpGain ; loss = Config.PVP.loss.
-- Retourne { a = delta, b = delta, capped = { a = bool, b = bool }, fed = bool } sans rien modifier.
function Ranked.outcome(cfg, gainFn, loss, r)
	local w, l = r.winner, (r.winner == "a" and "b" or "a")
	local out = { capped = {} }
	local gain = gainFn(r[w].trophies, r[l].trophies)
	if r.forfeit and (r.turns or 0) < cfg.minTurnsForGain then
		gain = 0
		out.fed = true -- forfait trop tôt : rien pour le gagnant (deux comptes ne peuvent pas se « nourrir »)
	end
	local room = math.max(0, cfg.dailyTrophyCap - r[w].live.gained)
	if gain > room then
		gain = room
		out.capped[w] = true
	end
	out[w] = gain
	out[l] = -math.min(math.max(0, r[l].trophies), loss)
	return out
end

-- Applique un delta à pv (battle.pvp) et live (battle.live) d'un joueur. win = bool.
function Ranked.apply(pv, live, delta, win)
	pv.trophies = math.max(0, pv.trophies + delta)
	if win then
		pv.wins = pv.wins + 1
		live.w = live.w + 1
		if delta > 0 then
			live.gained = live.gained + delta
		end
	else
		pv.losses = pv.losses + 1
		live.l = live.l + 1
	end
end

-- Combat consommé au départ (les deux présents) ; un match annulé ne consomme rien.
function Ranked.canFight(cfg, live)
	return live.fights < cfg.dailyFights
end

---------------------------------------------------------------- téléportation, repli, retour
-- Après `attempts` échecs : { retry = délai } tant que attempts <= cfg.teleportRetries, sinon { requeue = true }.
function Ranked.teleportPlan(cfg, attempts)
	if attempts <= cfg.teleportRetries then
		return { retry = cfg.teleportRetryDelay }
	end
	return { requeue = true }
end

-- Repli vers l'asynchrone après cfg.fallbackAfter secondes sans adversaire.
function Ranked.shouldFallback(cfg, since, now)
	return now - since >= cfg.fallbackAfter
end

-- Destination du retour : la partie d'origine si son entrée du registre ChipeParties existe encore (le MemoryStore l'efface à expiration),
-- est ouverte et compte encore le joueur parmi ses membres (le hub ne le retire qu'à son arrivée au hub) ; sinon le hub.
-- (createdAt du registre est un os.clock() du HUB : non comparable depuis un autre serveur, donc non utilisé ici.)
-- Retourne { place = "party", code, partyId } ou { place = "hub", partyId }.
function Ranked.returnPlan(Game, partyId, entry, uid)
	if
		type(partyId) == "string"
		and type(entry) == "table"
		and entry.open
		and type(entry.code) == "string"
		and contains(entry.members, uid)
		and type(entry.count) == "number"
		and entry.count <= math.min(entry.size or Game.MaxPlayers, Game.MaxPlayers)
	then
		return { place = "party", code = entry.code, partyId = partyId }
	end
	return { place = "hub", partyId = type(partyId) == "string" and partyId or nil }
end

---------------------------------------------------------------- combat à deux joueurs : vues en miroir
-- Battle.view et les événements sont écrits du point de vue du camp 1 (camp A) ; le joueur B reçoit la vue inversée.
function Ranked.mirrorView(v)
	local out = table.clone(v)
	out.sides = { v.sides[2], v.sides[1] }
	if v.winner then
		out.winner = 3 - v.winner
	end
	return out
end

function Ranked.mirrorEvents(events)
	local out = {}
	for i, ev in ipairs(events) do
		local c = table.clone(ev)
		if c.side == 1 or c.side == 2 then
			c.side = 3 - c.side
		end
		out[i] = c
	end
	return out
end

-- Action reçue du client (chaîne) -> action Battle, ou nil.
function Ranked.parseAction(arg)
	if arg == "attack" or arg == "skill" then
		return { kind = arg }
	end
	if type(arg) == "string" and #arg <= 8 then
		local n = tonumber(arg:match("^swap(%d)$"))
		if n then
			return { kind = "swap", to = n }
		end
	end
	return nil
end

---------------------------------------------------------------- quotas MemoryStore (E.3)
-- Requêtes par minute estimées : chaque serveur publie son compte et lit l'ouverture (2 × 60/ccuPublish) et tente le bail (60/leaderEvery) ;
-- le leader lit la file (60/leaderEvery) et somme puis écrit les comptes (2 × 60/ccuPublish) ; chaque joueur en file rafraîchit (60/refresh) et
-- interroge son ticket (60/pollTicket) ; chaque match coûte ~8 requêtes (2 réservations, match, 2 tickets, 2 retraits, 1 lecture à l'arène).
-- Limite Roblox : 1000 + 100 × joueurs par minute.
function Ranked.quotaPerMinute(cfg, servers, queued, matchesPerMin)
	local perServer = 2 * 60 / cfg.ccuPublish + 60 / cfg.leaderEvery
	local leader = 60 / cfg.leaderEvery + 2 * 60 / cfg.ccuPublish
	local perQueued = 60 / cfg.refresh + 60 / cfg.pollTicket
	return servers * perServer + leader + queued * perQueued + (matchesPerMin or 0) * 8
end

function Ranked.quotaLimit(players)
	return 1000 + 100 * players
end

return Ranked

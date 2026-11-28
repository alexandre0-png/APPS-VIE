-- ModuleScript : ReplicatedStorage/Duel   (lot 13, E.1 E.2 E.4, B.4)
-- Règles PURES du duel local et des ligues (aucun service Roblox, aucun require, horloge injectée, jamais d'erreur sur entrée invalide). Pas de += ni de continue (lanceur lupa).
-- Le serveur (Main.server.lua) fait les effets (placement sur le sable, Battle.turn, notifications) ; ce module décide.
--   Duel.canChallenge(ctx, cfg)        -> ok, raison, côté ("a" défieur | "b" défié)   [6 refus de E.2 + soi-même + occupé]
--   Duel.newBook() / request / answer / decline / expire / finish   -> carnet des défis (délai 20 s, un seul accepté)
--   Duel.newMatch / noteTurn            -> compteur d'inactivité : 2 tours sans action = forfait
--   Duel.settle(duelA, duelB, ...)      -> récompenses (10/jour, 3/paire/jour), ratio V/D ; AUCUN trophée
--   Duel.percent / record / recordFor   -> ratio « 124 V / 37 D (77 %) » (même formule que IntroPlan)
--   Duel.league / seasonReset / seasonReward / introSide -> ligues, saison, données d'intro B.4
local Duel = {}

Duel.CAP = 10000000
Duel.REASONS = { "self", "range", "egg", "chased", "dialogue", "castle", "newbie", "busy" }

local DEFAULT = { range = 30, requestTimeout = 20, sameTargetCooldown = 120, rewardedPerDay = 10, samePairRewardedPerDay = 3, turnSeconds = 10, afkTurnsToForfeit = 2, coinsWinMins = 1, coinsLoseMins = 0.25, maxPendingPerTarget = 3, maxCoins = 1e12 }

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function cfgOf(cfg)
	local c = {}
	for k, v in pairs(DEFAULT) do
		c[k] = v
	end
	if type(cfg) == "table" then
		for k, v in pairs(cfg) do
			if DEFAULT[k] ~= nil and isNum(v) then
				c[k] = v
			end
		end
	end
	return c
end

local function count(v)
	if not isNum(v) or v < 0 then
		return 0
	end
	return math.min(Duel.CAP, math.floor(v))
end

-- ---------------------------------------------------------------- Ratio
function Duel.percent(wins, losses)
	local w, l = count(wins), count(losses)
	return math.floor(100 * w / math.max(1, w + l) + 0.5)
end

function Duel.record(wins, losses)
	local w, l = count(wins), count(losses)
	return w .. " V / " .. l .. " D (" .. Duel.percent(w, l) .. " %)"
end

-- Victoires/défaites selon le mode (B.4). profile = battle (données du joueur) ; PNJ : passer { wins, losses } fixes au lieu d'un profil.
-- pvp = battle.pvp.wins/losses + battle.live.w/l ; duel = battle.duel.w/l ; pve = battle.pve.w/l ; tower = étage atteint (V = étages franchis, D = 0).
function Duel.recordFor(mode, battle)
	local b = type(battle) == "table" and battle or {}
	if mode == "duel" then
		local d = type(b.duel) == "table" and b.duel or {}
		return count(d.w), count(d.l)
	elseif mode == "pvp" then
		local p = type(b.pvp) == "table" and b.pvp or {}
		local lv = type(b.live) == "table" and b.live or {}
		return math.min(Duel.CAP, count(p.wins) + count(lv.w)), math.min(Duel.CAP, count(p.losses) + count(lv.l))
	elseif mode == "pve" then
		local d = type(b.pve) == "table" and b.pve or {}
		return count(d.w), count(d.l)
	elseif mode == "tower" then
		return count(b.best), 0
	elseif mode == "npc" then
		return count(b.wins), count(b.losses)
	end
	return 0, 0
end

-- ---------------------------------------------------------------- Ligues
-- leagues = Config.LEAGUES (liste triée par min croissant). Retourne l'entrée de la ligue (la plus haute dont min <= trophées), jamais nil si la liste est valide.
function Duel.league(leagues, trophies)
	local t = isNum(trophies) and math.max(0, math.floor(trophies)) or 0
	local best, idx
	if type(leagues) ~= "table" then
		return nil, 0
	end
	for i = 1, #leagues do
		local L = leagues[i]
		if type(L) == "table" and isNum(L.min) and t >= L.min and (best == nil or L.min >= best.min) then
			best, idx = L, i
		end
	end
	return best, idx or 0
end

-- Texte de ligue pour l'intro (IntroPlan : 16 caractères max) : « 🥇 Or ».
function Duel.leagueText(leagues, trophies)
	local L = Duel.league(leagues, trophies)
	if not L then
		return ""
	end
	return ((type(L.icon) == "string" and L.icon ~= "") and (L.icon .. " ") or "") .. tostring(L.name)
end

-- Remise partielle de saison (E.4) : sous 300 inchangé ; au-delà trophées = max(300, floor(trophées x 0,6)).
function Duel.seasonReset(trophies, from, factor)
	local t = isNum(trophies) and math.max(0, math.floor(trophies)) or 0
	local f = isNum(from) and from or 300
	local k = isNum(factor) and factor or 0.6
	if t <= f then
		return t
	end
	return math.max(f, math.floor(t * k))
end

-- Meilleure récompense dont le seuil est atteint (rewards triées par trophées croissants).
function Duel.seasonReward(rewards, trophies)
	local t = isNum(trophies) and trophies or 0
	local best
	if type(rewards) ~= "table" then
		return nil
	end
	for i = 1, #rewards do
		local r = rewards[i]
		if type(r) == "table" and isNum(r.trophies) and t >= r.trophies and (best == nil or r.trophies >= best.trophies) then
			best = r
		end
	end
	return best
end

-- Un côté de l'intro (B.4) à passer à IntroPlan.plan : { name, userId, wins, losses, league, trophies, pets }.
function Duel.introSide(mode, battle, base, leagues)
	local w, l = Duel.recordFor(mode, battle)
	local b = type(base) == "table" and base or {}
	local tr = count(b.trophies)
	return { name = b.name, userId = b.userId, wins = w, losses = l, league = Duel.leagueText(leagues, tr), trophies = tr, pets = b.pets }
end

-- ---------------------------------------------------------------- Défi : 6 cas de refus (E.2) + soi-même + occupé
-- ctx = { a = { userId, carryingEgg, chased, inDialogue, inCastle, newbie, busy }, b = { même forme }, distance = studs }
-- newbie = protection débutant ACTIVE (déjà non désactivée). Retourne true | false, raison, "a"|"b".
function Duel.canChallenge(ctx, cfg)
	local c = cfgOf(cfg)
	if type(ctx) ~= "table" or type(ctx.a) ~= "table" or type(ctx.b) ~= "table" then
		return false, "busy", "a"
	end
	if ctx.a.userId ~= nil and ctx.a.userId == ctx.b.userId then
		return false, "self", "a"
	end
	if not isNum(ctx.distance) or ctx.distance > c.range or ctx.distance < 0 then
		return false, "range", "b"
	end
	local keys = { { "carryingEgg", "egg" }, { "chased", "chased" }, { "inDialogue", "dialogue" }, { "inCastle", "castle" }, { "newbie", "newbie" }, { "busy", "busy" } }
	local sides = { { "a", ctx.a }, { "b", ctx.b } }
	for k = 1, #keys do
		for s = 1, 2 do
			if sides[s][2][keys[k][1]] == true then
				return false, keys[k][2], sides[s][1]
			end
		end
	end
	return true, "", ""
end

-- ---------------------------------------------------------------- Carnet des défis
-- book = { pending = { [challengerId] = { from, to, t } }, last = { ["from>to"] = t }, active = { [userId] = duelId }, nextId }
function Duel.newBook()
	return { pending = {}, last = {}, active = {}, nextId = 1 }
end

local function pendingFor(book, to)
	local n = 0
	for _, p in pairs(book.pending) do
		if p.to == to then
			n = n + 1
		end
	end
	return n
end

-- Envoie un défi. ctx comme canChallenge (+ ctx.a.userId, ctx.b.userId nombres). Retourne true | false, raison.
function Duel.request(book, ctx, now, cfg)
	local c = cfgOf(cfg)
	if type(book) ~= "table" or type(ctx) ~= "table" or type(ctx.a) ~= "table" or type(ctx.b) ~= "table" or not isNum(ctx.a.userId) or not isNum(ctx.b.userId) or not isNum(now) then
		return false, "busy"
	end
	local from, to = ctx.a.userId, ctx.b.userId
	if book.active[from] or book.active[to] then
		return false, "busy"
	end
	local ok, why = Duel.canChallenge(ctx, c)
	if not ok then
		return false, why
	end
	local last = book.last[from .. ">" .. to]
	if last and now - last < c.sameTargetCooldown then
		return false, "cooldown"
	end
	local mine = book.pending[from]
	if mine and now - mine.t < c.requestTimeout then
		return false, "pendingOut"
	end
	if pendingFor(book, to) >= c.maxPendingPerTarget then
		return false, "crowded"
	end
	book.pending[from] = { from = from, to = to, t = now }
	book.last[from .. ">" .. to] = now
	return true, ""
end

-- Le défié accepte le défi de `from`. Un seul défi accepté : tous les autres défis qui touchent l'un des deux sont annulés (retournés).
-- Retourne true, duelId, annulés | false, raison.
function Duel.answer(book, to, from, accept, now, cfg, ctx)
	local c = cfgOf(cfg)
	local p = type(book) == "table" and isNum(from) and book.pending[from] or nil
	if not p or p.to ~= to or not isNum(now) then
		return false, "none"
	end
	if now - p.t > c.requestTimeout then
		book.pending[from] = nil
		return false, "expired"
	end
	if not accept then
		book.pending[from] = nil
		return false, "declined"
	end
	if book.active[from] or book.active[to] then
		book.pending[from] = nil
		return false, "busy"
	end
	if ctx ~= nil then
		local ok, why = Duel.canChallenge(ctx, c) -- états relus à l'acceptation
		if not ok then
			book.pending[from] = nil
			return false, why
		end
	end
	book.pending[from] = nil
	local id = book.nextId
	book.nextId = id + 1
	book.active[from], book.active[to] = id, id
	local cancelled = {}
	for k, q in pairs(book.pending) do
		if q.from == from or q.to == from or q.from == to or q.to == to then
			cancelled[#cancelled + 1] = { from = q.from, to = q.to }
			book.pending[k] = nil
		end
	end
	return true, id, cancelled
end

function Duel.decline(book, to, from, now, cfg)
	return Duel.answer(book, to, from, false, now, cfg)
end

-- Défis expirés (à appeler toutes les secondes) : retourne la liste { from, to } retirée.
function Duel.expire(book, now, cfg)
	local c = cfgOf(cfg)
	local out = {}
	if type(book) ~= "table" or not isNum(now) then
		return out
	end
	for k, p in pairs(book.pending) do
		if now - p.t > c.requestTimeout then
			out[#out + 1] = { from = p.from, to = p.to }
			book.pending[k] = nil
		end
	end
	return out
end

-- Fin ou départ : libère les deux joueurs et retire leurs défis en attente (joueur qui quitte).
function Duel.finish(book, userId)
	if type(book) ~= "table" then
		return
	end
	local id = book.active[userId]
	if id then
		for u, v in pairs(book.active) do
			if v == id then
				book.active[u] = nil
			end
		end
	end
	for k, p in pairs(book.pending) do
		if p.from == userId or p.to == userId then
			book.pending[k] = nil
		end
	end
end

-- Purge les anciennes dates de cooldown (évite la croissance de la table).
function Duel.prune(book, now, cfg)
	local c = cfgOf(cfg)
	if type(book) ~= "table" or not isNum(now) then
		return
	end
	for k, t in pairs(book.last) do
		if now - t >= c.sameTargetCooldown then
			book.last[k] = nil
		end
	end
end

-- ---------------------------------------------------------------- Tours et forfait
function Duel.newMatch(idA, idB)
	return { a = idA, b = idB, afkA = 0, afkB = 0, turns = 0, over = false, winner = nil, reason = "" }
end

-- Enregistre un tour : actedA/actedB = le joueur a choisi une action avant la fin des 10 s. Une action remet le compteur à 0.
-- Retourne "continue" | "forfeitA" | "forfeitB" | "cancelled" (les deux inactifs en même temps : duel annulé, ni vainqueur ni récompense).
function Duel.noteTurn(m, actedA, actedB, cfg)
	local c = cfgOf(cfg)
	if type(m) ~= "table" or m.over then
		return "continue"
	end
	m.turns = m.turns + 1
	m.afkA = actedA and 0 or (m.afkA + 1)
	m.afkB = actedB and 0 or (m.afkB + 1)
	local fa, fb = m.afkA >= c.afkTurnsToForfeit, m.afkB >= c.afkTurnsToForfeit
	if fa and fb then
		m.over, m.reason = true, "cancelled"
		return "cancelled"
	elseif fa then
		m.over, m.winner, m.reason = true, "b", "forfeit"
		return "forfeitA"
	elseif fb then
		m.over, m.winner, m.reason = true, "a", "forfeit"
		return "forfeitB"
	end
	return "continue"
end

-- ---------------------------------------------------------------- Récompenses et ratio
-- Profil de duel assaini : { w, l, day, n, pairs = { [idAdversaire texte] = nombre } }. Les paires ne contiennent que des duels récompensés (<= rewardedPerDay clés).
function Duel.cleanState(raw, today)
	local d = type(raw) == "table" and raw or {}
	local day = isNum(d.day) and math.floor(d.day) or 0
	local out = { w = count(d.w), l = count(d.l), day = day, n = 0, pairs = {} }
	if day == today then
		out.n = math.min(1000, count(d.n))
		if type(d.pairs) == "table" then
			local k = 0
			for key, v in pairs(d.pairs) do
				if type(key) == "string" and isNum(v) and v >= 1 and k < 20 then
					out.pairs[key] = math.min(1000, math.floor(v))
					k = k + 1
				end
			end
		end
	else
		out.day = isNum(today) and today or day
	end
	return out
end

function Duel.coins(incomePerSec, minutes, cfg)
	local c = cfgOf(cfg)
	if not isNum(incomePerSec) or incomePerSec <= 0 or not isNum(minutes) or minutes <= 0 then
		return 0
	end
	return math.min(c.maxCoins, math.floor(incomePerSec * 60 * minutes))
end

-- Solde un duel pour UN joueur. state = battle.duel (modifié), oppId = userId adversaire, outcome = "win" | "loss" | "draw", now, incomePerSec.
-- Le ratio (w/l) est toujours compté (sauf annulé) ; les pièces seulement si quota du jour (10) ET quota de la paire (3) non atteints.
-- Retourne { rewarded, coins, reason, won }. NE TOUCHE JAMAIS aux trophées (aucun champ trophée n'existe ici).
function Duel.settle(state, oppId, outcome, now, incomePerSec, cfg)
	local c = cfgOf(cfg)
	local today = isNum(now) and math.floor(now / 86400) or 0
	local clean = Duel.cleanState(state, today)
	if type(state) == "table" then
		state.w, state.l, state.day, state.n, state.pairs = clean.w, clean.l, clean.day, clean.n, clean.pairs
	else
		state = clean
	end
	if outcome ~= "win" and outcome ~= "loss" then
		return { rewarded = false, coins = 0, reason = "draw", won = false }
	end
	local won = outcome == "win"
	if won then
		state.w = math.min(Duel.CAP, state.w + 1)
	else
		state.l = math.min(Duel.CAP, state.l + 1)
	end
	local key = tostring(isNum(oppId) and math.floor(oppId) or 0)
	local pair = state.pairs[key] or 0
	if state.n >= c.rewardedPerDay then
		return { rewarded = false, coins = 0, reason = "dayCap", won = won }
	end
	if pair >= c.samePairRewardedPerDay then
		return { rewarded = false, coins = 0, reason = "pairCap", won = won }
	end
	state.n = state.n + 1
	state.pairs[key] = pair + 1
	return { rewarded = true, coins = Duel.coins(incomePerSec, won and c.coinsWinMins or c.coinsLoseMins, c), reason = "", won = won }
end

-- Aide : issue d'un match vue de chaque côté ("win"/"loss"/"draw").
function Duel.outcomes(m)
	if type(m) ~= "table" or not m.over or m.winner == nil then
		return "draw", "draw"
	end
	if m.winner == "a" then
		return "win", "loss"
	end
	return "loss", "win"
end

return Duel

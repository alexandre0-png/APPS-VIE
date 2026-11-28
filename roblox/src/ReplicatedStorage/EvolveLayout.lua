-- ModuleScript : ReplicatedStorage/Shared/EvolveLayout   (interface « ✨ Évoluer » : logique PURE, testée par tests/evolveui.luau)
-- Module pur (aucune instance Roblox, aucun require ; `Evolution` est INJECTÉ en argument) : liste des pets évoluables, aperçu des gains, doublons
-- sacrifiés, machine d'états de la confirmation en DEUX étapes, retour visuel court (<= 1,2 s), états refusés, disposition (cibles >= 44 px), contrastes.
-- Le client N'ENVOIE QUE l'emplacement (evoPreview) puis { i, maxCost } (evolve) : doublons, coût et interdits restent décidés par le SERVEUR
-- (Evolution.plan). Ici : estimation de confort (même règle pure qu'Evolution), jamais une autorité. Config.EVOLUTION.enabled = false => « bientôt »,
-- aucune action possible, aucun message envoyé. Pas de += / -= / continue, pas de math.atan2 (lanceur lupa).
local EvolveLayout = {}

EvolveLayout.MIN_TOUCH = 44
EvolveLayout.ROW_H = 52
EvolveLayout.CONFIRM_SECONDS = 4 -- la 2e étape expire : un appui isolé ne fait jamais évoluer
EvolveLayout.SEND_TIMEOUT = 6 -- sans réponse du serveur : retour à l'état « prêt » (aperçu redemandé)
EvolveLayout.FX_SECONDS = 1.0
EvolveLayout.MAX_FX = 1.2
EvolveLayout.PREVIEW_COOLDOWN = 0.35 -- au plus une demande d'aperçu toutes les 0,35 s côté client
EvolveLayout.MAX_ROWS = 40
EvolveLayout.DEFAULT_VIEWPORT = { w = 640, h = 360 }
EvolveLayout.MIN_VIEWPORT = { w = 240, h = 320 }

EvolveLayout.UI = {
	panel = { 24, 38, 46 }, panelStroke = { 255, 210, 63 }, row = { 44, 60, 70 }, rowSel = { 70, 94, 110 }, text = { 250, 247, 238 }, muted = { 188, 204, 208 },
	ok = { 96, 232, 120 }, warn = { 255, 196, 60 }, bad = { 255, 140, 140 }, soon = { 255, 226, 140 },
	btnOn = { 255, 210, 63 }, btnOff = { 70, 78, 86 }, btnConfirm = { 255, 159, 28 }, btnCancel = { 255, 99, 99 },
	darkText = { 30, 24, 0 }, offText = { 226, 228, 236 }, cancelText = { 40, 8, 8 },
}

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

local function rect(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

---------------------------------------------------------------- configuration et gains

local function cfgOf(Config)
	return type(Config) == "table" and type(Config.EVOLUTION) == "table" and Config.EVOLUTION or nil
end

function EvolveLayout.enabled(Config)
	local cfg = cfgOf(Config)
	return cfg ~= nil and cfg.enabled == true
end

-- Pourcentage entier d'un multiplicateur : 1,15 -> 15 ; invalide -> 0.
function EvolveLayout.pct(mul)
	if not isNum(mul) then
		return 0
	end
	return math.floor((mul - 1) * 100 + 0.5)
end

-- Gains affichés de la forme 2 d'un pet { p, s, m, f } : revenu avant / après (par seconde) et pourcentages. nil si le pet est inconnu.
function EvolveLayout.gains(Config, sl)
	local cfg = cfgOf(Config)
	if not cfg or type(sl) ~= "table" or type(Config.PETS) ~= "table" or Config.PETS[sl.p] == nil or type(Config.petIncome) ~= "function" then
		return nil
	end
	local before = Config.petIncome(sl.p, sl.s, sl.m)
	local after = Config.petIncome(sl.p, sl.s, sl.m, 2)
	return { incomeBefore = before, incomeAfter = after, incomePct = EvolveLayout.pct(cfg.incomeMul), powerPct = EvolveLayout.pct(cfg.powerMul) }
end

---------------------------------------------------------------- liste des pets évoluables

local function tierOf(Config, sl)
	local def = type(Config.PETS) == "table" and Config.PETS[sl.p] or nil
	return def and def.tier or 1
end

local function tierName(Config, tier)
	local t = type(Config.TIERS) == "table" and Config.TIERS[tier] or nil
	return t and t.name or ("Rareté " .. tostring(tier))
end

-- Vue de l'état du joueur pour les règles pures d'Evolution : { slots, equip, battle = { team } } ; la défense PvP n'est pas envoyée au client (le serveur tranche).
local function dataOf(state)
	local st = type(state) == "table" and state or {}
	local team = type(st.battle) == "table" and type(st.battle.team) == "table" and st.battle.team or {}
	return { slots = type(st.slots) == "table" and st.slots or {}, equip = type(st.equip) == "table" and st.equip or {}, battle = { team = team } }
end

local function capOf(state)
	local c = type(state) == "table" and state.cap
	if isNum(c) and c >= 1 then
		return math.floor(c)
	end
	return 0
end

-- Estimation (même règle pure que le serveur, sans la défense PvP ni les pièces) pour l'emplacement i : { ok, code, found, need, sac }.
function EvolveLayout.estimate(Config, E, state, i)
	local cfg = cfgOf(Config)
	local need = cfg and cfg.sacrifices or 3
	if type(E) ~= "table" or not cfg then
		return { ok = false, code = "disabled", need = need }
	end
	local d, cap = dataOf(state), capOf(state)
	local ok, code = E.targetCheck(Config, d, i, cap)
	if not ok then
		return { ok = false, code = code, need = need }
	end
	local sac, found = E.pickSacrifices(Config, d, i, cap)
	if not sac then
		return { ok = false, code = "dupes", found = found or 0, need = need }
	end
	return { ok = true, code = nil, sac = sac, need = need }
end

-- Liste des pets de la base : { i, p, name, emoji, tier, tierName, form, status, code, found, need, income, incomeAfter, tag }.
--   status : "ready" (évolution possible d'après l'estimation), "dupes" (pas assez de doublons), "locked" (interdit : suiveur, équipe, taille, mutation...),
--   "done" (déjà en forme 2). Ordre : prêts d'abord, puis doublons manquants, interdits, forme 2 ; à égalité rareté décroissante puis indice.
function EvolveLayout.list(Config, E, state)
	local rows = {}
	local st = type(state) == "table" and state or {}
	local slots = type(st.slots) == "table" and st.slots or {}
	local cap = capOf(st)
	for i = 1, math.min(cap, EvolveLayout.MAX_ROWS) do
		local sl = slots[i]
		if type(sl) == "table" and sl.k == "p" and type(Config.PETS) == "table" and Config.PETS[sl.p] ~= nil then
			local def = Config.PETS[sl.p]
			local form = (sl.f == 2) and 2 or 1
			local row = { i = i, p = sl.p, name = tostring(def.name or "?"), emoji = tostring(def.emoji or "?"), tier = tierOf(Config, sl), form = form, size = sl.s, mut = sl.m }
			row.tierName = tierName(Config, row.tier)
			local g = EvolveLayout.gains(Config, sl)
			row.income = g and g.incomeBefore or 0
			row.incomeAfter = g and g.incomeAfter or 0
			if form == 2 then
				row.status, row.code, row.tag = "done", "already", "★2"
				row.income = g and g.incomeAfter or 0
			else
				local est = EvolveLayout.estimate(Config, E, st, i)
				row.need, row.found = est.need, est.found
				if est.ok then
					row.status, row.tag = "ready", "✨ Prêt"
				elseif est.code == "dupes" then
					row.status, row.code, row.tag = "dupes", "dupes", "Doublons " .. tostring(est.found or 0) .. "/" .. tostring(est.need)
				else
					row.status, row.code, row.tag = "locked", est.code, "🔒"
				end
			end
			rows[#rows + 1] = row
		end
	end
	local rank = { ready = 1, dupes = 2, locked = 3, done = 4 }
	table.sort(rows, function(a, b)
		if rank[a.status] ~= rank[b.status] then
			return rank[a.status] < rank[b.status]
		end
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return a.i < b.i
	end)
	return rows
end

function EvolveLayout.countReady(rows)
	local n = 0
	for _, r in ipairs(type(rows) == "table" and rows or {}) do
		if r.status == "ready" then
			n = n + 1
		end
	end
	return n
end

-- Texte d'en-tête : « bientôt » quand la fonction est coupée ; sinon règle courte et nombre de pets prêts.
function EvolveLayout.header(Config, rows)
	local cfg = cfgOf(Config)
	if not cfg or cfg.enabled ~= true then
		return { soon = true, title = "✨ Évolution", subtitle = "Bientôt disponible : fais évoluer tes pets en forme 2.", rule = "" }
	end
	local ready = EvolveLayout.countReady(rows)
	local rule = (cfg.sacrifices or 3) .. " doublons de même rareté + " .. math.floor((cfg.costSeconds or 300) / 60 + 0.5) .. " min de revenus"
	local sub
	if #(rows or {}) == 0 then
		sub = "Fais d'abord éclore des pets."
	elseif ready == 0 then
		sub = "Aucun pet prêt : il te faut " .. (cfg.sacrifices or 3) .. " doublons de la même rareté."
	else
		sub = ready == 1 and "1 pet prêt à évoluer." or (ready .. " pets prêts à évoluer.")
	end
	return { soon = false, title = "✨ Évolution", subtitle = sub, rule = rule }
end

---------------------------------------------------------------- textes de refus

-- Message d'un code de refus (celui du serveur : Evolution.REFUSE) ; `view` ajoute le nombre de doublons trouvés ou le prix.
function EvolveLayout.refuseText(E, code, view)
	local R = type(E) == "table" and type(E.REFUSE) == "table" and E.REFUSE or {}
	if code == "dupes" and type(view) == "table" and isNum(view.found) and isNum(view.need) then
		return "Doublons : " .. math.floor(view.found) .. "/" .. math.floor(view.need) .. ". Il faut " .. math.floor(view.need) .. " doublons de la même rareté (jamais le dernier exemplaire d'une espèce)."
	elseif code == "coins" and type(view) == "table" and isNum(view.cost) then
		return "Pas assez de pièces : il en faut " .. math.floor(view.cost) .. " (5 min de revenus)."
	end
	return R[code] or R.slot or "Choisis un pet de ta base."
end

---------------------------------------------------------------- doublons sacrifiés (choix du serveur, affichage et vérification côté client)

-- Pastilles des doublons : { { i, emoji, name, tierName } } pour la liste `sac` de l'aperçu du serveur.
function EvolveLayout.sacChips(Config, state, sac)
	local out = {}
	local slots = type(state) == "table" and type(state.slots) == "table" and state.slots or {}
	for _, j in ipairs(type(sac) == "table" and sac or {}) do
		local sl = slots[j]
		local def = type(sl) == "table" and type(Config.PETS) == "table" and Config.PETS[sl.p] or nil
		if def then
			out[#out + 1] = { i = j, emoji = tostring(def.emoji or "?"), name = tostring(def.name or "?"), tierName = tierName(Config, def.tier or 1) }
		else
			out[#out + 1] = { i = j, emoji = "?", name = "?", tierName = "" }
		end
	end
	return out
end

-- Vérification de confort de la liste de doublons proposée par le serveur (jamais une autorité) : exactement `need` emplacements distincts, tous des pets de
-- la même rareté que le pet visé, jamais le pet visé lui-même. Retourne (true) ou (false, motif).
function EvolveLayout.validateSelection(Config, state, i, sac, need)
	local slots = type(state) == "table" and type(state.slots) == "table" and state.slots or {}
	local target = slots[i]
	if type(target) ~= "table" or target.k ~= "p" or type(Config.PETS) ~= "table" or Config.PETS[target.p] == nil then
		return false, "target"
	end
	if type(sac) ~= "table" or not isNum(need) or #sac ~= need then
		return false, "count"
	end
	local tier = Config.PETS[target.p].tier
	local seen = {}
	for _, j in ipairs(sac) do
		if not isNum(j) or j % 1 ~= 0 or j == i or seen[j] then
			return false, "dup"
		end
		seen[j] = true
		local sl = slots[j]
		if type(sl) ~= "table" or sl.k ~= "p" or type(Config.PETS[sl.p]) ~= "table" or Config.PETS[sl.p].tier ~= tier then
			return false, "tier"
		end
	end
	return true
end

---------------------------------------------------------------- machine d'états : sélection -> aperçu -> confirmation en deux étapes -> envoi -> retour visuel

function EvolveLayout.newFlow()
	return { phase = "idle", i = nil, view = nil, armedAt = nil, sentAt = nil, doneAt = nil, previewAt = nil, msg = nil, done = nil }
end

-- Appui sur une ligne : (re)demande l'aperçu. Pas pendant l'envoi ni le retour visuel. Retourne (flow, action) ; action = { kind = "preview", i } ou nil
-- (nil si la fonction est coupée, si l'emplacement est invalide ou si la dernière demande est trop récente).
function EvolveLayout.select(flow, i, now, enabled)
	if enabled ~= true or not isNum(i) or i % 1 ~= 0 or i < 1 or flow.phase == "sending" or flow.phase == "done" then
		return flow, nil
	end
	local t = isNum(now) and now or 0
	if flow.i == i and (flow.phase == "loading" or flow.phase == "ready" or flow.phase == "confirm") then
		return flow, nil
	end
	if isNum(flow.previewAt) and t - flow.previewAt < EvolveLayout.PREVIEW_COOLDOWN and flow.i ~= i then
		flow.i, flow.view, flow.phase, flow.armedAt, flow.msg = i, nil, "loading", nil, nil
		flow.pending = true -- demande différée : le client la relance après le délai (voir EvolveLayout.due)
		return flow, nil
	end
	flow.i, flow.view, flow.phase, flow.armedAt, flow.msg, flow.pending = i, nil, "loading", nil, nil, nil
	flow.previewAt = t
	return flow, { kind = "preview", i = i }
end

-- Demande d'aperçu différée à relancer ? Retourne l'action ou nil.
function EvolveLayout.due(flow, now)
	if flow.pending and flow.phase == "loading" and flow.i and isNum(now) and isNum(flow.previewAt) and now - flow.previewAt >= EvolveLayout.PREVIEW_COOLDOWN then
		flow.pending = nil
		flow.previewAt = now
		return { kind = "preview", i = flow.i }
	end
	return nil
end

-- Aperçu reçu du serveur ({ ok, i, sac, cost, need } ou { ok = false, code, ... }) : ignoré s'il ne concerne pas le pet choisi ou si la phase ne l'attend pas.
function EvolveLayout.onPreview(flow, view, now)
	if type(view) ~= "table" or flow.i == nil or view.i ~= flow.i then
		return flow
	end
	if flow.phase ~= "loading" and flow.phase ~= "ready" and flow.phase ~= "confirm" and flow.phase ~= "sending" and flow.phase ~= "refused" then
		return flow
	end
	flow.view = view
	flow.armedAt, flow.sentAt = nil, nil
	if view.ok == true and type(view.sac) == "table" and isNum(view.cost) then
		flow.phase, flow.msg = "ready", nil
	else
		flow.phase, flow.msg = "refused", view.code or "slot"
	end
	return flow
end

-- Appui sur le bouton principal. ready -> confirm (1re étape) ; confirm -> sending (2e étape, action evolve avec le prix vu) ; sinon rien.
-- Retourne (flow, action) ; action = { kind = "evolve", i, maxCost } ou nil.
function EvolveLayout.press(flow, now, enabled)
	if enabled ~= true then
		return flow, nil
	end
	local t = isNum(now) and now or 0
	if flow.phase == "ready" and type(flow.view) == "table" then
		flow.phase, flow.armedAt = "confirm", t
		return flow, nil
	elseif flow.phase == "confirm" and type(flow.view) == "table" then
		if isNum(flow.armedAt) and t - flow.armedAt <= EvolveLayout.CONFIRM_SECONDS then
			flow.phase, flow.sentAt = "sending", t
			return flow, { kind = "evolve", i = flow.i, maxCost = flow.view.cost }
		end
		flow.phase, flow.armedAt = "ready", nil
	end
	return flow, nil
end

-- Annule la confirmation (bouton « Annuler ») : retour à « prêt ». Sans effet pendant l'envoi.
function EvolveLayout.cancel(flow)
	if flow.phase == "confirm" then
		flow.phase, flow.armedAt = "ready", nil
	end
	return flow
end

-- Remise à zéro complète (fermeture de l'écran, pet disparu).
function EvolveLayout.reset(flow)
	flow.phase, flow.i, flow.view, flow.armedAt, flow.sentAt, flow.doneAt, flow.msg, flow.pending, flow.done = "idle", nil, nil, nil, nil, nil, nil, nil, nil
	return flow
end

-- Écoulement du temps : la 2e étape expire (confirm -> ready), l'envoi sans réponse revient à « prêt » avec un message, le retour visuel prend fin.
-- Retourne (flow, action) : action = { kind = "preview", i } quand l'envoi expire (l'aperçu est redemandé pour resynchroniser).
function EvolveLayout.tick(flow, now)
	local t = isNum(now) and now or 0
	if flow.phase == "confirm" and isNum(flow.armedAt) and t - flow.armedAt > EvolveLayout.CONFIRM_SECONDS then
		flow.phase, flow.armedAt = "ready", nil
	elseif flow.phase == "sending" and isNum(flow.sentAt) and t - flow.sentAt > EvolveLayout.SEND_TIMEOUT then
		flow.phase, flow.sentAt, flow.msg = "loading", nil, "timeout"
		flow.previewAt = t
		return flow, { kind = "preview", i = flow.i }
	elseif flow.phase == "done" and isNum(flow.doneAt) and t - flow.doneAt >= EvolveLayout.FX_SECONDS then
		EvolveLayout.reset(flow)
	end
	return flow, nil
end

-- Réponse « done » du serveur ({ k = "done", i, p, n }) : retour visuel (<= 1,2 s) puis retour au repos.
function EvolveLayout.onDone(flow, msg, now)
	if type(msg) ~= "table" or flow.i == nil or msg.i ~= flow.i or flow.phase ~= "sending" then
		return flow
	end
	flow.phase, flow.doneAt, flow.done, flow.armedAt, flow.sentAt = "done", isNum(now) and now or 0, { i = msg.i, p = msg.p, n = msg.n }, nil, nil
	return flow
end

-- Bouton principal : { text, active, kind } d'après la phase, le coût de l'aperçu et l'interrupteur. Jamais actif si la fonction est coupée.
function EvolveLayout.button(flow, enabled, E)
	local view = flow.view
	if enabled ~= true then
		return { text = "Bientôt disponible", active = false, kind = "soon", cancel = false }
	end
	local ph = flow.phase
	if ph == "ready" and type(view) == "table" then
		return { text = "✨ Évoluer (" .. math.floor(view.cost or 0) .. " 🪙)", active = true, kind = "ready", cancel = false }
	elseif ph == "confirm" and type(view) == "table" then
		return { text = "Confirmer : " .. math.floor(view.need or 3) .. " doublons + " .. math.floor(view.cost or 0) .. " 🪙", active = true, kind = "confirm", cancel = true }
	elseif ph == "loading" then
		return { text = "Vérification…", active = false, kind = "loading", cancel = false }
	elseif ph == "sending" then
		return { text = "Évolution…", active = false, kind = "sending", cancel = false }
	elseif ph == "done" then
		return { text = "✨ Évolué !", active = false, kind = "done", cancel = false }
	elseif ph == "refused" then
		return { text = "✖ " .. EvolveLayout.refuseText(E, flow.msg, view), active = false, kind = "refused", cancel = false }
	end
	return { text = "Choisis un pet", active = false, kind = "idle", cancel = false }
end

-- Résumé du pet choisi : { gains, sac chips, lignes de texte } pour le panneau de détail (nil si aucun pet choisi).
function EvolveLayout.detail(Config, state, flow)
	if flow.i == nil then
		return nil
	end
	local slots = type(state) == "table" and type(state.slots) == "table" and state.slots or {}
	local sl = slots[flow.i]
	if type(sl) ~= "table" or sl.k ~= "p" then
		return nil
	end
	local g = EvolveLayout.gains(Config, sl)
	if not g then
		return nil
	end
	local def = Config.PETS[sl.p]
	local lines = {
		"Revenu : +" .. g.incomePct .. " % (" .. string.format("%.1f", g.incomeBefore) .. " → " .. string.format("%.1f", g.incomeAfter) .. " /s)",
		"Force en combat : +" .. g.powerPct .. " % (pv et attaque)",
	}
	local chips = {}
	if type(flow.view) == "table" and type(flow.view.sac) == "table" then
		chips = EvolveLayout.sacChips(Config, state, flow.view.sac)
	end
	return { name = tostring(def.name or "?"), emoji = tostring(def.emoji or "?"), gains = g, lines = lines, chips = chips }
end

---------------------------------------------------------------- retour visuel court (propriétés mesurables)

-- Image du retour d'évolution à l'instant a (0..1) : échelle 1 -> 1,25 -> 1 (rebond), halo qui s'éteint, texte « ★2 » qui apparaît ; extrémités exactes.
function EvolveLayout.fx(a)
	local k = isNum(a) and clamp(a, 0, 1) or 1
	local pulse = math.sin(math.pi * k)
	local halo = 1 - k
	local starA = clamp(k * 3, 0, 1)
	return { scale = 1 + 0.25 * pulse, haloAlpha = halo, haloTransparency = 1 - halo * 0.7, starAlpha = starA }
end

function EvolveLayout.fxSeconds(reduced)
	return reduced == true and 0.5 or EvolveLayout.FX_SECONDS
end

---------------------------------------------------------------- disposition

function EvolveLayout.viewport(vw, vh)
	local d, m = EvolveLayout.DEFAULT_VIEWPORT, EvolveLayout.MIN_VIEWPORT
	local w = isNum(vw) and vw > 0 and vw or d.w
	local h = isNum(vh) and vh > 0 and vh or d.h
	return math.floor(math.max(m.w, w)), math.floor(math.max(m.h, h))
end

-- Rectangles (pixels, relatifs à la fenêtre) : panneau centré, en-tête, fermeture, liste défilante, détail, bouton principal, bouton annuler.
-- Garanties testées : tout dans la fenêtre moins la zone sûre, boutons >= 44 px, aucune superposition entre liste, détail et boutons.
function EvolveLayout.rects(vw, vh, safeIn)
	vw, vh = EvolveLayout.viewport(vw, vh)
	local s = type(safeIn) == "table" and safeIn or {}
	local sl, st, sr, sb = clamp(isNum(s.l) and s.l or 0, 0, vw * 0.25), clamp(isNum(s.t) and s.t or 0, 0, vh * 0.25), clamp(isNum(s.r) and s.r or 0, 0, vw * 0.25), clamp(isNum(s.b) and s.b or 0, 0, vh * 0.25)
	local m = 8
	local ax0, ay0, ax1, ay1 = sl + m, st + m, vw - sr - m, vh - sb - m
	local aw, ah = ax1 - ax0, ay1 - ay0
	local pw = math.floor(math.min(aw, 440))
	local ph = math.floor(math.min(ah, 520))
	local px = math.floor(ax0 + (aw - pw) / 2)
	local py = math.floor(ay0 + (ah - ph) / 2)
	local pad, gap, T = 10, 6, EvolveLayout.MIN_TOUCH
	local out = { vw = vw, vh = vh, panel = rect(px, py, pw, ph) }
	out.close = rect(px + pw - pad - T, py + pad, T, T)
	out.header = rect(px + pad, py + pad, pw - 2 * pad - T - gap, T)
	out.subtitle = rect(px + pad, py + pad + T + 2, pw - 2 * pad, 34)
	local footerH = T + 4
	local detailH = ph >= 420 and 118 or 86
	local topH = pad + T + 2 + 34 + gap -- en-tête et sous-titre
	detailH = math.max(52, math.min(detailH, ph - topH - pad - footerH - 2 * gap - EvolveLayout.ROW_H)) -- fenêtre basse : le détail cède de la place, la liste garde une ligne entière
	local by = py + ph - pad - footerH
	out.cancel = rect(px + pad, by, math.floor((pw - 2 * pad - gap) * 0.32), footerH)
	out.primary = rect(out.cancel.x + out.cancel.w + gap, by, pw - 2 * pad - gap - out.cancel.w, footerH)
	out.detail = rect(px + pad, by - gap - detailH, pw - 2 * pad, detailH)
	local ly = out.subtitle.y + out.subtitle.h + gap
	out.list = rect(px + pad, ly, pw - 2 * pad, math.max(EvolveLayout.ROW_H, out.detail.y - gap - ly))
	out.rowH = EvolveLayout.ROW_H
	out.area = rect(ax0, ay0, aw, ah)
	return out
end

function EvolveLayout.overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Nombre de lignes entièrement visibles dans la liste ; la liste défile au-delà.
function EvolveLayout.visibleRows(r)
	return math.max(1, math.floor(r.list.h / r.rowH))
end

---------------------------------------------------------------- contraste (accessibilité : jamais la couleur seule, texte >= 4,5:1)

local function lin(c)
	local v = c / 255
	if v <= 0.03928 then
		return v / 12.92
	end
	return ((v + 0.055) / 1.055) ^ 2.4
end
function EvolveLayout.luminance(rgb)
	return 0.2126 * lin(rgb[1]) + 0.7152 * lin(rgb[2]) + 0.0722 * lin(rgb[3])
end
function EvolveLayout.contrast(a, b)
	local la, lb = EvolveLayout.luminance(a), EvolveLayout.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end
-- Couples (texte, fond) réellement affichés ; chacun doit atteindre 4,5:1 (testé).
function EvolveLayout.textPairs()
	local U = EvolveLayout.UI
	return {
		{ "titre", U.text, U.panel }, { "sous-titre", U.muted, U.panel }, { "ligne", U.text, U.row }, { "ligne choisie", U.text, U.rowSel },
		{ "prêt", U.ok, U.row }, { "doublons manquants", U.warn, U.row }, { "interdit", U.bad, U.row }, { "bientôt", U.soon, U.panel },
		{ "bouton actif", U.darkText, U.btnOn }, { "bouton inactif", U.offText, U.btnOff }, { "confirmer", U.darkText, U.btnConfirm }, { "annuler", U.cancelText, U.btnCancel },
		{ "détail", U.text, U.panel },
	}
end

return EvolveLayout

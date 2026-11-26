-- ModuleScript : ReplicatedStorage/IntroPlan   (lot 10, B.4)
-- PLAN PUR de l'intro de combat (aucun service Roblox, aucun require, déterministe, jamais d'erreur) : deux bandeaux (joueur à gauche, adversaire à droite) avec
-- nom, ligue, trophées, ratio « 124 V / 37 D (77 %) » et 3 vignettes de pets (type + compteur de rareté), « VS » qui frappe, flèche d'avantage de type, décompte 3-2-1.
-- DÉCISION : durée totale 3,0 s au maximum (la spec disait 3,5 s ; plafond demandé 3 s) ; passable après 1,0 s ; sans décompte l'intro dure 2,2 s.
-- Entrée : IntroPlan.plan(info, opts)
--   info = { mode = "pvp"|"duel"|"pve"|"npc"|"tower", countdown = bool (décompte 3-2-1 si le temps de tour n'a pas démarré), advantage = nombre (multiplicateur du pet actif du joueur
--            contre le pet actif de l'adversaire, 1,5 / 1,25 / 1 / 0,8 / 0,67),
--            me = { name, userId, wins, losses, league, trophies, pets = { { type = "Feu", odds = 38494, tier = 5 }, ... } },
--            foe = { même forme ; name peut être un PNJ avec wins/losses fictifs } }
--   opts = { fmtOdds = function(n) -> texte (défaut : Odds.label, injecté par l'appelant ; sinon « 1 sur N » simple) }
-- Sortie : { duration, skipAfter, countdown, mode, left = side, right = side, vs = {t, d, ...}, arrow = {...} | nil, count = {{t, text}...}, beats }
--   side = { name, record = "124 V / 37 D (77 %)", wins, losses, percent, league, trophies, userId, pets = { {type, odds, oddsText, tier} (3 au plus) } }
-- Brancher : `BattleIntro.play(gui, IntroPlan.plan(info, { fmtOdds = Odds.label }), { onDone = startBattle })`.
-- Pas de += ni de continue (lanceur lupa).
local IntroPlan = {}

IntroPlan.MAX_DURATION = 3
IntroPlan.SKIP_AFTER = 1
IntroPlan.SLIDE = 0.4
IntroPlan.MAX_PETS = 3
IntroPlan.CAP = 999999999

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function count(v)
	if not isNum(v) or v < 0 then
		return 0
	end
	return math.min(IntroPlan.CAP, math.floor(v))
end

-- Pourcentage de victoires : floor(100 x V / max(1, V + D) + 0,5).
function IntroPlan.percent(wins, losses)
	local w, l = count(wins), count(losses)
	return math.floor(100 * w / math.max(1, w + l) + 0.5)
end

-- « 124 V / 37 D (77 %) »
function IntroPlan.record(wins, losses)
	local w, l = count(wins), count(losses)
	return w .. " V / " .. l .. " D (" .. IntroPlan.percent(w, l) .. " %)"
end

-- Multiplicateur en français : 1,5 -> « 1,5 » ; 1,25 -> « 1,25 » ; 0,67 -> « 0,67 » ; 0,8 -> « 0,8 ».
function IntroPlan.fmtMult(m)
	if not isNum(m) or m <= 0 then
		return "1"
	end
	local s = string.format("%.2f", m)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return (s:gsub("%.", ","))
end

local function cleanText(v, fallback, maxLen)
	if type(v) ~= "string" or v == "" then
		return fallback
	end
	return v:sub(1, maxLen or 24)
end

local function simpleOdds(n)
	if not isNum(n) or n < 1 then
		return ""
	end
	return "1 sur " .. string.format("%.0f", math.floor(n + 0.5))
end

local function side(raw, fmt)
	local t = type(raw) == "table" and raw or {}
	local w, l = count(t.wins), count(t.losses)
	local pets = {}
	local src = type(t.pets) == "table" and t.pets or {}
	for i = 1, math.min(IntroPlan.MAX_PETS, #src) do
		local p = type(src[i]) == "table" and src[i] or {}
		local odds = isNum(p.odds) and p.odds > 0 and p.odds or nil
		local text = ""
		if odds then
			local ok, res = pcall(fmt, odds)
			text = ok and type(res) == "string" and res or simpleOdds(odds)
		end
		pets[i] = { type = cleanText(p.type, "", 16), odds = odds, oddsText = text, tier = isNum(p.tier) and math.max(1, math.min(10, math.floor(p.tier))) or 1 }
	end
	return {
		name = cleanText(t.name, "???", 20),
		userId = isNum(t.userId) and math.floor(t.userId) or 0,
		wins = w,
		losses = l,
		percent = IntroPlan.percent(w, l),
		record = IntroPlan.record(w, l),
		league = cleanText(t.league, "", 16),
		trophies = count(t.trophies),
		pets = pets,
	}
end

function IntroPlan.plan(info, opts)
	local inf = type(info) == "table" and info or {}
	local fmt = type(opts) == "table" and type(opts.fmtOdds) == "function" and opts.fmtOdds or simpleOdds
	local countdown = inf.countdown == true
	local duration = countdown and 3.0 or 2.2
	local S = IntroPlan.SLIDE
	local mult = isNum(inf.advantage) and inf.advantage or 1
	local arrow = nil
	if mult > 1.0001 or mult < 0.9999 then
		arrow = { t = 1.0, d = 1.0, mult = mult, text = (mult > 1 and "Avantage ×" or "Désavantage ×") .. IntroPlan.fmtMult(mult), good = mult > 1, side = "left" }
	end
	local counts = {}
	local beats = {
		{ t = 0, d = S, kind = "slide", side = "left" },
		{ t = 0, d = S, kind = "slide", side = "right" },
		{ t = S, d = 0.4, kind = "pets" },
		{ t = 0.5, d = 0.3, kind = "vs", from = 2, to = 1, shake = 0.3, volume = 0.5, sound = "fanfare" },
	}
	if arrow then
		beats[#beats + 1] = { t = arrow.t, d = arrow.d, kind = "arrow" }
	end
	if countdown then
		for i = 1, 3 do
			local t = 1.6 + (i - 1) * 0.4
			counts[i] = { t = t, text = tostring(4 - i) }
			beats[#beats + 1] = { t = t, d = 0.4, kind = "count", text = tostring(4 - i) }
		end
	end
	beats[#beats + 1] = { t = duration - 0.2, d = 0.2, kind = "exit" }
	return {
		duration = duration,
		skipAfter = IntroPlan.SKIP_AFTER,
		countdown = countdown,
		mode = type(inf.mode) == "string" and inf.mode:sub(1, 12) or "pve",
		left = side(inf.me, fmt),
		right = side(inf.foe, fmt),
		vs = beats[4],
		arrow = arrow,
		count = counts,
		beats = beats,
	}
end

-- Contrôle de cohérence (tests, BattleIntro).
function IntroPlan.check(plan)
	if type(plan) ~= "table" or type(plan.beats) ~= "table" or not isNum(plan.duration) then
		return false, "plan invalide"
	end
	if plan.duration <= 0 or plan.duration > IntroPlan.MAX_DURATION then
		return false, "durée hors bornes"
	end
	for i = 1, #plan.beats do
		local b = plan.beats[i]
		if type(b) ~= "table" or not isNum(b.t) or not isNum(b.d) or b.t < 0 or b.d < 0 or b.t + b.d > plan.duration + 1e-9 then
			return false, "prise " .. i .. " hors de la durée"
		end
	end
	return true, ""
end

return IntroPlan

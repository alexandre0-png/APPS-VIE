-- ModuleScript : ReplicatedStorage/HatchPlan   (lot 10, B.3)
-- PLAN PUR des 10 animations d'éclosion (une par rareté) : aucune dépendance, aucun service Roblox, déterministe (mêmes entrées -> même plan), jamais d'erreur.
-- Remplace `CinematicKit.hatchPlan` pour le nouvel écran d'éclosion (HatchFx exécute le plan). Le plan est une liste de « prises » (beats) :
--   { t = début (s), d = durée (s), kind = "...", n = nombre d'objets d'effet créés (0 si aucun), color = "main"|"second"|"white"|"black"|"gold"|"red"|"rainbow", ... }
-- Types de prises : shake (l'œuf tremble), pop (l'œuf disparaît), burst (n éclats), rays (n rayons), ring (anneaux, mode "converge"|"expand"|"ground"|"rise"),
-- flash (plein écran), shakeScreen, text (glyphe ou libellé : couronne, « ??? »), banner (bandeau de rareté), zoom (champ de vision), tint (teinte / désaturation
-- de l'image 3D), black (écran noir), slot (mini machine à sous rareté/taille/mutation), crystals, frost, cracks, chains, runes, smoke, stars, wings, pillar, split.
-- Plan complet : { r, duration, skipAfter, noSkip, camera, reduced, sound = {key, fanfare}, revealAt, beats, counter = {t, d, steps, from, to} | nil, special, exceptional,
--   secretSound, objects (somme des n, <= 30), particles (objets hors bandeau/texte/ailes/pilier ; <= 50 % en version réduite), peakRate (objets/s au pic, <= 40), seed }.
-- DÉCISIONS : durée de r10 ramenée de 9,0 s (spec B.3) à 8,0 s (plafond demandé) ; chaque n est ensuite ajusté pour tenir 30 objets et 40 objets/s ;
-- la version réduite (mobile) divise chaque n de particule par deux (arrondi bas) donc <= 50 % ; bandeau, texte, ailes et pilier restent ; zoom retiré si la caméra ne doit pas bouger (œuf porté, poursuite).
-- Brancher : `local plan = HatchPlan.plan(slot.r, slot.o, { reduced = isMobile, firstTime = firstTimeForThisRarity, still = carryingEgg })` puis HatchFx.play(gui, plan, opts).
-- Pas de += ni de continue (lanceur lupa).
local HatchPlan = {}

HatchPlan.MAX_DURATION = 8
HatchPlan.MAX_OBJECTS = 30
HatchPlan.MAX_RATE = 40
HatchPlan.SKIP_AFTER = 1.5
HatchPlan.COUNTER_SECONDS = 0.8
HatchPlan.COUNTER_STEPS = 12
-- Durées par rareté (B.3 ; r10 plafonnée à 8 s).
HatchPlan.DURATIONS = { 1.2, 1.5, 2.0, 2.8, 4.0, 5.0, 6.0, 7.0, 6.5, 8.0 }
local EXCEPTIONAL_MIN = 100000
local SECRET_SOUND_MIN = 1000000
local SPECIAL_MIN = 10000

-- Prises qui ne sont pas des particules : toujours conservées telles quelles en version réduite (bandeau, texte, anneau unique, ailes, pilier, éclat plein écran).
local FIXED_KINDS = { banner = true, text = true, wings = true, pillar = true }

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Clé de son (reprend Config.hatchSoundKey du lot 9 : r1-2 hatch, r3 rare, r4 epic, r5-6 legendary, r7-10 hatchSecret ; fanfare dès r8).
function HatchPlan.soundKey(r)
	local rr = isNum(r) and math.floor(r) or 1
	local key = "hatch"
	if rr >= 7 then
		key = "hatchSecret"
	elseif rr >= 5 then
		key = "legendary"
	elseif rr == 4 then
		key = "epic"
	elseif rr == 3 then
		key = "rare"
	end
	return { key = key, fanfare = rr >= 8, divine = rr >= 10 }
end

local function beat(t, d, kind, n, extra)
	local b = { t = t, d = d, kind = kind, n = n or 0 }
	if extra then
		for k, v in pairs(extra) do
			b[k] = v
		end
	end
	return b
end

-- Nombre de runes du cercle runique pour r >= 5 (B.3) : min(12, 4 + (r-4) x 2).
function HatchPlan.runes(r)
	return math.min(12, 4 + (r - 4) * 2)
end

-- Séquences de base (version complète, avant ajustement des plafonds). rv = instant de la révélation.
local function build(r)
	local B = {}
	local rv
	if r == 1 then
		rv = 0.5
		B = {
			beat(0, 0.4, "shake", 0, { amp = 3 }),
			beat(0.4, 0.1, "pop", 0),
			beat(0.4, 0.15, "flash", 0, { color = "white", a = 0.7 }),
			beat(0.4, 0.5, "rays", 6, { color = "white", len = 120 }),
		}
	elseif r == 2 then
		rv = 0.55
		B = {
			beat(0, 0.5, "shake", 0, { amp = 4 }),
			beat(0.5, 0.1, "pop", 0),
			beat(0.5, 0.7, "burst", 12, { color = "main", glyph = "cube", dist = 150, arc = "crown" }),
			beat(0.7, 0.7, "burst", 6, { color = "second", glyph = "petal", dist = 110, arc = "fall" }),
		}
	elseif r == 3 then
		rv = 1.05
		B = {
			beat(0, 1.0, "ring", 1, { color = "main", mode = "converge", ease = "in" }),
			beat(0.2, 0.8, "shake", 0, { amp = 5, grow = true }),
			beat(1.0, 0.15, "flash", 0, { color = "main", a = 0.6 }),
			beat(1.0, 0.1, "pop", 0),
			beat(1.0, 0.8, "ring", 2, { color = "main", mode = "ground" }),
		}
	elseif r == 4 then
		rv = 2.1
		B = {
			beat(0, 0.8, "crystals", 6, { color = "main", from = "ground" }),
			beat(0.8, 0.25, "shakeScreen", 0, { amp = 6 }),
			beat(0.9, 1.2, "slot", 4, { color = "main" }),
			beat(2.0, 0.1, "pop", 0),
			beat(2.1, 0.7, "banner", 1, { color = "main" }),
		}
	elseif r == 5 then
		rv = 2.1
		B = {
			beat(0, 1.4, "text", 1, { glyph = "crown", color = "gold", fall = true }),
			beat(0.6, 1.4, "shake", 0, { amp = 6, grow = true }),
			beat(0.8, 1.2, "runes", HatchPlan.runes(5), { color = "gold" }),
			beat(1.4, 2.4, "zoom", 0, { k = 1.15 }),
			beat(2.0, 0.2, "flash", 0, { color = "gold", a = 0.8 }),
			beat(2.0, 0.1, "pop", 0),
			beat(2.0, 0.5, "split", 2, { color = "gold" }),
			beat(2.0, 1.0, "rays", 12, { color = "gold", len = 220 }),
			beat(2.2, 1.8, "banner", 1, { color = "gold" }),
		}
	elseif r == 6 then
		rv = 2.6
		B = {
			beat(0.3, 2.1, "chains", 6, { color = "second", breakAt = 2.1 }),
			beat(0.4, 1.6, "cracks", 4, { color = "red" }),
			beat(0.5, 1.8, "shake", 0, { amp = 8, grow = true }),
			beat(2.0, 0.6, "tint", 0, { color = "red", a = 0.5 }),
			beat(2.4, 0.6, "shakeScreen", 0, { amp = 10 }),
			beat(2.4, 0.1, "pop", 0),
			beat(2.4, 1.0, "runes", HatchPlan.runes(6), { color = "red" }),
			beat(2.7, 2.0, "banner", 1, { color = "red" }),
		}
	elseif r == 7 then
		rv = 3.2
		B = {
			beat(0, 1.5, "crystals", 6, { color = "main", from = "around" }),
			beat(0.8, 1.6, "frost", 3, { color = "white" }),
			beat(1.5, 1.4, "shake", 0, { amp = 7, grow = true }),
			beat(3.0, 0.15, "flash", 0, { color = "main", a = 0.8 }),
			beat(3.0, 0.1, "pop", 0),
			beat(3.0, 0.8, "burst", 8, { color = "main", glyph = "shard", dist = 190, arc = "ball" }),
			beat(3.0, 1.5, "runes", HatchPlan.runes(7), { color = "main" }),
			beat(3.3, 2.4, "banner", 1, { color = "main" }),
		}
	elseif r == 8 then
		rv = 2.9
		B = {
			beat(0, 2.5, "black", 0, { a = 1, fadeOut = true }),
			beat(0.5, 2.0, "text", 1, { glyph = "???", color = "white" }),
			beat(2.5, 0.9, "ring", 1, { color = "rainbow", mode = "expand" }),
			beat(2.8, 0.9, "ring", 1, { color = "rainbow", mode = "expand" }),
			beat(2.5, 1.0, "stars", 8, { color = "rainbow" }),
			beat(2.5, 0.15, "flash", 0, { color = "white", a = 0.9 }),
			beat(2.5, 0.1, "pop", 0),
			beat(2.6, 1.2, "runes", HatchPlan.runes(8), { color = "rainbow" }),
			beat(3.0, 3.2, "banner", 1, { color = "rainbow" }),
		}
	elseif r == 9 then
		rv = 2.8
		B = {
			beat(0, 0.8, "tint", 0, { sat = -1, hold = true, a = 0 }),
			beat(0.5, 2.0, "text", 1, { glyph = "crown", color = "black" }),
			beat(2.5, 0.8, "burst", 6, { color = "black", glyph = "shard", dist = 160, arc = "ball" }),
			beat(2.5, 2.0, "smoke", 5, { color = "second" }),
			beat(2.5, 0.4, "shakeScreen", 0, { amp = 8 }),
			beat(2.5, 0.1, "pop", 0),
			beat(2.6, 1.2, "runes", HatchPlan.runes(9), { color = "white" }),
			beat(2.9, 2.2, "banner", 1, { color = "white" }),
		}
	else
		rv = 3.3
		B = {
			beat(0, 1.8, "wings", 2, { color = "main" }),
			beat(1.0, 1.5, "ring", 1, { color = "gold", mode = "rise" }),
			beat(1.4, 6.0, "pillar", 1, { color = "main" }),
			beat(2.4, 3.0, "zoom", 0, { k = 1.1 }),
			beat(3.0, 0.2, "flash", 0, { color = "white", a = 0.9 }),
			beat(3.0, 0.1, "pop", 0),
			beat(3.0, 2.0, "rays", 16, { color = "main", len = 260 }),
			beat(3.0, 2.0, "runes", HatchPlan.runes(10), { color = "gold" }),
			beat(3.4, 4.0, "banner", 1, { color = "main" }),
		}
	end
	return B, rv
end

-- Somme des objets et pic de débit (objets/s, estimé sur une grille de 0,05 s) d'une liste de prises.
local function measure(beats, duration)
	local total = 0
	for i = 1, #beats do
		total = total + beats[i].n
	end
	local peak = 0
	local t = 0
	while t <= duration do
		local rate = 0
		for i = 1, #beats do
			local b = beats[i]
			if b.n > 0 and t >= b.t and t < b.t + math.max(b.d, 0.4) then
				rate = rate + b.n / math.max(b.d, 0.4)
			end
		end
		if rate > peak then
			peak = rate
		end
		t = t + 0.05
	end
	return total, peak
end

-- Réduit les plus gros n (un cran à la fois, ordre stable) jusqu'à respecter les plafonds d'objets et de débit. Les prises à 1 objet ne sont jamais supprimées.
local function fit(beats, duration, maxObjects)
	local guard = 0
	while guard < 400 do
		guard = guard + 1
		local total, peak = measure(beats, duration)
		if total <= maxObjects and peak <= HatchPlan.MAX_RATE then
			return
		end
		local bestI, bestN = nil, 1
		for i = 1, #beats do
			if beats[i].n > bestN and not FIXED_KINDS[beats[i].kind] then
				bestI, bestN = i, beats[i].n
			end
		end
		if bestI == nil then
			return
		end
		beats[bestI].n = beats[bestI].n - math.max(1, math.floor(bestN * 0.15))
	end
end

-- Plan d'éclosion. r : rareté (1..10, borné), N : compteur « 1 sur N » (nombre, sinon ignoré).
-- opts : reduced (version mobile), firstTime (première fois qu'une rareté >= 8 est obtenue : non passable), still (la caméra ne bouge pas).
function HatchPlan.plan(r, N, opts)
	local o = type(opts) == "table" and opts or {}
	local rr = 1
	if isNum(r) then
		rr = math.max(1, math.min(10, math.floor(r)))
	end
	local duration = HatchPlan.DURATIONS[rr]
	local beats, revealAt = build(rr)
	if o.still == true then
		local kept = {}
		for i = 1, #beats do
			if beats[i].kind ~= "zoom" then
				kept[#kept + 1] = beats[i]
			end
		end
		beats = kept
	end
	local num = nil
	if isNum(N) and N >= 1 then
		num = math.min(N, 9007199254740992)
	end
	local exceptional = num ~= nil and num >= EXCEPTIONAL_MIN
	if exceptional then
		beats[#beats + 1] = beat(revealAt + 0.2, math.min(1.6, duration - revealAt - 0.2), "text", 1, { glyph = "exceptional", color = "gold", y = "low" })
	end
	-- plafonds d'objets et de débit sur la version complète, puis réduction mobile (moitié, arrondi bas)
	fit(beats, duration, HatchPlan.MAX_OBJECTS)
	local reduced = o.reduced == true
	if reduced then
		for i = 1, #beats do
			if not FIXED_KINDS[beats[i].kind] then
				beats[i].n = math.floor(beats[i].n / 2)
			end
		end
	end
	table.sort(beats, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return a.kind < b.kind
	end)
	local objects, peak = measure(beats, duration)
	local particles = 0
	for i = 1, #beats do
		if not FIXED_KINDS[beats[i].kind] then
			particles = particles + beats[i].n
		end
	end
	local counter = nil
	if num ~= nil then
		local cd = math.min(HatchPlan.COUNTER_SECONDS, duration - revealAt)
		counter = { t = revealAt, d = math.max(0.25, cd), steps = HatchPlan.COUNTER_STEPS, from = 1, to = num }
	end
	return {
		r = rr,
		duration = duration,
		skipAfter = HatchPlan.SKIP_AFTER,
		noSkip = o.firstTime == true and rr >= 8,
		camera = o.still ~= true,
		reduced = reduced,
		sound = HatchPlan.soundKey(rr),
		revealAt = revealAt,
		beats = beats,
		counter = counter,
		special = num ~= nil and num >= SPECIAL_MIN,
		exceptional = exceptional,
		secretSound = num ~= nil and num >= SECRET_SOUND_MIN,
		objects = objects,
		particles = particles,
		peakRate = peak,
		seed = (rr * 7919 + (num and math.floor(num) % 100003 or 0)) % 2147483647,
	}
end

-- Contrôle de cohérence d'un plan (utilisé par les tests et par HatchFx avant exécution) : retourne ok, raison.
function HatchPlan.check(plan)
	if type(plan) ~= "table" or type(plan.beats) ~= "table" or not isNum(plan.duration) then
		return false, "plan invalide"
	end
	if plan.duration <= 0 or plan.duration > HatchPlan.MAX_DURATION then
		return false, "durée hors bornes"
	end
	for i = 1, #plan.beats do
		local b = plan.beats[i]
		if type(b) ~= "table" or type(b.kind) ~= "string" or not isNum(b.t) or not isNum(b.d) or not isNum(b.n) then
			return false, "prise " .. i .. " invalide"
		end
		if b.t < 0 or b.d < 0 or b.t + b.d > plan.duration + 1e-9 or b.n < 0 then
			return false, "prise " .. i .. " hors de la durée"
		end
	end
	return true, ""
end

return HatchPlan

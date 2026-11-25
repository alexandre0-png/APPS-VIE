-- ModuleScript : ReplicatedStorage/Shared/Riddle
-- REFONTE lot 6 : énigme de la Mère Poule en 3 étapes GUIDÉES (plumes, runes, berceuse). Module PUR : aucune dépendance à Roblox, testé avec Lune/lupa.
-- Le serveur tient l'état (profil `puzzle`), le client ne fait qu'afficher ; ce module décide de tout ce qui est « règle » :
--   plumes du jour, berceuse du jour, transitions d'étape (refusées si invalides), indices, compte à rebours, répliques, guidage, effet collectif.
--
-- Générateur : Config.dayRng (le MÊME Park-Miller déterministe que Config.riddleFor) avec un « sel » par usage, pour que les plumes, la berceuse et
-- les runes d'un même jour ne soient pas corrélées : plumes = dayRng(jour + 5003), berceuse = dayRng(jour + 9007), runes = dayRng(jour) (Config.riddleFor).
-- Même jour = mêmes plumes, mêmes runes, même berceuse pour tous les joueurs.
--
-- Étapes : 0 non commencée · 1 plumes · 2 runes · 3 berceuse · 4 faite (= puzzle.day == jour). Le profil ne stocke que 0..3 (+ puzzle.pday, le jour de la
-- progression : un autre jour = remise à zéro) ; « 4 » se déduit de puzzle.day.
local Riddle = {}

Riddle.STEP = { idle = 0, feathers = 1, runes = 2, lullaby = 3, done = 4 }
Riddle.DIRS = { "N", "E", "S", "O" } -- ordre de Config.RUNE_DIRECTIONS et de Config.Map2.runeStones
Riddle.DIR_OF = { "du Nord", "de l'Est", "du Sud", "de l'Ouest" } -- « La plume du Nord », « la rune de l'Est »
local FEATHER_SALT, LULLABY_SALT = 5003, 9007
local BIT = { 1, 2, 4, 8 } -- masque des plumes : Nord 1, Est 2, Sud 4, Ouest 8

local function validDir(dir)
	return type(dir) == "number" and dir == dir and dir % 1 == 0 and dir >= 1 and dir <= 4
end

-- Profil `puzzle` neuf (même forme que Data.default().puzzle).
function Riddle.fresh()
	return { day = 0, solved = 0, step = 0, feathers = 0, hints = 0, fragments = 0, pday = 0, met = false }
end

---------------------------------------------------------------- Plumes et berceuse du jour
-- Une plume par direction (N, E, S, O) parmi les 3 emplacements de Config.FEATHER_SPOTS : { { dir, key, index, x, z, where } x4 }.
function Riddle.featherSpots(Config, day)
	local r = Config.dayRng(day + FEATHER_SALT)
	local out = {}
	for dir = 1, 4 do
		local list = Config.FEATHER_SPOTS[Riddle.DIRS[dir]]
		local idx = r(#list)
		local sp = list[idx]
		out[dir] = { dir = dir, key = Riddle.DIRS[dir], index = idx, x = sp.x, z = sp.z, where = sp.where, dock = sp.dock == true }
	end
	return out
end

-- Berceuse du jour : Config.HEN.lullabyLength pierres (numéros 1..4 = Nord, Est, Sud, Ouest), chaque pierre présente au moins une fois
-- (les 4 pierres d'abord, puis des pierres tirées, le tout mélangé).
function Riddle.lullaby(Config, day)
	local r = Config.dayRng(day + LULLABY_SALT)
	local n = math.max(4, Config.HEN.lullabyLength)
	local seq = { 1, 2, 3, 4 }
	for i = 5, n do
		seq[i] = r(4)
	end
	for i = n, 2, -1 do
		local j = r(i)
		seq[i], seq[j] = seq[j], seq[i]
	end
	return seq
end

-- Durée totale d'une écoute de la berceuse (secondes) : chaque pierre brille `lullabyNote` s, puis `lullabyGap` s de silence.
function Riddle.lullabyDuration(Config)
	return Config.HEN.lullabyLength * (Config.HEN.lullabyNote + Config.HEN.lullabyGap)
end

-- Début (en secondes depuis le début de l'écoute) de la note i.
function Riddle.noteStart(Config, i)
	return (i - 1) * (Config.HEN.lullabyNote + Config.HEN.lullabyGap)
end

---------------------------------------------------------------- État et transitions (toutes pures : elles modifient p et disent si c'était permis)
function Riddle.available(chaptersDone)
	return type(chaptersDone) == "number" and chaptersDone >= 2 -- chapitre 2 réussi
end

function Riddle.featherCount(mask)
	local n = 0
	for dir = 1, 4 do
		if math.floor(mask / BIT[dir]) % 2 == 1 then
			n = n + 1
		end
	end
	return n
end

function Riddle.hasFeather(mask, dir)
	return validDir(dir) and type(mask) == "number" and math.floor(mask / BIT[dir]) % 2 == 1
end

-- Un autre jour que celui de la progression : remise à zéro (étape, plumes, indices ; fragments et résolutions sont conservés).
-- Retourne true si une remise à zéro a eu lieu, puis true si une progression a été perdue.
function Riddle.normalize(p, day)
	if p.pday ~= day then
		local lost = p.step ~= 0 or p.feathers ~= 0 or p.hints ~= 0
		p.pday, p.step, p.feathers, p.hints = day, 0, 0, 0
		return true, lost
	end
	return false, false
end

-- Étape effective : 4 si résolue ce jour, sinon l'étape sauvegardée (0..3).
function Riddle.stepOf(p, day)
	if p.day == day then
		return 4
	end
	return p.step
end

-- 0 -> 1 : le joueur accepte d'aider la Mère Poule. Refusée si indisponible (chapitre 2), déjà faite ou déjà commencée.
function Riddle.start(p, day, avail)
	if not avail then
		return false, "locked"
	end
	Riddle.normalize(p, day)
	if p.day == day then
		return false, "done"
	end
	if p.step ~= 0 then
		return false, "started"
	end
	p.step = 1
	return true
end

-- Ramassage d'une plume (étape 1 seulement). Retourne ok, nombre de plumes (ou ok=false, raison).
function Riddle.collect(p, day, dir)
	Riddle.normalize(p, day)
	if p.day == day then
		return false, "done"
	end
	if p.step ~= 1 then
		return false, "step"
	end
	if not validDir(dir) then
		return false, "dir"
	end
	if Riddle.hasFeather(p.feathers, dir) then
		return false, "have"
	end
	p.feathers = p.feathers + BIT[dir]
	return true, Riddle.featherCount(p.feathers)
end

-- 1 -> 2 : IMPOSSIBLE sans les 4 plumes.
function Riddle.toRunes(p, day)
	Riddle.normalize(p, day)
	if p.day == day then
		return false, "done"
	end
	if p.step ~= 1 then
		return false, "step"
	end
	if Riddle.featherCount(p.feathers) ~= 4 then
		return false, "feathers"
	end
	p.step = 2
	return true
end

-- Une rune ne se tourne qu'une fois la plume de sa direction ramassée, et seulement pendant les étapes 1 et 2.
function Riddle.runeUnlocked(p, day, dir)
	if p.day == day or p.pday ~= day then
		return false
	end
	return (p.step == 1 or p.step == 2) and Riddle.hasFeather(p.feathers, dir)
end

-- Nombre de runes justes (jamais lesquelles). runes et answer : 4 symboles.
function Riddle.runesCorrect(runes, answer)
	local k = 0
	for i = 1, 4 do
		if runes[i] ~= nil and runes[i] == answer[i] then
			k = k + 1
		end
	end
	return k
end

-- 2 -> 3 : seulement si les 4 runes sont justes (`correct` = résultat de runesCorrect).
function Riddle.toLullaby(p, day, correct)
	Riddle.normalize(p, day)
	if p.day == day then
		return false, "done"
	end
	if p.step ~= 2 then
		return false, "step"
	end
	if correct ~= 4 then
		return false, "runes"
	end
	p.step = 3
	return true
end

-- Touche d'une pierre pendant la berceuse : seq = suite attendue, pos = position attendue (1..#seq), stone = pierre touchée (1..4).
-- Retourne "ok" (bonne pierre, pos avance), "done" (dernière pierre juste) ou "wrong" (erreur : pos revient à 1, la suite est rejouée).
function Riddle.tap(seq, pos, stone)
	if seq[pos] ~= nil and stone == seq[pos] then
		if pos >= #seq then
			return "done", 1
		end
		return "ok", pos + 1
	end
	return "wrong", 1
end

function Riddle.tapAllowed(Config, now, lastTap)
	return type(now) == "number" and type(lastTap) == "number" and now - lastTap >= Config.HEN.tapMinGap
end

function Riddle.pickupAllowed(Config, dist, now, lastPick)
	return type(dist) == "number" and dist == dist and dist <= Config.HEN.pickupDistance and type(now) == "number" and type(lastPick) == "number" and now - lastPick >= Config.HEN.pickupGap
end

-- 3 -> 4 : récompense UNE fois par jour. Retourne ok puis { eggTier, coinsMins, fragments, legendary, titleNew } ; fragments cumulés,
-- 1 œuf Légendaire à chaque tranche de Config.HEN.fragmentsForEgg (7) atteinte, titre « Ami de la Mère Poule » dès 7.
function Riddle.complete(Config, p, day, lullabyDone)
	Riddle.normalize(p, day)
	if p.day == day then
		return false, "done"
	end
	if p.step ~= 3 then
		return false, "step"
	end
	if lullabyDone ~= true then
		return false, "lullaby"
	end
	local before = p.fragments
	local after = before + 1
	local per = Config.HEN.fragmentsForEgg
	local legendary = math.floor(after / per) - math.floor(before / per)
	p.day = day
	p.solved = p.solved + 1
	p.step, p.feathers = 0, 0
	p.fragments = after
	return true, { eggTier = Config.PUZZLE_EGG_TIER, mins = Config.PUZZLE_MINS, fragments = after, legendary = legendary, titleNew = before < per and after >= per }
end

function Riddle.hasTitle(Config, fragments)
	return type(fragments) == "number" and fragments >= Config.HEN.fragmentsForEgg
end

---------------------------------------------------------------- Indices (« 💡 Un coup de bec »)
-- 2 par jour, jamais payants. Le 1er : gratuit après hintAfterSeconds dans l'étape courante. Le 2e : après failsForHint validations ratées à l'étape 2.
-- Retourne ok ; sinon false, raison ("step" | "max" | "wait" | "fails"), et le temps (s) ou le nombre de validations ratées restantes.
function Riddle.hintStatus(Config, p, day, secondsInStep, fails)
	local H = Config.HEN
	local step = Riddle.stepOf(p, day)
	if step < 1 or step > 3 then
		return false, "step"
	end
	if p.hints >= H.hintsPerDay then
		return false, "max"
	end
	if p.hints == 0 then
		if secondsInStep >= H.hintAfterSeconds then
			return true
		end
		return false, "wait", math.ceil(H.hintAfterSeconds - secondsInStep)
	end
	if step == 2 and fails >= H.failsForHint then
		return true
	end
	return false, "fails", step == 2 and (H.failsForHint - fails) or nil
end

-- Contenu de l'indice : identifiant de réplique et paramètres. runes = symboles actuels du joueur (4 numéros).
function Riddle.hintFor(Config, p, day, runes)
	local step = Riddle.stepOf(p, day)
	if step == 1 then
		local spots = Riddle.featherSpots(Config, day)
		for dir = 1, 4 do
			if not Riddle.hasFeather(p.feathers, dir) then
				return "hintFeather", { dir = Riddle.DIR_OF[dir], where = spots[dir].where }
			end
		end
	elseif step == 2 then
		local answer = Config.riddleFor(day).answer
		for dir = 1, 4 do
			if runes[dir] ~= answer[dir] then
				return "hintRune", { dir = Riddle.DIR_OF[dir], symbol = Config.RUNES[answer[dir]] }
			end
		end
	elseif step == 3 then
		return "hintLullaby", { dir = Riddle.DIR_OF[Riddle.lullaby(Config, day)[1]] }
	end
	return nil
end

---------------------------------------------------------------- Compte à rebours
-- « Nouvelle berceuse dans h mm » : heures, minutes (arrondies au-dessus), secondes restantes avant 00:00 UTC.
function Riddle.untilNext(now)
	local left = 86400 - (now % 86400)
	local total = math.ceil(left / 60)
	return math.floor(total / 60), total % 60, left
end

---------------------------------------------------------------- Répliques
function Riddle.format(tpl, params)
	return (tpl:gsub("{(%w+)}", function(k)
		local v = params and params[k]
		if v == nil then
			return "{" .. k .. "}"
		end
		return tostring(v)
	end))
end

-- « du Nord, de l'Est et de l'Ouest » d'après le masque de plumes (les directions MANQUANTES).
function Riddle.missingDirs(mask)
	local list = {}
	for dir = 1, 4 do
		if not Riddle.hasFeather(mask, dir) then
			list[#list + 1] = Riddle.DIR_OF[dir]
		end
	end
	if #list <= 1 then
		return list[1] or ""
	end
	return table.concat(list, ", ", 1, #list - 1) .. " et " .. list[#list]
end

-- Paramètres de la réplique « missing » d'après le masque.
function Riddle.missingParams(mask)
	return { n = 4 - Riddle.featherCount(mask), dirs = Riddle.missingDirs(mask) }
end

-- Réplique « {h} h {mm} ».
function Riddle.doneParams(now)
	local h, m = Riddle.untilNext(now)
	return { h = h, mm = string.format("%02d", m) }
end

-- Texte d'une réplique (id de Config.HEN_LINES) : { id, pages = { texte, ... }, buttons = { { id, text }, ... } }.
-- step = étape du joueur : ajoute « 💡 Un coup de bec » (étapes 1 à 3) et « 🔁 Réécouter » (étape 3) aux répliques de suivi.
function Riddle.say(Config, id, params, step)
	local L = Config.HEN_LINES
	local B = L.buttons
	local pages, ids = nil, {}
	if id == "first" then
		pages, ids = L.first, { "go", "again" }
	elseif id == "explain" or id == "again" then
		pages, ids = { L[id] }, { "go", "later" }
	elseif id == "success" or id == "done" or id == "locked" or id == "feather" then
		pages = { L[id] }
	elseif L[id] ~= nil and type(L[id]) == "string" then
		pages = { L[id] }
		if step == 1 or step == 2 or step == 3 then
			ids[#ids + 1] = "hint"
		end
		if step == 3 then
			ids[#ids + 1] = "replay"
		end
	else
		return { id = id, pages = {}, buttons = {} }
	end
	local out = {}
	for i, p in ipairs(pages) do
		out[i] = Riddle.format(p, params)
	end
	local buttons = {}
	for _, b in ipairs(ids) do
		buttons[#buttons + 1] = { id = b, text = B[b] }
	end
	return { id = id, pages = out, buttons = buttons }
end

-- Texte d'une plume ramassée : « 🪶 Plume du Nord : « ce qui coule et berce » ».
function Riddle.featherLine(Config, day, dir)
	local clue = Config.riddleFor(day).clues[dir]
	return Riddle.format(Config.HEN_LINES.feather, { dir = Riddle.DIR_OF[dir], clue = clue }), clue
end

---------------------------------------------------------------- Guidage (faisceau, mini-carte)
-- Centre du quart de carte (quadrant Nord-Ouest, Nord-Est, Sud-Ouest, Sud-Est de Config.Map2.bounds) qui contient (x, z).
function Riddle.quarter(Config, x, z)
	local b = Config.Map2.bounds
	return (x < 0 and b.x0 or b.x1) / 2, (z < 0 and b.z0 or b.z1) / 2
end

local function dist2d(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Cible du faisceau jaune d'après l'état `hen` envoyé par le serveur (avail, step, spots = plumes NON ramassées { dir, x, z }) et la position du joueur.
-- { kind = "hen" | "quarter" | "feather" | "runes", x, z, dir, near } ou nil. Étape 0 : la Mère Poule. Étape 1 : le centre du quart de carte de la plume la
-- plus proche tant qu'on en est loin (> quarterReach du centre), puis la plume elle-même ; `near` = à moins de sparkleDistance (la plume scintille).
-- Étapes 2 et 3 : le Grand Œuf (les 4 runes l'entourent).
function Riddle.guide(Config, hen, px, pz)
	if type(hen) ~= "table" or hen.avail ~= true or type(hen.step) ~= "number" or hen.step >= 4 then
		return nil
	end
	local H = Config.HEN
	if hen.step == 0 then
		return { kind = "hen", x = Config.Map2.hen.x, z = Config.Map2.hen.z }
	elseif hen.step >= 2 then
		return { kind = "runes", x = Config.Map2.bigEgg.x, z = Config.Map2.bigEgg.z }
	end
	local best, bd = nil, math.huge
	for _, sp in ipairs(hen.spots or {}) do
		if type(sp.x) == "number" and type(sp.z) == "number" then
			local d = dist2d(px, pz, sp.x, sp.z)
			if d < bd then
				best, bd = sp, d
			end
		end
	end
	if not best then
		return { kind = "hen", x = Config.Map2.hen.x, z = Config.Map2.hen.z }
	end
	if bd <= H.sparkleDistance then
		return { kind = "feather", x = best.x, z = best.z, dir = best.dir, near = true }
	end
	local qx, qz = Riddle.quarter(Config, best.x, best.z)
	if dist2d(px, pz, qx, qz) > H.quarterReach then
		return { kind = "quarter", x = qx, z = qz, dir = best.dir }
	end
	return { kind = "feather", x = best.x, z = best.z, dir = best.dir, near = false }
end

---------------------------------------------------------------- Effet collectif (Pluie de chance)
-- c = { day, count, fired } propre au serveur. Retourne true quand l'événement doit démarrer MAINTENANT (une fois par jour et par serveur).
function Riddle.collectiveAdd(Config, c, day)
	if c.day ~= day then
		c.day, c.count, c.fired = day, 0, false
	end
	c.count = c.count + 1
	if not c.fired and c.count >= Config.HEN.collectiveSolves then
		c.fired = true
		return true
	end
	return false
end

return Riddle

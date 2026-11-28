-- ModuleScript : ReplicatedStorage/Shared/Battle   (LOT 12 partie A : moteur refait, D.1 à D.4 et D.6 de LOTS_9_PLUS.md)
-- Moteur de combat PUR (aucun service Roblox) de l'Arène des pets : équipes de 3 pets, tour par tour, résolution DÉTERMINISTE d'après une graine.
-- Le serveur est la seule autorité : le client n'envoie qu'une intention (attaque, spécial, changer de pet) et rejoue les événements reçus.
-- Types (9) : 3 triangles primaires (BEATS, x1,5 / x0,67) : Feu > Nature > Eau > Feu, Lumière > Ombre > Ciel > Lumière, Terre > Foudre > Glace > Terre ;
-- relations secondaires (BEATS2, x1,25 / x0,8), une sortante et une entrante par type. La clé `Nature` est conservée (affichée « Plante » : Battle.TYPE_LABEL).
-- Spécial : CHARGE u.charge 0..5 ; chaque attaque +1 (+1 de plus si le coup est x1,25 ou mieux) ; le spécial exige 5 et consomme 5.
-- Aucune dépendance Roblox ; pas de `+=` ni de `continue` (lanceur lupa).
local Battle = {}

Battle.TYPES = { "Feu", "Eau", "Nature", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }
Battle.TYPE_EMOJI = { Feu = "🔥", Eau = "💧", Nature = "🌿", Glace = "❄️", Foudre = "⚡", Terre = "⛰️", Ciel = "🌪️", Ombre = "🌑", ["Lumière"] = "✨" }
Battle.TYPE_LABEL = { Feu = "Feu", Eau = "Eau", Nature = "Plante", Glace = "Glace", Foudre = "Foudre", Terre = "Terre", Ciel = "Ciel", Ombre = "Ombre", ["Lumière"] = "Lumière" }
-- Nom du spécial par type (D.3) : l'EFFET vient de la compétence de l'espèce (Battle.SKILLS), le NOM du type de l'attaquant.
Battle.SPECIAL_NAME = {
	Feu = "Souffle ardent", Eau = "Raz-de-marée", Nature = "Fouet de lianes", Glace = "Blizzard", Foudre = "Arc électrique",
	Terre = "Séisme", Ciel = "Tempête", Ombre = "Voile des ténèbres", ["Lumière"] = "Rayon sacré",
}
Battle.BEATS = { Feu = "Nature", Nature = "Eau", Eau = "Feu", ["Lumière"] = "Ombre", Ombre = "Ciel", Ciel = "Lumière", Terre = "Foudre", Foudre = "Glace", Glace = "Terre" }
Battle.BEATS2 = { Feu = "Glace", Glace = "Ciel", Ciel = "Terre", Terre = "Feu", Foudre = "Eau", Eau = "Ombre", Ombre = "Nature", Nature = "Lumière", ["Lumière"] = "Foudre" }
Battle.STRONG, Battle.WEAK = 1.5, 0.67
Battle.STRONG2, Battle.WEAK2 = 1.25, 0.8
Battle.MAX_TURNS = 40
Battle.CHARGE_MAX = 5 -- charge nécessaire au spécial
Battle.CHARGE_BONUS_MUL = 1.25 -- un coup de cette efficacité ou mieux donne +1 de charge en plus
-- Multiplicateur global de dégâts (les deux camps : ne change aucun rapport de force). Les STATS de D.4 étant imposées (6 à 7 coups pour mettre un pet à terre),
-- il ramène la durée moyenne d'un combat 3 contre 3 à 8-14 tours (cible du lot 12, mesurée par tests/lot12a.luau) ; à 1 : ~18 tours.
Battle.DAMAGE_MUL = 1.6

-- Type de chacune des 18 espèces (ordre de Config.PETS) ; le lot 11 (bestiaire) prolonge ces deux tables (une entrée par espèce, `Nature` pour Plante).
Battle.SPECIES_TYPE = { "Ciel", "Ombre", "Lumière", "Eau", "Nature", "Feu", "Lumière", "Ombre", "Ciel", "Feu", "Nature", "Eau", "Ciel", "Ombre", "Lumière", "Nature", "Eau", "Feu" }
-- Spécial de chaque espèce (clé de Battle.SKILLS).
Battle.SPECIES_SKILL = { "focus", "heal", "guard", "stun", "strike", "drain", "heal", "stun", "guard", "drain", "strike", "heal", "strike", "focus", "stun", "drain", "heal", "guard" }
-- Spécial « signature » des trois nouveaux types (pour les espèces du lot 11 qui n'en choisissent pas un autre).
Battle.TYPE_SKILL = { Glace = "freeze", Foudre = "chain", Terre = "bulwark" }
Battle.SKILLS = {
	strike = { name = "Coup puissant", mul = 2.5 },
	drain = { name = "Morsure vampire", mul = 1.6, leech = 0.4 }, -- soigne 40 % des dégâts
	heal = { name = "Soin", heal = 0.35 }, -- 35 % des pv max, retire l'étourdissement
	guard = { name = "Garde", keep = 0.3, hits = 2 }, -- les 2 prochains coups reçus ne font que 30 %
	stun = { name = "Étourdissement", mul = 1.2 }, -- l'ennemi passe 1 tour
	focus = { name = "Concentration", mul = 1.4, boost = 1.4, turns = 3 }, -- puis attaque +40 % pendant 3 tours
	freeze = { name = "Gel", mul = 1.5, drain = 2 }, -- l'ennemi perd 2 de charge
	chain = { name = "Chaîne d'éclairs", mul = 1.6, splash = 0.35 }, -- 35 % des dégâts sur le pet suivant en réserve
	bulwark = { name = "Rempart", mul = 1.3, keep = 0.5, hits = 1 }, -- puis le prochain coup reçu ne fait que 50 %
}

-- Multiplicateur d'efficacité du type `atk` contre le type `def` : 1,5 / 0,67 (primaire), 1,25 / 0,8 (secondaire), sinon 1.
function Battle.typeMul(atk, def)
	if Battle.BEATS[atk] == def then
		return Battle.STRONG
	elseif Battle.BEATS[def] == atk then
		return Battle.WEAK
	elseif Battle.BEATS2[atk] == def then
		return Battle.STRONG2
	elseif Battle.BEATS2[def] == atk then
		return Battle.WEAK2
	end
	return 1
end

-- Nom affiché du spécial d'une unité : nom propre au type de l'attaquant (D.3), à défaut celui de la compétence.
function Battle.specialName(unitOrType, skill)
	local ty = type(unitOrType) == "table" and unitOrType.type or unitOrType
	local sk = skill or (type(unitOrType) == "table" and unitOrType.skill)
	return Battle.SPECIAL_NAME[ty] or (Battle.SKILLS[sk] and Battle.SKILLS[sk].name) or "Spécial"
end

-- Générateur déterministe de qualité (Park-Miller « MINSTD » révisé : multiplicateur 48271, modulo 2^31 - 1). Le produit reste < 2^47, donc EXACT en
-- double précision (un LCG 1103515245 dépasserait 2^53 et perdrait des bits). État = entier 1..2^31-2, retourne (valeur 0..1 exclu, nouvel état).
Battle.RNG_MUL, Battle.RNG_MOD = 48271, 2147483647
local function nextRnd(state)
	state = (state * 48271) % 2147483647
	return state / 2147483647, state
end
Battle.nextRnd = nextRnd

-- Graine -> état initial valide (1..2^31-2) puis 4 tirages d'échauffement (des graines voisines ne donnent pas des premiers tirages voisins).
function Battle.seedState(seed)
	local n = tonumber(seed) or 1
	if n ~= n or n == math.huge or n == -math.huge then
		n = 1
	end
	local s = (math.floor(n) % 2147483646) + 1
	for _ = 1, 4 do
		local _v
		_v, s = nextRnd(s)
	end
	return s
end

local SIZE_BONUS = { 0.95, 1, 1.05, 1.10, 1.15 }
local MUT_BONUS = { 1, 1.03, 1.05, 1.08, 1.10, 1.12 }
Battle.SIZE_BONUS, Battle.MUT_BONUS = SIZE_BONUS, MUT_BONUS

-- LOT 9, REGLE DE DESIGN (2) : stats de base par rareté (1..10). Puissance = pv + 3 x attaque + 2 x vitesse (Battle.power), strictement croissante,
-- facteur >= 1,25 entre raretés consécutives (testé). Raretés 3 à 7 (Rare .. Ultra Rare) = valeurs EXACTES de l'ancienne formule pour les anciennes
-- raretés 2 à 6 (un pet migré garde ses stats) ; le Commun passe de 60/10/12 à 50/8/12 pour laisser la place au Peu commun (règle x1,25).
Battle.STATS = {
	{ hp = 50, atk = 8, spd = 12 },
	{ hp = 68, atk = 11, spd = 12 },
	{ hp = 87, atk = 14, spd = 14 },
	{ hp = 126, atk = 20, spd = 16 },
	{ hp = 183, atk = 27, spd = 18 },
	{ hp = 265, atk = 38, spd = 20 },
	{ hp = 385, atk = 54, spd = 22 },
	{ hp = 490, atk = 68, spd = 24 },
	{ hp = 620, atk = 86, spd = 26 },
	{ hp = 785, atk = 108, spd = 28 },
}
Battle.POWER_GROWTH_MIN = 1.25
function Battle.power(st)
	return st.hp + 3 * st.atk + 2 * st.spd
end
-- Profils de combat au sein d'une rareté (lot 12 : attribués par espèce). `k` = répartition pv / attaque / vitesse, `power` = puissance visée
-- relative à l'équilibré : l'écart entre le profil le plus faible et le plus fort d'une rareté est de 8 à 15 % (1,06 / 0,94 = +12,8 %), et le
-- plus fort d'une rareté reste sous le plus faible de la suivante (testé). Rien d'achetable ne modifie ces tables.
Battle.PROFILES = {
	balanced = { k = { hp = 1, atk = 1, spd = 1 }, power = 1 },
	tank = { k = { hp = 1.3, atk = 0.85, spd = 0.85 }, power = 1.05 },
	attacker = { k = { hp = 0.85, atk = 1.3, spd = 1 }, power = 1.06 },
	fast = { k = { hp = 0.85, atk = 0.95, spd = 1.35 }, power = 0.94 },
}
function Battle.profileStats(r, profile)
	local b = Battle.STATS[r]
	local pr = Battle.PROFILES[profile] or Battle.PROFILES.balanced
	local raw = { hp = b.hp * pr.k.hp, atk = b.atk * pr.k.atk, spd = b.spd * pr.k.spd }
	local f = pr.power * Battle.power(b) / Battle.power(raw)
	return { hp = raw.hp * f, atk = raw.atk * f, spd = raw.spd * f }
end

-- ---------------------------------------------------------------- Niveaux de pets (D.6)
-- XP pour passer du niveau L au suivant : floor(40 x L^1,1) ; niveau 1..20 ; +1,5 % de pv ET d'attaque par niveau au-dessus de 1.
-- L'XP est stockée sur l'emplacement (`slot.x`, total cumulé). AUCUN produit payant ne donne d'XP de pet (règle de design, testée).
Battle.MAX_LEVEL = 20
Battle.LEVEL_STEP = 0.015
-- Constantes de la courbe : exposant 1,1 (décision de la gestion : D.6 écrivait 1,6 mais annonçait ~ 9 600 XP cumulés ; 1,6 donnait 34 742, 1,1 donne 9 734,
-- aligné sur PetXp.lua du lot 12 B). Un seul réglage à changer.
Battle.XP_BASE, Battle.XP_EXP = 40, 1.1
function Battle.xpTo(level)
	return math.floor(Battle.XP_BASE * level ^ Battle.XP_EXP)
end
local XP_AT = { 0 } -- XP_AT[L] = XP cumulée minimale pour être au niveau L
for L = 2, Battle.MAX_LEVEL do
	XP_AT[L] = XP_AT[L - 1] + Battle.xpTo(L - 1)
end
Battle.XP_AT = XP_AT
Battle.XP_CAP = XP_AT[Battle.MAX_LEVEL]
function Battle.levelFromXp(x)
	x = tonumber(x) or 0
	local lv = 1
	while lv < Battle.MAX_LEVEL and x >= XP_AT[lv + 1] do
		lv = lv + 1
	end
	return lv
end
-- Nouvelle XP totale après un gain (jamais négative, plafonnée au niveau 20) ; `amount` non numérique -> inchangée.
function Battle.addXp(x, amount)
	x = math.max(0, tonumber(x) or 0)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount <= 0 then
		return math.min(x, Battle.XP_CAP)
	end
	return math.min(Battle.XP_CAP, x + math.floor(math.min(amount, 1e9)))
end
function Battle.levelMul(level)
	return 1 + Battle.LEVEL_STEP * (math.min(math.max(level or 1, 1), Battle.MAX_LEVEL) - 1)
end
-- XP gagnée par pet de l'équipe à la fin d'un combat : PvE gagné 20 + 5 x étage, perdu 5 ; PvP 15 / 5 (la graine de récompense reste côté serveur).
function Battle.xpReward(win, floor, pvp)
	if pvp then
		return win and 15 or 5
	end
	return win and (20 + 5 * math.max(0, floor or 0)) or 5
end

-- Unité de combat à partir de paramètres bruts (aussi utilisée par les tests). spec = { type, skill, tier, level, scale, size, mut, p }.
function Battle.rawUnit(spec)
	local t = math.min(math.max(spec.tier or 1, 1), #Battle.STATS)
	local st = Battle.STATS[t]
	local level = math.min(math.max(math.floor(spec.level or 1), 1), Battle.MAX_LEVEL)
	local bonus = (SIZE_BONUS[spec.size or 2] or 1) * (MUT_BONUS[spec.mut or 1] or 1) * (spec.scale or 1) * Battle.levelMul(level)
	local hp = math.floor(st.hp * bonus + 0.5)
	return {
		p = spec.p or 1, s = spec.size or 2, m = spec.mut or 1, tier = t, level = level,
		type = spec.type, skill = spec.skill,
		maxHp = hp, hp = hp, atk = math.floor(st.atk * bonus + 0.5), spd = st.spd,
		charge = 0, guard = 0, guardKeep = 1, stun = 0, focus = 0,
	}
end

-- Unité de combat d'un pet { p = espèce, s = taille, m = mutation, x = XP (optionnel) } ; `scale` : multiplicateur (adversaires de la tour) ;
-- `tierOverride` : rareté des stats (étage de la tour dont la rareté n'a pas encore d'espèce : apparence d'une rareté inférieure, stats de l'étage).
-- Niveau d'après `pet.x` (XP de l'emplacement) ; sans `x` : niveau 1 (adversaires, anciens profils).
function Battle.unit(Config, pet, scale, tierOverride)
	local def = Config.PETS[pet.p]
	return Battle.rawUnit({
		p = pet.p, size = pet.s, mut = pet.m, scale = scale, tier = tierOverride or def.tier,
		type = Battle.SPECIES_TYPE[pet.p], skill = Battle.SPECIES_SKILL[pet.p], level = Battle.levelFromXp(pet.x),
	})
end

local function copyUnit(u)
	local c = {}
	for k, v in pairs(u) do
		c[k] = v
	end
	c.charge, c.guard, c.guardKeep, c.stun, c.focus = c.charge or 0, c.guard or 0, c.guardKeep or 1, c.stun or 0, c.focus or 0
	return c
end

-- Nouveau combat. teamA/teamB : listes d'unités (Battle.unit). Camp A = joueur (ou attaquant), camp B = adversaire (ou défenseur).
-- `seed` : graine injectable ; même graine + mêmes équipes + mêmes actions = même journal.
function Battle.new(seed, teamA, teamB)
	local function side(team)
		local units = {}
		for i, u in ipairs(team) do
			units[i] = copyUnit(u)
		end
		return { units = units, active = 1 }
	end
	return { seed = seed, rnd = Battle.seedState(seed), turn = 0, sides = { side(teamA), side(teamB) }, over = false, winner = nil, log = {} }
end

local function alive(u)
	return u.hp > 0
end

local function activeOf(st, i)
	local sd = st.sides[i]
	return sd.units[sd.active]
end

local function firstAlive(sd, from)
	for k = 0, #sd.units - 1 do
		local idx = ((from - 1 + k) % #sd.units) + 1
		if alive(sd.units[idx]) then
			return idx
		end
	end
	return nil
end

-- Actions : { kind = "attack" } | { kind = "skill" } (le spécial) | { kind = "swap", to = n }. Retourne nil si valide, sinon la raison du refus.
function Battle.validate(st, sideIdx, action)
	if type(action) ~= "table" then
		return "action invalide"
	end
	local sd = st.sides[sideIdx]
	local u = sd.units[sd.active]
	if action.kind == "attack" then
		return nil
	elseif action.kind == "skill" then
		if u.charge < Battle.CHARGE_MAX then
			return "spécial pas prêt (" .. u.charge .. "/" .. Battle.CHARGE_MAX .. ")"
		end
		return nil
	elseif action.kind == "swap" then
		local to = action.to
		if type(to) ~= "number" or to % 1 ~= 0 or not sd.units[to] then
			return "pet inconnu"
		elseif to == sd.active or not alive(sd.units[to]) then
			return "pet indisponible"
		end
		return nil
	end
	return "action inconnue"
end

-- Action de l'IA (déterministe, sans tirage) : spécial dès que la charge est pleine, sauf `heal` tant que les pv > 70 % et `guard` tant que l'ennemi
-- n'a pas 4+ de charge (il attend alors en attaquant) ; change de pet quand le type adverse est très favorable, que ce pet est blessé et qu'un meilleur existe.
function Battle.aiAction(st, sideIdx)
	local sd, foe = st.sides[sideIdx], activeOf(st, 3 - sideIdx)
	local u = sd.units[sd.active]
	if Battle.typeMul(foe.type, u.type) >= Battle.STRONG and u.hp < u.maxHp * 0.6 then
		for i, o in ipairs(sd.units) do
			if i ~= sd.active and alive(o) and Battle.typeMul(foe.type, o.type) <= 1 then
				return { kind = "swap", to = i }
			end
		end
	end
	if u.charge >= Battle.CHARGE_MAX then
		local sk = u.skill
		local wait = (sk == "heal" and u.hp > u.maxHp * 0.7) or (sk == "guard" and foe.charge < 4)
		if not wait then
			return { kind = "skill" }
		end
	end
	return { kind = "attack" }
end

local function emit(st, ev)
	st.log[#st.log + 1] = ev
	return ev
end

-- Inflige des dégâts de `side` (attaquant) à l'unité active adverse ; retourne (dégâts, multiplicateur de type).
local function strike(st, atkSide, mul)
	local a, d = activeOf(st, atkSide), activeOf(st, 3 - atkSide)
	local r
	r, st.rnd = nextRnd(st.rnd)
	local tm = Battle.typeMul(a.type, d.type)
	local atk = a.atk * (a.focus > 0 and Battle.SKILLS.focus.boost or 1)
	local dmg = math.max(1, math.floor(atk * mul * tm * Battle.DAMAGE_MUL * (0.9 + 0.2 * r) + 0.5))
	if d.guard > 0 then
		dmg = math.max(1, math.floor(dmg * d.guardKeep))
		d.guard = d.guard - 1
		if d.guard == 0 then
			d.guardKeep = 1
		end
	end
	d.hp = math.max(0, d.hp - dmg)
	return dmg, tm
end

local function perform(st, sideIdx, action)
	local sd = st.sides[sideIdx]
	local u = sd.units[sd.active]
	if not alive(u) then
		return
	end
	if u.stun > 0 then -- un pet étourdi passe son tour et ne charge pas
		u.stun = u.stun - 1
		emit(st, { t = "stunned", side = sideIdx, p = u.p })
		return
	end
	if action.kind == "swap" then
		sd.active = action.to -- la charge reste attachée au pet
		emit(st, { t = "swap", side = sideIdx, to = action.to, p = sd.units[action.to].p })
		return
	end
	local foe = activeOf(st, 3 - sideIdx)
	if action.kind == "skill" and u.charge >= Battle.CHARGE_MAX then
		local sk = Battle.SKILLS[u.skill]
		u.charge = u.charge - Battle.CHARGE_MAX
		if u.skill == "heal" then
			local h = math.min(u.maxHp - u.hp, math.floor(u.maxHp * sk.heal + 0.5))
			u.hp = u.hp + h
			u.stun = 0
			emit(st, { t = "heal", side = sideIdx, amount = h, skill = u.skill, special = true, name = Battle.specialName(u), p = u.p })
		elseif u.skill == "guard" then
			u.guard, u.guardKeep = sk.hits, sk.keep
			emit(st, { t = "guard", side = sideIdx, skill = u.skill, special = true, name = Battle.specialName(u), p = u.p })
		else
			local dmg, tm = strike(st, sideIdx, sk.mul)
			emit(st, { t = "hit", side = sideIdx, dmg = dmg, mul = tm, skill = u.skill, special = true, name = Battle.specialName(u), hp = foe.hp, p = u.p, target = foe.p })
			if u.skill == "drain" then
				local h = math.min(u.maxHp - u.hp, math.floor(dmg * sk.leech))
				u.hp = u.hp + h
			elseif u.skill == "stun" and foe.hp > 0 then
				foe.stun = 1
			elseif u.skill == "focus" then
				u.focus = sk.turns + 1 -- décrémenté en fin de ce tour : 3 tours complets ensuite
				emit(st, { t = "buff", side = sideIdx, skill = u.skill, p = u.p })
			elseif u.skill == "freeze" and foe.hp > 0 then
				local lost = math.min(foe.charge, sk.drain)
				foe.charge = foe.charge - lost
				emit(st, { t = "discharge", side = sideIdx, amount = lost, target = foe.p, charge = foe.charge })
			elseif u.skill == "chain" then
				local fs = st.sides[3 - sideIdx]
				local nxt = firstAlive(fs, fs.active + 1)
				if nxt and nxt ~= fs.active then
					local rs = fs.units[nxt]
					local sp = math.max(1, math.floor(dmg * sk.splash))
					rs.hp = math.max(0, rs.hp - sp)
					emit(st, { t = "splash", side = sideIdx, dmg = sp, to = nxt, hp = rs.hp, p = u.p, target = rs.p })
				end
			elseif u.skill == "bulwark" then
				u.guard, u.guardKeep = sk.hits, sk.keep
				emit(st, { t = "guard", side = sideIdx, skill = u.skill, p = u.p })
			end
		end
	else
		local dmg, tm = strike(st, sideIdx, 1)
		u.charge = math.min(Battle.CHARGE_MAX, u.charge + 1 + (tm >= Battle.CHARGE_BONUS_MUL and 1 or 0))
		emit(st, { t = "hit", side = sideIdx, dmg = dmg, mul = tm, hp = foe.hp, p = u.p, target = foe.p, charge = u.charge })
	end
end

local function settle(st)
	for i = 1, 2 do
		local sd = st.sides[i]
		if not alive(sd.units[sd.active]) then
			local nxt = firstAlive(sd, sd.active)
			if nxt then
				sd.active = nxt
				emit(st, { t = "swap", side = i, to = nxt, forced = true, p = sd.units[nxt].p })
			else
				emit(st, { t = "ko", side = i })
			end
		end
	end
	local aOut, bOut = firstAlive(st.sides[1], 1) == nil, firstAlive(st.sides[2], 1) == nil
	if aOut or bOut then
		st.over, st.winner = true, aOut and 2 or 1
		if aOut and bOut then
			st.winner = 2 -- égalité : le défenseur l'emporte
		end
	end
end

local function totalFrac(sd)
	local hp, mx = 0, 0
	for _, u in ipairs(sd.units) do
		hp, mx = hp + u.hp, mx + u.maxHp
	end
	return hp / mx
end

-- Joue UN tour : actionA = intention du camp A (validée ici ; invalide -> attaque), le camp B joue l'IA (ou actionB). Retourne les événements du tour.
function Battle.turn(st, actionA, actionB)
	if st.over then
		return {}
	end
	local from = #st.log + 1
	st.turn = st.turn + 1
	if Battle.validate(st, 1, actionA) then
		actionA = { kind = "attack" }
	end
	actionB = actionB or Battle.aiAction(st, 2)
	if Battle.validate(st, 2, actionB) then
		actionB = { kind = "attack" }
	end
	emit(st, { t = "turn", n = st.turn })
	-- les changements de pet passent en premier, puis la vitesse décide (égalité : tirage)
	local order = { 1, 2 }
	local acts = { actionA, actionB }
	local function prio(i)
		return acts[i].kind == "swap" and 1 or 0
	end
	local ua, ub = activeOf(st, 1), activeOf(st, 2)
	local tie
	tie, st.rnd = nextRnd(st.rnd)
	if prio(2) > prio(1) or (prio(2) == prio(1) and (ub.spd > ua.spd or (ub.spd == ua.spd and tie < 0.5))) then
		order = { 2, 1 }
	end
	for _, i in ipairs(order) do
		if not st.over and alive(activeOf(st, i)) then
			perform(st, i, acts[i])
			settle(st)
		end
	end
	settle(st) -- même si personne n'a pu agir (deux camps déjà à terre)
	for i = 1, 2 do -- effets qui s'estompent
		for _, u in ipairs(st.sides[i].units) do
			if u.focus > 0 then
				u.focus = u.focus - 1
			end
		end
	end
	if not st.over and st.turn >= Battle.MAX_TURNS then
		local fa, fb = totalFrac(st.sides[1]), totalFrac(st.sides[2])
		st.over, st.winner = true, fa > fb and 1 or 2 -- limite de tours : le plus de PV restants gagne, égalité au défenseur
		emit(st, { t = "timeout" })
	end
	local out = {}
	for i = from, #st.log do
		out[#out + 1] = st.log[i]
	end
	return out
end

-- Équipe adverse de l'étage `floor` de la tour (déterministe) : 3 espèces de la rareté de l'étage, taille normale, niveau Config.towerScale.
function Battle.towerTeam(Config, floor)
	local tier = Config.towerTier(floor)
	local look = Config.liveEggTier(tier) -- lot 9 : rareté sans espèce publiée : espèces de la rareté inférieure, stats de l'étage
	local ids = {}
	for i, d in ipairs(Config.PETS) do
		if d.tier == look then
			ids[#ids + 1] = i
		end
	end
	local scale = Config.towerScale(floor)
	local team = {}
	for k = 1, Config.TOWER.teamSize do
		team[k] = Battle.unit(Config, { p = ids[(floor + k) % #ids + 1], s = 2, m = 1 }, scale, tier)
	end
	return team
end

-- Combat complet automatique (IA des deux côtés) : sert à l'équilibrage et aux tests. Retourne l'état final.
function Battle.run(seed, teamA, teamB)
	local st = Battle.new(seed, teamA, teamB)
	while not st.over do
		Battle.turn(st, Battle.aiAction(st, 1))
	end
	return st
end

-- Texte court d'un événement pour le journal : « 🐰 Lapin : Coup puissant ! 12 dégâts (super efficace) ». `side` 1 = toi.
function Battle.describe(Config, ev)
	local def = ev.p and Config.PETS[ev.p]
	local who = def and (def.emoji .. " " .. def.name) or ""
	local pre = ev.side == 1 and "" or "Adversaire · "
	if ev.t == "turn" then
		return "— Tour " .. ev.n .. " —"
	elseif ev.t == "hit" then
		local eff = ev.mul > 1 and " (super efficace !)" or (ev.mul < 1 and " (peu efficace)" or "")
		local sk = ev.skill and ((ev.name or Battle.SKILLS[ev.skill].name) .. " ! ") or ""
		return pre .. who .. " : " .. sk .. ev.dmg .. " dégâts" .. eff
	elseif ev.t == "heal" then
		return pre .. who .. " se soigne de " .. ev.amount
	elseif ev.t == "guard" then
		return pre .. who .. " se met en garde"
	elseif ev.t == "buff" then
		return pre .. who .. " se concentre (attaque +40 %)"
	elseif ev.t == "stunned" then
		return pre .. who .. " est étourdi et passe son tour"
	elseif ev.t == "discharge" then
		return pre .. who .. " : l'adversaire perd " .. ev.amount .. " de charge"
	elseif ev.t == "splash" then
		return pre .. who .. " : l'éclair touche le pet en réserve (" .. ev.dmg .. " dégâts)"
	elseif ev.t == "swap" then
		return pre .. (ev.forced and "envoie " or "change pour ") .. who
	elseif ev.t == "ko" then
		return (ev.side == 1 and "Ton équipe est" or "L'équipe adverse est") .. " à terre"
	elseif ev.t == "timeout" then
		return "Limite de " .. Battle.MAX_TURNS .. " tours : les PV restants décident"
	end
	return ""
end

-- Vue minimale d'un camp pour l'interface (aucune donnée de graine). `cd` = charge restante avant le spécial (0 = prêt) : l'ancien écran qui lit `cd` reste valable.
function Battle.view(st)
	local out = { turn = st.turn, over = st.over, winner = st.winner, sides = {} }
	for i = 1, 2 do
		local sd = st.sides[i]
		local units = {}
		for k, u in ipairs(sd.units) do
			units[k] = {
				p = u.p, s = u.s, m = u.m, type = u.type, hp = u.hp, maxHp = u.maxHp, skill = u.skill, level = u.level,
				charge = u.charge, chargeMax = Battle.CHARGE_MAX, cd = math.max(0, Battle.CHARGE_MAX - u.charge),
				guard = u.guard > 0, stun = u.stun, focus = u.focus,
			}
		end
		out.sides[i] = { units = units, active = sd.active }
	end
	return out
end

return Battle

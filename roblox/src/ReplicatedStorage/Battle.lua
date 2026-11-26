-- ModuleScript : ReplicatedStorage/Shared/Battle
-- Moteur de combat PUR (aucun service Roblox) de l'Arène des pets : équipes de 3 pets, tour par tour, résolution DÉTERMINISTE d'après une graine.
-- Le serveur est la seule autorité : le client n'envoie qu'une intention (attaque, compétence, changer de pet) et rejoue les événements reçus.
-- Types (6) : roue Feu > Nature > Eau > Feu et Lumière > Ombre > Ciel > Lumière (avantage x1,5, désavantage x0,67). Une compétence par espèce.
local Battle = {}

Battle.TYPES = { "Feu", "Eau", "Nature", "Ciel", "Ombre", "Lumière" }
Battle.TYPE_EMOJI = { Feu = "🔥", Eau = "💧", Nature = "🌿", Ciel = "🌪️", Ombre = "🌑", ["Lumière"] = "✨" }
Battle.BEATS = { Feu = "Nature", Nature = "Eau", Eau = "Feu", ["Lumière"] = "Ombre", Ombre = "Ciel", Ciel = "Lumière" }
Battle.STRONG, Battle.WEAK = 1.5, 0.67
Battle.MAX_TURNS = 30

-- Type de chacune des 18 espèces (ordre de Config.PETS), 3 par type ; les 3 espèces d'une même rareté forment un TRIANGLE complet de la roue (Feu/Nature/Eau ou Lumière/Ombre/Ciel) : à rareté égale, aucune n'est favorisée.
Battle.SPECIES_TYPE = { "Ciel", "Ombre", "Lumière", "Eau", "Nature", "Feu", "Lumière", "Ombre", "Ciel", "Feu", "Nature", "Eau", "Ciel", "Ombre", "Lumière", "Nature", "Eau", "Feu" }
-- Compétence de chaque espèce : strike (dégâts x1,8), drain (dégâts x1,1 et soin du tiers), heal (soin 30 %), guard (le prochain coup ne fait que 30 %), stun (dégâts x1 et l'ennemi passe son tour), focus (attaque +25 % pendant 3 tours).
Battle.SPECIES_SKILL = { "focus", "heal", "guard", "stun", "strike", "drain", "heal", "stun", "guard", "drain", "strike", "heal", "strike", "focus", "stun", "drain", "heal", "guard" }
Battle.SKILLS = {
	strike = { name = "Coup puissant", cd = 3, mul = 1.6 },
	drain = { name = "Morsure vampire", cd = 3, mul = 1.1 },
	heal = { name = "Soin", cd = 4, heal = 0.25 },
	guard = { name = "Garde", cd = 3, keep = 0.3 },
	stun = { name = "Étourdissement", cd = 5, mul = 1.0 },
	focus = { name = "Concentration", cd = 4, boost = 1.4 },
}

-- Multiplicateur d'efficacité du type `atk` contre le type `def`.
function Battle.typeMul(atk, def)
	if Battle.BEATS[atk] == def then
		return Battle.STRONG
	elseif Battle.BEATS[def] == atk then
		return Battle.WEAK
	end
	return 1
end

-- Générateur déterministe (Park–Miller) : état = entier, retourne (valeur 0..1, nouvel état).
local function nextRnd(state)
	state = (state * 16807) % 2147483647
	return state / 2147483647, state
end
Battle.nextRnd = nextRnd

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

-- Unité de combat d'un pet { p = espèce, s = taille, m = mutation } ; `scale` : multiplicateur de niveau (adversaires de la tour) ;
-- `tierOverride` : rareté des stats (étage de la tour dont la rareté n'a pas encore d'espèce : apparence d'une rareté inférieure, stats de l'étage).
function Battle.unit(Config, pet, scale, tierOverride)
	local def = Config.PETS[pet.p]
	local bonus = (SIZE_BONUS[pet.s] or 1) * (MUT_BONUS[pet.m] or 1) * (scale or 1)
	local t = tierOverride or def.tier
	local st = Battle.STATS[math.min(math.max(t, 1), #Battle.STATS)]
	local hp = math.floor(st.hp * bonus + 0.5)
	return {
		p = pet.p, s = pet.s, m = pet.m, tier = t,
		type = Battle.SPECIES_TYPE[pet.p], skill = Battle.SPECIES_SKILL[pet.p],
		maxHp = hp, hp = hp, atk = math.floor(st.atk * bonus + 0.5), spd = st.spd,
		cd = 0, guard = false, stun = 0, focus = 0,
	}
end

local function copyUnit(u)
	local c = {}
	for k, v in pairs(u) do
		c[k] = v
	end
	return c
end

-- Nouveau combat. teamA/teamB : listes d'unités (Battle.unit). Camp A = joueur (ou attaquant), camp B = adversaire (ou défenseur).
function Battle.new(seed, teamA, teamB)
	local function side(team)
		local units = {}
		for i, u in ipairs(team) do
			units[i] = copyUnit(u)
		end
		return { units = units, active = 1 }
	end
	return { seed = seed, rnd = (math.floor(seed) % 2147483646) + 1, turn = 0, sides = { side(teamA), side(teamB) }, over = false, winner = nil, log = {} }
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

-- Actions : { kind = "attack" } | { kind = "skill" } | { kind = "swap", to = n }. Retourne nil si valide, sinon la raison du refus.
function Battle.validate(st, sideIdx, action)
	if type(action) ~= "table" then
		return "action invalide"
	end
	local sd = st.sides[sideIdx]
	local u = sd.units[sd.active]
	if action.kind == "attack" then
		return nil
	elseif action.kind == "skill" then
		if u.cd > 0 then
			return "compétence en recharge"
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

-- Action de l'IA (déterministe) : compétence si prête et utile, sinon attaque ; change de pet quand le type est très défavorable et qu'un meilleur existe.
function Battle.aiAction(st, sideIdx)
	local sd, foe = st.sides[sideIdx], activeOf(st, 3 - sideIdx)
	local u = sd.units[sd.active]
	if Battle.typeMul(foe.type, u.type) > 1 then
		for i, o in ipairs(sd.units) do
			if i ~= sd.active and alive(o) and Battle.typeMul(foe.type, o.type) <= 1 and u.hp < u.maxHp * 0.6 then
				return { kind = "swap", to = i }
			end
		end
	end
	if u.cd == 0 then
		local sk = u.skill
		if sk == "heal" and u.hp > u.maxHp * 0.6 then
			return { kind = "attack" }
		end
		return { kind = "skill" }
	end
	return { kind = "attack" }
end

local function emit(st, ev)
	st.log[#st.log + 1] = ev
	return ev
end

-- Inflige des dégâts de `side` (attaquant) à l'unité active adverse ; retourne les dégâts.
local function strike(st, atkSide, mul)
	local a, d = activeOf(st, atkSide), activeOf(st, 3 - atkSide)
	local r
	r, st.rnd = nextRnd(st.rnd)
	local tm = Battle.typeMul(a.type, d.type)
	local atk = a.atk * (a.focus > 0 and Battle.SKILLS.focus.boost or 1)
	local dmg = math.max(1, math.floor(atk * mul * tm * (0.9 + 0.2 * r) + 0.5))
	if d.guard then
		dmg = math.max(1, math.floor(dmg * Battle.SKILLS.guard.keep))
		d.guard = false
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
	if u.stun > 0 then
		u.stun = u.stun - 1
		emit(st, { t = "stunned", side = sideIdx, p = u.p })
		return
	end
	if action.kind == "swap" then
		sd.active = action.to
		emit(st, { t = "swap", side = sideIdx, to = action.to, p = sd.units[action.to].p })
		return
	end
	local foe = activeOf(st, 3 - sideIdx)
	if action.kind == "skill" and u.cd == 0 then
		local sk = Battle.SKILLS[u.skill]
		u.cd = sk.cd
		if u.skill == "heal" then
			local h = math.min(u.maxHp - u.hp, math.floor(u.maxHp * sk.heal + 0.5))
			u.hp = u.hp + h
			emit(st, { t = "heal", side = sideIdx, amount = h, skill = u.skill, p = u.p })
		elseif u.skill == "guard" then
			u.guard = true
			emit(st, { t = "guard", side = sideIdx, skill = u.skill, p = u.p })
		elseif u.skill == "focus" then
			u.focus = 3
			emit(st, { t = "buff", side = sideIdx, skill = u.skill, p = u.p })
		else
			local dmg, tm = strike(st, sideIdx, sk.mul)
			emit(st, { t = "hit", side = sideIdx, dmg = dmg, mul = tm, skill = u.skill, hp = foe.hp, p = u.p, target = foe.p })
			if u.skill == "drain" then
				local h = math.min(u.maxHp - u.hp, math.floor(dmg / 3))
				u.hp = u.hp + h
			elseif u.skill == "stun" and foe.hp > 0 then
				foe.stun = 1
			end
		end
	else
		local dmg, tm = strike(st, sideIdx, 1)
		emit(st, { t = "hit", side = sideIdx, dmg = dmg, mul = tm, hp = foe.hp, p = u.p, target = foe.p })
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
	-- les changements de pet passent en premier, puis la vitesse décide (égalité : camp A)
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
	for i = 1, 2 do -- recharges et effets qui s'estompent
		for _, u in ipairs(st.sides[i].units) do
			if u.cd > 0 then
				u.cd = u.cd - 1
			end
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
		local sk = ev.skill and (Battle.SKILLS[ev.skill].name .. " ! ") or ""
		return pre .. who .. " : " .. sk .. ev.dmg .. " dégâts" .. eff
	elseif ev.t == "heal" then
		return pre .. who .. " se soigne de " .. ev.amount
	elseif ev.t == "guard" then
		return pre .. who .. " se met en garde"
	elseif ev.t == "buff" then
		return pre .. who .. " se concentre (attaque +40 %)"
	elseif ev.t == "stunned" then
		return pre .. who .. " est étourdi et passe son tour"
	elseif ev.t == "swap" then
		return pre .. (ev.forced and "envoie " or "change pour ") .. who
	elseif ev.t == "ko" then
		return (ev.side == 1 and "Ton équipe est" or "L'équipe adverse est") .. " à terre"
	elseif ev.t == "timeout" then
		return "Limite de " .. Battle.MAX_TURNS .. " tours : les PV restants décident"
	end
	return ""
end

-- Vue minimale d'un camp pour l'interface (aucune donnée de graine).
function Battle.view(st)
	local out = { turn = st.turn, over = st.over, winner = st.winner, sides = {} }
	for i = 1, 2 do
		local sd = st.sides[i]
		local units = {}
		for k, u in ipairs(sd.units) do
			units[k] = { p = u.p, s = u.s, m = u.m, type = u.type, hp = u.hp, maxHp = u.maxHp, cd = u.cd, skill = u.skill, guard = u.guard, stun = u.stun, focus = u.focus }
		end
		out.sides[i] = { units = units, active = sd.active }
	end
	return out
end

return Battle

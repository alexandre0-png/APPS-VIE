-- Simulation PURE (aucun service Roblox) d'un vol dans un territoire gardé par un joueur-robot. Sert aux tests de difficulté (lots 4 et 8A) :
-- Zed : < 30 % sans amélioration de vitesse, > 60 % avec vitesse >= 30 ; Mara : 30 à 70 % selon la vitesse ; Gus : > 85 % (clément).
--
-- HYPOTHÈSES (écrites noir sur blanc ; si une seule change, les chiffres changent) :
--  H1  Décor : le territoire `opts.terr` (défaut "zed", Config.TERR), ses gardiens aux postes de Config.TERR[terr].posts, patrouille de +/- half sur
--      l'axe X (comme Builder/Main), gardien borné au disque (Guard.clampToDisc, rayon max(r - territoryMargin, dPost + half + 0.5)).
--  H2  Gardiens : exactement la logique de Main (Guard.perceive avec Config.guardStats(terr), Guard.nextState, délai d'alerte du rival, poursuite à
--      guardSpeed, coup de `damage` pv si distance < attackRange et délai attackCd, invulnérabilité iframes du joueur). Pas de vigilance (premier vol).
--  H3  Joueur-robot ACTIF (lot 8A) : arrive à l'ENTRÉE du territoire à un instant tiré au hasard dans le cycle des gardiens, marche tout droit vers un
--      nid tiré au hasard, tient le bouton Config.stealTime(Doigts agiles, terr) (immobile ; un coup remet le maintien à zéro), puis repart tout droit
--      vers l'entrée en portant l'œuf (vitesse x Config.carryMul de la rareté typique du territoire : Zed Légendaire, Mara Épique, Gus Commun). Sa
--      vitesse de marche est Config.walkSpeed(statVitesse) (16 studs/s à 0, 24 à 30). S'il voit un gardien le POURSUIVRE à moins de 30 studs avant
--      d'avoir l'œuf, il renonce, revient à l'entrée, attend que tous les gardiens aient repris leur patrouille puis 0 à 6 s (hasard), et retente sur
--      un nid tiré au hasard. Il ne fait aucune autre esquive et passe la herse de Zed seulement ouverte.
--  H4  Pièges (Traps.playerStep) : clochettes, dalles et lanternes envoient les gardiens à l'endroit (état « perte de cible », comme Main) ; boue x0,6.
--  H5  Réussite = le robot sort par l'entrée avec l'œuf et des points de vie > 0 en moins de 120 s. Échec = 0 pv, œuf repris, ou 120 s écoulées.
--  H6  Les poursuivants ne quittent jamais leur disque ; aucun gardien ne vise le robot à moins de GUARD.safeRadius de l'entrée (comme le jeu).
--  H7  Règle du lot 8A (même que Main), là où Config.TERR[terr].nestAlarm existe (Mara, Zed) : chiper un œuf réveille le gardien le plus proche
--      du voleur, qui le CHARGE `delay` s plus tard ; si CE gardien le frappe pendant qu'il porte l'œuf, l'œuf retourne à son nid (B.4, « retaken »).
--      Les autres coups ne coûtent que des pv (lot 4). Gus (gentle, sans alarme) : une prise renvoie à la base ; avant d'avoir l'œuf, c'est un
--      échec ; avec l'œuf, il est gardé (règle de Main) : réussite.
local Sim = {}

local sqrt = math.sqrt

local CARRY_TIER = { zed = 4, mara = 3, gusNW = 1, gusSW = 1, wild = 1 }

local function newRng(seed)
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

-- Avance le robot d'un pas. th = { x, z, phase ("idle" | "in" | "hold" | "out" | "flee" | "rest"), hold, wait, moving, speedNow }.
-- Retourne "grab" à l'instant où le maintien aboutit, "done" quand il est ressorti par l'entrée avec l'œuf.
local function thiefStep(th, env, tnow, dt, started)
	th.moving = false
	if not started then
		return nil
	end
	if th.phase == "idle" then
		th.phase = "in"
	end
	if th.phase == "rest" then -- à l'abri près de l'entrée : attend que tous les gardiens patrouillent, puis 0 à 6 s, et retente
		if env.calm() then
			th.wait = th.wait or env.rnd() * 6
			th.wait = th.wait - dt
			if th.wait <= 0 then
				th.wait, th.phase, th.hold = nil, "in", 0
				env.nest = env.T.nests[math.floor(env.rnd() * #env.T.nests) + 1]
			end
		end
		return nil
	end
	local tx, tz, speed
	if th.phase == "flee" then
		tx, tz, speed = env.ex, env.ez, env.walk
	elseif th.phase == "in" then
		tx, tz, speed = env.nest[1], env.nest[2], env.walk
	elseif th.phase == "hold" then
		tx, tz, speed = th.x, th.z, 0
	else
		tx, tz, speed = env.ex, env.ez, env.walk * env.carryMul
	end
	local dx, dz = tx - th.x, tz - th.z
	local d = sqrt(dx * dx + dz * dz)
	if th.phase == "hold" then
		th.hold = th.hold + dt
		if th.hold >= env.holdTime then
			th.phase = "out"
			return "grab"
		end
	elseif th.phase == "flee" and d < 3 then
		th.phase = "rest"
	elseif th.phase == "in" and d < 2 then
		th.phase, th.hold = "hold", 0
	elseif th.phase == "out" and d < 2.5 then
		return "done"
	else
		local blocked = th.phase == "out" and d < 4 and env.L ~= nil and env.L.gate ~= nil and not env.Traps.gateOpen(tnow, env.L.gate) -- herse baissée
		if not blocked then
			local mv = math.min(d, speed * dt) * env.Traps.mudMul(env.ps, tnow, env.Config.TRAPS)
			th.x, th.z = th.x + dx / d * mv, th.z + dz / d * mv
			th.moving, th.speedNow = mv > 0, speed
		end
	end
	return nil
end

local function newGuards(env, rnd)
	local T, out = env.T, {}
	for i, p in ipairs(T.posts or {}) do
		local inner = T.r - env.Config.GUARD.territoryMargin
		local dPost = sqrt((p[1] - T.x) ^ 2 + (p[2] - T.z) ^ 2)
		local half = math.max(4, math.min(12, inner - dPost))
		out[i] = { x = p[1] + (rnd() * 2 - 1) * half, z = p[2], cx = p[1], pz = p[2], half = half, dir = rnd() < 0.5 and -1 or 1, clampR = math.max(inner, dPost + half + 0.5),
			st = { state = "patrol", timer = 0, lost = 0 }, fx = 1, fz = 0, cd = 0, last = nil }
	end
	return out
end

local function patrolMove(g, speed, dt)
	g.x = g.x + g.dir * speed * dt
	if g.x > g.cx + g.half then
		g.dir = -1
	elseif g.x < g.cx - g.half then
		g.dir = 1
	end
	g.fx, g.fz = g.dir, 0
end

-- Un essai. Retourne true si le vol réussit. opts : terr (défaut "zed"), fing (Doigts agiles), stats (table de compteurs, facultative).
function Sim.trial(Config, Guard, Traps, speedStat, rnd, opts)
	opts = opts or {}
	local key = opts.terr or "zed"
	local T = Config.TERR[key]
	local stats = Config.guardStats(key)
	local GC = setmetatable({ alertDelay = stats.alertDelay or Config.GUARD.alertDelay }, { __index = Config.GUARD })
	local ex, ez = Config.territoryEntry(key)
	local alarm = T.nestAlarm -- H7 : nil hors de la cour de Zed
	local env = { Config = Config, Guard = Guard, Traps = Traps, T = T, stats = stats, L = Traps.layout(Config, key), ex = ex, ez = ez, rnd = rnd,
		nest = T.nests[math.floor(rnd() * #T.nests) + 1], walk = Config.walkSpeed(speedStat), carryMul = Config.carryMul({ CARRY_TIER[key] or 1 }),
		holdTime = Config.stealTime(opts.fing or 0, key), ps = Traps.newPlayerState() }
	local dt = 0.1
	local guards = newGuards(env, rnd)
	env.calm = function()
		for _, g in ipairs(guards) do
			if g.st.state ~= "patrol" then
				return false
			end
		end
		return true
	end
	local tStart = rnd() * 40 -- instant du cycle des lanternes et de la herse à l'arrivée du robot
	local me = { x = ex, z = ez, phase = "idle", hold = 0, moving = false, speedNow = 0 }
	local hp, inv = 100, 0
	local chargeAt = nil
	local function count(k)
		if opts.stats then
			opts.stats[k] = (opts.stats[k] or 0) + 1
		end
	end
	local tn = 0
	while tn < 120 do
		local tnow = tStart + tn
		if me.phase == "in" or me.phase == "hold" then -- H3 : renonce s'il est poursuivi de près avant d'avoir l'œuf
			for _, g in ipairs(guards) do
				if g.st.state == "chase" and ((g.x - me.x) ^ 2 + (g.z - me.z) ^ 2) < 30 * 30 then
					me.phase, me.hold = "flee", 0
				end
			end
		end
		local res = thiefStep(me, env, tnow, dt, true)
		if res == "done" then
			count(hp == 100 and "clean" or "hurt")
			return hp > 0
		elseif res == "grab" and alarm then
			chargeAt = tn + alarm.delay
		end
		if chargeAt and tn >= chargeAt then -- H7 (b) : le gardien le plus proche charge le voleur
			chargeAt = nil
			local best, bd = nil, math.huge
			for _, g in ipairs(guards) do
				local d2 = (g.x - me.x) ^ 2 + (g.z - me.z) ^ 2
				if d2 < bd then
					best, bd = g, d2
				end
			end
			if best then
				best.st = Guard.charge(best.st)
				best.last, best.charge = { x = me.x, z = me.z }, true
			end
		end
		if env.L then
			for _, ev in ipairs(Traps.playerStep(env.ps, env.L, Config.TRAPS, tnow, me.x, me.z)) do
				if ev.kind ~= "mud" then -- alarme : les gardiens vont à l'endroit (comme Main)
					for _, g in ipairs(guards) do
						if g.st.state ~= "chase" then
							g.st = { state = "lostChase", timer = 0, lost = 0 }
							g.last = { x = me.x, z = me.z }
						end
					end
				end
			end
		end
		inv = math.max(0, inv - dt)
		local inTerr = ((me.x - T.x) ^ 2 + (me.z - T.z) ^ 2) <= T.r * T.r
		local canTarget = inTerr and sqrt((me.x - ex) ^ 2 + (me.z - ez) ^ 2) >= Config.GUARD.safeRadius
		for _, g in ipairs(guards) do
			g.cd = g.cd - dt
			local percept = { sees = false, hears = false, dist = math.huge, atHome = false }
			if canTarget and g.st.state ~= "lostChase" then
				percept = Guard.perceive({ x = g.x, z = g.z, fx = g.fx, fz = g.fz }, { x = me.x, z = me.z, speed = me.moving and me.speedNow or 0 }, stats, Config.GUARD)
				if percept.sees or percept.hears then
					g.last = { x = me.x, z = me.z }
				end
			end
			local homeX = math.max(g.cx - g.half, math.min(g.cx + g.half, g.x))
			percept.atHome = sqrt((homeX - g.x) ^ 2 + (g.pz - g.z) ^ 2) < 1
			g.st = Guard.nextState(g.st, dt, percept, GC)
			local state = g.st.state
			if state ~= "chase" then
				g.charge = false -- la charge s'arrête avec la poursuite (comme Main)
			end
			if state == "patrol" then
				patrolMove(g, stats.patrolSpeed, dt)
			elseif state == "alert" then
				if g.last then
					local dx, dz = g.last.x - g.x, g.last.z - g.z
					local d = sqrt(dx * dx + dz * dz)
					if d > 0.01 then
						g.fx, g.fz = dx / d, dz / d
					end
				end
			elseif state == "chase" or state == "lostChase" then
				local gx, gz = g.x, g.z
				if state == "chase" and canTarget then
					gx, gz = me.x, me.z
				elseif g.last then
					gx, gz = g.last.x, g.last.z
				end
				local dx, dz = gx - g.x, gz - g.z
				local d = sqrt(dx * dx + dz * dz)
				if d > 0.01 then
					local mv = math.min(d, stats.guardSpeed * dt)
					g.x, g.z = g.x + dx / d * mv, g.z + dz / d * mv
					g.fx, g.fz = dx / d, dz / d
				end
				if state == "chase" and canTarget and d < Config.GUARD.attackRange and g.cd <= 0 and (stats.gentle or inv <= 0) then
					g.cd = Config.GUARD.attackCd
					if stats.gentle then -- Gus : renvoi à la base ; l'œuf porté est gardé (Main), sinon l'essai est perdu
						count(me.phase == "out" and "gentleHome" or "gentleCaught")
						return me.phase == "out"
					end
					hp = hp - stats.damage
					inv = Config.GUARD.iframes
					me.hold = 0 -- un coup interrompt le maintien du bouton (recul hors de portée du prompt)
					if me.phase == "out" and g.charge then -- H7 : le gardien qui charge reprend l'œuf, qui retourne à son nid
						count("retaken")
						return false
					end
				end
			else -- retour au poste
				local dx, dz = homeX - g.x, g.pz - g.z
				local d = sqrt(dx * dx + dz * dz)
				if d >= 1 then
					local mv = math.min(d, stats.patrolSpeed * 1.6 * dt)
					g.x, g.z = g.x + dx / d * mv, g.z + dz / d * mv
					g.fx, g.fz = dx / d, dz / d
				end
			end
			g.x, g.z = Guard.clampToDisc(g.x, g.z, T.x, T.z, g.clampR)
		end
		if hp <= 0 then
			count("dead")
			return false
		end
		tn = tn + dt
	end
	count("timeout")
	return false
end

-- Taux de réussite sur `n` essais (graine fixe : résultat reproductible).
function Sim.rate(Config, Guard, Traps, speedStat, n, seed, opts)
	local rnd = newRng(seed or 12345)
	local ok = 0
	for _ = 1, n do
		if Sim.trial(Config, Guard, Traps, speedStat, rnd, opts) then
			ok = ok + 1
		end
	end
	return ok / n
end

return Sim

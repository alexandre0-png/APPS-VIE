-- Simulation PURE (aucun service Roblox) d'un vol dans le territoire de Zed par un joueur-robot. Sert aux tests de difficulté du lot 4 :
-- taux de réussite d'un vol chez Zed sans amélioration de vitesse (< 30 %) et avec vitesse >= 30 (> 60 %).
--
-- HYPOTHÈSES (écrites noir sur blanc ; si une seule change, les chiffres changent) :
--  H1  Décor : le territoire de Zed (Config.TERR.zed), ses 3 gardiens aux postes de Config.TERR.zed.posts, patrouille de +/- patrolHalf sur l'axe X (comme
--      Builder/Main), gardien borné au disque (Guard.clampToDisc, rayon max(r - territoryMargin, dPost + patrolHalf + 0.5)).
--  H2  Gardiens : exactement la logique de Main (Guard.perceive avec Config.guardStats("zed"), Guard.nextState, délai d'alerte Config.GUARD.alertDelay,
--      poursuite à guardSpeed, coup de `damage` pv si distance < attackRange et délai attackCd, invulnérabilité iframes du joueur). Pas de vigilance (premier vol).
--  H3  Joueur-robot : arrive à l'ENTRÉE (herse) à un instant tiré au hasard dans le cycle des gardiens (phases de patrouille aléatoires), marche tout droit vers un
--      nid tiré au hasard, tient le bouton Config.stealTime(0, "zed") = 3,5 s (immobile : silencieux, mais visible ; un coup remet le maintien à zéro), puis
--      repart tout droit vers l'entrée en portant l'œuf (vitesse x Config.carryMul de sa rareté, Légendaire = rareté 4). Sa vitesse de marche est
--      Config.walkSpeed(statVitesse) (16 studs/s à 0, 24 à 30). Il ignore les gardiens (aucune esquive) mais passe la herse seulement ouverte.
--  H4  Pièges de Zed : dalles d'alarme et lanternes tournantes (Traps.playerStep) ; une alarme envoie les gardiens à l'endroit (état « perte de cible »,
--      comme Main). La herse (Traps.gateOpen) est franchie seulement quand elle est ouverte.
--  H5  Réussite = le robot sort par l'entrée avec l'œuf et des points de vie > 0 (un coup est subi, pas fatal : 100 pv, coup de 28, au plus 3 coups).
--      Échec = 0 pv (l'œuf est rendu) ou plus de 120 s.
--  H6  Les poursuivants ne quittent jamais leur disque : la poursuite s'arrête au bord du territoire (comme dans le jeu).
local Sim = {}

local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi

local function newRng(seed)
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
end

-- Avance le robot d'un pas. th = { x, z, phase ("idle" | "in" | "hold" | "out"), hold, moving, speedNow }. Retourne "done" quand il est ressorti par l'entrée.
local function thiefStep(th, env, tnow, dt, started)
	th.moving = false
	if not started then
		return nil
	end
	if th.phase == "idle" then
		th.phase = "in"
	end
	if th.phase == "rest" then -- à l'abri près de l'entrée : il attend que tous les gardiens aient repris leur poste, puis retente
		if env.calm and env.calm() then
			th.phase, th.hold = "in", 0
			env.nest = env.T.nests[math.floor(env.rnd() * #env.T.nests) + 1]
		end
		return nil
	end
	local tx, tz, speed
	if th.phase == "flee" then
		tx, tz, speed = env.ex, env.ez, env.walk
		local dx0, dz0 = tx - th.x, tz - th.z
		if sqrt(dx0 * dx0 + dz0 * dz0) < 3 then
			th.phase = "rest"
			return nil
		end
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
		end
	elseif th.phase == "in" and d < 2 then
		th.phase, th.hold = "hold", 0
	elseif th.phase == "out" and d < 2.5 then
		return "done"
	else
		local blocked = th.phase == "out" and d < 4 and not env.Traps.gateOpen(tnow, env.L.gate) -- la herse barre l'entrée
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
	for i, p in ipairs(T.posts) do
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

-- Le plan « aller, maintenir, revenir » commencé à `offset` s reste-t-il hors de vue (cône, lanternes, dalles) si les gardiens ne font que patrouiller ?
local function planIsSafe(env, guards0, offset, tStart, dt)
	local gs = {}
	for i, g in ipairs(guards0) do
		gs[i] = { x = g.x, z = g.z, dir = g.dir, cx = g.cx, half = g.half, fx = g.dir, fz = 0 }
	end
	local th = { x = env.ex, z = env.ez, phase = "idle", hold = 0 }
	local ps = env.Traps.newPlayerState()
	env.ps = ps
	local tn = 0
	while tn < 70 do
		for _, g in ipairs(gs) do
			patrolMove(g, env.stats.patrolSpeed, dt)
		end
		local res = thiefStep(th, env, tStart + tn, dt, tn >= offset)
		if res == "done" then
			return true
		end
		if sqrt((th.x - env.ex) ^ 2 + (th.z - env.ez) ^ 2) >= env.Config.GUARD.safeRadius and tn >= offset then
			for _, g in ipairs(gs) do
				if env.Guard.sees({ x = g.x, z = g.z, fx = g.fx, fz = g.fz }, { x = th.x, z = th.z }, env.stats.viewDist, env.stats.viewAngle) then
					return false
				end
			end
			for _, ev in ipairs(env.Traps.playerStep(ps, env.L, env.Config.TRAPS, tStart + tn, th.x, th.z)) do
				if ev.kind ~= "mud" then
					return false
				end
			end
		end
		tn = tn + dt
	end
	return false
end

-- Un essai. Retourne true si le vol réussit. opts.observant : le robot attend (au plus opts.patience s) une fenêtre où il n'est vu de personne.
function Sim.trial(Config, Guard, Traps, speedStat, rnd, opts)
	opts = opts or {}
	local T = Config.TERR.zed
	local stats = Config.guardStats("zed")
	local GC = setmetatable({ alertDelay = stats.alertDelay or Config.GUARD.alertDelay }, { __index = Config.GUARD })
	local ex, ez = Config.territoryEntry("zed")
	local env = { Config = Config, Guard = Guard, Traps = Traps, T = T, stats = stats, L = Traps.layout(Config, "zed"), ex = ex, ez = ez,
		nest = T.nests[math.floor(rnd() * #T.nests) + 1], walk = Config.walkSpeed(speedStat), carryMul = Config.carryMul({ 4 }), holdTime = Config.stealTime(opts.fing or 0, "zed") }
	local dt = 0.1
	local guards = newGuards(env, rnd)
	local tStart = rnd() * 40 -- instant du cycle des lanternes et de la herse à l'arrivée du robot
	local startAt = 0
	if opts.observant then
		startAt = -1
		local o = 0
		while o <= (opts.patience or 30) do
			if planIsSafe(env, guards, o, tStart, dt) then
				startAt = o
				break
			end
			o = o + 0.5
		end
		if startAt < 0 then
			startAt = opts.patience or 30 -- aucune fenêtre : il tente sa chance
		end
	end
	local me = { x = ex, z = ez, phase = "idle", hold = 0, moving = false, speedNow = 0 }
	local hp, inv = 100, 0
	env.ps = Traps.newPlayerState()
	local tn = 0
	while tn < startAt + 120 do
		local tnow = tStart + tn
		if opts.flee and (me.phase == "in" or me.phase == "hold") then
			for _, g in ipairs(guards) do
				if g.st.state == "chase" and ((g.x - me.x) ^ 2 + (g.z - me.z) ^ 2) < 30 * 30 then
					me.phase, me.hold = "flee", 0
				end
			end
		end
		env.calm = function()
			for _, g in ipairs(guards) do
				if g.st.state ~= "patrol" then
					return false
				end
			end
			return true
		end
		env.rnd = rnd
		local res = thiefStep(me, env, tnow, dt, tn >= startAt)
		if res == "done" then
			if opts.stats then
				local k = hp == 100 and "clean" or (hp == 72 and "hit1" or "hit2plus")
				opts.stats[k] = (opts.stats[k] or 0) + 1
			end
			return hp > 0
		end
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
				if state == "chase" and canTarget and d < Config.GUARD.attackRange and g.cd <= 0 and inv <= 0 then
					hp = hp - stats.damage
					inv, g.cd = Config.GUARD.iframes, Config.GUARD.attackCd
					if not opts.holdSurvivesHit then
						me.hold = 0 -- un coup interrompt le maintien du bouton (recul hors de portée du prompt)
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
			if opts.stats then
				opts.stats.dead = (opts.stats.dead or 0) + 1
				opts.stats["dead_" .. me.phase] = (opts.stats["dead_" .. me.phase] or 0) + 1
			end
			return false
		end
		tn = tn + dt
	end
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

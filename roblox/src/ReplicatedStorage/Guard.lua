-- ModuleScript : ReplicatedStorage/Shared/Guard
-- Perception et état des gardiens (chien de Gus, loup de Mara, ours de Zed) : champ de vision (cône + distance), ouïe (le bruit dépend de la
-- vitesse du joueur), machine à états Patrouille / Alerte / Poursuite / Perte de cible / Retour, dégâts avec invulnérabilité courte et régénération.
-- PUR (aucun service Roblox, positions = tables { x, z }) : testé hors de Roblox. Main n'applique que ces décisions au monde.
local Guard = {}

local sqrt, acos, deg = math.sqrt, math.acos, math.deg

local function len(x, z)
	return sqrt(x * x + z * z)
end

-- Angle en degrés (0..180) entre le regard (fx, fz) et la direction (dx, dz). 0 si l'un des vecteurs est nul.
function Guard.angle(fx, fz, dx, dz)
	local a, b = len(fx, fz), len(dx, dz)
	if a < 1e-9 or b < 1e-9 then
		return 0
	end
	local c = (fx * dx + fz * dz) / (a * b)
	return deg(acos(math.max(-1, math.min(1, c))))
end

-- Le gardien g = { x, z, fx, fz } voit-il la cible t = { x, z } ? Cône de `viewAngle` degrés (total) et distance max `viewDist`.
function Guard.sees(g, t, viewDist, viewAngle)
	local dx, dz = t.x - g.x, t.z - g.z
	local d = len(dx, dz)
	if d > viewDist then
		return false
	end
	if d < 1.5 then
		return true -- collé au gardien : toujours vu
	end
	return Guard.angle(g.fx, g.fz, dx, dz) <= viewAngle / 2
end

-- Niveau de bruit (0..1) selon la vitesse : immobile = silence, marche lente = discret, course = plein bruit.
function Guard.noise(speed, cfg)
	if type(speed) ~= "number" or speed ~= speed or speed <= cfg.stillSpeed then
		return 0
	elseif speed < cfg.sneakSpeed then
		return cfg.sneakNoise
	end
	return 1
end

-- Entend-il la cible ? Rayon d'ouïe réduit proportionnellement au bruit.
function Guard.hears(dist, noise, hearRadius)
	return noise > 0 and dist <= hearRadius * noise
end

-- Perception complète : { sees, hears, dist }. g = { x, z, fx, fz }, t = { x, z, speed }, rival = { viewDist, viewAngle, hearRadius }.
function Guard.perceive(g, t, rival, cfg)
	local d = len(t.x - g.x, t.z - g.z)
	return { sees = Guard.sees(g, t, rival.viewDist, rival.viewAngle), hears = Guard.hears(d, Guard.noise(t.speed, cfg), rival.hearRadius), dist = d }
end

-- Machine à états. st = { state, timer, lost } ; percept = { sees, hears, atHome, dist } ; retourne le nouvel état (nouvelle table) et un événement
-- éventuel : "alert" (intrigué), "spotted" (poursuite), "lost" (cible perdue), "calm" (retour au calme).
--   patrol  : voit -> alert ; entend -> alert
--   alert   : s'arrête et regarde ; voit pendant alertDelay -> chase ; ne perçoit plus alertMax secondes -> return
--   chase   : voit ou entend -> poursuite continue ; ne perçoit plus -> lostChase ; trop loin (giveUpDist) -> return
--   lostChase : continue vers la dernière position connue loseDelay secondes (perte de cible), retrouve la cible -> chase, sinon -> return
--   return  : revient à la patrouille ; en route, voit -> alert
function Guard.nextState(st, dt, p, cfg)
	local s, timer, lost = st.state, st.timer or 0, st.lost or 0
	local event = nil
	if s == "patrol" then
		if p.sees or p.hears then
			s, timer, event = "alert", 0, "alert"
		end
	elseif s == "alert" then
		if p.sees then
			timer = timer + dt
			if timer >= cfg.alertDelay then
				s, timer, lost, event = "chase", 0, 0, "spotted"
			end
		elseif p.hears then
			timer = math.max(0, timer - dt * 0.25) -- bruit seul : reste méfiant mais ne poursuit pas
		else
			timer = timer + dt
			if timer >= cfg.alertMax then
				s, timer, event = "return", 0, "calm"
			end
		end
	elseif s == "chase" then
		if p.dist > cfg.giveUpDist then
			s, lost, event = "return", 0, "lost"
		elseif p.sees or p.hears then
			lost = 0
		else
			s, lost = "lostChase", 0
		end
	elseif s == "lostChase" then
		if p.sees or p.hears then
			s, lost, event = "chase", 0, "spotted"
		else
			lost = lost + dt
			if lost >= cfg.loseDelay then
				s, lost, event = "return", 0, "lost"
			end
		end
	else -- return
		if p.sees then
			s, timer, event = "alert", 0, "alert"
		elseif p.atHome then
			s, timer, event = "patrol", 0, "calm"
		end
	end
	return { state = s, timer = timer, lost = lost }, event
end

-- Dégâts : retourne (nouveaux points de vie, touché ?, invulnérabilité restante). Pendant l'invulnérabilité ou si hp <= 0 : aucun dégât.
function Guard.applyDamage(hp, damage, iframes, cfg)
	if iframes > 0 or hp <= 0 or damage <= 0 then
		return hp, false, iframes
	end
	return math.max(0, hp - damage), true, cfg.iframes
end

-- Régénération : après regenDelay secondes sans coup, regenPerSec par seconde (baseRegen par seconde dans la base du joueur). Plafonnée à maxHp.
-- Ramène (x, z) dans le disque de centre (cx, cz) et de rayon `radius` (territoire : le gardien ne quitte jamais son plateau ni ne traverse la douve).
function Guard.clampToDisc(x, z, cx, cz, radius)
	local dx, dz = x - cx, z - cz
	local d = len(dx, dz)
	if d <= radius or d < 1e-9 then
		return x, z
	end
	return cx + dx / d * radius, cz + dz / d * radius
end

-- Détection d'un gardien bloqué : `tr` = { t = 0 } conservé par gardien. Renvoie true quand il devrait bouger (want) mais avance de moins de cfg.stuckSpeed studs/s
-- depuis cfg.stuckSeconds secondes ; tout mouvement ou toute immobilité voulue (alerte) remet le compteur à zéro.
function Guard.stuckStep(tr, dt, moved, want, cfg)
	if not want or moved > cfg.stuckSpeed * dt then
		tr.t = 0
		return false
	end
	tr.t = tr.t + dt
	if tr.t >= cfg.stuckSeconds then
		tr.t = 0
		return true
	end
	return false
end

-- Pose de marche procédurale : rebond vertical et roulis en marchant (selon la vitesse), respiration à l'arrêt. `t` en secondes. Retourne (y, roulis en radians).
function Guard.walkPose(t, speed)
	if speed > 0.5 then
		local ph = t * speed * 0.9
		return math.abs(math.sin(ph)) * math.min(0.35, 0.04 * speed), math.sin(ph) * 0.06
	end
	return math.sin(t * 2) * 0.04, 0
end

-- Vigilance d'un territoire (Config.VIGILANCE) : `steals` = horodatages (s) des vols réussis dans CE territoire. Bonus de vue et d'ouïe = perSteal par vol
-- des `window` dernières secondes, plafonné à `max` ; retour à zéro `decay` secondes après le dernier vol. Retourne un nombre (0 .. max).
function Guard.vigilance(steals, now, cfg)
	local last, n = nil, 0
	for _, t in ipairs(steals) do
		if t <= now then
			if now - t <= cfg.window then
				n = n + 1
			end
			if last == nil or t > last then
				last = t
			end
		end
	end
	if last == nil or now - last >= cfg.decay then
		return 0
	end
	return math.min(cfg.max, n * cfg.perSteal)
end

-- Retire les vols trop anciens pour compter (hors de la fenêtre) : la liste ne grossit jamais. Retourne la nouvelle liste.
function Guard.vigilancePrune(steals, now, cfg)
	local out = {}
	for _, t in ipairs(steals) do
		if now - t <= cfg.window then
			out[#out + 1] = t
		end
	end
	return out
end

-- Réglages de perception majorés par la vigilance (vue et ouïe x (1 + bonus)) ; l'angle de vue ne change pas. Nouvelle table.
function Guard.boosted(rival, bonus)
	return { viewDist = rival.viewDist * (1 + bonus), viewAngle = rival.viewAngle, hearRadius = rival.hearRadius * (1 + bonus) }
end

function Guard.regen(hp, sinceHit, dt, atBase, cfg)
	if hp <= 0 or hp >= cfg.maxHp then
		return math.min(hp, cfg.maxHp)
	end
	local rate = atBase and cfg.baseRegen or (sinceHit >= cfg.regenDelay and cfg.regenPerSec or 0)
	return math.min(cfg.maxHp, hp + rate * dt)
end

return Guard

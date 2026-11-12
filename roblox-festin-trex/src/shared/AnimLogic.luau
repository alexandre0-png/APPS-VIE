--!nonstrict
-- Logique pure des animations (testable hors Studio) : activation par Config.Animations,
-- exécution protégée (pcall) et fonctions de courbes/angles.

local AnimLogic = {}

function AnimLogic.enabled(cfg: any, key: string): boolean
	return type(cfg) == "table" and cfg.Enabled == true and cfg[key] == true
end

-- Exécute fn(...) seulement si l'animation `key` est active ; une erreur est capturée (le jeu continue).
function AnimLogic.run(cfg: any, key: string, fn: (...any) -> (), ...: any): boolean
	if not AnimLogic.enabled(cfg, key) then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[FestinTRex] animation « " .. key .. " » : " .. tostring(err))
	end
	return ok
end

-- Rebond classique (0 -> 1) avec plusieurs rebonds amortis.
function AnimLogic.bounceOut(t: number): number
	t = math.clamp(t, 0, 1)
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	end
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375
end

function AnimLogic.easeOutBack(t: number): number
	t = math.clamp(t, 0, 1)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- Hauteur d'un objet qui rebondit : 0 en t=0, amortie, 0 en t=1.
function AnimLogic.bounceHeight(t: number, bounces: number, peak: number): number
	t = math.clamp(t, 0, 1)
	local decay = (1 - t) ^ 2
	return math.abs(math.sin(t * math.pi * bounces)) * peak * decay
end

-- Cap (yaw) pour qu'une tête en (hx,hz) regardant vers +Z se tourne vers (tx,tz), borné à ±maxAngle.
-- Une cible derrière la tête ne la tourne pas.
function AnimLogic.aimYaw(hx: number, hz: number, tx: number, tz: number, maxAngle: number): number
	local dx, dz = tx - hx, tz - hz
	if dz <= 0.001 then
		return 0
	end
	return math.clamp(math.atan2(dx, dz), -maxAngle, maxAngle)
end

-- Levée de patte d'un cycle de marche sur place : jamais négative (la patte ne passe pas sous le sol).
function AnimLogic.stompLift(t: number, amplitude: number, speed: number, phase: number): number
	return amplitude * math.max(0, math.sin(t * speed + phase))
end

return AnimLogic

--[[
	AnimMath : fonctions pures des animations (testables sans Roblox).
]]

local AnimMath = {}

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

-- Roulis de caméra en degrés selon le braquage (-1..1) et la vitesse ; 0 à l'arrêt ; vers l'intérieur du virage
function AnimMath.leanDegrees(steer, speed, maxSpeed, maxDeg)
	if maxSpeed <= 0 then
		return 0
	end
	local ratio = clamp(math.abs(speed) / maxSpeed, 0, 1.3)
	local speedFactor = clamp((math.abs(speed) - 8) / 30, 0, 1) * ratio
	return clamp(steer, -1, 1) * maxDeg * speedFactor
end

-- Tangage de suspension en degrés : la caméra plonge au freinage, se cabre à l'accélération (accel en studs/s²)
function AnimMath.pitchDegrees(accel, maxDeg)
	return clamp(-accel / 90, -1, 1) * maxDeg * -1
end

-- Dérapage stylisé : fort braquage à grande vitesse. Retourne (actif, intensité 0..1)
function AnimMath.drift(steer, speed, maxSpeed, steerThreshold, speedRatio)
	if maxSpeed <= 0 then
		return false, 0
	end
	local s = math.abs(steer)
	local r = math.abs(speed) / maxSpeed
	if s >= steerThreshold and r >= speedRatio then
		local intensity = clamp(((s - steerThreshold) / (1 - steerThreshold + 1e-6)) * 0.5 + (r - speedRatio) * 1.2, 0.15, 1)
		return true, intensity
	end
	return false, 0
end

-- Effet de démarrage : accélération franche depuis (presque) l'arrêt
function AnimMath.launch(prevSpeed, speed, throttle)
	return throttle > 0.6 and prevSpeed < 6 and speed - prevSpeed > 1.5
end

-- Rebond "pop" (easeOutBack) de 0 à 1 : t dans [0,1]
function AnimMath.popScale(t)
	t = clamp(t, 0, 1)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- Machine à écrire (UTF-8 sûr) : texte visible à l'instant t pour cps caractères/s
function AnimMath.typewriter(text, t, cps)
	local n = utf8.len(text) or #text
	local shown = clamp(math.floor(t * cps), 0, n)
	if shown >= n then
		return text
	end
	if shown <= 0 then
		return ""
	end
	local byte = utf8.offset(text, shown + 1)
	return text:sub(1, (byte or #text + 1) - 1)
end

-- Lissage exponentiel indépendant du framerate
function AnimMath.smooth(current, target, dt, rate)
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Angle de la porte (degrés) à l'instant t pour une ouverture puis fermeture sur `duration` secondes
function AnimMath.doorAngle(t, duration, openDeg)
	if duration <= 0 then
		return 0
	end
	local p = clamp(t / duration, 0, 1)
	if p < 0.4 then
		return openDeg * (p / 0.4)
	elseif p < 0.6 then
		return openDeg
	end
	return openDeg * (1 - (p - 0.6) / 0.4)
end

return AnimMath

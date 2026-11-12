--[[
  Motion : calculs purs des animations (sans objet Roblox) : balancement, respiration, secousse,
  battements de paupières, ouverture de couvercle, balancement de lampe.
  Ces fonctions ne font qu'un calcul : elles sont testées en Python (tools/lua/test_motion.py).
]]
local Motion = {}

local TAU = math.pi * 2

local function clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

-- Décélération en fin de mouvement : 0 au départ, 1 à l'arrivée
function Motion.easeOut(progress)
	local p = clamp01(progress)
	return 1 - (1 - p) ^ 3
end

-- Balancement de marche : oscillation verticale, nulle à l'arrêt
function Motion.bob(time, moving, amplitude)
	if not moving then
		return 0
	end
	return amplitude * math.sin(time * TAU * 1.8)
end

-- Respiration à l'arrêt : montée et descente lente, entre 0 et amplitude
function Motion.breath(time, amplitude)
	return amplitude * (0.5 - 0.5 * math.cos(time * TAU / 4))
end

-- Secousse décroissante (jumpscare, débusquage) : nulle après duration secondes
function Motion.shake(elapsed, duration, strength)
	if elapsed < 0 or duration <= 0 or elapsed >= duration then
		return 0
	end
	local decay = 1 - elapsed / duration
	return strength * decay * math.sin(elapsed * 45)
end

-- Réveil : battements de paupières. Chaque étape = { transparence du voile, part de la durée }.
-- La transparence est 0 (noir) à 1 (vue claire). La dernière étape est claire.
local BLINK = {
	{ 0.55, 0.18 },
	{ 0.00, 0.10 },
	{ 0.70, 0.20 },
	{ 0.00, 0.10 },
	{ 0.35, 0.15 },
	{ 1.00, 0.27 },
}

-- Étapes avec durées en secondes, qui totalisent exactement duration
function Motion.blinkSteps(duration)
	local steps = {}
	local total = 0
	for _, s in ipairs(BLINK) do
		total = total + s[2]
	end
	for i, s in ipairs(BLINK) do
		steps[i] = { transparency = s[1], seconds = duration * s[2] / total }
	end
	return steps
end

-- Couvercle : angle atteint à une progression donnée, en degrés (signe négatif = ouverture)
function Motion.lidAngle(progress, maxAngle)
	return maxAngle * Motion.easeOut(progress)
end

-- Lampe : balancement lent autour de la verticale, en degrés
function Motion.swayAngle(time, maxAngle, period)
	return maxAngle * math.sin(time * TAU / (period or 5))
end

return Motion

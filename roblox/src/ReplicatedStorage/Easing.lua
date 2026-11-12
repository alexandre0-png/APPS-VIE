-- ModuleScript : ReplicatedStorage/Shared/Easing
-- Fonctions d'animation PURES (aucun service Roblox, aucun Instance) : courbes, squash & stretch, rebonds, clignements, regards,
-- paramètres de confettis et garde-fou d'exécution. Testées hors de Roblox (tests/run.luau). Le client (Animations.client.lua)
-- ne fait qu'appliquer ces valeurs aux objets.
local Easing = {}

local pi, sin, cos, exp, abs, floor, sqrt = math.pi, math.sin, math.cos, math.exp, math.abs, math.floor, math.sqrt

local function clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end
Easing.clamp01 = clamp01

local function frac(x)
	return x - floor(x)
end

function Easing.lerp(a, b, t)
	return a + (b - a) * t
end

-- Courbes classiques (entrée et sortie dans [0, 1]) ---------------------------------------------------------------
function Easing.outQuad(x)
	x = clamp01(x)
	return 1 - (1 - x) * (1 - x)
end

function Easing.outBack(x)
	x = clamp01(x)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function Easing.outElastic(x)
	x = clamp01(x)
	if x == 0 or x == 1 then
		return x
	end
	return 2 ^ (-10 * x) * sin((x * 10 - 0.75) * (2 * pi) / 3) + 1
end

function Easing.outBounce(x)
	x = clamp01(x)
	local n1, d1 = 7.5625, 2.75
	if x < 1 / d1 then
		return n1 * x * x
	elseif x < 2 / d1 then
		x = x - 1.5 / d1
		return n1 * x * x + 0.75
	elseif x < 2.5 / d1 then
		x = x - 2.25 / d1
		return n1 * x * x + 0.9375
	end
	x = x - 2.625 / d1
	return n1 * x * x + 0.984375
end

-- Squash & stretch : au temps t (0 -> 1), retourne (sx, sy) à appliquer en largeur et en hauteur.
-- Part écrasé (sy < 1, sx > 1), puis s'étire, puis oscille de moins en moins jusqu'à (1, 1). Toujours strictement positif.
function Easing.squashStretch(t, strength)
	if t >= 1 then
		return 1, 1
	end
	if t < 0 then
		t = 0
	end
	local amp = (strength or 0.4) * exp(-5 * t) * cos(14 * t)
	return math.max(0.2, 1 + amp * 0.6), math.max(0.2, 1 - amp)
end

-- Petit saut d'un œuf toutes les `period` secondes. Retourne (décalage vertical >= 0, sx, sy).
-- Étirement en l'air, écrasement à l'atterrissage ; hors du saut : (0, 1, 1).
function Easing.eggHop(time, phase, height, period)
	period = period or 3.2
	height = height or 0.6
	local u = ((time + (phase or 0)) % period) / 0.6 -- le saut dure 0,6 s
	if u >= 1 then
		return 0, 1, 1
	end
	local y = height * sin(u * pi)
	local sy = 1 + 0.15 * sin(u * pi)
	if u > 0.85 then
		sy = 1 - 0.12 * sin((u - 0.85) / 0.15 * pi)
	end
	return y, 1 / sqrt(sy), sy
end

-- Balancement d'un œuf porté pendant la course (décalage vertical >= 0).
function Easing.runBounce(time, moving)
	if not moving then
		return 0
	end
	return 0.25 * abs(sin(time * 8))
end

-- Clignement : 1 = œil ouvert, 0 = fermé. Bref (0,16 s) à intervalle irrégulier propre à chaque `seed`.
function Easing.blinkOpenness(time, seed)
	seed = seed or 0
	local period = 2.6 + (seed % 7) * 0.37
	local ph = (time + seed * 0.53) % period
	local d = 0.16
	if ph < d then
		return 1 - sin(ph / d * pi)
	end
	return 1
end

-- Regard : décalage (dx, dy) des yeux, dx dans [-0.85, 0.85], dy dans [-0.3, 0.3].
function Easing.look(time, seed)
	seed = seed or 0
	local dx = sin(time * 0.7 + seed) * 0.6 + sin(time * 1.9 + seed * 2) * 0.25
	local dy = sin(time * 0.5 + seed * 3) * 0.3
	return dx, dy
end

-- Bouche : ouverture dans [0, 1] ; elle « mâche » brièvement de temps en temps.
function Easing.mouthOpen(time, seed)
	seed = seed or 0
	local period = 4 + (seed % 5) * 0.6
	local ph = (time + seed * 0.9) % period
	if ph < 0.7 then
		return sin(ph / 0.7 * pi)
	end
	return 0
end

-- Pulsation d'une barrière de zone, dans [0, 1].
function Easing.gatePulse(time, speed)
	return 0.5 + 0.5 * sin(time * (speed or 2))
end

-- Récompenses : effets de confettis selon la clé de son envoyée avec la notification serveur. nil = pas de confettis.
Easing.REWARD = {
	claim = { count = 24, minSpeed = 160, maxSpeed = 340, life = 1.3 },
	event = { count = 40, minSpeed = 180, maxSpeed = 380, life = 1.5 },
	rare = { count = 70, minSpeed = 200, maxSpeed = 440, life = 1.7 },
}
function Easing.rewardBurst(sfx)
	return Easing.REWARD[sfx]
end

-- Secousse de caméra (champ de vision) selon la clé de son : delta en degrés, durée d'un aller en secondes.
Easing.FOV_KICK = {
	steal = { delta = 5, time = 0.14 },
	caught = { delta = -8, time = 0.2 },
}

-- Particule `i` d'une salve de `count` confettis : éventail vers le haut, déterministe (suite de la section d'or).
-- Retourne { angle (radians, 0 = droite, -pi/2 = haut), speed, spin (degrés/s), hue [0,1), w, h (pixels) }.
function Easing.confettiParticle(i, count, burst)
	local minSpeed, maxSpeed = burst.minSpeed, burst.maxSpeed
	return {
		angle = -pi / 2 + (frac(i * 0.6180339887) - 0.5) * 1.8,
		speed = minSpeed + frac(i * 0.7548776662) * (maxSpeed - minSpeed),
		spin = (frac(i * 0.5698402910) - 0.5) * 720,
		hue = frac(i * 0.3819660113 + count * 0.01),
		w = 6 + floor(frac(i * 0.2599) * 7),
		h = 10 + floor(frac(i * 0.4143) * 9),
	}
end

-- Garde-fou d'une animation. isEnabled(name) -> bool ; failed : table partagée name -> true ; fn : l'animation (appelée sous pcall).
-- Une animation désactivée n'est pas exécutée. Une animation qui lève une erreur est désactivée pour le reste de la session
-- (onError(name, err) est appelé une seule fois). Retourne true si fn s'est exécutée sans erreur.
function Easing.guard(isEnabled, failed, name, fn, onError)
	if failed[name] or not isEnabled(name) then
		return false
	end
	local ok, err = pcall(fn)
	if not ok then
		failed[name] = true
		if onError then
			onError(name, err)
		end
	end
	return ok
end

return Easing

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
function Easing.inOutSine(x)
	x = clamp01(x)
	return -(cos(pi * x) - 1) / 2
end

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
		return clamp01(1 - sin(ph / d * pi)) -- bornée : sin(pi) vaut ±1e-16 selon le moteur
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

-- Poule : coups de bec doubles à intervalle irrégulier. Retourne l'enfoncement de la tête dans [0, 1].
function Easing.peck(time, seed)
	seed = seed or 0
	local period = 3.4 + (seed % 5) * 0.5
	local ph = (time + seed * 0.7) % period
	if ph < 0.25 then
		return clamp01(sin(ph / 0.25 * pi))
	elseif ph < 0.5 then
		return clamp01(sin((ph - 0.25) / 0.25 * pi))
	end
	return 0
end

-- Pulsation d'une barrière de zone, dans [0, 1].
-- Échelle du pet qui apparaît à l'éclosion (a = progression 0..1) : part de 25 %, ne dépasse jamais `cap` et vaut exactement 1 à la fin.
function Easing.popScale(a, squash, cap)
	cap = cap or 1.15
	if a >= 1 then
		return 1
	end
	local scale
	if squash then
		local _, sy = Easing.squashStretch(a, 0.45)
		scale = (0.25 + 0.75 * Easing.outQuad(math.min(1, a * 1.8))) * sy
	else
		scale = 0.25 + 0.75 * Easing.outBack(a)
	end
	return math.min(cap, math.max(0.05, scale))
end

-- États des pets : idle (respiration), move (bonds penchés vers l'avant), ability (saut en vrille). Retourne { y, pitch, yaw, scale } ;
-- state "ability" attend p = progression 0..1 de la capacité (Easing.abilityProgress). Toutes les valeurs sont bornées.
function Easing.petPose(state, t, seed, p)
	seed = seed or 0
	if state == "move" then
		return { y = abs(sin(t * 9 + seed)) * 0.7, pitch = -0.18, yaw = sin(t * 9 + seed) * 0.08, scale = 1 }
	elseif state == "ability" then
		local q = clamp01(p or 0)
		return { y = sin(q * pi) * 1.8, pitch = 0, yaw = q * 2 * pi, scale = 1 + 0.25 * sin(q * pi) }
	end
	return { y = sin(t * 3 + seed) * 0.25, pitch = 0, yaw = sin(t * 0.8 + seed) * 0.12, scale = 1 }
end

-- Progression 0..1 de la capacité d'un pet (durée `window` s toutes les `interval` s environ, décalée par seed), nil hors capacité.
function Easing.abilityProgress(t, seed, interval, window)
	window = window or 1.1
	local period = (interval or 9) + ((seed or 0) % 5)
	if period <= window then
		return nil
	end
	local phase = (t + (seed or 0) * 1.3) % period
	if phase < window then
		return phase / window
	end
	return nil
end

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

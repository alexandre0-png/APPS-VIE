-- Mathématiques des animations (pures : testées avec Lune). Aucun appel à l'API Roblox ici.
-- Les valeurs renvoyées sont appliquées par Fx (serveur), CreatureFx, Anim et HUD (client).

local AnimMath = {}

local TAU = math.pi * 2

function AnimMath.clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

function AnimMath.lerp(a, b, t)
	return a + (b - a) * t
end

function AnimMath.easeOutQuad(t)
	t = AnimMath.clamp01(t)
	return 1 - (1 - t) * (1 - t)
end

function AnimMath.easeInOut(t)
	t = AnimMath.clamp01(t)
	return t * t * (3 - 2 * t)
end

-- Dépassement léger puis retour : sert aux « pop » joyeux.
function AnimMath.easeOutBack(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- Proportion d'animal « en l'air » (0 = au sol, 1 = pleinement replié) selon la hauteur au-dessus du sol (studs).
function AnimMath.tuck(lift)
	return AnimMath.clamp01((lift or 0) / 1.2)
end

-- Angle d'une patte : trot au sol, pattes repliées en l'air, plus ample quand l'animal est joyeux (joy 0..1).
function AnimMath.gait(t, freq, phase, lift, joy)
	local swing = math.sin(t * freq + phase) * 0.7 * (1 + 0.5 * (joy or 0))
	return AnimMath.lerp(swing, -0.9, AnimMath.tuck(lift))
end

-- Battement d'aile : plus rapide en vitesse, amplitude constante.
function AnimMath.flap(t, speed)
	return math.sin(t * (6 + (speed or 40) * 0.05)) * 0.55
end

-- Échelle du cœur qui apparaît (0 -> 1 avec dépassement) sur `duration` secondes.
function AnimMath.heartPop(t, duration)
	return AnimMath.easeOutBack((t or 0) / (duration or 0.45))
end

-- Capture : p de 0 à 1. Renvoie montée (studs), rotation (rad) et petit rebond.
function AnimMath.capture(p)
	p = AnimMath.clamp01(p)
	return AnimMath.easeOutQuad(p) * 16, TAU * 2 * p, math.sin(p * math.pi) * 3
end

-- Joie : décalage vertical (rebonds qui s'amortissent) et lacet (un tour complet) à t secondes sur `duration`.
function AnimMath.joy(t, duration)
	duration = duration or 2.5
	if t < 0 or t > duration then
		return 0, 0
	end
	local fade = 1 - t / duration
	return math.abs(math.sin(t * 7)) * 2.2 * fade, TAU * AnimMath.easeInOut(t / 1.2)
end

-- Lasso : p de 0 à 1. La corde ondule (courbe) puis se tend (largeur) ; la boucle se resserre autour de l'animal.
function AnimMath.lassoCurve(p)
	p = AnimMath.clamp01(p)
	return 12 * (1 - p), 0.25 + 0.3 * p
end

function AnimMath.loopRadius(p, startRadius, endRadius)
	return AnimMath.lerp(startRadius, endRadius, AnimMath.easeOutQuad(p))
end

-- Bras du joueur qui lance : angle d'épaule à t secondes (0.3 s : armer puis lancer).
function AnimMath.throwArm(t)
	if t < 0 or t > 0.3 then
		return 0
	end
	if t < 0.12 then
		return -2.4 * (t / 0.12)
	end
	return -2.4 + 3.6 * ((t - 0.12) / 0.18)
end

-- Balayage de couleur entre zones : p de 0 à 1. Renvoie position de départ du bandeau (-1 à 1) et opacité.
function AnimMath.wipe(p)
	p = AnimMath.clamp01(p)
	local alpha = 0.55 * (1 - math.abs(p * 2 - 1))
	return AnimMath.lerp(-1, 1, AnimMath.easeInOut(p)), alpha
end

-- Étoiles qui tournent autour de la tête (étourdi) : décalage x, z de l'étoile i sur n à t secondes.
function AnimMath.orbit(t, i, n, radius)
	local angle = t * 5 + (i / n) * TAU
	return math.cos(angle) * radius, math.sin(angle) * radius
end

-- Nuage de fumée : échelle et transparence à p de 0 à 1.
function AnimMath.poof(p)
	p = AnimMath.clamp01(p)
	return 1 + 2.5 * AnimMath.easeOutQuad(p), p
end

-- Piétinement d'un boss : à-coups verticaux réguliers (age en secondes).
function AnimMath.bossStomp(age)
	return math.abs(math.sin(age * 3)) * 1.2
end

-- Vue d'ensemble d'une zone au départ : p de 0 à 1 ; renvoie progression adoucie et hauteur de caméra.
function AnimMath.flyover(p)
	p = AnimMath.clamp01(p)
	local e = AnimMath.easeInOut(p)
	return e, AnimMath.lerp(60, 14, e)
end

-- Coup de zoom : champ de vision ajouté à t secondes sur `duration` (monte vite, redescend doucement).
function AnimMath.fovPunch(t, duration, amount)
	if t < 0 or t > duration then
		return 0
	end
	local p = t / duration
	if p < 0.2 then
		return amount * (p / 0.2)
	end
	return amount * (1 - (p - 0.2) / 0.8)
end

return AnimMath

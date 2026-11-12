-- Anim.luau : fonctions d'animation pures (testables hors Roblox) et garde-fous.
-- Chaque animation est activable dans Config.Animations et exécutée dans un pcall :
-- une animation qui échoue ne casse jamais le jeu.

local Config = require(script.Parent.Config)

local Anim = {}

function Anim.enabled(name)
	local a = Config.Animations
	return a.master ~= false and a[name] == true
end

-- Exécute fn(...) seulement si l'animation est active ; capture toute erreur. Retourne true si fn a réussi.
function Anim.run(name, fn, ...)
	if not Anim.enabled(name) then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Anim] " .. name .. " : " .. tostring(err))
	end
	return ok
end

function Anim.clamp01(t)
	if t < 0 then
		return 0
	elseif t > 1 then
		return 1
	end
	return t
end

function Anim.easeOutCubic(t)
	t = Anim.clamp01(t)
	return 1 - (1 - t) ^ 3
end

function Anim.easeOutBack(t)
	t = Anim.clamp01(t)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function Anim.easeInOutSine(t)
	t = Anim.clamp01(t)
	return -(math.cos(math.pi * t) - 1) / 2
end

-- Respiration : oscillation lente autour de 0, amplitude amp
function Anim.breath(t, phase, amp)
	return math.sin(t * 1.6 + phase) * amp
end

-- Saut : t dans [0,1] -> hauteur (0 au début et à la fin)
function Anim.hop(t, height)
	t = Anim.clamp01(t)
	return math.sin(math.pi * t) * height
end

-- Série de n sauts sur la durée totale : hauteur à l'instant elapsed (0 hors fenêtre)
function Anim.hops(elapsed, total, n, height)
	if elapsed < 0 or elapsed >= total then
		return 0
	end
	local per = total / n
	return Anim.hop((elapsed % per) / per, height)
end

-- Compteur animé : valeur affichée entre from et to à la progression t
function Anim.counter(from, to, t)
	return from + (to - from) * Anim.easeOutCubic(t)
end

-- Fossile qui apparaît : retourne décalage vertical et transparence (t dans [0,1])
function Anim.fossilRise(t)
	t = Anim.clamp01(t)
	local y = Anim.easeOutBack(math.min(1, t * 1.6)) * 2.2
	local alpha = t < 0.7 and 0 or (t - 0.7) / 0.3
	return y, alpha
end

-- Porte qui s'ouvre : fraction d'ouverture (0 fermée, 1 ouverte)
function Anim.door(t)
	return Anim.easeInOutSine(t)
end

return Anim

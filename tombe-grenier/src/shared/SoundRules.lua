--[[
  SoundRules : choix des sons selon l'état du joueur et du monstre (logique pure, testée).
  Aucun appel Roblox : le client et le serveur lui passent des nombres.
]]
local SoundRules = {}

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

-- Volume du battement de cœur : plus fort quand le monstre est proche ou en poursuite, jamais au-delà de max.
-- distance : studs jusqu'au monstre (nil = inconnu) ; near : portée en studs ; chasing : booléen ; lowSanity : booléen.
function SoundRules.heartVolume(distance, near, chasing, lowSanity, max)
	max = max or 0.7
	local v = 0
	if typeof(distance) == "number" and distance < near then
		v = (1 - distance / near) * max
	end
	if chasing then
		v = math.max(v, max * 0.7)
	end
	if lowSanity then
		v = math.max(v, max * 0.35)
	end
	return clamp(v, 0, max)
end

-- Volume du murmure : seulement quand le monstre est proche (portée near), pas pendant la poursuite.
function SoundRules.murmurVolume(distance, near, chasing, max)
	max = max or 0.35
	if chasing or typeof(distance) ~= "number" or distance >= near then
		return 0
	end
	return clamp((1 - distance / near) * max, 0, max)
end

-- Pas du joueur. s : { speed, climbing (vitesse verticale absolue), grounded, sprint, quiet, crouch }.
-- Retourne la clé du son et l'intervalle en secondes, ou nil (immobile, en l'air, mode silencieux, accroupi).
function SoundRules.footstep(s)
	if not s.grounded or s.quiet or s.crouch then
		return nil
	end
	if typeof(s.speed) ~= "number" or s.speed < 2 then
		return nil
	end
	if typeof(s.climbing) == "number" and s.climbing > 1.5 then
		return "marche_escalier", 0.45
	end
	if s.sprint then
		return "pas_courses", 0.32
	end
	return "pas_bois", 0.5
end

-- Volume final : base du manifeste, réduit par le mode silencieux, borné.
function SoundRules.scaled(base, quiet)
	local v = base or 0.5
	if quiet then
		v = v * 0.4
	end
	return clamp(v, 0, 1)
end

-- Un objet ramassé : l'un des compteurs de l'inventaire a augmenté (ou une clé est apparue).
function SoundRules.pickedUp(before, after)
	if typeof(before) ~= "table" or typeof(after) ~= "table" then
		return false
	end
	for _, key in ipairs({ "photos", "docs" }) do
		if (after[key] or 0) > (before[key] or 0) then
			return true
		end
	end
	for _, key in ipairs({ "hasKey", "smallKey", "caveKey" }) do
		if after[key] == true and before[key] ~= true then
			return true
		end
	end
	return false
end

return SoundRules

--[[
  CinematicTimeline : calculs purs des cinématiques (sans objet Roblox).
  Un plan est { t = durée en secondes, ... }. La timeline d'une cinématique est la suite de ses plans.
  Testé par tools/lua/test_cinematic.py.
]]
local CinematicTimeline = {}

-- Durée totale d'une suite de plans
function CinematicTimeline.total(plans)
	local sum = 0
	for _, plan in ipairs(plans) do
		sum = sum + plan.t
	end
	return sum
end

-- Plan en cours au temps elapsed : index du plan et temps écoulé dans ce plan.
-- Retourne nil une fois la cinématique terminée (ou pour un temps négatif).
function CinematicTimeline.locate(plans, elapsed)
	if elapsed < 0 then
		return nil
	end
	local start = 0
	for i, plan in ipairs(plans) do
		if elapsed < start + plan.t then
			return i, elapsed - start
		end
		start = start + plan.t
	end
	return nil
end

-- Cinématique passée : le temps restant est nul, et la reprise ne rejoue rien
function CinematicTimeline.remaining(plans, elapsed)
	return math.max(0, CinematicTimeline.total(plans) - math.max(0, elapsed))
end

return CinematicTimeline

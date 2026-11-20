--[[
  MonsterSway : balancement et inclinaison de la silhouette du monstre selon son allure (logique pure, testée).
  Aucune animation de squelette : la silhouette « Ombre rampante » se balance autour de son pivot.
  pose(allure, t) retourne { roll, pitch, bob } : roulis et tangage en radians, hauteur en studs.
  Allures : "immobile" (respiration lente), "marche" (balancement latéral), "course" (penché en avant, ample).
]]
local MonsterSway = {}

local TAU = 2 * math.pi

-- Fréquence (Hz), roulis maximal, tangage fixe (degrés), hauteur de rebond (studs) par allure
MonsterSway.GAITS = {
	immobile = { freq = 0.3, roll = 1.5, pitch = 0, bob = 0.04 },
	marche = { freq = 1.7, roll = 5, pitch = 4, bob = 0.12 },
	course = { freq = 2.8, roll = 8, pitch = 16, bob = 0.2 },
}

function MonsterSway.pose(gait, t)
	local g = MonsterSway.GAITS[gait] or MonsterSway.GAITS.immobile
	local phase = TAU * g.freq * t
	return {
		roll = math.rad(g.roll) * math.sin(phase),
		pitch = math.rad(g.pitch),
		bob = g.bob * math.abs(math.sin(phase / 2)),
	}
end

return MonsterSway

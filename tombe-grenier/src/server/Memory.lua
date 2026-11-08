--[[
  Memory : ce que le monstre retient des habitudes du joueur.
  - Pièces souvent visitées : le monstre patrouille plus volontiers dans ces pièces.
  - Cachettes souvent utilisées : le monstre les inspecte en premier pendant ses recherches.
  La mémoire survit d'une partie à l'autre tant que le serveur tourne (session).
]]
local Memory = {}

local roomVisits = {}
local spotUses = {}

function Memory.visit(roomId)
	if roomId then
		roomVisits[roomId] = (roomVisits[roomId] or 0) + 1
	end
end

function Memory.spotUsed(spotName)
	if spotName then
		spotUses[spotName] = (spotUses[spotName] or 0) + 1
	end
end

-- Poids d'une pièce pour le choix des patrouilles (1 = inconnue, jusqu'à 4)
function Memory.roomWeight(roomId)
	if not roomId then
		return 1
	end
	return math.min(4, 1 + (roomVisits[roomId] or 0) * 0.25)
end

-- Poids d'une cachette pour l'ordre d'inspection (1 = jamais utilisée, jusqu'à 4)
function Memory.spotWeight(spotName)
	return math.min(4, 1 + (spotUses[spotName] or 0) * 0.5)
end

return Memory

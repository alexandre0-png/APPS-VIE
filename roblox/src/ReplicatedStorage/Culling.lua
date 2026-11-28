-- ModuleScript : ReplicatedStorage/Shared/Culling
-- Masquage des zones éloignées, côté client, SANS toucher à StreamingEnabled : logique PURE testée hors de Roblox. Une zone (domaine : plateau et contenu) plus
-- loin que `cullAt` du joueur est masquée (transparence locale, lumières, particules et étiquettes coupées) ; elle réapparaît en dessous de `showAt`
-- (hystérésis : pas de clignotement à la limite). Le travail est découpé en lots (`chunks`) pour ne jamais bloquer une image.
local Culling = {}

-- Retourne true si la zone doit être MASQUÉE. wasCulled : état actuel. Distance invalide (nil, NaN) : on ne masque rien (sûr).
function Culling.decide(distance, wasCulled, cullAt, showAt)
	if type(distance) ~= "number" or distance ~= distance then
		return false
	end
	if wasCulled then
		return distance > showAt
	end
	return distance > cullAt
end

-- Distance horizontale d'un point à une zone circulaire, bord compris (0 dans la zone).
function Culling.distanceTo(px, pz, zone)
	local d = math.sqrt((px - zone.x) ^ 2 + (pz - zone.z) ^ 2) - zone.radius
	return d > 0 and d or 0
end

-- Découpe une liste en lots de `size` éléments (au moins 1).
function Culling.chunks(list, size)
	size = math.max(1, math.floor(size or 1))
	local out = {}
	for i = 1, #list, size do
		local lot = {}
		for j = i, math.min(i + size - 1, #list) do
			lot[#lot + 1] = list[j]
		end
		out[#out + 1] = lot
	end
	return out
end

return Culling

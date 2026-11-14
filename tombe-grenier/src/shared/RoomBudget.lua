--[[
  RoomBudget : budget de lumière par pièce et placement des repères de sol (calculs purs, testés).
  - activeRooms : seules les pièces les plus proches du joueur gardent leur lueur allumée.
  - qualityLimits : nombre maximal de lueurs actives et réduction de portée selon le niveau de qualité.
  - landmarkSpot : position d'un repère de sol qui ne chevauche aucun meuble de la pièce.
]]
local RoomBudget = {}

-- Niveaux : "auto" se règle sur « moyen » (pas de mesure de performance côté serveur).
local LEVELS = {
	bas = { lights = 4, rangeScale = 0.6 },
	moyen = { lights = 8, rangeScale = 0.8 },
	haut = { lights = 14, rangeScale = 1.0 },
}

function RoomBudget.qualityLimits(name)
	if name == "auto" or LEVELS[name] == nil then
		return LEVELS.moyen
	end
	return LEVELS[name]
end

-- rooms : liste de { id, cx, cz, level }. player : { x, z, level }. Retourne les identifiants retenus,
-- du plus proche au plus éloigné. Une pièce d'un autre étage compte 1000 studs de plus.
function RoomBudget.activeRooms(rooms, player, maxLights)
	local scored = {}
	for _, r in ipairs(rooms) do
		local dx, dz = r.cx - player.x, r.cz - player.z
		local d = math.sqrt(dx * dx + dz * dz)
		if r.level ~= player.level then
			d = d + 1000
		end
		table.insert(scored, { id = r.id, d = d })
	end
	table.sort(scored, function(a, b)
		if a.d == b.d then
			return a.id < b.id
		end
		return a.d < b.d
	end)
	local out = {}
	for i = 1, math.min(maxLights, #scored) do
		table.insert(out, scored[i].id)
	end
	return out
end

local function overlaps(ax0, ax1, az0, az1, bx0, bx1, bz0, bz1, margin)
	return ax0 < bx1 + margin and ax1 > bx0 - margin and az0 < bz1 + margin and az1 > bz0 - margin
end

-- Repère de sol de taille (w, d) centré près de (cx, cz), à l'intérieur de la pièce, sans chevaucher
-- un meuble de même étage. Essaie le centre puis des décalages. Retourne x, z ou nil si aucun emplacement.
function RoomBudget.landmarkSpot(room, boxes, w, d)
	local offsets = { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 }, { 6, 6 }, { -6, 6 }, { 6, -6 }, { -6, -6 } }
	for _, o in ipairs(offsets) do
		local x, z = room.cx + o[1], room.cz + o[2]
		local inside = x - w / 2 >= room.x0 and x + w / 2 <= room.x1 and z - d / 2 >= room.z0 and z + d / 2 <= room.z1
		if inside then
			local clear = true
			for _, b in ipairs(boxes) do
				if overlaps(x - w / 2, x + w / 2, z - d / 2, z + d / 2, b.x0, b.x1, b.z0, b.z1, 0.5) then
					clear = false
					break
				end
			end
			if clear then
				return x, z
			end
		end
	end
	return nil
end

return RoomBudget

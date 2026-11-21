-- ModuleScript : ReplicatedStorage/Shared/MiniMap
-- Mini-carte : projection PURE (testée) d'un point du monde vers un disque centré sur le joueur, nord en haut (axe -Z vers le haut de l'écran).
-- `radius` = studs représentés du centre au bord, `half` = demi-taille du disque en pixels. Les repères importants (base, zones, portails) sont ramenés
-- au bord quand ils sont trop loin (`clamp`), les autres (gardiens) disparaissent hors du disque.
local MiniMap = {}

function MiniMap.place(px, pz, x, z, radius, half, clamp)
	if type(px) ~= "number" or type(pz) ~= "number" or type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z or px ~= px or pz ~= pz or radius <= 0 then
		return nil
	end
	local dx, dz = x - px, z - pz
	local d = math.sqrt(dx * dx + dz * dz)
	if d > radius then
		if not clamp then
			return nil
		end
		dx, dz = dx / d * radius, dz / d * radius
	end
	return dx / radius * half, dz / radius * half -- (droite, bas) en pixels depuis le centre
end

-- Repères du monde : { {kind, x, z, label, locked} } (base du joueur, zones, portails de voyage rapide). Pur : ne lit que Config et la position de la base.
function MiniMap.landmarks(Config, plotX, plotZ, chaptersDone)
	local out = {}
	if plotX then
		out[#out + 1] = { kind = "base", x = plotX, z = plotZ, label = "🏠" }
	end
	for i, riv in ipairs(Config.RIVALS) do
		local cx, cz = Config.rivalCenter(i)
		out[#out + 1] = { kind = "zone", x = cx, z = cz, label = riv.emoji, locked = not Config.zoneUnlocked(chaptersDone or 0, i) }
		local tx, tz = Config.travelPad(i)
		out[#out + 1] = { kind = "portal", x = tx, z = tz, label = "🌀" }
	end
	return out
end

return MiniMap

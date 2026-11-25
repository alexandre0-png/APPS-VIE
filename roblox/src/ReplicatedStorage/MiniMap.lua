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

-- Repères du monde : { {kind, x, z, label, locked} } (REFONTE lot 2) : ta base (🏠), les autres bases (kind « plot »), les territoires (zones ;
-- grisés si verrouillés), les portails de la rose (grisés si verrouillés). Pur : ne lit que Config et la position de la base.
function MiniMap.landmarks(Config, plotX, plotZ, chaptersDone)
	local out = {}
	if plotX then
		out[#out + 1] = { kind = "base", x = plotX, z = plotZ, label = "🏠" }
	end
	for _, b in ipairs(Config.Map2.bases) do
		if not (plotX and math.abs(b.x - plotX) < 1 and math.abs(b.z - plotZ) < 1) then
			out[#out + 1] = { kind = "plot", x = b.x, z = b.z, label = "⬜" }
		end
	end
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		local riv = Config.RIVALS[t.rival]
		out[#out + 1] = { kind = "zone", x = t.x, z = t.z, label = riv and riv.emoji or "🧺", locked = riv ~= nil and not Config.zoneUnlocked(chaptersDone or 0, t.rival), key = key }
	end
	for k = 1, #Config.TRAVEL2.portals do
		local px, pz = Config.portalPad(k)
		out[#out + 1] = { kind = "portal", x = px, z = pz, label = "🌀", locked = not Config.portalUnlocked(chaptersDone or 0, k) }
	end
	return out
end

-- Plumes dorées non ramassées à moins de `range` studs (icône 🪶, REFONTE lot 6). spots = { { x, z } } publiés par le serveur (étape 1 seulement).
function MiniMap.featherMarks(spots, px, pz, range)
	local out = {}
	if type(spots) ~= "table" or type(px) ~= "number" or type(pz) ~= "number" or px ~= px or pz ~= pz then
		return out
	end
	for _, sp in ipairs(spots) do
		if type(sp.x) == "number" and type(sp.z) == "number" then
			local dx, dz = sp.x - px, sp.z - pz
			if dx * dx + dz * dz <= range * range then
				out[#out + 1] = { kind = "feather", x = sp.x, z = sp.z, label = "🪶" }
			end
		end
	end
	return out
end

return MiniMap

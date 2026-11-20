--[[
  Zones : nom de la zone où se trouve le joueur (grenier, étage, rez-de-chaussée, cave, sous-sol, jardin) et
  annonceur de bannière (logique pure, testée). Une bannière n'apparaît qu'après une présence stable, jamais
  deux fois de suite pour la même zone, et pas plus d'une toutes les `spacing` secondes.
]]
local Zones = {}

Zones.INFO = {
	grenier = { title = "LE GRENIER", sub = "Tout a commencé ici", role = "option" },
	etage = { title = "L'ÉTAGE", sub = "Les chambres dorment, pas toi", role = "option" },
	rez = { title = "LE REZ-DE-CHAUSSÉE", sub = "La sortie est proche", role = "play" },
	cave = { title = "LA CAVE", sub = "Ça sent la terre et la peur", role = "danger" },
	sous_sol = { title = "LE SOUS-SOL", sub = "Chaque pas résonne", role = "danger" },
	jardin = { title = "LE JARDIN", sub = "L'air libre, pas la liberté", role = "save" },
}

-- Pièces du niveau du sous-sol qui forment la cave proprement dite
Zones.CAVE_ROOMS = { cave = true }

-- rooms : { { id, level, x0, z0, x1, z1 } }, base : { level = y du sol }, H : hauteur. Retourne l'identifiant de zone ou nil.
function Zones.at(rooms, base, H, x, y, z)
	for _, r in ipairs(rooms) do
		local floor = base[r.level]
		if floor and x >= r.x0 and x < r.x1 and z >= r.z0 and z < r.z1 and y >= floor - 1 and y < floor + H + 1 then
			if r.level == "attic" then
				return "grenier"
			elseif r.level == "first" then
				return "etage"
			elseif r.level == "ground" then
				return "rez"
			end
			return Zones.CAVE_ROOMS[r.id] and "cave" or "sous_sol"
		end
	end
	-- Hors de la maison : le jardin, ou l'escalier extérieur qui descend au sous-sol
	if y < (base.ground or 0) - 2 then
		return "sous_sol"
	end
	return "jardin"
end

-- Annonceur : update(zone, now) retourne l'identifiant à annoncer, ou nil.
-- settle : secondes de présence avant l'annonce ; spacing : secondes minimum entre deux annonces ; repeatAfter : secondes
-- avant de réannoncer une zone déjà annoncée (après être passé ailleurs).
function Zones.newAnnouncer(settle, spacing, repeatAfter)
	local self = { candidate = nil, since = 0, current = nil, lastAt = -1e9, announcedAt = {} }
	function self.update(zone, now)
		if zone == nil then
			self.candidate = nil
			return nil
		end
		if zone ~= self.candidate then
			self.candidate = zone
			self.since = now
			return nil
		end
		if zone == self.current then
			return nil
		end
		if now - self.since < settle then
			return nil
		end
		self.current = zone
		local previous = self.announcedAt[zone]
		if previous and now - previous < repeatAfter then
			return nil
		end
		if now - self.lastAt < spacing then
			-- trop tôt : on garde la zone en attente, elle sera annoncée dès que l'écart est respecté
			self.current = nil
			return nil
		end
		self.lastAt = now
		self.announcedAt[zone] = now
		return zone
	end
	return self
end

return Zones

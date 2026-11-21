--[[
  PerfRules : budgets de performance et règles de masquage des pièces (logique pure, testée).
  Les budgets sont ceux de Config.Perf ; le masquage de pièces garde visibles les pièces les plus proches du joueur
  (RoomBudget.activeRooms) et cache le décor des autres.
]]
local Shared = script.Parent
local Config = require(Shared.Config)
local RoomBudget = require(Shared.RoomBudget)

local PerfRules = {}

-- Un petit objet ne projette pas d'ombre : les ombres coûtent cher sur téléphone
PerfRules.SMALL_SHADOW = 3

function PerfRules.castsShadow(sx, sy, sz)
	return math.max(sx, sy, sz) >= PerfRules.SMALL_SHADOW
end

-- counts : { parts, lights, particles, halos } ; retourne la liste des dépassements (vide si tout va bien)
function PerfRules.violations(counts)
	local cfg = Config.Perf
	local out = {}
	if (counts.parts or 0) > cfg.MaxParts then
		table.insert(out, ("parts %d > %d"):format(counts.parts, cfg.MaxParts))
	end
	if (counts.lights or 0) > cfg.MaxLights then
		table.insert(out, ("lumières %d > %d"):format(counts.lights, cfg.MaxLights))
	end
	if (counts.particles or 0) > cfg.MaxParticles then
		table.insert(out, ("particules %d > %d"):format(counts.particles, cfg.MaxParticles))
	end
	if (counts.halos or 0) > cfg.MaxHalos then
		table.insert(out, ("halos %d > %d"):format(counts.halos, cfg.MaxHalos))
	end
	return out
end

-- Pièces dont le décor reste visible : la pièce du joueur puis les plus proches (même étage d'abord).
-- rooms : { { id, level, cx, cz } }, player : { x, z, level }. Retourne { [id] = true }.
function PerfRules.visibleRooms(rooms, player, count)
	local set = {}
	for _, id in ipairs(RoomBudget.activeRooms(rooms, player, count or Config.Perf.CullRooms)) do
		set[id] = true
	end
	return set
end

-- Pièce (identifiant) qui contient le point, ou nil (jardin, extérieur). base : { [niveau] = y du sol }, height : hauteur d'étage.
function PerfRules.roomIdAt(rooms, base, height, x, y, z)
	for _, r in ipairs(rooms) do
		local floorY = base[r.level]
		if
			floorY
			and x >= r.x0
			and x <= r.x1
			and z >= r.z0
			and z <= r.z1
			and y >= floorY - 1
			and y <= floorY + height
		then
			return r.id
		end
	end
	return nil
end

-- Ligne de la fenêtre de debug
function PerfRules.debugLine(fps, serverMs, ping, parts)
	return ("FPS %d | serveur %.1f ms | ping %d ms | parts %d"):format(
		math.floor(fps + 0.5),
		serverMs,
		math.floor(ping + 0.5),
		parts
	)
end

return PerfRules

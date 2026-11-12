--!strict
-- Décisions des bots d'arène (fonctions pures, testables hors Roblox).
local BotLogic = {}

export type Target = { Id: number, X: number, Z: number }

-- Nombre de bots à maintenir : complète jusqu'à `minCombatants`, jamais de bots sans joueur.
function BotLogic.DesiredCount(humans: number, minCombatants: number, maxBots: number): number
	if humans <= 0 then
		return 0
	end
	return math.clamp(minCombatants - humans, 0, maxBots)
end

-- Cible la plus proche dans le rayon de vision. Renvoie (index, distance) ou nil.
function BotLogic.NearestTarget(x: number, z: number, targets: { Target }, sight: number): (number?, number?)
	local best, bestDist = nil, sight
	for i, t in ipairs(targets) do
		local d = math.sqrt((t.X - x) ^ 2 + (t.Z - z) ^ 2)
		if d <= bestDist then
			best, bestDist = i, d
		end
	end
	return best, if best then bestDist else nil
end

local ANGLES = { 0, 40, -40, 80, -80, 130, -130 }

-- Direction (ux, uz) unitaire vers (dx, dz), contournant les obstacles :
-- `isBlocked(ux, uz)` dit si un pas dans cette direction est impossible.
-- `side` (1 ou -1) choisit le côté d'évitement préféré.
function BotLogic.Steer(dx: number, dz: number, isBlocked: (number, number) -> boolean, side: number): (number?, number?)
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.001 then
		return nil, nil
	end
	local bx, bz = dx / len, dz / len
	for _, deg in ipairs(ANGLES) do
		local a = math.rad(deg * side)
		local ux = bx * math.cos(a) - bz * math.sin(a)
		local uz = bx * math.sin(a) + bz * math.cos(a)
		if not isBlocked(ux, uz) then
			return ux, uz
		end
	end
	return nil, nil
end

function BotLogic.CanAttack(dist: number, range: number, now: number, lastAttack: number, cooldown: number): boolean
	return dist <= range and now - lastAttack >= cooldown
end

return BotLogic

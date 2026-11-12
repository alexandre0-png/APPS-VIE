--!strict
-- Balistique pure (nombres, pas de Vector3) : utilisée à l'identique par le serveur (validation)
-- et par les clients (animation), donc l'arc affiché correspond exactement à l'arc calculé.

local Ballistics = {}

function Ballistics.flightTime(distance: number, speed: number, minT: number, maxT: number): number
	return math.clamp(distance / speed, minT, maxT)
end

-- Vitesse initiale pour atteindre (tx,ty,tz) depuis (ox,oy,oz) en T secondes, gravité g (>0, vers -Y).
function Ballistics.launchVelocity(ox: number, oy: number, oz: number, tx: number, ty: number, tz: number, T: number, g: number): (number, number, number)
	return (tx - ox) / T, (ty - oy) / T + 0.5 * g * T, (tz - oz) / T
end

function Ballistics.position(ox: number, oy: number, oz: number, vx: number, vy: number, vz: number, t: number, g: number): (number, number, number)
	return ox + vx * t, oy + vy * t - 0.5 * g * t * t, oz + vz * t
end

return Ballistics

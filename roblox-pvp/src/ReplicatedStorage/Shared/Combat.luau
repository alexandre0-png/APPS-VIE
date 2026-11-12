--!strict
-- Calculs de combat purs (testables hors Roblox).
local Combat = {}

export type DamageOptions = {
	Headshot: boolean?,
	HeadshotMult: number?,
	Backstab: boolean?,
	BackstabMult: number?,
	Boost: number?, -- multiplicateur global (orbe de rage)
	Falloff: number?, -- 0..1 (atténuation de zone)
}

function Combat.ComputeDamage(base: number, opts: DamageOptions?): number
	local dmg = base
	if opts then
		if opts.Headshot then
			dmg *= opts.HeadshotMult or 1.5
		end
		if opts.Backstab then
			dmg *= opts.BackstabMult or 1
		end
		if opts.Boost then
			dmg *= opts.Boost
		end
		if opts.Falloff then
			dmg *= opts.Falloff
		end
	end
	return math.max(1, math.floor(dmg + 0.5))
end

-- Atténuation linéaire d'une explosion : 100% au centre, 35% au bord.
function Combat.SplashFalloff(dist: number, radius: number): number
	if radius <= 0 then
		return 1
	end
	return math.clamp(1 - (dist / radius) * 0.65, 0.35, 1)
end

-- Vrai si la direction (dx,dz) est dans un cône d'angle `arcDeg` autour de (fx,fz).
function Combat.InCone(fx: number, fz: number, dx: number, dz: number, arcDeg: number): boolean
	local fl = math.sqrt(fx * fx + fz * fz)
	local dl = math.sqrt(dx * dx + dz * dz)
	if dl < 0.001 then
		return true -- cible quasi superposée
	end
	if fl < 0.001 then
		return false
	end
	local dot = (fx * dx + fz * dz) / (fl * dl)
	return dot >= math.cos(math.rad(arcDeg / 2))
end

-- Vrai si l'attaquant est dans le dos de la victime.
-- (vx,vz) = regard de la victime ; (ax,az) = vecteur attaquant -> victime.
function Combat.IsBackstab(vx: number, vz: number, ax: number, az: number): boolean
	local vl = math.sqrt(vx * vx + vz * vz)
	local al = math.sqrt(ax * ax + az * az)
	if vl < 0.001 or al < 0.001 then
		return false
	end
	return (vx * ax + vz * az) / (vl * al) > 0.5
end

-- Perturbation d'une direction pour les plombs : renvoie (yaw, pitch) en radians
-- à partir de deux nombres aléatoires u,v dans [0,1[.
function Combat.SpreadAngles(spreadDeg: number, u: number, v: number): (number, number)
	local r = math.rad(spreadDeg) * math.sqrt(u)
	local theta = v * math.pi * 2
	return math.cos(theta) * r, math.sin(theta) * r
end

return Combat

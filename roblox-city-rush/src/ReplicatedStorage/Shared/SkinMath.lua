--[[
	SkinMath : calculs purs pour habiller un véhicule / placer un modèle externe (testables sans Roblox).
]]

local SkinMath = {}

-- Échelle uniforme pour que le plus long côté horizontal (X ou Z) vaille targetLength
function SkinMath.fitScale(sizeX, sizeZ, targetLength)
	local longest = math.max(sizeX, sizeZ)
	if longest <= 1e-6 or targetLength <= 0 then
		return 1
	end
	return targetLength / longest
end

-- Rotation (radians) pour que l'axe long soit Z : quart de tour si X est plus long, plus rotation manuelle (degrés)
function SkinMath.yawRadians(sizeX, sizeZ, extraDegrees)
	local yaw = math.rad(extraDegrees or 0)
	if sizeX > sizeZ then
		yaw += math.pi / 2
	end
	return yaw
end

-- Dimensions plausibles ? Retourne (ok, raison)
function SkinMath.sizeOk(x, y, z, maxSize)
	if x ~= x or y ~= y or z ~= z then
		return false, "dimensions invalides"
	end
	if x <= 0.05 or y <= 0.05 or z <= 0.05 then
		return false, "modèle plat ou vide"
	end
	if math.max(x, y, z) > maxSize then
		return false, "modèle trop grand"
	end
	return true, "ok"
end

return SkinMath

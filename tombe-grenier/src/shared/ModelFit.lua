--[[
  ModelFit : mise à l'échelle et orientation d'un modèle chargé qui remplace un objet de la carte (logique pure, testée).
  Le chargeur mesure le modèle (Model:GetExtentsSize) : l'échelle et l'orientation réelles d'un FBX ne sont pas connues
  d'avance, ce module calcule le facteur d'échelle et l'angle à partir des mesures.

  Mode d'échelle : "longest" (la plus grande dimension du modèle égale la plus grande de la cible),
  "height" (la hauteur du modèle égale la hauteur cible), "fit" (le modèle tient entièrement dans la cible).
  Face avant du modèle : l'axe horizontal vers lequel il regarde tel qu'il a été modélisé (réglable : Config.Assets.Front).
]]
local ModelFit = {}

-- Un modèle par objet remplacé. floor : posé sur le sol de l'étage (horloge) plutôt que sur la pièce invisible.
ModelFit.PLANS = {
	["clé or"] = { mode = "longest", front = "-Z" },
	["coffret ancien"] = { mode = "longest", front = "-Z" }, -- serrure dorée sur la face -Z
	["horloge comtoise"] = { mode = "height", height = 6.5, front = "+Z", floor = true }, -- cadran « -Y » côté Blender = +Z Roblox
	["poupée ancienne"] = { mode = "height", height = 1.6, front = "-Z" },
	["bougie chandelier"] = { mode = "height", height = 1.0, front = "-Z" },
}

ModelFit.FRONT = {
	["-Z"] = { 0, -1 },
	["+Z"] = { 0, 1 },
	["-X"] = { -1, 0 },
	["+X"] = { 1, 0 },
}

-- Luau fournit math.atan2 ; Lua 5.4 (tests) accepte math.atan(y, x)
local atan2 = math.atan2 or math.atan

local MIN_SCALE, MAX_SCALE = 0.02, 50

local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- extents, target : { x, y, z } en studs. Retourne un facteur d'échelle fini et borné (1 si les mesures sont invalides).
function ModelFit.scaleFor(extents, target, mode)
	local ex, ey, ez = extents[1], extents[2], extents[3]
	if not (finite(ex) and finite(ey) and finite(ez)) or ex <= 0 or ey <= 0 or ez <= 0 then
		return 1
	end
	local s
	if mode == "height" then
		s = target[2] / ey
	elseif mode == "fit" then
		s = math.min(target[1] / ex, target[2] / ey, target[3] / ez)
	else
		s = math.max(target[1], target[2], target[3]) / math.max(ex, ey, ez)
	end
	if not finite(s) or s <= 0 then
		return 1
	end
	return math.max(MIN_SCALE, math.min(MAX_SCALE, s))
end

-- Direction horizontale (axe le plus proche) de la pièce vers le centre de la pièce : le modèle regarde vers l'intérieur.
function ModelFit.faceToward(pos, centre)
	local dx, dz = centre[1] - pos[1], centre[2] - pos[2]
	if math.abs(dx) < 1e-6 and math.abs(dz) < 1e-6 then
		return { 0, 1 }
	end
	if math.abs(dx) > math.abs(dz) then
		return { dx > 0 and 1 or -1, 0 }
	end
	return { 0, dz > 0 and 1 or -1 }
end

-- Rotation autour de Y (radians, ]-pi, pi]) qui amène la face avant `front` dans la direction `wanted` ({dx, dz}).
-- Convention Roblox : tourner de t autour de +Y envoie +Z vers (sin t, cos t) ; le cap d'un vecteur est atan2(x, z).
function ModelFit.yawFor(front, wanted)
	local f = ModelFit.FRONT[front] or ModelFit.FRONT["-Z"]
	local t = atan2(wanted[1], wanted[2]) - atan2(f[1], f[2])
	while t > math.pi do
		t = t - 2 * math.pi
	end
	while t <= -math.pi do
		t = t + 2 * math.pi
	end
	return t
end

return ModelFit

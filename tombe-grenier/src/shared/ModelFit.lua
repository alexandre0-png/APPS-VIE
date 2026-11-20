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
	-- Bibliothèque Blender : meubles qui tiennent dans la boîte du meuble de la carte, orientés vers l'intérieur de la pièce
	["armoire gothique"] = { mode = "fit", front = "-Z" },
	["commode ancienne"] = { mode = "fit", front = "-Z" },
	["berceau"] = { mode = "fit", front = "-Z" },
	["cheval à bascule"] = { mode = "fit", front = "-Z" },
	["miroir sur pied"] = { mode = "fit", front = "-Z" },
	["malle"] = { mode = "fit", front = "-Z" },
	["statuette"] = { mode = "height", front = "-Z" }, -- statue de l'énigme : à la hauteur de la pièce de jeu
	["cadre photo"] = { mode = "longest", front = "-Z" }, -- cadre des photos : à la taille de la photo remplacée
	["chaise ancienne"] = { mode = "fit", front = "+Z" },
	["table de salle"] = { mode = "fit", front = "+Z" },
	["étagère murale"] = { mode = "fit", front = "+Z" },
	["caisses en bois"] = { mode = "fit", front = "+Z" },
	["pied de lit"] = { mode = "fit", front = "+Z" },
	["plante d'intérieur"] = { mode = "fit", front = "+Z" },
	["console d'entrée"] = { mode = "fit", front = "+Z" },
	["baignoire sur pieds"] = { mode = "fit", front = "+Z" },
	["lavabo"] = { mode = "fit", front = "+Z" },
	["WC"] = { mode = "fit", front = "+Z" },
	["armoire de toilette"] = { mode = "fit", front = "+Z" },
	["barrique"] = { mode = "fit", front = "+Z" },
	["cuve"] = { mode = "fit", front = "+Z" },
	["canapé ancien"] = { mode = "fit", front = "+Z" },
	["fauteuil ancien"] = { mode = "fit", front = "+Z" },
	["cuisinière ancienne"] = { mode = "fit", front = "+Z" },
	["frigo ancien"] = { mode = "fit", front = "+Z" },
	["cercueil"] = { mode = "fit", front = "+Z" },
	["coffre verrouillé"] = { mode = "fit", front = "+Z" },
	["coffre à jouets"] = { mode = "fit", front = "+Z" },
	["vitrine"] = { mode = "fit", front = "+Z" },
	["portemanteau"] = { mode = "fit", front = "+Z" },
	["lampadaire ancien"] = { mode = "fit", front = "+Z" },
	["lit double ancien"] = { mode = "fit", front = "+Z" },
	["établi"] = { mode = "fit", front = "+Z" },
	["cheminée gothique"] = { mode = "fit", front = "-Z" },
	["étagère livres"] = { mode = "fit", front = "-Z" },
	["gramophone ancien"] = { mode = "longest", front = "-Z" },
	["escalier Blender"] = { mode = "fit", front = "-Z" }, -- chargé, pas encore posé : l'escalier de la carte reste
	["lustre"] = { mode = "height", front = "-Z" },
	["machine à coudre"] = { mode = "longest", front = "-Z" },
	["porte ancienne"] = { mode = "height", front = "-Z" },
	["tapis rond"] = { mode = "longest", front = "-Z" },
	["téléphone ancien"] = { mode = "longest", front = "-Z" },
	["toile d'araignée"] = { mode = "longest", front = "-Z" },
	["valise"] = { mode = "longest", front = "-Z" },
	["ombre rampante"] = { mode = "height", front = "-Z" }, -- monstre : à la hauteur du rig
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

-- Quart de tour : les largeurs en x et en z du modèle s'échangent
function ModelFit.rotatedExtents(extents, yaw)
	if math.abs(math.sin(yaw)) > 0.5 then
		return { extents[3], extents[2], extents[1] }
	end
	return { extents[1], extents[2], extents[3] }
end

-- Résout la pose : échelle et rotation pour un modèle de mesures `extents`, remplaçant un objet de taille `target`,
-- tourné vers `facing` ({ dx, dz }). front : face avant réelle si elle diffère du plan (Config.Assets.Front).
-- Retourne { scale, yaw, size } où size est la taille finale du modèle une fois posé.
function ModelFit.solve(name, extents, target, facing, front)
	local plan = ModelFit.PLANS[name] or { mode = "fit", front = "-Z" }
	local yaw = ModelFit.yawFor(front or plan.front, facing)
	local turned = ModelFit.rotatedExtents(extents, yaw)
	local goal = plan.height and { 0, plan.height, 0 } or target
	local scale = ModelFit.scaleFor(turned, goal, plan.mode)
	return { scale = scale, yaw = yaw, size = { turned[1] * scale, turned[2] * scale, turned[3] * scale } }
end

return ModelFit

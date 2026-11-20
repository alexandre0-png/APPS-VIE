--[[
  ModelColor : convention de couleur des modèles Blender. Roblox ignore les couleurs d'un FBX sans texture : chaque pièce
  séparée du modèle s'appelle `Nom__RRGGBB` (couleur hexadécimale du matériau). Le chargeur lit le suffixe et peint la pièce.
  Sans suffixe, la couleur actuelle est conservée. Blender ajoute parfois `.001` en fin de nom : toléré.
  parse / materialKey sont purs (testés hors Roblox) ; paint applique le résultat aux pièces d'un modèle chargé.
]]
local ModelColor = {}

-- Retire les accents courants et met en minuscules pour comparer les noms
local function fold(s)
	s = s:lower()
	local map = {
		["é"] = "e",
		["è"] = "e",
		["ê"] = "e",
		["ë"] = "e",
		["à"] = "a",
		["â"] = "a",
		["î"] = "i",
		["ï"] = "i",
		["ô"] = "o",
		["ù"] = "u",
		["û"] = "u",
		["ç"] = "c",
	}
	for from, to in pairs(map) do
		s = s:gsub(from, to)
	end
	return s
end

-- Couleur hexadécimale en suffixe `__RRGGBB` (éventuellement suivie de `.001`). Retourne r, g, b (0 à 255) ou nil.
function ModelColor.parse(name)
	if type(name) ~= "string" then
		return nil
	end
	local base = name:gsub("%.%d+$", "")
	local hex = base:match("__(%x%x%x%x%x%x)$")
	if not hex then
		return nil
	end
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Mots du nom qui désignent un métal doré ou ferré, une flamme ou un verre
ModelColor.METAL = { "anneau", "tige", "dent", "serrure", "poignee", "cadre", "laiton", "ferrure", "fer", "cercle" }
ModelColor.NEON = { "flamme", "oeil", "yeux", "lueur" }
ModelColor.GLASS = { "verre", "vitre" }

local function hasWord(name, words)
	local f = fold(name)
	for _, w in ipairs(words) do
		if f:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- "metal", "neon", "glass" ou "plastic" (par défaut)
function ModelColor.materialKey(name)
	if type(name) ~= "string" then
		return "plastic"
	end
	if hasWord(name, ModelColor.NEON) then
		return "neon"
	end
	if hasWord(name, ModelColor.GLASS) then
		return "glass"
	end
	if hasWord(name, ModelColor.METAL) then
		return "metal"
	end
	return "plastic"
end

-- Peint chaque pièce dont le nom porte un suffixe de couleur : couleur, matériau, sans collision, ancrée.
-- Retourne le nombre de pièces peintes. Ne lève jamais d'erreur.
function ModelColor.paint(model)
	local painted = 0
	local materials = {
		plastic = Enum.Material.Plastic,
		metal = Enum.Material.Metal,
		neon = Enum.Material.Neon,
		glass = Enum.Material.Glass,
	}
	local ok = pcall(function()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local r, g, b = ModelColor.parse(d.Name)
				if r then
					d.Color = Color3.fromRGB(r, g, b)
					d.Material = materials[ModelColor.materialKey(d.Name)]
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					painted += 1
				end
			end
		end
	end)
	return ok and painted or 0
end

return ModelColor

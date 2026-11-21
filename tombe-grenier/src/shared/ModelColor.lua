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
		["œ"] = "oe",
		["Œ"] = "oe",
		["É"] = "e",
		["È"] = "e",
		["Ê"] = "e",
		["À"] = "a",
		["Ç"] = "c",
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

-- Mots EXACTS du nom (séparés par _, espace, tiret ou majuscule) : métal seulement pour les pièces explicitement métalliques,
-- néon seulement pour la flamme, les yeux et la lanterne, verre pour verre et vitre. Tout le reste est du plastique mat.
ModelColor.METAL = {
	"anneau",
	"tige",
	"dent",
	"dents",
	"serrure",
	"poignee",
	"poignees",
	"laiton",
	"fer",
	"ferrure",
	"chrome",
	"pic",
	"pics",
}
ModelColor.GILDED = { "dore", "doree", "dores", "or" } -- « Cadre doré » : le cadre n'est métallique que doré
ModelColor.NEON = { "flamme", "oeil", "yeux", "lanterne" }
ModelColor.GLASS = { "verre", "vitre" }
ModelColor.DEFAULT_COLOR = { 176, 164, 150 } -- pièce sans suffixe et trop sombre : gris chaud, jamais noir par défaut

-- Mots du nom, en minuscules sans accent : `Cadre_Dore__B8A060.001` -> cadre, dore
function ModelColor.words(name)
	local base = name:gsub("%.%d+$", ""):gsub("__%x%x%x%x%x%x$", "")
	base = base:gsub("(%l)(%u)", "%1 %2")
	local out = {}
	for word in fold(base):gmatch("%a+") do
		table.insert(out, word)
	end
	return out
end

local function has(words, list)
	for _, w in ipairs(words) do
		for _, candidate in ipairs(list) do
			if w == candidate then
				return true
			end
		end
	end
	return false
end

-- "metal", "neon", "glass" ou "plastic" (par défaut)
function ModelColor.materialKey(name)
	if type(name) ~= "string" then
		return "plastic"
	end
	local words = ModelColor.words(name)
	if has(words, ModelColor.NEON) then
		return "neon"
	end
	if has(words, ModelColor.GLASS) then
		return "glass"
	end
	if has(words, ModelColor.METAL) then
		return "metal"
	end
	if has(words, { "cadre" }) and has(words, ModelColor.GILDED) then
		return "metal"
	end
	return "plastic"
end

-- Couleur trop sombre pour être une vraie couleur d'objet : moyenne des canaux (0 à 255) sous 30
function ModelColor.isTooDark(r, g, b)
	return type(r) == "number" and (r + g + b) / 3 < 30
end

-- Peint chaque pièce dont le nom porte un suffixe de couleur : couleur exacte, matériau selon le nom, Reflectance 0,
-- sans collision, ancrée. Une pièce SANS suffixe garde sa couleur, sauf si elle est noire par défaut (gris chaud) ;
-- les apparences de surface importées (SurfaceAppearance) sont retirées. Retourne le nombre de pièces peintes.
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
				for _, child in ipairs(d:GetChildren()) do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				d.Reflectance = 0
				if r then
					d.Color = Color3.fromRGB(r, g, b)
					d.Material = materials[ModelColor.materialKey(d.Name)]
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					painted += 1
				else
					local c = d.Color
					if c and ModelColor.isTooDark(c.R * 255, c.G * 255, c.B * 255) then
						local fallback = ModelColor.DEFAULT_COLOR
						d.Color = Color3.fromRGB(fallback[1], fallback[2], fallback[3])
					end
					if d.Material == Enum.Material.Metal then
						d.Material = Enum.Material.Plastic
					end
				end
			end
		end
	end)
	return ok and painted or 0
end

return ModelColor

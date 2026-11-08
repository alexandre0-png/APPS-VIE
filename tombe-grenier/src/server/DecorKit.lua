--[[
  DecorKit : petits objets posés sur les meubles (livres, bouteilles, boîtes, coussins, casseroles).
  Déterministe : même décor à chaque partie (seed fixe). Tout est décoratif (non collisionnable).

  Remplacement par des modèles Studio : si ServerStorage/Decor contient un modèle (Model ou BasePart)
  dont le nom est celui du meuble (ex. « table », « bibliothèque »), il est posé sur le meuble
  à la place des objets générés. C'est le point d'extension prévu pour les décors réalistes.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rng = require(Shared.Rng)

local DecorKit = {}

local SEED = 4242

-- Ce qui se pose sur chaque type de meuble (nom exact du meuble dans MapData)
local RECIPES = {
	["table"] = { "bouteille", "assiette" },
	["table ronde"] = { "bouteille", "boîte" },
	["table basse"] = { "livre" },
	["bibliothèque"] = { "livre", "livre", "livre" },
	["étagère"] = { "livre", "boîte" },
	["étagères"] = { "livre", "boîte" },
	["commode"] = { "boîte", "vase" },
	["lit"] = { "coussin" },
	["lit double"] = { "coussin", "coussin" },
	["lit enfant"] = { "coussin" },
	["canapé"] = { "coussin", "coussin" },
	["cuisinière"] = { "casserole" },
	["îlot"] = { "bouteille", "assiette" },
	["bureau"] = { "livre", "livre" },
	["caisses"] = { "boîte" },
	["coffre"] = { "boîte" },
	["console"] = { "vase" },
	["buffet"] = { "assiette", "bouteille" },
	["placards"] = { "boîte" },
}

-- Taille (x, y, z) et apparence de chaque objet générique
local PROPS = {
	livre = { size = Vector3.new(0.6, 0.15, 0.9), material = Enum.Material.Fabric, shape = nil },
	boîte = { size = Vector3.new(1.0, 0.7, 0.8), material = Enum.Material.Cardboard, shape = nil },
	bouteille = { size = Vector3.new(1.4, 0.45, 0.45), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder },
	assiette = { size = Vector3.new(0.12, 1.0, 1.0), material = Enum.Material.SmoothPlastic, shape = Enum.PartType.Cylinder },
	vase = { size = Vector3.new(1.0, 0.6, 0.6), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder },
	coussin = { size = Vector3.new(0.5, 1.2, 1.0), material = Enum.Material.Fabric, shape = nil },
	casserole = { size = Vector3.new(0.6, 0.6, 0.6), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
}

local COLORS = {
	livre = { Color3.fromRGB(90, 40, 35), Color3.fromRGB(40, 60, 45), Color3.fromRGB(60, 50, 35) },
	boîte = { Color3.fromRGB(150, 120, 80), Color3.fromRGB(130, 100, 70) },
	bouteille = { Color3.fromRGB(60, 80, 60), Color3.fromRGB(90, 60, 40) },
	assiette = { Color3.fromRGB(230, 225, 215) },
	vase = { Color3.fromRGB(120, 110, 100) },
	coussin = { Color3.fromRGB(110, 40, 40), Color3.fromRGB(70, 70, 60), Color3.fromRGB(60, 45, 70) },
	casserole = { Color3.fromRGB(70, 70, 75) },
}

local function pick(rng, list)
	return list[rng:int(1, #list)]
end

-- Crée un objet générique, orienté selon sa forme, posé sur (x, y, z) (y = dessus du meuble)
local function makeProp(parent, kind, rng, x, y, z)
	local spec = PROPS[kind]
	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true
	part.CanCollide = false
	part.Size = spec.size
	part.Material = spec.material
	part.Color = pick(rng, COLORS[kind])
	if spec.shape then
		part.Shape = spec.shape
	end
	-- Le cylindre a son axe sur X : on le redresse sur Y
	local isCylinder = spec.shape == Enum.PartType.Cylinder
	local rotation = isCylinder and CFrame.Angles(0, 0, math.pi / 2) or CFrame.new()
	-- Hauteur réelle posée sur le meuble : sur X pour un cylindre couché, sur Y sinon
	local height = isCylinder and spec.size.X or spec.size.Y
	part.CFrame = CFrame.new(x, y + height / 2, z) * rotation
	part.Parent = parent
	return part
end

-- Modèle Studio de même nom que le meuble, s'il existe
local function studioModel(name)
	local folder = ServerStorage:FindFirstChild("Decor")
	local template = folder and folder:FindFirstChild(name)
	return template
end

local function placeModel(template, parent, x, y, z)
	local model = template:Clone()
	if model:IsA("Model") then
		model:PivotTo(CFrame.new(x, y + 0.5, z))
	elseif model:IsA("BasePart") then
		model.CFrame = CFrame.new(x, y + model.Size.Y / 2, z)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	if model:IsA("BasePart") then
		model.Anchored = true
		model.CanCollide = false
	end
	model.Parent = parent
end

-- Pose le décor sur chaque meuble listé
function DecorKit.dress(parent, furniture)
	local rng = Rng.new(SEED)
	for _, f in ipairs(furniture) do
		local recipe = RECIPES[f.name]
		if recipe then
			local top = f.y1
			local template = studioModel(f.name)
			if template then
				placeModel(template, parent, (f.x0 + f.x1) / 2, top, (f.z0 + f.z1) / 2)
			else
				for _, kind in ipairs(recipe) do
					-- Position aléatoire sur la surface, en gardant 0,3 stud de marge
					local x = rng:range(f.x0 + 0.3, f.x1 - 0.3)
					local z = rng:range(f.z0 + 0.3, f.z1 - 0.3)
					makeProp(parent, kind, rng, x, top, z)
				end
			end
		end
	end
end

return DecorKit

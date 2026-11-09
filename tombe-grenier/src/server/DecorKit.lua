--[[
  DecorKit : petits objets posés sur les meubles (livres, bouteilles, boîtes, coussins, casseroles).
  Déterministe : même décor à chaque partie (seed fixe). Tout est décoratif (non collisionnable).

  Remplacement par des modèles Studio : si ServerStorage/Decor contient un modèle (Model ou BasePart)
  dont le nom est celui du meuble (ex. « table », « bibliothèque »), il est posé sur le meuble
  à la place des objets générés. C'est le point d'extension prévu pour les décors réalistes.
]]
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rng = require(Shared.Rng)
local MapData = require(Shared.MapData)

-- Pièces fermées par une énigme : les livres qui s'y trouvent ne sont pas des indices
local LOCKED = { sdb = true, bureau = true, cha = true, sdb2 = true, cel = true }

local function inLockedRoom(f)
	local cx, cz = (f.x0 + f.x1) / 2, (f.z0 + f.z1) / 2
	for _, r in ipairs(MapData.rooms) do
		if LOCKED[r.id] and cx >= r.x0 and cx <= r.x1 and cz >= r.z0 and cz <= r.z1 then
			local floor = MapData.base[r.level]
			if f.y0 >= floor - 1 and f.y0 <= floor + MapData.H + 1 then
				return true
			end
		end
	end
	return false
end

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
	["boîte"] = { size = Vector3.new(1.0, 0.7, 0.8), material = Enum.Material.Cardboard, shape = nil },
	bouteille = { size = Vector3.new(1.4, 0.45, 0.45), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder },
	assiette = { size = Vector3.new(0.12, 1.0, 1.0), material = Enum.Material.SmoothPlastic, shape = Enum.PartType.Cylinder },
	vase = { size = Vector3.new(1.0, 0.6, 0.6), material = Enum.Material.Glass, shape = Enum.PartType.Cylinder },
	coussin = { size = Vector3.new(0.5, 1.2, 1.0), material = Enum.Material.Fabric, shape = nil },
	casserole = { size = Vector3.new(0.6, 0.6, 0.6), material = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
}

local COLORS = {
	livre = { Color3.fromRGB(90, 40, 35), Color3.fromRGB(40, 60, 45), Color3.fromRGB(60, 50, 35) },
	["boîte"] = { Color3.fromRGB(150, 120, 80), Color3.fromRGB(130, 100, 70) },
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

-- Modèle Studio de même nom (ServerStorage/Decor), ou nil
local function studioModel(name)
	local folder = ServerStorage:FindFirstChild("Decor")
	return folder and folder:FindFirstChild(name) or nil
end

-- Place un modèle, pivot au bas et au centre sur (x, y, z).
-- target (taille cible en studs) : le modèle est mis à l'échelle pour l'occuper, proportions gardées.
local function placeModel(template, parent, x, y, z, target)
	local model = template:Clone()
	if model:IsA("Model") then
		if target then
			local _, size = model:GetBoundingBox()
			local fit = math.min(target.X / math.max(size.X, 0.01),
				target.Y / math.max(size.Y, 0.01), target.Z / math.max(size.Z, 0.01))
			model:ScaleTo(model:GetScale() * fit)
		end
		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
		model:TranslateBy(Vector3.new(x, y, z) - bottom)
	elseif model:IsA("BasePart") then
		if target then
			model.Size = target
		end
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

-- Pose le décor. furnParts[i] : partie créée pour furniture[i] ; cachée (collision gardée)
-- quand un modèle la remplace.
function DecorKit.dress(parent, furniture, furnParts)
	local rng = Rng.new(SEED)
	for i, f in ipairs(furniture) do
		-- Une grande bibliothèque (plus de 8 studs de large) prend le modèle dédié
		local modelName = (f.name == "bibliothèque" and f.x1 - f.x0 > 8) and "grande bibliothèque" or f.name
		local template = studioModel(modelName)
		if template then
			local target = Vector3.new(f.x1 - f.x0, f.y1 - f.y0, f.z1 - f.z0)
			placeModel(template, parent, (f.x0 + f.x1) / 2, f.y0, (f.z0 + f.z1) / 2, target)
			if furnParts and furnParts[i] then
				furnParts[i].Transparency = 1
				furnParts[i].CastShadow = false
			end
		else
			local recipe = RECIPES[f.name]
			if recipe then
				for _, kind in ipairs(recipe) do
					-- Position aléatoire sur la surface, en gardant 0,3 stud de marge
					local x = rng:range(f.x0 + 0.3, f.x1 - 0.3)
					local z = rng:range(f.z0 + 0.3, f.z1 - 0.3)
					local itemModel = studioModel(kind)
					if itemModel then
						placeModel(itemModel, parent, x, f.y1, z, nil)
					else
						local prop = makeProp(parent, kind, rng, x, f.y1, z)
						if kind == "livre" and not inLockedRoom(f) then
							-- Livres lisibles : les marque-pages sont tirés à chaque partie (Quests.setup)
							CollectionService:AddTag(prop, "Livre")
						end
					end
				end
			end
		end
	end
end

return DecorKit

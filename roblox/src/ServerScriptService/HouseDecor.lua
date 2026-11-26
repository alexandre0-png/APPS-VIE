-- ModuleScript : ServerScriptService/HouseDecor   (lot 8B-meubles, NON INTÉGRÉ : voir roblox/HOUSEDECOR_INTEGRATION_NOTES.md)
-- Place le décor intérieur d'une maison selon son niveau (données : ReplicatedStorage/Shared/HouseDecorData).
--   HouseDecor.apply(houseModel, level, config) -> rapport { placed, kept, removed, loaded, fallback, parts }
--   * idempotent : rappeler apply avec le même niveau ne crée rien ; monter de niveau ajoute seulement le nouveau décor ;
--     descendre de niveau retire le décor qui n'appartient plus au niveau (nettoyage propre) ;
--   * chargement : InsertService:LoadAsset, un seul appel par ID (cache de modèles, échec mémorisé pour la session) ;
--     repli procédural (une Part de forme et couleur données) si l'asset échoue, si config.useAssets == false ou sans service ;
--   * le chargement peut céder la main (LoadAsset) : appeler depuis task.spawn côté serveur, jamais dans la boucle de rendu.
-- Aucune variable globale ; pas de += ; pas de continue ; garde de type avant toute comparaison numérique.
local HouseDecor = {}

local FOLDER_NAME = "HouseDecor" -- dossier enfant de la maison
local ID_ATTR = "HouseDecorId" -- attribut de chaque objet placé
local LEVEL_ATTR = "HouseDecorLevel" -- attribut du dossier : niveau appliqué
local NAME_PREFIX = "HD_"

-- Cache partagé : assetId -> modèle source (jamais placé, on clone) ou false (échec mémorisé).
local sharedCache = {}

local function getData(config)
	if config.data ~= nil then
		return config.data
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HouseDecorData"))
end

-- Niveau entier borné 1..count ; tout ce qui n'est pas un nombre (ou NaN) vaut 1 ; l'infini est borné comme un grand nombre.
local function clampLevel(level, count)
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	local n = math.floor(level)
	if n < 1 then
		return 1
	end
	if n > count then
		return count
	end
	return n
end

local function insertServiceOf(config)
	if config.insertService ~= nil then
		return config.insertService or nil -- false = « pas de service » (tests, Studio hors ligne)
	end
	local ok, svc = pcall(function()
		return game:GetService("InsertService")
	end)
	if ok then
		return svc
	end
	return nil
end

-- Modèle source d'un asset : charge au plus une fois (succès ou échec mémorisés dans le cache).
-- Retourne un Instance (Model ou BasePart) à cloner, ou nil (repli procédural).
local function templateOf(assetId, config)
	local cache = config.cache or sharedCache
	local hit = cache[assetId]
	if hit ~= nil then
		return hit or nil
	end
	if config.useAssets == false then
		return nil
	end
	local svc = insertServiceOf(config)
	if svc == nil then
		return nil
	end
	local ok, container = pcall(function()
		return svc:LoadAsset(assetId)
	end)
	if not ok or typeof(container) ~= "Instance" then
		cache[assetId] = false
		return nil
	end
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if model == nil then
		container:Destroy()
		cache[assetId] = false
		return nil
	end
	model.Parent = nil
	container:Destroy()
	cache[assetId] = model
	return model
end

-- Place un objet à partir de son modèle Blender : orientation, mise à l'échelle uniforme (tient dans la boîte `size`), centrage sur `cf`.
local function placeModel(template, item, cf, folder)
	local model = template:Clone()
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		model.Parent = wrapper
		model = wrapper
	end
	model.Name = NAME_PREFIX .. item.id
	model:SetAttribute(ID_ATTR, item.id)
	model.Parent = folder
	model:PivotTo(cf)
	local ext = model:GetExtentsSize()
	if type(ext.X) == "number" and type(ext.Y) == "number" and type(ext.Z) == "number" and ext.X > 0 and ext.Y > 0 and ext.Z > 0 then
		local k = math.min(item.size[1] / ext.X, item.size[2] / ext.Y, item.size[3] / ext.Z)
		if k > 0 and k < math.huge then
			model:ScaleTo(k)
		end
	end
	local bbCF = model:GetBoundingBox()
	model:PivotTo(CFrame.new(cf.Position - bbCF.Position) * model:GetPivot())
	return model
end

-- Repli procédural : une seule Part, forme et couleur de l'objet.
local function placeFallback(item, cf, folder)
	local fb = item.fallback
	local part = Instance.new("Part")
	part.Name = NAME_PREFIX .. item.id
	part:SetAttribute(ID_ATTR, item.id)
	part.Anchored = true
	part.CanCollide = item.size[2] >= 3
	part.Material = Enum.Material[fb.material] or Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(fb.color[1], fb.color[2], fb.color[3])
	if fb.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(item.size[2], item.size[1], item.size[3])
		part.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(item.size[1], item.size[2], item.size[3])
		part.CFrame = cf
	end
	part.Parent = folder
	return part
end

-- Place un objet ; retourne "loaded", "fallback" ou nil (déjà présent après un yield : rien de créé).
-- config.offset = { x, y, z } : origine des positions de la fiche par rapport au pivot de la maison (ex. Builder, maison procédurale :
-- centre de la façade à (0, 1.6, zc)). Composantes non numériques = 0.
local function offsetOf(config)
	local o = config.offset
	local out = { 0, 0, 0 }
	if type(o) == "table" then
		for i = 1, 3 do
			if type(o[i]) == "number" and o[i] == o[i] then
				out[i] = o[i]
			end
		end
	end
	return out
end

local function placeItem(folder, houseCF, item, config)
	local o = offsetOf(config)
	local cf = houseCF * CFrame.new(o[1] + item.pos[1], o[2] + item.pos[2] + item.size[2] / 2, o[3] + item.pos[3]) * CFrame.Angles(0, math.rad(item.rot or 0), 0)
	local template = templateOf(item.assetId, config)
	-- templateOf peut céder la main : un autre appel a pu placer le même objet entre-temps
	if folder:FindFirstChild(NAME_PREFIX .. item.id) then
		return nil
	end
	if template ~= nil then
		placeModel(template, item, cf, folder)
		return "loaded"
	end
	placeFallback(item, cf, folder)
	return "fallback"
end

-- Applique le décor du niveau `level` à `houseModel`. Retourne le rapport.
function HouseDecor.apply(houseModel, level, config)
	local cfg = config or {}
	local data = getData(cfg)
	local lv = clampLevel(level, data.LEVEL_COUNT)
	local folder = houseModel:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = houseModel
	end
	local wanted = data.unlocked(lv)
	local want = {}
	for _, item in ipairs(wanted) do
		want[item.id] = item
	end
	local report = { placed = 0, kept = 0, removed = 0, loaded = 0, fallback = 0, parts = data.budget(lv) }
	-- 1) nettoyage : objets inconnus, retirés du niveau, ou en double
	local have = {}
	for _, child in ipairs(folder:GetChildren()) do
		local id = child:GetAttribute(ID_ATTR)
		if type(id) ~= "string" or want[id] == nil or have[id] then
			child:Destroy()
			report.removed = report.removed + 1
		else
			have[id] = true
			report.kept = report.kept + 1
		end
	end
	-- 2) ajout du décor manquant (cumul : les objets des niveaux précédents restent)
	local houseCF = houseModel:GetPivot()
	for _, item in ipairs(wanted) do
		if not have[item.id] then
			local how = placeItem(folder, houseCF, item, cfg)
			if how == "loaded" then
				report.loaded = report.loaded + 1
				report.placed = report.placed + 1
			elseif how == "fallback" then
				report.fallback = report.fallback + 1
				report.placed = report.placed + 1
			end
		end
	end
	folder:SetAttribute(LEVEL_ATTR, lv)
	return report
end

-- Retire tout le décor de la maison (départ, reconstruction).
function HouseDecor.clear(houseModel)
	local folder = houseModel:FindFirstChild(FOLDER_NAME)
	if folder ~= nil then
		folder:Destroy()
	end
end

-- Exposé pour les tests : vide le cache des modèles chargés.
function HouseDecor.resetCache()
	sharedCache = {}
end

return HouseDecor

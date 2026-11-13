--[[
  ModelLoader : charge les modèles de décor (identifiants Roblox) dans ServerStorage/Decor, sous le nom
  du meuble ou de l'objet. DecorKit et MapBuilder les posent à la place des boîtes de substitution.
  Côté serveur uniquement, avec InsertService:LoadAsset, dans pcall et avec un délai maximum (Config.Assets.Timeout).
  Scripts et événements retirés (AssetLoad.sanitize). En cas d'échec, la pièce de remplacement actuelle reste.
]]
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetLoad = require(Shared.AssetLoad)

local ModelLoader = {}

-- Nom du meuble (tel qu'il apparaît dans tools/map/generate_map.py) -> identifiant de modèle
local MODELS = {
	["armoire"] = 11237264353,
	["lit"] = 4962765494,
	["bibliothèque"] = 9904549498,
	["téléphone"] = 1552930535,
	["télévision"] = 52257438,
	["tableau"] = 10728175427,
	["tableau2"] = 14852009787,
	["mannequin"] = 119619217119127,
	["grande bibliothèque"] = 95255430761213,
	["lampe plafond"] = 10810000263,
	["tableau3"] = 158661179,
	["tableau4"] = 130893645012904,
	["tableau5"] = 111204431705606,
	["tableau6"] = 16611095319,
	["enfant"] = 5363005472,
	["voiture"] = 78927333558155,
	["fenêtre bois"] = 5875960491,
	["fenêtre rouille"] = 2975574647,
	["cheminée"] = 3554244943,
}

-- Modèles de Config.Assets -> nom de meuble ou d'objet où ils servent
local ASSET_NAMES = {
	ChaiseHorreur = "chaise",
	ChaiseBois = "chaise bois",
	ChaiseAntique = "fauteuil",
	ChaiseBloquante = "chaise bloquante",
	LampeHorreur = "lampe horreur",
	TableLongue = "table",
	Plante = "plante",
}

-- Chargement d'un identifiant avec délai maximum. Retourne le conteneur, ou nil.
local function loadWithTimeout(id)
	local result = nil
	local done = false
	task.spawn(function()
		local ok, container = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		result = ok and container or nil
		done = true
	end)
	local limit = (Config.Assets and Config.Assets.Timeout) or 8
	local waited = 0
	while not done and waited < limit do
		task.wait(0.2)
		waited += 0.2
	end
	return result
end

ModelLoader.loadWithTimeout = loadWithTimeout

-- Liste à charger : les modèles de meubles, puis ceux de Config.Assets
local function entries()
	local list = {}
	for name, id in pairs(MODELS) do
		table.insert(list, { name = name, id = id })
	end
	for key, name in pairs(ASSET_NAMES) do
		local id = Config.Assets and Config.Assets[key]
		if typeof(id) == "number" and id > 0 then
			table.insert(list, { name = name, id = id })
		end
	end
	return list
end

function ModelLoader.ensure()
	local folder = ServerStorage:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = ServerStorage
	end
	if Config.Assets and Config.Assets.Enabled == false then
		return
	end
	local todo = {}
	for _, e in ipairs(entries()) do
		if not folder:FindFirstChild(e.name) then
			table.insert(todo, e)
		end
	end
	local report = AssetLoad.install(todo, loadWithTimeout, folder)
	for _, name in ipairs(report.failed) do
		warn(("[ModelLoader] modèle « %s » non chargé : la pièce de remplacement reste"):format(name))
	end
end

return ModelLoader

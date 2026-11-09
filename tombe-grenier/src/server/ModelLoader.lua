--[[
  ModelLoader : charge les modèles de meubles fournis (identifiants Roblox) dans ServerStorage/Decor,
  sous le nom du meuble. DecorKit les pose à la place des boîtes de substitution.
  Les scripts éventuellement présents dans un modèle sont retirés. En cas d'échec, la boîte reste.
]]
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

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

function ModelLoader.ensure()
	local folder = ServerStorage:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = ServerStorage
	end
	for name, id in pairs(MODELS) do
		if not folder:FindFirstChild(name) then
			local ok, container = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			local model = ok and container and container:FindFirstChildWhichIsA("Model", true)
			if model then
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
						d:Destroy()
					end
				end
				model.Name = name
				model.Parent = folder
			else
				warn(("[ModelLoader] modèle « %s » non chargé (id %d)"):format(name, id))
			end
			if container then
				container:Destroy()
			end
		end
	end
end

return ModelLoader

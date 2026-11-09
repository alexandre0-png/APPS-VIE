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

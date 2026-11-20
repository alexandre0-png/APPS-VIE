--[[
  ModelLoader : charge les modèles de décor (identifiants Roblox) dans ServerStorage/Decor, sous le nom
  du meuble ou de l'objet. DecorKit et MapBuilder les posent à la place des boîtes de substitution.
  Côté serveur uniquement, avec InsertService:LoadAsset, dans pcall et avec un délai maximum (Config.Assets.Timeout).
  Scripts et événements retirés (AssetLoad.sanitize). En cas d'échec, la pièce de remplacement reste.
]]
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetLoad = require(Shared.AssetLoad)

local ModelLoader = {}

local todo = nil -- modèles encore à charger (partagé par les tâches parallèles)

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
	ChaiseModerne = "chaise moderne",
	ChaiseEcole = "chaise école",
	CanapeU = "canapé U",
	TableMetal = "table métal",
	TableBois = "table bois",
	TableManger = "table à manger",
	TableRondeChaise = "table ronde moderne",
	Billard = "billard",
	VieuxOrdinateur = "ordinateur",
	LampeTable = "lampe de table",
	PlanteMoyenne = "plante moyenne",
	PlanteModerne = "plante moderne",
	PlanteFenetre = "plante fenêtre",
	PlanteExterieure = "plante extérieure",
	PlanteSakura = "sakura",
	CleOr = "clé or",
	CoffretAncien = "coffret ancien",
	HorlogeComtoise = "horloge comtoise",
	PoupeeAncienne = "poupée ancienne",
	BougieChandelier = "bougie chandelier",
}

-- Chargement d'un identifiant avec délai maximum (limit : secondes, 8 par défaut). Retourne le conteneur, ou nil.
local function loadWithTimeout(id, limit)
	local result = nil
	local done = false
	task.spawn(function()
		local ok, container = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		result = ok and container or nil
		done = true
	end)
	limit = limit or (Config.Assets and Config.Assets.Timeout) or 8
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
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

ModelLoader.entries = entries

-- Chargement en arrière-plan : le jeu ne l'attend jamais. Des tâches parallèles (Config.Assets.Workers) tirent les
-- modèles à charger ; au bout du plafond global (Config.Assets.GlobalTimeout, 10 s) plus rien n'est lancé et chaque
-- chargement en cours est abandonné. onDone(report) est appelé une seule fois, avec les modèles installés, échoués et
-- laissés de côté. Un modèle absent garde sa pièce de remplacement procédurale.
function ModelLoader.start(onDone)
	local folder = ServerStorage:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = ServerStorage
	end
	local report = { ok = {}, failed = {}, skipped = {} }
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, e in ipairs(todo or {}) do
			table.insert(report.skipped, e.name)
		end
		if #report.failed > 0 or #report.skipped > 0 then
			warn(
				("[ModelLoader] %d modèle(s) chargé(s), %d en échec, %d laissé(s) de côté (plafond %d s) : pièces de remplacement conservées"):format(
					#report.ok,
					#report.failed,
					#report.skipped,
					(Config.Assets and Config.Assets.GlobalTimeout) or 10
				)
			)
		end
		print(
			("[Boot] modèles chargés : %d ok, %d échec, %d de côté"):format(
				#report.ok,
				#report.failed,
				#report.skipped
			)
		)
		if onDone then
			local ok, err = pcall(onDone, report)
			if not ok then
				warn("[ModelLoader] habillage après chargement en erreur : " .. tostring(err))
			end
		end
	end
	if Config.Assets and Config.Assets.Enabled == false then
		finish()
		return report
	end
	todo = {}
	for _, e in ipairs(entries()) do
		if not folder:FindFirstChild(e.name) then
			table.insert(todo, e)
		end
	end
	local cap = (Config.Assets and Config.Assets.GlobalTimeout) or 10
	local deadline = os.clock() + cap
	local workers = math.max(1, (Config.Assets and Config.Assets.Workers) or 8)
	local running = workers
	local function within(id)
		return loadWithTimeout(
			id,
			math.max(0.2, math.min((Config.Assets and Config.Assets.Timeout) or 8, deadline - os.clock()))
		)
	end
	for _ = 1, workers do
		task.spawn(function()
			while os.clock() < deadline do
				local entry = table.remove(todo, 1)
				if not entry then
					break
				end
				local ok, partial = pcall(AssetLoad.install, { entry }, within, folder)
				if ok then
					for _, name in ipairs(partial.ok) do
						table.insert(report.ok, name)
					end
					for _, name in ipairs(partial.failed) do
						table.insert(report.failed, name)
					end
				else
					table.insert(report.failed, entry.name)
				end
			end
			running -= 1
			if running == 0 then
				finish()
			end
		end)
	end
	-- Filet de sécurité : même si une tâche reste bloquée, l'habillage a lieu au plus tard peu après le plafond
	task.delay(cap + 2, finish)
	return report
end

return ModelLoader

--!nonstrict
-- Point d'entrée serveur : initialise les services dans l'ordre des dépendances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

Remotes.init()

local Services = script.Parent:WaitForChild("Services")
local MapBuilder = require(Services:WaitForChild("MapBuilder"))
local PlayerService = require(Services:WaitForChild("PlayerService"))
local DinoService = require(Services:WaitForChild("DinoService"))
local EventService = require(Services:WaitForChild("EventService"))
local FoodService = require(Services:WaitForChild("FoodService"))
local NameTagService = require(Services:WaitForChild("NameTagService"))
local QuestService = require(Services:WaitForChild("QuestService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))

local state = Instance.new("Configuration")
state.Name = "GameState"
state.Parent = ReplicatedStorage

local mapFolder, boardLabels = MapBuilder.build()

DinoService.init(mapFolder)
EventService.init()
FoodService.init()
QuestService.init()
NameTagService.init()
LeaderboardService.init(boardLabels)
ShopService.init()
MonetizationService.init()
PlayerService.init() -- en dernier : les joueurs déjà présents déclenchent les hooks ci-dessus

print("[FestinTRex] Serveur prêt.")

-- Main.server.luau : point d'entrée serveur de Dino Dig Park.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes) -- crée les RemoteEvents avant tout le reste

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GameService = require(script.Parent.GameService)
local Monetization = require(script.Parent.Monetization)
local EventService = require(script.Parent.EventService)
local Leaderboard = require(script.Parent.Leaderboard)
local AssetService = require(script.Parent.AssetService)

DataService.init()
PlotService.init() -- construit le monde (lobby + parcelles)
GameService.Monetization = Monetization
Monetization.init(GameService)
EventService.init(GameService)
Leaderboard.init()
AssetService.init() -- modèles externes : en arrière-plan, repli automatique
GameService.init() -- en dernier : commence à accepter les joueurs

print("[Dino Dig Park] serveur prêt")

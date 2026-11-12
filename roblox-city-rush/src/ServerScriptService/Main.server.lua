--[[
	Main.server.lua : point d'entrée serveur de CITY RUSH.
	Ordre : remotes -> données -> économie -> monde -> services dépendants -> boucles -> apparition des joueurs.
]]

local Players = game:GetService("Players")

Players.CharacterAutoLoads = false
Players.RespawnTime = 3

local Services = script.Parent:WaitForChild("Services")
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local World = require(Services.WorldService)
local Pedestrians = require(Services.PedestrianService)
local VehicleService = require(Services.VehicleService)
local WantedService = require(Services.WantedService)
local MissionService = require(Services.MissionService)
local CollectibleService = require(Services.CollectibleService)
local StoryService = require(Services.StoryService)
local EventService = require(Services.EventService)
local LeaderboardService = require(Services.LeaderboardService)
local MonetizationService = require(Services.MonetizationService)

-- Les joueurs peuvent arriver pendant la génération : on gère leur apparition dès maintenant.
local function loadCharacter(player)
	if player.Parent then
		player:LoadCharacter()
	end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				task.delay(Players.RespawnTime, loadCharacter, player)
			end)
		end
	end)
	task.spawn(function()
		local t = os.clock()
		while player.Parent and (not workspace:GetAttribute("WorldReady") or not DataService.get(player)) and os.clock() - t < 40 do
			task.wait(0.2)
		end
		if not player.Parent then
			return
		end
		loadCharacter(player)
		local profile = DataService.get(player)
		if profile and profile.Stats.joins == 1 then
			-- premier lancement : la Citadine apparaît automatiquement
			task.wait(2.5)
			VehicleService.spawnFor(player, "citadine")
			RemoteService.notify(player, "Bienvenue à CITY RUSH ! Ta Citadine t'attend. Touche G = garage.", "good")
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

RemoteService.init()
DataService.init()
EconomyService.init()
World.build()
Pedestrians.init()
VehicleService.init()
VehicleService.setDependencies(World, Pedestrians, WantedService)
WantedService.init(World)
MissionService.init(World)
CollectibleService.init(World)
StoryService.init()
MonetizationService.init()

VehicleService.start()
Pedestrians.start()
WantedService.start()
MissionService.start()
CollectibleService.start()
StoryService.start()
EventService.start(World)
LeaderboardService.start(World)

workspace:SetAttribute("WorldReady", true)
print("[CityRush] Serveur prêt")

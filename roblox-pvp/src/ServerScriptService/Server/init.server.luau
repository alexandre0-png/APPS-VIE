--!nonstrict
-- Point d'entrée serveur de "Arène des Légendes".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script

local Remotes = require(Shared.Remotes) -- crée les remotes avant tout
local MapBuilder = require(Server.MapBuilder)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)
local QuestService = require(Server.QuestService)
local CombatService = require(Server.CombatService)
local WeaponService = require(Server.WeaponService)
local MatchService = require(Server.MatchService)
local RequestService = require(Server.RequestService)
local LeaderboardService = require(Server.LeaderboardService)
local DummyService = require(Server.DummyService)

-- Les personnages sont chargés manuellement une fois le profil prêt.
Players.CharacterAutoLoads = false

local map = MapBuilder.Build()
workspace:SetAttribute("MatchState", "Waiting")

DataService.Init()
CombatService.Init()
WeaponService.Init()
MatchService.Init(map)
RequestService.Init()
LeaderboardService.Init(map)
DummyService.Init(map.DummySpots)

local function onPlayerAdded(player)
	local profile = DataService.Load(player)
	if player.Parent ~= Players then
		return
	end
	QuestService.Ensure(player)
	PlayerService.Setup(player, profile)
	PlayerService.Respawn(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

local _ = Remotes -- référence conservée (création des remotes)

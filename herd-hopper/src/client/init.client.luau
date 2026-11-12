-- Point d'entrée client de Saute-Troupeau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Modules = script:WaitForChild("Modules")
local ClientState = require(Modules.ClientState)
local CreatureFx = require(Modules.CreatureFx)
local CameraRig = require(Modules.CameraRig)
local Controls = require(Modules.Controls)
local HUD = require(Modules.HUD)
local Menu = require(Modules.Menu)
local Ambience = require(Modules.Ambience)

-- Données serveur -> client
Remotes.Data.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		ClientState.setData(snapshot)
	end
end)

Remotes.Status.OnClientEvent:Connect(function(status)
	if type(status) == "string" then
		ClientState.setStatus(status)
	end
end)

Remotes.Scores.OnClientEvent:Connect(function(list)
	if type(list) == "table" then
		ClientState.setScores(list)
	end
end)

Remotes.Feedback.OnClientEvent:Connect(function(payload)
	HUD.feedback(payload)
end)

Remotes.Results.OnClientEvent:Connect(function(payload)
	HUD.showResults(payload)
end)

Remotes.Launched.OnClientEvent:Connect(function(velocity)
	if typeof(velocity) == "Vector3" then
		Controls.onLaunched(velocity)
	end
end)

-- Sans personnage vivant on repasse en mode salon.
player.CharacterAdded:Connect(function()
	ClientState.setStatus("Lobby")
end)

-- Modules
HUD.init()
Menu.init()
CreatureFx.init()
CameraRig.init()
Controls.init()
Ambience.init()

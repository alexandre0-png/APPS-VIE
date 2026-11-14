--[[
  Lieu hub (projet hub.project.json) : arrivée, zones solo et duo, file d'attente, puis téléportation
  vers un serveur privé du lieu de jeu. Ce projet n'inclut ni la maison, ni les systèmes de partie :
  seulement le code commun (src/common) et le partagé (src/shared).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubRules = require(Shared.HubRules)
local Hub = require(script.Parent.Common.Hub)
local Profile = require(script.Parent.Common.Profile)

-- Le hub ne construit que l'accueil ; les joueurs y arrivent directement
Hub.build()
Hub.enter()

-- Rang et titre affichés au-dessus de chaque joueur du hub
local function greet(player)
	task.spawn(function()
		Profile.load(player)
		pcall(Profile.attachLabel, player)
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	greet(player)
end

Players.PlayerAdded:Connect(function(player)
	greet(player)
	-- Un joueur qui arrive dans le hub est placé au point d'accueil
	task.defer(Hub.enter)
end)

-- Boucle : attend une borne, puis envoie le groupe vers le lieu de jeu
while true do
	local group = Hub.waitForStart()
	local mode = HubRules.groupMode(#group)
	local launched = Hub.startGame(group)
	if not launched then
		warn(("[Hub] lancement %s refusé, nouvel essai dans 5 s"):format(mode))
		task.wait(5)
	end
end

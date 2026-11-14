--[[
  SpawnLog : traces [Spawn] dans la console serveur (F9 en jeu, Sortie en Studio) pour suivre un joueur
  de son arrivée à son premier mouvement : rôle, PlaceId, état de la carte, positions, remplacements.
  Config.Spawn.Debug = false les coupe.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SpawnLog = {}

function SpawnLog.say(fmt, ...)
	if Config.Spawn.Debug then
		print("[Spawn] " .. fmt:format(...))
	end
end

-- Position lisible d'un personnage : « (x, y, z) » ou « aucun personnage »
function SpawnLog.where(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return "aucun personnage"
	end
	local p = root.Position
	return ("(%.1f, %.1f, %.1f)"):format(p.X, p.Y, p.Z)
end

return SpawnLog

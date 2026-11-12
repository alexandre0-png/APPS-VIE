-- Remotes.luau : crée (serveur) ou attend (client) les RemoteEvents du jeu.
-- Action : client -> serveur (nom d'action + payload validé côté serveur)
-- State  : serveur -> client (état complet du joueur)
-- Notify : serveur -> client (messages)
-- Fx     : serveur -> client (effets : creusage, éclosion, achat…)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local NAMES = { "Action", "State", "Notify", "Fx" }

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, n in ipairs(NAMES) do
		local r = folder:FindFirstChild(n)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
		Remotes[n] = r
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, n in ipairs(NAMES) do
		Remotes[n] = folder:WaitForChild(n)
	end
end

return Remotes

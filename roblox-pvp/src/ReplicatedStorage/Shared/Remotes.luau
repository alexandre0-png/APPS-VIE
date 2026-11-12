--!nonstrict
-- Création (serveur) et accès (client) aux RemoteEvents / RemoteFunction.
-- Toute action sensible passe par `Request` (validée et limitée en débit côté serveur).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Attack", "Fx", "Notify", "Feed", "Hit", "Sync", "Match" }
local FUNCTIONS = { "Request" }

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		local ev = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
		Remotes[name] = ev
	end
	for _, name in ipairs(FUNCTIONS) do
		local fn = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = folder
		Remotes[name] = fn
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in ipairs(EVENTS) do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in ipairs(FUNCTIONS) do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes

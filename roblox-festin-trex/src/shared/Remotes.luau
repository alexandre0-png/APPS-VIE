--!strict
-- Définition unique des RemoteEvents / RemoteFunction. Le serveur les crée, le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = { "Throw", "State", "Notify", "ThrowFx", "FeedFx", "OpenPanel", "Reveal", "FeastFx" }
Remotes.Functions = { "Request" }

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		for _, name in ipairs(Remotes.Events) do
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = f
		end
		for _, name in ipairs(Remotes.Functions) do
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = f
		end
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name: string): any
	return folder():WaitForChild(name)
end

-- Côté serveur : crée le dossier tout de suite (appelé par Main avant tout autre service).
function Remotes.init()
	folder()
end

return Remotes

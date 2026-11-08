--[[
  Remotes : canaux réseau client <-> serveur.
  Le serveur crée le dossier au démarrage ; le client attend qu'il soit répliqué.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local EVENTS = {
	"SetQuiet",         -- client -> serveur : boolean (mode silencieux)
	"SetSprint",        -- client -> serveur : boolean (sprint)
	"ToggleFlashlight", -- client -> serveur : (aucun argument)
	"Effect",           -- serveur -> client : { kind = ..., ... }
	"HUD",              -- serveur -> client : progression de l'équipe
}

function Remotes.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
end

function Remotes.get(name)
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

function Remotes.fire(name, player, payload)
	Remotes.get(name):FireClient(player, payload)
end

function Remotes.fireAll(name, payload)
	Remotes.get(name):FireAllClients(payload)
end

return Remotes

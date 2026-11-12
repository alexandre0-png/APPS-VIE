-- Création / récupération des RemoteEvents et RemoteFunctions.
-- Le serveur crée tout au démarrage ; le client attend leur réplication.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Hook", -- C->S : id de la bête visée
	"Launch", -- C->S : quitter la monture
	"Steer", -- C->S : direction latérale [-1, 1]
	"Collect", -- C->S : récupérer l'animal monté (une fois sa confiance gagnée)
	"Lasso", -- C->S : lancer le lasso de capture sur un animal à cœur
	"Ready", -- C->S : partir en expédition (zone choisie, prêt oui/non)
	"Prompt", -- C->S : demande d'achat Robux (kind, key)
	"Data", -- S->C : profil du joueur
	"Status", -- S->C : état du joueur (Lobby, Riding, Air, Hooking, Down, Dead, Finished)
	"Launched", -- S->C : vitesse initiale du bond
	"Feedback", -- S->C : messages / effets
	"Scores", -- S->C : classement en direct
	"Results", -- S->C : résultats de manche
}

local FUNCTIONS = {
	"Buy",
	"Equip",
	"ClaimDaily",
	"ClaimQuest",
	"ZooAction", -- améliorations, caisse, histoire
}

local isServer = RunService:IsServer()
local folder

if isServer then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

local function fetch(name, className)
	local remote = folder:FindFirstChild(name)
	if remote then
		return remote
	end
	if isServer then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

for _, name in ipairs(EVENTS) do
	Remotes[name] = fetch(name, "RemoteEvent")
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = fetch(name, "RemoteFunction")
end

return Remotes

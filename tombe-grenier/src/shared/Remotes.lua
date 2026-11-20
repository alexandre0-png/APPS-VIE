--[[
  Remotes : canaux réseau client <-> serveur.
  Le serveur crée le dossier au démarrage ; le client attend qu'il soit répliqué.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local EVENTS = {
	"SetQuiet", -- client -> serveur : boolean (mode silencieux)
	"SetSprint", -- client -> serveur : boolean (sprint)
	"ToggleFlashlight", -- client -> serveur : (aucun argument)
	"Effect", -- serveur -> client : { kind = ..., ... }
	"HUD", -- serveur -> client : progression de l'équipe
	"Objective", -- serveur -> client : texte de l'objectif courant
	"Message", -- serveur -> client : { text = ... } (indices, lecture, retours)
	"Keypad", -- serveur -> client : ouvre l'écran de saisie du code
	"SubmitCode", -- client -> serveur : texte du code saisi
	"Throw", -- client -> serveur : direction du lancer (vecteur unitaire)
	"Flashback", -- serveur -> client : { kind = "family" | "intro" | "cahier" | "journal" | "plaque" } (séquence courte)
	"Restart", -- client -> serveur : « Rejouer » après une fin
	"Quit", -- client -> serveur : « Quitter » après une fin (le joueur quitte la partie)
	"Inventory", -- serveur -> client : { smallKey, caveKey, docs, docsTotal } (objets visibles à l'écran)
	"SetCrouch", -- client -> serveur : boolean (accroupi, touche C)
	"AskHint", -- client -> serveur : demande l'indication de l'étape (touche H)
	"Reveal", -- serveur -> client : { n, total, text } étape accomplie (bannière « Étape n sur N »)
	"Journal", -- serveur -> client : { lines = { texte, ... } } journal de quêtes (touche J)
	"Hint", -- serveur -> client : { text = ... } indication affichée en bas à gauche
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

-- Canal factice : si les Remotes n'arrivent jamais (serveur en panne), le client continue au lieu de bloquer
-- pour toujours. Toutes les opérations réseau deviennent sans effet.
local function nullEvent()
	local noop = { Connect = function() end, Wait = function() end }
	return {
		OnClientEvent = noop,
		OnServerEvent = noop,
		FireServer = function() end,
		FireClient = function() end,
		FireAllClients = function() end,
	}
end

local warned = false

function Remotes.get(name)
	local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
	local event = folder and folder:WaitForChild(name, 10)
	if not event then
		if not warned then
			warned = true
			warn(
				"[Remotes] le dossier ReplicatedStorage.Remotes (ou « "
					.. name
					.. " ») n'existe pas après 10 s : le serveur n'a pas démarré correctement. "
					.. "Les échanges réseau sont ignorés."
			)
		end
		return nullEvent()
	end
	return event
end

function Remotes.fire(name, player, payload)
	Remotes.get(name):FireClient(player, payload)
end

function Remotes.fireAll(name, payload)
	Remotes.get(name):FireAllClients(payload)
end

return Remotes

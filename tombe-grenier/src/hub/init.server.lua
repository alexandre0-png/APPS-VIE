--[[
  Lieu hub (projet hub.project.json) : arrivée, zones solo et duo, file d'attente, puis téléportation
  vers un serveur privé du lieu de jeu. Ce projet n'inclut ni la maison, ni les systèmes de partie :
  seulement le code commun (src/common) et le partagé (src/shared).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
-- Les Remotes existent avant tout le reste : un client éventuel les attend dès son démarrage.
Remotes.init()
local HubRules = require(Shared.HubRules)
local Config = require(Shared.Config)

-- Test du hub seul en Studio (hub.project.json) : le rôle est forcé à « hub » avant le chargement de Hub.
-- En production (hors Studio), le rôle vient de game.PlaceId comparé à Config.Game.Places : ce réglage est ignoré.
Config.Debug.PlaceRole = Config.Debug.PlaceRole or "hub"

local Hub = require(script.Parent.Common.Hub)
local Profile = require(script.Parent.Common.Profile)
local SpawnSafety = require(script.Parent.Common.SpawnSafety)
local SpawnLog = require(script.Parent.Common.SpawnLog)

-- Le lieu hub charge les personnages tout seul (rien d'autre ne le fait ici) : réglage forcé, car la propriété
-- Players.CharacterAutoLoads est enregistrée avec le lieu.
pcall(function()
	Players.CharacterAutoLoads = true
end)
SpawnLog.say(
	"hub : démarrage, PlaceId=%d, rôle=%s, StreamingEnabled=%s, CharacterAutoLoads=%s, %d joueur(s) déjà là",
	game.PlaceId,
	Hub.role(),
	tostring(workspace.StreamingEnabled),
	tostring(Players.CharacterAutoLoads),
	#Players:GetPlayers()
)

-- Filet de sécurité, lancé avant toute construction : un joueur sans personnage 5 s après son arrivée en reçoit un ;
-- un joueur arrivé par téléportation (ou de retour de la partie) qui tomberait sous le sol est replacé sur le
-- point d'apparition du hub.
SpawnSafety.start(function()
	local folder = workspace:FindFirstChild("Hub")
	return folder and folder:FindFirstChild("HubSpawn")
end)

-- Le hub ne construit que l'accueil ; les joueurs y arrivent directement. Une erreur de construction n'arrête
-- pas le script : le hub reste jouable et la boucle de lancement tourne.
local built, buildError = pcall(Hub.build)
if not built then
	warn("[Boot] hub ERREUR : " .. tostring(buildError))
else
	print("[Boot] hub construction ok")
end
local hubFolder = workspace:FindFirstChild("Hub")
local hubSpawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
SpawnLog.say(
	"hub : construction %s, point d'apparition %s",
	built and "terminée" or "EN ERREUR",
	hubSpawn and "présent" or "ABSENT"
)
local enteredOk, enterError = pcall(Hub.enter)
if enteredOk then
	print("[Boot] hub accueil ok")
else
	warn("[Boot] hub accueil ERREUR : " .. tostring(enterError))
end

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

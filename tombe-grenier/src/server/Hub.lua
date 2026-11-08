--[[
  Hub : salon d'attente commun à tous les joueurs, à l'écart de la maison.
  Une borne « Lancer la partie » démarre la partie ; sans borne, elle démarre après
  Config.Game.HubWait secondes à partir de l'arrivée du premier joueur.
  Tous les joueurs présents au hub sont téléportés dans le cercueil du grenier.
  Après une fin, tout le monde est téléporté de nouveau au hub.
  Le hub et le cercueil ne sont jamais des points d'apparition actifs en même temps.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Hub = {}

local CENTER = Vector3.new(300, 0, 300) -- loin de la maison et de la clôture
local folder = nil
local launchRequested = false

local function coffinSpawn()
	local root = Workspace:FindFirstChild("TombeMap")
	return root and root:FindFirstChild("CercueilSpawn")
end

local function setSpawns(hubOn)
	local cercueil = coffinSpawn()
	local hubSpawn = folder and folder:FindFirstChild("HubSpawn")
	if cercueil then
		cercueil.Enabled = not hubOn
	end
	if hubSpawn then
		hubSpawn.Enabled = hubOn
	end
end

-- Téléporte un joueur à la position cf ; s'il n'a pas de personnage, il en reçoit un au bon endroit
local function teleport(player, cf)
	local char = player.Character
	if char then
		char:PivotTo(cf)
	else
		task.spawn(function()
			player:LoadCharacter()
			local newChar = player.Character
			if newChar then
				newChar:PivotTo(cf)
			end
		end)
	end
end

local function makePad(name, pos, color, text, onPress)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(8, 1, 8)
	part.Position = pos
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.ObjectText = name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(onPress)
end

-- Construit le hub (une seule fois, après la carte)
function Hub.build()
	folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "Sol"
	floor.Anchored = true
	floor.Size = Vector3.new(60, 2, 60)
	floor.Position = CENTER + Vector3.new(0, -1, 0)
	floor.Color = Color3.fromRGB(40, 38, 36)
	floor.Material = Enum.Material.Concrete
	floor.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = CENTER + Vector3.new(0, 0.5, 0)
	spawn.Parent = folder

	local lamp = Instance.new("Part")
	lamp.Name = "Lampe"
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.Size = Vector3.new(1, 1, 1)
	lamp.Position = CENTER + Vector3.new(0, 12, 0)
	lamp.Material = Enum.Material.Neon
	lamp.Color = Color3.fromRGB(255, 220, 160)
	lamp.Parent = folder
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp

	makePad("Borne Lancer", CENTER + Vector3.new(0, 0.5, 12), Color3.fromRGB(180, 140, 90), "Lancer la partie",
		function()
			launchRequested = true
		end)

	setSpawns(true)
end

-- Tous les joueurs au hub
function Hub.enter()
	launchRequested = false
	setSpawns(true)
	local spawnPart = folder and folder:FindFirstChild("HubSpawn")
	local cf = spawnPart and (spawnPart.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(CENTER + Vector3.new(0, 4, 0))
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, cf)
	end
end

-- Bloque jusqu'au lancement : la borne, ou le délai après l'arrivée du premier joueur
-- Retourne la liste des joueurs présents au hub
function Hub.waitForStart()
	local firstSeen = nil
	while true do
		local present = Players:GetPlayers()
		if #present > 0 then
			firstSeen = firstSeen or os.clock()
			if launchRequested or os.clock() - firstSeen >= Config.Game.HubWait then
				return present
			end
		else
			firstSeen = nil
			launchRequested = false
		end
		task.wait(0.3)
	end
end

-- Téléporte le groupe dans le cercueil du grenier
function Hub.startGame(group)
	launchRequested = false
	setSpawns(false)
	local cercueil = coffinSpawn()
	local cf = cercueil and (cercueil.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(90, 27, 45)
	for _, player in ipairs(group) do
		teleport(player, cf)
	end
end

return Hub

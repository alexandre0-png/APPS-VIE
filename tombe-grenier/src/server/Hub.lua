--[[
  Hub : salon d'attente avant chaque partie, à l'écart de la maison.
  Deux bornes : « Solo » lance la partie tout de suite ; « Duo » attend un second joueur
  pendant Config.Game.DuoWait secondes, sinon la partie démarre en solo.
  Les joueurs qui ne font pas partie de la partie restent dans le hub.
  Le cercueil et le hub sont des points d'apparition : un seul est actif à la fois.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Hub = {}

local CENTER = Vector3.new(300, 0, 300) -- loin de la maison et de la clôture
local folder = nil
local soloChoice = {}  -- [player] = true
local duoChoice = {}   -- [player] = instant du choix

local function setSpawns(hubOn)
	local root = Workspace:FindFirstChild("TombeMap")
	local cercueil = root and root:FindFirstChild("CercueilSpawn")
	local hubSpawn = folder and folder:FindFirstChild("HubSpawn")
	if cercueil then
		cercueil.Enabled = not hubOn
	end
	if hubSpawn then
		hubSpawn.Enabled = hubOn
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

	makePad("Borne Solo", CENTER + Vector3.new(-12, 0.5, 0), Color3.fromRGB(120, 180, 140), "Jouer en solo",
		function(player)
			soloChoice[player] = true
		end)
	makePad("Borne Duo", CENTER + Vector3.new(12, 0.5, 0), Color3.fromRGB(140, 120, 180), "Jouer en duo",
		function(player)
			duoChoice[player] = os.clock()
		end)

	setSpawns(true)
end

-- Renvoie tout le monde au hub, et remet les choix à zéro
function Hub.enter()
	soloChoice = {}
	duoChoice = {}
	setSpawns(true)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

-- Bloque jusqu'au choix : retourne le mode ("solo" ou "duo") et les joueurs concernés
function Hub.waitForMode()
	while true do
		for player in pairs(soloChoice) do
			if player.Parent then
				return "solo", { player }
			end
		end

		local first = nil
		for player, instant in pairs(duoChoice) do
			if player.Parent and (first == nil or instant < duoChoice[first]) then
				first = player
			end
		end

		if first then
			local deadline = os.clock() + Config.Game.DuoWait
			while os.clock() < deadline do
				local group = {}
				for player in pairs(duoChoice) do
					if player.Parent then
						table.insert(group, player)
					end
				end
				if #group >= 2 then
					return "duo", { group[1], group[2] }
				end
				for player in pairs(soloChoice) do
					if player.Parent then
						return "solo", { player }
					end
				end
				task.wait(0.5)
			end
			-- Personne n'a répondu à la borne Duo : la partie démarre en solo
			return "solo", { first }
		end

		task.wait(0.3)
	end
end

-- Lance la partie pour le groupe : le cercueil devient le point d'apparition
function Hub.startGame(group)
	setSpawns(false)
	soloChoice = {}
	duoChoice = {}
	for _, player in ipairs(group) do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

return Hub

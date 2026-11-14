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
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local HubRules = require(Shared.HubRules)

local Hub = {}

-- Rôle de ce lieu :
--   "hub"    : lieu d'attente. Les joueurs y arrivent, puis Roblox les envoie sur un serveur privé du lieu de jeu.
--   "game"   : lieu de jeu. Les joueurs y arrivent par téléportation, la partie démarre à l'arrivée.
--   "single" : un seul lieu (test en Studio, ou identifiants non renseignés). Tout se passe ici.
local function computeRole()
	-- En Studio, chaque fichier de lieu indique son rôle (hub.rbxl ou game.rbxl)
	if RunService:IsStudio() and (Config.Debug.PlaceRole == "hub" or Config.Debug.PlaceRole == "game") then
		return Config.Debug.PlaceRole
	end
	if RunService:IsStudio() or Config.Game.Places.hub == 0 or Config.Game.Places.game == 0 then
		return "single"
	end
	if game.PlaceId == Config.Game.Places.hub then
		return "hub"
	elseif game.PlaceId == Config.Game.Places.game then
		return "game"
	end
	return "single"
end

local role = computeRole()

function Hub.role()
	return role
end

local CENTER = Vector3.new(300, 0, 300) -- loin de la maison et de la clôture
local folder = nil
local launchRequested = false
local requestedMode = nil -- "solo" ou "duo" : borne pressée, nil sinon
local queueLabels = {}    -- [mode] = BillboardGui TextLabel (file d'attente visible)

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
	-- Panneau de file d'attente, au-dessus de la borne
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 40)
	board.StudsOffset = Vector3.new(0, 4, 0)
	board.AlwaysOnTop = false
	board.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	label.TextColor3 = Color3.fromRGB(240, 225, 190)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.Text = ""
	label.Parent = board
	return label
end

-- Met à jour les panneaux : nombre de joueurs qui attendent chaque mode
local function updateQueues()
	local present = #Players:GetPlayers()
	for mode, label in pairs(queueLabels) do
		if label and label.Parent then
			local needed = mode == "duo" and 2 or 1
			label.Text = HubRules.queueText(mode == "duo" and "Partie duo" or "Partie solo", requestedMode == mode and present or 0, needed)
		end
	end
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

	-- Deux zones : partie solo et partie duo (le joueur entre dans la zone et lance)
	queueLabels.solo = makePad("Zone solo", CENTER + Vector3.new(-9, 0.5, 12), Color3.fromRGB(180, 140, 90), "Partie solo",
		function()
			requestedMode = "solo"
			launchRequested = true
			updateQueues()
		end)
	queueLabels.duo = makePad("Zone duo", CENTER + Vector3.new(9, 0.5, 12), Color3.fromRGB(120, 150, 170), "Partie duo",
		function()
			requestedMode = "duo"
			updateQueues()
		end)
	-- Décor : piliers et banc, pour que le hub ait une ambiance propre
	for _, corner in ipairs({ Vector3.new(-26, 6, -26), Vector3.new(26, 6, -26), Vector3.new(-26, 6, 26), Vector3.new(26, 6, 26) }) do
		local pillar = Instance.new("Part")
		pillar.Name = "Pilier"
		pillar.Anchored = true
		pillar.Size = Vector3.new(3, 12, 3)
		pillar.Position = CENTER + corner
		pillar.Color = Color3.fromRGB(60, 56, 52)
		pillar.Material = Enum.Material.Concrete
		pillar.Parent = folder
	end
	local bench = Instance.new("Part")
	bench.Name = "Banc"
	bench.Anchored = true
	bench.Size = Vector3.new(10, 1, 2)
	bench.Position = CENTER + Vector3.new(0, 1, -18)
	bench.Color = Color3.fromRGB(90, 62, 40)
	bench.Material = Enum.Material.Wood
	bench.Parent = folder

	setSpawns(true)
end

-- Renvoie les joueurs vers le lieu hub (après une fin, dans le lieu de jeu)
local function sendToHubPlace(players)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Config.Game.Places.hub, players)
	end)
	if not ok then
		warn("[Hub] retour au hub impossible : " .. tostring(err))
	end
end

-- Tous les joueurs au hub (ou retour au lieu hub, si ce lieu est le lieu de jeu)
function Hub.enter()
	launchRequested = false
	requestedMode = nil
	if role == "game" then
		sendToHubPlace(Players:GetPlayers())
		return
	end
	setSpawns(true)
	local spawnPart = folder and folder:FindFirstChild("HubSpawn")
	local cf = spawnPart and (spawnPart.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(CENTER + Vector3.new(0, 4, 0))
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, cf)
	end
end

-- Bloque jusqu'au lancement. Lieu hub : la borne ou le délai. Lieu de jeu : 5 s après l'arrivée.
-- Retourne la liste des joueurs présents
function Hub.waitForStart()
	if role == "game" then
		while #Players:GetPlayers() == 0 do
			task.wait(0.5)
		end
		task.wait(5) -- laisse arriver le second joueur s'il suit
		return Players:GetPlayers()
	end
	local firstSeen = nil
	while true do
		local present = Players:GetPlayers()
		updateQueues()
		if #present > 0 then
			firstSeen = firstSeen or os.clock()
			local waited = os.clock() - firstSeen
			local mode = requestedMode
			if launchRequested then
				mode = mode or "solo"
			end
			if HubRules.shouldLaunch(mode, #present, waited, Config.Game) then
				return present
			end
		else
			firstSeen = nil
			launchRequested = false
			requestedMode = nil
		end
		task.wait(0.3)
	end
end

-- Lieu hub : réserve un serveur privé du lieu de jeu et y envoie le groupe.
-- Retourne true si la téléportation est lancée (ce serveur n'a plus rien à faire pour ce groupe).
local function sendToPrivateGame(group)
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(Config.Game.Places.game)
		TeleportService:TeleportToPrivateServer(Config.Game.Places.game, code, group)
	end)
	if not ok then
		warn("[Hub] téléportation vers le serveur privé impossible : " .. tostring(err))
	end
	return ok
end

-- Lance la partie pour le groupe : serveur privé (lieu hub), ou cercueil du grenier (autres rôles)
function Hub.startGame(group)
	launchRequested = false
	requestedMode = nil
	if role == "hub" then
		return sendToPrivateGame(group)
	end
	setSpawns(false)
	local cercueil = coffinSpawn()
	local cf = cercueil and (cercueil.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(90, 27, 45)
	for _, player in ipairs(group) do
		teleport(player, cf)
	end
	return true
end

return Hub

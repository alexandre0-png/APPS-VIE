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
local Retry = require(Shared.Retry)
local HubLayout = require(Shared.HubLayout)
local SpawnLog = require(script.Parent.SpawnLog)

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
local queue = {} -- [joueur] = { mode = "solo" | "duo", at = horloge } : file d'attente par borne
local joinedAt = {} -- [joueur] = horloge d'arrivée au hub
local notify = nil -- message court à l'écran des joueurs (défini plus bas)
local queueLabels = {} -- [mode] = BillboardGui TextLabel (file d'attente visible)

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
	SpawnLog.say(
		"%s : téléportation demandée vers (%.1f, %.1f, %.1f), personnage actuel en %s",
		player.Name,
		cf.Position.X,
		cf.Position.Y,
		cf.Position.Z,
		SpawnLog.where(char)
	)
	if char then
		char:PivotTo(cf)
	else
		task.spawn(function()
			-- Un chargement est peut-être déjà en route (porte d'apparition, chien de garde) : on lui laisse 2 s
			-- avant d'en lancer un second, qui détruirait le premier personnage.
			local waited = 0
			while not player.Character and player.Parent and waited < 2 do
				task.wait(0.25)
				waited = waited + 0.25
			end
			if not player.Character and player.Parent then
				player:LoadCharacter()
			end
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

-- Met à jour les panneaux : nombre de joueurs en file pour chaque borne
local function updateQueues()
	local counts = { solo = 0, duo = 0 }
	for player, entry in pairs(queue) do
		if player.Parent then
			counts[entry.mode] = (counts[entry.mode] or 0) + 1
		end
	end
	for mode, label in pairs(queueLabels) do
		if label and label.Parent then
			label.Text = HubRules.queueText(
				mode == "duo" and "Partie duo" or "Partie solo",
				counts[mode] or 0,
				mode == "duo" and 2 or 1
			)
		end
	end
end

-- Appui sur une borne : entre dans la file de cette borne ; un second appui sur la même borne la quitte
local function pressPad(player, mode)
	if typeof(player) ~= "Instance" then
		return
	end
	local entry = queue[player]
	if entry and entry.mode == mode then
		queue[player] = nil
		notify({ player }, "Tu as quitté la file d'attente.")
	else
		queue[player] = { mode = mode, at = os.clock() }
		if mode == "duo" then
			notify(
				{ player },
				("Partie duo : en attente d'un second joueur, %d s au plus, puis la partie démarre en solo."):format(
					Config.Game.DuoWait
				)
			)
		else
			notify({ player }, "Départ pour la partie solo.")
		end
	end
	updateQueues()
end

-- Limites invisibles : quatre murs et un plafond autour de la zone du hub, pour que personne ne sorte ni ne tombe.
-- Ces pièces sont volontairement transparentes et collisionnables ; elles ne sont ni cliquables ni détectables.
local function buildBounds()
	local bounds = HubLayout.BOUNDS
	local boundsFolder = Instance.new("Folder")
	boundsFolder.Name = "Limites"
	boundsFolder.Parent = folder
	for _, b in ipairs(HubLayout.boundBoxes()) do
		local wall = Instance.new("Part")
		wall.Name = b.name
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanQuery = false
		wall.CanTouch = false
		wall.Transparency = 1
		wall.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
		wall.Position = CENTER + Vector3.new(b.pos[1], b.pos[2], b.pos[3])
		wall.Parent = boundsFolder
	end
	return bounds
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
	queueLabels.solo = makePad(
		"Zone solo",
		CENTER + Vector3.new(-9, 0.5, 12),
		Color3.fromRGB(180, 140, 90),
		"Partie solo",
		function(player)
			pressPad(player, "solo")
		end
	)
	queueLabels.duo = makePad(
		"Zone duo",
		CENTER + Vector3.new(9, 0.5, 12),
		Color3.fromRGB(120, 150, 170),
		"Partie duo",
		function(player)
			pressPad(player, "duo")
		end
	)
	-- Décor : piliers et banc, pour que le hub ait une ambiance propre
	for _, corner in ipairs({
		Vector3.new(-26, 6, -26),
		Vector3.new(26, 6, -26),
		Vector3.new(-26, 6, 26),
		Vector3.new(26, 6, 26),
	}) do
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

	-- Ambiance : brume légère et lumière froide, plus les lampes de couleur aux piliers
	pcall(function()
		local Lighting = game:GetService("Lighting")
		Lighting.ClockTime = 22
		Lighting.Ambient = Color3.fromRGB(20, 18, 22)
		Lighting.OutdoorAmbient = Color3.fromRGB(16, 16, 22)
		Lighting.FogColor = Color3.fromRGB(28, 26, 30)
		Lighting.FogStart = 60
		Lighting.FogEnd = 260
		local haze = Lighting:FindFirstChild("HubBrume") or Instance.new("Atmosphere")
		haze.Name = "HubBrume"
		haze.Density = 0.3
		haze.Color = Color3.fromRGB(120, 110, 100)
		haze.Haze = 1.2
		haze.Parent = Lighting
	end)
	for _, p in ipairs(folder:GetChildren()) do
		if p.Name == "Pilier" then
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 0.6
			glow.Color = Color3.fromRGB(255, 190, 120)
			glow.Parent = p
		end
	end

	-- Panneau d'explication, face à l'arrivée
	local board = Instance.new("Part")
	board.Name = "PanneauExplication"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(22, 8, 0.6)
	board.Position = CENTER + Vector3.new(0, 6, -29)
	board.Color = Color3.fromRGB(30, 26, 24)
	board.Material = Enum.Material.Wood
	board.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- le joueur arrive côté +Z : il voit la face arrière
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(0.92, 0.9)
	text.Position = UDim2.fromScale(0.04, 0.05)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(230, 220, 195)
	text.Font = Enum.Font.Gotham
	text.TextScaled = true
	text.TextWrapped = true
	text.Text = "LA TOMBE DU GRENIER\n"
		.. "Choisis une zone au sol : « Partie solo » ou « Partie duo ».\n"
		.. "Trois vies par joueur. Une mort en coûte une. Un coéquipier peut te réanimer.\n"
		.. "Fouille la maison : papiers, livres, statues et objets répondent à une règle."
	text.Parent = gui

	buildBounds()

	-- Décor du hub (mobilier, bougies, lampes, panneaux, poussière) : n'empêche jamais le hub de fonctionner
	local okDecor, errDecor = pcall(function()
		require(script.Parent.HubDecor).build(folder, CENTER)
	end)
	if not okDecor then
		warn("[Hub] décor non construit : " .. tostring(errDecor))
	end

	setSpawns(true)
end

-- Joueurs encore présents sur ce serveur
local function alive(list)
	local out = {}
	for _, player in ipairs(list) do
		if player.Parent then
			table.insert(out, player)
		end
	end
	return out
end

-- Message court à l'écran des joueurs (le hub n'a pas de script client)
notify = function(group, text)
	for _, player in ipairs(group) do
		pcall(function()
			local gui = Instance.new("ScreenGui")
			gui.Name = "MessageHub"
			gui.ResetOnSpawn = false
			local label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Position = UDim2.fromScale(0.5, 0.15)
			label.Size = UDim2.new(0.8, 0, 0, 60)
			label.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
			label.BackgroundTransparency = 0.3
			label.TextColor3 = Color3.fromRGB(230, 220, 200)
			label.TextWrapped = true
			label.TextSize = 20
			label.Font = Enum.Font.GothamMedium
			label.Text = text
			label.Parent = gui
			gui.Parent = player:WaitForChild("PlayerGui", 5)
			task.delay(8, function()
				gui:Destroy()
			end)
		end)
	end
end

local RETRY_DELAYS = { 2, 5 } -- pauses avant les deuxième et troisième essais
local watchdogRunning = false
local failedTries = {} -- [joueur] = échecs de téléportation signalés par le moteur

-- Renvoie les joueurs vers le lieu hub, avec essais répétés, puis joueur par joueur, puis un message clair.
-- Un veilleur recommence tant que des joueurs restent sur ce serveur (aucun joueur coincé).
function Hub.sendPlayersToHub(players)
	local group = alive(players)
	if #group == 0 then
		return true
	end
	local ok, tries, err = Retry.run(function()
		TeleportService:TeleportAsync(Config.Game.Places.hub, alive(group))
	end, RETRY_DELAYS, task.wait)
	if not ok then
		warn(("[Hub] retour au hub impossible après %d essai(s) : %s"):format(tries, tostring(err)))
		notify(group, "Retour au hub difficile : nouvelle tentative en cours. Ne quitte pas le jeu.")
		for _, player in ipairs(alive(group)) do
			pcall(function()
				TeleportService:TeleportAsync(Config.Game.Places.hub, { player })
			end)
		end
	end
	if not watchdogRunning then
		watchdogRunning = true
		task.spawn(function()
			for _ = 1, 6 do
				task.wait(25)
				local left = alive(Players:GetPlayers())
				if #left == 0 then
					break
				end
				notify(left, "Retour au hub en cours...")
				pcall(function()
					TeleportService:TeleportAsync(Config.Game.Places.hub, left)
				end)
			end
			watchdogRunning = false
		end)
	end
	return ok
end

-- Échec signalé par le moteur après une téléportation acceptée : message, puis jusqu'à deux nouveaux essais
pcall(function()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		failedTries[player] = (failedTries[player] or 0) + 1
		warn(
			("[Hub] téléportation de %s refusée (%s) : %s"):format(player.Name, tostring(result), tostring(message))
		)
		if failedTries[player] > 2 or not placeId then
			notify({ player }, "La téléportation a échoué. Réessaie dans quelques instants.")
			return
		end
		notify({ player }, "La téléportation a échoué, nouvel essai dans 3 secondes.")
		task.delay(3, function()
			if player.Parent then
				pcall(function()
					TeleportService:TeleportAsync(placeId, { player }, options)
				end)
			end
		end)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	failedTries[player] = nil
	queue[player] = nil
	joinedAt[player] = nil
end)

-- Tous les joueurs au hub (ou retour au lieu hub, si ce lieu est le lieu de jeu)
function Hub.enter()
	if role == "game" then
		Hub.sendPlayersToHub(Players:GetPlayers())
		return
	end
	setSpawns(true)
	local spawnPart = folder and folder:FindFirstChild("HubSpawn")
	local cf = spawnPart and (spawnPart.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(CENTER + Vector3.new(0, 4, 0))
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, cf)
	end
end

-- Bloque jusqu'au prochain groupe à lancer (un joueur seul, un duo, ou le plus ancien arrivé).
-- Lieu de jeu : le premier arrivé, et son partenaire s'il arrive dans les 5 s. Retourne la liste des joueurs du groupe.
function Hub.waitForStart()
	if role == "game" then
		while #Players:GetPlayers() == 0 do
			task.wait(0.5)
		end
		task.wait(5) -- laisse arriver le second joueur s'il suit
		local group = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if #group < (Config.Game.MaxPlayers or 2) then
				table.insert(group, player)
			end
		end
		return group
	end
	while true do
		local list = {}
		local byId = {}
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			joinedAt[player] = joinedAt[player] or now
			local entry = queue[player]
			table.insert(list, {
				id = player.UserId,
				joinedAt = joinedAt[player],
				queue = entry and entry.mode or nil,
				queuedAt = entry and entry.at or 0,
			})
			byId[player.UserId] = player
		end
		updateQueues()
		local ids = HubRules.nextGroup(list, now, Config.Game)
		if ids then
			local group = {}
			for _, id in ipairs(ids) do
				local player = byId[id]
				if player then
					queue[player] = nil
					joinedAt[player] = nil
					table.insert(group, player)
				end
			end
			if #group > 0 then
				updateQueues()
				return group
			end
		end
		task.wait(0.3)
	end
end

-- Même expérience : le lieu de jeu est un autre lieu de l'expérience. Serveur privé d'abord (deux essais) ;
-- si Roblox refuse, repli sur un serveur public (deux essais) avec un message clair.
local function sendToPrivateGame(group)
	local ok, _, err = Retry.run(function()
		local code = TeleportService:ReserveServer(Config.Game.Places.game)
		TeleportService:TeleportToPrivateServer(Config.Game.Places.game, code, alive(group))
	end, { 2 }, task.wait)
	if ok then
		return true
	end
	warn("[Hub] serveur privé impossible, repli sur un serveur public : " .. tostring(err))
	notify(
		group,
		"Serveur privé indisponible : tu rejoins un serveur public. Tu risques d'y croiser d'autres joueurs."
	)
	local okPublic, _, errPublic = Retry.run(function()
		TeleportService:TeleportAsync(Config.Game.Places.game, alive(group))
	end, { 2, 4 }, task.wait)
	if not okPublic then
		warn("[Hub] téléportation publique impossible : " .. tostring(errPublic))
		notify(group, "Impossible de lancer la partie pour l'instant. Réessaie dans quelques secondes.")
	end
	return okPublic
end

-- Lance la partie pour le groupe : serveur privé (lieu hub), ou cercueil du grenier (autres rôles)
function Hub.startGame(group)
	group = alive(group)
	if #group == 0 then
		return false
	end
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

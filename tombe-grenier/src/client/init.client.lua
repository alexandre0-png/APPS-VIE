--[[
  Client : vue première personne, HUD, effets de sanité, saisie du code, entrées.
  Aucune décision de gameplay ici : le client envoie des intentions, le serveur décide.
  Pas de sang : les coups se traduisent par un voile sombre et un son.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Cinematic = require(script.Cinematic)

local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson

-- Interface
local gui = Instance.new("ScreenGui")
gui.Name = "TombeHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function fullFrame(color, transparency, zIndex)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	frame.Parent = gui
	return frame
end

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.fromRGB(218, 214, 200)
	l.TextSize = props.size or 18
	-- Lisible sur téléphone comme sur grand écran : le texte se règle, dans des bornes
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 13
	limit.MaxTextSize = props.size or 18
	limit.Parent = l
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Position = props.position
	l.AnchorPoint = props.anchor or Vector2.zero
	l.Size = props.sizeUDim or UDim2.fromOffset(360, 26)
	l.Text = ""
	l.ZIndex = 5
	l.Parent = gui
	return l
end

local tint = fullFrame(Color3.fromRGB(40, 40, 44), 1, 1)

local blackFrame = fullFrame(Color3.new(0, 0, 0), 1, 50)

-- HUD minimal : seul l'objectif reste affiché en permanence
local objectiveLabel = label({ position = UDim2.fromOffset(16, 16), sizeUDim = UDim2.new(0.9, 0, 0, 30) })

-- Message contextuel (indice, lecture, retour d'action) : bas de l'écran
local subtitleLabel = label({
	position = UDim2.new(0.5, 0, 1, -110),
	anchor = Vector2.new(0.5, 1),
	sizeUDim = UDim2.new(0.7, 0, 0, 70),
	align = Enum.TextXAlignment.Center,
	size = 20,
})
subtitleLabel.TextTransparency = 1

-- Message de fin de partie : centre
local messageLabel = label({
	position = UDim2.fromScale(0.5, 0.5),
	anchor = Vector2.new(0.5, 0.5),
	sizeUDim = UDim2.new(0.9, 0, 0, 90),
	align = Enum.TextXAlignment.Center,
	size = 26,
})
messageLabel.TextTransparency = 1

-- Indication demandée (touche H) : bas à gauche, reste affichée jusqu'à la suivante
local hintLabel = label({
	position = UDim2.new(0, 16, 1, -40),
	sizeUDim = UDim2.new(0.6, 0, 0, 40),
	size = 18,
})

-- Règles affichées au réveil : une fois, puis elles s'effacent
local function showRules()
	local rules = label({
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		sizeUDim = UDim2.new(0.9, 0, 0, 170),
		align = Enum.TextXAlignment.Center,
		size = 22,
	})
	rules.Text = "Tu as trois vies. Une mort t'en coûte une.\n"
		.. "Ton coéquipier peut te réanimer s'il est près de toi.\n"
		.. "Fouille la maison : papiers, livres, statues et objets répondent à une règle.\n"
		.. "Touche H pour une indication. Ctrl ralentit tes pas, Maj court, F éclaire."
	task.delay(12, function()
		TweenService:Create(rules, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
	end)
end

-- Sanité : effet visuel (voile sombre), sans chiffre à l'écran
local function refreshSanity()
	local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
	-- Sanité haute : écran intact. Sanité basse : voile sombre qui couvre l'écran.
	tint.BackgroundTransparency = 1 - (1 - sanity / Config.Player.SanityMax) * 0.6
end

player:GetAttributeChangedSignal("Sanity"):Connect(refreshSanity)
refreshSanity()

local function flash(color, alpha, duration)
	local frame = fullFrame(color, 1 - alpha, 30)
	TweenService:Create(frame, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
	task.delay(duration, function()
		frame:Destroy()
	end)
end

local function blackout(duration)
	blackFrame.BackgroundTransparency = 0
	task.delay(duration, function()
		TweenService:Create(blackFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	end)
end

local function fadeOut(lbl, delay)
	task.delay(delay, function()
		TweenService:Create(lbl, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
	end)
end

local function showSubtitle(text)
	subtitleLabel.Text = text
	subtitleLabel.TextTransparency = 0
	fadeOut(subtitleLabel, 6)
end

local function showMessage(text)
	messageLabel.Text = text
	messageLabel.TextTransparency = 0
	fadeOut(messageLabel, 8)
end

-- Écran de saisie du code (coffret à bijoux)
local keypad = Instance.new("Frame")
keypad.Size = UDim2.fromOffset(300, 170)
keypad.Position = UDim2.fromScale(0.5, 0.5)
keypad.AnchorPoint = Vector2.new(0.5, 0.5)
keypad.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
keypad.BorderSizePixel = 0
keypad.Visible = false
keypad.ZIndex = 40
keypad.Parent = gui

local keypadTitle = label({ position = UDim2.fromOffset(16, 12), sizeUDim = UDim2.fromOffset(268, 24), size = 18 })
keypadTitle.Text = "Coffret à bijoux"
keypadTitle.Parent = keypad
keypadTitle.ZIndex = 41

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.fromOffset(268, 48)
codeBox.Position = UDim2.fromOffset(16, 48)
codeBox.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
codeBox.TextColor3 = Color3.fromRGB(230, 220, 190)
codeBox.Font = Enum.Font.Code
codeBox.TextSize = 32
codeBox.PlaceholderText = "????"
codeBox.Text = ""
codeBox.ClearTextOnFocus = false
codeBox.ZIndex = 41
codeBox.Parent = keypad

local function closeKeypad()
	keypad.Visible = false
end

local function submitCode()
	local text = codeBox.Text
	if #text == 4 then
		Remotes.get("SubmitCode"):FireServer(text)
		codeBox.Text = ""
		closeKeypad()
	end
end

-- Seuls les chiffres, quatre maximum
codeBox:GetPropertyChangedSignal("Text"):Connect(function()
	local digits = codeBox.Text:gsub("%D", ""):sub(1, 4)
	if digits ~= codeBox.Text then
		codeBox.Text = digits
	end
	if #digits == 4 then
		submitCode()
	end
end)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(268, 40)
closeButton.Position = UDim2.fromOffset(16, 110)
closeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
closeButton.TextColor3 = Color3.fromRGB(218, 214, 200)
closeButton.Font = Enum.Font.GothamMedium
closeButton.TextSize = 18
closeButton.Text = "Refermer"
closeButton.ZIndex = 41
closeButton.Parent = keypad
closeButton.Activated:Connect(closeKeypad)

-- Battements de cœur : pendant la poursuite ou à sanité basse
task.spawn(function()
	while true do
		local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
		local chasing = workspace:GetAttribute("MonsterChasing") == true
		if chasing or sanity < Config.Player.SanityLow then
			Audio.play("battement", gui, { lifetime = 3 })
			task.wait(chasing and 0.8 or 0.6 + sanity / 50)
		else
			task.wait(0.5)
		end
	end
end)

-- Lampe UV : bascule le mode ; les marques UV (tag UVMark) apparaissent avec leur texte
local uvOn = false
local uvLabels = {}
local function setUv(on)
	uvOn = on
	Audio.play("clic_lampe", gui, { lifetime = 2 })
	for _, mark in ipairs(CollectionService:GetTagged("UVMark")) do
		if mark:IsA("BasePart") then
			mark.Transparency = on and 0.2 or 1
			if on and not uvLabels[mark] then
				local billboard = Instance.new("BillboardGui")
				billboard.Size = UDim2.fromOffset(260, 60)
				billboard.StudsOffset = Vector3.new(0, 1.5, 0)
				billboard.AlwaysOnTop = true
				billboard.Parent = mark
				local text = Instance.new("TextLabel")
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 0.4
				text.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
				text.TextColor3 = Color3.fromRGB(190, 140, 255)
				text.Font = Enum.Font.GothamMedium
				text.TextScaled = true
				text.TextWrapped = true
				text.Text = mark:GetAttribute("Text") or ""
				text.Parent = billboard
				uvLabels[mark] = billboard
			end
			if uvLabels[mark] then
				uvLabels[mark].Enabled = on
			end
		end
	end
end

local function toggleUv()
	setUv(not uvOn)
end

-- Ambiance continue, baissée pendant une poursuite, et musique de poursuite tant que le monstre chasse
local ambience = Audio.play("ambiance", gui)
local chaseMusic = nil
local tensionMusic = nil
local function updateMusic()
	local chasing = workspace:GetAttribute("MonsterChasing") == true
	local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
	local low = sanity < Config.Player.SanityLow
	if ambience then
		ambience.Volume = chasing and 0.15 or (low and 0.55 or 0.4)
	end
	if chasing and not chaseMusic then
		chaseMusic = Audio.play("poursuite", gui)
	elseif not chasing and chaseMusic then
		chaseMusic:Destroy()
		chaseMusic = nil
	end
	-- Tension : sanité basse, hors poursuite
	if low and not chasing and not tensionMusic then
		tensionMusic = Audio.play("ambiance_tension", gui)
	elseif (not low or chasing) and tensionMusic then
		tensionMusic:Destroy()
		tensionMusic = nil
	end
end
workspace:GetAttributeChangedSignal("MonsterChasing"):Connect(updateMusic)
player:GetAttributeChangedSignal("Sanity"):Connect(updateMusic)
updateMusic()

-- Respiration tant que le joueur est caché (attribut posé par le serveur)
local breath = nil
player:GetAttributeChangedSignal("Hidden"):Connect(function()
	if player:GetAttribute("Hidden") then
		breath = Audio.play("respiration", gui)
	elseif breath then
		breath:Destroy()
		breath = nil
	end
end)

-- Réveil : noir, puis la vue revient doucement
local function introSequence(duration)
	blackFrame.BackgroundTransparency = 0
	task.delay(duration * 0.4, function()
		TweenService:Create(blackFrame, TweenInfo.new(duration * 0.5), { BackgroundTransparency = 1 }):Play()
	end)
end

-- Flashbacks : séquences courtes (6 s au plus), sans texte, avec un son déjà fourni.
-- Chaque étape : { couleur, opacité, durée }.
local FLASHBACK_SEQUENCES = {
	family = {
		sound = nil,
		steps = {
			{ Color3.fromRGB(120, 95, 60), 0.5, 1.6 },
			{ Color3.fromRGB(90, 60, 40), 0.6, 1.2 },
			{ Color3.fromRGB(20, 20, 35), 0.55, 1.4 },
			{ Color3.fromRGB(10, 10, 10), 0.7, 1.2 },
		},
	},
	cahier = {
		sound = "chaise_grince",
		steps = {
			{ Color3.fromRGB(230, 225, 205), 0.7, 1.2 },
			{ Color3.fromRGB(40, 40, 50), 0.6, 1.0 },
			{ Color3.fromRGB(230, 225, 205), 0.5, 0.9 },
		},
	},
	journal = {
		sound = "porte_grince",
		steps = {
			{ Color3.fromRGB(60, 40, 30), 0.4, 1.0 },
			{ Color3.fromRGB(10, 10, 12), 0.8, 1.4 },
			{ Color3.fromRGB(60, 40, 30), 0.5, 1.0 },
		},
	},
	plaque = {
		sound = "cri_loin",
		steps = {
			{ Color3.fromRGB(20, 20, 30), 0.7, 1.5 },
			{ Color3.fromRGB(180, 40, 40), 0.6, 0.8 },
			{ Color3.fromRGB(10, 10, 10), 0.9, 1.2 },
		},
	},
}

local function flashbackSequence(kind)
	local seq = FLASHBACK_SEQUENCES[kind] or FLASHBACK_SEQUENCES.family
	if seq.sound then
		Audio.play(seq.sound, gui, { lifetime = 4 })
	end
	task.spawn(function()
		for _, step in ipairs(seq.steps) do
			local frame = fullFrame(step[1], 1 - step[2], 35)
			task.wait(step[3])
			frame:Destroy()
		end
	end)
end

-- Teinte de fin : levée du jour pour la fuite, lumière douce pour la vérité, obscurité pour la malédiction
local ENDING_TINT = {
	win = { Color3.fromRGB(255, 150, 80), 0.25 },
	truth = { Color3.fromRGB(255, 230, 180), 0.2 },
	lose = { Color3.fromRGB(0, 0, 0), 0.5 },
}
local function endingVisual(reason)
	local tint = ENDING_TINT[reason]
	if tint then
		local frame = fullFrame(tint[1], 1 - tint[2], 25)
		frame.Name = "FinTeinte"
	end
end

-- Bouton « Rejouer », visible après une fin
local restartButton = Instance.new("TextButton")
restartButton.Size = UDim2.fromOffset(220, 46)
restartButton.Position = UDim2.new(0.5, 0, 0.66, 0)
restartButton.AnchorPoint = Vector2.new(0.5, 0.5)
restartButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
restartButton.TextColor3 = Color3.fromRGB(230, 220, 190)
restartButton.Font = Enum.Font.GothamMedium
restartButton.TextSize = 20
restartButton.Text = "Rejouer"
restartButton.Visible = false
restartButton.ZIndex = 45
restartButton.Parent = gui
restartButton.Activated:Connect(function()
	Remotes.get("Restart"):FireServer()
	restartButton.Visible = false
end)

-- Événements serveur
Remotes.get("Effect").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "Hit" then
		flash(Color3.fromRGB(10, 10, 12), 0.6, 0.6)
	elseif data.kind == "Scare" then
		flash(Color3.new(1, 1, 1), 0.6, 0.15)
		Audio.play("stinger_peur", gui, { lifetime = 3 })
		-- le son du débusquage est joué côté serveur (PlayerState.unhide)
	elseif data.kind == "Cine" then
		Cinematic.play(data.name, gui)
	elseif data.kind == "Intro" then
		restartButton.Visible = false
		introSequence(data.duration or 8)
		showRules()
	elseif data.kind == "Blackout" then
		blackout(data.duration or 2)
	elseif data.kind == "RoundEnd" then
		-- Le texte de fin et le bouton attendent la fin de la cinématique
		task.spawn(function()
			while Cinematic.isPlaying() do
				task.wait(0.2)
			end
			showMessage(data.text or "")
			endingVisual(data.reason)
			restartButton.Visible = true
		end)
	end
end)

-- Inventaire : en haut à droite, ce que le joueur a en main
local inventoryLabel = label({
	position = UDim2.new(1, -16, 0, 16),
	anchor = Vector2.new(1, 0),
	sizeUDim = UDim2.new(0.42, 0, 0, 120),
	align = Enum.TextXAlignment.Right,
	size = 18,
})
local inventory = { photos = 0, photosRequired = 3, hasKey = false, smallKey = false, caveKey = false, docs = 0, docsTotal = 4 }

local function refreshInventory()
	local lines = {
		("Souvenirs %d/%d"):format(inventory.photos, inventory.photosRequired),
		("Documents %d/%d"):format(inventory.docs, inventory.docsTotal),
	}
	if inventory.smallKey then
		table.insert(lines, "Petite clé")
	end
	if inventory.caveKey then
		table.insert(lines, "Clé de la cave")
	end
	if inventory.hasKey then
		table.insert(lines, "Clé rouillée")
	end
	inventoryLabel.Text = table.concat(lines, "\n")
end

-- Progression de l'équipe (photos, clé de la sortie) : envoyée par le serveur, affichée ici
Remotes.get("HUD").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		inventory.photos = data.photos or 0
		inventory.photosRequired = data.photosRequired or 3
		inventory.hasKey = data.hasKey == true
		refreshInventory()
	end
end)

Remotes.get("Inventory").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		inventory.smallKey = data.smallKey == true
		inventory.caveKey = data.caveKey == true
		inventory.docs = data.docs or inventory.docs
		inventory.docsTotal = data.docsTotal or inventory.docsTotal
		refreshInventory()
	end
end)

Remotes.get("Hint").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and data.text then
		hintLabel.Text = "Indice : " .. data.text
	end
end)

Remotes.get("Objective").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and data.text then
		objectiveLabel.Text = data.text
	end
end)

Remotes.get("Message").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and data.text then
		showSubtitle(data.text)
	end
end)

Remotes.get("Flashback").OnClientEvent:Connect(function(data)
	flashbackSequence(typeof(data) == "table" and data.kind or "family")
end)

Remotes.get("Keypad").OnClientEvent:Connect(function()
	keypad.Visible = true
	codeBox:CaptureFocus()
end)

-- Entrées : Ctrl = silencieux, Shift = sprint, F = lampe, G = lancer de bruit, Échap = fermer
local function sendQuiet(on)
	Remotes.get("SetQuiet"):FireServer(on)
end

local function sendSprint(on)
	Remotes.get("SetSprint"):FireServer(on)
end

local function sendCrouch(on)
	Remotes.get("SetCrouch"):FireServer(on)
end

local function throwNoise()
	local camera = workspace.CurrentCamera
	if camera then
		Remotes.get("Throw"):FireServer(camera.CFrame.LookVector)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and keypad.Visible then
		closeKeypad()
		return
	end
	if processed or keypad.Visible then
		return
	end
	-- Clavier, et manette (L1 silence, L2 course, B accroupi, Y lampe, R1 lancer, Haut indice)
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.ButtonL1 then
		sendQuiet(true)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		sendSprint(true)
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		Remotes.get("ToggleFlashlight"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		sendCrouch(true)
	elseif input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.DPadUp then
		Remotes.get("AskHint"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonR1 then
		throwNoise()
	elseif input.KeyCode == Enum.KeyCode.U or input.KeyCode == Enum.KeyCode.ButtonR3 then
		toggleUv()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.ButtonL1 then
		sendQuiet(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		sendSprint(false)
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		sendCrouch(false)
	end
end)

-- Actions de jeu : chaque bouton ne s'affiche que quand il sert (contexte), et la touche est rappelée à l'écran
local lastObjectiveAt = os.clock()
Remotes.get("Objective").OnClientEvent:Connect(function()
	lastObjectiveAt = os.clock()
end)

local function nearUvMark(radius)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, mark in ipairs(CollectionService:GetTagged("UVMark")) do
		if mark:IsA("BasePart") and (mark.Position - root.Position).Magnitude < radius then
			return true
		end
	end
	return false
end

local ACTIONS = {
	{ name = "Course", order = 0, always = true, touch = true, kb = "Maj", gp = "L2",
	  down = function() sendSprint(true) end, up = function() sendSprint(false) end },
	{ name = "Accroupi", order = 1, always = true, touch = true, kb = "C", gp = "B",
	  down = function() sendCrouch(true) end, up = function() sendCrouch(false) end },
	{ name = "Lampe", order = 2, touch = true, kb = "F", gp = "Y",
	  visible = function() return player:GetAttribute("InDark") == true end,
	  down = function() Remotes.get("ToggleFlashlight"):FireServer() end },
	{ name = "Lancer", order = 3, touch = true, kb = "G", gp = "R1",
	  visible = function() return (player:GetAttribute("Throws") or 0) > 0 end,
	  down = throwNoise },
	{ name = "UV", order = 4, touch = true, kb = "U", gp = "R3",
	  visible = function() return uvOn or nearUvMark(22) end,
	  down = toggleUv },
	{ name = "Indice", order = 5, touch = true, kb = "H", gp = "Haut",
	  visible = function() return os.clock() - lastObjectiveAt > 60 end,
	  down = function() Remotes.get("AskHint"):FireServer() end },
}

local actionButtons = {}
for _, action in ipairs(ACTIONS) do
	if action.touch then
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 110, 0, 54)
		b.Position = UDim2.new(1, -124, 1, -(70 + action.order * 62))
		b.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		b.BackgroundTransparency = 0.3
		b.TextColor3 = Color3.fromRGB(230, 226, 210)
		b.Font = Enum.Font.GothamMedium
		b.Text = action.name
		b.TextScaled = true
		b.ZIndex = 20
		b.Visible = false
		b.Parent = gui
		if action.down then
			b.MouseButton1Down:Connect(action.down)
		end
		if action.up then
			b.MouseButton1Up:Connect(action.up)
		end
		actionButtons[action] = b
	end
end

-- Rappel des touches (clavier et manette) pour les actions disponibles
local keyHint = label({
	position = UDim2.new(0.5, 0, 1, -40),
	anchor = Vector2.new(0.5, 1),
	sizeUDim = UDim2.new(0.7, 0, 0, 30),
	align = Enum.TextXAlignment.Center,
	size = 16,
})

local function refreshActions()
	local usesTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local usesGamepad = UserInputService.GamepadEnabled
	local parts = {}
	for _, action in ipairs(ACTIONS) do
		local shown = action.always or (action.visible and action.visible()) == true
		if action.touch and actionButtons[action] then
			actionButtons[action].Visible = usesTouch and shown
		end
		if shown and not usesTouch and not action.always then
			table.insert(parts, ("%s : %s"):format(usesGamepad and action.gp or action.kb, action.name))
		end
	end
	keyHint.Text = table.concat(parts, "     ")
end

task.spawn(function()
	while true do
		refreshActions()
		task.wait(0.25)
	end
end)

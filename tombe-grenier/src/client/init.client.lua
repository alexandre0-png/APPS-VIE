--[[
  Client : vue première personne, HUD, effets de sanité, saisie du code, entrées.
  Aucune décision de gameplay ici : le client envoie des intentions, le serveur décide.
  Pas de sang : les coups se traduisent par un voile sombre et un son.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)

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

-- Vignette : bords de l'écran assombris, par quatre dégradés (sans image)
local function vignetteEdge(size, position, rotation)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.ZIndex = 2
	frame.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = rotation
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = frame
	return frame
end
vignetteEdge(UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90)
vignetteEdge(UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90)
vignetteEdge(UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0)
vignetteEdge(UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180)
local blackFrame = fullFrame(Color3.new(0, 0, 0), 1, 50)

local objectiveLabel = label({ position = UDim2.fromOffset(16, 16), sizeUDim = UDim2.fromOffset(640, 26) })
local statsLabel = label({ position = UDim2.new(0, 16, 1, -40) })

-- Message contextuel (indice, lecture, retour d'action) : bas de l'écran
local subtitleLabel = label({
	position = UDim2.new(0.5, 0, 1, -110),
	anchor = Vector2.new(0.5, 1),
	sizeUDim = UDim2.fromOffset(820, 70),
	align = Enum.TextXAlignment.Center,
	size = 20,
})
subtitleLabel.TextTransparency = 1

-- Message de fin de partie : centre
local messageLabel = label({
	position = UDim2.fromScale(0.5, 0.5),
	anchor = Vector2.new(0.5, 0.5),
	sizeUDim = UDim2.fromOffset(760, 90),
	align = Enum.TextXAlignment.Center,
	size = 26,
})
messageLabel.TextTransparency = 1

-- Affichage des attributs serveur
local function refreshStats()
	local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
	-- Sanité haute : écran intact. Sanité basse : voile sombre qui couvre l'écran.
	tint.BackgroundTransparency = 1 - (1 - sanity / Config.Player.SanityMax) * 0.6

	local stamina = player:GetAttribute("Stamina") or 100
	local battery = player:GetAttribute("Battery") or 100
	statsLabel.Text = ("Endurance %d%%   ·   Lampe %d%%"):format(math.floor(stamina), math.floor(battery))
end

player:GetAttributeChangedSignal("Sanity"):Connect(refreshStats)
player:GetAttributeChangedSignal("Stamina"):Connect(refreshStats)
player:GetAttributeChangedSignal("Battery"):Connect(refreshStats)
refreshStats()

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

-- Ambiance continue
Audio.play("ambiance", gui)

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

-- Événements serveur
Remotes.get("Effect").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "Hit" then
		flash(Color3.fromRGB(10, 10, 12), 0.6, 0.6)
	elseif data.kind == "Scare" then
		flash(Color3.new(1, 1, 1), 0.6, 0.15)
		-- le son du débusquage est joué côté serveur (PlayerState.unhide)
	elseif data.kind == "Blackout" then
		blackout(data.duration or 2)
	elseif data.kind == "RoundEnd" then
		showMessage(data.text or "")
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
	if input.KeyCode == Enum.KeyCode.LeftControl then
		sendQuiet(true)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(true)
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.get("ToggleFlashlight"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		throwNoise()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftControl then
		sendQuiet(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(false)
	end
end)

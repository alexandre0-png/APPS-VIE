--[[
  Client : vue première personne, HUD minimal, effets de sanité, entrées.
  Aucune décision de gameplay ici : le client envoie des intentions, le serveur décide.
  Pas de menu, pas de sous-titres, pas de texte explicatif.
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
	l.Position = props.position
	l.AnchorPoint = props.anchor or Vector2.zero
	l.Size = props.sizeUDim or UDim2.fromOffset(360, 26)
	l.Text = ""
	l.ZIndex = 5
	l.Parent = gui
	return l
end

local tint = fullFrame(Color3.fromRGB(90, 0, 0), 1, 1)
local blackFrame = fullFrame(Color3.new(0, 0, 0), 1, 50)

local objectiveLabel = label({ position = UDim2.fromOffset(16, 16) })
local statsLabel = label({ position = UDim2.new(0, 16, 1, -40) })

local messageLabel = label({
	position = UDim2.fromScale(0.5, 0.5),
	anchor = Vector2.new(0.5, 0.5),
	sizeUDim = UDim2.fromOffset(700, 60),
	align = Enum.TextXAlignment.Center,
	size = 26,
})
messageLabel.TextTransparency = 1

-- Affichage des attributs serveur
local function refreshStats()
	local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
	-- Sanité haute : écran intact. Sanité basse : teinte rouge sombre qui couvre l'écran.
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

local ROUND_MESSAGES = {
	win = "Tu t'échappes de la tombe.",
	lose = "La tombe te reprend.",
}

local function showMessage(text)
	messageLabel.Text = text
	messageLabel.TextTransparency = 0
	task.delay(4, function()
		TweenService:Create(messageLabel, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
	end)
end

-- Battements de cœur à sanité basse
task.spawn(function()
	while true do
		local sanity = player:GetAttribute("Sanity") or Config.Player.SanityMax
		if sanity < Config.Player.SanityLow then
			Audio.play("heartbeat", gui, { volume = 0.6, lifetime = 3 })
			task.wait(0.6 + sanity / 50)
		else
			task.wait(0.5)
		end
	end
end)

-- Événements serveur
Remotes.get("Effect").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "Hit" then
		flash(Color3.fromRGB(140, 0, 0), 0.5, 0.5)
	elseif data.kind == "Scare" then
		flash(Color3.new(1, 1, 1), 0.6, 0.15)
		Audio.play("scare", gui, { lifetime = 4 })
	elseif data.kind == "Blackout" then
		blackout(data.duration or 2)
	elseif data.kind == "RoundEnd" then
		showMessage(ROUND_MESSAGES[data.reason] or "")
	end
end)

Remotes.get("HUD").OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	local key = data.hasKey and "oui" or "non"
	if data.exitReady then
		objectiveLabel.Text = "Sortie ouverte"
	else
		objectiveLabel.Text = ("Photos %d/%d · Clé : %s"):format(data.photos or 0, data.photosRequired or 0, key)
	end
end)

-- Entrées : Ctrl = silencieux (maintenu), Shift = sprint (maintenu), F = lampe
local function sendQuiet(on)
	Remotes.get("SetQuiet"):FireServer(on)
end

local function sendSprint(on)
	Remotes.get("SetSprint"):FireServer(on)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftControl then
		sendQuiet(true)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(true)
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.get("ToggleFlashlight"):FireServer()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftControl then
		sendQuiet(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(false)
	end
end)

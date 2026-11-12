-- Animation d'introduction : survol du zoo avec le titre, puis la caméra revient derrière le joueur.
-- Jouée une fois par session, dès que le profil est chargé. Un appui n'importe où la passe.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local CameraRig = require(script.Parent.CameraRig)
local Sfx = require(script.Parent.Sfx)

local Intro = {}

local player = Players.LocalPlayer
local played = false

local DURATION = 8

local function plotCenter()
	local center = player:GetAttribute("PlotCenter")
	if typeof(center) == "Vector3" then
		return center
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or Vector3.new(0, 330, 0)
end

local function play()
	if played or ClientState.Status ~= "Lobby" then
		return
	end
	played = true

	local center = plotCenter()
	local gui = UI.make("ScreenGui", {
		Name = "HerdHopperIntro",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
	}, player:WaitForChild("PlayerGui"))

	local bars = {}
	for _, top in ipairs({ true, false }) do
		bars[#bars + 1] = UI.frame(gui, {
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.new(0, 0, top and 0 or 1, 0),
			Size = UDim2.new(1, 0, 0.12, 0),
			BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		})
	end

	local title = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.new(0.8, 0, 0.18, 0),
		Text = "SAUTE-ZOO",
		maxSize = 110,
		TextColor3 = UI.Colors.Accent,
		TextTransparency = 1,
	})
	local lines = {
		"Ta tante t'a laissé un zoo. Il est vide.",
		"Pars en expédition : saute d'animal en animal.",
		"Un cœur rose ? Récupère-le : il rejoint ton zoo !",
	}
	local sub = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Size = UDim2.new(0.8, 0, 0.07, 0),
		Text = lines[1],
		maxSize = 34,
		Font = UI.FontBody,
		TextTransparency = 1,
	})
	local hint = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.97, 0),
		Size = UDim2.new(0.5, 0, 0.04, 0),
		Text = "Touche l'écran pour passer",
		maxSize = 20,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Muted,
	})

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		CameraRig.stopCinematic()
		gui:Destroy()
	end

	CameraRig.cinematic(function(t)
		-- survol circulaire au-dessus du zoo, qui descend lentement
		local angle = t * 0.32 + 0.6
		local radius = 95 - t * 5
		local height = 70 - t * 4.5
		local eye = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		return CFrame.lookAt(eye, center + Vector3.new(0, 4, 0))
	end, DURATION, finish)

	-- titre et phrases en fondu
	task.spawn(function()
		UI.tween(title, 1.2, { TextTransparency = 0 })
		Sfx.play("go")
		task.wait(1.6)
		for index, line in ipairs(lines) do
			if finished then
				return
			end
			sub.Text = line
			UI.tween(sub, 0.5, { TextTransparency = 0 })
			task.wait(1.8)
			UI.tween(sub, 0.4, { TextTransparency = 1 })
			task.wait(0.45)
			if index == #lines then
				break
			end
		end
	end)

	local connection
	connection = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Keyboard
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			connection:Disconnect()
			finish()
		end
	end)
	task.delay(DURATION + 0.5, function()
		if connection.Connected then
			connection:Disconnect()
		end
		finish()
	end)
	hint.Visible = true
	bars[1].Visible = true
end

function Intro.init()
	local function try()
		if ClientState.Data and ClientState.Data.loaded and player.Character and player:GetAttribute("PlotCenter") then
			task.delay(1.2, play)
		end
	end
	ClientState.connect("Data", try)
	player:GetAttributeChangedSignal("PlotCenter"):Connect(try)
	try()
end

return Intro

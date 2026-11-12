--[[
	Cinematics : séquences caméra courtes (20-40 s), skippables, jamais bloquantes.
	- déclenchées uniquement par le serveur (Remote "Cinematic"), une fois par joueur
	- bandes noires, légendes, bouton "Passer" (+ Espace / Entrée / B manette)
	- se terminent seules en cas de mort, d'erreur ou de dépassement de durée ; la caméra est toujours restaurée
	Réglages : Config.Cinematics (global) et Config.Cinematics.Sequences.<id>.enabled
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("CinematicLogic"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Cinematics = {}
local player = Players.LocalPlayer
local cfg = Config.Cinematics

local mainGui
local queue = {}
local current -- { lp = lecteur, cleanup = fn }

function Cinematics.isPlaying()
	return current ~= nil
end

function Cinematics.skip()
	if current and current.lp:skip() then
		current.cleanup()
	end
end

local function center(shot)
	if shot.center == "player" then
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return nil
		end
		local p = hrp.Position
		return { p.X, p.Y, p.Z }
	end
	return shot.center
end

local function run(id)
	local seq = cfg.Sequences[id]
	local ok, msg = Logic.validate(seq)
	if not ok then
		warn("[Cinematics] " .. id .. " invalide: " .. tostring(msg))
		return false
	end
	local cam = workspace.CurrentCamera
	local lp = Logic.newPlayer(seq)

	local gui = UI.new("ScreenGui", { Name = "CityRushCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = player:WaitForChild("PlayerGui") })
	local top, bottom
	if cfg.Letterbox then
		top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
		bottom = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
		TweenService:Create(top, info, { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
		TweenService:Create(bottom, info, { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
	end
	UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 0), Size = UDim2.fromOffset(600, 34), Text = seq.title or "", TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = UI.Theme.Accent, Parent = gui })
	local caption = UI.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.87, 0), Size = UDim2.new(0.8, 0, 0, 60), Text = "", TextSize = 26, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), Parent = gui })
	UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = caption })
	local skipBtn = UI.button({
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 0.95, 0), Size = UDim2.fromOffset(190, 46),
		Text = "Passer ▶  (Espace)", TextSize = 18, BackgroundColor3 = Color3.fromRGB(30, 32, 40), Parent = gui,
	}, function()
		Cinematics.skip()
	end)
	UI.stroke(skipBtn, UI.Theme.Accent, 2)

	local hudWasEnabled = mainGui and mainGui.Enabled
	if cfg.HideHud and mainGui then
		mainGui.Enabled = false
	end
	local prevType, prevSubject = cam.CameraType, cam.CameraSubject
	cam.CameraType = Enum.CameraType.Scriptable

	local conns = {}
	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		pcall(function()
			cam.CameraType = prevType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or prevType
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraSubject = hum or prevSubject
		end)
		if mainGui and hudWasEnabled ~= nil then
			mainGui.Enabled = hudWasEnabled
		end
		gui:Destroy()
		current = nil
		-- cinématique suivante de la file
		task.delay(0.6, function()
			local nextId = table.remove(queue, 1)
			if nextId then
				Cinematics.play(nextId)
			end
		end)
	end
	current = { lp = lp, cleanup = cleanup }

	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		local ok2, err = pcall(function()
			lp:step(math.min(dt, 0.1))
			if lp.finished then
				cleanup()
				return
			end
			local shot, progress = lp:current()
			local c = center(shot)
			if not c then
				lp:skip()
				cleanup()
				return
			end
			local pos, look = Logic.pose(shot, progress, c)
			cam.CFrame = CFrame.lookAt(Vector3.new(pos.x, pos.y, pos.z), Vector3.new(look.x, look.y, look.z))
			caption.Text = shot.caption
		end)
		if not ok2 then
			warn("[Cinematics] erreur, cinématique interrompue: " .. tostring(err))
			cleanup()
		end
	end))
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonB then
			Cinematics.skip()
		end
	end))
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		table.insert(conns, hum.Died:Connect(Cinematics.skip))
	end
	-- filet de sécurité : jamais plus long que prévu
	task.delay(lp.total + 5, function()
		if current and current.lp == lp then
			Cinematics.skip()
			cleanup()
		end
	end)
	return true
end

function Cinematics.play(id)
	if not cfg.Enabled then
		return
	end
	if current then
		Logic.enqueue(queue, id, cfg.MaxQueue)
		return
	end
	local ok, err = pcall(run, id)
	if not ok then
		warn("[Cinematics] " .. id .. ": " .. tostring(err))
		if current then
			current.cleanup()
		end
	end
end

function Cinematics.init(gui)
	mainGui = gui
	State.CinematicRequested:Connect(function(id)
		Cinematics.play(id)
	end)
	State.cinematicsReady = true
	for _, id in ipairs(State.pendingCinematics) do
		Cinematics.play(id)
	end
	State.pendingCinematics = {}
end

return Cinematics

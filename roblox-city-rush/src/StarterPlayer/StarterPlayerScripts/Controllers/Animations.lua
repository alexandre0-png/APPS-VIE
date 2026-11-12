--[[
	Animations : animations arcade (visuelles, locales, sans effet sur la physique ni sur le serveur).
	Chaque animation est activable dans Config.Animations et protégée par pcall.
	Véhicule : roulis dans les virages, plongée/cabrage de suspension, effet de démarrage, dérapage stylisé
	(fumée), porte conducteur, éclair de phares au klaxon. Police : menottes à l'arrestation.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AnimMath = require(Shared:WaitForChild("AnimMath"))
local Util = require(Shared:WaitForChild("Util"))

local VehicleController = require(script.Parent.VehicleController)
local State = require(script.Parent.State)

local Animations = {}
local A = Config.Animations
local player = Players.LocalPlayer

-- Interrupteur : Animations.on("UI", "RewardPop")
function Animations.on(group, key)
	if not A.Enabled then
		return false
	end
	local g = A[group]
	return type(g) == "table" and g[key] == true
end

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Animations] " .. name .. ": " .. tostring(err))
	end
	return ok
end

-- ---------------------------------------------------------------- caméra : roulis + suspension
local lean, pitch = 0, 0
local lastFwd, lastAccel = 0, 0
local driving = false
local cur = { steer = 0, speed = 0, maxSpeed = 80, throttle = 0, fwd = 0 }
local drift = { model = nil, emitters = {} }
local lastSpeedForLaunch = 0

local function ensureDrift(chassis)
	if drift.model == chassis and drift.emitters[1] and drift.emitters[1].Parent then
		return
	end
	for _, e in ipairs(drift.emitters) do
		e:Destroy()
	end
	drift.emitters = {}
	drift.model = chassis
	for _, sx in ipairs({ -1, 1 }) do
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(sx * 3, -2, chassis.Size.Z / 2 - 2.8)
		att.Parent = chassis
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(2, 6)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(225, 225, 230))
		e.Parent = att
		table.insert(drift.emitters, e)
	end
end

local function onVehicle(speed, boost, isDriving, steer, throttle, maxSpeed, fwd)
	driving = isDriving
	if not isDriving then
		for _, e in ipairs(drift.emitters) do
			e.Rate = 0
		end
		return
	end
	cur.steer, cur.speed, cur.maxSpeed, cur.throttle, cur.fwd = steer or 0, speed, maxSpeed or 80, throttle or 0, fwd or speed
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local chassis = seat and seat.Parent and seat.Parent.PrimaryPart
	if not chassis then
		return
	end
	if Animations.on("Vehicle", "Drift") then
		local active, intensity = AnimMath.drift(cur.steer, speed, cur.maxSpeed, A.DriftSteerThreshold, A.DriftSpeedRatio)
		ensureDrift(chassis)
		for _, e in ipairs(drift.emitters) do
			e.Rate = active and (10 + 40 * intensity) or 0
		end
	end
	if Animations.on("Vehicle", "Launch") and AnimMath.launch(lastSpeedForLaunch, speed, cur.throttle) then
		ensureDrift(chassis)
		for _, e in ipairs(drift.emitters) do
			e:Emit(10)
		end
	end
	lastSpeedForLaunch = speed
end

local function cameraStep(dt)
	local targetLean, targetPitch = 0, 0
	if driving then
		if Animations.on("Vehicle", "Lean") then
			targetLean = AnimMath.leanDegrees(cur.steer, cur.speed, cur.maxSpeed, A.MaxLeanDegrees)
		end
		if Animations.on("Vehicle", "Suspension") then
			local accel = (cur.fwd - lastFwd) / math.max(dt, 1e-3)
			lastAccel = AnimMath.smooth(lastAccel, accel, dt, 6)
			targetPitch = AnimMath.pitchDegrees(lastAccel, 2.5)
		end
		lastFwd = cur.fwd
	end
	lean = AnimMath.smooth(lean, targetLean, dt, 5)
	pitch = AnimMath.smooth(pitch, targetPitch, dt, 5)
	if math.abs(lean) > 0.01 or math.abs(pitch) > 0.01 then
		local cam = workspace.CurrentCamera
		-- roulis vers l'intérieur du virage, légère inclinaison avant/arrière
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(pitch), 0, math.rad(-lean))
	end
end

-- ---------------------------------------------------------------- porte conducteur
local function swingDoor(model)
	local door = model and model:FindFirstChild("DoorL")
	local hinge = door and door:FindFirstChild("DoorHinge")
	if not hinge then
		return
	end
	local c0 = hinge.C0
	local duration, openDeg = 0.9, 62
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= duration or not hinge.Parent then
			if hinge.Parent then
				hinge.C0 = c0
			end
			conn:Disconnect()
			return
		end
		hinge.C0 = c0 * CFrame.Angles(0, math.rad(-AnimMath.doorAngle(t, duration, openDeg)), 0)
	end)
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local lastModel
	hum.Seated:Connect(function(active, seat)
		if not Animations.on("Vehicle", "Door") then
			return
		end
		local model = active and seat and seat.Parent or lastModel
		if active then
			lastModel = model
		end
		if model and model:GetAttribute("CRVehicle") then
			safe("porte", swingDoor, model)
		end
	end)
end

-- ---------------------------------------------------------------- klaxon : éclair de phares
local function flashHeadlights()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat.Parent
	if not model then
		return
	end
	task.spawn(function()
		for _ = 1, 2 do
			for _, d in ipairs(model:GetChildren()) do
				if d.Name == "Headlight" then
					d.Color = Color3.new(1, 1, 1)
					d.Material = Enum.Material.Neon
					local l = d:FindFirstChildOfClass("SpotLight")
					if l then
						l.Enabled = true
					end
				end
			end
			task.wait(0.12)
			for _, d in ipairs(model:GetChildren()) do
				if d.Name == "Headlight" then
					d.Color = Color3.fromRGB(255, 244, 200)
					local l = d:FindFirstChildOfClass("SpotLight")
					if l then
						l.Enabled = false
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

-- ---------------------------------------------------------------- menottes (arrestation)
function Animations.playCuffs(parentGui)
	if not Animations.on("Police", "Cuffs") then
		return
	end
	safe("menottes", function()
		local function cuff(fromLeft)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Text = "⛓"
			l.TextSize = 110
			l.Font = Enum.Font.GothamBlack
			l.TextColor3 = Color3.fromRGB(215, 220, 235)
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Size = UDim2.fromOffset(160, 160)
			l.Position = UDim2.new(fromLeft and -0.1 or 1.1, 0, 0.35, 0)
			l.ZIndex = 60
			l.Parent = parentGui
			TweenService:Create(l, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(fromLeft and 0.44 or 0.56, 0, 0.35, 0) }):Play()
			task.delay(2.3, function()
				TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.wait(0.35)
				l:Destroy()
			end)
		end
		cuff(true)
		cuff(false)
		-- "clic" : petite secousse
		task.delay(0.45, function()
			local cam = workspace.CurrentCamera
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				if t > 0.25 then
					conn:Disconnect()
					return
				end
				cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.4, 0)
			end)
		end)
	end)
end

-- ---------------------------------------------------------------- animations d'interface réutilisables
-- Pop d'un élément (échelle 0.6 -> 1 avec rebond) via un UIScale
function Animations.pop(guiObject, from, duration)
	if not guiObject then
		return
	end
	safe("pop", function()
		local scale = guiObject:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = guiObject
		local t0 = os.clock()
		duration = duration or 0.35
		from = from or 0.6
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) / duration
			if t >= 1 or not guiObject.Parent then
				scale.Scale = 1
				conn:Disconnect()
				return
			end
			scale.Scale = from + (1 - from) * AnimMath.popScale(t)
		end)
	end)
end

-- Texte qui se tape tout seul
function Animations.typewrite(label, text, cps)
	cps = cps or 55
	label.Text = ""
	task.spawn(function()
		local t0 = os.clock()
		while label.Parent do
			local t = os.clock() - t0
			label.Text = AnimMath.typewriter(text, t, cps)
			if label.Text == text then
				return
			end
			task.wait(0.03)
		end
	end)
end

function Animations.init()
	if not A.Enabled then
		return
	end
	VehicleController.Updated:Connect(function(...)
		safe("véhicule", onVehicle, ...)
	end)
	RunService:BindToRenderStep("CRAnimations", Enum.RenderPriority.Camera.Value + 2, function(dt)
		safe("caméra", cameraStep, dt)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H and VehicleController.Driving and Animations.on("Vehicle", "Horn") then
			safe("klaxon", flashHeadlights)
		end
	end)
end

return Animations

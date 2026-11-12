--!nonstrict
-- Effets visuels et sonores : arcs de lancer (rejoués depuis le calcul serveur), impacts,
-- bonus flottants, festin, vague de sauce (calculée localement depuis l'heure serveur).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)

local Effects = {}

local localPlayer = Players.LocalPlayer
local swinging: { [Instance]: boolean } = {}

local function c3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function nearCamera(pos: Vector3, maxDist: number): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude <= maxDist
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Color = ColorSequence.new(color)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Acceleration = Vector3.new(0, -30, 0)
	e.LightEmission = 0.4
	e.Parent = anchor
	e:Emit(count)
	Debris:AddItem(anchor, 1.5)
end

local function popup(pos: Vector3, text: string, color: Color3, big: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos + Vector3.new(0, 3, 0)
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromOffset(220, 60) else UDim2.fromOffset(130, 36)
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.MaxDistance = 220
	gui.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Linear), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.3)
end

-- Geste de lancer : on décale brièvement l'épaule (C0) du lanceur, uniquement en local.
local function swingArm(character: Model?)
	if not character then
		return
	end
	local shoulder = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	if not shoulder or not shoulder:IsA("Motor6D") or swinging[shoulder] then
		return
	end
	swinging[shoulder] = true
	local original = shoulder.C0
	local up = TweenService:Create(shoulder, TweenInfo.new(0.1), { C0 = original * CFrame.Angles(math.rad(-140), 0, 0) })
	local down = TweenService:Create(shoulder, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { C0 = original })
	up:Play()
	up.Completed:Connect(function()
		down:Play()
	end)
	down.Completed:Connect(function()
		shoulder.C0 = original
		swinging[shoulder] = nil
	end)
end

-- ---------------------------------------------------------------- lancers

local function onThrowFx(userId: number, foodId: string, origin: Vector3, v: Vector3, tHit: number, kind: string, hitPos: Vector3)
	local food = Economy.findFood(foodId)
	if not food then
		return
	end
	local owner = Players:GetPlayerByUserId(userId)
	swingArm(owner and owner.Character)
	if userId == localPlayer.UserId or nearCamera(origin, 120) then
		UIKit.sfx("Throw", if userId == localPlayer.UserId then 0.5 else 0.25, 0.9 + math.random() * 0.3)
	end
	if userId == localPlayer.UserId and kind ~= "mouth" then
		task.delay(tHit, HUD.hideCombo)
	end

	local p = Instance.new("Part")
	p.Name = "FlyingFood"
	p.Shape = Enum.PartType[food.Shape]
	p.Size = Vector3.new(food.Size[1], food.Size[2], food.Size[3])
	p.Color = c3(food.Color)
	p.Material = Enum.Material[food.Material]
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(origin)
	p.Parent = workspace

	local g = workspace.Gravity
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= tHit then
			conn:Disconnect()
			p:Destroy()
			if kind == "ground" or kind == "none" then
				burst(hitPos, c3(food.Color), 8, 14)
			end
			return
		end
		local x, y, z = Ballistics.position(origin.X, origin.Y, origin.Z, v.X, v.Y, v.Z, t, g)
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(t * 9, t * 6, 0)
	end)
	-- Sécurité : si le client rame, la pièce est détruite quand même.
	Debris:AddItem(p, tHit + 2)
end

local function onFeedFx(hitPos: Vector3, coins: number, userId: number, kind: string, combo: number)
	if kind == "thud" then
		if nearCamera(hitPos, 120) then
			UIKit.sfx("Thud", 0.4, 0.8)
		end
		burst(hitPos, Color3.fromRGB(200, 200, 200), 6, 10)
		return
	end
	local mine = userId == localPlayer.UserId
	local fav = kind == "fav"
	local text = "+" .. Util.formatNumber(coins)
	if fav then
		text ..= " ⭐"
	end
	popup(hitPos, text, if fav then Color3.fromRGB(255, 120, 200) else Color3.fromRGB(255, 220, 70), mine)
	burst(hitPos, if fav then Color3.fromRGB(255, 120, 200) else Color3.fromRGB(255, 200, 60), if mine then 22 else 10, 26)
	if mine then
		UIKit.sfx("Munch", 0.6, 0.95 + math.min(combo, 20) * 0.02)
		UIKit.sfx("Coin", 0.4, 1 + math.min(combo, 20) * 0.03)
		HUD.showCombo(combo)
	elseif nearCamera(hitPos, 120) then
		UIKit.sfx("Munch", 0.3)
	end
end

-- ---------------------------------------------------------------- festin

local function shake(duration: number, intensity: number)
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration and hum.Parent do
			local k = intensity * (1 - (os.clock() - start) / duration)
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			task.wait()
		end
		hum.CameraOffset = Vector3.zero
	end)
end

local function confetti()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Vector3.new(0, 45, 20)
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 230)),
	})
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(25, 55)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.8)
	e.Acceleration = Vector3.new(0, -35, 0)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Parent = anchor
	for _ = 1, 3 do
		e:Emit(80)
		task.wait(0.25)
	end
	Debris:AddItem(anchor, 4)
end

local function onFeastFx(stageName: string, topName: string)
	UIKit.sfx("Roar", 0.9, 0.8)
	UIKit.sfx("Success", 0.6)
	shake(0.7, 1.2)
	task.spawn(confetti)
	local text = "🎉 FESTIN COMPLET ! 🎉"
	if topName ~= "" then
		text ..= "\nMeilleur nourrisseur : " .. topName
	end
	local gui = HUD.gui()
	local l = UIKit.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(640, 120),
		Text = text,
		TextSize = 40,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 220, 70),
		TextStrokeTransparency = 0,
	})
	task.delay(2.5, function()
		TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.9)
		l:Destroy()
	end)
end

-- ---------------------------------------------------------------- événements

local wave: Part? = nil
local waveConn: RBXScriptConnection? = nil

local function stopWave()
	if waveConn then
		waveConn:Disconnect()
		waveConn = nil
	end
	if wave then
		wave:Destroy()
		wave = nil
	end
end

local function startWave(state: Instance)
	stopWave()
	local cfg = Config.Events.Sauce
	local dir = state:GetAttribute("SauceDir") or 1
	local startAt = state:GetAttribute("EventStart") or 0
	local from, to = -cfg.Half, cfg.Half
	if dir < 0 then
		from, to = to, from
	end
	local w = Instance.new("Part")
	w.Name = "SauceWave"
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Size = Vector3.new(12, cfg.Height, 540)
	w.Color = Color3.fromRGB(215, 45, 35)
	w.Material = Enum.Material.SmoothPlastic
	w.Transparency = 0.25
	w.Parent = workspace
	local foam = Instance.new("Part")
	foam.Anchored = true
	foam.CanCollide = false
	foam.CanQuery = false
	foam.CanTouch = false
	foam.Size = Vector3.new(14, 2, 540)
	foam.Color = Color3.fromRGB(255, 230, 220)
	foam.Transparency = 0.1
	foam.Parent = w
	wave = w
	UIKit.sfx("Wave", 0.8)
	waveConn = RunService.RenderStepped:Connect(function()
		local t = (workspace:GetServerTimeNow() - startAt) / cfg.Duration
		t = math.clamp(t, 0, 1)
		local x = from + (to - from) * t
		w.CFrame = CFrame.new(x, cfg.Height / 2, 0)
		foam.CFrame = CFrame.new(x, cfg.Height + 0.5, 0)
	end)
end

local frenzyTint: ColorCorrectionEffect? = nil

function Effects.init()
	Remotes.get("ThrowFx").OnClientEvent:Connect(onThrowFx)
	Remotes.get("FeedFx").OnClientEvent:Connect(onFeedFx)
	Remotes.get("FeastFx").OnClientEvent:Connect(onFeastFx)

	local state = ReplicatedStorage:WaitForChild("GameState")
	local lastKey = ""
	state.AttributeChanged:Connect(function()
		local id = state:GetAttribute("EventId") or ""
		local phase = state:GetAttribute("EventPhase") or ""
		local key = id .. ":" .. phase
		if key == lastKey then
			return
		end
		lastKey = key
		if id == "sauce" and phase == "active" then
			startWave(state)
		elseif id == "sauce" and phase ~= "warning" then
			stopWave()
		elseif id == "" then
			stopWave()
		end
		if id == "frenzy" and phase == "active" then
			if not frenzyTint then
				frenzyTint = Instance.new("ColorCorrectionEffect")
				frenzyTint.TintColor = Color3.fromRGB(255, 225, 190)
				frenzyTint.Parent = game:GetService("Lighting")
			end
		elseif frenzyTint then
			frenzyTint:Destroy()
			frenzyTint = nil
		end
	end)
end

return Effects

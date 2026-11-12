--[[
	VisualFX : effets visuels client, tous réglables dans Config.Visual et protégés par pcall.
	- qualité auto (tactile = low) : bloom / rayons / ombres
	- lampadaires qui éclairent la nuit (budget de lumières par qualité)
	- lueurs bleues/rouges des voitures de police
	- étincelles + secousse caméra lors d'un choc, traînée à grande vitesse
	- étalonnage des couleurs selon l'heure
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local VehicleController = require(script.Parent.VehicleController)

local VisualFX = {}
local V = Config.Visual
local player = Players.LocalPlayer

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[VisualFX] " .. name .. " désactivé: " .. tostring(err))
	end
	return ok
end

local function quality()
	local q = V.Quality
	if q == "auto" then
		return UserInputService.TouchEnabled and "low" or "high"
	end
	return q
end

local function night()
	local t = Lighting.ClockTime
	return t >= 18.3 or t < 5.7
end

-- ---------------------------------------------------------------- qualité globale
local function applyQuality()
	local q = quality()
	local bloom = Lighting:FindFirstChild("CRBloom")
	local rays = Lighting:FindFirstChild("CRSunRays")
	if bloom then
		bloom.Enabled = q ~= "low"
	end
	if rays then
		rays.Enabled = q == "high"
	end
	Lighting.GlobalShadows = q ~= "low"
end

-- ---------------------------------------------------------------- lampadaires
local lampLights = {} -- [part] = PointLight

local function lampLoop()
	local cam = workspace.CurrentCamera
	while true do
		local budget = V.LampLights[quality()] or 6
		local isNight = night()
		local wanted = {}
		if isNight and cam then
			local origin = cam.CFrame.Position
			local near = {}
			for _, part in ipairs(CollectionService:GetTagged("LampHead")) do
				local d = (part.Position - origin).Magnitude
				if d < 170 then
					table.insert(near, { part = part, d = d })
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			for i = 1, math.min(budget, #near) do
				wanted[near[i].part] = true
			end
		end
		for part, on in pairs(wanted) do
			local light = lampLights[part]
			if not light then
				light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 225, 160)
				light.Range = 40
				light.Brightness = 1.4
				light.Shadows = false
				light.Parent = part
				lampLights[part] = light
			end
			light.Enabled = on
		end
		for part, light in pairs(lampLights) do
			if not part.Parent then
				lampLights[part] = nil
			elseif not wanted[part] then
				light.Enabled = false
			end
		end
		task.wait(1)
	end
end

-- ---------------------------------------------------------------- gyrophares
local function sirenLoop()
	local cam = workspace.CurrentCamera
	while true do
		for _, tag in ipairs({ "SirenA", "SirenB" }) do
			for _, part in ipairs(CollectionService:GetTagged(tag)) do
				local light = part:FindFirstChildOfClass("PointLight")
				local near = cam and (part.Position - cam.CFrame.Position).Magnitude < 220
				if near and not light then
					light = Instance.new("PointLight")
					light.Color = tag == "SirenA" and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(60, 90, 255)
					light.Range = 26
					light.Brightness = 3
					light.Shadows = false
					light.Parent = part
				end
				if light then
					light.Enabled = near and part.Transparency < 0.3
				end
			end
		end
		task.wait(0.2)
	end
end

-- ---------------------------------------------------------------- choc & traînée
local shakeT = 0
local function shake(intensity)
	shakeT = math.max(shakeT, intensity)
end

local function burstSparks(chassis)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(25, 45)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 120, 30))
	e.Size = NumberSequence.new(0.5, 0)
	e.LightEmission = 1
	e.Parent = chassis
	e:Emit(24)
	task.delay(1, function()
		e:Destroy()
	end)
end

local trail, trailModel
local function ensureTrail(chassis, model)
	if trail and trailModel == model and trail.Parent then
		return trail
	end
	if trail then
		trail:Destroy()
	end
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.Position = Vector3.new(-2.2, -0.6, chassis.Size.Z / 2)
	a1.Position = Vector3.new(2.2, -0.6, chassis.Size.Z / 2)
	a0.Parent = chassis
	a1.Parent = chassis
	trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.LightEmission = 0.4
	trail.Enabled = false
	trail.Parent = chassis
	trailModel = model
	return trail
end

local lastSpeed, lastT = 0, 0
local function onVehicle(speed, boost, driving)
	if not driving then
		lastSpeed = 0
		if trail then
			trail.Enabled = false
		end
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat.Parent
	local chassis = model and model.PrimaryPart
	if not chassis then
		return
	end
	local now = os.clock()
	if V.CrashSparks and lastSpeed - speed > 28 and now - lastT < 0.25 then
		burstSparks(chassis)
		if V.CameraShake then
			shake(math.clamp((lastSpeed - speed) / 80, 0.2, 1))
		end
	end
	lastSpeed, lastT = speed, now
	if V.SpeedTrail and quality() ~= "low" then
		local tr = ensureTrail(chassis, model)
		tr.Enabled = speed > 75
	end
end

local function shakeStep(dt)
	if shakeT <= 0.01 then
		return
	end
	local cam = workspace.CurrentCamera
	local k = shakeT * 0.6
	cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	shakeT = math.max(0, shakeT - dt * 2.5)
end

-- ---------------------------------------------------------------- étalonnage
local function gradeLoop()
	local cc = Lighting:FindFirstChild("CRColor")
	while cc do
		local t = Lighting.ClockTime
		local tint
		if t < 5 or t >= 20 then
			tint = Color3.fromRGB(170, 185, 255) -- nuit bleutée
		elseif t < 7.5 then
			tint = Color3.fromRGB(255, 215, 185) -- aube
		elseif t >= 17 and t < 20 then
			tint = Color3.fromRGB(255, 205, 170) -- coucher de soleil
		else
			tint = Color3.fromRGB(255, 255, 255)
		end
		cc.TintColor = cc.TintColor:Lerp(tint, 0.25)
		task.wait(2)
	end
end

function VisualFX.init()
	if not V.Enabled then
		return
	end
	safe("qualité", applyQuality)
	Util.supervise("VisualFX.lampes", lampLoop)
	if V.SirenGlow then
		Util.supervise("VisualFX.sirènes", sirenLoop)
	end
	if V.Grade then
		safe("étalonnage", function()
			task.spawn(gradeLoop)
		end)
	end
	VehicleController.Updated:Connect(function(speed, boost, driving)
		safe("véhicule", onVehicle, speed, boost, driving)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if shakeT > 0 then
			safe("secousse", shakeStep, dt)
		end
	end)
end

return VisualFX

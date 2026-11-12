--!nonstrict
-- Effets visuels et sonores côté client : balancements d'arme, traînées de tir,
-- projectiles, explosions, nombres de dégâts, projection (knockback).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Effects = {}

local player = Players.LocalPlayer
local originalC0 = setmetatable({}, { __mode = "k" })
local projectiles = {}
local HUDRef = nil

function Effects.SetHUD(hud)
	HUDRef = hud
end

-- ===== Sons =====
function Effects.PlaySound(id, parent, volume, pitch)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 120
	s.Parent = parent or SoundService
	s:Play()
	Debris:AddItem(s, 3)
end

local function transient(part, lifetime)
	Debris:AddItem(part, lifetime)
	return part
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = workspace
	return p
end

-- ===== Balancement d'arme =====
local function shoulderOf(character)
	local arm = character:FindFirstChild("RightUpperArm")
	if arm then
		return arm:FindFirstChild("RightShoulder")
	end
	local torso = character:FindFirstChild("Torso")
	return torso and torso:FindFirstChild("Right Shoulder")
end

-- Style de balancement par arme : angle d'épaule, durées montée/retour, pitch du son.
local SWING_STYLES = {
	dagger = { Raise = -1.0, Up = 0.05, Down = 0.1, Pitch = 1.35 },
	katana = { Raise = -1.9, Up = 0.05, Down = 0.12, Pitch = 1.2 },
	sovereign = { Raise = -2.3, Up = 0.1, Down = 0.25, Pitch = 0.8 },
	hammer = { Raise = -2.8, Up = 0.18, Down = 0.35, Pitch = 0.6 },
}

local function swingArm(character, heavy, style)
	local motor = shoulderOf(character)
	if not motor then
		return
	end
	local base = originalC0[motor] or motor.C0
	originalC0[motor] = base
	local raise = style and style.Raise or (heavy and -2.6 or -1.5)
	local upTime = style and style.Up or (heavy and 0.14 or 0.07)
	local downTime = style and style.Down or (heavy and 0.3 or 0.16)
	local up = TweenService:Create(motor, TweenInfo.new(upTime, Enum.EasingStyle.Quad), { C0 = base * CFrame.Angles(raise, 0, 0) })
	up:Play()
	up.Completed:Once(function()
		if motor.Parent then
			TweenService:Create(motor, TweenInfo.new(downTime, Enum.EasingStyle.Quad), { C0 = base }):Play()
		end
	end)
end

local function slashArc(character, color, heavy)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cf = root.CFrame * CFrame.new(0, 0.5, -4) * CFrame.Angles(0, 0, math.rad(90))
	local disc = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 5, 5),
		CFrame = cf,
		Color = Color3.fromHex(color),
		Transparency = 0.35,
	})
	local grow = heavy and 11 or 8
	TweenService:Create(disc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, grow, grow),
		Transparency = 1,
	}):Play()
	transient(disc, 0.3)
end

local function onSwing(who, kind, color, weaponId)
	local character = who and who.Character
	if not character then
		return
	end
	local heavy = kind == "Slam"
	local style = weaponId and SWING_STYLES[weaponId]
	swingArm(character, heavy, style)
	slashArc(character, color or "FFFFFF", heavy)
	local root = character:FindFirstChild("HumanoidRootPart")
	Effects.PlaySound(heavy and Config.Sounds.Heavy or Config.Sounds.Swing, root, 0.6, (style and style.Pitch or 1) * (0.95 + math.random() * 0.1))
end

-- ===== Tirs instantanés =====
local function onTracer(starts, ends, color, thick)
	local c = Color3.fromHex(color or "FFFFFF")
	for i, from in ipairs(starts) do
		local to = ends[i]
		if to then
			local dist = (to - from).Magnitude
			local width = thick and 0.35 or 0.12
			local p = fxPart({
				Size = Vector3.new(width, width, math.max(0.1, dist)),
				CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2),
				Color = c,
				Transparency = 0.1,
			})
			TweenService:Create(p, TweenInfo.new(thick and 0.35 or 0.16), { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, math.max(0.1, dist)) }):Play()
			transient(p, 0.4)
		end
	end
	if starts[1] then
		Effects.PlaySound(Config.Sounds.Shot, nil, 0.35, thick and 0.6 or 1.1)
	end
end

-- ===== Projectiles (visuel ; l'autorité reste au serveur) =====
local function onProjectile(_id, origin, velocity, gravity, color, isFire, maxAge)
	local c = Color3.fromHex(color or "FFFFFF")
	local p
	if isFire then
		p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = origin, Color = c })
		local light = Instance.new("PointLight")
		light.Color = c
		light.Range = 14
		light.Brightness = 2
		light.Parent = p
	else
		p = fxPart({
			Size = Vector3.new(0.18, 0.18, 2.6),
			CFrame = CFrame.lookAt(origin, origin + velocity),
			Color = Color3.fromRGB(235, 214, 160),
			Material = Enum.Material.Wood,
		})
	end
	-- traînée
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.35, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = isFire and 0.35 or 0.18
	trail.Color = ColorSequence.new(c)
	trail.LightEmission = 0.8
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = p
	table.insert(projectiles, { Part = p, Pos = origin, Vel = velocity, Gravity = gravity, Age = 0, Max = maxAge, Params = nil })
end

local function stepProjectiles(dt)
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		if not pr.Part.Parent then
			table.remove(projectiles, i)
		else
			pr.Vel += Vector3.new(0, -pr.Gravity * dt, 0)
			local step = pr.Vel * dt
			if not pr.Params then
				pr.Params = RaycastParams.new()
				pr.Params.FilterType = Enum.RaycastFilterType.Exclude
				local char = player.Character
				pr.Params.FilterDescendantsInstances = char and { char } or {}
			end
			local hit = workspace:Raycast(pr.Pos, step, pr.Params)
			pr.Age += dt
			if hit or pr.Age > pr.Max then
				pr.Part:Destroy()
				table.remove(projectiles, i)
			else
				pr.Pos += step
				pr.Part.CFrame = CFrame.lookAt(pr.Pos, pr.Pos + pr.Vel)
			end
		end
	end
end

local function onExplosion(position, radius, color)
	local c = Color3.fromHex(color or "FF8A30")
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = position, Color = c, Transparency = 0.2 })
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	transient(ball, 0.45)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(c)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(12, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = ball
	emitter:Emit(30)
	Effects.PlaySound(Config.Sounds.Heavy, ball, 0.8, 0.6)
end

local function onSlam(center, radius, color)
	local c = Color3.fromHex(color or "FFA94D")
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 3, 3),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = c,
		Transparency = 0.2,
	})
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	transient(ring, 0.5)
	Effects.PlaySound(Config.Sounds.Heavy, ring, 0.9, 0.5)
end

local function onKnockback(velocity)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = velocity
	end
end

function Effects.OnFx(kind, ...)
	local handlers = {
		Swing = onSwing,
		Tracer = onTracer,
		Projectile = onProjectile,
		Explosion = onExplosion,
		Slam = onSlam,
		Knockback = onKnockback,
	}
	local fn = handlers[kind]
	if fn then
		fn(...)
	end
end

-- ===== Retours de dégâts =====
local function damageNumber(position, amount, headshot, killed)
	local anchor = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 0, 0)
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(math.floor(amount))
	label.TextColor3 = killed and Color3.fromRGB(255, 80, 80) or (headshot and Color3.fromRGB(255, 220, 60) or Color3.new(1, 1, 1))
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = anchor
	if headshot then
		gui.Size = UDim2.fromOffset(160, 66)
	end
	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(gui.StudsOffset.X, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	transient(anchor, 0.9)
end

local function cameraShake(strength)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for _ = 1, 4 do
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function sparks(position, killed, headshot)
	local anchor = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position - Vector3.new(0, 1.5, 0), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(killed and Color3.fromRGB(255, 80, 80) or (headshot and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(255, 255, 255)))
	e.LightEmission = 1
	e.Size = NumberSequence.new(killed and 0.9 or 0.45, 0)
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(10, killed and 28 or 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(killed and 26 or 10)
	transient(anchor, 0.7)
end

function Effects.OnHit(data)
	if data.Kind == "Dealt" then
		sparks(data.Pos, data.Killed, data.Headshot)
		damageNumber(data.Pos, data.Amount, data.Headshot, data.Killed)
		Effects.PlaySound(data.Killed and Config.Sounds.Kill or Config.Sounds.Hit, nil, data.Killed and 0.7 or 0.4, data.Headshot and 1.5 or 1)
		if HUDRef then
			HUDRef.HitMarker(data.Headshot, data.Killed)
		end
	elseif data.Kind == "Taken" then
		cameraShake(math.clamp(data.Amount / 40, 0.2, 1))
		if HUDRef then
			HUDRef.DamageFlash(data.Amount, data.From)
		end
	end
end

function Effects.Init()
	RunService.Heartbeat:Connect(stepProjectiles)
end

return Effects

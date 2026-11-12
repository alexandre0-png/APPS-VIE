-- Effets visuels ponctuels côté serveur (anneaux d'avertissement, explosions, geysers, particules).

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local Fx = {}

local function folder()
	return State.FxFolder or workspace
end

-- Rafale de particules à une position.
function Fx.burst(position, color, count, speed)
	local part = Util.create("Part", {
		Name = "Burst",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		Position = position,
	}, folder())
	local emitter = Util.create("ParticleEmitter", {
		Enabled = false,
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(speed or 24, (speed or 24) * 1.6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Drag = 2,
	}, part)
	emitter:Emit(count or 30)
	Debris:AddItem(part, 2)
end

-- Anneau plat au sol (avertissement), disparaît après `duration`.
function Fx.ring(position, radius, color, duration)
	local ring = Util.create("Part", {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.45,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(position.X, 0.3, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
	}, folder())
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Transparency = 0.1 }):Play()
	Debris:AddItem(ring, duration)
	return ring
end

-- Boule d'explosion qui grossit puis s'estompe.
function Fx.explosion(position, radius, color)
	local ball = Util.create("Part", {
		Name = "Explosion",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.2,
		Size = Vector3.new(2, 2, 2),
		Position = position,
	}, folder())
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ball, info, {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.6)
	Fx.burst(position, color, 40, 40)
end

-- Colonne verticale (geyser).
function Fx.column(position, radius, height, color, duration)
	local col = Util.create("Part", {
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.35,
		Size = Vector3.new(1, radius * 1.6, radius * 1.6),
		CFrame = CFrame.new(position.X, 0.5, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
	}, folder())
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(col, info, {
		Size = Vector3.new(height, radius * 1.2, radius * 1.2),
		CFrame = CFrame.new(position.X, height / 2, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(col, duration + 0.1)
	Fx.burst(Vector3.new(position.X, 3, position.Z), color, 50, 50)
end

function Fx.clear()
	if State.FxFolder then
		State.FxFolder:ClearAllChildren()
	end
end

return Fx

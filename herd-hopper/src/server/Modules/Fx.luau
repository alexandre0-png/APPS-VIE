-- Effets visuels ponctuels côté serveur (anneaux d'avertissement, explosions, geysers, particules).

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local AnimMath = require(Shared.AnimMath)
local Util = require(Shared.Util)

local State = require(script.Parent.State)

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

-- Exécute une animation si elle est activée dans Config.Animations ; toute erreur est avalée (jamais bloquante).
function Fx.safe(flag, fn, ...)
	local cfg = Config.Animations
	if not cfg.Enabled or not cfg[flag] then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Animation " .. flag .. "] " .. tostring(err))
	end
	return ok
end

-- Nuage de fumée cartoon (échec, mort) : une boule douce qui grossit et s'estompe.
function Fx.poof(position, color)
	return Fx.safe("Death", function()
		local cloud = Util.create("Part", {
			Name = "Poof",
			Shape = Enum.PartType.Ball,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Material = Enum.Material.SmoothPlastic,
			Color = color or Color3.fromRGB(245, 245, 250),
			Transparency = 0.1,
			Size = Vector3.new(3, 3, 3),
			Position = position,
		}, folder())
		local scale, alpha = AnimMath.poof(1)
		TweenService:Create(cloud, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(3, 3, 3) * scale,
			Transparency = math.max(alpha, 0.99),
		}):Play()
		Debris:AddItem(cloud, 0.8)
		Fx.burst(position, color or Color3.fromRGB(245, 245, 250), 16, 14)
	end)
end

-- Étoiles d'étourdissement qui tournent un instant au-dessus de la tête.
function Fx.stars(position, seconds)
	return Fx.safe("Death", function()
		local duration = seconds or 1.4
		local count = 4
		local stars = {}
		for i = 1, count do
			stars[i] = Util.create("Part", {
				Name = "Star",
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 220, 80),
				Size = Vector3.new(0.9, 0.9, 0.9),
				Position = position,
			}, folder())
			Debris:AddItem(stars[i], duration + 0.2)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < duration do
				local t = os.clock() - t0
				for i, star in ipairs(stars) do
					if star.Parent then
						local dx, dz = AnimMath.orbit(t, i, count, 3)
						star.Position = position + Vector3.new(dx, 4.2 + math.sin(t * 6 + i) * 0.3, dz)
					end
				end
				task.wait(0.03)
			end
		end)
	end)
end

-- Boucle du lasso qui se resserre autour d'un animal capturé.
function Fx.lassoLoop(position, radius, color)
	return Fx.safe("Lasso", function()
		local ring = Util.create("Part", {
			Name = "LassoLoop",
			Shape = Enum.PartType.Cylinder,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Material = Enum.Material.Neon,
			Color = color or Color3.fromRGB(255, 120, 170),
			Transparency = 0.2,
			Size = Vector3.new(0.5, radius * 2.6, radius * 2.6),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		}, folder())
		local finalRadius = AnimMath.loopRadius(1, radius * 1.3, radius * 0.55)
		TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(0.5, finalRadius * 2, finalRadius * 2),
			Transparency = 0.8,
		}):Play()
		Debris:AddItem(ring, 0.5)
	end)
end

-- Confettis joyeux (capture, arrivée au zoo, boss vaincu).
function Fx.confetti(position, count)
	return Fx.safe("Joy", function()
		for _, color in ipairs({
			Color3.fromRGB(255, 96, 160),
			Color3.fromRGB(255, 214, 70),
			Color3.fromRGB(110, 210, 255),
		}) do
			Fx.burst(position, color, count or 14, 30)
		end
	end)
end

-- Estompe (ou ramène) un personnage : le « disparu dans un nuage » de la mort.
function Fx.fadeCharacter(character, transparency, seconds)
	return Fx.safe("Death", function()
		for _, descendant in ipairs(character:GetDescendants()) do
			local keep = descendant.Name == "HumanoidRootPart"
			if not keep and (descendant:IsA("BasePart") or descendant:IsA("Decal")) then
				TweenService:Create(descendant, TweenInfo.new(seconds or 0.4), { Transparency = transparency }):Play()
			end
		end
	end)
end

function Fx.clear()
	if State.FxFolder then
		State.FxFolder:ClearAllChildren()
	end
end

return Fx

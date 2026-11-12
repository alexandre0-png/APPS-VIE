-- HumanFactory.luau : petit personnage "Roblox classique" fait de blocs (visiteurs, ouvriers).
-- Pas de Humanoid : le mouvement est purement cosmétique (animé via HumanFactory.pose).

local HumanFactory = {}

local SKIN = {
	Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(255, 204, 153),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(190, 130, 90),
	Color3.fromRGB(120, 80, 55),
}

local function block(model, name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

-- opts : { shirt, pants, skin, hat (Color3|nil) }
function HumanFactory.build(opts)
	opts = opts or {}
	local skin = opts.skin or SKIN[math.random(1, #SKIN)]
	local shirt = opts.shirt or Color3.fromHSV(math.random(), 0.6, 0.9)
	local pants = opts.pants or Color3.fromRGB(50, 60, 90)

	local m = Instance.new("Model")
	m.Name = opts.name or "Visiteur"
	m.WorldPivot = CFrame.new(0, 0, 0)
	block(m, "Torso", Vector3.new(2, 2, 1), shirt)
	local head = block(m, "Head", Vector3.new(1.2, 1.2, 1.2), skin)
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	block(m, "ArmL", Vector3.new(1, 2, 1), skin)
	block(m, "ArmR", Vector3.new(1, 2, 1), skin)
	block(m, "LegL", Vector3.new(1, 2, 1), pants)
	block(m, "LegR", Vector3.new(1, 2, 1), pants)
	if opts.hat then
		block(m, "Hat", Vector3.new(1.5, 0.5, 1.5), opts.hat)
		block(m, "HatTop", Vector3.new(1.2, 0.4, 1.2), opts.hat)
	end
	HumanFactory.pose(m, CFrame.new(0, 0, 0), 0, 0)
	return m
end

-- baseCF : position au sol, regarde vers -Z. swing : angle jambes/bras en radians. armLift : bras levés (radians)
function HumanFactory.pose(model, baseCF, swing, armLift)
	local torso = model:FindFirstChild("Torso")
	if not torso then
		return
	end
	torso.CFrame = baseCF * CFrame.new(0, 3, 0)
	model.Head.CFrame = baseCF * CFrame.new(0, 4.6, 0)
	model.ArmL.CFrame = baseCF * CFrame.new(-1.5, 3.9, 0) * CFrame.Angles(swing - armLift, 0, 0) * CFrame.new(0, -0.9, 0)
	model.ArmR.CFrame = baseCF * CFrame.new(1.5, 3.9, 0) * CFrame.Angles(-swing - armLift, 0, 0) * CFrame.new(0, -0.9, 0)
	model.LegL.CFrame = baseCF * CFrame.new(-0.5, 2, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	model.LegR.CFrame = baseCF * CFrame.new(0.5, 2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	local hat = model:FindFirstChild("Hat")
	if hat then
		hat.CFrame = baseCF * CFrame.new(0, 5.3, 0)
		model.HatTop.CFrame = baseCF * CFrame.new(0, 5.6, 0)
	end
end

return HumanFactory

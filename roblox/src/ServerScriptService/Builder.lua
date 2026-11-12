-- ModuleScript : ServerScriptService/Builder
-- Construit TOUT le visuel avec des Parts, matériaux et particules de base Roblox (aucun asset externe).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Builder = {}

local FONT = Enum.Font.GothamBold
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function ball(props, parent)
	props.Shape = Enum.PartType.Ball
	props.CanCollide = false
	return part(props, parent)
end

local function sign(adornee, text, color, offsetY, width)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Adornee = adornee
	g.Size = UDim2.fromOffset(width or 200, 56)
	g.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	g.MaxDistance = 70
	g.AlwaysOnTop = false
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.TextSize = 18
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.Text = text
	t.Parent = g
	g.Parent = adornee
	return t
end
Builder.sign = sign

---------------------------------------------------------------- Œuf
function Builder.egg(tier, anchored)
	local c = Config.TIERS[tier].color
	local p = Instance.new("Part")
	p.Name = "Egg"
	p.Size = Vector3.new(2.4, 3.2, 2.4)
	p.Color = Color3.fromRGB(255, 244, 222):Lerp(c, 0.35)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = anchored ~= false
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	local l = Instance.new("PointLight")
	l.Color = c
	l.Range = 7
	l.Brightness = 1.2
	l.Parent = p
	return p
end

---------------------------------------------------------------- Pet (modèle 3D en Parts)
-- Retourne (modèle, hauteur de levage). Le modèle regarde vers -Z.
function Builder.pet(petIdx, sizeIdx, mutIdx)
	local def = Config.PETS[petIdx]
	local size = Config.SIZES[sizeIdx]
	local mut = Config.MUTS[mutIdx]
	local R = 1.5 * size.scale
	local model = Instance.new("Model")
	model.Name = "Pet"

	local bodyColor = def.color
	local bodyMat = Enum.Material.SmoothPlastic
	if mut.color then
		bodyColor = mut.color
		bodyMat = Enum.Material.Neon
	elseif mut.rainbow then
		bodyColor = Color3.fromRGB(255, 120, 220)
		bodyMat = Enum.Material.Neon
	end

	local body = ball({ Name = "Body", Size = Vector3.new(2 * R, 2 * R, 2 * R), CFrame = CFrame.new(0, 0, 0), Color = bodyColor, Material = bodyMat }, model)
	model.PrimaryPart = body
	local dark = Color3.fromRGB(25, 25, 30)

	local function addBall(name, off, sz, col, mat)
		return ball({ Name = name, Size = Vector3.new(sz, sz, sz), CFrame = CFrame.new(off), Color = col, Material = mat or Enum.Material.SmoothPlastic }, model)
	end
	local function addBlock(name, off, sz, col, rotZ, mat)
		return part({ Name = name, CanCollide = false, Size = sz, CFrame = CFrame.new(off) * CFrame.Angles(0, 0, rotZ or 0), Color = col, Material = mat or Enum.Material.SmoothPlastic }, model)
	end

	-- yeux
	addBall("EyeL", Vector3.new(-0.42 * R, 0.25 * R, -0.86 * R), 0.36 * R, dark)
	addBall("EyeR", Vector3.new(0.42 * R, 0.25 * R, -0.86 * R), 0.36 * R, dark)

	-- oreilles
	local ears = def.ears
	if ears == "round" then
		addBall("EarL", Vector3.new(-0.62 * R, 0.95 * R, -0.05 * R), 0.62 * R, bodyColor)
		addBall("EarR", Vector3.new(0.62 * R, 0.95 * R, -0.05 * R), 0.62 * R, bodyColor)
	elseif ears == "long" then
		addBlock("EarL", Vector3.new(-0.4 * R, 1.5 * R, 0), Vector3.new(0.36 * R, 1.3 * R, 0.3 * R), bodyColor, 0.15)
		addBlock("EarR", Vector3.new(0.4 * R, 1.5 * R, 0), Vector3.new(0.36 * R, 1.3 * R, 0.3 * R), bodyColor, -0.15)
	elseif ears == "point" then
		addBlock("EarL", Vector3.new(-0.6 * R, 1.05 * R, 0), Vector3.new(0.4 * R, 0.8 * R, 0.3 * R), bodyColor, 0.5)
		addBlock("EarR", Vector3.new(0.6 * R, 1.05 * R, 0), Vector3.new(0.4 * R, 0.8 * R, 0.3 * R), bodyColor, -0.5)
	elseif ears == "floppy" then
		addBlock("EarL", Vector3.new(-1.0 * R, 0.35 * R, 0), Vector3.new(0.35 * R, 0.9 * R, 0.5 * R), Color3.fromRGB(110, 70, 40), 0.2)
		addBlock("EarR", Vector3.new(1.0 * R, 0.35 * R, 0), Vector3.new(0.35 * R, 0.9 * R, 0.5 * R), Color3.fromRGB(110, 70, 40), -0.2)
	end

	-- extras
	local lift = R
	local extra = def.extra
	if extra == "beak" then
		addBlock("Beak", Vector3.new(0, -0.05 * R, -1.0 * R), Vector3.new(0.5 * R, 0.3 * R, 0.5 * R), Color3.fromRGB(255, 150, 30))
	elseif extra == "tail" then
		addBall("Tail", Vector3.new(0, -0.1 * R, 1.05 * R), 0.55 * R, bodyColor)
	elseif extra == "mane" then
		addBall("Mane", Vector3.new(0, 0, 0.3 * R), 2.5 * R, Color3.fromRGB(150, 90, 30))
		body.Size = Vector3.new(1.9 * R, 1.9 * R, 1.9 * R)
	elseif extra == "horn" then
		addBlock("Horn", Vector3.new(0, 1.2 * R, -0.45 * R), Vector3.new(0.25 * R, 0.9 * R, 0.25 * R), Color3.fromRGB(255, 215, 90), 0, Enum.Material.Neon)
	elseif extra == "wings" then
		addBlock("WingL", Vector3.new(-1.1 * R, 0.35 * R, 0.3 * R), Vector3.new(0.15 * R, 1.1 * R, 1.3 * R), bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), 0.6)
		addBlock("WingR", Vector3.new(1.1 * R, 0.35 * R, 0.3 * R), Vector3.new(0.15 * R, 1.1 * R, 1.3 * R), bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), -0.6)
		addBlock("Horn", Vector3.new(0, 1.05 * R, -0.5 * R), Vector3.new(0.22 * R, 0.6 * R, 0.22 * R), Color3.fromRGB(255, 240, 200))
	elseif extra == "tentacles" then
		for i, o in ipairs({ { -0.5, -0.5 }, { 0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, 0.5 } }) do
			addBlock("Tent" .. i, Vector3.new(o[1] * R, -1.25 * R, o[2] * R), Vector3.new(0.3 * R, 1.1 * R, 0.3 * R), bodyColor)
		end
		lift = 1.8 * R
	elseif extra == "antenna" then
		addBlock("Ant", Vector3.new(0, 1.3 * R, 0), Vector3.new(0.12 * R, 0.8 * R, 0.12 * R), bodyColor)
		addBall("AntTip", Vector3.new(0, 1.8 * R, 0), 0.35 * R, Color3.fromRGB(255, 80, 200), Enum.Material.Neon)
	end

	-- mutation : particules
	if mut.color or mut.rainbow then
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Rate = 8
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * R), NumberSequenceKeypoint.new(1, 0) })
		if mut.rainbow then
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 255, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
			})
		else
			e.Color = ColorSequence.new(mut.color)
		end
		e.Parent = body
	end

	-- étiquette
	local tier = Config.TIERS[def.tier]
	model:SetAttribute("Height", lift)
	return model, lift, 2.3 * R + 1.5
end

---------------------------------------------------------------- Gardien
function Builder.guard(rivalIdx)
	local r = Config.RIVALS[rivalIdx]
	local col = r.color:Lerp(Color3.fromRGB(60, 40, 30), 0.6)
	local model = Instance.new("Model")
	model.Name = "Guard" .. rivalIdx
	local body = part({ Name = "Body", CanCollide = false, Size = Vector3.new(3, 2.4, 4.4), CFrame = CFrame.new(0, 0, 0), Color = col }, model)
	model.PrimaryPart = body
	ball({ Name = "Head", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(0, 0.7, -2.7), Color = col }, model)
	part({ Name = "Snout", CanCollide = false, Size = Vector3.new(1.2, 0.9, 1.2), CFrame = CFrame.new(0, 0.3, -3.7), Color = Color3.fromRGB(35, 30, 30) }, model)
	ball({ Name = "EyeL", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(-0.7, 1.2, -3.5), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon }, model)
	ball({ Name = "EyeR", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(0.7, 1.2, -3.5), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon }, model)
	part({ Name = "EarL", CanCollide = false, Size = Vector3.new(0.5, 1.1, 0.6), CFrame = CFrame.new(-1.0, 1.9, -2.5) * CFrame.Angles(0, 0, 0.3), Color = col }, model)
	part({ Name = "EarR", CanCollide = false, Size = Vector3.new(0.5, 1.1, 0.6), CFrame = CFrame.new(1.0, 1.9, -2.5) * CFrame.Angles(0, 0, -0.3), Color = col }, model)
	part({ Name = "Tail", CanCollide = false, Size = Vector3.new(0.6, 0.6, 2), CFrame = CFrame.new(0, 0.8, 3.0) * CFrame.Angles(0.5, 0, 0), Color = col }, model)
	for i, o in ipairs({ { -1, -1.4 }, { 1, -1.4 }, { -1, 1.4 }, { 1, 1.4 } }) do
		part({ Name = "Leg" .. i, CanCollide = false, Size = Vector3.new(0.7, 1.6, 0.7), CFrame = CFrame.new(o[1], -1.8, o[2]), Color = col }, model)
	end
	local s = sign(body, "🐕 Gardien de " .. r.name, Color3.fromRGB(255, 120, 120), 4, 220)
	s.TextSize = 14
	return model
end

---------------------------------------------------------------- Monde
local function tree(pos, parent)
	part({ Name = "Trunk", Size = Vector3.new(2, 8, 2), Position = pos + Vector3.new(0, 4, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood }, parent)
	ball({ Name = "Leaves", Anchored = true, Size = Vector3.new(11, 11, 11), Position = pos + Vector3.new(0, 11, 0), Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass, CanCollide = false }, parent)
end

-- Retourne { plots, nests, treadmill, guards, center }
function Builder.build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("SpawnLocation") then
			c:Destroy()
		end
	end

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 120, 130)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.25
		a.Haze = 1
		a.Parent = Lighting
	end

	part({ Name = "Ground", Size = Vector3.new(620, 2, 620), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(96, 158, 84), Material = Enum.Material.Grass }, world)
	part({ Name = "Arena", Size = Vector3.new(1, 150, 150), CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(205, 180, 130), Material = Enum.Material.Sand, CanCollide = false }, world)

	local result = { plots = {}, nests = {}, guards = {} }

	-- Arbres
	local rng = Random.new(7)
	for _ = 1, 36 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(90, 122)
		tree(Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), world)
	end

	-- Rivaux PNJ (au nord, z négatif) ------------------------------------------------
	for i, riv in ipairs(Config.RIVALS) do
		local cx, cz = (i - 2) * 55, -70
		local folder = Instance.new("Folder")
		folder.Name = "Rival_" .. riv.name
		folder.Parent = world
		local disc = part({ Name = "Disc", Size = Vector3.new(1, 34, 34), CFrame = CFrame.new(cx, 0.5, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = riv.color:Lerp(Color3.fromRGB(70, 55, 40), 0.55), Material = Enum.Material.Slate, CanCollide = false }, folder)
		local pole = part({ Name = "Sign", Size = Vector3.new(1, 9, 1), Position = Vector3.new(cx, 4.5, cz - 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, folder)
		local t = sign(pole, riv.emoji .. " " .. riv.name .. "  " .. string.rep("★", riv.stars), Color3.fromRGB(255, 220, 90), 7, 260)
		t.TextSize = 22
		for j = 1, 3 do
			local nx = cx + (j - 2) * 8
			local mound = part({ Name = "Nest", Size = Vector3.new(0.7, 6, 6), CFrame = CFrame.new(nx, 1, cz - 3) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood, CanCollide = false }, folder)
			result.nests[#result.nests + 1] = { rival = i, pos = Vector3.new(nx, 3.2, cz - 3), mound = mound, folder = folder, egg = nil, rt = math.random() * 6 }
		end
		local g = Builder.guard(i)
		g.Parent = folder
		result.guards[#result.guards + 1] = {
			model = g, rival = i, cx = cx, patrolZ = cz + 12, pos = Vector3.new(cx, 2.4, cz + 12),
			dir = (i % 2 == 0) and -1 or 1, state = "patrol", cd = 0, lost = 0,
		}
		g:PivotTo(CFrame.new(cx, 2.4, cz + 12))
	end

	-- Tapis roulant ------------------------------------------------------------------
	do
		local belt = part({ Name = "Treadmill", Size = Vector3.new(16, 1, 40), Position = Vector3.new(0, 0.6, 38), Color = Color3.fromRGB(45, 48, 56), Material = Enum.Material.Metal }, world)
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, -14) -- tapis : pousse vers -Z, il faut courir vers +Z
		for k = 0, 7 do
			part({ Name = "Stripe", Size = Vector3.new(14, 0.1, 1.2), Position = Vector3.new(0, 1.16, 38 - 17.5 + k * 5), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon, CanCollide = false }, belt)
		end
		local pole = part({ Name = "TreadSign", Size = Vector3.new(1, 8, 1), Position = Vector3.new(-10, 4, 38), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		sign(pole, "🏃 TAPIS ROULANT\nCours dessus pour gagner en vitesse !", Color3.fromRGB(255, 220, 90), 6, 300)
		result.treadmill = { cf = belt.CFrame, size = belt.Size }
	end

	-- Bases des joueurs ---------------------------------------------------------------
	local N = Config.PLOT_COUNT
	local radius = 170
	for i = 1, N do
		local a = (i - 1) / N * math.pi * 2
		local pos = Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- l'avant (-Z) regarde le centre
		local model = Instance.new("Model")
		model.Name = "Plot" .. i
		model.Parent = world
		local plat = part({ Name = "Platform", Size = Vector3.new(52, 1, 52), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(70, 130, 95) }, model)
		part({ Name = "Border", Size = Vector3.new(54, 0.4, 54), CFrame = cf * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(140, 217, 160), CanCollide = false }, model)

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = cf * CFrame.new(0, 1.2, -20)
		spawn.Color = Color3.fromRGB(255, 210, 63)
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.4
		spawn.Parent = model

		local pads = {}
		for idx = 1, 12 do
			local col, row = (idx - 1) % 4, (idx - 1) // 4
			local lx, lz = -15 + col * 10, -6 + row * 11
			local pad = part({ Name = "Pad" .. idx, Size = Vector3.new(8, 0.4, 8), CFrame = cf * CFrame.new(lx, 1.2, lz), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7, CanCollide = false }, model)
			local lockText = sign(pad, "🔒", Color3.new(1, 1, 1), 2.5, 80)
			pads[idx] = { part = pad, lock = lockText.Parent, content = nil }
		end

		local board = part({ Name = "Board", Size = Vector3.new(1, 7, 1), CFrame = cf * CFrame.new(0, 4.5, 24), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, model)
		local nameLabel = sign(board, "Base libre", Color3.fromRGB(140, 217, 160), 6, 320)
		nameLabel.TextSize = 24

		result.plots[i] = { model = model, cf = cf, pads = pads, spawn = spawn, nameLabel = nameLabel, owner = nil, platform = plat }
	end

	result.treadmillContains = function(p)
		local rel = result.treadmill.cf:PointToObjectSpace(p)
		local s = result.treadmill.size
		return math.abs(rel.X) <= s.X / 2 and math.abs(rel.Z) <= s.Z / 2 and rel.Y > 0 and rel.Y < 8
	end

	return result
end

return Builder

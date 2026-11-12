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

	-- paupières (invisibles, le client les affiche à chaque clignement) et bouche (animée côté client)
	for _, side in ipairs({ { "LidL", -0.42 }, { "LidR", 0.42 } }) do
		local lid = addBall(side[1], Vector3.new(side[2] * R, 0.25 * R, -0.88 * R), 0.42 * R, bodyColor)
		lid.Transparency = 1
	end
	addBlock("Mouth", Vector3.new(0, -0.18 * R, -0.93 * R), Vector3.new(0.34 * R, 0.06 * R, 0.1 * R), dark)

	-- reflets dans les yeux, joues et pieds
	addBall("ShineL", Vector3.new(-0.46 * R, 0.34 * R, -1.0 * R), 0.13 * R, Color3.new(1, 1, 1))
	addBall("ShineR", Vector3.new(0.38 * R, 0.34 * R, -1.0 * R), 0.13 * R, Color3.new(1, 1, 1))
	if def.tier <= 3 then
		addBall("CheekL", Vector3.new(-0.72 * R, -0.05 * R, -0.68 * R), 0.26 * R, Color3.fromRGB(255, 150, 170))
		addBall("CheekR", Vector3.new(0.72 * R, -0.05 * R, -0.68 * R), 0.26 * R, Color3.fromRGB(255, 150, 170))
	end
	if def.extra ~= "tentacles" then
		local footCol = bodyColor:Lerp(Color3.new(0, 0, 0), 0.25)
		addBall("FootL", Vector3.new(-0.45 * R, -0.92 * R, -0.15 * R), 0.55 * R, footCol)
		addBall("FootR", Vector3.new(0.45 * R, -0.92 * R, -0.15 * R), 0.55 * R, footCol)
	end

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

	-- étincelles dorées discrètes : le pet « produit » des pièces
	local coin = Instance.new("ParticleEmitter")
	coin.Texture = SPARK
	coin.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	coin.Rate = 0.7
	coin.Lifetime = NumberRange.new(1.2, 1.8)
	coin.Speed = NumberRange.new(1, 2)
	coin.Acceleration = Vector3.new(0, 3, 0)
	coin.SpreadAngle = Vector2.new(60, 60)
	coin.LightEmission = 1
	coin.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	coin.Parent = body

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
	model:SetAttribute("Height", lift)
	CollectionService:AddTag(model, "PetFace") -- visage animé côté client (clignement, regard, bouche)
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

---------------------------------------------------------------- Éclairage
-- Ambiance « jour doré » : soleil chaud, brume légère, bloom discret, étalonnage plus vif.
function Builder.setupLighting()
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(95, 105, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 135, 155)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 205)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	local function effect(class, name, props)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		for k, v in pairs(props) do
			e[k] = v
		end
		return e
	end

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Parent = Lighting
	end
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(199, 220, 255)
	atm.Decay = Color3.fromRGB(255, 214, 170)
	atm.Glare = 0.25
	atm.Haze = 1.4

	effect("BloomEffect", "ChipeBloom", { Intensity = 0.4, Size = 28, Threshold = 0.95 })
	effect("SunRaysEffect", "ChipeSunRays", { Intensity = 0.15, Spread = 0.8 })
	effect("ColorCorrectionEffect", "ChipeGrade", { Saturation = 0.18, Contrast = 0.1, Brightness = 0.02 })
end

---------------------------------------------------------------- Monument du Grand Nid (identité du jeu, au centre de l'arène)
function Builder.monument(parent)
	local gold = Color3.fromRGB(255, 214, 120)
	part({ Name = "MonumentBase", Size = Vector3.new(1.4, 17, 17), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(176, 160, 128), Material = Enum.Material.Slate }, parent)
	part({ Name = "MonumentStep", Size = Vector3.new(0.8, 12, 12), CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(130, 116, 92), Material = Enum.Material.Slate }, parent)
	local egg = Instance.new("Part")
	egg.Name = "GrandNid"
	egg.Anchored = true
	egg.Size = Vector3.new(8, 11, 8)
	egg.CFrame = CFrame.new(0, 8.1, 0)
	egg.Color = gold
	egg.Material = Enum.Material.Metal
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Range = 28
	glow.Brightness = 1.5
	glow.Parent = egg
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 235, 160))
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(2, 3.5)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = egg
	egg.Parent = parent
	for k, c in ipairs({ { 0, 9.5, -3.7, 0.3 }, { 1.2, 6.6, -3.75, -0.5 }, { -1.1, 4.2, -3.6, 0.6 } }) do -- fissures lumineuses
		part({ Name = "Crack" .. k, Size = Vector3.new(0.35, 3.2, 0.35), CFrame = CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, 0, c[4]), Color = Color3.fromRGB(255, 248, 200), Material = Enum.Material.Neon, CanCollide = false }, parent)
	end
	-- Quatre runes cardinales (Nord = côté des rivaux). Chaque joueur règle ses propres runes : le symbole affiché est local au client
	-- (étiquette « Label » modifiée côté client), l'état est tenu par le serveur.
	local dirs = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
	for k, dv in ipairs(dirs) do
		local x, z = dv[1] * 9.5, dv[2] * 9.5
		local stone = part({ Name = "RuneStone", Size = Vector3.new(2.4, 5, 1.2), CFrame = CFrame.lookAt(Vector3.new(x, 3.2, z), Vector3.new(0, 3.2, 0)), Color = Color3.fromRGB(110, 104, 96), Material = Enum.Material.Slate }, parent)
		stone:SetAttribute("Idx", k)
		CollectionService:AddTag(stone, "RuneStone")
		part({ Name = "RuneGlow", Size = Vector3.new(1.1, 3.4, 0.2), CFrame = stone.CFrame * CFrame.new(0, 0.2, -0.65), Color = gold, Material = Enum.Material.Neon, CanCollide = false }, parent)
		local lbl = sign(stone, "?", Color3.fromRGB(255, 240, 190), 4.4, 120)
		lbl.TextSize = 44
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Tourner la rune"
		pr.ObjectText = "Rune du " .. Config.RUNE_DIRECTIONS[k]
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Kind", "Rune")
		pr:SetAttribute("Idx", k)
		pr.Parent = stone
	end
	-- Valider la combinaison en touchant le Grand Nid
	local confirm = Instance.new("ProximityPrompt")
	confirm.ActionText = "Poser la combinaison"
	confirm.ObjectText = "Grand Nid"
	confirm.HoldDuration = 0.5
	confirm.MaxActivationDistance = 14
	confirm.RequiresLineOfSight = false
	confirm:SetAttribute("Kind", "RuneConfirm")
	confirm.Parent = egg
	-- Panneau de l'énigme du Gardien (texte mis à jour chaque jour par le serveur), lisible des deux côtés
	local board = part({ Name = "RiddleBoard", Size = Vector3.new(12, 4.6, 0.5), Position = Vector3.new(0, 3.8, 14), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, parent)
	part({ Name = "RiddlePostL", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(-5.4, 2, 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	part({ Name = "RiddlePostR", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(5.4, 2, 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(720, 300)
		sg.LightInfluence = 0
		sg.Adornee = board
		sg.Parent = board
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 56)
		title.Font = FONT
		title.TextSize = 40
		title.TextColor3 = gold
		title.Text = "📜 Énigme du Gardien"
		title.Parent = sg
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(16, 60)
		body.Size = UDim2.new(1, -32, 1, -64)
		body.Font = Enum.Font.GothamMedium
		body.TextSize = 29
		body.TextWrapped = true
		body.TextColor3 = Color3.fromRGB(255, 244, 220)
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = "…"
		body.Parent = sg
		labels[#labels + 1] = body
	end
	local result = { labels = labels, center = Vector3.new(0, 8.1, 0) }
	local t = sign(egg, "✨ Le Grand Nid ✨\nReconstruis la Couvée, Chipeur !", gold, 9, 340)
	t.TextSize = 20
	return result
end

---------------------------------------------------------------- Monde
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80), Color3.fromRGB(255, 230, 90), Color3.fromRGB(140, 230, 110),
	Color3.fromRGB(80, 220, 200), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(235, 235, 235), Color3.fromRGB(170, 190, 160),
}
Builder.PLOT_COLORS = PLOT_COLORS
local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 130, 255), Color3.fromRGB(255, 150, 70),
}

local function tree(pos, parent, rng)
	local s = rng:NextNumber(0.85, 1.3)
	part({ Name = "Trunk", Size = Vector3.new(2 * s, 8 * s, 2 * s), Position = pos + Vector3.new(0, 4 * s, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood }, parent)
	local dark, light = Color3.fromRGB(62, 142, 68), Color3.fromRGB(92, 178, 86)
	ball({ Name = "Leaves", Size = Vector3.new(11 * s, 11 * s, 11 * s), Position = pos + Vector3.new(0, 11 * s, 0), Color = dark, Material = Enum.Material.Grass }, parent)
	ball({ Name = "Leaves", Size = Vector3.new(7 * s, 7 * s, 7 * s), Position = pos + Vector3.new(3.2 * s, 9.2 * s, 1.5 * s), Color = light, Material = Enum.Material.Grass }, parent)
	ball({ Name = "Leaves", Size = Vector3.new(6 * s, 6 * s, 6 * s), Position = pos + Vector3.new(-2.8 * s, 14 * s, -1 * s), Color = light, Material = Enum.Material.Grass }, parent)
end

local function torch(pos, parent)
	part({ Name = "TorchPost", Size = Vector3.new(0.8, 5, 0.8), Position = pos + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	local head = ball({ Name = "TorchHead", Size = Vector3.new(1.3, 1.3, 1.3), Position = pos + Vector3.new(0, 5.4, 0), Color = Color3.fromRGB(255, 150, 60), Material = Enum.Material.Neon }, parent)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 170, 70)
	fire.SecondaryColor = Color3.fromRGB(255, 90, 30)
	fire.Parent = head
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 170, 90)
	l.Range = 18
	l.Brightness = 1.2
	l.Parent = head
end

-- Retourne { plots, nests, treadmill, guards, treadmillContains }
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

	Builder.setupLighting()

	-- Sol, relief et décor ----------------------------------------------------------
	part({ Name = "Ground", Size = Vector3.new(620, 2, 620), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(92, 160, 82), Material = Enum.Material.Grass }, world)
	local rng = Random.new(7)
	for _ = 1, 14 do -- taches d'herbe plus claires / plus sombres
		local d = rng:NextNumber(40, 100)
		local c = rng:NextNumber() < 0.5 and Color3.fromRGB(104, 172, 90) or Color3.fromRGB(80, 146, 74)
		part({ Name = "Patch", Size = Vector3.new(0.1, d, d), CFrame = CFrame.new(rng:NextNumber(-280, 280), 0.03, rng:NextNumber(-280, 280)) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = c, Material = Enum.Material.Grass, CanCollide = false }, world)
	end
	for k = 0, 15 do -- collines à l'horizon
		local a = k / 16 * math.pi * 2
		local sz = rng:NextNumber(200, 320)
		ball({ Name = "Hill", Size = Vector3.new(sz, sz, sz), Position = Vector3.new(math.sin(a) * 400, -sz * 0.36, math.cos(a) * 400), Color = Color3.fromRGB(78 + (k % 3) * 8, 150 + (k % 2) * 10, 80), Material = Enum.Material.Grass }, world)
	end
	for _, w in ipairs({ { 0, 312, 640, 4 }, { 0, -312, 640, 4 }, { 312, 0, 4, 640 }, { -312, 0, 4, 640 } }) do -- murs invisibles : on ne tombe plus dans le vide
		part({ Name = "Wall", Size = Vector3.new(w[3], 100, w[4]), Position = Vector3.new(w[1], 50, w[2]), Transparency = 1 }, world).CanQuery = false
	end
	part({ Name = "ArenaRim", Size = Vector3.new(0.2, 156, 156), CFrame = CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(150, 125, 85), Material = Enum.Material.Sand, CanCollide = false }, world)
	part({ Name = "Arena", Size = Vector3.new(0.3, 150, 150), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(214, 190, 140), Material = Enum.Material.Sand, CanCollide = false }, world)

	local monument = Builder.monument(world)

	for _ = 1, 38 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(90, 125)
		tree(Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), world, rng)
	end
	for _ = 1, 110 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, 136)
		ball({ Name = "Flower", Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(math.sin(a) * r, 0.45, math.cos(a) * r), Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)] }, world)
	end
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, 138)
		local sz = rng:NextNumber(2.5, 5)
		ball({ Name = "Rock", Size = Vector3.new(sz, sz, sz), Position = Vector3.new(math.sin(a) * r, sz * 0.15, math.cos(a) * r), Color = Color3.fromRGB(130, 134, 140), Material = Enum.Material.Slate }, world)
	end

	local result = { plots = {}, nests = {}, guards = {}, riddleLabels = monument.labels, monumentCenter = monument.center }

	-- Rivaux PNJ (au nord, z négatif) ------------------------------------------------
	for i, riv in ipairs(Config.RIVALS) do
		local cx, cz = (i - 2) * 55, -70
		local folder = Instance.new("Folder")
		folder.Name = "Rival_" .. riv.name
		folder.Parent = world
		part({ Name = "GlowRing", Size = Vector3.new(0.4, 38, 38), CFrame = CFrame.new(cx, 0.3, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = riv.color, Material = Enum.Material.Neon, CanCollide = false }, folder)
		part({ Name = "Disc", Size = Vector3.new(1, 34, 34), CFrame = CFrame.new(cx, 0.5, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = riv.color:Lerp(Color3.fromRGB(70, 55, 40), 0.55), Material = Enum.Material.Slate, CanCollide = false }, folder)
		for k = 0, 13 do -- palissade sur l'arrière (le devant reste ouvert vers l'arène)
			local t = -0.15 * math.pi + k * (1.3 * math.pi / 13)
			local pp = Vector3.new(cx + 17.5 * math.cos(t), 0, cz - 17.5 * math.sin(t))
			part({ Name = "Post", Size = Vector3.new(1, 4, 1), Position = pp + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(100, 70, 46), Material = Enum.Material.Wood }, folder)
			ball({ Name = "PostCap", Size = Vector3.new(0.9, 0.9, 0.9), Position = pp + Vector3.new(0, 4.9, 0), Color = riv.color, Material = Enum.Material.Neon }, folder)
		end
		torch(Vector3.new(cx - 15, 0.5, cz + 9), folder)
		torch(Vector3.new(cx + 15, 0.5, cz + 9), folder)
		local zone = Config.ZONES[i]
		if zone and zone.chapter > 0 then
			-- Barrière du domaine verrouillé. Elle est solide pour tous ; le client la rend traversable (localement) dès que le
			-- joueur a réussi le chapitre requis. Le serveur refuse de toute façon tout vol dans une zone verrouillée.
			local gate = part({ Name = "ZoneGate", Size = Vector3.new(12, 40, 40), CFrame = CFrame.new(cx, 6, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 70, 90), Material = Enum.Material.Neon, Transparency = 0.6 }, folder)
			gate:SetAttribute("Rival", i)
			gate:SetAttribute("Chapter", zone.chapter)
			CollectionService:AddTag(gate, "ZoneGate")
			sign(gate, "🔒 " .. zone.name .. "\nHistoire : chapitre " .. zone.chapter, Color3.fromRGB(255, 210, 210), 10, 300)
		end
		local pole = part({ Name = "Sign", Size = Vector3.new(1, 9, 1), Position = Vector3.new(cx, 4.5, cz - 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, folder)
		part({ Name = "Flag", Size = Vector3.new(0.2, 3, 5), Position = Vector3.new(cx + 0.2, 8, cz - 11.5), Color = riv.color, Material = Enum.Material.Fabric, CanCollide = false }, folder)
		local t = sign(pole, riv.emoji .. " " .. riv.name .. "  " .. string.rep("★", riv.stars), Color3.fromRGB(255, 220, 90), 7, 260)
		t.TextSize = 22
		for j = 1, 3 do
			local nx = cx + (j - 2) * 8
			local mound = part({ Name = "Nest", Size = Vector3.new(0.7, 6, 6), CFrame = CFrame.new(nx, 1, cz - 3) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.Wood, CanCollide = false }, folder)
			part({ Name = "NestStraw", Size = Vector3.new(0.3, 4.4, 4.4), CFrame = CFrame.new(nx, 1.25, cz - 3) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(226, 196, 120), Material = Enum.Material.Fabric, CanCollide = false }, folder)
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

	-- Tapis roulant (les rayures sont animées côté client grâce au tag BeltStripe) -----
	do
		local belt = part({ Name = "Treadmill", Size = Vector3.new(16, 1, 40), Position = Vector3.new(0, 0.6, 38), Color = Color3.fromRGB(45, 48, 56), Material = Enum.Material.Metal }, world)
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, -14) -- le tapis pousse vers -Z : il faut courir vers +Z
		for k = 0, 7 do
			local stripe = part({ Name = "Stripe", Size = Vector3.new(14, 0.1, 1.2), Position = Vector3.new(0, 1.16, 38 - 17.5 + k * 5), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon, CanCollide = false }, belt)
			stripe:SetAttribute("Z0", -17.5 + k * 5)
			stripe:SetAttribute("CenterZ", 38)
			CollectionService:AddTag(stripe, "BeltStripe")
		end
		for _, sx in ipairs({ -8.6, 8.6 }) do
			part({ Name = "Rail", Size = Vector3.new(0.8, 1.6, 40), Position = Vector3.new(sx, 1.1, 38), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon }, world)
		end
		local pole = part({ Name = "TreadSign", Size = Vector3.new(1, 8, 1), Position = Vector3.new(-11, 4, 38), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		sign(pole, "🏃 TAPIS ROULANT\nCours dessus pour gagner en vitesse !", Color3.fromRGB(255, 220, 90), 6, 300)
		result.treadmill = { cf = belt.CFrame, size = belt.Size }
	end

	-- Bases des joueurs ---------------------------------------------------------------
	local N = Config.PLOT_COUNT
	local radius = 170
	for i = 1, N do
		local pc = PLOT_COLORS[(i - 1) % #PLOT_COLORS + 1]
		local a = (i - 1) / N * math.pi * 2
		local pos = Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- l'avant (-Z) regarde le centre
		local model = Instance.new("Model")
		model.Name = "Plot" .. i
		model.Parent = world
		local plat = part({ Name = "Platform", Size = Vector3.new(52, 1, 52), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(62, 112, 88):Lerp(pc, 0.15), Material = Enum.Material.Concrete }, model)
		for _, e in ipairs({ { 0, -25.5, 52, 1 }, { 0, 25.5, 52, 1 }, { -25.5, 0, 1, 52 }, { 25.5, 0, 1, 52 } }) do -- liseré néon aux couleurs de la base
			part({ Name = "Edge", Size = Vector3.new(e[3], 0.25, e[4]), CFrame = cf * CFrame.new(e[1], 1.1, e[2]), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
		end
		for _, c in ipairs({ { -25, -25 }, { 25, -25 }, { -25, 25 }, { 25, 25 } }) do -- lampadaires
			part({ Name = "LampPost", Size = Vector3.new(0.9, 7, 0.9), CFrame = cf * CFrame.new(c[1], 4.5, c[2]), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, model)
			ball({ Name = "Lamp", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = cf * CFrame.new(c[1], 8.4, c[2]), Color = Color3.fromRGB(255, 235, 170), Material = Enum.Material.Neon }, model)
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 235, 190)
		glow.Range = 45
		glow.Brightness = 0.7
		glow.Parent = plat

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = cf * CFrame.new(0, 1.2, -20)
		spawn.Color = pc
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.4
		spawn.Parent = model

		local pads = {}
		for idx = 1, 12 do
			local col, row = (idx - 1) % 4, (idx - 1) // 4
			local lx, lz = -15 + col * 10, -6 + row * 11
			local frame = part({ Name = "PadFrame" .. idx, Size = Vector3.new(8.8, 0.3, 8.8), CFrame = cf * CFrame.new(lx, 1.12, lz), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
			local pad = part({ Name = "Pad" .. idx, Size = Vector3.new(8, 0.4, 8), CFrame = cf * CFrame.new(lx, 1.2, lz), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7, CanCollide = false }, model)
			local lockText = sign(pad, "🔒", Color3.new(1, 1, 1), 2.5, 80)
			pads[idx] = { part = pad, lock = lockText.Parent, frame = frame, content = nil }
		end

		local board = part({ Name = "Board", Size = Vector3.new(1, 7, 1), CFrame = cf * CFrame.new(0, 4.5, 24), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, model)
		local plank = part({ Name = "Plank", Size = Vector3.new(18, 4.2, 0.7), CFrame = cf * CFrame.new(0, 8.6, 23.6), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, model)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front -- face -Z de la planche = côté arène
		sg.CanvasSize = Vector2.new(720, 168)
		sg.LightInfluence = 0
		sg.Adornee = plank
		sg.Parent = plank
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.Font = FONT
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = pc
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Text = "Base libre"
		nameLabel.Parent = sg
		board.Name = "BoardPole"

		result.plots[i] = { model = model, cf = cf, pads = pads, spawn = spawn, nameLabel = nameLabel, owner = nil, platform = plat, color = pc }
	end

	result.treadmillContains = function(p)
		local rel = result.treadmill.cf:PointToObjectSpace(p)
		local s = result.treadmill.size
		return math.abs(rel.X) <= s.X / 2 and math.abs(rel.Z) <= s.Z / 2 and rel.Y > 0 and rel.Y < 8
	end

	return result
end

---------------------------------------------------------------- Effets
-- Explosion de particules + flash lumineux à l'éclosion (disparaît seule).
function Builder.burst(position, color, count, big)
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(big and 14 or 8, big and 32 or 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.8 or 1), NumberSequenceKeypoint.new(1, 0) })
	e.Rate = 0
	e.Parent = anchor
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = big and 26 or 14
	l.Brightness = big and 6 or 3
	l.Parent = anchor
	anchor.Parent = workspace
	e:Emit(count)
	local ring = Instance.new("Part")
	ring.Name = "Shockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 3, 3)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring:SetAttribute("Big", big == true)
	CollectionService:AddTag(ring, "Shockwave") -- animée côté client
	ring.Parent = workspace
	game:GetService("Debris"):AddItem(ring, 1.5)
	game:GetService("TweenService"):Create(l, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	game:GetService("Debris"):AddItem(anchor, 2.5)
end

-- Œuf qui vole vers le joueur qui vient de le prendre (animé côté client grâce au tag FlyEgg).
function Builder.flyEgg(tier, fromPos, userId)
	local egg = Builder.egg(tier, true)
	egg.Name = "FlyEgg"
	egg.CFrame = CFrame.new(fromPos)
	egg:SetAttribute("Target", userId)
	egg:SetAttribute("Start", fromPos)
	CollectionService:AddTag(egg, "FlyEgg")
	egg.Parent = workspace
	game:GetService("Debris"):AddItem(egg, 1.2)
	return egg
end

-- Pet suiveur : version miniature d'un pet, sans étiquette.
function Builder.follower(petIdx, sizeIdx, mutIdx)
	local model = Builder.pet(petIdx, sizeIdx, mutIdx)
	model:ScaleTo(0.45)
	model:SetAttribute("Seed", petIdx * 31 + sizeIdx * 7 + mutIdx)
	return model
end

return Builder

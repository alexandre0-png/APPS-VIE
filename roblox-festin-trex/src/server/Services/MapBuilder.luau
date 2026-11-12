--!nonstrict
-- Construction procédurale du monde avec des Parts natives Roblox (aucun asset externe) :
-- place du festin, stands, kiosques, tables de survie, arbres, secrets, éclairage.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local MapBuilder = {}

local map: Folder

local function part(parent: Instance, props: any): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function c3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function billboard(adornee: BasePart, text: string, offset: Vector3, width: number, height: number, maxDistance: number, alwaysOnTop: boolean?)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance
	gui.AlwaysOnTop = alwaysOnTop == true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function prompt(parent: BasePart, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold
	pp.MaxActivationDistance = distance
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = parent
	return pp
end

-- ---------------------------------------------------------------- éléments

local function buildGround()
	part(map, { Name = "Ground", Size = Vector3.new(520, 2, 520), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(98, 155, 72), Material = Enum.Material.Grass })

	-- Place pavée circulaire : 2 anneaux de couleurs différentes.
	part(map, { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 150, 150), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(163, 162, 165), Material = Enum.Material.Cobblestone })
	part(map, { Name = "PlazaInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 90, 90), CFrame = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(196, 170, 120), Material = Enum.Material.Cobblestone })

	-- Chemin du point d'apparition à la place.
	part(map, { Name = "Path", Size = Vector3.new(14, 0.3, 70), Position = Vector3.new(0, 0.15, 95), Color = Color3.fromRGB(196, 170, 120), Material = Enum.Material.Cobblestone })

	-- Points d'apparition.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = Vector3.new(0, 0.5, 128)
	spawn.Color = Color3.fromRGB(255, 120, 80)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map
	billboard(spawn, "🍽️ Festin du T-Rex", Vector3.new(0, 7, 0), 260, 60, 150)

	-- Murs invisibles autour de l'arène.
	local walls = {
		{ Vector3.new(520, 80, 2), Vector3.new(0, 40, 258) },
		{ Vector3.new(520, 80, 2), Vector3.new(0, 40, -258) },
		{ Vector3.new(2, 80, 520), Vector3.new(258, 40, 0) },
		{ Vector3.new(2, 80, 520), Vector3.new(-258, 40, 0) },
	}
	for _, w in ipairs(walls) do
		part(map, { Name = "Wall", Size = w[1], Position = w[2], Transparency = 1, CanQuery = false, CanTouch = false })
	end
end

local function buildStand(food: any, pos: Vector3)
	local base = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local folder = Instance.new("Model")
	folder.Name = "Stand_" .. food.Id
	folder.Parent = map
	local accent = c3(food.Color)
	if food.Id == "gateau" then
		accent = Color3.fromRGB(255, 150, 200)
	end

	local counter = part(folder, { Name = "Counter", Size = Vector3.new(9, 4, 3.5), CFrame = base * CFrame.new(0, 2, 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	part(folder, { Name = "BackWall", Size = Vector3.new(9.4, 8, 0.5), CFrame = base * CFrame.new(0, 4, 2.6), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Wood })
	for _, x in ipairs({ -4.4, 4.4 }) do
		part(folder, { Name = "Post", Size = Vector3.new(0.6, 8.4, 0.6), CFrame = base * CFrame.new(x, 4.2, -1.4), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	end
	-- Auvent rayé
	local roof
	for i = 0, 4 do
		local stripe = part(folder, {
			Name = "Awning",
			Size = Vector3.new(2.4, 0.6, 6.6),
			CFrame = base * CFrame.new(-4.8 + i * 2.4, 8.4, 0.5) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = if i % 2 == 0 then accent else Color3.fromRGB(250, 250, 250),
		})
		if i == 2 then
			roof = stripe
		end
	end
	-- Présentoir
	for i = -1, 1 do
		part(folder, {
			Name = "Display",
			Shape = Enum.PartType[food.Shape],
			Size = Vector3.new(food.Size[1], food.Size[2], food.Size[3]) * 1.3,
			CFrame = base * CFrame.new(i * 2.4, 4 + food.Size[2] * 0.65, -0.2),
			Color = c3(food.Color),
			Material = Enum.Material[food.Material],
			CanCollide = false,
		})
	end
	counter:SetAttribute("FoodId", food.Id)
	local label = if food.Price > 0 then string.format("%s %s\nDébloquer : %s 🪙", food.Emoji, food.Name, Util.formatNumber(food.Price)) else (food.Emoji .. " " .. food.Name .. " (gratuit)")
	billboard(roof, label, Vector3.new(0, 4.5, 0), 240, 90, 110)

	local pp = prompt(counter, "Prendre", food.Name, 0, 11)
	pp:SetAttribute("FoodId", food.Id)
	CollectionService:AddTag(pp, "FoodStand")
end

local function buildKiosk(name: string, pos: Vector3, target: Vector3, color: Color3, text: string, panel: string, action: string)
	local base = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = map
	local counter = part(m, { Name = "Counter", Size = Vector3.new(14, 4, 4), CFrame = base * CFrame.new(0, 2, -2), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	part(m, { Name = "Back", Size = Vector3.new(16, 14, 1), CFrame = base * CFrame.new(0, 7, 5), Color = color })
	part(m, { Name = "SideL", Size = Vector3.new(1, 14, 8), CFrame = base * CFrame.new(-8, 7, 1.5), Color = color })
	part(m, { Name = "SideR", Size = Vector3.new(1, 14, 8), CFrame = base * CFrame.new(8, 7, 1.5), Color = color })
	local roof = part(m, { Name = "Roof", Size = Vector3.new(19, 1.4, 12), CFrame = base * CFrame.new(0, 14.4, -0.5), Color = Color3.fromRGB(200, 60, 60) })
	part(m, { Name = "Floor", Size = Vector3.new(16, 0.4, 9), CFrame = base * CFrame.new(0, 0.2, 1), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.WoodPlanks })
	billboard(roof, text, Vector3.new(0, 5, 0), 300, 100, 160)
	local pp = prompt(counter, action, text, 0.2, 12)
	pp:SetAttribute("Panel", panel)
	CollectionService:AddTag(pp, "PanelPrompt")
end

local function buildAltar(pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Altar"
	m.Parent = map
	part(m, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 14, 14), CFrame = CFrame.new(pos.X, 0.75, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Marble })
	local orb = part(m, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = Vector3.new(pos.X, 5, pos.Z), Color = Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 22
	light.Parent = orb
	billboard(orb, "✨ Autel d'évolution", Vector3.new(0, 4, 0), 300, 70, 160)
	local pp = prompt(orb, "Évoluer", "Autel d'évolution", 0.2, 14)
	pp:SetAttribute("Panel", "rebirth")
	CollectionService:AddTag(pp, "PanelPrompt")
end

local function buildLeaderboard(pos: Vector3, target: Vector3): { TextLabel }
	local base = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
	local m = Instance.new("Model")
	m.Name = "Leaderboard"
	m.Parent = map
	for _, x in ipairs({ -9, 9 }) do
		part(m, { Name = "Post", Size = Vector3.new(1.2, 8, 1.2), CFrame = base * CFrame.new(x, 4, 0.8), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	end
	local board = part(m, { Name = "Board", Size = Vector3.new(22, 13, 1), CFrame = base * CFrame.new(0, 12, 0), Color = Color3.fromRGB(35, 35, 45) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 52
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	title.Text = "🏆 Plus gros nourrisseurs"
	title.Parent = gui
	local labels = {}
	for i = 1, 10 do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -40, 0, 38)
		l.Position = UDim2.new(0, 20, 0, 72 + (i - 1) * 43)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = 30
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Text = string.format("%d. —", i)
		l.Parent = gui
		labels[i] = l
	end
	return labels
end

-- Table de survie surélevée avec escalier.
local function buildTable(pos: Vector3, stairsDir: number)
	local m = Instance.new("Model")
	m.Name = "SafeTable"
	m.Parent = map
	local top = part(m, { Name = "Top", Size = Vector3.new(16, 1, 16), Position = Vector3.new(pos.X, 14.5, pos.Z), Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.Wood })
	part(m, { Name = "Cloth", Size = Vector3.new(12, 0.2, 12), Position = Vector3.new(pos.X, 15.1, pos.Z), Color = Color3.fromRGB(220, 60, 60), CanCollide = false })
	for _, dx in ipairs({ -7, 7 }) do
		for _, dz in ipairs({ -7, 7 }) do
			part(m, { Name = "Leg", Size = Vector3.new(1.4, 14, 1.4), Position = Vector3.new(pos.X + dx, 7, pos.Z + dz), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
		end
	end
	-- 10 marches de 1,5 stud (hauteur totale 15), côté de l'axe central.
	local edgeZ = pos.Z + stairsDir * 8
	for k = 1, 10 do
		local z = edgeZ + stairsDir * (1.5 + (10 - k) * 3)
		part(m, { Name = "Step", Size = Vector3.new(8, 1.5 * k, 3), Position = Vector3.new(pos.X, 0.75 * k, z), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.WoodPlanks })
	end
	billboard(top, "🛟 Zone sûre", Vector3.new(0, 6, 0), 220, 60, 300, true)
end

local function buildTrees()
	for i = 1, 40 do
		local angle = (i / 40) * math.pi * 2 + math.sin(i * 12.9898) * 0.08
		local radius = 190 + (math.sin(i * 78.233) * 0.5 + 0.5) * 50
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local s = 0.8 + (math.sin(i * 3.7) * 0.5 + 0.5) * 0.6
		part(map, { Name = "Trunk", Size = Vector3.new(2.4 * s, 10 * s, 2.4 * s), Position = Vector3.new(x, 5 * s, z), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
		part(map, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(14 * s, 14 * s, 14 * s), Position = Vector3.new(x, 14 * s, z), Color = Color3.fromRGB(60 + (i % 3) * 12, 140 + (i % 4) * 8, 60), Material = Enum.Material.Grass, CanCollide = false })
	end
end

local function buildBunting()
	local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 170, 255), Color3.fromRGB(120, 220, 120), Color3.fromRGB(255, 140, 220) }
	for i = 1, 24 do
		local a = (i / 24) * math.pi * 2
		local x, z = math.cos(a) * 72, math.sin(a) * 72
		part(map, { Name = "FlagPole", Size = Vector3.new(0.6, 14, 0.6), Position = Vector3.new(x, 7, z), Color = Color3.fromRGB(230, 230, 230), CanQuery = false })
		part(map, { Name = "Flag", Size = Vector3.new(0.3, 2.6, 3.4), CFrame = CFrame.new(x, 12.6, z) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, 1.9), Color = colors[(i % #colors) + 1], CanCollide = false, CanQuery = false })
	end
end

local SECRETS = {
	{ "s1", Vector3.new(10, 1.5, -62) },
	{ "s2", Vector3.new(130, 16.2, 45) },
	{ "s3", Vector3.new(-200, 1.5, -150) },
	{ "s4", Vector3.new(-110, 1.5, 78) },
	{ "s5", Vector3.new(212, 1.5, 112) },
}

local function buildSecrets()
	for _, s in ipairs(SECRETS) do
		local fork = part(map, { Name = "GoldenFork_" .. s[1], Size = Vector3.new(0.9, 2.6, 0.9), Position = s[2], Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color = fork.Color
		light.Range = 9
		light.Brightness = 1.5
		light.Parent = fork
		local pp = prompt(fork, "Ramasser", "Fourchette d'or", 0.6, 10)
		pp:SetAttribute("SecretId", s[1])
		CollectionService:AddTag(pp, "Secret")
	end
end

local function buildLighting()
	Lighting.ClockTime = 16.4 -- heure dorée : ombres longues, couleurs chaudes
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(125, 122, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true
	for _, class in ipairs({ "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect" }) do
		local old = Lighting:FindFirstChildOfClass(class)
		if old then
			old:Destroy()
		end
	end
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.25
	atmo.Color = Color3.fromRGB(255, 220, 190)
	atmo.Decay = Color3.fromRGB(255, 170, 120)
	atmo.Glare = 0.2
	atmo.Haze = 0.7
	atmo.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 22
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(255, 247, 238)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.12
	rays.Spread = 0.7
	rays.Parent = Lighting
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 120
	dof.InFocusRadius = 140
	dof.NearIntensity = 0
	dof.Parent = Lighting
end

-- Décor : assiette géante sous le T-Rex, lampadaires, fleurs, rochers (positions pseudo-aléatoires déterministes).
local function buildDecor()
	local plate = part(map, { Name = "DinoPlate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 74, 74), CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(245, 245, 248), Material = Enum.Material.Marble, CanQuery = false })
	part(plate.Parent, { Name = "DinoPlateRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 80, 80), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(215, 70, 70), Material = Enum.Material.SmoothPlastic, CanQuery = false })

	-- 12 lampadaires entre les drapeaux.
	for i = 1, 12 do
		local a = ((i - 0.5) / 12) * math.pi * 2
		local x, z = math.cos(a) * 66, math.sin(a) * 66
		part(map, { Name = "LampPole", Size = Vector3.new(0.7, 11, 0.7), Position = Vector3.new(x, 5.5, z), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, CanQuery = false })
		local bulb = part(map, { Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = Vector3.new(x, 12, z), Color = Color3.fromRGB(255, 226, 140), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Range = 26
		light.Brightness = 1.1
		light.Shadows = false
		light.Parent = bulb
	end

	-- Fleurs et rochers hors de la place.
	local flowerColors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 110, 255) }
	for i = 1, 140 do
		local a = math.sin(i * 12.9898) * 43758.5453
		local b = math.sin(i * 78.233) * 24634.6345
		local angle = (a - math.floor(a)) * math.pi * 2
		local radius = 90 + (b - math.floor(b)) * 90
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		part(map, { Name = "Flower", Size = Vector3.new(0.7, 0.9, 0.7), Position = Vector3.new(x, 0.45, z), Color = flowerColors[(i % #flowerColors) + 1], CanCollide = false, CanQuery = false, CanTouch = false })
	end
	for i = 1, 24 do
		local a = math.sin(i * 39.346) * 43758.5453
		local b = math.sin(i * 11.135) * 24634.6345
		local c = math.sin(i * 7.77) * 9123.1
		local angle = (a - math.floor(a)) * math.pi * 2
		local radius = 100 + (b - math.floor(b)) * 110
		local size = 3 + (c - math.floor(c)) * 5
		part(map, { Name = "Rock", Size = Vector3.new(size, size * 0.7, size * 0.9), CFrame = CFrame.new(math.cos(angle) * radius, size * 0.25, math.sin(angle) * radius) * CFrame.Angles(0, angle, math.rad(8)), Color = Color3.fromRGB(135, 135, 140), Material = Enum.Material.Slate, CanQuery = false })
	end
end

-- Retourne (dossierCarte, étiquettesDuClassement)
function MapBuilder.build(): (Folder, { TextLabel })
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	buildLighting()
	buildGround()
	buildBunting()
	buildDecor()
	buildTrees()

	-- Stands de nourriture en arc de cercle devant le T-Rex.
	local angles = { -62, -37, -12, 12, 37, 62 }
	for i, food in ipairs(Config.Foods) do
		local a = math.rad(angles[i])
		buildStand(food, Vector3.new(math.sin(a) * 58, 0, math.cos(a) * 58))
	end

	buildKiosk("ShopKiosk", Vector3.new(-100, 0, 72), Vector3.new(0, 0, 72), Color3.fromRGB(255, 170, 60), "🛒 Boutique", "shop", "Ouvrir")
	buildKiosk("NestKiosk", Vector3.new(100, 0, 72), Vector3.new(0, 0, 72), Color3.fromRGB(120, 200, 120), "🥚 Nid des compagnons", "pets", "Ouvrir")
	buildKiosk("QuestKiosk", Vector3.new(30, 0, 108), Vector3.new(0, 0, 128), Color3.fromRGB(200, 150, 90), "📜 Quêtes du jour", "quests", "Ouvrir")
	buildAltar(Vector3.new(0, 0, 160))
	local labels = buildLeaderboard(Vector3.new(-30, 0, 108), Vector3.new(0, 0, 128))

	-- 8 tables de survie : 4 colonnes x 2 rangées, escaliers tournés vers l'axe central.
	for _, x in ipairs({ -125, -80, 80, 125 }) do
		buildTable(Vector3.new(x, 0, 40), -1)
		buildTable(Vector3.new(x, 0, -40), 1)
	end

	buildSecrets()
	return map, labels
end

return MapBuilder

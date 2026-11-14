-- ModuleScript : ServerScriptService/HubWorld (lieu HUB uniquement)
-- Construit le hub : place pavée avec fontaine, 5 portails de lancement (solo, 2, 3, 4, 5 joueurs) en arc, panneau des parties d'amis,
-- décor et ambiance. Tout en Parts, matériaux et lumières de base Roblox. Léger (une centaine de Parts) : pensé pour les téléphones.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local HubWorld = {}

local FONT = Enum.Font.GothamBold
local ZONE_COLORS = {
	Color3.fromRGB(255, 210, 63), -- solo
	Color3.fromRGB(91, 227, 125), -- 2
	Color3.fromRGB(74, 163, 255), -- 3
	Color3.fromRGB(184, 120, 255), -- 4
	Color3.fromRGB(255, 107, 107), -- 5
}

local function part(props, parent)
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

local function cylinder(props, parent) -- cylindre à axe vertical
	props.Shape = Enum.PartType.Cylinder
	local h, d = props.Height, props.Diameter
	props.Size = Vector3.new(h, d, d)
	props.Height, props.Diameter = nil, nil
	local pos = props.Position
	props.Position = nil
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props, parent)
end

local function billboard(adornee, text, offsetY, width, height)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(width, height)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = adornee
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = bb
	return l
end

local function tree(pos, parent, rng)
	local s = rng:NextNumber(0.9, 1.4)
	part({ Name = "Trunk", Size = Vector3.new(2 * s, 8 * s, 2 * s), Position = pos + Vector3.new(0, 4 * s, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood }, parent)
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(11 * s, 11 * s, 11 * s), Position = pos + Vector3.new(0, 11 * s, 0), Color = Color3.fromRGB(70, 150, 80), Material = Enum.Material.Grass }, parent)
end

local function lamp(pos, parent)
	part({ Name = "LampPost", Size = Vector3.new(0.8, 7, 0.8), Position = pos + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, parent)
	local head = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = pos + Vector3.new(0, 7.6, 0), Color = Color3.fromRGB(255, 235, 170), Material = Enum.Material.Neon }, parent)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 225, 160)
	l.Range = 24
	l.Brightness = 1.2
	l.Parent = head
end

function HubWorld.setupLighting()
	Lighting.ClockTime = 17.6 -- crépuscule doré : les portails néon ressortent
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 100, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 125, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 200, 150)
	Lighting.GlobalShadows = true
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(255, 205, 170)
	atm.Decay = Color3.fromRGB(180, 120, 160)
	atm.Haze = 1.6
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChild("HubBloom") or Instance.new("BloomEffect")
	bloom.Name = "HubBloom"
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end

-- Retourne { spawn, zones = { [taille] = { part, label, center, radius } }, folder }
function HubWorld.build(Config)
	local world = Instance.new("Folder")
	world.Name = "HubWorld"
	world.Parent = workspace
	HubWorld.setupLighting()
	local rng = Random.new(11)

	cylinder({ Name = "Ground", Height = 2, Diameter = 420, Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(88, 150, 84), Material = Enum.Material.Grass }, world)
	cylinder({ Name = "Plaza", Height = 0.6, Diameter = 96, Position = Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(196, 184, 160), Material = Enum.Material.Cobblestone }, world)
	cylinder({ Name = "PlazaRing", Height = 0.7, Diameter = 100, Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(150, 125, 85), Material = Enum.Material.Slate }, world)
	local rimWall = part({ Name = "Rim", Size = Vector3.new(420, 80, 2), Position = Vector3.new(0, 40, -210), Transparency = 1, CanQuery = false }, world)
	for _, w in ipairs({ { 0, 210, 420, 2 }, { 210, 0, 2, 420 }, { -210, 0, 2, 420 } }) do
		part({ Name = "Wall", Size = Vector3.new(w[3], 80, w[4]), Position = Vector3.new(w[1], 40, w[2]), Transparency = 1, CanQuery = false }, world)
	end
	rimWall.CanQuery = false

	-- Fontaine centrale
	cylinder({ Name = "FountainBase", Height = 2.4, Diameter = 16, Position = Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(170, 170, 178), Material = Enum.Material.Marble }, world)
	cylinder({ Name = "FountainWater", Height = 0.4, Diameter = 14, Position = Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false }, world)
	local spout = part({ Name = "Spout", Size = Vector3.new(1.4, 6, 1.4), Position = Vector3.new(0, 5, 0), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.Marble }, world)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(160, 225, 255))
	spray.Rate = 14
	spray.Lifetime = NumberRange.new(1, 1.6)
	spray.Speed = NumberRange.new(6, 10)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.Size = NumberSequence.new(0.5, 0)
	spray.LightEmission = 0.7
	spray.Parent = spout
	local fl = Instance.new("PointLight")
	fl.Color = Color3.fromRGB(120, 210, 255)
	fl.Range = 22
	fl.Brightness = 1.4
	fl.Parent = spout

	-- Point d'arrivée au sud de la place
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 0.4, 14)
	spawn.Position = Vector3.new(0, 0.6, 34)
	spawn.Color = Color3.fromRGB(255, 226, 150)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.45
	spawn.Parent = world

	-- Titre au-dessus de l'entrée
	local titlePost = part({ Name = "TitlePost", Size = Vector3.new(1.2, 14, 1.2), Position = Vector3.new(0, 7, 50), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
	local titleBoard = part({ Name = "TitleBoard", Size = Vector3.new(24, 6, 0.8), Position = Vector3.new(0, 13, 49.5), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, world)
	billboard(titleBoard, "🥚 " .. Config.TITLE .. " : le hub", 0, 360, 70)
	billboard(titlePost, "Entre dans un portail pour lancer ta partie", -4, 360, 40).TextSize = 18

	-- Panneau des parties d'amis (la liste cliquable est dans l'interface, en haut à droite)
	local fp = part({ Name = "FriendsPost", Size = Vector3.new(1, 8, 1), Position = Vector3.new(-26, 4, 28), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
	local fb = part({ Name = "FriendsBoard", Size = Vector3.new(11, 5, 0.7), Position = Vector3.new(-26, 8.6, 28), Color = Color3.fromRGB(46, 110, 80), Material = Enum.Material.WoodPlanks }, world)
	billboard(fb, "👥 Parties de tes amis\nBouton « Amis » en haut à droite", 0, 300, 90)
	CollectionService:AddTag(fp, "HubFriendsPost")

	-- Portails de lancement : un arc au nord de la place, du solo à 5 joueurs
	local zones = {}
	local sizes = Config.Game.Sizes
	local R = 62
	for i, size in ipairs(sizes) do
		local a = math.rad(-72 + (i - 1) * 36) -- -72°..72° autour du nord (-Z)
		local cx, cz = math.sin(a) * R, -math.cos(a) * R
		local color = ZONE_COLORS[(i - 1) % #ZONE_COLORS + 1]
		local rot = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(0, 0, 0))
		cylinder({ Name = "PortalRing" .. size, Height = 0.5, Diameter = 21, Position = Vector3.new(cx, 0.45, cz), Color = color, Material = Enum.Material.Neon, CanCollide = false }, world)
		local padPart = cylinder({ Name = "PortalZone" .. size, Height = 0.6, Diameter = 18, Position = Vector3.new(cx, 0.55, cz), Color = color:Lerp(Color3.new(0, 0, 0), 0.55), Material = Enum.Material.SmoothPlastic, CanCollide = false }, world)
		padPart:SetAttribute("Size", size)
		CollectionService:AddTag(padPart, "PortalZone")
		for _, sx in ipairs({ -10.5, 10.5 }) do -- piliers de l'arche
			part({ Name = "Pillar", Size = Vector3.new(2, 14, 2), CFrame = rot * CFrame.new(sx, 7, -2), Color = Color3.fromRGB(205, 200, 210), Material = Enum.Material.Marble }, world)
		end
		local lintel = part({ Name = "Lintel", Size = Vector3.new(24, 2.4, 2.4), CFrame = rot * CFrame.new(0, 15, -2), Color = color, Material = Enum.Material.Neon }, world)
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Range = 30
		pl.Brightness = 1.6
		pl.Parent = lintel
		local label = billboard(lintel, "", 5, 320, 110)
		label.Text = size == 1 and "SOLO" or (size .. " JOUEURS")
		local status = billboard(padPart, "Libre", 7, 300, 60)
		status.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		zones[size] = { part = padPart, status = status, center = Vector3.new(cx, 0, cz), radius = 9, color = color, title = label }
	end

	-- Décor : lampadaires autour de la place, arbres, fleurs, rochers, collines
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		lamp(Vector3.new(math.sin(a) * 47, 0, math.cos(a) * 47), world)
	end
	for _ = 1, 46 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(70, 190)
		tree(Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), world, rng)
	end
	local flowerColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 140, 255), Color3.fromRGB(120, 220, 255) }
	for _ = 1, 90 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(52, 120)
		part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(math.sin(a) * r, 0.45, math.cos(a) * r), Color = flowerColors[rng:NextInteger(1, #flowerColors)], CanCollide = false }, world)
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local sz = rng:NextNumber(120, 200)
		part({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Position = Vector3.new(math.sin(a) * 250, -sz * 0.38, math.cos(a) * 250), Color = Color3.fromRGB(80 + (k % 3) * 8, 140 + (k % 2) * 12, 90), Material = Enum.Material.Grass, CanCollide = false }, world)
	end
	return { spawn = spawn, zones = zones, folder = world }
end

return HubWorld

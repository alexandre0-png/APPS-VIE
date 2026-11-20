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
	local post = part({ Name = "LampPost", Size = Vector3.new(0.8, 7, 0.8), Position = pos + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, parent)
	local head = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = pos + Vector3.new(0, 7.6, 0), Color = Color3.fromRGB(255, 235, 170), Material = Enum.Material.Neon }, parent)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 225, 160)
	l.Range = 24
	l.Brightness = 1.2
	l.Parent = head
	return { post = post, head = head, x = pos.X, z = pos.Z }
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

-- Place une copie d'un modèle de décor : mise à l'échelle à `height` studs, posée au sol en (x, z), tournée de `rotDeg`. Tout est ancré,
-- sans collision ni requête (décor). Retourne true si le modèle est en place ; en cas d'erreur, tout est défait. Ne lève jamais d'erreur.
function HubWorld.placeModel(model, x, z, rotDeg, height, parent)
	local ok = pcall(function()
		if not model:IsA("Model") then
			error("pas un Model")
		end
		local _, size = model:GetBoundingBox()
		if size.Y < 0.05 then
			error("hauteur nulle")
		end
		model:ScaleTo(height / size.Y)
		local bbox, size2 = model:GetBoundingBox()
		local target = CFrame.new(x, size2.Y / 2, z) * CFrame.Angles(0, math.rad(rotDeg), 0)
		model:PivotTo(target * bbox:ToObjectSpace(model:GetPivot()))
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		model.Parent = parent
	end)
	if not ok then
		pcall(function()
			model:Destroy()
		end)
	end
	return ok
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
	-- Murs et plafond INVISIBLES : on ne sort jamais du hub, ni par les côtés ni en sautant très haut (hauteur des murs = plafond).
	local CEIL = 130
	for _, w in ipairs({ { 0, -212, 428, 4 }, { 0, 212, 428, 4 }, { 212, 0, 4, 428 }, { -212, 0, 4, 428 } }) do
		part({ Name = "InvisibleWall", Size = Vector3.new(w[3], CEIL, w[4]), Position = Vector3.new(w[1], CEIL / 2, w[2]), Transparency = 1, CanQuery = false }, world)
	end
	part({ Name = "InvisibleCeiling", Size = Vector3.new(428, 4, 428), Position = Vector3.new(0, CEIL + 2, 0), Transparency = 1, CanQuery = false }, world)

	-- Fontaine centrale
	local fBase = cylinder({ Name = "FountainBase", Height = 2.4, Diameter = 16, Position = Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(170, 170, 178), Material = Enum.Material.Marble }, world)
	local fWater = cylinder({ Name = "FountainWater", Height = 0.4, Diameter = 14, Position = Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false }, world)
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
		zones[size] = { part = padPart, status = status, center = Vector3.new(cx, 0, cz), radius = 9, color = color, title = label, size = size, mode = "arena" }
	end

	-- Portails du mode CHÂTEAU : second arc, plus au nord, couleur pierre et feu (clés « c1 » à « c5 »)
	local castleColor = Color3.fromRGB(255, 110, 60)
	for i, size in ipairs(sizes) do
		local a = math.rad(-72 + (i - 1) * 36)
		local cx, cz = math.sin(a) * 108, -math.cos(a) * 108
		local rot = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(0, 0, 0))
		cylinder({ Name = "CastlePortalRing" .. size, Height = 0.5, Diameter = 21, Position = Vector3.new(cx, 0.45, cz), Color = castleColor, Material = Enum.Material.Neon, CanCollide = false }, world)
		local padPart = cylinder({ Name = "CastlePortalZone" .. size, Height = 0.6, Diameter = 18, Position = Vector3.new(cx, 0.55, cz), Color = Color3.fromRGB(70, 36, 24), Material = Enum.Material.Slate, CanCollide = false }, world)
		padPart:SetAttribute("Size", size)
		padPart:SetAttribute("Mode", "castle")
		CollectionService:AddTag(padPart, "PortalZone")
		for _, sx in ipairs({ -10.5, 10.5 }) do -- piliers en pierre sombre, créneaux
			part({ Name = "CastlePillar", Size = Vector3.new(2.6, 16, 2.6), CFrame = rot * CFrame.new(sx, 8, -2), Color = Color3.fromRGB(112, 108, 120), Material = Enum.Material.Slate }, world)
			part({ Name = "CastleMerlon", Size = Vector3.new(3.4, 1.4, 3.4), CFrame = rot * CFrame.new(sx, 16.7, -2), Color = Color3.fromRGB(96, 92, 104), Material = Enum.Material.Slate }, world)
		end
		local lintel = part({ Name = "CastleLintel", Size = Vector3.new(24, 2.4, 2.4), CFrame = rot * CFrame.new(0, 15.5, -2), Color = castleColor, Material = Enum.Material.Neon }, world)
		local pl = Instance.new("PointLight")
		pl.Color = castleColor
		pl.Range = 30
		pl.Brightness = 1.6
		pl.Parent = lintel
		local label = billboard(lintel, "", 5, 340, 110)
		label.Text = "🏰 CHÂTEAU · " .. (size == 1 and "SOLO" or (size .. " JOUEURS"))
		local status = billboard(padPart, "Libre", 7, 300, 60)
		status.TextColor3 = Color3.fromRGB(255, 190, 150)
		zones["c" .. size] = { part = padPart, status = status, center = Vector3.new(cx, 0, cz), radius = 9, color = castleColor, title = label, size = size, mode = "castle" }
	end
	local cb = part({ Name = "CastleBoard", Size = Vector3.new(15, 9, 0.7), CFrame = CFrame.lookAt(Vector3.new(0, 10, 78), Vector3.new(0, 10, 36)), Color = Color3.fromRGB(70, 46, 40), Material = Enum.Material.WoodPlanks }, world)
	billboard(cb, "🏰 Mode Château\nSalles à pièges : pics, lames, boulets, portes.\nCoffre final : œuf rare. Classement des temps.", 0, 420, 130)

	-- Panneaux d'explication : planches lisibles (SurfaceGui) tournées vers le point d'arrivée
	local function board(name, pos, title, lines, color)
		local post = part({ Name = name .. "Post", Size = Vector3.new(1, 7, 1), Position = pos + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		local face = part({ Name = name, Size = Vector3.new(15, 9, 0.7), CFrame = CFrame.lookAt(pos + Vector3.new(0, 10, 0), Vector3.new(0, 10, 36)), Color = Color3.fromRGB(46, 90, 64), Material = Enum.Material.WoodPlanks }, world)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(600, 360)
		sg.LightInfluence = 0
		sg.Adornee = face
		sg.Parent = face
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Position = UDim2.fromOffset(20, 10)
		head.Size = UDim2.new(1, -40, 0, 56)
		head.Font = FONT
		head.TextScaled = true
		head.TextColor3 = color
		head.Text = title
		head.Parent = sg
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(24, 72)
		body.Size = UDim2.new(1, -48, 1, -84)
		body.Font = Enum.Font.GothamMedium
		body.TextSize = 27
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextColor3 = Color3.fromRGB(240, 250, 242)
		body.Text = table.concat(lines, "\n")
		body.Parent = sg
		return post
	end
	local G = Config.Game
	board("BoardHow", Vector3.new(26, 0, 30), "Comment jouer", {
		"🥚 Chipe des œufs, fais-les éclore, deviens Roi des Couvées.",
		"🏃 Cours sur le tapis pour aller plus vite.",
		"🐾 Tes pets rapportent des pièces, même absent.",
	}, Color3.fromRGB(255, 210, 63))
	board("BoardParty", Vector3.new(-26, 0, 8), "Lancer une partie", {
		"1. Choisis ta taille : solo ou 2 à " .. G.MaxPlayers .. " joueurs.",
		"2. Entre dans le portail de ce nombre.",
		"3. Départ " .. G.CountdownFull .. " s après le dernier joueur (ou " .. G.PartialWait .. " s si le groupe est incomplet).",
	}, Color3.fromRGB(91, 227, 125))
	board("BoardFriends", Vector3.new(26, 0, 8), "Rejoindre des amis", {
		"👥 Bouton « Amis » en haut à droite.",
		"Tu vois les parties ouvertes de tes amis (moins de " .. G.MaxPlayers .. " joueurs).",
		"Appuie sur Rejoindre : tu arrives en cours de partie, tes œufs sont protégés " .. G.LateJoinGrace .. " s.",
	}, Color3.fromRGB(74, 163, 255))
	local benchItems, lampItems = {}, {}
	for i = 1, 6 do -- bancs autour de la fontaine
		local a = i / 6 * math.pi * 2 + 0.5
		local bx, bz = math.sin(a) * 15, math.cos(a) * 15
		local look = CFrame.lookAt(Vector3.new(bx, 1.6, bz), Vector3.new(0, 1.6, 0))
		local seat = part({ Name = "BenchSeat", Size = Vector3.new(6, 0.6, 2), CFrame = look, Color = Color3.fromRGB(150, 104, 70), Material = Enum.Material.WoodPlanks }, world)
		local back = part({ Name = "BenchBack", Size = Vector3.new(6, 1.8, 0.4), CFrame = look * CFrame.new(0, 1.2, 1), Color = Color3.fromRGB(130, 90, 60), Material = Enum.Material.WoodPlanks }, world)
		benchItems[#benchItems + 1] = { seat = seat, back = back, x = bx, z = bz, rot = math.deg(a) }
	end
	for _, z in pairs(zones) do -- fanions et chemin de pas depuis le point d'arrivée jusqu'à chaque portail
		for k = 1, 7 do
			local t = k / 8
			part({ Name = "PathStone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.4, 4.4), CFrame = CFrame.new(Vector3.new(0 + (z.center.X - 0) * t, 0.5, 34 + (z.center.Z - 34) * t)) * CFrame.Angles(0, 0, math.pi / 2), Color = z.color:Lerp(Color3.fromRGB(215, 205, 180), 0.6), Material = Enum.Material.Cobblestone, CanCollide = false }, world)
		end
	end
	local sparks = part({ Name = "Fireflies", Size = Vector3.new(160, 14, 160), Position = Vector3.new(0, 9, 0), Transparency = 1, CanCollide = false, CanQuery = false }, world)
	local ff = Instance.new("ParticleEmitter")
	ff.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ff.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	ff.Rate = 10
	ff.Lifetime = NumberRange.new(4, 6)
	ff.Speed = NumberRange.new(0.5, 1.5)
	ff.SpreadAngle = Vector2.new(180, 180)
	ff.Size = NumberSequence.new(0.35)
	ff.LightEmission = 1
	ff.Parent = sparks

	-- Décor : lampadaires autour de la place, arbres, fleurs, rochers, collines
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		lampItems[#lampItems + 1] = lamp(Vector3.new(math.sin(a) * 47, 0, math.cos(a) * 47), world)
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
	return { spawn = spawn, zones = zones, folder = world, fountainParts = { fBase, fWater, spout }, benchItems = benchItems, lampItems = lampItems }
end

return HubWorld

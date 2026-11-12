--!nonstrict
-- Construit tout le décor avec des blocs Roblox natifs :
--   * le HUB (lobby) : place pavée, armurerie, tableau de quêtes, coffre quotidien,
--     zone d'entraînement, portail vers l'arène, classement ;
--   * l'ARÈNE : forteresse à tour centrale, bunkers d'angle, couvertures, lave,
--     jump pads, soins et orbe de rage.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local MapBuilder = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function mk(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			if k == "Color" and type(v) == "string" then
				v = Color3.fromHex(v)
			end
			p[k] = v
		end
	end
	if p.CanCollide == false and props.CanQuery == nil then
		p.CanQuery = false -- les éléments non solides ne bloquent ni tirs ni caméra
	end
	p.Parent = parent
	return p
end

-- Disque horizontal (cylindre couché) dont le dessus est à `topY`.
local function disc(parent, name, center, diameter, height, topY, color, material)
	return mk(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center.X, topY - height / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

local function billboard(parent, text, size, color, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size or 260, 60)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parent
	return gui
end

local function prompt(parent, action, text, menu)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = text
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp:SetAttribute("OpenMenu", menu)
	pp.Parent = parent
	return pp
end

local function tree(parent, x, z, scale)
	local h = 7 * scale
	mk(parent, { Name = "Trunk", Size = Vector3.new(1.6 * scale, h, 1.6 * scale), Position = Vector3.new(x, h / 2, z), Color = rgb(106, 74, 42), Material = Enum.Material.Wood })
	mk(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9 * scale, 8 * scale, 9 * scale), Position = Vector3.new(x, h + 2 * scale, z), Color = rgb(70, 140, 60), Material = Enum.Material.Grass, CanCollide = false })
end

local function lamp(parent, x, z)
	mk(parent, { Name = "LampPost", Size = Vector3.new(0.8, 9, 0.8), Position = Vector3.new(x, 4.5, z), Color = rgb(40, 40, 46), Material = Enum.Material.Metal })
	local bulb = mk(parent, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = Vector3.new(x, 9.6, z), Color = rgb(255, 230, 150), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = rgb(255, 220, 150)
	light.Parent = bulb
end

local function setupLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.Ambient = rgb(90, 90, 100)
	Lighting.OutdoorAmbient = rgb(120, 125, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.12
		cc.Contrast = 0.08
		cc.TintColor = rgb(255, 248, 240)
		cc.Parent = Lighting
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.08
		rays.Spread = 0.6
		rays.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Offset = 0.2
		atm.Color = rgb(199, 210, 230)
		atm.Decay = rgb(255, 214, 170)
		atm.Glare = 0.2
		atm.Haze = 0.8
		atm.Parent = Lighting
	end
end

-- ===================================================================
-- HUB
-- ===================================================================
local function buildLobby(root, result)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root

	mk(lobby, { Name = "Ground", Size = Vector3.new(420, 2, 420), Position = Vector3.new(0, -1, 0), Color = rgb(84, 140, 62), Material = Enum.Material.Grass })
	disc(lobby, "Plaza", Vector3.new(0, 0, 0), 120, 1, 0.5, rgb(142, 138, 130), Enum.Material.Cobblestone)
	disc(lobby, "PlazaInner", Vector3.new(0, 0, 0), 44, 1, 0.9, rgb(96, 100, 112), Enum.Material.Slate)
	disc(lobby, "PlazaRune", Vector3.new(0, 0, 0), 30, 1, 1.1, rgb(60, 64, 80), Enum.Material.Slate)

	-- monument central : épée géante
	mk(lobby, { Name = "MonumentBase", Size = Vector3.new(8, 2, 8), Position = Vector3.new(0, 2, 0), Color = rgb(120, 124, 135), Material = Enum.Material.Granite })
	mk(lobby, { Name = "MonumentBlade", Size = Vector3.new(2.4, 22, 0.7), Position = Vector3.new(0, 14, 0), Color = rgb(214, 220, 230), Material = Enum.Material.Metal })
	mk(lobby, { Name = "MonumentGuard", Size = Vector3.new(10, 1.2, 1.4), Position = Vector3.new(0, 4.6, 0), Color = rgb(255, 196, 40), Material = Enum.Material.Metal })
	local glow = mk(lobby, { Name = "MonumentGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = Vector3.new(0, 26, 0), Color = rgb(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
	CollectionService:AddTag(glow, "Spin")
	billboard(glow, "ARÈNE DES LÉGENDES", 340, rgb(255, 214, 90), Vector3.new(0, 4, 0))

	-- point d'apparition du hub
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 1.0, -30)
	spawn.Color = rgb(70, 130, 220)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	result.LobbySpawn = spawn
	billboard(spawn, "Bienvenue, guerrier !", 280, rgb(255, 255, 255), Vector3.new(0, 5, 0))

	-- portail vers l'arène
	local portalZ = 44
	for _, sx in ipairs({ -10, 10 }) do
		mk(lobby, { Name = "PortalPillar", Size = Vector3.new(4, 18, 4), Position = Vector3.new(sx, 9.5, portalZ), Color = rgb(70, 60, 90), Material = Enum.Material.Granite })
		mk(lobby, { Name = "PortalRune", Size = Vector3.new(4.2, 1, 4.2), Position = Vector3.new(sx, 14, portalZ), Color = rgb(190, 110, 255), Material = Enum.Material.Neon })
	end
	mk(lobby, { Name = "PortalBeam", Size = Vector3.new(24, 3, 4.4), Position = Vector3.new(0, 19, portalZ), Color = rgb(70, 60, 90), Material = Enum.Material.Granite })
	local portal = mk(lobby, { Name = "ArenaPortal", Size = Vector3.new(16, 16, 0.8), Position = Vector3.new(0, 9.5, portalZ), Color = rgb(170, 90, 255), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
	local swirl = Instance.new("ParticleEmitter")
	swirl.Rate = 40
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Speed = NumberRange.new(2, 5)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new(0.8, 0)
	swirl.Color = ColorSequence.new(rgb(210, 150, 255), rgb(120, 80, 255))
	swirl.LightEmission = 1
	swirl.Parent = portal
	billboard(portal, "⚔ ENTRER DANS L'ARÈNE ⚔", 380, rgb(255, 255, 255), Vector3.new(0, 11, 0))
	result.Portal = portal
	local portalStep = mk(lobby, { Name = "PortalStep", Size = Vector3.new(16, 1, 6), Position = Vector3.new(0, 1, portalZ - 3), Color = rgb(70, 60, 90), Material = Enum.Material.Granite, CanCollide = true, Transparency = 0 })
	local pp = prompt(portalStep, "Entrer dans l'arène", "Portail", nil)
	pp:SetAttribute("JoinArena", true)

	-- fanions violets le long du portail et lucioles sur la place
	for i = -3, 3 do
		mk(lobby, { Name = "Pennant", Size = Vector3.new(2, 3, 0.2), CFrame = CFrame.new(i * 3.2, 17.2 - math.abs(i) * 0.3, portalZ - 2.4) * CFrame.Angles(0, 0, math.rad(180)), Color = i % 2 == 0 and rgb(170, 90, 255) or rgb(255, 200, 60), Material = Enum.Material.Fabric, CanCollide = false })
	end
	local flies = mk(lobby, { Name = "Fireflies", Size = Vector3.new(110, 1, 110), Position = Vector3.new(0, 4, 0), Transparency = 1, CanCollide = false })
	local ff = Instance.new("ParticleEmitter")
	ff.Rate = 6
	ff.Lifetime = NumberRange.new(4, 7)
	ff.Speed = NumberRange.new(0.5, 1.5)
	ff.SpreadAngle = Vector2.new(180, 180)
	ff.Size = NumberSequence.new(0.2, 0.05)
	ff.Color = ColorSequence.new(rgb(255, 240, 150))
	ff.LightEmission = 1
	ff.Transparency = NumberSequence.new(0.1, 1)
	ff.Parent = flies

	-- armurerie
	local sx, sz = -40, 14
	mk(lobby, { Name = "ShopFloor", Size = Vector3.new(22, 1, 18), Position = Vector3.new(sx, 1, sz), Color = rgb(92, 70, 48), Material = Enum.Material.WoodPlanks })
	mk(lobby, { Name = "ShopBack", Size = Vector3.new(22, 11, 1), Position = Vector3.new(sx, 6.5, sz + 8.5), Color = rgb(150, 112, 74), Material = Enum.Material.WoodPlanks })
	mk(lobby, { Name = "ShopLeft", Size = Vector3.new(1, 11, 18), Position = Vector3.new(sx - 10.5, 6.5, sz), Color = rgb(150, 112, 74), Material = Enum.Material.WoodPlanks })
	mk(lobby, { Name = "ShopRight", Size = Vector3.new(1, 11, 18), Position = Vector3.new(sx + 10.5, 6.5, sz), Color = rgb(150, 112, 74), Material = Enum.Material.WoodPlanks })
	mk(lobby, { Name = "ShopRoof", Size = Vector3.new(25, 1.2, 21), Position = Vector3.new(sx, 12.6, sz), Color = rgb(160, 60, 52), Material = Enum.Material.Brick })
	local counter = mk(lobby, { Name = "ShopCounter", Size = Vector3.new(14, 3.4, 2.6), Position = Vector3.new(sx, 3.2, sz + 3), Color = rgb(110, 78, 50), Material = Enum.Material.Wood })
	prompt(counter, "Ouvrir l'armurerie", "Armurerie", "Shop")
	billboard(counter, "ARMURERIE", 260, rgb(255, 214, 90), Vector3.new(0, 7.5, 0))
	-- présentoir d'armes décoratif
	for i = -2, 2 do
		mk(lobby, { Name = "DisplayBlade", Size = Vector3.new(0.5, 5, 0.2), CFrame = CFrame.new(sx + i * 3.6, 7, sz + 7.8) * CFrame.Angles(0, 0, math.rad(i * 8)), Color = rgb(210, 216, 226), Material = Enum.Material.Metal })
	end

	-- tableau de quêtes
	local qx, qz = 40, 14
	mk(lobby, { Name = "BoardPostL", Size = Vector3.new(1, 10, 1), Position = Vector3.new(qx - 5, 5, qz), Color = rgb(92, 70, 48), Material = Enum.Material.Wood })
	mk(lobby, { Name = "BoardPostR", Size = Vector3.new(1, 10, 1), Position = Vector3.new(qx + 5, 5, qz), Color = rgb(92, 70, 48), Material = Enum.Material.Wood })
	local board = mk(lobby, { Name = "QuestBoard", Size = Vector3.new(10, 6, 0.8), Position = Vector3.new(qx, 7, qz), Color = rgb(170, 130, 84), Material = Enum.Material.WoodPlanks })
	prompt(board, "Voir les quêtes", "Tableau des quêtes", "Quests")
	billboard(board, "QUÊTES DU JOUR", 260, rgb(120, 220, 255), Vector3.new(0, 5, 0))

	-- coffre quotidien
	local cx, cz = 40, -14
	mk(lobby, { Name = "ChestBase", Size = Vector3.new(6, 3.4, 4), Position = Vector3.new(cx, 2.7, cz), Color = rgb(138, 92, 46), Material = Enum.Material.Wood })
	mk(lobby, { Name = "ChestBand", Size = Vector3.new(6.2, 0.8, 4.2), Position = Vector3.new(cx, 3.2, cz), Color = rgb(255, 196, 40), Material = Enum.Material.Metal })
	local lid = mk(lobby, { Name = "ChestLid", Size = Vector3.new(6, 1.6, 4), Position = Vector3.new(cx, 5.2, cz), Color = rgb(160, 108, 54), Material = Enum.Material.Wood })
	prompt(lid, "Cadeau quotidien", "Coffre", "Daily")
	billboard(lid, "CADEAU QUOTIDIEN", 260, rgb(255, 214, 90), Vector3.new(0, 4, 0))

	-- zone d'entraînement
	local tx, tz = -50, -34
	disc(lobby, "TrainingFloor", Vector3.new(tx, 0, tz), 40, 1, 0.8, rgb(120, 96, 70), Enum.Material.Sand)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		mk(lobby, { Name = "Fence", Size = Vector3.new(1, 3.4, 3), CFrame = CFrame.new(tx + math.cos(a) * 20.5, 2.5, tz + math.sin(a) * 20.5) * CFrame.Angles(0, -a, 0), Color = rgb(110, 78, 50), Material = Enum.Material.Wood })
	end
	local sign = mk(lobby, { Name = "TrainingSign", Size = Vector3.new(14, 1, 1), Position = Vector3.new(tx, 12, tz - 18), Color = rgb(40, 40, 46), Material = Enum.Material.Wood, CanCollide = false })
	billboard(sign, "ZONE D'ENTRAÎNEMENT", 340, rgb(255, 255, 255), Vector3.new(0, 1.5, 0))
	result.DummySpots = {}
	for i = 0, 4 do
		local a = (i - 2) * 0.55 + math.pi / 2
		table.insert(result.DummySpots, CFrame.new(tx + math.cos(a) * 11 - 3, 0.8, tz + math.sin(a) * 11 + 6) * CFrame.Angles(0, math.rad(-90 - (i - 2) * 25), 0))
	end

	-- classement mondial
	local board2 = mk(lobby, { Name = "LeaderboardBoard", Size = Vector3.new(30, 18, 1.2), Position = Vector3.new(0, 11, -62), Color = rgb(30, 32, 44), Material = Enum.Material.SmoothPlastic })
	mk(lobby, { Name = "LeaderboardFrame", Size = Vector3.new(32, 20, 1), Position = Vector3.new(0, 11, -62.3), Color = rgb(255, 196, 40), Material = Enum.Material.Metal })
	mk(lobby, { Name = "LeaderboardLegL", Size = Vector3.new(1.5, 4, 1.5), Position = Vector3.new(-12, 2, -62), Color = rgb(70, 70, 80), Material = Enum.Material.Metal })
	mk(lobby, { Name = "LeaderboardLegR", Size = Vector3.new(1.5, 4, 1.5), Position = Vector3.new(12, 2, -62), Color = rgb(70, 70, 80), Material = Enum.Material.Metal })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.Parent = board2
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 44
	title.TextColor3 = rgb(255, 214, 90)
	title.Text = "🏆 TOP ÉLIMINATIONS 🏆"
	title.Parent = sg
	result.LeaderboardRows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.fromOffset(30, 64 + (i - 1) * 32)
		row.Size = UDim2.new(1, -60, 0, 30)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextSize = 26
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and rgb(255, 214, 90) or rgb(235, 235, 240)
		row.Text = ("%d.  —"):format(i)
		row.Parent = sg
		result.LeaderboardRows[i] = row
	end

	-- runes du hub (énigme) : r1 derrière un pilier du portail, r2 derrière l'armurerie, r3 au fond de la cour, r4 derrière le classement
	for _, def in ipairs({ { "r1", 10, 2.2, portalZ + 4.5 }, { "r2", -40, 2.2, 28 }, { "r3", -68, 2.2, -34 }, { "r4", 0, 2.2, -69 } }) do
		local p = mk(lobby, { Name = "Rune_" .. def[1], Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = Vector3.new(def[2], def[3], def[4]), Color = rgb(255, 215, 90), Material = Enum.Material.Neon, CanCollide = false })
		CollectionService:AddTag(p, "Spin")
		table.insert(result.Runes, { Id = def[1], Part = p })
	end

	-- murs d'enceinte, arbres et lampadaires
	local R = 98
	for _, def in ipairs({ { 0, -R, 2 * R, 2 }, { 0, R, 2 * R, 2 }, { -R, 0, 2, 2 * R }, { R, 0, 2, 2 * R } }) do
		mk(lobby, { Name = "OuterWall", Size = Vector3.new(def[3], 14, def[4]), Position = Vector3.new(def[1], 7, def[2]), Color = rgb(128, 120, 112), Material = Enum.Material.Brick })
	end
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2 + 0.1
		local r = 70 + (i % 4) * 6
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x - -50) > 28 or math.abs(z - -34) > 28 then
			if not (math.abs(x) < 16 and z > 30) then
				tree(lobby, x, z, 0.9 + (i % 3) * 0.2)
			end
		end
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		lamp(lobby, math.cos(a) * 56, math.sin(a) * 56)
	end
end

-- ===================================================================
-- ARÈNE
-- ===================================================================
local ARENA_CENTER = Vector3.new(0, 0, 600)
MapBuilder.ArenaCenter = ARENA_CENTER

local function buildArena(root, result)
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = root
	local C = ARENA_CENTER

	local function at(x, y, z)
		return Vector3.new(C.X + x, C.Y + y, C.Z + z)
	end
	-- Place un bloc défini en coordonnées du quadrant 0, répliqué sur 4 quadrants (rotation de 90°).
	local function quad(name, size, localCF, color, material, extra)
		for k = 0, 3 do
			local rot = CFrame.Angles(0, math.rad(90 * k), 0)
			local cf = CFrame.new(C) * rot * localCF
			local props = { Name = name, Size = size, CFrame = cf, Color = color, Material = material }
			if extra then
				for key, v in pairs(extra) do
					props[key] = v
				end
			end
			mk(arena, props)
		end
	end

	-- sol & enceinte
	mk(arena, { Name = "Floor", Size = Vector3.new(156, 6, 156), Position = at(0, -3, 0), Color = rgb(110, 106, 100), Material = Enum.Material.Cobblestone })
	mk(arena, { Name = "OuterGround", Size = Vector3.new(420, 2, 420), Position = at(0, -7, 0), Color = rgb(70, 60, 54), Material = Enum.Material.Slate })
	disc(arena, "FloorRune", at(0, 0, 0), 72, 0.4, 0.2, rgb(80, 76, 90), Enum.Material.Slate)
	for _, def in ipairs({ { 0, -77, 156, 4 }, { 0, 77, 156, 4 }, { -77, 0, 4, 156 }, { 77, 0, 4, 156 } }) do
		mk(arena, { Name = "Wall", Size = Vector3.new(def[3], 30, def[4]), Position = at(def[1], 15, def[2]), Color = rgb(138, 104, 78), Material = Enum.Material.Brick })
		mk(arena, { Name = "WallTrim", Size = Vector3.new(def[3] + 2, 2, def[4] + 2), Position = at(def[1], 30.5, def[2]), Color = rgb(96, 72, 56), Material = Enum.Material.Brick })
	end
	for i = -7, 7 do
		for _, def in ipairs({ { i * 10, -77 }, { i * 10, 77 }, { -77, i * 10 }, { 77, i * 10 } }) do
			mk(arena, { Name = "Merlon", Size = Vector3.new(4, 4, 4), Position = at(def[1], 33.5, def[2]), Color = rgb(138, 104, 78), Material = Enum.Material.Brick })
		end
	end
	-- plafond invisible : empêche de sortir en sautant
	mk(arena, { Name = "Ceiling", Size = Vector3.new(160, 1, 160), Position = at(0, 80, 0), Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false })

	-- tour centrale (plateau + 4 rampes)
	disc(arena, "TowerBase", at(0, 0, 0), 34, 8, 8, rgb(104, 108, 120), Enum.Material.Slate)
	disc(arena, "TowerTrim", at(0, 0, 0), 36, 1, 8.4, rgb(160, 150, 120), Enum.Material.Cobblestone)
	local angle = math.atan(8 / 24)
	local len = math.sqrt(24 * 24 + 8 * 8)
	mk(arena, { Name = "RampN", Size = Vector3.new(9, 1, len), CFrame = CFrame.new(at(0, 4, 29)) * CFrame.Angles(angle, 0, 0), Color = rgb(150, 142, 128), Material = Enum.Material.Slate })
	mk(arena, { Name = "RampS", Size = Vector3.new(9, 1, len), CFrame = CFrame.new(at(0, 4, -29)) * CFrame.Angles(-angle, 0, 0), Color = rgb(150, 142, 128), Material = Enum.Material.Slate })
	mk(arena, { Name = "RampE", Size = Vector3.new(len, 1, 9), CFrame = CFrame.new(at(29, 4, 0)) * CFrame.Angles(0, 0, -angle), Color = rgb(150, 142, 128), Material = Enum.Material.Slate })
	mk(arena, { Name = "RampW", Size = Vector3.new(len, 1, 9), CFrame = CFrame.new(at(-29, 4, 0)) * CFrame.Angles(0, 0, angle), Color = rgb(150, 142, 128), Material = Enum.Material.Slate })
	for _, d in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		mk(arena, { Name = "TowerPillar", Size = Vector3.new(2, 7, 2), Position = at(d[1] * 12, 12, d[2] * 12), Color = rgb(160, 150, 120), Material = Enum.Material.Cobblestone })
	end

	-- bunkers d'angle + rampe d'accès + couvertures (en quadrant 0, répliqués ×4)
	quad("Bunker", Vector3.new(20, 7, 20), CFrame.new(60, 3.5, 60), rgb(120, 112, 104), Enum.Material.Concrete)
	quad("BunkerTrim", Vector3.new(21, 0.4, 21), CFrame.new(60, 7.2, 60), rgb(160, 120, 90), Enum.Material.Brick)
	local bAngle = math.atan(7 / 20)
	quad("BunkerRamp", Vector3.new(8, 1, math.sqrt(20 * 20 + 7 * 7)), CFrame.new(60, 3.5, 40) * CFrame.Angles(-bAngle, 0, 0), rgb(150, 142, 128), Enum.Material.Slate)
	quad("CoverWall", Vector3.new(3, 7, 12), CFrame.new(48, 3.5, 14), rgb(130, 96, 70), Enum.Material.Brick)
	quad("CoverPillar", Vector3.new(5, 12, 5), CFrame.new(14, 6, 48), rgb(150, 142, 128), Enum.Material.Cobblestone)
	quad("CoverCrates", Vector3.new(8, 4, 8), CFrame.new(44, 2, 46), rgb(150, 108, 60), Enum.Material.WoodPlanks)
	quad("CoverCratesTop", Vector3.new(4, 3, 4), CFrame.new(44, 5.5, 46), rgb(170, 124, 70), Enum.Material.WoodPlanks)
	quad("CoverLow", Vector3.new(10, 5, 3), CFrame.new(18, 2.5, 16), rgb(120, 114, 108), Enum.Material.Concrete)

	-- lave (zone mortelle)
	result.Lava = {}
	for k = 0, 3 do
		local rot = CFrame.Angles(0, math.rad(90 * k), 0)
		local lavaPart = mk(arena, {
			Name = "Lava",
			Size = Vector3.new(14, 0.3, 14),
			CFrame = CFrame.new(C) * rot * CFrame.new(28, 0.15, 28),
			Color = rgb(255, 92, 20),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 110, 30)
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = lavaPart
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Rate = 6
		bubbles.Lifetime = NumberRange.new(1, 2)
		bubbles.Speed = NumberRange.new(2, 4)
		bubbles.Size = NumberSequence.new(0.6, 0)
		bubbles.Color = ColorSequence.new(rgb(255, 180, 60), rgb(255, 80, 20))
		bubbles.LightEmission = 1
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.Parent = lavaPart
		table.insert(result.Lava, lavaPart)
		-- rebord d'avertissement
		for _, e in ipairs({ { 0, 7.4, 15.6, 0.8 }, { 0, -7.4, 15.6, 0.8 }, { 7.4, 0, 0.8, 14 }, { -7.4, 0, 0.8, 14 } }) do
			mk(arena, { Name = "LavaRim", Size = Vector3.new(e[3], 0.6, e[4]), CFrame = CFrame.new(C) * rot * CFrame.new(28 + e[1], 0.3, 28 + e[2]), Color = rgb(40, 36, 36), Material = Enum.Material.Slate })
		end
	end

	-- jump pads
	result.JumpPads = {}
	for _, pos in ipairs({ { 0, 47 }, { 0, -47 }, { 47, 0 }, { -47, 0 } }) do
		local pad = mk(arena, { Name = "JumpPad", Size = Vector3.new(7, 0.6, 7), Position = at(pos[1], 0.3, pos[2]), Color = rgb(40, 220, 255), Material = Enum.Material.Neon })
		pad:SetAttribute("JumpPad", true)
		pad:SetAttribute("Power", 78)
		billboard(pad, "▲", 80, rgb(255, 255, 255), Vector3.new(0, 3, 0))
		table.insert(result.JumpPads, pad)
	end

	-- soins (4) et orbe de rage
	result.HealthPacks = {}
	for _, pos in ipairs({ { 0, 58 }, { 0, -58 }, { 58, 0 }, { -58, 0 } }) do
		mk(arena, { Name = "PackBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = CFrame.new(at(pos[1], 0.3, pos[2])) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(240, 240, 240), Material = Enum.Material.Marble })
		local pack = mk(arena, { Name = "HealthPack", Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 2.8, 2.8), Position = at(pos[1], 3, pos[2]), Color = rgb(255, 70, 90), Material = Enum.Material.Neon, CanCollide = false })
		CollectionService:AddTag(pack, "Spin")
		billboard(pack, "+SOIN", 120, rgb(255, 120, 130), Vector3.new(0, 3, 0))
		table.insert(result.HealthPacks, pack)
	end
	mk(arena, { Name = "OrbBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7, 7), CFrame = CFrame.new(at(0, 8.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(60, 50, 70), Material = Enum.Material.Granite })
	local orb = mk(arena, { Name = "RageOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), Position = at(0, 12, 0), Color = rgb(255, 40, 40), Material = Enum.Material.Neon, CanCollide = false })
	CollectionService:AddTag(orb, "Spin")
	billboard(orb, "ORBE DE RAGE  ×1,5 dégâts", 300, rgb(255, 90, 90), Vector3.new(0, 4, 0))
	local orbLight = Instance.new("PointLight")
	orbLight.Color = rgb(255, 60, 60)
	orbLight.Range = 24
	orbLight.Brightness = 2
	orbLight.Parent = orb
	result.RageOrb = orb
	result.ArenaCenter = C

	-- torches
	for i = -3, 3 do
		for _, def in ipairs({ { i * 20, -73 }, { i * 20, 73 }, { -73, i * 20 }, { 73, i * 20 } }) do
			local torch = mk(arena, { Name = "Torch", Size = Vector3.new(1, 6, 1), Position = at(def[1], 3, def[2]), Color = rgb(70, 50, 36), Material = Enum.Material.Wood })
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 4
			fire.Parent = torch
			if (i % 2) == 0 then
				local light = Instance.new("PointLight")
				light.Range = 26
				light.Brightness = 1
				light.Color = rgb(255, 170, 90)
				light.Parent = torch
			end
		end
	end

	-- bannières d'équipe sur les murs (rouge à l'ouest/est, bleu au nord/sud)
	for i = -2, 2 do
		for _, def in ipairs({ { i * 28, -75, "E74C3C", 0 }, { i * 28, 75, "3498DB", 0 }, { -75, i * 28, "3498DB", 90 }, { 75, i * 28, "E74C3C", 90 } }) do
			local cloth = mk(arena, { Name = "Banner", Size = Vector3.new(7, 16, 0.5), CFrame = CFrame.new(at(def[1], 20, def[2])) * CFrame.Angles(0, math.rad(def[4]), 0), Color = def[3], Material = Enum.Material.Fabric })
			mk(arena, { Name = "BannerBar", Size = Vector3.new(9, 0.8, 0.9), CFrame = cloth.CFrame * CFrame.new(0, 8.4, 0), Color = rgb(255, 200, 60), Material = Enum.Material.Metal })
		end
	end
	-- anneau runique lumineux au sol et braises flottantes
	local ring = disc(arena, "RuneRing", at(0, 0, 0), 66, 0.3, 0.25, rgb(255, 150, 60), Enum.Material.Neon)
	ring.Transparency = 0.8
	ring.CanCollide = false
	ring.CanQuery = false
	local inner = disc(arena, "RuneRingInner", at(0, 0, 0), 62, 0.4, 0.3, rgb(74, 69, 64), Enum.Material.Cobblestone)
	inner.CanCollide = false
	inner.CanQuery = false
	local embers = mk(arena, { Name = "EmberSource", Size = Vector3.new(140, 1, 140), Position = at(0, 2, 0), Transparency = 1, CanCollide = false })
	local em = Instance.new("ParticleEmitter")
	em.Rate = 14
	em.Lifetime = NumberRange.new(5, 8)
	em.Speed = NumberRange.new(2, 5)
	em.EmissionDirection = Enum.NormalId.Top
	em.Size = NumberSequence.new(0.25, 0)
	em.Color = ColorSequence.new(rgb(255, 190, 90), rgb(255, 90, 30))
	em.LightEmission = 1
	em.Transparency = NumberSequence.new(0.2, 1)
	em.Parent = embers

	-- runes de l'énigme (3 dans l'arène : r4 est dans le hub, voir buildLobby)
	for _, def in ipairs({ { "r5", 60, 9.4, 60 }, { "r6", -14, 9.6, 0 } }) do
		local p = mk(arena, { Name = "Rune_" .. def[1], Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = at(def[2], def[3], def[4]), Color = rgb(255, 215, 90), Material = Enum.Material.Neon, CanCollide = false })
		CollectionService:AddTag(p, "Spin")
		table.insert(result.Runes, { Id = def[1], Part = p })
	end

	-- points d'apparition (16 sur un anneau)
	result.ArenaSpawns = {}
	for k = 0, 15 do
		local a = math.rad(k * 22.5 + 11.25)
		local sp = Instance.new("SpawnLocation")
		sp.Name = "ArenaSpawn" .. (k + 1)
		sp.Anchored = true
		sp.Neutral = true
		sp.Duration = 0
		sp.Enabled = true
		sp.CanCollide = false
		sp.CanQuery = false
		sp.Transparency = 1
		sp.Size = Vector3.new(6, 1, 6)
		sp.Position = at(math.cos(a) * 66, 0.5, math.sin(a) * 66)
		sp.Parent = arena
		table.insert(result.ArenaSpawns, sp)
	end
end

-- Construit le monde une seule fois et renvoie les références utiles aux services.
function MapBuilder.Build()
	setupLighting()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace
	local result = { Runes = {} }
	buildLobby(root, result)
	buildArena(root, result)
	return result
end

return MapBuilder

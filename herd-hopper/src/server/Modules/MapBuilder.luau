-- Construction procédurale de tout le monde : salon (lobby), piste en 4 biomes, falaises, décors,
-- portiques, ligne d'arrivée, podium et mur de lave. Uniquement des blocs et matériaux Roblox standards.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)

local State = require(script.Parent.State)
local CreatureService = require(script.Parent.CreatureService)
local DataService = require(script.Parent.DataService)

local MapBuilder = {}

local rng = Random.new(20240611)
local built = 0
local statusLabel = nil
local boardRows = {}
local nameCache = {}

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function pace()
	built = built + 1
	if built % 150 == 0 then
		task.wait()
	end
end

-- Crée un bloc ancré. o = { name, shape, collide, trans, shadow, mat }
local function P(parent, size, cf, color, material, o)
	o = o or {}
	local part = Instance.new("Part")
	part.Name = o.name or "Block"
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = o.collide == true
	part.CanTouch = false
	part.CanQuery = o.collide == true
	part.CastShadow = o.shadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.trans then
		part.Transparency = o.trans
	end
	if o.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif o.shape == "Cyl" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = parent
	pace()
	return part
end

local function mat(name)
	return Enum.Material[name]
end

local function jitter(color, amount)
	local d = (rng:NextNumber() - 0.5) * amount
	return C(
		math.clamp(math.floor(color.R * 255 + d), 0, 255),
		math.clamp(math.floor(color.G * 255 + d), 0, 255),
		math.clamp(math.floor(color.B * 255 + d), 0, 255)
	)
end

local function yaw(deg)
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- ---------------------------------------------------------------------------
-- Éclairage
-- ---------------------------------------------------------------------------

function MapBuilder.SetupLighting()
	Lighting.ClockTime = 15
	Lighting.Brightness = 2.6
	Lighting.GlobalShadows = true
	Lighting.Ambient = C(96, 96, 110)
	Lighting.OutdoorAmbient = C(124, 128, 142)
	Lighting.ColorShift_Top = C(255, 242, 214)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "HHSky"
		sky.Parent = Lighting
	end

	local atmosphere = ensure("Atmosphere", "HHAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Config.Biomes[1].atmosphere
	atmosphere.Decay = C(255, 222, 180)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "HHBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1

	local rays = ensure("SunRaysEffect", "HHRays")
	rays.Intensity = 0.12
	rays.Spread = 0.8

	local color = ensure("ColorCorrectionEffect", "HHColor")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.TintColor = Config.Biomes[1].tint
end

-- ---------------------------------------------------------------------------
-- Panneaux (SurfaceGui)
-- ---------------------------------------------------------------------------

local function makeLabel(parent, text, size, position, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color or C(255, 255, 255)
	label.Font = font or Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeBoard(parent, size, cf, canvas, bg)
	local board = P(parent, size, cf, bg or C(34, 40, 56), Enum.Material.SmoothPlastic, { name = "Board", shadow = true })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas
	gui.LightInfluence = 0
	gui.Parent = board
	return board, gui
end

-- ---------------------------------------------------------------------------
-- Salon (lobby)
-- ---------------------------------------------------------------------------

local function buildLobby(map)
	local center = Config.Lobby.Center
	local size = Config.Lobby.Size
	local top = center.Y + size.Y / 2
	State.LobbyCFrame = CFrame.new(center.X, top + 3, center.Z)

	P(map, size, CFrame.new(center), C(228, 222, 206), Enum.Material.Marble, { name = "LobbyFloor", collide = true, shadow = true })

	-- liserés néon
	local trim = C(255, 200, 70)
	local half = size.X / 2
	P(map, V(size.X, 0.4, 2), CFrame.new(center.X, top + 0.2, center.Z - half + 1), trim, Enum.Material.Neon, { name = "Trim" })
	P(map, V(size.X, 0.4, 2), CFrame.new(center.X, top + 0.2, center.Z + half - 1), trim, Enum.Material.Neon, { name = "Trim" })
	P(map, V(2, 0.4, size.Z), CFrame.new(center.X - half + 1, top + 0.2, center.Z), trim, Enum.Material.Neon, { name = "Trim" })
	P(map, V(2, 0.4, size.Z), CFrame.new(center.X + half - 1, top + 0.2, center.Z), trim, Enum.Material.Neon, { name = "Trim" })

	-- murs invisibles
	local wallH = 80
	local function barrier(sz, pos)
		P(map, sz, CFrame.new(pos), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "LobbyBarrier", collide = true, trans = 1 })
	end
	barrier(V(size.X + 4, wallH, 2), V(center.X, top + wallH / 2, center.Z - half))
	barrier(V(size.X + 4, wallH, 2), V(center.X, top + wallH / 2, center.Z + half))
	barrier(V(2, wallH, size.Z + 4), V(center.X - half, top + wallH / 2, center.Z))
	barrier(V(2, wallH, size.Z + 4), V(center.X + half, top + wallH / 2, center.Z))

	-- points d'apparition
	local offsets = { V(-12, 0, 12), V(12, 0, 12), V(-12, 0, -4), V(12, 0, -4) }
	for index, off in ipairs(offsets) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn" .. index
		spawn.Size = V(8, 1, 8)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.CanCollide = true
		spawn.Color = C(255, 200, 70)
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.2
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.CFrame = CFrame.new(center.X + off.X, top + 0.5, center.Z + off.Z)
		spawn.Parent = map
	end

	-- panneau d'état de la manche
	local _, infoGui = makeBoard(map, V(60, 26, 1), CFrame.new(center.X, top + 20, center.Z + half - 6), V(960, 416), C(28, 34, 52))
	makeLabel(infoGui, "SAUTE-TROUPEAU", UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 0, 20), 96, C(255, 214, 90))
	statusLabel = makeLabel(infoGui, "Chargement...", UDim2.new(1, -40, 0, 140), UDim2.new(0, 20, 0, 160), 72, C(255, 255, 255))
	makeLabel(infoGui, "Bondis de bête en bête. Fuis le mur de lave !", UDim2.new(1, -40, 0, 70), UDim2.new(0, 20, 0, 320), 44, C(190, 205, 235), Enum.Font.GothamMedium)

	-- panneau "comment jouer"
	local howPos = Vector3.new(center.X + half - 8, top + 16, center.Z + 10)
	local _, howGui = makeBoard(map, V(42, 30, 1), CFrame.lookAt(howPos, Vector3.new(center.X, top + 16, center.Z + 10)), V(672, 480), C(40, 46, 66))
	makeLabel(howGui, "COMMENT JOUER", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 12), 48, C(255, 214, 90))
	local how = "ESPACE / bouton : sauter de ta bête\n"
		.. "Maintiens en l'air : LASSO auto sur la bête dorée\n"
		.. "A / D ou joystick : diriger ta monture\n"
		.. "Reste dessus pour DOMPTER et marquer\n"
		.. "Enchaîne les lassos pour le COMBO\n"
		.. "Le mur de lave te rattrape : avance !"
	local howLabel = makeLabel(howGui, how, UDim2.new(1, -40, 1, -90), UDim2.new(0, 20, 0, 80), 34, C(235, 240, 255), Enum.Font.GothamMedium)
	howLabel.TextXAlignment = Enum.TextXAlignment.Left
	howLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- classement mondial
	local lbPos = Vector3.new(center.X - half + 8, top + 16, center.Z + 10)
	local _, lbGui = makeBoard(map, V(42, 30, 1), CFrame.lookAt(lbPos, Vector3.new(center.X, top + 16, center.Z + 10)), V(672, 480), C(40, 46, 66))
	makeLabel(lbGui, "TOP 10 · MEILLEUR SCORE", UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 8), 40, C(255, 214, 90))
	for i = 1, 10 do
		local row = makeLabel(lbGui, "", UDim2.new(1, -40, 0, 36), UDim2.new(0, 20, 0, 64 + (i - 1) * 40), 28, C(235, 240, 255), Enum.Font.GothamMedium)
		row.TextXAlignment = Enum.TextXAlignment.Left
		boardRows[i] = row
	end
	boardRows[1].Text = "Chargement du classement..."

	-- statues du bestiaire sur piédestaux
	for index, def in ipairs(Species.List) do
		local x = center.X + (index - 4) * 19
		local z = center.Z - half + 14
		P(map, V(15, 3, 15), CFrame.new(x, top + 1.5, z), C(70, 76, 98), Enum.Material.Slate, { name = "Pedestal", collide = true, shadow = true })
		local model, root = CreatureService.BuildModel(def, 1)
		model.Name = "Statue_" .. def.id
		local y = top + 3 + (def.flying and 9 or def.rootY)
		root.CFrame = CFrame.lookAt(V(x, y, z), V(x, y, z + 1))
		model.Parent = map
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.new(0, 160, 0, 36)
		tag.StudsOffset = V(0, 14, 0)
		tag.AlwaysOnTop = false
		tag.MaxDistance = 140
		tag.Adornee = root
		tag.Parent = root
		makeLabel(tag, def.name, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 22, C(255, 255, 255))
	end
end

function MapBuilder.SetStatus(text)
	if statusLabel then
		statusLabel.Text = text
	end
end

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	name = ok and name or ("Joueur " .. tostring(userId))
	nameCache[userId] = name
	return name
end

function MapBuilder.RefreshBoard()
	local top = DataService.GetTop(10)
	if not top then
		if boardRows[1] then
			boardRows[1].Text = "Classement indisponible"
		end
		return
	end
	for i = 1, 10 do
		local entry = top[i]
		if entry then
			boardRows[i].Text = ("%d. %s — %d"):format(i, nameFor(entry.userId), entry.score)
		else
			boardRows[i].Text = ("%d. —"):format(i)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Piste
-- ---------------------------------------------------------------------------

local function buildFloor(map)
	local finishZ = Config.Track.FinishZ
	for z = -400, finishZ + 400 - 100, 100 do
		local biome = Config.biomeAt(z + 50)
		P(map, V(200, 8, 100), CFrame.new(0, -4, z + 50), biome.ground, mat(biome.material), { name = "Floor", collide = true })
	end

	-- plaques de terrain pour casser l'uniformité
	for _ = 1, 280 do
		local z = -300 + rng:NextNumber() * (finishZ + 600)
		local biome = Config.biomeAt(z)
		local color = jitter(biome.ground, 34)
		P(
			map,
			V(14 + rng:NextNumber() * 22, 0.16, 14 + rng:NextNumber() * 22),
			CFrame.new((rng:NextNumber() * 2 - 1) * 78, 0.08, z) * yaw(rng:NextNumber() * 180),
			color,
			mat(biome.material),
			{ name = "Patch" }
		)
	end
end

local function buildCliffs(map)
	local finishZ = Config.Track.FinishZ
	for z = -400, finishZ + 420, 26 do
		local biome = Config.biomeAt(z)
		for _, side in ipairs({ -1, 1 }) do
			local w = 26 + rng:NextNumber() * 14
			local h = 30 + rng:NextNumber() * 46
			local x = side * (Config.Track.WallX + 4 + w / 2 + rng:NextNumber() * 6)
			P(
				map,
				V(w, h, 32 + rng:NextNumber() * 10),
				CFrame.new(x, h / 2 - 2, z + rng:NextNumber() * 8) * yaw(rng:NextNumber() * 20 - 10),
				jitter(biome.cliff, 30),
				mat(biome.cliffMaterial),
				{ name = "Cliff", collide = true, shadow = true }
			)
			-- deuxième rangée, plus haute
			local h2 = h + 20 + rng:NextNumber() * 30
			P(
				map,
				V(w + 14, h2, 34),
				CFrame.new(x + side * (w * 0.7), h2 / 2 - 2, z + rng:NextNumber() * 8) * yaw(rng:NextNumber() * 30 - 15),
				jitter(biome.cliff, 40),
				mat(biome.cliffMaterial),
				{ name = "CliffBack", collide = true, shadow = true }
			)
			if rng:NextNumber() < 0.25 then
				local hs = h + 10 + rng:NextNumber() * 20
				P(
					map,
					V(7, hs, 7),
					CFrame.new(side * (Config.Track.WallX + 2 + rng:NextNumber() * 6), hs / 2, z + 13) * yaw(rng:NextNumber() * 90),
					jitter(biome.cliff, 30),
					mat(biome.cliffMaterial),
					{ name = "Spire", collide = true, shadow = true }
				)
			end
		end
	end

	-- murs invisibles (la piste est un couloir)
	local length = finishZ + 1000
	local midZ = finishZ / 2 + 100
	for _, side in ipairs({ -1, 1 }) do
		P(map, V(4, 240, length), CFrame.new(side * (Config.Track.WallX + 2), 120, midZ), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "Barrier", collide = true, trans = 1 })
	end
	P(map, V(200, 240, 4), CFrame.new(0, 120, -420), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "BarrierBack", collide = true, trans = 1 })
	P(map, V(200, 240, 4), CFrame.new(0, 120, finishZ + 380), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "BarrierFront", collide = true, trans = 1 })
end

-- ---------------------------------------------------------------------------
-- Décors par biome
-- ---------------------------------------------------------------------------

local emitterBudget = 14
local lightBudget = 8

local function acacia(map, x, z)
	local r = rng:NextNumber() * 360
	P(map, V(2, 10, 2), CFrame.new(x, 5, z) * yaw(r), C(110, 80, 50), Enum.Material.Wood, { name = "Trunk" })
	P(map, V(16, 3, 16), CFrame.new(x, 11.5, z) * yaw(r), jitter(C(94, 142, 62), 24), Enum.Material.Grass, { name = "Canopy", shadow = true })
	P(map, V(10, 2.5, 10), CFrame.new(x, 14, z) * yaw(r + 20), jitter(C(104, 154, 70), 24), Enum.Material.Grass, { name = "Canopy" })
end

local function boulder(map, x, z, color, material)
	local s = 4 + rng:NextNumber() * 5
	P(map, V(s * 1.3, s, s), CFrame.new(x, s / 2 - 0.3, z) * CFrame.Angles(rng:NextNumber() * 0.4, rng:NextNumber() * 6, rng:NextNumber() * 0.4), jitter(color, 26), material, { name = "Boulder", shadow = true })
end

local function bones(map, x, z)
	local r = rng:NextNumber() * 360
	local bone = C(238, 232, 214)
	P(map, V(1.4, 1.4, 9), CFrame.new(x, 0.7, z) * yaw(r), bone, Enum.Material.SmoothPlastic, { name = "Bone" })
	for i = -1, 1 do
		P(map, V(0.9, 5, 0.9), CFrame.new(x, 2.4, z) * yaw(r) * CFrame.new(i * 2.4, 0, 0) * CFrame.Angles(0, 0, 0.35 * i), bone, Enum.Material.SmoothPlastic, { name = "Rib" })
	end
end

local function cactus(map, x, z)
	local green = jitter(C(80, 140, 70), 20)
	local r = rng:NextNumber() * 360
	P(map, V(3, 12, 3), CFrame.new(x, 6, z) * yaw(r), green, Enum.Material.Grass, { name = "Cactus", shadow = true })
	P(map, V(5, 1.6, 1.6), CFrame.new(x, 6, z) * yaw(r) * CFrame.new(3.2, 0, 0), green, Enum.Material.Grass, { name = "Arm" })
	P(map, V(1.6, 4, 1.6), CFrame.new(x, 8, z) * yaw(r) * CFrame.new(5.2, 0, 0), green, Enum.Material.Grass, { name = "Arm" })
	if rng:NextNumber() < 0.5 then
		P(map, V(5, 1.6, 1.6), CFrame.new(x, 4.4, z) * yaw(r) * CFrame.new(-3.2, 0, 0), green, Enum.Material.Grass, { name = "Arm" })
		P(map, V(1.6, 3.4, 1.6), CFrame.new(x, 6.2, z) * yaw(r) * CFrame.new(-5.2, 0, 0), green, Enum.Material.Grass, { name = "Arm" })
	end
end

local function mesa(map, x, z, color)
	local h = 10 + rng:NextNumber() * 14
	local w = 10 + rng:NextNumber() * 8
	P(map, V(w, h, w * 0.9), CFrame.new(x, h / 2, z) * yaw(rng:NextNumber() * 90), jitter(color, 26), Enum.Material.Sandstone, { name = "Mesa", shadow = true })
	P(map, V(w * 0.7, 2.5, w * 0.6), CFrame.new(x, h + 1.2, z) * yaw(rng:NextNumber() * 90), jitter(color, 30), Enum.Material.Sandstone, { name = "MesaTop" })
end

local function pine(map, x, z)
	local r = rng:NextNumber() * 360
	P(map, V(2.4, 12, 2.4), CFrame.new(x, 6, z), C(96, 70, 46), Enum.Material.Wood, { name = "Trunk" })
	P(map, V(13, 3, 13), CFrame.new(x, 10, z) * yaw(r), jitter(C(40, 96, 54), 20), Enum.Material.Grass, { name = "Leaves", shadow = true })
	P(map, V(9.5, 3, 9.5), CFrame.new(x, 13, z) * yaw(r + 25), jitter(C(46, 108, 60), 20), Enum.Material.Grass, { name = "Leaves" })
	P(map, V(6, 3, 6), CFrame.new(x, 16, z) * yaw(r + 50), jitter(C(54, 120, 66), 20), Enum.Material.Grass, { name = "Leaves" })
	P(map, V(3, 3, 3), CFrame.new(x, 18.5, z) * yaw(r), jitter(C(60, 130, 70), 20), Enum.Material.Grass, { name = "Leaves" })
end

local function mushroom(map, x, z)
	local s = 0.8 + rng:NextNumber() * 0.8
	P(map, V(3 * s, 5 * s, 3 * s), CFrame.new(x, 2.5 * s, z), C(240, 232, 214), Enum.Material.SmoothPlastic, { name = "Stem" })
	P(map, V(9 * s, 4.2 * s, 9 * s), CFrame.new(x, 6.2 * s, z), C(204, 60, 64), Enum.Material.SmoothPlastic, { name = "Cap", shape = "Ball", shadow = true })
	P(map, V(1.6 * s, 0.6, 1.6 * s), CFrame.new(x + 1.5 * s, 8.2 * s, z + 0.5 * s), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "Dot" })
end

local function obsidianSpike(map, x, z)
	local h = 10 + rng:NextNumber() * 14
	local w = 4 + rng:NextNumber() * 3
	P(map, V(w, h, w), CFrame.new(x, h / 2 - 0.5, z) * CFrame.Angles((rng:NextNumber() - 0.5) * 0.3, rng:NextNumber() * 6, (rng:NextNumber() - 0.5) * 0.3), jitter(C(34, 30, 38), 16), Enum.Material.Basalt, { name = "Spike", shadow = true })
end

local function lavaPool(map, x, z)
	local w = 8 + rng:NextNumber() * 8
	local pool = P(map, V(w, 0.3, w * 0.8), CFrame.new(x, 0.18, z) * yaw(rng:NextNumber() * 180), C(255, 100, 20), Enum.Material.Neon, { name = "LavaPool" })
	if emitterBudget > 0 and rng:NextNumber() < 0.25 then
		emitterBudget = emitterBudget - 1
		local att = Instance.new("Attachment")
		att.Parent = pool
		local em = Instance.new("ParticleEmitter")
		em.Rate = 8
		em.Lifetime = NumberRange.new(1.2, 2.2)
		em.Speed = NumberRange.new(6, 12)
		em.SpreadAngle = Vector2.new(20, 20)
		em.LightEmission = 1
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		em.Color = ColorSequence.new(C(255, 140, 40), C(255, 60, 20))
		em.Parent = att
	end
	if lightBudget > 0 and rng:NextNumber() < 0.15 then
		lightBudget = lightBudget - 1
		local light = Instance.new("PointLight")
		light.Color = C(255, 120, 40)
		light.Range = 30
		light.Brightness = 2
		light.Parent = pool
	end
end

local function crystals(map, x, z, color)
	local r = rng:NextNumber() * 360
	for i = 1, 3 + rng:NextInteger(0, 2) do
		local h = 4 + rng:NextNumber() * 9
		local ox, oz = (rng:NextNumber() - 0.5) * 6, (rng:NextNumber() - 0.5) * 6
		P(map, V(1.6 + rng:NextNumber(), h, 1.6 + rng:NextNumber()), CFrame.new(x + ox, h / 2 - 0.3, z + oz) * yaw(r + i * 40) * CFrame.Angles((rng:NextNumber() - 0.5) * 0.5, 0, (rng:NextNumber() - 0.5) * 0.5), jitter(color, 30), Enum.Material.Glass, { name = "Crystal", shadow = true })
	end
end

local function decorate(map, z, x)
	local biome = Config.biomeAt(z)
	local roll = rng:NextNumber()
	if biome.name == "SAVANE DORÉE" then
		if roll < 0.45 then
			acacia(map, x, z)
		elseif roll < 0.75 then
			boulder(map, x, z, C(150, 140, 126), Enum.Material.Rock)
		else
			bones(map, x, z)
		end
	elseif biome.name == "DÉSERT ROUGE" then
		if roll < 0.45 then
			cactus(map, x, z)
		elseif roll < 0.75 then
			mesa(map, x, z, C(200, 112, 70))
		elseif roll < 0.88 then
			bones(map, x, z)
		elseif roll < 0.94 then
			crystals(map, x, z, C(255, 150, 110))
		else
			boulder(map, x, z, C(196, 150, 110), Enum.Material.Sandstone)
		end
	elseif biome.name == "FORÊT GÉANTE" then
		if roll < 0.55 then
			pine(map, x, z)
		elseif roll < 0.85 then
			mushroom(map, x, z)
		elseif roll < 0.93 then
			crystals(map, x, z, C(120, 220, 190))
		else
			boulder(map, x, z, C(96, 108, 96), Enum.Material.Slate)
		end
	else
		if roll < 0.5 then
			obsidianSpike(map, x, z)
		elseif roll < 0.8 then
			lavaPool(map, x, z)
		else
			boulder(map, x, z, C(60, 52, 56), Enum.Material.Basalt)
		end
	end
end

local function buildProps(map)
	local finishZ = Config.Track.FinishZ
	for z = -300, finishZ + 260, 17 do
		for _, side in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.75 then
				local x = side * (Config.Track.HalfWidth + 4 + rng:NextNumber() * 14)
				decorate(map, z + (rng:NextNumber() - 0.5) * 10, x)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Portiques, départ, arrivée
-- ---------------------------------------------------------------------------

local function gate(map, z, text, color)
	local height = 46
	for _, side in ipairs({ -1, 1 }) do
		P(map, V(9, height, 9), CFrame.new(side * 72, height / 2, z), C(86, 92, 112), Enum.Material.Slate, { name = "GatePillar", collide = true, shadow = true })
	end
	local beam, gui = makeBoard(map, V(153, 12, 8), CFrame.new(0, height + 2, z), V(1530, 120), color)
	beam.Name = "GateBeam"
	beam.CanCollide = false
	beam.CanQuery = false
	makeLabel(gui, text, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 100, C(255, 255, 255))
end

local function buildGates(map)
	local finishZ = Config.Track.FinishZ

	gate(map, 0, "DÉPART", C(46, 120, 70))
	P(map, V(180, 0.3, 4), CFrame.new(0, 0.2, 0), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "StartLine" })

	for i = 2, #Config.Biomes do
		local biome = Config.Biomes[i]
		gate(map, biome.from, biome.name, C(54, 62, 90))
	end

	gate(map, finishZ, "ARRIVÉE", C(160, 40, 50))
	-- damier d'arrivée
	for col = 0, 29 do
		for row = 0, 1 do
			local dark = (col + row) % 2 == 0
			P(
				map,
				V(6, 0.3, 3),
				CFrame.new(-87 + col * 6 + 3, 0.2, finishZ - 1.5 + row * 3),
				dark and C(20, 20, 20) or C(255, 255, 255),
				Enum.Material.SmoothPlastic,
				{ name = "FinishChecker" }
			)
		end
	end

	-- confettis à l'arrivée
	for _, side in ipairs({ -1, 1 }) do
		local anchor = P(map, V(1, 1, 1), CFrame.new(side * 72, 48, finishZ + 4), C(255, 255, 255), Enum.Material.SmoothPlastic, { name = "ConfettiAnchor", trans = 1 })
		local att = Instance.new("Attachment")
		att.Parent = anchor
		local em = Instance.new("ParticleEmitter")
		em.Rate = 20
		em.Lifetime = NumberRange.new(2.5, 4)
		em.Speed = NumberRange.new(14, 26)
		em.SpreadAngle = Vector2.new(40, 40)
		em.Acceleration = V(0, -30, 0)
		em.LightEmission = 0.5
		em.Size = NumberSequence.new(0.9)
		em.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 90, 120)),
			ColorSequenceKeypoint.new(0.5, C(255, 220, 80)),
			ColorSequenceKeypoint.new(1, C(100, 220, 255)),
		})
		em.Parent = att
	end

	-- podium
	local podiumZ = finishZ + 120
	P(map, V(18, 12, 18), CFrame.new(0, 6, podiumZ), C(255, 205, 60), Enum.Material.Metal, { name = "Podium1", collide = true, shadow = true })
	P(map, V(18, 8, 18), CFrame.new(-20, 4, podiumZ), C(200, 204, 214), Enum.Material.Metal, { name = "Podium2", collide = true, shadow = true })
	P(map, V(18, 5, 18), CFrame.new(20, 2.5, podiumZ), C(190, 120, 70), Enum.Material.Metal, { name = "Podium3", collide = true, shadow = true })
end

-- ---------------------------------------------------------------------------
-- Mur de lave
-- ---------------------------------------------------------------------------

local function buildWall()
	local model = Instance.new("Model")
	model.Name = "LavaWall"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(176, 70, 16)
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Material = Enum.Material.Neon
	root.Color = C(255, 90, 20)
	root.CFrame = CFrame.new(0, 35, Config.Wall.StartZ - 8)
	root.Parent = model
	model.PrimaryPart = root

	for i = 1, 22 do
		local s = 10 + rng:NextNumber() * 12
		local ball = Instance.new("Part")
		ball.Name = "Boulder"
		ball.Shape = Enum.PartType.Ball
		ball.Size = V(s, s, s)
		ball.Anchored = false
		ball.CanCollide = false
		ball.CanTouch = false
		ball.CanQuery = false
		ball.Massless = true
		ball.CastShadow = false
		local hot = i % 3 == 0
		ball.Material = hot and Enum.Material.Neon or Enum.Material.Basalt
		ball.Color = hot and C(255, 150, 40) or C(46, 34, 34)
		local lx = (rng:NextNumber() * 2 - 1) * 84
		local ly = -28 + rng:NextNumber() * 66
		ball.CFrame = root.CFrame * CFrame.new(lx, ly, -6 - rng:NextNumber() * 4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ball
		weld.Parent = ball
		ball.Parent = model
	end

	local top = Instance.new("Attachment")
	top.Position = V(0, 36, -8)
	top.Parent = root
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Flames"
	fire.Rate = 70
	fire.Lifetime = NumberRange.new(0.8, 1.6)
	fire.Speed = NumberRange.new(18, 30)
	fire.SpreadAngle = Vector2.new(25, 25)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 0) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.Color = ColorSequence.new(C(255, 170, 50), C(255, 60, 20))
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = top

	local light = Instance.new("PointLight")
	light.Color = C(255, 120, 40)
	light.Range = 70
	light.Brightness = 3
	light.Parent = root

	model.Parent = workspace
	return root
end

-- ---------------------------------------------------------------------------
-- Point d'entrée
-- ---------------------------------------------------------------------------

-- Renvoie la pièce racine du mur de lave.
function MapBuilder.Build()
	MapBuilder.SetupLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = workspace
	State.CreaturesFolder = creatures

	local fx = Instance.new("Folder")
	fx.Name = "Fx"
	fx.Parent = workspace
	State.FxFolder = fx

	buildLobby(map)
	task.wait()
	buildFloor(map)
	task.wait()
	buildCliffs(map)
	task.wait()
	buildProps(map)
	task.wait()
	buildGates(map)
	task.wait()
	return buildWall()
end

return MapBuilder

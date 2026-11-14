-- ModuleScript : ServerScriptService/Scenery
-- Décor identitaire de chaque domaine, chemins, repères lointains et secrets. Tout en Parts de base ; les outils de construction de
-- Builder sont injectés (h.part, h.ball, h.tree, h.torch, h.sign). Chaque fonction retourne le nombre de Parts créées (budget mobile).
local CollectionService = game:GetService("CollectionService")

local Scenery = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function cyl(h, props, parent, diameter, height, pos, rotY)
	-- cylindre à axe vertical : height = hauteur, diameter = diamètre
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotY or 0, math.pi / 2)
	return h.part(props, parent)
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function emitter(parent, color, rate, speed, life, size, accel)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = accel or Vector3.new(0, 0, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 0.8
	e.Parent = parent
	return e
end

---------------------------------------------------------------- Domaine de Gus : la ferme dorée
function Scenery.gus(h, cx, cz, parent, rng)
	local n = 0
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	-- grange rouge (côté ouest, derrière la palisade)
	local bx, bz = cx - 24, cz - 24
	P({ Name = "BarnWalls", Size = Vector3.new(15, 9, 12), Position = Vector3.new(bx, 4.5, bz), Color = rgb(168, 52, 46), Material = Enum.Material.WoodPlanks })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "BarnRoof", Size = Vector3.new(8.6, 0.8, 13.5), CFrame = CFrame.new(bx + side * 3.6, 10.6, bz) * CFrame.Angles(0, 0, -side * 0.62), Color = rgb(96, 70, 52), Material = Enum.Material.Wood })
	end
	P({ Name = "BarnDoor", Size = Vector3.new(5, 6.4, 0.5), Position = Vector3.new(bx, 3.2, bz + 6.2), Color = rgb(235, 225, 205), Material = Enum.Material.Wood })
	P({ Name = "BarnCross", Size = Vector3.new(5.6, 0.5, 0.3), CFrame = CFrame.new(bx, 3.2, bz + 6.5) * CFrame.Angles(0, 0, 0.9), Color = rgb(168, 52, 46), CanCollide = false })
	-- moulin à vent
	local mx, mz = cx + 26, cz - 22
	cyl(h, { Name = "MillTower", Color = rgb(226, 210, 178), Material = Enum.Material.Brick }, parent, 6.5, 15, Vector3.new(mx, 7.5, mz))
	n += 1
	cyl(h, { Name = "MillCap", Color = rgb(150, 70, 52), Material = Enum.Material.Wood }, parent, 7.4, 2.4, Vector3.new(mx, 16, mz))
	n += 1
	for k = 0, 3 do
		P({ Name = "MillBlade", Size = Vector3.new(1.6, 11, 0.4), CFrame = CFrame.new(mx, 14, mz + 3.4) * CFrame.Angles(0, 0, k * math.pi / 2 + 0.4) * CFrame.new(0, 5.5, 0), Color = rgb(245, 235, 215), Material = Enum.Material.Fabric, CanCollide = false })
	end
	-- champs de blé (rangées) et bottes de foin
	for r = 0, 5 do
		P({ Name = "Wheat", Size = Vector3.new(30, 2.6, 1.8), Position = Vector3.new(cx + 2, 1.3, cz - 40 + r * 3.2), Color = rgb(226 - (r % 2) * 14, 188 - (r % 2) * 10, 70), Material = Enum.Material.Grass, CanCollide = false })
	end
	for k = 1, 6 do
		n += 1
		cyl(h, { Name = "HayBale", Color = rgb(226, 196, 98), Material = Enum.Material.Fabric }, parent, 3.6, 3.2, Vector3.new(cx - 8 + k * 4.2, 1.8, cz - 12 + (k % 2) * 3), rng:NextNumber(0, 3))
	end
	-- clôture ouest, épouvantail
	for k = 0, 8 do
		P({ Name = "FencePost", Size = Vector3.new(0.7, 3.2, 0.7), Position = Vector3.new(cx - 40, 1.6, cz - 4 + k * 3.4), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
	end
	P({ Name = "FenceRail", Size = Vector3.new(0.4, 0.5, 28), Position = Vector3.new(cx - 40, 2.3, cz + 10), Color = rgb(140, 104, 70), Material = Enum.Material.Wood })
	P({ Name = "ScarecrowPole", Size = Vector3.new(0.5, 5, 0.5), Position = Vector3.new(cx + 12, 2.5, cz - 32), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
	P({ Name = "ScarecrowArms", Size = Vector3.new(4.6, 0.5, 0.5), Position = Vector3.new(cx + 12, 4, cz - 32), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
	n += 1
	h.ball({ Name = "ScarecrowHead", Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(cx + 12, 5.6, cz - 32), Color = rgb(235, 200, 120) }, parent)
	P({ Name = "ScarecrowHat", Size = Vector3.new(2.2, 0.3, 2.2), Position = Vector3.new(cx + 12, 6.4, cz - 32), Color = rgb(150, 110, 60), Material = Enum.Material.Fabric, CanCollide = false })
	-- collines douces et lumière chaude
	for k = 1, 3 do
		n += 1
		h.ball({ Name = "FarmHill", Size = Vector3.new(60, 40, 60), Position = Vector3.new(cx - 40 + k * 40, -12, cz - 78), Color = rgb(120, 168, 70), Material = Enum.Material.Grass }, parent)
	end
	local lamp = P({ Name = "FarmLight", Size = Vector3.new(0.6, 0.6, 0.6), Position = Vector3.new(cx, 22, cz - 8), Transparency = 1, CanCollide = false })
	light(lamp, rgb(255, 214, 140), 60, 0.7)
	return n
end

---------------------------------------------------------------- Domaine de Mara : les bois ensorcelés
function Scenery.mara(h, cx, cz, parent, rng)
	local n = 0
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	-- arbres morts tordus
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(26, 46)
		local x, z = cx + math.sin(a) * r, cz - math.abs(math.cos(a)) * r * 0.9 - 6
		local s = rng:NextNumber(0.9, 1.5)
		P({ Name = "DeadTrunk", Size = Vector3.new(1.6 * s, 11 * s, 1.6 * s), CFrame = CFrame.new(x, 5.5 * s, z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.12, 0.12)), Color = rgb(52, 40, 52), Material = Enum.Material.Slate })
		for b = 1, 3 do
			P({ Name = "DeadBranch", Size = Vector3.new(0.7, 5.5 * s, 0.7), CFrame = CFrame.new(x, (6 + b * 1.6) * s, z) * CFrame.Angles(0, b * 2.1, 0.9 + b * 0.1) * CFrame.new(0, 2.4 * s, 0), Color = rgb(52, 40, 52), Material = Enum.Material.Slate, CanCollide = false })
		end
	end
	-- champignons lumineux (quelques-uns éclairent)
	local colors = { rgb(190, 110, 255), rgb(90, 235, 235), rgb(255, 110, 200) }
	for k = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 40)
		local x, z = cx + math.sin(a) * r, cz - math.abs(math.cos(a)) * r - 4
		local s = rng:NextNumber(0.8, 1.8)
		local col = colors[(k % #colors) + 1]
		P({ Name = "MushroomStem", Size = Vector3.new(0.7 * s, 1.8 * s, 0.7 * s), Position = Vector3.new(x, 0.9 * s, z), Color = rgb(230, 225, 235), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		n += 1
		local cap = h.ball({ Name = "MushroomCap", Size = Vector3.new(2.6 * s, 1.6 * s, 2.6 * s), Position = Vector3.new(x, 2 * s, z), Color = col, Material = Enum.Material.Neon }, parent)
		if k % 3 == 0 then
			light(cap, col, 14, 0.9)
		end
	end
	-- cimetière
	for k = 1, 10 do
		local x, z = cx - 38 + (k % 5) * 5, cz + 6 + math.floor(k / 5) * 6
		P({ Name = "Tombstone", Size = Vector3.new(2.4, 3.4, 0.7), CFrame = CFrame.new(x, 1.7, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.08, 0.08)), Color = rgb(120, 118, 130), Material = Enum.Material.Slate })
	end
	-- mare violette et lucioles
	n += 1
	local pond = cyl(h, { Name = "WitchPond", Color = rgb(150, 70, 230), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false }, parent, 16, 0.3, Vector3.new(cx + 26, 0.25, cz + 4))
	emitter(pond, rgb(220, 255, 140), 6, 2, 3, 0.35, Vector3.new(0, 0.6, 0))
	light(pond, rgb(170, 90, 255), 28, 1.2)
	-- lanterne-lune sur un grand mât
	P({ Name = "MoonPost", Size = Vector3.new(1, 24, 1), Position = Vector3.new(cx - 2, 12, cz - 48), Color = rgb(60, 48, 66), Material = Enum.Material.Metal })
	n += 1
	local moon = h.ball({ Name = "MoonLantern", Size = Vector3.new(6, 6, 6), Position = Vector3.new(cx - 2, 26, cz - 48), Color = rgb(235, 225, 255), Material = Enum.Material.Neon }, parent)
	light(moon, rgb(190, 170, 255), 60, 1.4)
	return n
end

---------------------------------------------------------------- Domaine de Zed : la citadelle de lave
function Scenery.zed(h, cx, cz, parent, rng)
	local n = 0
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	-- aiguilles d'obsidienne
	for k = 1, 11 do
		local a = k / 11 * math.pi * 1.3 - 0.15 * math.pi
		local r = rng:NextNumber(32, 52)
		local x, z = cx + math.cos(a) * r, cz - math.sin(a) * r
		local hgt = rng:NextNumber(10, 24)
		P({ Name = "ObsidianSpire", Size = Vector3.new(rng:NextNumber(3, 5), hgt, rng:NextNumber(3, 5)), CFrame = CFrame.new(x, hgt / 2, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 3), rng:NextNumber(-0.12, 0.12)), Color = rgb(36, 32, 44), Material = Enum.Material.Slate })
	end
	-- lacs de lave (braises, lueur)
	for k = 1, 4 do
		local x, z = cx - 30 + k * 15, cz - 16 - (k % 2) * 14
		n += 1
		local lava = cyl(h, { Name = "LavaPool", Color = rgb(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false }, parent, rng:NextNumber(8, 13), 0.3, Vector3.new(x, 0.22, z))
		light(lava, rgb(255, 120, 40), 26, 1.5)
		if k == 2 then
			emitter(lava, rgb(255, 160, 60), 12, 8, 2, 0.5, Vector3.new(0, 4, 0))
		end
	end
	-- tour sombre aux anneaux cyan
	n += 1
	cyl(h, { Name = "TowerBase", Color = rgb(44, 40, 54), Material = Enum.Material.Slate }, parent, 9, 22, Vector3.new(cx + 30, 11, cz - 36))
	for k = 1, 3 do
		n += 1
		local ring = cyl(h, { Name = "TowerRing", Color = rgb(60, 230, 255), Material = Enum.Material.Neon, CanCollide = false }, parent, 9.6, 0.5, Vector3.new(cx + 30, 5 + k * 5.5, cz - 36))
		if k == 3 then
			light(ring, rgb(60, 230, 255), 40, 1.5)
		end
	end
	-- passerelle d'acier
	for k = 0, 5 do
		P({ Name = "BridgePlank", Size = Vector3.new(4, 0.4, 2.2), Position = Vector3.new(cx - 18 + k * 2.5, 0.9, cz + 4), Color = rgb(70, 72, 80), Material = Enum.Material.DiamondPlate })
	end
	return n
end

---------------------------------------------------------------- Chemins en pas japonais
function Scenery.paths(h, parent, cfg)
	local n = 0
	local function stones(ax, az, bx, bz, step)
		local dx, dz = bx - ax, bz - az
		local len = math.sqrt(dx * dx + dz * dz)
		local count = math.floor(len / step)
		for k = 0, count do
			local t = k / math.max(count, 1)
			n += 1
			cyl(h, { Name = "PathStone", Color = rgb(196, 180, 150), Material = Enum.Material.Cobblestone, CanCollide = false }, parent, 4.4, 0.25, Vector3.new(ax + dx * t, 0.18, az + dz * t))
		end
	end
	for i = 1, #cfg.RIVALS do
		local cx, cz = cfg.rivalCenter(i)
		stones(cx * 0.5, -78, cx, cz + 24, 7)
	end
	local r = cfg.Map.plotRadius - 30
	for k = 0, 29 do
		local a = k / 30 * math.pi * 2
		n += 1
		cyl(h, { Name = "RingStone", Color = rgb(190, 176, 148), Material = Enum.Material.Cobblestone, CanCollide = false }, parent, 5.2, 0.25, Vector3.new(math.sin(a) * r, 0.18, math.cos(a) * r), a)
	end
	return n
end

---------------------------------------------------------------- Repères lointains (visibles de loin pour s'orienter)
function Scenery.landmarks(h, parent, rng)
	local n = 0
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	-- Grand Arbre (sud-ouest)
	P({ Name = "GreatTreeTrunk", Size = Vector3.new(10, 46, 10), Position = Vector3.new(-300, 23, 220), Color = rgb(105, 74, 48), Material = Enum.Material.Wood })
	for k = 1, 5 do
		n += 1
		h.ball({ Name = "GreatTreeLeaves", Size = Vector3.new(52 - k * 4, 40 - k * 3, 52 - k * 4), Position = Vector3.new(-300 + math.sin(k * 1.7) * 12, 52 + (k % 3) * 4, 220 + math.cos(k * 1.7) * 12), Color = rgb(70 + k * 5, 150, 82), Material = Enum.Material.Grass }, parent)
	end
	-- Tour de guet (sud-est)
	for _, c in ipairs({ { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }) do
		P({ Name = "WatchLeg", Size = Vector3.new(1.4, 30, 1.4), Position = Vector3.new(300 + c[1], 15, 230 + c[2]), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
	end
	P({ Name = "WatchDeck", Size = Vector3.new(15, 1.2, 15), Position = Vector3.new(300, 30, 230), Color = rgb(140, 104, 70), Material = Enum.Material.WoodPlanks })
	P({ Name = "WatchRoof", Size = Vector3.new(17, 1, 17), Position = Vector3.new(300, 38, 230), Color = rgb(150, 70, 52), Material = Enum.Material.Wood })
	for _, c in ipairs({ { -7, -7 }, { 7, -7 }, { -7, 7 }, { 7, 7 } }) do
		P({ Name = "WatchPost", Size = Vector3.new(0.8, 8, 0.8), Position = Vector3.new(300 + c[1], 34, 230 + c[2]), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
	end
	local fire = P({ Name = "WatchBeacon", Size = Vector3.new(2, 1, 2), Position = Vector3.new(300, 31.2, 230), Color = rgb(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
	light(fire, rgb(255, 170, 80), 50, 1.6)
	-- Arche de pierre (est)
	for _, sx in ipairs({ -9, 9 }) do
		P({ Name = "ArchPillar", Size = Vector3.new(6, 26, 6), Position = Vector3.new(430 + sx, 13, 20), Color = rgb(140, 138, 148), Material = Enum.Material.Slate })
	end
	P({ Name = "ArchTop", Size = Vector3.new(26, 6, 7), Position = Vector3.new(430, 28, 20), Color = rgb(150, 148, 158), Material = Enum.Material.Slate })
	-- Obélisque doré (ouest)
	P({ Name = "ObeliskBase", Size = Vector3.new(10, 3, 10), Position = Vector3.new(-430, 1.5, -20), Color = rgb(150, 146, 140), Material = Enum.Material.Marble })
	P({ Name = "Obelisk", Size = Vector3.new(5, 34, 5), Position = Vector3.new(-430, 20, -20), Color = rgb(255, 214, 120), Material = Enum.Material.Metal })
	local tip = h.ball({ Name = "ObeliskTip", Size = Vector3.new(4, 4, 4), Position = Vector3.new(-430, 38.5, -20), Color = rgb(255, 240, 180), Material = Enum.Material.Neon }, parent)
	n += 1
	light(tip, rgb(255, 224, 140), 70, 1.6)
	return n
end

---------------------------------------------------------------- Relief : monticules et forêt périphérique
function Scenery.relief(h, parent, rng, cfg)
	local n = 0
	local half = cfg.Map.groundSize / 2
	local function clear(x, z)
		for i = 1, #cfg.RIVALS do
			local cx, cz = cfg.rivalCenter(i)
			if math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) < 110 then
				return false
			end
		end
		for _, sct in ipairs(cfg.SECRETS) do
			if math.sqrt((x - sct.x) ^ 2 + (z - sct.z) ^ 2) < 40 then
				return false
			end
		end
		return math.sqrt(x * x + z * z) > 270
	end
	for _ = 1, 34 do -- monticules praticables
		local x, z = rng:NextNumber(-half + 80, half - 80), rng:NextNumber(-half + 80, half - 80)
		if clear(x, z) then
			local sz = rng:NextNumber(36, 90)
			n += 1
			local m = h.ball({ Name = "Mound", Size = Vector3.new(sz, sz * 0.5, sz), Position = Vector3.new(x, -sz * 0.12, z), Color = Color3.fromRGB(86 + rng:NextInteger(0, 18), 150 + rng:NextInteger(0, 16), 80), Material = Enum.Material.Grass }, parent)
			m.CanCollide = true
		end
	end
	for _ = 1, 46 do -- forêt périphérique
		local x, z = rng:NextNumber(-half + 40, half - 40), rng:NextNumber(-half + 40, half - 40)
		if clear(x, z) then
			n += 4
			h.tree(Vector3.new(x, 0, z), parent, rng)
		end
	end
	return n
end

---------------------------------------------------------------- Secrets : un sanctuaire par domaine, fouillable une fois par jour
function Scenery.secrets(h, parent, cfg)
	local n = 0
	for _, sct in ipairs(cfg.SECRETS) do
		local base = Vector3.new(sct.x, 0, sct.z)
		n += 3
		cyl(h, { Name = "ShrineBase", Color = rgb(150, 146, 140), Material = Enum.Material.Marble }, parent, 12, 1.2, base + Vector3.new(0, 0.6, 0))
		h.part({ Name = "ShrinePillar", Size = Vector3.new(2.4, 7, 2.4), Position = base + Vector3.new(0, 4.7, 0), Color = rgb(190, 184, 176), Material = Enum.Material.Marble }, parent)
		local gem = h.ball({ Name = "Secret_" .. sct.id, Size = Vector3.new(3, 3, 3), Position = base + Vector3.new(0, 9.4, 0), Color = rgb(255, 214, 90), Material = Enum.Material.Neon }, parent)
		light(gem, rgb(255, 214, 120), 34, 1.4)
		emitter(gem, rgb(255, 230, 140), 5, 2, 2, 0.4, Vector3.new(0, 1, 0))
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Fouiller"
		pr.ObjectText = sct.emoji .. " " .. sct.name
		pr.HoldDuration = 1
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr:SetAttribute("SecretId", sct.id)
		CollectionService:AddTag(pr, "SecretPrompt")
		pr.Parent = gem
	end
	return n
end

return Scenery

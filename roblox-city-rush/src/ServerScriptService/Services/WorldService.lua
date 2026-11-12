--[[
	WorldService : génère toute la ville avec des Parts natives Roblox (aucun asset externe).
	Grille 5x5 de blocs, routes, bâtiments par quartier, props destructibles, lampadaires,
	points d'intérêt (missions, concession, police...), éclairage et cycle jour/nuit.
	Appel : World.build() (bloquant, yield) puis World.* pour lire les points d'intérêt.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local VehicleBuilder = require(script.Parent.VehicleBuilder)

local World = {}

local M = Config.Map
local SW_H = M.SidewalkHeight -- hauteur du dessus des trottoirs
local ROAD_H = M.RoadHeight
local rng = Random.new(1337)

-- Données exposées
World.ParkingSpots = {} -- CFrame (position au sol + orientation le long de la route)
World.DeliveryPoints = {} -- Vector3
World.TaxiStops = {} -- Vector3
World.StarSpots = {} -- Vector3
World.RaceCircuit = {} -- Vector3
World.RoadNodes = {} -- [ix][iz] = Vector3
World.Spawn = CFrame.new(0, 3, 0)
World.PolicePoint = CFrame.new(0, 3, 372)
World.Hideout = Vector3.new(0, 0.5, -400)
World.Bank = Vector3.new(0, 0.5, -200)
World.Ready = false

local root, fRoads, fBuild, fBands, fProps, fBreak, fDecor
local made = 0

local function mk(parent, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	if typeof(cf) == "Vector3" then
		p.CFrame = CFrame.new(cf)
	else
		p.CFrame = cf
	end
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local tag
	if extra then
		for k, v in pairs(extra) do
			if k == "Tag" then
				tag = v
			else
				p[k] = v
			end
		end
	end
	p.Parent = parent
	if tag then
		CollectionService:AddTag(p, tag)
	end
	made += 1
	if made % 350 == 0 then
		task.wait()
	end
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local NOCOLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function sign(part, text, offsetY, width, color)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 260, 56)
	bb.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 320
	bb.Parent = part
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = rgb(20, 22, 30)
	tl.BackgroundTransparency = 0.15
	tl.Text = text
	tl.Font = Enum.Font.GothamBlack
	tl.TextSize = 26
	tl.TextColor3 = color or rgb(255, 255, 255)
	tl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = tl
	local st = Instance.new("UIStroke")
	st.Color = color or rgb(255, 196, 0)
	st.Thickness = 2
	st.Parent = tl
end

-- Pastille lumineuse interactive (le serveur y attache les ProximityPrompt selon le tag/attribut)
local function hubPad(pos, color, tag, attrs, label)
	local pad = mk(fDecor, Vector3.new(0.5, 12, 12), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Transparency = 0.25,
		Tag = tag,
	})
	pad.Name = "Hub_" .. tag
	for k, v in pairs(attrs or {}) do
		pad:SetAttribute(k, v)
	end
	local beam = mk(fDecor, Vector3.new(60, 3, 3), CFrame.new(pos + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.8,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	beam.Name = "HubBeam"
	if label then
		sign(pad, label, 9, 300, color)
	end
	return pad
end

-- ====================================================================
-- Briques de décor
-- ====================================================================
local function tree(x, z, big)
	local h = big and rng:NextNumber(10, 14) or rng:NextNumber(7, 10)
	mk(fProps, Vector3.new(1.6, h, 1.6), Vector3.new(x, SW_H + h / 2, z), rgb(110, 78, 50), Enum.Material.Wood)
	local d = h * 1.1 + 2
	mk(fProps, Vector3.new(d, d, d), Vector3.new(x, SW_H + h + d * 0.25, z), rgb(rng:NextInteger(50, 80), rng:NextInteger(130, 165), rng:NextInteger(50, 80)), Enum.Material.Grass, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CastShadow = false,
	})
end

local function palm(x, z)
	local h = rng:NextNumber(14, 18)
	mk(fProps, Vector3.new(1.4, h, 1.4), Vector3.new(x, 0.3 + h / 2, z), rgb(150, 110, 70), Enum.Material.Wood)
	for k = 1, 5 do
		local a = k * math.pi * 2 / 5
		mk(fProps, Vector3.new(9, 0.4, 2.2), CFrame.new(x + math.cos(a) * 3.5, h + 0.2, z + math.sin(a) * 3.5) * CFrame.Angles(0, -a, math.rad(-18)), rgb(60, 150, 70), Enum.Material.Grass, NOCOLLIDE)
	end
end

local function lamp(x, z, rotY)
	mk(fProps, Vector3.new(0.7, 14, 0.7), Vector3.new(x, SW_H + 7, z), rgb(60, 62, 70), Enum.Material.Metal)
	mk(fProps, Vector3.new(2.4, 0.6, 1.4), CFrame.new(x, SW_H + 14, z) * CFrame.Angles(0, rotY, 0), rgb(255, 235, 170), Enum.Material.Neon, {
		Tag = "LampHead",
		CanCollide = false,
		CastShadow = false,
	})
end

local function breakable(kind, x, z)
	local cf = CFrame.new(x, SW_H, z)
	local p
	if kind == "bench" then
		p = mk(fBreak, Vector3.new(6, 2.2, 1.8), cf * CFrame.new(0, 1.1, 0), rgb(120, 80, 50), Enum.Material.Wood)
	elseif kind == "hydrant" then
		p = mk(fBreak, Vector3.new(1.6, 2.8, 1.6), cf * CFrame.new(0, 1.4, 0), rgb(220, 50, 50), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		p.CFrame = cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	elseif kind == "bin" then
		p = mk(fBreak, Vector3.new(2.6, 2.2, 2.2), cf * CFrame.new(0, 1.3, 0), rgb(70, 130, 90), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		p.CFrame = cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	elseif kind == "crate" then
		p = mk(fBreak, Vector3.new(3.2, 3.2, 3.2), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rgb(176, 130, 80), Enum.Material.Wood)
	else -- mailbox
		p = mk(fBreak, Vector3.new(1.6, 3, 1.6), cf * CFrame.new(0, 1.5, 0), rgb(50, 90, 200), Enum.Material.Metal)
	end
	p.Name = kind
	return p
end

local function bandedTower(cx, cz, w, d, h, color, glass)
	mk(fBuild, Vector3.new(w, h, d), Vector3.new(cx, SW_H + h / 2, cz), color, Enum.Material.Concrete)
	local n = math.floor((h - 4) / 6)
	for k = 0, n - 1 do
		mk(fBands, Vector3.new(w + 0.5, 3.4, d + 0.5), Vector3.new(cx, SW_H + 4.5 + k * 6, cz), glass, Enum.Material.Glass, {
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Tag = "Lit",
		})
	end
	mk(fBuild, Vector3.new(w + 2, 1.2, d + 2), Vector3.new(cx, SW_H + h + 0.6, cz), rgb(70, 72, 80), Enum.Material.Concrete)
	if rng:NextNumber() < 0.5 then
		mk(fBuild, Vector3.new(0.8, 14, 0.8), Vector3.new(cx, SW_H + h + 8, cz), rgb(200, 200, 205), Enum.Material.Metal)
		mk(fBuild, Vector3.new(1.4, 1.4, 1.4), Vector3.new(cx, SW_H + h + 15, cz), rgb(255, 60, 60), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
end

local function house(cx, cz, faceDir, colorIdx)
	local pastel = {
		rgb(236, 214, 170), rgb(190, 220, 200), rgb(230, 190, 190), rgb(200, 205, 235),
		rgb(240, 230, 190), rgb(210, 190, 160),
	}
	local c = pastel[(colorIdx % #pastel) + 1]
	local w, h, d = 30, 14, 24
	mk(fBuild, Vector3.new(w, h, d), Vector3.new(cx, SW_H + h / 2, cz), c, Enum.Material.Brick)
	mk(fBuild, Vector3.new(w + 3, 1.2, d + 3), CFrame.new(cx, SW_H + h + 0.6, cz), rgb(150, 70, 60), Enum.Material.Slate)
	mk(fBuild, Vector3.new(w - 2, 3, d - 2), CFrame.new(cx, SW_H + h + 2.4, cz), rgb(150, 70, 60), Enum.Material.Slate)
	mk(fBuild, Vector3.new(3, 5, 3), Vector3.new(cx + 9, SW_H + h + 4, cz - 4), rgb(120, 60, 50), Enum.Material.Brick)
	-- face avant : +/- Z
	local fz = cz + faceDir * (d / 2)
	mk(fBuild, Vector3.new(4, 7.5, 0.5), Vector3.new(cx, SW_H + 3.75, fz + faceDir * 0.1), rgb(90, 60, 40), Enum.Material.Wood, { CanCollide = false })
	for _, sx in ipairs({ -9, 9 }) do
		mk(fBands, Vector3.new(5, 4, 0.4), Vector3.new(cx + sx, SW_H + 7, fz + faceDir * 0.1), rgb(120, 170, 210), Enum.Material.Glass, {
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Tag = "Lit",
		})
	end
	-- allée + point de livraison
	mk(fBuild, Vector3.new(5, 0.1, 20), Vector3.new(cx, SW_H + 0.05, fz + faceDir * 11), rgb(190, 185, 175), Enum.Material.Concrete, { CanCollide = false })
	table.insert(World.DeliveryPoints, Vector3.new(cx, SW_H, fz + faceDir * 21))
	-- clôture basse (destructible)
	breakable("mailbox", cx + 6, fz + faceDir * 21)
end

local function warehouse(cx, cz, w, d, h, color)
	mk(fBuild, Vector3.new(w, h, d), Vector3.new(cx, SW_H + h / 2, cz), color, Enum.Material.Metal)
	mk(fBuild, Vector3.new(w + 1.5, 1, d + 1.5), Vector3.new(cx, SW_H + h + 0.5, cz), rgb(90, 92, 98), Enum.Material.Metal)
	mk(fBuild, Vector3.new(w * 0.25, h * 0.7, 0.6), Vector3.new(cx, SW_H + h * 0.35, cz - d / 2 - 0.1), rgb(60, 62, 68), Enum.Material.Metal, { CanCollide = false })
	for k = -1, 1, 2 do
		mk(fBands, Vector3.new(w * 0.18, 2, d + 0.5), Vector3.new(cx + k * w * 0.32, SW_H + h - 3, cz), rgb(100, 140, 170), Enum.Material.Glass, {
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Tag = "Lit",
		})
	end
end

local function container(x, z, rotY, level)
	local cols = { rgb(200, 60, 50), rgb(50, 110, 190), rgb(230, 170, 40), rgb(60, 150, 90), rgb(120, 120, 130) }
	mk(fBuild, Vector3.new(7, 7, 24), CFrame.new(x, SW_H + 3.5 + (level or 0) * 7, z) * CFrame.Angles(0, rotY, 0), cols[rng:NextInteger(1, #cols)], Enum.Material.CorrodedMetal)
end

-- ====================================================================
-- Routes et blocs
-- ====================================================================
local function buildGroundAndRoads()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(4000, 16, 4000), Enum.Material.Water)

	mk(fRoads, Vector3.new(M.GroundHalf * 2, 6, M.GroundHalf * 2), Vector3.new(0, -3, 0), rgb(96, 150, 78), Enum.Material.Grass).Name = "Ground"

	local span = 1040
	local asphalt = rgb(58, 60, 66)
	for k = 0, 5 do
		local c = -500 + M.Pitch * k
		mk(fRoads, Vector3.new(M.RoadWidth, 0.6, span), Vector3.new(c, 0, 0), asphalt, Enum.Material.Asphalt)
		mk(fRoads, Vector3.new(span, 0.6, M.RoadWidth), Vector3.new(0, 0, c), asphalt, Enum.Material.Asphalt)
	end
	-- marquage central pointillé (on évite les intersections)
	for k = 0, 5 do
		local c = -500 + M.Pitch * k
		local t = -500
		while t < 500 do
			local nearNode = false
			for n = 0, 5 do
				if math.abs(t - (-500 + M.Pitch * n)) < 30 then
					nearNode = true
					break
				end
			end
			if not nearNode then
				mk(fDecor, Vector3.new(0.8, 0.1, 12), Vector3.new(c, 0.35, t), rgb(240, 200, 60), Enum.Material.SmoothPlastic, NOCOLLIDE)
				mk(fDecor, Vector3.new(12, 0.1, 0.8), Vector3.new(t, 0.35, c), rgb(240, 200, 60), Enum.Material.SmoothPlastic, NOCOLLIDE)
			end
			t += 32
		end
	end
	-- passages piétons au centre
	for _, ix in ipairs({ 2, 3 }) do
		for _, iz in ipairs({ 2, 3 }) do
			local p = World.RoadNodes[ix][iz]
			for s = -1, 1, 2 do
				for k = -3, 3 do
					mk(fDecor, Vector3.new(1.6, 0.1, 9), Vector3.new(p.X + k * 3.8, 0.35, p.Z + s * 26), rgb(240, 240, 240), Enum.Material.SmoothPlastic, NOCOLLIDE)
					mk(fDecor, Vector3.new(9, 0.1, 1.6), Vector3.new(p.X + s * 26, 0.35, p.Z + k * 3.8), rgb(240, 240, 240), Enum.Material.SmoothPlastic, NOCOLLIDE)
				end
			end
		end
	end

	-- digue périphérique visible + mur invisible haut
	local H = M.GroundHalf
	local gapZ0, gapZ1 = 40, 150 -- ouverture pour la jetée (côté est)
	local function wall(size, pos)
		mk(fDecor, size, pos, rgb(150, 152, 158), Enum.Material.Concrete)
		mk(fDecor, Vector3.new(size.X, 60, size.Z), pos + Vector3.new(0, 33, 0), rgb(255, 255, 255), Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
	end
	wall(Vector3.new(H * 2, 5, 4), Vector3.new(0, 2.5, -H + 2))
	wall(Vector3.new(H * 2, 5, 4), Vector3.new(0, 2.5, H - 2))
	wall(Vector3.new(4, 5, H * 2), Vector3.new(-H + 2, 2.5, 0))
	-- côté est en deux morceaux (jetée au milieu)
	wall(Vector3.new(4, 5, (H + gapZ0) - 0), Vector3.new(H - 2, 2.5, -H + (H + gapZ0) / 2))
	wall(Vector3.new(4, 5, H - gapZ1), Vector3.new(H - 2, 2.5, gapZ1 + (H - gapZ1) / 2))
end

local function buildBlockSlab(i, j, material, color)
	local c = Config.blockCenter(i, j)
	mk(fRoads, Vector3.new(M.BlockSize, SW_H, M.BlockSize), Vector3.new(c.X, SW_H / 2, c.Z), color or rgb(176, 176, 180), material or Enum.Material.Concrete).Name = ("Block_%d_%d"):format(i, j)
	-- lampadaires sur les bords
	for s = -1, 1, 2 do
		lamp(c.X + s * 76, c.Z - 40, 0)
		lamp(c.X + s * 76, c.Z + 40, 0)
		lamp(c.X - 40, c.Z + s * 76, math.pi / 2)
		lamp(c.X + 40, c.Z + s * 76, math.pi / 2)
	end
	-- mobilier urbain destructible
	local kinds = { "bench", "hydrant", "bin", "crate", "mailbox" }
	for _ = 1, 4 do
		local side = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-60, 60)
		local x, z
		if side == 1 then
			x, z = c.X + t, c.Z - 74
		elseif side == 2 then
			x, z = c.X + t, c.Z + 74
		elseif side == 3 then
			x, z = c.X - 74, c.Z + t
		else
			x, z = c.X + 74, c.Z + t
		end
		breakable(kinds[rng:NextInteger(1, #kinds)], x, z)
	end
	return c
end

-- ====================================================================
-- Quartiers
-- ====================================================================
local function districtDowntown(i, j)
	local c = buildBlockSlab(i, j)
	local cols = { rgb(120, 130, 145), rgb(150, 155, 165), rgb(95, 105, 120), rgb(170, 150, 130), rgb(80, 90, 110) }
	local glass = { rgb(60, 100, 140), rgb(40, 70, 100), rgb(70, 120, 120) }
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local h = rng:NextInteger(40, 150)
			if not (i == 3 and j == 2 and sz == 1) then -- la banque occupe le côté sud de ce bloc
			bandedTower(c.X + sx * 38, c.Z + sz * 38, rng:NextInteger(44, 56), rng:NextInteger(44, 56), h, cols[rng:NextInteger(1, #cols)], glass[rng:NextInteger(1, #glass)])
			end
		end
	end
	return c
end

local function districtResidential(i, j)
	local c = buildBlockSlab(i, j)
	local k = 0
	for _, row in ipairs({ -1, 1 }) do
		for col = -1, 1 do
			k += 1
			local hx, hz = c.X + col * 50, c.Z + row * 38
			if not (i == 1 and j == 3 and row == -1 and col == 1) then -- emplacement de la pizzeria
				house(hx, hz, row, k + i + j)
				tree(hx + 20 * (col == 0 and 1 or -col), hz + row * 4, false)
			end
		end
	end
	return c
end

local function districtIndustrial(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(150, 150, 150))
	warehouse(c.X - 30, c.Z - 38, 70, 50, 24, rgb(130, 140, 150))
	warehouse(c.X + 36, c.Z + 38, 60, 50, 20, rgb(140, 120, 100))
	for k = 0, 2 do
		container(c.X + 50, c.Z - 40 + k * 8, math.pi / 2, k % 2)
		container(c.X - 52, c.Z + 38 + (k - 1) * 8, math.pi / 2, 0)
	end
	for _ = 1, 6 do
		breakable("crate", c.X + rng:NextNumber(-60, 60), c.Z + rng:NextNumber(-8, 8))
	end
	return c
end

local function districtBeach(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Sand, rgb(231, 208, 150))
	for _ = 1, 8 do
		palm(c.X + rng:NextNumber(-65, 65), c.Z + rng:NextNumber(-65, 65))
	end
	for k = 1, 3 do
		local x, z = c.X + rng:NextNumber(-50, 50), c.Z + rng:NextNumber(-50, 50)
		mk(fProps, Vector3.new(0.4, 8, 0.4), Vector3.new(x, SW_H + 4, z), rgb(240, 240, 240))
		mk(fProps, Vector3.new(11, 0.5, 11), CFrame.new(x, SW_H + 8, z), k % 2 == 0 and rgb(230, 60, 60) or rgb(60, 140, 230), Enum.Material.Fabric, { CanCollide = false })
	end
	-- poste de secouriste
	mk(fBuild, Vector3.new(8, 10, 8), Vector3.new(c.X + 50, SW_H + 5, c.Z - 50), rgb(250, 250, 250), Enum.Material.Wood)
	mk(fBuild, Vector3.new(10, 1, 10), Vector3.new(c.X + 50, SW_H + 10.5, c.Z - 50), rgb(230, 60, 60), Enum.Material.Wood)
	return c
end

local function districtPark(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Grass, rgb(80, 150, 70))
	for _ = 1, 22 do
		tree(c.X + rng:NextNumber(-70, 70), c.Z + rng:NextNumber(-70, 70), true)
	end
	mk(fDecor, Vector3.new(50, 0.2, 40), Vector3.new(c.X, SW_H + 0.1, c.Z), rgb(60, 140, 200), Enum.Material.Glass, { CanCollide = false, Transparency = 0.2 })
	mk(fDecor, Vector3.new(6, 0.2, 150), Vector3.new(c.X, SW_H + 0.1, c.Z), rgb(200, 190, 170), Enum.Material.Pebble, { CanCollide = false })
	for _ = 1, 3 do
		breakable("bench", c.X + rng:NextNumber(-60, 60), c.Z + rng:NextNumber(-65, 65))
	end
	return c
end

local function districtHarbor(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(140, 140, 145))
	for k = 0, 3 do
		container(c.X - 40 + k * 22, c.Z - 20, 0, 0)
		container(c.X - 40 + k * 22, c.Z - 20, 0, 1)
	end
	warehouse(c.X, c.Z + 45, 90, 40, 22, rgb(120, 130, 140))
	-- grue
	mk(fBuild, Vector3.new(4, 50, 4), Vector3.new(c.X + 60, SW_H + 25, c.Z + 10), rgb(240, 160, 30), Enum.Material.Metal)
	mk(fBuild, Vector3.new(4, 4, 60), Vector3.new(c.X + 60, SW_H + 52, c.Z - 12), rgb(240, 160, 30), Enum.Material.Metal)
	-- jetée vers l'est
	mk(fDecor, Vector3.new(230, 1, 38), Vector3.new(M.GroundHalf + 5, 0.5, 95), rgb(140, 100, 65), Enum.Material.WoodPlanks)
	for k = 0, 8 do
		mk(fDecor, Vector3.new(3, 14, 3), Vector3.new(M.GroundHalf - 90 + k * 25, -6, 95 + 17), rgb(90, 65, 45), Enum.Material.Wood)
		mk(fDecor, Vector3.new(3, 14, 3), Vector3.new(M.GroundHalf - 90 + k * 25, -6, 95 - 17), rgb(90, 65, 45), Enum.Material.Wood)
	end
	return c
end

local function districtStadium(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(160, 160, 165))
	mk(fDecor, Vector3.new(100, 0.2, 100), Vector3.new(c.X, SW_H + 0.1, c.Z), rgb(70, 160, 80), Enum.Material.Grass, { CanCollide = false })
	-- gradins
	for k = 0, 3 do
		mk(fBuild, Vector3.new(120 + k * 6, 3, 8), Vector3.new(c.X, SW_H + 1.5 + k * 3, c.Z - 66 - k * 5), rgb(190, 60 + k * 20, 60), Enum.Material.Concrete)
		mk(fBuild, Vector3.new(120 + k * 6, 3, 8), Vector3.new(c.X, SW_H + 1.5 + k * 3, c.Z + 66 + k * 5), rgb(60, 90 + k * 20, 200), Enum.Material.Concrete)
	end
	-- arche de départ
	local ax = c.X - 70
	mk(fBuild, Vector3.new(3, 22, 3), Vector3.new(ax, SW_H + 11, c.Z - 28), rgb(30, 30, 35), Enum.Material.Metal)
	mk(fBuild, Vector3.new(3, 22, 3), Vector3.new(ax, SW_H + 11, c.Z + 28), rgb(30, 30, 35), Enum.Material.Metal)
	local banner = mk(fBuild, Vector3.new(3, 6, 62), Vector3.new(ax, SW_H + 22, c.Z), rgb(20, 20, 24), Enum.Material.Metal)
	sign(banner, "COURSE DE RUE", 6, 320, rgb(255, 80, 80))
	hubPad(Vector3.new(ax - 8, SW_H, c.Z), rgb(255, 70, 70), "MissionHub", { Mission = "race", Label = "Course de rue" })
	return c
end

local function districtPlaza(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Cobblestone, rgb(170, 160, 150))
	-- fontaine
	mk(fDecor, Vector3.new(3, 34, 34), CFrame.new(c.X, SW_H + 1.5, c.Z) * CFrame.Angles(0, 0, math.pi / 2), rgb(190, 190, 195), Enum.Material.Marble, { Shape = Enum.PartType.Cylinder })
	mk(fDecor, Vector3.new(0.4, 30, 30), CFrame.new(c.X, SW_H + 2.8, c.Z) * CFrame.Angles(0, 0, math.pi / 2), rgb(70, 150, 220), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.25 })
	mk(fDecor, Vector3.new(2, 10, 2), Vector3.new(c.X, SW_H + 7, c.Z), rgb(190, 190, 195), Enum.Material.Marble)
	-- tableau de classement (SurfaceGui rempli par LeaderboardService)
	local board = mk(fBuild, Vector3.new(44, 24, 2), CFrame.new(c.X, SW_H + 14, c.Z + 56), rgb(20, 22, 30), Enum.Material.Metal)
	board.Name = "LeaderboardBoard"
	mk(fBuild, Vector3.new(2, 14, 2), Vector3.new(c.X - 18, SW_H + 7, c.Z + 56), rgb(70, 70, 80), Enum.Material.Metal)
	mk(fBuild, Vector3.new(2, 14, 2), Vector3.new(c.X + 18, SW_H + 7, c.Z + 56), rgb(70, 70, 80), Enum.Material.Metal)
	-- point d'apparition
	local sp = Instance.new("SpawnLocation")
	sp.Name = "MainSpawn"
	sp.Size = Vector3.new(14, 1, 14)
	sp.CFrame = CFrame.new(c.X, SW_H + 0.5, c.Z - 40)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Color = rgb(255, 196, 0)
	sp.Material = Enum.Material.Neon
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Transparency = 0.4
	sp.Parent = fDecor
	World.Spawn = CFrame.new(c.X, SW_H + 4, c.Z - 40)
	for k = 1, 4 do
		local a = k * math.pi / 2 + math.pi / 4
		tree(c.X + math.cos(a) * 62, c.Z + math.sin(a) * 62, false)
	end
	for k = 1, 4 do
		breakable("bench", c.X + (k - 2.5) * 22, c.Z + 26)
	end
	-- Panneau d'accueil
	local mon = mk(fDecor, Vector3.new(8, 14, 3), Vector3.new(c.X + 30, SW_H + 7, c.Z - 20), rgb(40, 44, 56), Enum.Material.Metal)
	sign(mon, "CITY RUSH", 10, 280, rgb(255, 196, 0))
	return c
end

local function showcase(parent, specId, pos, rotY)
	local spec = Config.getVehicle(specId)
	local car = VehicleBuilder.build(spec, spec.color, { static = true })
	car:PivotTo(CFrame.new(pos + Vector3.new(0, VehicleBuilder.RideHeight, 0)) * CFrame.Angles(0, rotY, 0))
	car.Parent = parent
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = d.Name == "Chassis"
		end
	end
	return car
end

local function districtDealer(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(185, 185, 190))
	-- showroom vitré
	mk(fBuild, Vector3.new(110, 1, 60), Vector3.new(c.X, SW_H + 0.5, c.Z + 20), rgb(235, 235, 240), Enum.Material.Marble)
	mk(fBuild, Vector3.new(110, 1.2, 60), Vector3.new(c.X, SW_H + 17, c.Z + 20), rgb(50, 52, 60), Enum.Material.Metal)
	mk(fBuild, Vector3.new(110, 16, 1), Vector3.new(c.X, SW_H + 8, c.Z + 50), rgb(60, 90, 130), Enum.Material.Glass, { Transparency = 0.4 })
	mk(fBuild, Vector3.new(1, 16, 60), Vector3.new(c.X - 55, SW_H + 8, c.Z + 20), rgb(60, 90, 130), Enum.Material.Glass, { Transparency = 0.4 })
	mk(fBuild, Vector3.new(1, 16, 60), Vector3.new(c.X + 55, SW_H + 8, c.Z + 20), rgb(60, 90, 130), Enum.Material.Glass, { Transparency = 0.4 })
	local showcaseIds = { "berline", "muscle", "sport", "super" }
	for k, id in ipairs(showcaseIds) do
		local pos = Vector3.new(c.X - 42 + (k - 1) * 28, SW_H + 1, c.Z + 22)
		mk(fDecor, Vector3.new(0.4, 18, 18), CFrame.new(pos.X, SW_H + 1.2, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 36), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		showcase(fProps, id, pos + Vector3.new(0, 0.6, 0), math.pi / 5 * (k % 2 == 0 and 1 or -1))
	end
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(c.X, SW_H + 24, c.Z + 20), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "CONCESSIONNAIRE", 0, 340, rgb(80, 200, 255))
	hubPad(Vector3.new(c.X, SW_H, c.Z - 25), rgb(80, 200, 255), "DealerHub", {}, "Voir les véhicules")
	return c
end

local function districtPaySpray(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(170, 170, 172))
	mk(fBuild, Vector3.new(60, 20, 50), Vector3.new(c.X, SW_H + 10, c.Z + 30), rgb(250, 210, 60), Enum.Material.Metal)
	mk(fBuild, Vector3.new(34, 14, 1), Vector3.new(c.X, SW_H + 7, c.Z + 4.5), rgb(40, 42, 50), Enum.Material.Metal, { CanCollide = false })
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(c.X, SW_H + 25, c.Z + 4), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "PAY'N'SPRAY", 0, 300, rgb(255, 214, 0))
	hubPad(Vector3.new(c.X, SW_H, c.Z - 14), rgb(255, 214, 0), "SprayHub", {}, "Effacer ton casier")
	return c
end

local function districtPolice(i, j)
	local c = buildBlockSlab(i, j, Enum.Material.Concrete, rgb(160, 165, 175))
	mk(fBuild, Vector3.new(90, 24, 40), Vector3.new(c.X, SW_H + 12, c.Z + 40), rgb(70, 90, 140), Enum.Material.Concrete)
	mk(fBuild, Vector3.new(94, 1.5, 44), Vector3.new(c.X, SW_H + 24.7, c.Z + 40), rgb(35, 40, 60), Enum.Material.Metal)
	for k = -3, 3 do
		mk(fBands, Vector3.new(8, 8, 0.4), Vector3.new(c.X + k * 12, SW_H + 14, c.Z + 20), rgb(150, 200, 255), Enum.Material.Glass, {
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Tag = "Lit",
		})
	end
	mk(fBuild, Vector3.new(24, 3, 1), Vector3.new(c.X, SW_H + 20, c.Z + 19.6), rgb(30, 60, 200), Enum.Material.Neon, { CanCollide = false })
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(c.X, SW_H + 32, c.Z + 20), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "COMMISSARIAT", 0, 320, rgb(90, 140, 255))
	World.PolicePoint = CFrame.new(c.X, SW_H + 4, c.Z - 30) * CFrame.Angles(0, math.pi, 0)
	return c
end

-- Banque (braquage) : dans le bloc downtown (3,2)
local function addBank(i, j)
	local c = Config.blockCenter(i, j)
	-- on remplace une tour du quart nord-ouest par un bâtiment bancaire bas
	local bx, bz = c.X, c.Z + 50
	mk(fBuild, Vector3.new(70, 22, 30), Vector3.new(bx, SW_H + 11, bz + 10), rgb(235, 228, 210), Enum.Material.Marble)
	mk(fBuild, Vector3.new(76, 2, 38), Vector3.new(bx, SW_H + 23, bz + 10), rgb(130, 125, 115), Enum.Material.Concrete)
	for k = -3, 3 do
		mk(fBuild, Vector3.new(3, 18, 3), Vector3.new(bx + k * 10, SW_H + 9, bz - 8), rgb(245, 240, 230), Enum.Material.Marble)
	end
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(bx, SW_H + 28, bz - 8), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "BANQUE CENTRALE", 0, 340, rgb(255, 214, 0))
	World.Bank = Vector3.new(bx, SW_H, bz - 20)
	hubPad(World.Bank, rgb(255, 60, 60), "MissionHub", { Mission = "heist", Label = "Braquage" }, "Braquer la banque")
end

local function addPizzeria(i, j)
	local c = Config.blockCenter(i, j)
	mk(fBuild, Vector3.new(36, 14, 26), Vector3.new(c.X + 48, SW_H + 7, c.Z - 55), rgb(255, 120, 60), Enum.Material.Brick)
	mk(fBuild, Vector3.new(40, 1, 30), Vector3.new(c.X + 48, SW_H + 14.5, c.Z - 55), rgb(150, 40, 30), Enum.Material.Slate)
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(c.X + 48, SW_H + 19, c.Z - 41), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "PIZZERIA", 0, 240, rgb(255, 150, 80))
	hubPad(Vector3.new(c.X + 48, SW_H, c.Z - 30), rgb(255, 150, 80), "MissionHub", { Mission = "delivery", Label = "Livraison" }, "Livrer des pizzas")
end

local function addTaxiStand(i, j)
	local c = Config.blockCenter(i, j)
	mk(fBuild, Vector3.new(12, 10, 20), Vector3.new(c.X - 58, SW_H + 5, c.Z - 10), rgb(255, 214, 0), Enum.Material.Metal)
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(c.X - 58, SW_H + 14, c.Z - 10), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, "STATION TAXI", 0, 260, rgb(255, 214, 0))
	hubPad(Vector3.new(c.X - 40, SW_H, c.Z - 10), rgb(255, 214, 0), "MissionHub", { Mission = "taxi", Label = "Course de taxi" }, "Prendre une course")
end

local function addHideout()
	local c = Config.blockCenter(3, 1)
	World.Hideout = Vector3.new(c.X - 30, SW_H, c.Z + 55)
	local pad = hubPad(World.Hideout, rgb(80, 255, 120), "Hideout", {}, "Planque")
	pad.Name = "HideoutPad"
end

-- ====================================================================
-- Jumps (rampes) et étoiles
-- ====================================================================
local function jumpRamp(x, z, rotY)
	local len, rise = 30, 12
	local ang = math.atan(rise / len)
	local cf = CFrame.new(x, 0.3 + rise / 2, z) * CFrame.Angles(0, rotY, 0) * CFrame.Angles(ang, 0, 0)
	-- l'avant (-Z local) monte : rotation +X relève -Z
	mk(fProps, Vector3.new(16, 1.2, math.sqrt(len * len + rise * rise)), cf, rgb(255, 160, 40), Enum.Material.Metal)
	local fwd = CFrame.Angles(0, rotY, 0).LookVector
	local starPos = Vector3.new(x, 0, z) + fwd * 42 + Vector3.new(0, 16, 0)
	table.insert(World.StarSpots, starPos)
end

local function placeStars()
	-- 4 étoiles sur rampes (routes périphériques)
	jumpRamp(-500, -350, 0) -- route ouest, vers -Z
	jumpRamp(500, 350, math.pi) -- route est, vers +Z
	jumpRamp(-350, 500, math.pi / 2 * -1) -- route sud
	jumpRamp(350, -500, math.pi / 2) -- route nord

	-- étoiles au sol : recoins de blocs (toujours sur trottoir)
	local c0 = rng
	local spots = {
		{ 1, 1 }, { 2, 1 }, { 4, 1 }, { 1, 3 }, { 1, 5 }, { 2, 5 }, { 4, 5 }, { 5, 5 }, { 5, 4 }, { 5, 2 },
		{ 3, 1 }, { 2, 3 }, { 4, 3 }, { 3, 4 }, { 5, 1 }, { 1, 2 }, { 1, 4 }, { 3, 2 }, { 2, 2 }, { 4, 4 }, { 4, 2 },
	}
	for k, b in ipairs(spots) do
		local c = Config.blockCenter(b[1], b[2])
		local a = c0:NextNumber(0, math.pi * 2)
		local r = 62
		table.insert(World.StarSpots, Vector3.new(c.X + math.cos(a) * r, SW_H + 3, c.Z + math.sin(a) * r))
		if #World.StarSpots >= Config.Collectibles.Count - 5 then
			break
		end
	end
	-- jetée, plage, toits bas
	table.insert(World.StarSpots, Vector3.new(M.GroundHalf + 100, 4, 95))
	table.insert(World.StarSpots, Vector3.new(M.GroundHalf + 190, 4, 95))
	table.insert(World.StarSpots, Vector3.new(M.GroundHalf - 70, 4, -300))
	table.insert(World.StarSpots, Vector3.new(M.GroundHalf - 70, 4, 300))
	table.insert(World.StarSpots, Vector3.new(-610, 4, 0))
	while #World.StarSpots > Config.Collectibles.Count do
		table.remove(World.StarSpots)
	end
end

-- ====================================================================
-- Points de circulation
-- ====================================================================
local function computeNodes()
	for ix = 0, 5 do
		World.RoadNodes[ix] = {}
		for iz = 0, 5 do
			World.RoadNodes[ix][iz] = Config.nodePos(ix, iz)
		end
	end
	local ring = { { 5, 0 }, { 2, 0 }, { 0, 0 }, { 0, 3 }, { 0, 5 }, { 3, 5 }, { 5, 5 }, { 5, 3 } }
	for _, n in ipairs(ring) do
		table.insert(World.RaceCircuit, World.RoadNodes[n[1]][n[2]])
	end
end

local function computeParking()
	local count = 0
	local tries = 0
	while count < 30 and tries < 400 do
		tries += 1
		local alongZ = rng:NextInteger(0, 1) == 1
		local line = rng:NextInteger(0, 5)
		local c = -500 + M.Pitch * line
		local t = rng:NextNumber(-470, 470)
		-- éviter les intersections
		local ok = true
		for n = 0, 5 do
			if math.abs(t - (-500 + M.Pitch * n)) < 55 then
				ok = false
			end
		end
		if ok then
			local side = rng:NextInteger(0, 1) == 1 and 1 or -1
			local pos, yaw
			if alongZ then
				pos = Vector3.new(c + side * 12, 0.3, t)
				yaw = side > 0 and math.pi or 0
			else
				pos = Vector3.new(t, 0.3, c + side * 12)
				yaw = side > 0 and -math.pi / 2 or math.pi / 2
			end
			table.insert(World.ParkingSpots, CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
			count += 1
		end
	end
end

local function computeTaxiStops()
	for _ = 1, 12 do
		local i, j = rng:NextInteger(1, 5), rng:NextInteger(1, 5)
		local c = Config.blockCenter(i, j)
		local side = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-50, 50)
		local p
		if side == 1 then
			p = Vector3.new(c.X + t, SW_H, c.Z - 76)
		elseif side == 2 then
			p = Vector3.new(c.X + t, SW_H, c.Z + 76)
		elseif side == 3 then
			p = Vector3.new(c.X - 76, SW_H, c.Z + t)
		else
			p = Vector3.new(c.X + 76, SW_H, c.Z + t)
		end
		table.insert(World.TaxiStops, p)
	end
end

-- ====================================================================
-- Détails visuels (budget : ~500 parts) : feux tricolores, haies, enseignes de toit, panneaux
-- ====================================================================
local function trafficLight(x, z, rotY)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, rotY, 0)
	mk(fProps, Vector3.new(0.6, 12, 0.6), base * CFrame.new(0, SW_H + 6, 0), rgb(50, 52, 58), Enum.Material.Metal)
	mk(fProps, Vector3.new(2.2, 5.6, 1.4), base * CFrame.new(0, SW_H + 12.5, 0), rgb(30, 30, 34), Enum.Material.Metal)
	local colors = { rgb(235, 60, 60), rgb(240, 190, 40), rgb(70, 210, 100) }
	for i, c in ipairs(colors) do
		mk(fProps, Vector3.new(1.2, 1.2, 0.3), base * CFrame.new(0, SW_H + 14.2 - (i - 1) * 1.7, -0.75), c, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
	end
end

local function hedge(x, z, w, d)
	mk(fProps, Vector3.new(w, 2.4, d), Vector3.new(x, SW_H + 1.2, z), rgb(52, 120, 56), Enum.Material.Grass)
	for _ = 1, 2 do
		mk(fProps, Vector3.new(1.4, 1.4, 1.4), Vector3.new(x + rng:NextNumber(-w / 2, w / 2), SW_H + 2.9, z + rng:NextNumber(-d / 2, d / 2)), rng:NextInteger(0, 1) == 1 and rgb(240, 120, 150) or rgb(250, 220, 90), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
	end
end

local function roofSign(cx, cz, h, text, color)
	mk(fProps, Vector3.new(26, 0.6, 3), Vector3.new(cx, SW_H + h + 3, cz), rgb(40, 42, 50), Enum.Material.Metal, { CanCollide = false })
	local sg = mk(fDecor, Vector3.new(1, 1, 1), Vector3.new(cx, SW_H + h + 7, cz), rgb(255, 255, 255), Enum.Material.SmoothPlastic, NOCOLLIDE)
	sg.Transparency = 1
	sign(sg, text, 0, 220, color)
end

local function addDetails()
	-- feux tricolores aux 36 carrefours (un seul poteau par carrefour, coin nord-ouest)
	for ix = 0, 5 do
		for iz = 0, 5 do
			local p = World.RoadNodes[ix][iz]
			trafficLight(p.X + 24, p.Z + 24, rng:NextInteger(0, 1) * math.pi)
		end
	end
	-- haies et massifs devant les maisons des blocs résidentiels
	for j = 1, M.Grid do
		for i = 1, M.Grid do
			if Config.Districts[j][i] == "residential" then
				local c = Config.blockCenter(i, j)
				for _, row in ipairs({ -1, 1 }) do
					for col = -1, 1 do
						hedge(c.X + col * 50 - 14, c.Z + row * 38 + row * 15, 8, 2)
					end
				end
			end
		end
	end
	-- enseignes lumineuses sur les toits du centre-ville
	local names = { "HOTEL", "CAFE", "CINEMA", "BAR", "NEON CITY", "SHOP", "HOTEL RUSH", "GARAGE" }
	local colors = { rgb(255, 80, 160), rgb(80, 220, 255), rgb(255, 200, 60), rgb(120, 255, 140) }
	local n = 0
	for j = 1, M.Grid do
		for i = 1, M.Grid do
			if Config.Districts[j][i] == "downtown" and not (i == 3 and j == 2) then
				n += 1
				local c = Config.blockCenter(i, j)
				roofSign(c.X, c.Z - 8, 30, names[(n % #names) + 1], colors[(n % #colors) + 1])
			end
		end
	end
end

-- ====================================================================
-- Lumière & jour/nuit
-- ====================================================================
local function setupLighting()
	Lighting.Brightness = 2.5
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = rgb(110, 115, 130)
	Lighting.Ambient = rgb(70, 72, 82)
	Lighting.GeographicLatitude = 30
	Lighting.ClockTime = 12
	for _, name in ipairs({ "CRAtmosphere", "CRBloom", "CRColor", "CRSunRays" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "CRAtmosphere"
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = rgb(190, 205, 225)
	atm.Decay = rgb(120, 130, 150)
	atm.Glare = 0.1
	atm.Haze = 1.4
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CRBloom"
	bloom.Intensity = 0.25
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CRColor"
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "CRSunRays"
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.5
	clouds.Parent = workspace.Terrain
	workspace.Terrain.WaterTransparency = 0.7
	workspace.Terrain.WaterColor = rgb(30, 110, 160)
	workspace.Terrain.WaterWaveSize = 0.3
end

local function startDayCycle()
	task.spawn(function()
		local clock = 12
		local step = 24 / Config.DayLengthSeconds
		while true do
			task.wait(1)
			clock = (clock + step) % 24
			Lighting.ClockTime = clock
		end
	end)
end

-- ====================================================================
-- Props destructibles
-- ====================================================================
local brokenQueue = 0
function World.breakProp(part)
	if not part or not part.Parent or part.Parent ~= fBreak then
		return false
	end
	local original = part:Clone()
	local home = fBreak
	part.Anchored = false
	part.CanCollide = false
	part.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(25, 45), rng:NextNumber(-25, 25))
	part.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
	part.Name = "Debris"
	part.Parent = fDecor
	Debris:AddItem(part, 4)
	task.delay(35, function()
		if home and home.Parent then
			original.Parent = home
		end
	end)
	return true
end

World.BreakFolder = nil

-- ====================================================================
-- Construction principale
-- ====================================================================
function World.build()
	local old = workspace:FindFirstChild("City")
	if old then
		old:Destroy()
	end
	root = folder("City", workspace)
	fRoads = folder("Roads", root)
	fBuild = folder("Buildings", root)
	fBands = folder("Windows", root)
	fProps = folder("Props", root)
	fBreak = folder("Breakables", root)
	fDecor = folder("Decor", root)
	World.BreakFolder = fBreak
	World.Root = root

	setupLighting()
	computeNodes()
	buildGroundAndRoads()

	local builders = {
		residential = districtResidential,
		industrial = districtIndustrial,
		downtown = districtDowntown,
		plaza = districtPlaza,
		harbor = districtHarbor,
		beach = districtBeach,
		stadium = districtStadium,
		park = districtPark,
		payspray = districtPaySpray,
		police = districtPolice,
		dealer = districtDealer,
	}
	for j = 1, M.Grid do
		for i = 1, M.Grid do
			builders[Config.Districts[j][i]](i, j)
		end
	end

	addBank(3, 2)
	addPizzeria(1, 3)
	addTaxiStand(3, 3)
	addHideout()
	if Config.Visual and Config.Visual.Details then
		local ok, err = pcall(addDetails)
		if not ok then
			warn("[World] détails visuels ignorés: " .. tostring(err))
		end
	end
	placeStars()
	computeParking()
	computeTaxiStops()
	startDayCycle()

	root:SetAttribute("Built", true)
	World.Ready = true
	print(string.format("[World] Ville générée : %d parts", made))
end

return World

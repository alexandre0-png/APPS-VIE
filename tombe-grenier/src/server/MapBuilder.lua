--[[
  MapBuilder : construit la maison, le jardin et les éléments fixes à partir de Shared.MapData,
  puis dispose les objets de chaque partie (placeRound) à partir d'une seed.

  MapData est généré par tools/map/generate_map.py : ne pas éditer à la main.

  Hiérarchie créée dans Workspace/TombeMap :
    Maison/   Murs, Dalles, Escaliers, Meubles, Décor, Props (cachettes, repères, lampes, porte)
    Jardin/   pelouse, allée, arbres
    MursInvisibles/  clôture, portail, grille
    Round/    objets tirés pour la partie en cours (photos, clé, piles, objets, chutes, apparition)
    CercueilSpawn    SpawnLocation sur le cercueil du grenier

  Matériaux : brique et mur partagent l'ID 9920482813 (confirmé).
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.MapData)
local Rng = require(Shared.Rng)

local MapBuilder = {}

local ROUND_FOLDER = "Round"

-- Lampes construites une fois : { room = id, part = bulb, light = PointLight }
local lamps = {}
-- Pièces plongées dans le noir pour la partie en cours : { [roomId] = true }
local darkRooms = {}

local MATERIALS = {
	carrelage   = { color = Color3.fromRGB(150, 150, 145), material = Enum.Material.Marble,
	                tex = "17429425079", faces = { Enum.NormalId.Top }, tile = 6 },
	ardoise     = { color = Color3.fromRGB(45, 47, 52), material = Enum.Material.Slate,
	                tex = "9920599782", faces = { Enum.NormalId.Top }, tile = 6 },
	brique      = { color = Color3.fromRGB(95, 50, 40), material = Enum.Material.Brick,
	                tex = "9920482813", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	mur         = { color = Color3.fromRGB(120, 112, 100), material = Enum.Material.Concrete,
	                tex = "9920482813", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	plancher    = { color = Color3.fromRGB(70, 50, 34), material = Enum.Material.Wood },
	bois        = { color = Color3.fromRGB(92, 62, 40), material = Enum.Material.Wood },
	bois_sombre = { color = Color3.fromRGB(45, 30, 20), material = Enum.Material.Wood },
	metal       = { color = Color3.fromRGB(60, 60, 66), material = Enum.Material.Metal },
	tissu       = { color = Color3.fromRGB(90, 40, 40), material = Enum.Material.Fabric },
	pierre      = { color = Color3.fromRGB(100, 100, 100), material = Enum.Material.Cobblestone },
	vert        = { color = Color3.fromRGB(40, 70, 40), material = Enum.Material.LeafyGrass },
	porcelaine  = { color = Color3.fromRGB(220, 220, 215), material = Enum.Material.SmoothPlastic },
	carton      = { color = Color3.fromRGB(150, 120, 80), material = Enum.Material.Cardboard },
	herbe       = { color = Color3.fromRGB(46, 74, 40), material = Enum.Material.Grass },
}

local LAMP_PALETTE = {
	Color3.fromRGB(255, 205, 140), -- chaude, ampoule à filament
	Color3.fromRGB(190, 215, 255), -- froide, tube fluorescent
	Color3.fromRGB(200, 235, 200), -- verdâtre, lampe mourante
}

local function applyTextures(part, spec)
	if not spec.tex then
		return
	end
	for _, face in ipairs(spec.faces) do
		local texture = Instance.new("Texture")
		texture.Texture = "rbxassetid://" .. spec.tex
		texture.Face = face
		texture.StudsPerTileU = spec.tile
		texture.StudsPerTileV = spec.tile
		texture.Parent = part
	end
end

-- Boîte ancrée à partir d'un rectangle x0..x1, y0..y1, z0..z1. deco = true : non collisionnable.
local function makeBox(parent, b, matKey, name)
	local spec = MATERIALS[matKey]
	if not spec then
		warn(("[MapBuilder] matériau inconnu '%s' (%s), 'mur' utilisé"):format(tostring(matKey), tostring(name)))
		spec = MATERIALS.mur
	end
	local part = Instance.new("Part")
	part.Name = name or "Piece"
	part.Anchored = true
	part.Size = Vector3.new(b.x1 - b.x0, b.y1 - b.y0, b.z1 - b.z0)
	part.CFrame = CFrame.new((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, (b.z0 + b.z1) / 2)
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if b.deco then
		part.CanCollide = false
	end
	applyTextures(part, spec)
	part.Parent = parent
	return part
end

-- Point invisible centré sur pos (tags de gameplay)
local function makeMarker(parent, pos, size, name, tag)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(size[1], size[2], size[3])
	part.Position = Vector3.new(pos[1], pos[2], pos[3])
	part.Parent = parent
	CollectionService:AddTag(part, tag)
	return part
end

-- Objet visible posé sur un meuble ou un sol (photos, clé, piles, objets interactifs)
local function makeVisible(parent, pos, size, name, color, material, tag)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.Material = material
	part.Size = Vector3.new(size[1], size[2], size[3])
	part.Position = Vector3.new(pos[1], pos[2], pos[3])
	part.Parent = parent
	CollectionService:AddTag(part, tag)
	return part
end

-- Tire n éléments distincts de list avec la seed (Fisher-Yates partiel)
local function pick(rng, list, n)
	local copy = table.clone(list)
	local out = {}
	for i = 1, math.min(n, #copy) do
		local j = rng:int(i, #copy)
		copy[i], copy[j] = copy[j], copy[i]
		table.insert(out, copy[i])
	end
	return out
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function buildHouse(root)
	local house = Instance.new("Model")
	house.Name = "Maison"
	house.Parent = root

	local folders = {}
	for _, name in ipairs({ "Murs", "Dalles", "Escaliers", "Meubles", "Décor", "Props" }) do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = house
		folders[name] = f
	end

	for _, w in ipairs(Data.walls) do
		makeBox(folders.Murs, w, w.mat, w.name or "Mur")
	end
	for _, s in ipairs(Data.slabs) do
		makeBox(folders.Dalles, s, s.mat, s.name or "Dalle")
	end
	for _, s in ipairs(Data.steps) do
		makeBox(folders.Escaliers, s, s.mat, "Marche")
	end
	for _, f in ipairs(Data.furniture) do
		local part = makeBox(folders.Meubles, f, f.mat, f.name)
		if f.name == "cercueil" then
			part.CanCollide = false -- décoratif : le point de spawn est juste dessous
		end
	end
	for _, d in ipairs(Data.decor) do
		makeBox(folders["Décor"], d, d.mat, d.name)
	end

	-- Cachettes : une par armoire
	for _, h in ipairs(Data.hiding) do
		makeMarker(folders.Props, h.pos, h.size, h.name, "Hiding")
	end

	-- Repères fixes et porte de sortie
	lamps = {}
	for _, p in ipairs(Data.props) do
		if p.tag == "Waypoint" then
			makeMarker(folders.Props, p.pos, p.size, p.name, "Waypoint")
		elseif p.tag == "Lamp" then
			-- Une ampoule par pièce ; l'allumage et la couleur sont tirés à chaque partie
			local bulb = makeVisible(folders.Props, p.pos, p.size, p.name,
				LAMP_PALETTE[1], Enum.Material.Neon, "Lamp")
			bulb.Transparency = 0.2
			local light = Instance.new("PointLight")
			light.Range = 24
			light.Brightness = 1.2
			light.Color = LAMP_PALETTE[1]
			light.Shadows = false
			light.Parent = bulb
			table.insert(lamps, { room = p.room, part = bulb, light = light })
		elseif p.tag == "ExitDoor" then
			local door = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(70, 45, 30), Enum.Material.Wood, "ExitDoor")
			door.CanCollide = true -- porte fermée tant que la sortie n'est pas ouverte
		end
	end
end

local function buildInvisibleWalls(root)
	local folder = Instance.new("Folder")
	folder.Name = "MursInvisibles"
	folder.Parent = root
	for _, w in ipairs(Data.invisible) do
		local part = Instance.new("Part")
		part.Name = w.name
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = 1
		part.Size = Vector3.new(w.x1 - w.x0, w.y1 - w.y0, w.z1 - w.z0)
		part.CFrame = CFrame.new((w.x0 + w.x1) / 2, (w.y0 + w.y1) / 2, (w.z0 + w.z1) / 2)
		part.Parent = folder
		CollectionService:AddTag(part, "InvisibleWall")
		if w.puzzle then
			part:SetAttribute("Puzzle", w.puzzle)
		end
	end
end

local function buildGarden(root)
	local garden = Instance.new("Folder")
	garden.Name = "Jardin"
	garden.Parent = root

	for _, p in ipairs(Data.garden.plates) do
		makeBox(garden, p, p.mat, p.name)
	end
	for _, p in ipairs(Data.garden.path) do
		makeBox(garden, p, p.mat, p.name)
	end
	for _, t in ipairs(Data.garden.trees) do
		local trunk = Instance.new("Part")
		trunk.Name = "Tronc"
		trunk.Anchored = true
		trunk.Size = Vector3.new(1.5, 8, 1.5)
		trunk.Position = Vector3.new(t.x, 4, t.z)
		trunk.Color = Color3.fromRGB(60, 42, 30)
		trunk.Material = Enum.Material.Wood
		trunk.Parent = garden

		local canopy = Instance.new("Part")
		canopy.Name = "Feuillage"
		canopy.Shape = Enum.PartType.Ball
		canopy.Anchored = true
		canopy.CanCollide = false
		canopy.Size = Vector3.new(9, 9, 9)
		canopy.Position = Vector3.new(t.x, 11, t.z)
		canopy.Color = Color3.fromRGB(30, 55, 32)
		canopy.Material = Enum.Material.LeafyGrass
		canopy.Parent = garden
	end
end

local function buildSpawn(root)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CercueilSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Size = Vector3.new(Data.spawn.size[1], Data.spawn.size[2], Data.spawn.size[3])
	spawn.Position = Vector3.new(Data.spawn.pos[1], Data.spawn.pos[2], Data.spawn.pos[3])
	spawn.Parent = root
end

-- Ambiance nocturne : peu de lumière extérieure, teinte froide, grain et bloom discrets
local function setLighting()
	Lighting.ClockTime = 23.5
	Lighting.GlobalShadows = true
	Lighting.Brightness = 0.15
	Lighting.Ambient = Color3.fromRGB(8, 7, 8)
	Lighting.OutdoorAmbient = Color3.fromRGB(6, 6, 9)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.FogColor = Color3.fromRGB(10, 10, 12)
	Lighting.FogEnd = 300

	local function effect(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e or not e:IsA(class) then
			if e then
				e:Destroy()
			end
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end

	local atmo = effect("Atmosphere", "TombeAtmosphere")
	atmo.Density = 0.35
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(60, 56, 52)
	atmo.Decay = Color3.fromRGB(70, 60, 50)
	atmo.Glare = 0
	atmo.Haze = 1.5

	local cc = effect("ColorCorrectionEffect", "TombeCorrection")
	cc.Saturation = -0.35
	cc.Contrast = 0.12
	cc.TintColor = Color3.fromRGB(255, 235, 220)
	cc.Brightness = -0.05

	local bloom = effect("BloomEffect", "TombeBloom")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 0.95

	local rays = effect("SunRaysEffect", "TombeSunRays")
	rays.Intensity = 0
end

-- Construit la carte fixe. Idempotent : reconstruit tout si la carte existe déjà.
function MapBuilder.build()
	local root = Workspace:FindFirstChild("TombeMap")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "TombeMap"
	root.Parent = Workspace

	buildHouse(root)
	buildInvisibleWalls(root)
	buildGarden(root)
	buildSpawn(root)
	setLighting()
	print(("[MapBuilder] carte fixe construite : %d murs, %d meubles, %d lampes")
		:format(#Data.walls, #Data.furniture, #lamps))
	return root
end

-- Dispose les objets de la partie : emplacements, lampes allumées ou éteintes, pièces sombres.
-- Même seed => même disposition. Appelé à chaque début de partie.
function MapBuilder.placeRound(seed)
	local root = Workspace:FindFirstChild("TombeMap")
	if not root then
		error("[MapBuilder] placeRound appelé avant build")
	end
	local old = root:FindFirstChild(ROUND_FOLDER)
	if old then
		old:Destroy()
	end
	local round = Instance.new("Folder")
	round.Name = ROUND_FOLDER
	round.Parent = root

	local rng = Rng.new(seed)
	local slots = Data.slots

	-- Pièces dans le noir
	darkRooms = {}
	local chosenDark = pick(rng, slots.dark_eligible, slots.dark_count)
	for _, rid in ipairs(chosenDark) do
		darkRooms[rid] = true
	end

	-- Lampes : allumées hors pièces sombres, couleur et intensité tirées
	for _, lamp in ipairs(lamps) do
		local lit = not darkRooms[lamp.room]
		CollectionService:RemoveTag(lamp.part, "FlickerLight")
		lamp.light.Enabled = lit
		lamp.light.Color = LAMP_PALETTE[rng:int(1, #LAMP_PALETTE)]
		lamp.light.Brightness = rng:range(0.9, 1.5)
		lamp.light.Range = rng:range(20, 28)
		lamp.part.Transparency = lit and 0.2 or 0.9
		if lit then
			CollectionService:AddTag(lamp.part, "FlickerLight")
		end
	end

	-- Photos, clé, piles
	for _, slot in ipairs(pick(rng, slots.photo, 3)) do
		makeVisible(round, slot.pos, slot.size, "Photo " .. slot.name,
			Color3.fromRGB(235, 230, 215), Enum.Material.SmoothPlastic, "Photo")
	end
	for _, slot in ipairs(pick(rng, slots.key, 1)) do
		makeVisible(round, slot.pos, slot.size, "Clé " .. slot.name,
			Color3.fromRGB(200, 170, 60), Enum.Material.Metal, "Key")
	end
	for _, slot in ipairs(pick(rng, slots.battery, 3)) do
		makeVisible(round, slot.pos, slot.size, "Pile " .. slot.name,
			Color3.fromRGB(70, 110, 170), Enum.Material.SmoothPlastic, "Battery")
	end

	-- Objets interactifs : un emplacement par objet
	for _, key in ipairs(sortedKeys(slots.interactable)) do
		local slot = pick(rng, slots.interactable[key], 1)[1]
		local item = makeVisible(round, slot.pos, slot.size, slot.kind,
			Color3.fromRGB(140, 110, 80), Enum.Material.Wood, "Interactable")
		item:SetAttribute("Kind", slot.kind)
		item:SetAttribute("Place", slot.name)
	end

	-- Chutes d'objets et apparition du monstre
	for _, slot in ipairs(pick(rng, slots.fall, 4)) do
		makeMarker(round, slot.pos, slot.size, "Chute " .. slot.name, "FallSpot")
	end
	for _, slot in ipairs(pick(rng, slots.monster, 1)) do
		makeMarker(round, slot.pos, slot.size, "Apparition " .. slot.name, "MonsterSpawn")
	end

	local dark = {}
	for rid in pairs(darkRooms) do
		table.insert(dark, rid)
	end
	table.sort(dark)
	print(("[MapBuilder] partie seed=%d, pièces sombres : %s"):format(seed, table.concat(dark, ", ")))
	return { dark = dark }
end

-- Identifiant de la pièce contenant pos, ou nil (escaliers et hors maison inclus)
function MapBuilder.roomAt(pos)
	local floorY = pos.Y - 2.5 -- la racine d'un personnage est environ 3 studs au-dessus du sol
	for _, r in ipairs(Data.rooms) do
		local base = Data.base[r.level]
		if floorY >= base and floorY < base + Data.H
			and pos.X >= r.x0 and pos.X < r.x1
			and pos.Z >= r.z0 and pos.Z < r.z1
		then
			return r.id
		end
	end
	return nil
end

function MapBuilder.isDark(roomId)
	return roomId ~= nil and darkRooms[roomId] == true
end

return MapBuilder

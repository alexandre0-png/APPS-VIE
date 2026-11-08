--[[
  MapBuilder : construit la maison, le jardin et les points de tag à partir de Shared.MapData.
  MapData est généré par tools/map/generate_map.py : ne rien modifier à la main dans ce module
  pour la disposition. Tout ce qui est créé ici est reconstruit à chaque lancement du serveur.

  Hiérarchie créée dans Workspace :
    Maison/ Murs, Dalles, Escaliers, Meubles, Props
    Jardin/ Pelouse, Allée, Arbres
    Clôture (murs invisibles)
    SpawnLocation (cercueil du grenier)
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.MapData)

local MapBuilder = {}

-- Matériaux. Les IDs Roblox sont ceux fournis (carrelage, brique, ardoise, mur).
-- Le mur et la brique partagent le même ID (9920482813) : à vérifier avant l'upload.
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

-- Crée une boîte ancrée à partir d'un rectangle x0..x1, y0..y1, z0..z1
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
	applyTextures(part, spec)
	part.Parent = parent
	return part
end

-- Point invisible centré sur pos, de taille size (tags de gameplay)
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

-- Objet visible posé sur un meuble ou un sol (photos, clé, objets interactifs)
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

local function buildHouse(root)
	local house = Instance.new("Model")
	house.Name = "Maison"
	house.Parent = root

	local folders = {}
	for _, name in ipairs({ "Murs", "Dalles", "Escaliers", "Meubles", "Props" }) do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = house
		folders[name] = f
	end

	for _, w in ipairs(Data.walls) do
		makeBox(folders.Murs, w, w.mat, "Mur")
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
			part.CanCollide = false -- le cercueil est décoratif, le point de spawn est juste dessous
		end
	end

	-- Cachettes : un point par armoire, tag Hiding
	for _, h in ipairs(Data.hiding) do
		makeMarker(folders.Props, h.pos, h.size, h.name, "Hiding")
	end

	-- Tags de gameplay
	for _, p in ipairs(Data.props) do
		local tag = p.tag
		local name = p.name
		if tag == "Waypoint" or tag == "FallSpot" or tag == "MonsterSpawn" then
			makeMarker(folders.Props, p.pos, p.size, name, tag)
		elseif tag == "FlickerLight" then
			local bulb = makeVisible(folders.Props, p.pos, p.size, name,
				Color3.fromRGB(255, 220, 150), Enum.Material.Neon, tag)
			bulb.Transparency = 0.2
			local light = Instance.new("PointLight")
			light.Range = 26
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 205, 140)
			light.Parent = bulb
		elseif tag == "Photo" then
			makeVisible(folders.Props, p.pos, p.size, name,
				Color3.fromRGB(235, 230, 215), Enum.Material.SmoothPlastic, tag)
		elseif tag == "Key" then
			makeVisible(folders.Props, p.pos, p.size, name,
				Color3.fromRGB(200, 170, 60), Enum.Material.Metal, tag)
		elseif tag == "Interactable" then
			local item = makeVisible(folders.Props, p.pos, p.size, name,
				Color3.fromRGB(140, 110, 80), Enum.Material.Wood, tag)
			item:SetAttribute("Kind", p.kind or name)
		elseif tag == "ExitDoor" then
			local door = makeVisible(folders.Props, p.pos, p.size, name,
				Color3.fromRGB(70, 45, 30), Enum.Material.Wood, tag)
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

local function setLighting()
	Lighting.Ambient = Color3.fromRGB(14, 12, 12)
	Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 16)
	Lighting.Brightness = 0.5
	Lighting.FogColor = Color3.fromRGB(8, 8, 12)
	Lighting.FogEnd = 450
end

-- Construit la carte. Idempotent : reconstruit tout si la carte existe déjà.
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
	print(("[MapBuilder] carte construite : %d murs, %d meubles, %d points de tag")
		:format(#Data.walls, #Data.furniture, #Data.props + #Data.hiding))
	return root
end

return MapBuilder

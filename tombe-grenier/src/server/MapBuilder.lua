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
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.MapData)
local Rng = require(Shared.Rng)
local DecorKit = require(script.Parent.DecorKit)
local Atmosphere = require(script.Parent.Atmosphere)

local MapBuilder = {}

local ROUND_FOLDER = "Round"

-- Lampes construites une fois : { room = id, part = bulb, light = PointLight }
local lamps = {}
-- Pièces plongées dans le noir pour la partie en cours : { [roomId] = true }
local darkRooms = {}

-- Pièces fermées par une énigme : pas de cailloux dedans
local CLOSED_ROOMS = { sdb = true, bureau = true, cha = true, sdb2 = true, cel = true }
local PEBBLE_COUNT = 4

local MATERIALS = {
	carrelage   = { color = Color3.fromRGB(150, 150, 145), material = Enum.Material.Marble,
	                tex = "17429425079", faces = { Enum.NormalId.Top }, tile = 6 },
	ardoise     = { color = Color3.fromRGB(45, 47, 52), material = Enum.Material.Slate,
	                tex = "9920599782", faces = { Enum.NormalId.Top }, tile = 6 },
	brique      = { color = Color3.fromRGB(95, 50, 40), material = Enum.Material.Brick,
	                tex = "97381143864995", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	mur         = { color = Color3.fromRGB(120, 112, 100), material = Enum.Material.Concrete,
	                tex = "100280695301167", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	papier      = { color = Color3.fromRGB(150, 130, 110), material = Enum.Material.Fabric,
	                tex = "11787663363", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	bureau      = { color = Color3.fromRGB(110, 100, 90), material = Enum.Material.Concrete,
	                tex = "93902698", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	bois_mur    = { color = Color3.fromRGB(80, 55, 38), material = Enum.Material.Wood,
	                tex = "539614542", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	rouille     = { color = Color3.fromRGB(90, 60, 40), material = Enum.Material.CorrodedMetal,
	                tex = "889609059", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	beton       = { color = Color3.fromRGB(100, 100, 98), material = Enum.Material.Concrete,
	                tex = "65710031", faces = { Enum.NormalId.Front, Enum.NormalId.Back }, tile = 4 },
	plancher    = { color = Color3.fromRGB(70, 50, 34), material = Enum.Material.Wood,
	                tex = "3867164051", faces = { Enum.NormalId.Top }, tile = 6 },
	bois        = { color = Color3.fromRGB(92, 62, 40), material = Enum.Material.Wood },
	asphalte    = { color = Color3.fromRGB(45, 45, 48), material = Enum.Material.Asphalt },
	-- Plafond du grenier : ciel intérieur sur la face tournée vers les combles, ardoise dessus
	plafond_grenier = { color = Color3.fromRGB(40, 40, 46), material = Enum.Material.Slate,
	                tex = "1585871274", faces = { Enum.NormalId.Bottom }, tile = 12 },
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

-- Pose le modèle chargé (ServerStorage/Decor) sur la pièce invisible qui porte l'invite ; ne fait rien s'il manque
local function placeDecorModel(name, pos, anchorPart)
	local folder = ServerStorage:FindFirstChild("Decor")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(CFrame.new(pos[1], pos[2], pos[3]))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Parent = anchorPart
end

-- Pose un modèle chargé à l'échelle d'une boîte cible (fenêtre, cheminée), sans collision
local function placeFitted(name, cf, target, parent)
	local folder = ServerStorage:FindFirstChild("Decor")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return
	end
	local model = template:Clone()
	local _, size = model:GetBoundingBox()
	local fit = math.min(target.X / math.max(size.X, 0.01), target.Y / math.max(size.Y, 0.01), target.Z / math.max(size.Z, 0.01))
	model:ScaleTo(model:GetScale() * fit)
	model:PivotTo(cf)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Parent = parent
end

-- Soude le modèle chargé à la pièce ancre : le modèle suit l'ancre quand elle tourne
local function weldDecorModel(name, anchorPart)
	local folder = ServerStorage:FindFirstChild("Decor")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(anchorPart.CFrame)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorPart
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model.Parent = anchorPart
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
		-- Murs du pourtour : façade en brique
		local outer = w.x0 <= -0.4 or w.z0 <= -0.4 or w.x1 >= 120.4 or w.z1 >= 90.4
		makeBox(folders.Murs, w, outer and "brique" or w.mat, w.name or "Mur")
	end
	-- Fenêtres sur les façades nord et sud, et cheminée contre le mur ouest du salon
	local windows = {
		{ 20, 4.5, -0.4, "fenêtre bois", 0 }, { 100, 4.5, -0.4, "fenêtre bois", 0 },
		{ 20, 4.5, 90.4, "fenêtre bois", 0 }, { 100, 4.5, 90.4, "fenêtre bois", 0 },
		{ 20, 16.5, -0.4, "fenêtre bois", 0 }, { 100, 16.5, -0.4, "fenêtre bois", 0 },
		{ 20, 16.5, 90.4, "fenêtre bois", 0 }, { 100, 16.5, 90.4, "fenêtre bois", 0 },
		{ 20, 28.5, -0.4, "fenêtre rouille", 0 }, { 100, 28.5, -0.4, "fenêtre rouille", 0 },
	}
	for _, w in ipairs(windows) do
		placeFitted(w[4], CFrame.new(w[1], w[2], w[3]), Vector3.new(3, 4, 0.5), folders["Décor"])
	end
	placeFitted("cheminée", CFrame.new(1.5, 1.5, 22) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(4, 3, 2.5), folders["Décor"])
	for _, s in ipairs(Data.slabs) do
		makeBox(folders.Dalles, s, s.mat, s.name or "Dalle")
	end
	for _, s in ipairs(Data.steps) do
		makeBox(folders.Escaliers, s, s.mat, "Marche")
	end
	local furnParts = {}
	for i, f in ipairs(Data.furniture) do
		local part = makeBox(folders.Meubles, f, f.mat, f.name)
		furnParts[i] = part
		if f.name == "coffre à jouets" then
			CollectionService:AddTag(part, "MusicBox")
		end
		if f.name == "cheval à bascule" then
			CollectionService:AddTag(part, "Rocking")
		end
		if f.name == "coffre verrouillé" then
			CollectionService:AddTag(part, "Chest")
		end
		if f.name == "cercueil" then
			part.CanCollide = false -- décoratif : le point de spawn est juste dessous
			CollectionService:AddTag(part, "Tombe")
		end
	end
	local paintingCount = 0
	for _, d in ipairs(Data.decor) do
		local deco = makeBox(folders["Décor"], d, d.mat, d.name)
		if string.sub(d.name, 1, 6) == "rideau" then
			CollectionService:AddTag(deco, "Curtain")
		end
		if string.sub(d.name, 1, 7) == "tableau" then
			CollectionService:AddTag(deco, "Tableau")
			local picture = ServerStorage:FindFirstChild("Decor")
			local picNames = { "tableau", "tableau2", "tableau3", "tableau4", "tableau5", "tableau6" }
			local template = picture and picture:FindFirstChild(picNames[paintingCount % #picNames + 1])
			paintingCount += 1
			if template then
				local model = template:Clone()
				model:PivotTo(deco.CFrame)
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = false
					end
				end
				deco.Transparency = 1
				model.Parent = folders["Décor"]
			end
		end
	end

	-- Portes intérieures : panneaux dans chaque ouverture (Props les ouvre et les ferme)
	for _, d in ipairs(Data.doors) do
		if not d.puzzle and not d.front then
			local base = Data.base[d.level]
			local b
			if d.orient == "v" then
				b = { x0 = d.line - 0.25, x1 = d.line + 0.25, z0 = d.c - d.w / 2, z1 = d.c + d.w / 2 }
			else
				b = { x0 = d.c - d.w / 2, x1 = d.c + d.w / 2, z0 = d.line - 0.25, z1 = d.line + 0.25 }
			end
			b.y0 = base
			b.y1 = base + 7
			local panel = makeBox(folders.Meubles, b, "bois", "Porte")
			CollectionService:AddTag(panel, "Door")
			if d.lock then
				panel:SetAttribute("Lock", d.lock)
			end
		end
	end

	-- Décor posé sur les meubles (ou modèles Studio de ServerStorage/Decor)
	DecorKit.dress(folders["Décor"], Data.furniture, furnParts)

	-- Cachettes : une par armoire
	for _, h in ipairs(Data.hiding) do
		local spot = makeMarker(folders.Props, h.pos, h.size, h.name, "Hiding")
		spot:SetAttribute("Kind", h.kind)
		if h.posture then
			spot:SetAttribute("Posture", h.posture)
		end
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
			placeDecorModel("lampe plafond", p.pos, bulb)
			bulb.Transparency = 0.2
			local light = Instance.new("PointLight")
			light.Range = 24
			light.Brightness = 1.2
			light.Color = LAMP_PALETTE[1]
			light.Shadows = false
			light.Parent = bulb
			table.insert(lamps, { room = p.room, part = bulb, light = light })
		elseif p.tag == "Interactable" then
			local item = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(190, 170, 140), Enum.Material.SmoothPlastic, "Interactable")
			item:SetAttribute("Kind", p.kind)
		elseif p.tag == "Mirror" then
			local glass = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(170, 190, 200), Enum.Material.Glass, "Mirror")
			glass.Transparency = 0.45
		elseif p.tag == "TV" then
			local tv = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, "TV")
			placeDecorModel("télévision", p.pos, tv)
		elseif p.tag == "Horloge" then
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(120, 95, 60), Enum.Material.Wood, "Horloge")
		elseif p.tag == "IntroPhoto" then
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(225, 215, 190), Enum.Material.SmoothPlastic, "IntroPhoto")
		elseif p.tag == "Switch" then
			local sw = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(200, 200, 195), Enum.Material.SmoothPlastic, "Switch")
			sw:SetAttribute("Label", p.name)
		elseif p.tag == "Phone" then
			local phone = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic, "Phone")
			phone:SetAttribute("Label", p.name)
			placeDecorModel("téléphone", p.pos, phone)
		elseif p.tag == "CaveDoor" then
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(70, 72, 78), Enum.Material.Metal, "CaveDoor")
		elseif p.tag == "Coffret" then
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(90, 60, 40), Enum.Material.Wood, "Coffret")
		elseif p.tag == "Mannequin" then
			-- Mannequin : une pièce invisible porte l'invite et le pivot (Quests) ; le modèle y est soudé
			local anchor = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(230, 225, 215), Enum.Material.SmoothPlastic, "Mannequin")
			anchor.Transparency = 1
			weldDecorModel("mannequin", anchor)
		elseif p.tag == "Statue" then
			-- Statue de pierre : son orientation se tourne (énigme des statues, Quests)
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(190, 185, 175), Enum.Material.Marble, "Statue")
		elseif p.tag == "Trappe" or p.tag == "TrappeGrenier" or p.tag == "TrappePalier" then
			-- Trappe pleine : elle bloque le passage tant qu'elle n'est pas ouverte (Quests)
			local hatch = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(78, 56, 38), Enum.Material.Wood, p.tag)
			hatch.CanCollide = true
			hatch.Transparency = 0
		elseif p.tag == "Respire" then
			-- Panneau du mur qui respire : presque invisible, sa zone sert à l'interaction
			local panel = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(70, 60, 60), Enum.Material.Slate, "Respire")
			panel.Transparency = 0.85
		elseif p.tag == "Plaque" then
			local plaque = makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(150, 140, 120), Enum.Material.Metal, "Interactable")
			plaque:SetAttribute("Kind", "plaque du cercueil")
		elseif p.tag == "Key" then
			-- Clé de la sortie, dans la malle : son invite est activée par Objectives.unlockKey
			makeVisible(folders.Props, p.pos, p.size, p.name,
				Color3.fromRGB(200, 170, 60), Enum.Material.Metal, "Key")
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
	-- Route au-delà du portail, pour la voiture (cinématique de fuite)
	makeBox(garden, { x0 = 50, x1 = 70, y0 = -0.2, y1 = 0, z0 = 150, z1 = 260 }, "asphalte", "route")
	-- Escalier extérieur qui descend au sous-sol
	for _, p in ipairs(Data.garden.steps or {}) do
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
	-- Ombres plus douces et éclairage indirect : le plus proche possible du mode Future,
	-- qui ne se règle que dans Studio (Lighting.Technology n'est pas modifiable par code)
	pcall(function()
		Lighting.ShadowSoftness = 0.35
	end)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

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

	-- Profondeur de champ très légère : la lampe torche et les objets proches restent nets
	local dof = effect("DepthOfFieldEffect", "TombeDepthOfField")
	dof.FocusDistance = 6
	dof.InFocusRadius = 12
	dof.NearIntensity = 0
	dof.FarIntensity = 0.15
end

-- Ombres des lampes : les 4 lampes allumées les plus proches d'un joueur projettent des ombres.
-- Coût de rendu borné, et les ombres suivent les joueurs dans toute la maison.
local MAX_SHADOW_LAMPS = 4
local SHADOW_RANGE = 40

function MapBuilder.startShadowLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			local roots = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					table.insert(roots, root.Position)
				end
			end

			local candidates = {}
			for _, lamp in ipairs(lamps) do
				if lamp.light.Enabled and #roots > 0 then
					local best = math.huge
					for _, pos in ipairs(roots) do
						best = math.min(best, (pos - lamp.part.Position).Magnitude)
					end
					if best < SHADOW_RANGE then
						table.insert(candidates, { lamp = lamp, d = best })
					end
				end
			end
			table.sort(candidates, function(a, b)
				return a.d < b.d
			end)

			local want = {}
			for i = 1, math.min(MAX_SHADOW_LAMPS, #candidates) do
				want[candidates[i].lamp] = true
			end
			for _, lamp in ipairs(lamps) do
				lamp.light.Shadows = want[lamp] == true
			end
		end
	end)
end

-- Courant rétabli pendant duration secondes : toutes les lampes s'allument, même dans le noir
function MapBuilder.powerOn(duration)
	for _, lamp in ipairs(lamps) do
		lamp.light.Enabled = true
		lamp.light.Brightness = 1.4
		lamp.part.Transparency = 0.2
	end
	task.delay(duration, function()
		for _, lamp in ipairs(lamps) do
			local lit = not darkRooms[lamp.room]
			lamp.light.Enabled = lit
			lamp.light.Brightness = 1.2
			lamp.part.Transparency = lit and 0.2 or 0.9
		end
	end)
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
	pcall(Atmosphere.build)
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
	-- Papier du code : un emplacement tiré, la valeur du code vient de la seed (voir Quests)
	for _, slot in ipairs(pick(rng, slots.note, 1)) do
		makeVisible(round, slot.pos, slot.size, "Papier " .. slot.name,
			Color3.fromRGB(235, 225, 190), Enum.Material.SmoothPlastic, "CodeNote")
	end
	-- Clé de la salle de bain : ouvre la porte verrouillée de la salle de bain
	for _, slot in ipairs(pick(rng, slots.bathkey, 1)) do
		makeVisible(round, slot.pos, slot.size, "Clé salle de bain",
			Color3.fromRGB(190, 160, 60), Enum.Material.Metal, "BathKey")
	end
	-- Fausses clés : elles ne servent à rien
	for i, slot in ipairs(pick(rng, slots.decoy, 3)) do
		makeVisible(round, slot.pos, slot.size, "Fausse clé " .. slot.name,
			Color3.fromRGB(170, 150, 70), Enum.Material.Metal, (i == 1) and "CaveKey" or "Decoy")
	end
	for _, slot in ipairs(pick(rng, slots.battery, 3)) do
		makeVisible(round, slot.pos, slot.size, "Pile " .. slot.name,
			Color3.fromRGB(70, 110, 170), Enum.Material.SmoothPlastic, "Battery")
	end

	-- Cailloux au sol, dans les pièces ouvertes : de quoi lancer (un caillou par lancer)
	local open = {}
	for _, r in ipairs(Data.rooms) do
		if not CLOSED_ROOMS[r.id] and r.level ~= "basement" then
			table.insert(open, r)
		end
	end
	for _ = 1, PEBBLE_COUNT do
		local r = open[rng:int(1, #open)]
		local x, z = rng:range(r.x0 + 1.5, r.x1 - 1.5), rng:range(r.z0 + 1.5, r.z1 - 1.5)
		local base = Data.base[r.level]
		local ray = Workspace:Raycast(Vector3.new(x, base + 4, z), Vector3.new(0, -6, 0))
		local onFloor = ray and math.abs(ray.Position.Y - base) < 0.3
		if onFloor and not (x > Data.stair[1] - 2 and x < Data.stair[3] + 2 and z > Data.stair[2] - 2 and z < Data.stair[4] + 2) then
			makeVisible(round, { x, Data.base[r.level] + 0.2, z }, { 0.5, 0.4, 0.5 }, "Caillou",
				Color3.fromRGB(105, 100, 96), Enum.Material.Slate, "Throwable")
		end
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
function MapBuilder.roomAt(pos, atFloor)
	-- Un point de repère posé au sol (atFloor) ou la racine d'un personnage (~3 studs au-dessus)
	local floorY = atFloor and pos.Y or pos.Y - 2.5
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

function MapBuilder.roomName(roomId)
	for _, r in ipairs(Data.rooms) do
		if r.id == roomId then
			return r.name
		end
	end
	return "une pièce"
end

-- Éteint les lampes d'une pièce pendant seconds secondes (une pièce noire le reste)
function MapBuilder.lampOff(roomId, seconds)
	if darkRooms[roomId] then
		return
	end
	for _, lamp in ipairs(lamps) do
		if lamp.room == roomId then
			lamp.light.Enabled = false
			lamp.part.Transparency = 0.9
		end
	end
	task.delay(seconds, function()
		for _, lamp in ipairs(lamps) do
			if lamp.room == roomId then
				lamp.light.Enabled = not darkRooms[roomId]
				lamp.part.Transparency = 0.2
			end
		end
	end)
end

function MapBuilder.isDark(roomId)
	return roomId ~= nil and darkRooms[roomId] == true
end

return MapBuilder

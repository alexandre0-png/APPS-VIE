-- ModuleScript : ServerScriptService/Builder
-- Construit TOUT le visuel avec des Parts, matériaux et particules de base Roblox (aucun asset externe).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))
local Castle = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Castle"))
local GuardMod = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Guard")) -- pose de marche
local AssetsMod = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Assets")) -- fonctions pures (fitHeight)
local PlacementMod = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Placement")) -- pose planifiée du décor
local MapGeoMod = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MapGeo")) -- géométrie de la carte 700 x 500 (REFONTE lot 2)
local TrapsMod = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Traps")) -- plan des pièges des territoires (REFONTE lot 4)
local DecorMod = require(script.Parent:WaitForChild("Decor")) -- lot 8B-décor : modèles Blender des lots 15 à 17 (repli procédural)
PlacementMod.MapGeo = MapGeoMod
PlacementMod.yield = function()
	task.wait()
end

local Builder = {}

local FONT = Enum.Font.GothamBold
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function ball(props, parent)
	props.Shape = Enum.PartType.Ball
	props.CanCollide = false
	return part(props, parent)
end

local function sign(adornee, text, color, offsetY, width)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Adornee = adornee
	g.Size = UDim2.fromOffset(width or 200, 56)
	g.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	g.MaxDistance = 70
	g.AlwaysOnTop = false
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.TextSize = 18
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	t.Text = text
	t.Parent = g
	g.Parent = adornee
	return t
end
Builder.sign = sign

---------------------------------------------------------------- Œuf
-- Chargeur de modèles d'œufs (module Assets, branché par Main). Nil = apparence par défaut partout.
local eggAssets = nil
local builtPlots = {} -- bases des joueurs (Builder.build) pour le dallage
local builtCastle = nil -- monde du château (Scenery.castle) pour l'habillage Blender différé
local builtGuards = {} -- { model, rival } des gardiens construits (habillage Blender différé)
function Builder.setAssets(a)
	eggAssets = a
end

-- Habille l'œuf `p` avec une copie du modèle Roblox de sa rareté : la Part reste la racine (tags, prompts, soudure au joueur, animations),
-- elle devient invisible et le modèle y est soudé par des Weld enfants des parts du modèle (pas de Weld direct sur l'œuf : l'animation de
-- course cherche le Weld du joueur). Retourne true si le modèle est en place ; en cas d'erreur, tout est défait (apparence par défaut).
local function dressEgg(p, tier)
	local clone = eggAssets and eggAssets.cloneEgg(tier)
	if not clone then
		return false
	end
	local ok = pcall(function()
		if not clone:IsA("Model") then
			error("pas un Model")
		end
		-- lot 9 : échelle d'après la pièce `Coque` (couronne, auréole et ailes dépassent), repli sur le modèle entier
		local fitted, why = AssetsMod.fitByPart(clone, Config.Assets.eggShellPart or "Coque", Config.eggHeight(tier))
		if not fitted then
			error(why)
		end
		-- plafond relatif à l'emplacement et au joueur : un modèle très large ou trop haut est ramené à la borne (jamais d'œuf géant)
		local ext = clone:GetExtentsSize()
		local f = Config.fitScale({ X = ext.X, Y = ext.Y, Z = ext.Z }, Config.eggMaxSize())
		if f < 1 then
			clone:ScaleTo(clone:GetScale() * f)
		end
		local cf = clone:GetBoundingBox()
		clone:PivotTo(CFrame.new() * cf:ToObjectSpace(clone:GetPivot()))
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				local w = Instance.new("Weld")
				w.Part0 = p
				w.Part1 = d
				w.C0 = d.CFrame
				w.Parent = d
			end
		end
		-- lot 9 : coques de verre (Ultra Rare, Divin) forcées par le code (pièce `Coque` non nommée « Verre » dans le modèle)
		local look = Config.eggLook(tier)
		if look and look.glass then
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") and AssetsMod.baseName(d.Name) == (Config.Assets.eggShellPart or "Coque") then
					d.Material = Enum.Material.Glass
					d.Transparency = look.glass
				end
			end
		end
		clone.Name = "Skin"
		clone.Parent = p
	end)
	if not ok then
		pcall(function()
			clone:Destroy()
		end)
		return false
	end
	p.Transparency = 1
	return true
end

-- Halo décoratif soudé à l'œuf (sphère translucide ou anneau). Le client le fait tourner / scintiller (tag EggHalo, attributs Spin / Flicker).
local function addHalo(p, h)
	local halo = Instance.new("Part")
	halo.Name = "Halo"
	halo.Material = Enum.Material.Neon
	halo.Color = h.color
	halo.Transparency = h.transparency
	halo.CanCollide = false
	halo.CanTouch = false
	halo.CanQuery = false
	halo.Massless = true
	halo.Anchored = false
	halo.CastShadow = false
	local rot = CFrame.new()
	if h.shape == "ring" then
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.14, 3.2 * h.scale, 3.2 * h.scale)
		rot = CFrame.Angles(0, 0, math.rad(90))
	else
		halo.Shape = Enum.PartType.Ball
		halo.Size = Vector3.new(3.2 * h.scale, 3.2 * h.scale, 3.2 * h.scale)
	end
	local w = Instance.new("Weld")
	w.Name = "HaloWeld"
	w.Part0 = p
	w.Part1 = halo
	w.C0 = rot
	w.Parent = halo
	halo:SetAttribute("Spin", h.spin or 0)
	halo:SetAttribute("Flicker", h.flicker == true)
	halo:SetAttribute("BaseT", h.transparency)
	CollectionService:AddTag(halo, "EggHalo")
	halo.Parent = p
end

-- Lot 9 (A.5) : détails procéduraux d'un œuf (pièces soudées, <= Config.EggFx.maxParts). L'emblème est une RUNE-ŒUF (losange creux à pointe
-- arrondie : 4 barres + 1 bille), jamais le logo Roblox. Retourne le nombre de Parts créées.
local function weldTo(p, part, cf)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	local w = Instance.new("Weld")
	w.Part0 = p
	w.Part1 = part
	w.C0 = cf
	w.Parent = part
	part.Parent = p
	return part
end
local function detailPart(name, size, color, material, shape)
	local d = Instance.new("Part")
	d.Name = name
	d.Size = size
	d.Color = color
	d.Material = material or Enum.Material.SmoothPlastic
	if shape then
		d.Shape = shape
	end
	d.TopSurface = Enum.SurfaceType.Smooth
	d.BottomSurface = Enum.SurfaceType.Smooth
	return d
end
function Builder.eggDetails(p, look)
	local n = 0
	local R, H = p.Size.X / 2, p.Size.Y / 2
	local function add(name, size, color, cf, material, shape)
		if n >= Config.EggFx.maxParts then
			return nil
		end
		n += 1
		return weldTo(p, detailPart(name, size, color, material, shape), cf)
	end
	-- emblème : rune-œuf sur la face avant (-Z)
	if look.emblem then
		local z = -R * 0.98
		for k, a in ipairs({ 35, -35, 145, -145 }) do
			local ang = math.rad(a)
			add("Embleme", Vector3.new(0.12, 0.5, 0.08), look.emblem, CFrame.new(math.sin(ang) * 0.18, 0.15 + math.cos(ang) * 0.22 * (k <= 2 and 1 or 0.7), z) * CFrame.Angles(0, 0, -ang), Enum.Material.Neon)
		end
		add("Embleme", Vector3.new(0.16, 0.16, 0.16), look.emblem, CFrame.new(0, 0.15, z), Enum.Material.Neon, Enum.PartType.Ball)
	end
	local d = look.details or {}
	local function around(count, radius, y, fn)
		for i = 1, count do
			local a = (i - 1) / count * math.pi * 2
			fn(i, CFrame.new(math.cos(a) * radius, y, math.sin(a) * radius) * CFrame.Angles(0, -a, 0))
		end
	end
	if d.spots then
		around(d.spots.n, R * 0.92, 0.5, function(_, cf)
			add("Motif", Vector3.new(0.5, 0.5, 0.5), d.spots.color, cf, nil, Enum.PartType.Ball)
		end)
	end
	if d.pixels then
		around(d.pixels.n, R * 0.95, -0.3, function(i, cf)
			add("Motif", Vector3.new(0.3, 0.3, 0.3), d.pixels.color, cf * CFrame.new(0, (i % 2) * 0.4, 0))
		end)
	end
	if d.stripes or d.cracks or d.shards then
		local sp = d.stripes or d.cracks or d.shards
		local mat = d.cracks and Enum.Material.Neon or nil
		around(sp.n, R * 0.97, 0.2, function(i, cf)
			add(d.cracks and "Fissure" or "Motif", Vector3.new(0.12, 1.2, 0.08), sp.color, cf * CFrame.Angles(0, 0, math.rad(25 * (i % 2 == 0 and 1 or -1))), mat)
		end)
	end
	if d.ring then
		add("Anneau", Vector3.new(0.12, R * 2.6, R * 2.6), d.ring.color, CFrame.Angles(0, 0, math.rad(90 + d.ring.tilt)), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if d.ring2 then
		add("Anneau", Vector3.new(0.12, R * 2.6, R * 2.6), d.ring2.color, CFrame.Angles(0, math.rad(90), math.rad(90 + d.ring2.tilt)), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if d.groundRing then
		add("Anneau", Vector3.new(0.1, R * 3, R * 3), d.groundRing.color, CFrame.new(0, -H + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if d.crystals then
		around(d.crystals.n, R * 1.15, -H + 0.4, function(i, cf)
			add("Cristaux", Vector3.new(0.3, 0.7 + (i % 2) * 0.3, 0.3), d.crystals.color, cf * CFrame.Angles(math.rad(15), 0, math.rad(15)), Enum.Material.Glass)
		end)
	end
	if d.crown then
		around(5, R * 0.45, H + 0.15, function(_, cf)
			add("Couronne", Vector3.new(0.18, 0.45, 0.18), d.crown.color, cf, Enum.Material.Metal)
		end)
	end
	if d.chain then
		for i = 1, d.chain.n do
			local t = (i - 0.5) / d.chain.n
			add("Chaine", Vector3.new(0.28, 0.12, 0.2), d.chain.color, CFrame.new((t - 0.5) * R * 2.1, (0.5 - t) * H * 1.6, -R * 0.9) * CFrame.Angles(0, 0, math.rad(40 + 90 * (i % 2))), Enum.Material.Metal)
		end
	end
	if d.stars then
		around(d.stars.n, R * 1.3, H * 0.6, function(_, cf)
			add("Etoiles", Vector3.new(0.3, 0.3, 0.3), d.stars.color, cf * CFrame.Angles(math.rad(45), 0, math.rad(45)), Enum.Material.Neon)
		end)
	end
	if d.wings then
		for _, sx in ipairs({ -1, 1 }) do
			add("Ailes", Vector3.new(1.4, 1, 0.1), d.wings.color, CFrame.new(sx * (R + 0.6), 0.3, 0.3) * CFrame.Angles(0, 0, math.rad(25 * sx)))
		end
	end
	if d.halo then
		add("Aureole", Vector3.new(0.1, R * 1.4, R * 1.4), d.halo.color, CFrame.new(0, H + 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	return n
end

-- Cubes en orbite (A.5) : soudés à un pivot invisible tagué EggHalo que le client fait tourner (Spin = tours/s x 2 pi).
local function addOrbit(p, o, budget)
	if budget <= 0 then
		return 0
	end
	local pivot = Instance.new("Part")
	pivot.Name = "Halo"
	pivot.Size = Vector3.new(0.2, 0.2, 0.2)
	pivot.Transparency = 1
	weldTo(p, pivot, CFrame.new())
	local hw = pivot:FindFirstChildOfClass("Weld")
	if hw then
		hw.Name = "HaloWeld"
	end
	pivot:SetAttribute("Spin", o.rps * math.pi * 2)
	pivot:SetAttribute("Flicker", false)
	pivot:SetAttribute("BaseT", 1)
	CollectionService:AddTag(pivot, "EggHalo")
	local count = math.min(o.n, budget - 1)
	local R = p.Size.X / 2 + 0.7
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		local c = detailPart("Orbite", Vector3.new(0.3, 0.3, 0.3), o.color, Enum.Material.Neon)
		weldTo(pivot, c, CFrame.new(math.cos(a) * R, 0.3 * math.sin(a * 2), math.sin(a) * R))
	end
	return count + 1
end

local function addParticles(p, pa)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(pa.color)
	e.Rate = pa.rate
	e.Lifetime = NumberRange.new(pa.life * 0.7, pa.life)
	e.Speed = NumberRange.new(pa.speed * 0.5, pa.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, pa.size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.8
	e.Parent = p
end

function Builder.egg(tier, anchored)
	local look = Config.EggFx.Enabled and Config.eggLook(tier) or nil
	local c = look and look.light or Config.TIERS[tier].color
	local p = Instance.new("Part")
	p.Name = "Egg"
	p.Size = Vector3.new(2.4, 3.2, 2.4)
	if look then
		p.Color = look.color
		p.Material = Enum.Material[look.material]
	else
		p.Color = Color3.fromRGB(255, 244, 222):Lerp(c, 0.35)
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Anchored = anchored ~= false
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	local l = Instance.new("PointLight")
	l.Color = c
	l.Range = 7
	l.Brightness = look and look.brightness or 1.2
	l.Parent = p
	if dressEgg(p, tier) then
		m:Destroy() -- la sphère n'est plus visible : inutile de la garder
		l.Brightness = 1.2
	elseif look then
		local used = Builder.eggDetails(p, look)
		if look.halo and used < Config.EggFx.maxParts then
			addHalo(p, look.halo)
			used += 1
		end
		if look.orbit then
			used += addOrbit(p, look.orbit, Config.EggFx.maxParts - used)
		end
		if look.particles then
			addParticles(p, look.particles)
		end
		p:SetAttribute("EggParts", used)
		if look.glass then
			p.Transparency = look.glass
		end
	end
	if look and look.orbit and p:FindFirstChild("Skin") then
		addOrbit(p, look.orbit, Config.EggFx.maxParts) -- les effets restent dans le code, même avec le modèle Blender
	end
	if look and look.particles and p:FindFirstChild("Skin") then
		addParticles(p, look.particles)
	end
	return p
end

---------------------------------------------------------------- Pet (modèle 3D en Parts)
-- Retourne (modèle, hauteur de levage). Le modèle regarde vers -Z.
-- Habille un pet avec le modèle Blender de Config.Assets.pets si disponible (même contrat que le pet procédural : Model, PrimaryPart, hauteur de
-- levage). Retourne (modèle, levage, hauteur d'étiquette) ou nil : l'appelant garde alors le pet procédural. Ne lève jamais d'erreur.
local function customPet(petIdx, size)
	local clone = eggAssets and eggAssets.clonePet and eggAssets.clonePet(petIdx)
	if not clone then
		return nil
	end
	local ok, lift, labelY = pcall(function()
		if not clone:IsA("Model") then
			error("pas un Model")
		end
		local height = Config.petTargetHeight(Config.PETS[petIdx].tier, size.scale)
		local fitted, why = AssetsMod.fitHeight(clone, height) -- mesure, mise à l'échelle sur la hauteur cible, vérification ±10 % (sinon pet procédural)
		if not fitted then
			error(why)
		end
		local first = nil
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				first = first or d
			end
		end
		if not first then
			error("aucune part")
		end
		clone.PrimaryPart = clone.PrimaryPart or first
		clone.Name = "Pet"
		return height / 2, height + 1.2
	end)
	if not ok then
		pcall(function()
			clone:Destroy()
		end)
		return nil
	end
	return clone, lift, labelY
end

function Builder.pet(petIdx, sizeIdx, mutIdx)
	local def = Config.PETS[petIdx]
	local size = Config.SIZES[sizeIdx]
	local mut = Config.MUTS[mutIdx]
	local custom, customLift, customLabel = customPet(petIdx, size)
	if custom then
		custom:SetAttribute("Tier", def.tier)
		return custom, customLift, customLabel
	end
	local R = 0.9 * math.min(size.scale, 1.6) -- pet procédural : même échelle réduite que les modèles Blender
	local model = Instance.new("Model")
	model.Name = "Pet"

	local bodyColor = def.color
	local bodyMat = Enum.Material.SmoothPlastic
	if mut.color then
		bodyColor = mut.color
		bodyMat = Enum.Material.Neon
	elseif mut.rainbow then
		bodyColor = Color3.fromRGB(255, 120, 220)
		bodyMat = Enum.Material.Neon
	end

	local body = ball({ Name = "Body", Size = Vector3.new(2 * R, 2 * R, 2 * R), CFrame = CFrame.new(0, 0, 0), Color = bodyColor, Material = bodyMat }, model)
	model.PrimaryPart = body
	local dark = Color3.fromRGB(25, 25, 30)

	local function addBall(name, off, sz, col, mat)
		return ball({ Name = name, Size = Vector3.new(sz, sz, sz), CFrame = CFrame.new(off), Color = col, Material = mat or Enum.Material.SmoothPlastic }, model)
	end
	local function addBlock(name, off, sz, col, rotZ, mat)
		return part({ Name = name, CanCollide = false, Size = sz, CFrame = CFrame.new(off) * CFrame.Angles(0, 0, rotZ or 0), Color = col, Material = mat or Enum.Material.SmoothPlastic }, model)
	end

	-- yeux
	addBall("EyeL", Vector3.new(-0.42 * R, 0.25 * R, -0.86 * R), 0.36 * R, dark)
	addBall("EyeR", Vector3.new(0.42 * R, 0.25 * R, -0.86 * R), 0.36 * R, dark)

	-- paupières (invisibles, le client les affiche à chaque clignement) et bouche (animée côté client)
	for _, side in ipairs({ { "LidL", -0.42 }, { "LidR", 0.42 } }) do
		local lid = addBall(side[1], Vector3.new(side[2] * R, 0.25 * R, -0.88 * R), 0.42 * R, bodyColor)
		lid.Transparency = 1
	end
	addBlock("Mouth", Vector3.new(0, -0.18 * R, -0.93 * R), Vector3.new(0.34 * R, 0.06 * R, 0.1 * R), dark)

	-- reflets dans les yeux, joues et pieds
	addBall("ShineL", Vector3.new(-0.46 * R, 0.34 * R, -1.0 * R), 0.13 * R, Color3.new(1, 1, 1))
	addBall("ShineR", Vector3.new(0.38 * R, 0.34 * R, -1.0 * R), 0.13 * R, Color3.new(1, 1, 1))
	if not Config.tierAtLeast(def.tier, "announce") then -- joues roses jusqu'à Épique
		addBall("CheekL", Vector3.new(-0.72 * R, -0.05 * R, -0.68 * R), 0.26 * R, Color3.fromRGB(255, 150, 170))
		addBall("CheekR", Vector3.new(0.72 * R, -0.05 * R, -0.68 * R), 0.26 * R, Color3.fromRGB(255, 150, 170))
	end
	if def.extra ~= "tentacles" then
		local footCol = bodyColor:Lerp(Color3.new(0, 0, 0), 0.25)
		addBall("FootL", Vector3.new(-0.45 * R, -0.92 * R, -0.15 * R), 0.55 * R, footCol)
		addBall("FootR", Vector3.new(0.45 * R, -0.92 * R, -0.15 * R), 0.55 * R, footCol)
	end

	-- oreilles
	local ears = def.ears
	if ears == "round" then
		addBall("EarL", Vector3.new(-0.62 * R, 0.95 * R, -0.05 * R), 0.62 * R, bodyColor)
		addBall("EarR", Vector3.new(0.62 * R, 0.95 * R, -0.05 * R), 0.62 * R, bodyColor)
	elseif ears == "long" then
		addBlock("EarL", Vector3.new(-0.4 * R, 1.5 * R, 0), Vector3.new(0.36 * R, 1.3 * R, 0.3 * R), bodyColor, 0.15)
		addBlock("EarR", Vector3.new(0.4 * R, 1.5 * R, 0), Vector3.new(0.36 * R, 1.3 * R, 0.3 * R), bodyColor, -0.15)
	elseif ears == "point" then
		addBlock("EarL", Vector3.new(-0.6 * R, 1.05 * R, 0), Vector3.new(0.4 * R, 0.8 * R, 0.3 * R), bodyColor, 0.5)
		addBlock("EarR", Vector3.new(0.6 * R, 1.05 * R, 0), Vector3.new(0.4 * R, 0.8 * R, 0.3 * R), bodyColor, -0.5)
	elseif ears == "floppy" then
		addBlock("EarL", Vector3.new(-1.0 * R, 0.35 * R, 0), Vector3.new(0.35 * R, 0.9 * R, 0.5 * R), Color3.fromRGB(110, 70, 40), 0.2)
		addBlock("EarR", Vector3.new(1.0 * R, 0.35 * R, 0), Vector3.new(0.35 * R, 0.9 * R, 0.5 * R), Color3.fromRGB(110, 70, 40), -0.2)
	end

	-- extras
	local lift = R
	local extra = def.extra
	if extra == "beak" then
		addBlock("Beak", Vector3.new(0, -0.05 * R, -1.0 * R), Vector3.new(0.5 * R, 0.3 * R, 0.5 * R), Color3.fromRGB(255, 150, 30))
	elseif extra == "tail" then
		addBall("Tail", Vector3.new(0, -0.1 * R, 1.05 * R), 0.55 * R, bodyColor)
	elseif extra == "mane" then
		addBall("Mane", Vector3.new(0, 0, 0.3 * R), 2.5 * R, Color3.fromRGB(150, 90, 30))
		body.Size = Vector3.new(1.9 * R, 1.9 * R, 1.9 * R)
	elseif extra == "horn" then
		addBlock("Horn", Vector3.new(0, 1.2 * R, -0.45 * R), Vector3.new(0.25 * R, 0.9 * R, 0.25 * R), Color3.fromRGB(255, 215, 90), 0, Enum.Material.Neon)
	elseif extra == "wings" then
		addBlock("WingL", Vector3.new(-1.1 * R, 0.35 * R, 0.3 * R), Vector3.new(0.15 * R, 1.1 * R, 1.3 * R), bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), 0.6)
		addBlock("WingR", Vector3.new(1.1 * R, 0.35 * R, 0.3 * R), Vector3.new(0.15 * R, 1.1 * R, 1.3 * R), bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), -0.6)
		addBlock("Horn", Vector3.new(0, 1.05 * R, -0.5 * R), Vector3.new(0.22 * R, 0.6 * R, 0.22 * R), Color3.fromRGB(255, 240, 200))
	elseif extra == "tentacles" then
		for i, o in ipairs({ { -0.5, -0.5 }, { 0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, 0.5 } }) do
			addBlock("Tent" .. i, Vector3.new(o[1] * R, -1.25 * R, o[2] * R), Vector3.new(0.3 * R, 1.1 * R, 0.3 * R), bodyColor)
		end
		lift = 1.8 * R
	elseif extra == "antenna" then
		addBlock("Ant", Vector3.new(0, 1.3 * R, 0), Vector3.new(0.12 * R, 0.8 * R, 0.12 * R), bodyColor)
		addBall("AntTip", Vector3.new(0, 1.8 * R, 0), 0.35 * R, Color3.fromRGB(255, 80, 200), Enum.Material.Neon)
	end

	-- étincelles dorées discrètes : le pet « produit » des pièces
	local coin = Instance.new("ParticleEmitter")
	coin.Texture = SPARK
	coin.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	coin.Rate = 0.7
	coin.Lifetime = NumberRange.new(1.2, 1.8)
	coin.Speed = NumberRange.new(1, 2)
	coin.Acceleration = Vector3.new(0, 3, 0)
	coin.SpreadAngle = Vector2.new(60, 60)
	coin.LightEmission = 1
	coin.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	coin.Parent = body

	-- mutation : particules
	if mut.color or mut.rainbow then
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Rate = 8
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * R), NumberSequenceKeypoint.new(1, 0) })
		if mut.rainbow then
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 255, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
			})
		else
			e.Color = ColorSequence.new(mut.color)
		end
		e.Parent = body
	end

	-- étiquette
	model:SetAttribute("Height", lift)
	CollectionService:AddTag(model, "PetFace") -- visage animé côté client (clignement, regard, bouche)
	model:SetAttribute("Tier", def.tier) -- états des pets (capacité des raretés élevées)
	return model, lift, 2.3 * R + 1.5
end

---------------------------------------------------------------- Gardien
-- Remplace l'apparence procédurale d'un gardien par un modèle Blender : le Body devient invisible (il porte l'étiquette et sert de repère),
-- les autres Parts procédurales sont détruites, le modèle est mis à l'échelle (hauteur en studs), posé au sol sous le Body et ancré.
-- Retourne true si remplacé ; sinon le gardien procédural est conservé. Ne lève jamais d'erreur.
local function fitGuard(model, clone, height)
	local ok = pcall(function()
		local body = model.PrimaryPart
		local fitted, why = AssetsMod.fitHeight(clone, height)
		if not fitted then
			error(why)
		end
		local bbox, size2 = clone:GetBoundingBox()
		clone:PivotTo(body.CFrame * CFrame.new(0, -2.4 + size2.Y / 2, 0) * bbox:ToObjectSpace(clone:GetPivot()))
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("BasePart") and c ~= body then
				c:Destroy()
			end
		end
		body.Transparency = 1
		local label = body:FindFirstChild("Label")
		if label then
			label.StudsOffsetWorldSpace = Vector3.new(0, height + 1.2, 0)
		end
		clone.Name = "Blender"
		clone.Parent = model
	end)
	if not ok then
		pcall(function()
			clone:Destroy()
		end)
	end
	return ok
end

-- Pièce d'un modèle Blender par son nom de base : « Pics » et « Pics__C0C0C0 » (suffixe de couleur) désignent la même pièce.
local function findNamed(model, base)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == base or d.Name:match("^(.-)__%x%x%x%x%x%x$") == base) then
			return d
		end
	end
	return nil
end

-- Pose un clone de modèle Blender centré en (x, z), posé sur le sol y0, mis à l'échelle pour que sa plus grande arête horizontale vaille `span`
-- (ou, sans span, pour que sa hauteur vaille `height`), ancré, sans collision. Retourne la table { model, center } ou nil (clone détruit).
local function setModel(clone, x, y0, z, span, height, parent, rotY)
	local ok = pcall(function()
		local _, size = clone:GetBoundingBox()
		if size.Y < 0.05 then
			error("hauteur nulle")
		end
		local longest = math.max(size.X, size.Z)
		if span and longest > 0.05 then
			clone:ScaleTo(span / longest)
		elseif height then
			local fitted, why = AssetsMod.fitHeight(clone, height)
			if not fitted then
				error(why)
			end
		end
		local bbox, size2 = clone:GetBoundingBox()
		clone:PivotTo(CFrame.new(x, y0 + size2.Y / 2, z) * CFrame.Angles(0, rotY or 0, 0) * bbox:ToObjectSpace(clone:GetPivot()))
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		clone.Parent = parent
	end)
	if not ok then
		pcall(function()
			clone:Destroy()
		end)
		return false
	end
	return true
end

-- Habille les pièges du château (pics, lames, boulets) avec les modèles Blender (groupe `traps`). Les Parts procédurales restent les « pilotes » de la
-- logique (positions, couleurs) ; le modèle suit : Pics se lève/descend, Lame tourne autour de l'axe vertical du modèle, Boulet suit la sphère.
-- Un piège dont le modèle n'a pas la pièce animée attendue garde son apparence procédurale. Retourne le nombre de pièges habillés.
function Builder.dressTraps(assets)
	local n = 0
	pcall(function()
		local waited = 0
		while not builtCastle and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
		end
		if not builtCastle then
			return
		end
		local parent = builtCastle.rooms[1] and builtCastle.rooms[1].door and builtCastle.rooms[1].door.Parent
		if not parent then
			return
		end
		for _, rec in ipairs(builtCastle.rooms) do
			for _, v in ipairs(rec.spikes) do
				local clone = assets.cloneModel("traps", "spikes")
				if clone then
					clone.Name = "TrapSpikes"
				end
				if clone and findNamed(clone, "Pics") and setModel(clone, v.wx, 0, v.wz, 6.4, nil, parent) then
					local pics = findNamed(clone, "Pics")
					v.vis = { part = pics, base = pics.CFrame, last = "" }
					v.tip.Transparency = 1
					n = n + 1
				elseif clone then
					clone:Destroy()
				end
			end
			for _, v in ipairs(rec.blades) do
				local clone = assets.cloneModel("traps", "blade")
				if clone then
					clone.Name = "TrapBlade"
				end
				if clone and findNamed(clone, "Lame") and setModel(clone, v.wx, 0, v.wz, v.arm.Size.X, nil, parent) then
					local lame = findNamed(clone, "Lame")
					v.vis = { part = lame, base = lame.CFrame, center = Vector3.new(v.wx, 0, v.wz) }
					v.arm.Transparency = 1
					n = n + 1
				elseif clone then
					clone:Destroy()
				end
			end
			for _, v in ipairs(rec.balls) do
				local clone = assets.cloneModel("traps", "ball")
				if clone then
					clone.Name = "TrapBall"
				end
				local d = v.part.Size.X
				if clone and setModel(clone, v.part.Position.X, -10, v.wz, d, nil, parent) then
					v.vis = { model = clone, d = d }
					v.part.Transparency = 1
					n = n + 1
				elseif clone then
					clone:Destroy()
				end
			end
		end
	end)
	return n
end

-- Habille le château (murs, tours, herses, coffre, torches, drapeaux, bâtiment en fond) avec les modèles Blender (groupes `castle` et `props`), dans un
-- budget de Parts (Config.Assets.castleBudgetParts, pire cas = plafond de Parts de chaque modèle). Les Parts procédurales gardent la collision et la logique
-- (murs, portes, coffre) et deviennent invisibles seulement si leur modèle a été posé. Herse (porte) et Couvercle (coffre) sont animées par le code.
-- Retourne le nombre de modèles posés.
function Builder.dressCastle(assets)
	local n, spent = 0, 0
	pcall(function()
		local waited = 0
		while not builtCastle and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
		end
		local w = builtCastle
		local parent = w and w.rooms[1] and w.rooms[1].door and w.rooms[1].door.Parent
		if not parent then
			return
		end
		local function put(group, key, x, y0, z, span, height, rotY, name)
			local cost = Config.Assets.modelsMaxParts[group .. "." .. key] or 60
			if spent + cost > Config.Assets.castleBudgetParts then
				return nil
			end
			local clone = assets.cloneModel(group, key)
			if not clone then
				return nil
			end
			clone.Name = name
			if setModel(clone, x, y0, z, span, height, parent, rotY) then
				spent = spent + cost
				n = n + 1
				return clone
			end
			return nil
		end
		local W, L = Castle.ROOM_WIDTH, Castle.ROOM_LENGTH
		-- murs : deux segments de L/2 par côté et par salle (les murs procéduraux restent les colliders)
		for r = 1, Castle.ROOMS do
			local placed = 0
			for _, sx in ipairs({ -1, 1 }) do
				for k = 0, 1 do
					local x, z = Castle.toWorld(r, sx * (W / 2 + 1), L / 4 + k * L / 2)
					if put("castle", "wall", x, 0, z, L / 2, nil, math.pi / 2, "CastleWallModel") then
						placed = placed + 1
					end
				end
			end
			if placed == 4 then
				local _, roomZ = Castle.toWorld(r, 0, L / 2)
				for _, c in ipairs(parent:GetChildren()) do
					if c.Name == "CastleWall" and c:IsA("BasePart") and math.abs(c.Position.Z - roomZ) < 1 then
						c.Transparency = 1
					end
				end
			end
		end
		-- tours de chaque côté de l'entrée
		local ex, ez = Castle.toWorld(1, 0, -6)
		for _, sx in ipairs({ -13, 13 }) do
			put("castle", "tower", ex + sx, 0, ez, nil, Config.Assets.targetHeights.tower, 0, "CastleTowerModel")
		end
		-- herses : la pièce Herse monte quand la porte s'ouvre (le pilote procédural garde la collision)
		for _, rec in ipairs(w.rooms) do
			local door = put("castle", "door", rec.doorX, 0, rec.doorZ, W, nil, 0, "CastleDoorModel")
			local herse = door and findNamed(door, "Herse")
			if herse then
				rec.vis = { part = herse, base = herse.CFrame, last = "" }
				rec.door.Transparency = 1
			elseif door then
				door:Destroy()
				n = n - 1
			end
		end
		-- coffre : le Couvercle s'ouvre quand le trésor est pris (Builder.openChest)
		if w.chest then
			local chest = put("props", "chest", w.chest.Position.X, 0, w.chest.Position.Z, nil, Config.Assets.targetHeights.chest, 0, "CastleChestModel")
			local lid = chest and findNamed(chest, "Couvercle")
			if lid then
				w.chestVis = { part = lid, base = lid.CFrame }
				w.chest.Transparency = 1
				local old = parent:FindFirstChild("CastleChestLid")
				if old then
					old.Transparency = 1
				end
			elseif chest then
				chest:Destroy()
				n = n - 1
			end
		end
		-- torches (la lumière du pilote reste) et drapeaux sur le portail
		for _, c in ipairs(parent:GetChildren()) do
			if c.Name == "CastleTorch" and c:IsA("BasePart") and put("props", "torch", c.Position.X, 4.4, c.Position.Z, nil, 3, 0, "CastleTorchModel") then
				c.Transparency = 1
			end
		end
		for _, sx in ipairs({ -8, 8 }) do
			put("props", "flag", ex + sx, 18.5, ez, nil, 7, 0, "CastleFlagModel")
		end
		-- bâtiment du château en fond, derrière la dernière salle
		local bx, bz = Castle.toWorld(Castle.ROOMS, 0, L + 45)
		put("props", "castle", bx, 0, bz, nil, 46, math.pi, "CastleBackdrop")
	end)
	return n
end

-- Habille l'arène : place pavée sous le monument (ground.plaza), bancs et lampadaires autour, moulin (pales animées) et enclos dans le domaine 1.
-- Budget `arenaBudgetParts` (pire cas) ; chaque modèle est facultatif (repli : rien n'est posé, la carte reste procédurale). Retourne le nombre posé.
local millVis = nil
function Builder.dressArena(assets)
	local n, spent = 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderArena"
		folder.Parent = world
		local function put(group, key, x, y0, z, span, height, rotY, name)
			local cost = Config.Assets.modelsMaxParts[group .. "." .. key] or 60
			if spent + cost > Config.Assets.arenaBudgetParts then
				return nil
			end
			local clone = assets.cloneModel(group, key)
			if not clone then
				return nil
			end
			clone.Name = name
			if setModel(clone, x, y0, z, span, height, folder, rotY) then
				spent = spent + cost
				n = n + 1
				return clone
			end
			return nil
		end
		local E = Config.Map2.bigEgg
		put("ground", "plaza", E.x, 0.34, E.z, E.r * 2 - 4, nil, 0, "ArenaPlaza") -- dallage de la place du Grand Œuf
		-- bancs et lampadaires de la place du marché (positions libres : hors halle, étals, fontaine, piste et portails)
		for _, b in ipairs({ { -20, -28 }, { 20, 24 }, { -18, 26 }, { 48, 18 } }) do
			put("props", "bench", b[1], 0, b[2], nil, Config.Assets.targetHeights.bench, math.rad(PlacementMod.facing(-b[1], -b[2])), "ArenaBench") -- le banc regarde le centre de la place
		end
		for _, l in ipairs({ { 30, -22 }, { -12, -42 }, { -52, 22 }, { 54, 8 } }) do
			put("props", "lamp", l[1], 0, l[2], nil, Config.Assets.targetHeights.lamp, 0, "ArenaLamp")
		end
		local cx, cz = Config.rivalCenter(1)
		local mill = put("props", "mill", cx - 24, Config.rivalHeight(1), cz + 22, nil, Config.Assets.targetHeights.mill, math.pi / 6, "ArenaMill")
		if mill then
			local p1, p2 = findNamed(mill, "Pales"), findNamed(mill, "Pales2")
			if p1 then
				millVis = { p1 = p1, b1 = p1.CFrame, p2 = p2, b2 = p2 and p2.CFrame }
			end
		end
		put("props", "pen", cx + 30, Config.rivalHeight(1), cz + 4, 16, nil, 0, "ArenaPen")
	end)
	return n
end

-- Fait tourner les pales du moulin (appelé 10 fois par seconde ; tournent en sens contraires autour de leur axe avant).
function Builder.animProps(t)
	local m = millVis
	if m and m.p1.Parent then
		m.p1.CFrame = m.b1 * CFrame.Angles(0, 0, t * 0.5)
		if m.p2 then
			m.p2.CFrame = m.b2 * CFrame.Angles(0, 0, -t * 0.35)
		end
	end
end

-- Dallage du sol (ground.path : chemins du Grand Nid vers les domaines ; ground.grass : pelouses autour de chaque base). Le coût d'une tuile est
-- MESURÉ (nombre réel de Parts du modèle chargé, Assets.status) et le placement s'arrête dès que `groundBudgetParts` serait dépassé ou que
-- `groundMaxTiles` est atteint. Retourne (tuiles posées, Parts utilisées). Sans modèle : rien (sol procédural conservé).
function Builder.dressGround(assets)
	local tiles, used = 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while (not world or #builtPlots == 0) and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderGround"
		folder.Parent = world
		local function cost(key)
			local st = assets.status and assets.status["m:ground." .. key]
			return st and st.ok and st.parts or nil
		end
		local function tile(key, x, z, span)
			local c = cost(key)
			if not c or used + c > Config.Assets.groundBudgetParts or tiles >= Config.Assets.groundMaxTiles then
				return false
			end
			local clone = assets.cloneModel("ground", key)
			if not clone then
				return false
			end
			clone.Name = "GroundTile"
			if setModel(clone, x, key == "path" and 0.12 or 0.06, z, span, nil, folder, 0) then -- les chemins sont posés 0,06 au-dessus des pelouses (jamais coplanaires)
				used = used + c
				tiles = tiles + 1
				return true
			end
			return false
		end
		-- routes pavées (Config.Map2.paths) hors de la place : une tuile tous les 12 studs, jamais dans l'eau
		local G = MapGeoMod.new(Config)
		local PL = Config.Map2.plaza
		for _, sg in ipairs(G.pathSegs) do
			if sg.half == Config.Map2.pathHalf and (sg.y or 0) == 0 then
				local dx, dz = sg[3] - sg[1], sg[4] - sg[2]
				local len = math.sqrt(dx * dx + dz * dz)
				local k = 0
				while k * 12 < len do
					local x, z = sg[1] + dx * k * 12 / len, sg[2] + dz * k * 12 / len
					if math.sqrt((x - PL.x) ^ 2 + (z - PL.z) ^ 2) > PL.r + 6 and G.waterEdgeDist(x, z, true) > 6 then
						tile("path", x, z, 12)
					end
					k = k + 1
				end
			end
		end
		-- pelouses : 3 x 3 tuiles de 20 studs devant chaque base
		for _, pl in ipairs(builtPlots) do
			local p = pl.spawn.Position
			for gx = -1, 1 do
				for gz = -1, 1 do
					tile("grass", p.X + gx * 20, p.Z + gz * 20, 20)
				end
			end
		end
	end)
	return tiles, used
end

-- Pose les textures tuilables (Config.Assets.textures) sur les grandes surfaces de la carte : herbe, eaux, sol et murs du château, planches, sable,
-- pavés. Une Texture par face listée, au plus `textureMaxCount` au total (priorité = `textureOrder`). Sans URL chargée pour une clé, la matière actuelle
-- reste. Retourne le nombre de Textures posées. Ne lève jamais d'erreur.
function Builder.dressTextures(assets)
	local count = 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local parts = {}
		for _, d in ipairs(world:GetDescendants()) do
			if d:IsA("BasePart") then
				parts[#parts + 1] = d
			end
		end
		local cfg = Config.Assets
		for _, key in ipairs(cfg.textureOrder) do
			local url = assets.textureUrls and assets.textureUrls[key]
			local def = cfg.textures[key]
			if url and def then
				for _, p in ipairs(parts) do
					for _, t in ipairs(def.targets) do
						if (t.name and p.Name == t.name) or (t.prefix and p.Name:sub(1, #t.prefix) == t.prefix) then
							for _, face in ipairs(t.faces) do
								if count >= cfg.textureMaxCount then
									return
								end
								local tx = Instance.new("Texture")
								tx.Name = "Tile_" .. key
								tx.Texture = url
								tx.Face = Enum.NormalId[face]
								tx.StudsPerTileU = def.tile
								tx.StudsPerTileV = def.tile
								tx.Transparency = def.transparency or 0
								tx.Parent = p
								count = count + 1
							end
						end
					end
				end
			end
		end
	end)
	return count
end

-- Publie les modèles d'effets (groupe `vfx`, déjà chargés par Assets) dans ReplicatedStorage.VfxTemplates : les clients les clonent pour VfxKit.play
-- (un client ne peut pas charger d'assets lui-même). Parts ancrées, sans collision, matière Neon d'origine conservée. Retourne le nombre publié.
function Builder.exportVfx(assets)
	local n = 0
	pcall(function()
		local RS = game:GetService("ReplicatedStorage")
		local folder = RS:FindFirstChild("VfxTemplates") or Instance.new("Folder")
		folder.Name = "VfxTemplates"
		for _, key in ipairs(AssetsMod.vfxKeys) do
			local clone = assets.cloneModel("vfx", key)
			if clone then
				clone.Name = key
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
					end
				end
				clone.Parent = folder
				n = n + 1
			end
		end
		folder.Parent = RS
	end)
	return n
end

-- Maison évolutive (REFONTE lot 5, D) : le niveau N remplace l'enclos par une maison (repère local de la base : façade -Z tournée vers la place, arrière +Z).
-- Niveau 1 : enclos de bois (modèle base.level1 ou rails procéduraux) ; niveaux 2 à 7 : modèles Blender house.l2..l7 (largeur = emprise du niveau - 4, bâtiment
-- à l'ARRIÈRE de la plateforme, façade vers la place) ou, à défaut, une maison procédurale simple ; niveau 8 : base.level8. La plateforme grandit avec le niveau
-- (dalle « BasePlate » sous les emplacements : côtés et arrière, l'avant et le spawn restent en place). Tout est dans le modèle « BaseUpgrade » (au plus
-- Config.Assets.houseBudgetPerBase Parts) : les emplacements (pads) ne sont JAMAIS touchés par un changement de niveau.
-- opts.animate : l'ancienne maison reste (« BaseUpgradeOld ») et la nouvelle attend sous le sol (attribut FinalPivot) jusqu'à Builder.finishUpgrade (animation client).
-- Retourne le nombre de Parts posées.
local function levelDef(level)
	local lv = Config.BASE_LEVELS[level]
	return {
		size = lv and lv.size or 52,
		name = lv and lv.name or "",
	}
end

-- Maison procédurale de repli (niveaux 2 à 8) : murs, toit, porte, fenêtres, cheminée, perron ; ~14 à 30 Parts selon le niveau. Posée à l'arrière.
local function proceduralHouse(level, box, backZ)
	local size = levelDef(level).size
	local golden = level >= 8
	local w = math.min(size - 8, 22 + level * 3.5) -- largeur de la façade
	local depth = 11 + level -- profondeur du bâtiment
	local h = 4.2 + level * 0.9 -- hauteur des murs
	local zc = backZ - 1 - depth / 2
	local wall = golden and Color3.fromRGB(240, 220, 150) or (level >= 6 and Color3.fromRGB(226, 228, 232) or (level >= 4 and Color3.fromRGB(214, 190, 150) or Color3.fromRGB(176, 128, 84)))
	local roof = golden and Color3.fromRGB(255, 205, 70) or Color3.fromRGB(176, 70, 60)
	local wood = Color3.fromRGB(110, 76, 46)
	box("HouseSocle", 0, 1.3, zc, w + 3, 0.6, depth + 3, Color3.fromRGB(150, 150, 158), Enum.Material.Cobblestone)
	box("HouseWall", 0, 1.6 + h / 2, zc, w, h, depth, wall, level >= 6 and Enum.Material.Concrete or Enum.Material.WoodPlanks)
	if level >= 6 then
		box("HouseRoof", 0, 1.6 + h + 0.4, zc, w + 1.6, 0.8, depth + 1.6, roof, Enum.Material.Metal) -- toit plat moderne
	else
		box("HouseRoof", 0, 1.6 + h + 0.7, zc, w + 2, 1.4, depth * 0.6, roof, Enum.Material.Slate) -- toit : dalle haute et large
		box("HouseRoofLow", 0, 1.6 + h + 0.2, zc, w + 2, 0.5, depth + 2, roof:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate)
	end
	box("HouseDoor", 0, 1.6 + 1.6, zc - depth / 2 - 0.1, 2.6, 3.2, 0.3, wood)
	for _, sx in ipairs({ -w * 0.3, w * 0.3 }) do
		box("HouseWindow", sx, 1.6 + h * 0.6, zc - depth / 2 - 0.1, 2.4, 2, 0.2, Color3.fromRGB(150, 205, 235), Enum.Material.Glass)
	end
	box("HouseChimney", w * 0.3, 1.6 + h + 2, zc + depth * 0.2, 1.6, 3, 1.6, Color3.fromRGB(120, 110, 108), Enum.Material.Brick)
	for k = 0, 2 do -- perron
		box("HouseStep", 0, 1.1 + k * 0.25, zc - depth / 2 - 1 - (2 - k) * 0.9, 4.2, 0.25, 0.9, Color3.fromRGB(170, 170, 176), Enum.Material.Slate)
	end
	if level >= 3 then
		for _, sx in ipairs({ -w / 2 - 1, w / 2 + 1 }) do
			local post = box("LampPost", sx, 2.8, zc - depth / 2 - 1, 0.5, 5.2, 0.5, Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
			local lamp = box("Lantern", sx, 5.6, zc - depth / 2 - 1, 1.1, 1.1, 1.1, Color3.fromRGB(255, 232, 160), Enum.Material.Neon)
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 224, 150), 14, 0.9
			l.Parent = lamp
			post.CanQuery = false
		end
	end
	if level >= 4 then -- auvent ou garage latéral
		box("HouseGarage", -w / 2 - 4, 1.6 + 2.2, zc, 7, 4.4, depth * 0.8, wall:Lerp(Color3.fromRGB(120, 120, 128), 0.3), Enum.Material.Concrete)
		box("HouseGarageDoor", -w / 2 - 4, 1.6 + 1.6, zc - depth * 0.4 - 0.1, 5, 3.2, 0.2, Color3.fromRGB(90, 92, 100), Enum.Material.Metal)
	end
	if level >= 5 then
		box("HouseTerrace", w / 2 + 3, 1.6 + 0.4, zc, 6, 0.4, depth * 0.8, wood, Enum.Material.WoodPlanks)
	end
	if golden then
		local glow = box("GoldGlow", 0, 1.6 + h + 4, zc, 3, 3, 3, Color3.fromRGB(255, 205, 70), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 205, 70), 26, 1.4
		l.Parent = glow
	end
	return zc -- lot 8B : centre du bâtiment (repère de plot.cf), repère du décor intérieur (HouseDecor)
end

function Builder.baseUpgrade(plot, level, opts)
	local made = 0
	pcall(function()
		if not (plot and plot.model and plot.cf) then
			return
		end
		local animate = opts ~= nil and opts.animate == true
		Builder.finishUpgrade(plot) -- une animation précédente encore en cours est terminée d'abord
		local old = plot.model:FindFirstChild("BaseUpgrade")
		if animate and old then
			old.Name = "BaseUpgradeOld"
			Builder.clearBase(plot, true)
		else
			Builder.clearBase(plot)
		end
		local folder = Instance.new("Model")
		folder.Name = "BaseUpgrade"
		local cf0 = plot.cf
		folder.WorldPivot = cf0
		local def = levelDef(level)
		local halfX, backZ = Config.baseExtent(level)
		-- dalle de la plateforme agrandie : couvre l'ancienne plateforme (dessus à 1,02 : jamais de scintillement) et déborde sur les côtés et l'arrière
		do
			local plat = plot.platform
			local zFront = -(Config.Map2.basePlatform / 2)
			made += 1
			part({ Name = "BasePlate", Size = Vector3.new(halfX * 2, 1, backZ - zFront), CFrame = cf0 * CFrame.new(0, 0.52, (backZ + zFront) / 2),
				Color = plat and plat.Color or Color3.fromRGB(70, 110, 90), Material = Enum.Material.Concrete, CanCollide = true }, folder)
		end
		local function box(name, x, y, z, sx, sy, sz, color, material, rot)
			made += 1
			return part({ Name = name, Size = Vector3.new(sx, sy, sz), CFrame = cf0 * CFrame.new(x, y, z) * CFrame.Angles(0, rot or 0, 0), Color = color, Material = material or Enum.Material.WoodPlanks, CanCollide = false }, folder)
		end
		-- modèle Blender : niveau 1 et 8 = base.levelN (emprise centrée, entrée -Z) ; niveaux 2 à 7 = house.lN (bâtiment à l'arrière, devant -Z)
		local placed = false
		local anchorY, anchorZ = 1.02, 0 -- niveau 1 et 8 (emprise centrée, dessus de la dalle) ; maisons : remplacé ci-dessous
		do
			local isHouse = level >= 2 and level <= 7
			local clone = eggAssets and eggAssets.cloneModel and (isHouse and eggAssets.cloneModel("house", "l" .. level) or eggAssets.cloneModel("base", "level" .. level))
			if clone then
				local ok = pcall(function()
					local _, size = clone:GetBoundingBox()
					local longest = math.max(size.X, size.Z)
					if size.Y < 0.05 or longest < 0.05 then
						error("mesure impossible")
					end
					local target = isHouse and (def.size - 4) or 52 -- l'emprise la plus grande du modèle = emprise du niveau - 4 (niveau 1 : 52, comme avant)
					if level == 8 then
						target = def.size - 4
					end
					local k = target / longest
					if isHouse and size.Z * k > 26 then
						k = 26 / size.Z -- jamais plus profond que 26 studs : l'avant de la maison reste loin de l'entrée
					end
					clone:ScaleTo(clone:GetScale() * k)
					local bbox, size2 = clone:GetBoundingBox()
					local cx, cy, cz = 0, size2.Y / 2, 0
					if isHouse then
						cy = 1 + size2.Y / 2
						cz = backZ - 1 - size2.Z / 2 -- le fond du modèle touche le bord arrière de la dalle
						anchorY, anchorZ = 1.6, cz
					end
					clone:PivotTo(cf0 * CFrame.new(cx, cy, cz) * bbox:ToObjectSpace(clone:GetPivot()))
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
							d.CanQuery = false
						end
					end
					clone.Name = "BaseModel"
					clone.Parent = folder
				end)
				if ok then
					made += Config.Assets.modelsMaxParts[(isHouse and "house.l" or "base.level") .. level] or 80
					placed = true
				else
					anchorY, anchorZ = 1.02, 0
					pcall(function()
						clone:Destroy()
					end)
				end
			end
		end
		if not placed then
			if level >= 2 then
				anchorY = 1.6 -- dessus du socle de la maison procédurale
			end
			if level == 1 then
				-- enclos de bois procédural (niveau 1) : lisse et poteaux autour de la plateforme
				local wood, wood2 = Color3.fromRGB(150, 104, 62), Color3.fromRGB(110, 76, 46)
				local E = 28.5
				box("Rail", -E, 1.6, 0, 0.6, 0.5, 2 * E, wood)
				box("Rail", E, 1.6, 0, 0.6, 0.5, 2 * E, wood)
				box("Rail", 0, 1.6, E, 2 * E, 0.5, 0.6, wood)
				for k = -3, 3 do
					local t = k * (E / 3)
					box("Post", -E, 1.0, t, 0.8, 2.1, 0.8, wood2)
					box("Post", E, 1.0, t, 0.8, 2.1, 0.8, wood2)
					box("Post", t, 1.0, E, 0.8, 2.1, 0.8, wood2)
				end
			else
				anchorZ = proceduralHouse(level, box, backZ)
			end
		end
		-- lot 8B-meubles : repère du décor intérieur (HouseDecor.apply, offset), dans le repère de plot.cf : centre du bâtiment au niveau du plancher
		folder:SetAttribute("DecorY", anchorY)
		folder:SetAttribute("DecorZ", anchorZ)
		folder.Parent = plot.model
		if animate then
			folder:SetAttribute("FinalPivot", cf0)
			folder:PivotTo(cf0 * CFrame.new(0, -Config.UPGRADE_FX.hide, 0)) -- la nouvelle maison attend sous le sol ; le client la fait monter
			plot.upgrading = true
		end
	end)
	return made
end

-- Fin de l'animation de montée de niveau : la nouvelle maison reprend sa place exacte, l'ancienne disparaît. Sans effet s'il n'y a rien à finir.
function Builder.finishUpgrade(plot)
	pcall(function()
		local model = plot and plot.model
		if not model then
			return
		end
		local new = model:FindFirstChild("BaseUpgrade")
		local final = new and new:GetAttribute("FinalPivot")
		if new and final then
			pcall(function()
				if new:GetScale() ~= 1 then
					new:ScaleTo(1)
				end
			end)
			new:PivotTo(final)
			new:SetAttribute("FinalPivot", nil)
		end
		local old = model:FindFirstChild("BaseUpgradeOld")
		if old then
			old:Destroy()
		end
		plot.upgrading = nil
	end)
end

function Builder.clearBase(plot, keepOld)
	pcall(function()
		local f = plot.model and plot.model:FindFirstChild("BaseUpgrade")
		if f then
			f:Destroy()
		end
		if not keepOld then
			local o = plot.model and plot.model:FindFirstChild("BaseUpgradeOld")
			if o then
				o:Destroy()
			end
			plot.upgrading = nil
		end
		plot.baseBlender = 0
	end)
end

-- Décor fin (fleurs, touffes, pierres, lanternes) : budget SÉPARÉ (decoBudgetParts) posé après la carte, coût mesuré d'après les Parts réelles des modèles ;
-- repli procédural limité (decoFallbackMax Parts de fleurs) si les modèles manquent. Retourne (objets posés, Parts utilisées, Parts de repli).
function Builder.dressDeco(assets)
	local placed, used, fallback = 0, 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderDeco"
		folder.Parent = world
		local P = PlacementMod.new(Config)
		local items = P.decor(P.plan().items)
		for _, it in ipairs(items) do
			local st = assets.status and assets.status["m:deco." .. it.kind]
			local cost = (st and st.ok and st.parts) or 0
			local clone = cost > 0 and assets.cloneModel("deco", it.kind) or nil
			if clone then
				if used + cost <= Config.Assets.decoBudgetParts then
					local ok = assets.place(clone, it.x, it.z, it.rot, Config.Assets.decoHeights[it.kind], folder, nil, it.y)
					if ok then
						used = used + cost
						placed = placed + 1
					end
				else
					clone:Destroy()
				end
			elseif it.kind:sub(1, 6) == "flower" and fallback + 2 <= Config.Assets.decoFallbackMax then
				local col = ({ flower_a = Color3.fromRGB(255, 120, 154), flower_b = Color3.fromRGB(255, 210, 63), flower_c = Color3.fromRGB(255, 255, 255) })[it.kind]
				part({ Name = "FlowerStem", Size = Vector3.new(0.2, 0.9, 0.2), Position = Vector3.new(it.x, 0.45 + (it.y or 0), it.z), Color = Color3.fromRGB(62, 142, 68), CanCollide = false, CanQuery = false }, folder)
				ball({ Name = "FlowerHead", Size = Vector3.new(0.7, 0.7, 0.7), Position = Vector3.new(it.x, 1 + (it.y or 0), it.z), Color = col, CanQuery = false }, folder)
				fallback = fallback + 2
			end
		end
	end)
	return placed, used, fallback
end

-- Chemins sinueux Blender (tuiles droites/virages bordés de pierres, touffes sur les bords) posés sur les polylignes de Config.Map2.paths ; les pavés
-- procéduraux (PathStone) proches d'une polyligne habillée sont retirés (jamais de superposition). Retourne (tuiles posées, Parts utilisées).
function Builder.dressPaths(assets)
	local tiles, used = 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		if not world then
			return
		end
		local A = Config.Assets
		local straight = assets.status and assets.status["m:paths.path_straight"]
		if not (straight and straight.ok) then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderPaths"
		folder.Parent = world
		local P = PlacementMod.new(Config)
		local function cost(key)
			local st = assets.status["m:paths." .. key]
			return st and st.ok and st.parts or 0
		end
		local PL = Config.Map2.plaza
		for _, path in ipairs(Config.Map2.paths) do
			local poly = path.pts
			local plan = PlacementMod.pathTiles(poly, A.pathTile, A.pathWind)
			local placedHere, wanted = 0, 0
			for _, t in ipairs(plan.tiles) do
				local key = t.kind
				local c = cost(key)
				if c <= 0 and key == "path_curve" then
					key, c = "path_straight", cost("path_straight")
				end
				local onPlaza = math.sqrt((t.x - PL.x) ^ 2 + (t.z - PL.z) ^ 2) < PL.r -- la place est déjà pavée
				if not onPlaza and not (P.blocked(t.x, t.z, 2, { allowDomain = true, allowPlateau = true }) == "eau") then
					wanted = wanted + 1
					if c > 0 and used + c <= A.pathBudgetParts then
						local clone = assets.cloneModel("paths", key)
						if clone and assets.place(clone, t.x, t.z, t.rot, nil, folder, A.pathTile, (path.y or 0) + 0.2) then
							used, tiles, placedHere = used + c, tiles + 1, placedHere + 1
						end
					end
				end
			end
			local sc = cost("path_stones")
			for i, b in ipairs(plan.borders) do
				if sc > 0 and used + sc <= A.pathBudgetParts and i % 2 == 0 then -- une pierre sur deux : bordure aérée
					local clone = assets.cloneModel("paths", "path_stones")
					if clone and assets.place(clone, b.x, b.z, b.rot, A.pathBorderHeight, folder, nil, 0.08) then
						used = used + sc
					end
				end
			end
			if placedHere > 0 and placedHere == wanted then -- tout le tracé est habillé : les dalles procédurales de ce chemin sont retirées
				for _, d in ipairs(world:GetDescendants()) do
					if (d.Name == "PathStone" or d.Name == "PathJoint" or d.Name == "DirtPath") and d:IsA("BasePart") then
						for k = 1, #poly - 1 do
							if PlacementMod.distToSegment(d.Position.X, d.Position.Z, poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2]) < A.pathWind + 6 then
								d:Destroy()
								break
							end
						end
					end
				end
			end
		end
	end)
	return tiles, used
end

-- Décor de village Blender sur la carte (tour, maisons à colombages, puits, pins hauts, rochers) : planifié par Placement.scenery, budget séparé.
-- Retourne (objets posés, Parts utilisées).
function Builder.dressScenery(assets)
	local placed, used = 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderVillage"
		folder.Parent = world
		local P = PlacementMod.new(Config)
		local dims = Config.Assets.sceneryDims
		for _, it in ipairs(P.scenery(P.plan().items)) do
			local st = assets.status and assets.status["m:scenery." .. it.kind]
			local cost = st and st.ok and st.parts or 0
			if cost > 0 and used + cost <= Config.Assets.sceneryBudgetParts then
				local clone = assets.cloneModel("scenery", it.kind)
				local d = dims[it.kind]
				if clone and assets.place(clone, it.x, it.z, it.rot, d.h, folder, d.len, it.y) then
					used, placed = used + cost, placed + 1
				end
			end
		end
	end)
	return placed, used
end

-- Panneaux de difficulté Blender (étoiles Etoile1..Etoile5 recolorées : or pour les étoiles acquises, gris sinon) à la place du panneau procédural.
function Builder.dressSigns(assets)
	local n = 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		if not world then
			return
		end
		for _, d in ipairs(world:GetDescendants()) do
			if d.Name == "DifficultyBoard" and d:IsA("BasePart") then
				local clone = assets.cloneModel("deco", "sign_stars")
				if clone then
					local stars = d:GetAttribute("Stars") or 1
					local pos = d.Position
					if setModel(clone, pos.X, pos.Y - 6.8, pos.Z, nil, Config.Assets.decoHeights.sign_stars, d.Parent, 0) then
						for _, q in ipairs(clone:GetDescendants()) do
							local idx = q:IsA("BasePart") and tonumber(AssetsMod.baseName(q.Name):match("^Etoile(%d)$"))
							if idx then
								q.Color = idx <= stars and Color3.fromRGB(255, 205, 70) or Color3.fromRGB(120, 120, 130)
							end
						end
						clone.Name = "StarSign"
						d.Transparency = 1
						n = n + 1
					end
				end
			end
		end
	end)
	return n
end

-- Lot 8B-décor : décor de carte des lots 15 à 17 (dôme de la halle, Grand Œuf, colisée, tapis, étals, arbres, lacs...). Decor.lua charge ses modèles par lots
-- parallèles (Assets.loadMany, clés m:decor.<famille>), pose chaque exemplaire en modèle ou en repli procédural dans World/BlenderDecor, jamais dans le disque
-- du kiosque (Config.Map2.kiosk). Retourne (exemplaires, Parts Blender, Parts de repli). Builder.refreshDecor reconstruit avec les modèles arrivés depuis.
local decorHandle = nil
function Builder.dressDecor(assets)
	local n, used, fallback = 0, 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		-- lot 16 : emprises des 8 vendeurs PNJ (SellersData.layout, mêmes calculs que Sellers.build) exclues du décor de carte
		local occupied = {}
		pcall(function()
			local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
			local SD = require(Shared:WaitForChild("SellersData"))
			occupied = SD.footprints(SD.layout(Config.Map2, require(Shared:WaitForChild("KioskData")), { decor = require(Shared:WaitForChild("DecorData")) }))
		end)
		decorHandle = DecorMod.build(world, MapGeoMod.new(Config), Config, { assets = assets, placement = PlacementMod.new(Config), root = world, warn = warn, occupied = occupied })
		for _, l in ipairs(decorHandle.lines or {}) do
			print(l)
		end
		n, used, fallback = #decorHandle.items, decorHandle.used or 0, decorHandle.fallbackUsed or 0
	end)
	return n, used, fallback
end

function Builder.refreshDecor()
	if decorHandle then
		pcall(function()
			decorHandle = DecorMod.refresh(decorHandle)
		end)
	end
end

-- Relief en toile de fond (budget séparé reliefBudgetParts) : crête de falaises sur deux niveaux au nord de la carte (décor de fond, au-delà de la borne
-- nord), cascades, escaliers ; un mur invisible garde les joueurs hors de la crête. Retourne (pièces posées, Parts utilisées).
function Builder.dressRelief(assets)
	local n, used = 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderRelief"
		folder.Parent = world
		local B = Config.Map2.bounds
		local budget = Config.Assets.reliefBudgetParts
		local function cost(key)
			local st = assets.status and assets.status["m:terrain." .. key]
			return (st and st.ok and st.parts) or nil
		end
		local function put(key, x, y0, z, span, height, rot)
			local c = cost(key)
			if not c or used + c > budget then
				return false
			end
			local clone = assets.cloneModel("terrain", key)
			if clone and setModel(clone, x, y0, z, span, height, folder, rot) then
				used = used + c
				n = n + 1
				return true
			end
			return false
		end
		if not cost("cliff_a") then
			return
		end
		local zRow = B.z0 - 22 -- crête au nord, dans le décor de fond (au-delà de la borne nord de la zone jouable)
		-- mur invisible : les joueurs ne montent pas sur la crête (doublé par la borne de la carte)
		part({ Name = "ReliefWall", Size = Vector3.new(B.x1 - B.x0, 14, 1.5), Position = Vector3.new(0, 7, zRow + 8), Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false }, folder)
		local x = B.x0 + 20
		local k = 0
		while x <= B.x1 - 20 do
			local key = k % 3 == 2 and "cliff_b" or "cliff_a"
			put(key, x, 0, zRow, 16, nil, 180)
			x = x + 16
			k = k + 1
		end
		put("cliff_corner", B.x0 + 4, 0, zRow, 12, nil, 180)
		put("cliff_corner", x, 0, zRow, 12, nil, 180)
		-- deuxième niveau (terrasse supérieure) sur la partie centrale, dans la limite du budget
		local x2 = -200
		while x2 <= 200 and put(k % 2 == 0 and "cliff_a" or "cliff_b", x2, 8, zRow - 5, 16, nil, 180) do
			x2 = x2 + 16
			k = k + 1
		end
		-- cascades devant la crête et escaliers (décor de fond)
		for _, wx in ipairs({ -260, 90 }) do
			put("waterfall", wx, 0, zRow + 4, nil, 8, 180)
		end
		for _, sx in ipairs({ -300, 260 }) do
			put("stairs", sx, 0, zRow + 8, 8, nil, 180)
		end
	end)
	return n, used
end

-- Anime la herse de la salle d'après l'état de la porte procédurale (appelé 10 fois par seconde, ne change que sur changement d'état).
function Builder.animDoor(rec, open)
	local vis = rec.vis
	if vis and vis.last ~= open then
		vis.last = open
		vis.part.CFrame = vis.base * CFrame.new(0, open and 9 or 0, 0)
	end
end

-- Ouvre le couvercle du coffre final quelques secondes.
function Builder.openChest()
	local cv = builtCastle and builtCastle.chestVis
	if cv then
		cv.part.CFrame = cv.base * CFrame.Angles(-1.2, 0, 0)
		task.delay(4, function()
			if cv.part.Parent then
				cv.part.CFrame = cv.base
			end
		end)
	end
end

-- Habille les chevaliers du château avec guards.knight (hauteur Config.Assets.guardHeights.knight). Le pilote procédural devient invisible.
function Builder.dressKnights(assets)
	local n = 0
	pcall(function()
		local waited = 0
		while not builtCastle and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
		end
		local parent = builtCastle and builtCastle.rooms[1] and builtCastle.rooms[1].door and builtCastle.rooms[1].door.Parent
		if not parent then
			return
		end
		for _, rec in ipairs(builtCastle.rooms) do
			for _, v in ipairs(rec.knights) do
				local clone = assets.cloneModel("guards", "knight")
				if clone then
					clone.Name = "CastleKnightModel"
					if setModel(clone, v.part.Position.X, 0, v.wz, nil, Config.Assets.guardHeights.knight, parent, 0) then
						v.vis = { model = clone, off = CFrame.new(v.part.Position.X, 0, v.wz):ToObjectSpace(clone:GetPivot()) }
						v.part.Transparency = 1
						n = n + 1
					end
				end
			end
		end
	end)
	return n
end

-- Place le modèle du chevalier sur sa position et le tourne dans le sens de la marche (devant = -Z : vers +X = -90°).
function Builder.animKnight(v, x, z, dir, speed)
	local vis = v.vis
	if vis then
		local by, roll = GuardMod.walkPose(os.clock() + (v.wz or 0), speed or 8) -- rebond et roulis de marche
		vis.model:PivotTo(CFrame.new(x, by, z) * CFrame.Angles(0, dir > 0 and -math.pi / 2 or math.pi / 2, 0) * CFrame.Angles(0, 0, roll) * vis.off)
	end
end

-- Anime le modèle d'un piège d'après la position de son pilote procédural (appelé 10 fois par seconde par le château).
function Builder.animSpike(v, tipY, state)
	local vis = v.vis
	if vis and vis.last ~= state then
		vis.last = state
		vis.part.CFrame = vis.base * CFrame.new(0, tipY - 0.9, 0) -- le modèle est dessiné pics sortis
	end
end
function Builder.animBlade(v, angle)
	local vis = v.vis
	if vis then
		local c = vis.center
		vis.part.CFrame = CFrame.new(c) * CFrame.Angles(0, angle, 0) * CFrame.new(-c) * vis.base
	end
end
function Builder.animBall(v, x, y, z)
	local vis = v.vis
	if vis then
		vis.model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, 0, -x / math.max(0.5, vis.d / 2)))
	end
end

-- Habille les gardiens des domaines avec les modèles Blender chargés (guards.dog / wolf / bear). Retourne le nombre de gardiens remplacés.
function Builder.dressGuards(assets)
	local n = 0
	pcall(function()
		local waited = 0
		while #builtGuards == 0 and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
		end
		for _, g in ipairs(builtGuards) do
			local kind = Config.Assets.guardKinds[g.rival]
			local clone = kind and assets.cloneModel("guards", kind)
			if clone and fitGuard(g.model, clone, Config.Assets.guardHeights[kind]) then
				n = n + 1
			end
		end
	end)
	return n
end

function Builder.guard(rivalIdx)
	local r = Config.RIVALS[rivalIdx]
	local col = r.color:Lerp(Color3.fromRGB(60, 40, 30), 0.6)
	local model = Instance.new("Model")
	model.Name = "Guard" .. rivalIdx
	local body = part({ Name = "Body", CanCollide = false, Size = Vector3.new(3, 2.4, 4.4), CFrame = CFrame.new(0, 0, 0), Color = col }, model)
	model.PrimaryPart = body
	ball({ Name = "Head", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(0, 0.7, -2.7), Color = col }, model)
	part({ Name = "Snout", CanCollide = false, Size = Vector3.new(1.2, 0.9, 1.2), CFrame = CFrame.new(0, 0.3, -3.7), Color = Color3.fromRGB(35, 30, 30) }, model)
	ball({ Name = "EyeL", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(-0.7, 1.2, -3.5), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon }, model)
	ball({ Name = "EyeR", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(0.7, 1.2, -3.5), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon }, model)
	part({ Name = "EarL", CanCollide = false, Size = Vector3.new(0.5, 1.1, 0.6), CFrame = CFrame.new(-1.0, 1.9, -2.5) * CFrame.Angles(0, 0, 0.3), Color = col }, model)
	part({ Name = "EarR", CanCollide = false, Size = Vector3.new(0.5, 1.1, 0.6), CFrame = CFrame.new(1.0, 1.9, -2.5) * CFrame.Angles(0, 0, -0.3), Color = col }, model)
	part({ Name = "Tail", CanCollide = false, Size = Vector3.new(0.6, 0.6, 2), CFrame = CFrame.new(0, 0.8, 3.0) * CFrame.Angles(0.5, 0, 0), Color = col }, model)
	for i, o in ipairs({ { -1, -1.4 }, { 1, -1.4 }, { -1, 1.4 }, { 1, 1.4 } }) do
		part({ Name = "Leg" .. i, CanCollide = false, Size = Vector3.new(0.7, 1.6, 0.7), CFrame = CFrame.new(o[1], -1.8, o[2]), Color = col }, model)
	end
	if r.gentle then -- anneau de vision au sol (disque jaune translucide de la portée de vue) : on voit jusqu'où Gus repère
		part({ Name = "VisionRing", Size = Vector3.new(0.1, r.viewDist * 2, r.viewDist * 2), CFrame = CFrame.new(0, -2.25, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.SmoothPlastic, Transparency = 0.8, CanCollide = false, CanQuery = false }, model)
	end
	local s = sign(body, "🐕 Gardien de " .. r.name, Color3.fromRGB(255, 120, 120), 4, 220)
	s.TextSize = 14
	return model
end

---------------------------------------------------------------- Éclairage
-- Ambiance « jour doré » : soleil chaud, brume légère, bloom discret, étalonnage plus vif.
function Builder.setupLighting()
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 2.2 -- plus doux
	Lighting.Ambient = Color3.fromRGB(110, 112, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 158)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 205)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	local function effect(class, name, props)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		for k, v in pairs(props) do
			e[k] = v
		end
		return e
	end

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Parent = Lighting
	end
	atm.Density = 0.32 -- brouillard léger : les lointains se fondent dans le ciel
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(199, 220, 255)
	atm.Decay = Color3.fromRGB(255, 214, 170)
	atm.Glare = 0.25
	atm.Haze = 1.7

	effect("BloomEffect", "ChipeBloom", { Intensity = 0.3, Size = 24, Threshold = 0.96 })
	effect("SunRaysEffect", "ChipeSunRays", { Intensity = 0.15, Spread = 0.8 })
	effect("ColorCorrectionEffect", "ChipeGrade", { Saturation = 0.1, Contrast = 0.06, Brightness = 0.02 }) -- couleurs plus harmonieuses, moins saturées
end

---------------------------------------------------------------- Grand Œuf de l'énigme (ancien Grand Nid ; REFONTE lot 2 : place à l'est de la place du marché)
-- Les noms (GrandNid, RuneStone, RiddleBoard), tags (RuneStone) et attributs (Kind, Idx) lus par le serveur et le client sont conservés.
function Builder.monument(parent)
	local gold = Color3.fromRGB(255, 214, 120)
	local E = Config.Map2.bigEgg
	local ox, oz = E.x, E.z
	part({ Name = "BigEggPlace", Size = Vector3.new(0.2, E.r * 2, E.r * 2), CFrame = CFrame.new(ox, 0.48, oz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(190, 176, 150), Material = Enum.Material.Cobblestone, CanCollide = false }, parent)
	part({ Name = "MonumentBase", Size = Vector3.new(1.4, 17, 17), CFrame = CFrame.new(ox, 0.8, oz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(176, 160, 128), Material = Enum.Material.Slate }, parent)
	part({ Name = "MonumentStep", Size = Vector3.new(0.8, 12, 12), CFrame = CFrame.new(ox, 1.7, oz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(130, 116, 92), Material = Enum.Material.Slate }, parent)
	local egg = Instance.new("Part")
	egg.Name = "GrandNid"
	egg.Anchored = true
	egg.Size = Vector3.new(E.h * 0.72, E.h, E.h * 0.72)
	local eggY = 2.1 + E.h / 2
	egg.CFrame = CFrame.new(ox, eggY, oz)
	egg.Color = gold
	egg.Material = Enum.Material.Metal
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Range = 32
	glow.Brightness = 1.5
	glow.Parent = egg
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 235, 160))
	sparks.Rate = 8
	sparks.Lifetime = NumberRange.new(2, 3.5)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = egg
	egg.Parent = parent
	local ew = E.h * 0.36
	for k, c in ipairs({ { 0, 0.42, -0.98, 0.3 }, { 0.15, 0.05, -1, -0.5 }, { -0.14, -0.28, -0.97, 0.6 } }) do -- fissures lumineuses (face nord)
		part({ Name = "Crack" .. k, Size = Vector3.new(0.35, 3.6, 0.35), CFrame = CFrame.new(ox + c[1] * ew, eggY + c[2] * E.h / 2, oz + c[3] * ew) * CFrame.Angles(0, 0, c[4]), Color = Color3.fromRGB(255, 248, 200), Material = Enum.Material.Neon, CanCollide = false }, parent)
	end
	-- Quatre runes cardinales (Nord = côté des rivaux). Chaque joueur règle ses propres runes : le symbole affiché est local au client
	-- (étiquette « Label » modifiée côté client), l'état est tenu par le serveur.
	for k, rs in ipairs(Config.Map2.runeStones) do -- ordre N, E, S, O (= Config.RUNE_DIRECTIONS)
		local x, z = rs.x, rs.z
		local stone = part({ Name = "RuneStone", Size = Vector3.new(2.4, 5, 1.2), CFrame = CFrame.lookAt(Vector3.new(x, 2.7, z), Vector3.new(ox, 2.7, oz)), Color = Color3.fromRGB(110, 104, 96), Material = Enum.Material.Slate }, parent)
		stone:SetAttribute("Idx", k)
		CollectionService:AddTag(stone, "RuneStone")
		part({ Name = "RuneGlow", Size = Vector3.new(1.1, 3.4, 0.2), CFrame = stone.CFrame * CFrame.new(0, 0.2, -0.65), Color = gold, Material = Enum.Material.Neon, CanCollide = false }, parent)
		local lbl = sign(stone, "?", Color3.fromRGB(255, 240, 190), 4.4, 120)
		lbl.TextSize = 44
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Tourner la rune"
		pr.ObjectText = "Rune du " .. Config.RUNE_DIRECTIONS[k]
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Kind", "Rune")
		pr:SetAttribute("Idx", k)
		pr.Parent = stone
	end
	-- Valider la combinaison en touchant le Grand Nid
	local confirm = Instance.new("ProximityPrompt")
	confirm.ActionText = "Poser la combinaison"
	confirm.ObjectText = "Grand Œuf"
	confirm.HoldDuration = 0.5
	confirm.MaxActivationDistance = 14
	confirm.RequiresLineOfSight = false
	confirm:SetAttribute("Kind", "RuneConfirm")
	confirm.Parent = egg
	-- Panneau de l'énigme de Mère Poule (texte mis à jour chaque jour par le serveur), lisible des deux côtés
	local bx, bz = ox + 16, oz + 14
	local board = part({ Name = "RiddleBoard", Size = Vector3.new(12, 4.6, 0.5), Position = Vector3.new(bx, 3.8, bz), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, parent)
	part({ Name = "RiddlePostL", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(bx - 5.4, 2, bz), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	part({ Name = "RiddlePostR", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(bx + 5.4, 2, bz), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(720, 300)
		sg.LightInfluence = 0
		sg.Adornee = board
		sg.Parent = board
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 56)
		title.Font = FONT
		title.TextSize = 40
		title.TextColor3 = gold
		title.Text = "📜 La berceuse du Grand Œuf"
		title.Parent = sg
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(16, 60)
		body.Size = UDim2.new(1, -32, 1, -64)
		body.Font = Enum.Font.GothamMedium
		body.TextSize = 29
		body.TextWrapped = true
		body.TextColor3 = Color3.fromRGB(255, 244, 220)
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = "Parle à la Mère Poule 🐔 : trouve ses 4 plumes dorées, règle les 4 runes, puis chante la berceuse. Un nouveau défi chaque jour !" -- texte fixe : les indices sont sur les plumes (lot 6)
		body.Parent = sg
		labels[#labels + 1] = body
	end
	local result = { labels = labels, center = Vector3.new(ox, eggY, oz) }
	local t = sign(egg, "✨ Le Grand Œuf ✨\nRéveille la Couvée, Chipeur !", gold, E.h / 2 + 3, 340)
	t.TextSize = 20
	return result
end

---------------------------------------------------------------- Mère Poule (gardienne du Grand Nid, guide de l'histoire)
-- Les parties de la tête portent un nom préfixé « Hen » : le client les fait picorer (Animations.client.lua) et la cinématique
-- d'introduction la met en scène (ancre « hen » = tag Hen).
function Builder.hen(parent)
	local white, red, orange, dark = Color3.fromRGB(250, 248, 240), Color3.fromRGB(235, 60, 60), Color3.fromRGB(255, 170, 40), Color3.fromRGB(30, 28, 32)
	local model = Instance.new("Model")
	model.Name = "MerePoule"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- cinématiques et énigme : toujours présente côté client
	local body = ball({ Name = "Body", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(0, 0, 0), Color = white }, model)
	model.PrimaryPart = body
	part({ Name = "Tail", Size = Vector3.new(1.2, 2.2, 0.6), CFrame = CFrame.new(0, 0.8, 2.1) * CFrame.Angles(-0.5, 0, 0), Color = white, CanCollide = false }, model)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Wing", Size = Vector3.new(0.3, 2, 2.2), CFrame = CFrame.new(side * 2.05, 0, 0.2) * CFrame.Angles(0, 0, side * 0.15), Color = Color3.fromRGB(238, 232, 220), CanCollide = false }, model)
		part({ Name = "Leg", Size = Vector3.new(0.3, 1.3, 0.3), CFrame = CFrame.new(side * 0.8, -2.5, 0), Color = orange, CanCollide = false }, model)
		part({ Name = "Foot", Size = Vector3.new(0.9, 0.2, 1.1), CFrame = CFrame.new(side * 0.8, -3.15, -0.3), Color = orange, CanCollide = false }, model)
		ball({ Name = "HenEye" .. (side < 0 and "L" or "R"), Size = Vector3.new(0.38, 0.38, 0.38), CFrame = CFrame.new(side * 0.6, 2.55, -2.6), Color = dark }, model)
	end
	ball({ Name = "HenHead", Size = Vector3.new(2.3, 2.3, 2.3), CFrame = CFrame.new(0, 2.3, -1.7), Color = white }, model)
	part({ Name = "HenComb", Size = Vector3.new(0.5, 0.9, 1.2), CFrame = CFrame.new(0, 3.6, -1.7), Color = red, CanCollide = false }, model)
	part({ Name = "HenBeak", Size = Vector3.new(0.8, 0.5, 0.9), CFrame = CFrame.new(0, 2.15, -3.0), Color = orange, CanCollide = false }, model)
	ball({ Name = "HenWattle", Size = Vector3.new(0.6, 0.8, 0.5), CFrame = CFrame.new(0, 1.6, -2.8), Color = red }, model)
	local label = sign(body, "🐔 Mère Poule\nGardienne du Grand Œuf", Color3.fromRGB(255, 220, 140), 5.5, 260)
	label.TextSize = 17
	-- Lot 6 : « Parler » ouvre le dialogue de l'énigme (le serveur choisit la réplique selon l'étape du joueur et envoie son identifiant).
	local talk = Instance.new("ProximityPrompt")
	talk.ActionText = "Parler"
	talk.ObjectText = "Mère Poule"
	talk.HoldDuration = 0
	talk.MaxActivationDistance = Config.HEN.talkDistance - 2
	talk.RequiresLineOfSight = false
	talk:SetAttribute("Kind", "HenTalk")
	talk.Parent = body
	model:SetAttribute("Seed", 3)
	CollectionService:AddTag(model, "Hen")
	local H, E = Config.Map2.hen, Config.Map2.bigEgg
	model:PivotTo(CFrame.lookAt(Vector3.new(H.x, 3.2, H.z), Vector3.new(E.x, 3.2, E.z))) -- regarde le Grand Œuf
	model.Parent = parent
	return model
end

-- Plume dorée de l'énigme (lot 6) : UNE Part néon (visible de tous), ramassée PAR JOUEUR (le serveur tient le masque `puzzle.feathers` ; le client cache la plume
-- de celui qui l'a prise). Déplacée chaque jour par le serveur (HenQuest) ; l'émetteur d'étincelles est coupé : le client l'allume à moins de 40 studs.
function Builder.feather(parent, dir)
	local f = part({ Name = "Feather", Size = Vector3.new(0.3, 3.4, 1.3), Color = Color3.fromRGB(255, 214, 90), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, parent)
	f:SetAttribute("Dir", dir)
	CollectionService:AddTag(f, "Feather")
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparkle"
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	sparks.Enabled = false
	sparks.Parent = f
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 214, 90)
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Parent = f
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Ramasser"
	pr.ObjectText = "Plume dorée"
	pr.HoldDuration = 0.5
	pr.MaxActivationDistance = Config.HEN.pickupDistance
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Kind", "Feather")
	pr:SetAttribute("Dir", dir)
	pr.Parent = f
	return f
end

---------------------------------------------------------------- Monde
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80), Color3.fromRGB(255, 230, 90), Color3.fromRGB(140, 230, 110),
	Color3.fromRGB(80, 220, 200), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(235, 235, 235), Color3.fromRGB(170, 190, 160),
}
Builder.PLOT_COLORS = PLOT_COLORS

local function tree(pos, parent, rng)
	local s = rng:NextNumber(0.85, 1.3)
	part({ Name = "Trunk", Size = Vector3.new(2 * s, 8 * s, 2 * s), Position = pos + Vector3.new(0, 4 * s, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood }, parent)
	local dark, light = Color3.fromRGB(62, 142, 68), Color3.fromRGB(92, 178, 86)
	ball({ Name = "Leaves", Size = Vector3.new(11 * s, 11 * s, 11 * s), Position = pos + Vector3.new(0, 11 * s, 0), Color = dark, Material = Enum.Material.Grass }, parent)
	ball({ Name = "Leaves", Size = Vector3.new(7 * s, 7 * s, 7 * s), Position = pos + Vector3.new(3.2 * s, 9.2 * s, 1.5 * s), Color = light, Material = Enum.Material.Grass }, parent)
	ball({ Name = "Leaves", Size = Vector3.new(6 * s, 6 * s, 6 * s), Position = pos + Vector3.new(-2.8 * s, 14 * s, -1 * s), Color = light, Material = Enum.Material.Grass }, parent)
end

local function torch(pos, parent)
	part({ Name = "TorchPost", Size = Vector3.new(0.8, 5, 0.8), Position = pos + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	local head = ball({ Name = "TorchHead", Size = Vector3.new(1.3, 1.3, 1.3), Position = pos + Vector3.new(0, 5.4, 0), Color = Color3.fromRGB(255, 150, 60), Material = Enum.Material.Neon }, parent)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 170, 70)
	fire.SecondaryColor = Color3.fromRGB(255, 90, 30)
	fire.Parent = head
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 170, 90)
	l.Range = 18
	l.Brightness = 1.2
	l.Parent = head
end

-- Décale de dy toutes les Parts d'un dossier (contenu d'un territoire posé sur le plateau du château).
local function liftFolder(folder, dy)
	if dy == 0 then
		return
	end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + Vector3.new(0, dy, 0)
		end
	end
end

-- Retourne { plots, nests, treadmill, guards, treadmillContains, fastTravel, partCount, ... }
-- REFONTE (lot 2) : carte Config.Map2 (700 x 500) : place du marché au centre, 5 bases tournées vers la place, territoires de Config.TERR,
-- château sur plateau au nord-est, arène au sud-ouest, lacs, rivières en polylignes. Géométrie dérivée : MapGeo.
function Builder.build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("SpawnLocation") then
			c:Destroy()
		end
	end

	Builder.setupLighting()
	local M2 = Config.Map2
	local G = MapGeoMod.new(Config)
	local P = PlacementMod.new(Config, MapGeoMod)

	-- Sol (herbe : zone jouable + décor de fond), bornes, collines, forêts --------------------------
	part({ Name = "Ground", Size = Vector3.new(M2.backdrop.w, 2, M2.backdrop.d), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(92, 160, 82), Material = Enum.Material.Grass }, world)
	local sceneryHelpers = { part = part, ball = ball, tree = tree, torch = torch, sign = sign }
	local sceneryParts = 0
	local function deco(name, fn)
		local okS, countS = pcall(fn)
		if okS then
			sceneryParts += countS or 0
		else
			warn("[Builder] décor « " .. name .. " » : " .. tostring(countS))
		end
	end
	deco("relief", function()
		local savedYield = PlacementMod.yield -- la carte se construit d'un bloc (pas de pause) : le serveur n'est prêt qu'après
		PlacementMod.yield = nil
		local okF, forest = pcall(P.forest)
		PlacementMod.yield = savedYield
		return Scenery.relief(sceneryHelpers, world, Config, okF and forest or {})
	end)
	deco("plaza", function()
		return Scenery.plaza(sceneryHelpers, world, Config)
	end)

	local monument = Builder.monument(world)
	local henModel = Builder.hen(world)

	local result = { plots = {}, nests = {}, guards = {}, riddleLabels = monument.labels, monumentCenter = monument.center, geo = G, hen = henModel, folder = world }

	-- Territoires (Config.TERR) : nids, postes des gardiens, décor, barrière des zones verrouillées, panneau de difficulté ---------------
	local gIndex = {} -- numéro du gardien dans son rival (Guard<rival>_<j>)
	for _, t in ipairs(G.terrs) do
		local folder = Instance.new("Folder")
		local riv = t.rival > 0 and Config.RIVALS[t.rival] or nil
		folder.Name = Config.territoryFolder(t.key)
		folder:SetAttribute("Territory", t.key)
		folder.Parent = world
		local y0 = G.groundY(t.x, t.z)
		local nestRival = riv and t.rival or 1 -- enclos sauvage : rattaché au domaine de Gus (toujours ouvert), poids propres (Config.TERR.wild)
		local color = riv and riv.color or Color3.fromRGB(200, 170, 110)
		if riv then
			part({ Name = "Disc", Size = Vector3.new(0.2, t.r * 2, t.r * 2), CFrame = CFrame.new(t.x, 0.12, t.z) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = color:Lerp(Color3.fromRGB(70, 55, 40), 0.55), Material = Enum.Material.Ground, Transparency = 0.35, CanCollide = false, CanQuery = false }, folder)
			local ex, ez = t.entry.x, t.entry.z
			torch(Vector3.new(ex - 4, 0, ez), folder)
			torch(Vector3.new(ex + 4, 0, ez), folder)
			local pole = part({ Name = "Sign", Size = Vector3.new(1, 9, 1), Position = Vector3.new(t.x, 4.5, t.z - t.r + 6), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, folder)
			part({ Name = "Flag", Size = Vector3.new(0.2, 3, 5), Position = Vector3.new(t.x + 0.2, 8, t.z - t.r + 8.5), Color = riv.color, Material = Enum.Material.Fabric, CanCollide = false }, folder)
			local lbl = sign(pole, riv.emoji .. " " .. riv.name .. "  " .. string.rep("★", riv.stars), Color3.fromRGB(255, 220, 90), 7, 260)
			lbl.TextSize = 22
			-- panneau de difficulté à l'entrée du territoire : étoiles et nombre de gardiens du territoire
			local dx, dz = ex + 8, ez
			local count = #t.posts
			local post = part({ Name = "DifficultySign", Size = Vector3.new(0.8, 6, 0.8), Position = Vector3.new(dx, 3, dz), Color = Color3.fromRGB(110, 76, 46), Material = Enum.Material.Wood, CanCollide = false }, folder)
			local board = part({ Name = "DifficultyBoard", Size = Vector3.new(7, 3, 0.5), Position = Vector3.new(dx, 6.8, dz), Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.WoodPlanks, CanCollide = false }, folder)
			local dl = sign(board, string.rep("⭐", riv.stars) .. string.rep("☆", 5 - riv.stars) .. "\n" .. riv.name .. " : " .. count .. " gardien" .. (count > 1 and "s" or ""), Color3.fromRGB(255, 220, 120), 0, 200)
			dl.TextSize = 16
			post.Anchored = true
			board:SetAttribute("Stars", riv.stars)
			local theme = Scenery[Config.Map.zoneKeys[t.rival]]
			if theme then
				local okS, countS = pcall(theme, sceneryHelpers, t, folder, Random.new(100 + t.rival * 7 + #t.key), 0)
				if okS then
					sceneryParts += countS
				else
					warn("[Builder] décor du territoire " .. t.key .. " : " .. tostring(countS))
				end
			end
			local zone = Config.ZONES[t.rival]
			if zone and zone.chapter > 0 then
				-- Barrière du territoire verrouillé. Elle est solide pour tous ; le client la rend traversable (localement) dès que le
				-- joueur a réussi le chapitre requis. Le serveur refuse de toute façon tout vol dans une zone verrouillée.
				local gate = part({ Name = "ZoneGate", Size = Vector3.new(12, t.r * 2 + 2, t.r * 2 + 2), CFrame = CFrame.new(t.x, 6, t.z) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 70, 90), Material = Enum.Material.Neon, Transparency = 0.6 }, folder)
				gate:SetAttribute("Rival", t.rival)
				gate:SetAttribute("Chapter", zone.chapter)
				CollectionService:AddTag(gate, "ZoneGate")
				sign(gate, "🔒 " .. zone.name .. "\nHistoire : chapitre " .. zone.chapter, Color3.fromRGB(255, 210, 210), 10, 300)
			end
		else
			-- enclos sauvage : clôture basse ouverte au sud, sans gardien
			local W = M2.wildPen
			for _, r in ipairs({ { 0, -W.d / 2, W.w, 0.4 }, { -W.w / 2, 0, 0.4, W.d }, { W.w / 2, 0, 0.4, W.d } }) do
				part({ Name = "PenRail", Size = Vector3.new(r[3], 0.5, r[4]), Position = Vector3.new(t.x + r[1], 2, t.z + r[2]), Color = Color3.fromRGB(140, 104, 70), Material = Enum.Material.Wood }, folder)
			end
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				part({ Name = "PenPost", Size = Vector3.new(0.7, 3, 0.7), Position = Vector3.new(t.x + c[1] * W.w / 2, 1.5, t.z + c[2] * W.d / 2), Color = Color3.fromRGB(120, 88, 58), Material = Enum.Material.Wood }, folder)
			end
			local pole = part({ Name = "Sign", Size = Vector3.new(0.8, 6, 0.8), Position = Vector3.new(t.x - W.w / 2 - 2, 3, t.z + W.d / 2), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, folder)
			sign(pole, "🧺 Enclos sauvage\nÀ chiper sans gardien !", Color3.fromRGB(255, 230, 150), 5, 240)
		end
		for ni, np in ipairs(t.nests or {}) do
			local nx, nz = np[1], np[2]
			local mound = part({ Name = "Nest", Size = Vector3.new(0.7, 6, 6), CFrame = CFrame.new(nx, 1, nz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.Wood, CanCollide = false }, folder)
			part({ Name = "NestStraw", Size = Vector3.new(0.3, 4.4, 4.4), CFrame = CFrame.new(nx, 1.32, nz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(226, 196, 120), Material = Enum.Material.Fabric, CanCollide = false }, folder)
			Scenery.marker(sceneryHelpers, Vector3.new(nx, 0.5 + ni * 0.06, nz), folder, "✋", 8) -- hauteurs distinctes : nids proches (enclos sauvage) sans z-fighting
			sceneryParts += 1
			result.nests[#result.nests + 1] = { rival = nestRival, terr = t.key, weights = (not riv) and t.data.weights or nil, pos = Vector3.new(nx, 3.2 + y0, nz), mound = mound, folder = folder, egg = nil, rt = math.random() * 6 }
		end
		-- gardiens : un par poste ; territoire = disque du territoire (clampToDisc), patrouille de ± patrolHalf autour du poste
		for _, post in ipairs(t.posts) do
			gIndex[t.rival] = (gIndex[t.rival] or 0) + 1
			local j = gIndex[t.rival]
			local gx, gz = post[1], post[2]
			local g = Builder.guard(t.rival)
			g.Name = "Guard" .. t.rival .. "_" .. j
			g:SetAttribute("Territory", t.key)
			g.Parent = folder
			builtGuards[#builtGuards + 1] = { model = g, rival = t.rival }
			local inner = t.r - Config.GUARD.territoryMargin
			local dPost = math.sqrt((gx - t.x) ^ 2 + (gz - t.z) ^ 2)
			local patrolHalf = math.max(4, math.min(12, inner - dPost))
			result.guards[#result.guards + 1] = {
				model = g, rival = t.rival, terr = t.key, tx = t.x, tz = t.z, clampR = math.max(inner, dPost + patrolHalf + 0.5), patrolHalf = patrolHalf,
				cx = gx, patrolZ = gz, pos = Vector3.new(gx, 2.4, gz), dir = ((t.rival + j) % 2 == 0) and -1 or 1, state = "patrol", cd = 0, lost = 0,
			}
			g:PivotTo(CFrame.new(gx, 2.4, gz))
		end
		-- contenu posé sur le sol réel (plateau du château pour la cour de Zed)
		liftFolder(folder, y0)
		if y0 ~= 0 then
			for _, g in ipairs(result.guards) do
				if g.terr == t.key then
					g.pos = g.pos + Vector3.new(0, y0, 0)
				end
			end
		end
	end

	-- Piste d'entraînement (ancien « Treadmill » ; clé `train` inchangée) : les rayures sont animées côté client (tag BeltStripe) -----
	do
		local T = M2.track
		local belt = part({ Name = "TrainingTrack", Size = Vector3.new(T.w, 1, T.d), Position = Vector3.new(T.x, 0.6, T.z), Color = Color3.fromRGB(45, 48, 56), Material = Enum.Material.Metal }, world)
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, -14) -- la piste pousse vers -Z : il faut courir vers +Z
		for k = 0, 7 do
			local stripe = part({ Name = "Stripe", Size = Vector3.new(T.w - 2, 0.1, 1.2), Position = Vector3.new(T.x, 1.16, T.z - 17.5 + k * 5), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon, CanCollide = false }, belt)
			stripe:SetAttribute("Z0", -17.5 + k * 5)
			stripe:SetAttribute("CenterZ", T.z)
			CollectionService:AddTag(stripe, "BeltStripe")
		end
		for _, sx in ipairs({ -T.w / 2 - 0.6, T.w / 2 + 0.6 }) do
			part({ Name = "Rail", Size = Vector3.new(0.8, 1.6, T.d), Position = Vector3.new(T.x + sx, 1.1, T.z), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon }, world)
		end
		local pole = part({ Name = "TreadSign", Size = Vector3.new(1, 8, 1), Position = Vector3.new(T.x + T.w / 2 + 3, 4, T.z + T.d / 2 - 2), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		sign(pole, "🏃 PISTE D'ENTRAÎNEMENT\nCours dessus pour gagner en vitesse !", Color3.fromRGB(255, 220, 90), 6, 300)
		result.treadmill = { cf = belt.CFrame, size = belt.Size }
	end

	-- Tapis roulant central du marché (lot 3) : sort de la halle, avance vers +X, finit dans le bac. AUCUN effet de vitesse sur les joueurs :
	-- rien n'y est solide (on le traverse comme un décor), les œufs y sont posés par le serveur (Main, section « Tapis roulant central »). ---
	do
		local B = M2.belt
		local len = B.x1 - B.x0
		local mx = (B.x0 + B.x1) / 2
		local steel, amber = Color3.fromRGB(52, 56, 66), Color3.fromRGB(255, 196, 64)
		local body = part({ Name = "CentralBelt", Size = Vector3.new(len, 0.8, B.width), Position = Vector3.new(mx, 0.4, B.z), Color = steel, Material = Enum.Material.Metal, CanCollide = false }, world)
		for _, sz in ipairs({ -B.width / 2 - 0.4, B.width / 2 + 0.4 }) do
			part({ Name = "BeltRail", Size = Vector3.new(len, 1.2, 0.8), Position = Vector3.new(mx, 0.6, B.z + sz), Color = amber, Material = Enum.Material.Neon, CanCollide = false }, world)
		end
		for k = 0, math.floor(len / 6) - 1 do -- repères fixes (le mouvement vient des œufs)
			part({ Name = "BeltMark", Size = Vector3.new(1.2, 0.1, B.width - 2), Position = Vector3.new(B.x0 + 3 + k * 6, 0.85, B.z), Color = amber, Material = Enum.Material.Neon, CanCollide = false }, body)
		end
		-- le bac : l'œuf qui arrive au bout y tombe et disparaît
		local bx, bz = B.bin.x, B.bin.z
		part({ Name = "BeltBinFloor", Size = Vector3.new(7, 0.8, B.width + 2), Position = Vector3.new(bx, 0.4, bz), Color = Color3.fromRGB(70, 48, 36), Material = Enum.Material.Wood }, world)
		part({ Name = "BeltBinWall", Size = Vector3.new(1, 3, B.width + 2), Position = Vector3.new(bx + 3.5, 1.5, bz), Color = Color3.fromRGB(96, 66, 48), Material = Enum.Material.Wood }, world)
		part({ Name = "BeltBinBack", Size = Vector3.new(7, 2, 1), Position = Vector3.new(bx, 1.2, bz - B.width / 2 - 0.5), Color = Color3.fromRGB(96, 66, 48), Material = Enum.Material.Wood }, world)
		part({ Name = "BeltBinFront", Size = Vector3.new(7, 2, 1), Position = Vector3.new(bx, 1.2, bz + B.width / 2 + 0.5), Color = Color3.fromRGB(96, 66, 48), Material = Enum.Material.Wood }, world)
		-- panneau : deux tables de rareté (celle en vigueur en surbrillance) et compte à rebours du tapis doré ; mis à jour par Main
		local post = part({ Name = "BeltPanelPost", Size = Vector3.new(1, 9, 1), Position = Vector3.new(mx, 4.5, B.z - B.width / 2 - 5), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		local g = Instance.new("BillboardGui")
		g.Name = "BeltPanel"
		g.Adornee = post
		g.Size = UDim2.fromOffset(440, 168)
		g.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
		g.MaxDistance = 80
		g.AlwaysOnTop = false
		local frame = Instance.new("Frame")
		frame.Name = "Card"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Parent = g
		local function label(name, y, h, size, color)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.Position = UDim2.new(0, 8, 0, y)
			t.Size = UDim2.new(1, -16, 0, h)
			t.Font = FONT
			t.TextSize = size
			t.TextColor3 = color
			t.TextWrapped = true
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextYAlignment = Enum.TextYAlignment.Top
			t.Text = ""
			t.Parent = frame
			return t
		end
		local panel = {
			title = label("Title", 4, 22, 18, Color3.fromRGB(255, 220, 90)),
			normal = label("Normal", 30, 40, 12, Color3.fromRGB(235, 235, 245)),
			golden = label("Golden", 74, 40, 12, Color3.fromRGB(235, 235, 245)),
			status = label("Status", 120, 40, 16, Color3.fromRGB(255, 220, 90)),
		}
		panel.title.Text = "🛤️ TAPIS DU MARCHÉ · raretés"
		g.Parent = post
		result.belt = { body = body, panel = panel, gui = g, post = post }
	end

	-- Bases des joueurs : façade (-Z local) tournée vers la place, spawn devant ---------------------------
	local N = Config.PLOT_COUNT
	local half = M2.basePlatform / 2
	for i = 1, N do
		local pc = PLOT_COLORS[(i - 1) % #PLOT_COLORS + 1]
		local b = G.bases[(i - 1) % #G.bases + 1]
		local pos = Vector3.new(b.x, 0, b.z)
		local cf = CFrame.lookAt(pos, Vector3.new(M2.plaza.x, 0, M2.plaza.z)) -- l'avant (-Z) regarde la place
		local model = Instance.new("Model")
		model.Name = "Plot" .. i
		model.Parent = world
		local plat = part({ Name = "Platform", Size = Vector3.new(half * 2, 1, half * 2), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(62, 112, 88):Lerp(pc, 0.15), Material = Enum.Material.Concrete }, model)
		for _, e in ipairs({ { 0, -half + 0.5, half * 2, 1 }, { 0, half - 0.5, half * 2, 1 }, { -half + 0.5, 0, 1, half * 2 }, { half - 0.5, 0, 1, half * 2 } }) do -- liseré néon aux couleurs de la base
			part({ Name = "Edge", Size = Vector3.new(e[3], 0.25, e[4]), CFrame = cf * CFrame.new(e[1], 1.1, e[2]), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
		end
		for _, c in ipairs({ { -half + 1, -half + 1 }, { half - 1, -half + 1 }, { -half + 1, half - 1 }, { half - 1, half - 1 } }) do -- lampadaires
			part({ Name = "LampPost", Size = Vector3.new(0.9, 7, 0.9), CFrame = cf * CFrame.new(c[1], 4.5, c[2]), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal }, model)
			ball({ Name = "Lamp", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = cf * CFrame.new(c[1], 8.4, c[2]), Color = Color3.fromRGB(255, 235, 170), Material = Enum.Material.Neon }, model)
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 235, 190)
		glow.Range = 45
		glow.Brightness = 0.7
		glow.Parent = plat

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = cf * CFrame.new(0, 1.2, -M2.spawnForward)
		spawn.Color = pc
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.4
		spawn.Parent = model

		local pads = {}
		for idx = 1, Config.SLOTS_MAX do
			local lx, lz = Config.padLocal(idx)
			local frame = part({ Name = "PadFrame" .. idx, Size = Vector3.new(8.8, 0.3, 8.8), CFrame = cf * CFrame.new(lx, 1.12, lz), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
			local pad = part({ Name = "Pad" .. idx, Size = Vector3.new(8, 0.4, 8), CFrame = cf * CFrame.new(lx, 1.2, lz), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7, CanCollide = false }, model)
			local lockText = sign(pad, "🔒", Color3.new(1, 1, 1), 2.5, 80)
			pads[idx] = { part = pad, lock = lockText.Parent, frame = frame, content = nil }
			if Config.Map.pedestals then
				sceneryParts += Scenery.pedestal(sceneryHelpers, (cf * CFrame.new(lx, 0.62, lz)).Position, model, nil, 8.6, true)
			end
		end

		local board = part({ Name = "Board", Size = Vector3.new(1, 7, 1), CFrame = cf * CFrame.new(17, 4.5, -25), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, model) -- lot 5 : le panneau passe devant (les emplacements occupent désormais tout le centre)
		local plank = part({ Name = "Plank", Size = Vector3.new(18, 4.2, 0.7), CFrame = cf * CFrame.new(17, 8.6, -25.4), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, model)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front -- face -Z de la planche = côté place
		sg.CanvasSize = Vector2.new(720, 168)
		sg.LightInfluence = 0
		sg.Adornee = plank
		sg.Parent = plank
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.Font = FONT
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = pc
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Text = "Base libre"
		nameLabel.Parent = sg
		board.Name = "BoardPole"

		builtPlots[i] = { spawn = spawn }
		result.plots[i] = { model = model, cf = cf, pads = pads, spawn = spawn, nameLabel = nameLabel, owner = nil, platform = plat, color = pc, index = i }
	end

	-- Chemins, eau, château, arène, secrets (chaque bloc est isolé : une erreur de décor ne bloque jamais le jeu)
	deco("paths", function()
		return Scenery.paths(sceneryHelpers, world, Config, G)
	end)
	deco("rivers", function()
		return Scenery.rivers(sceneryHelpers, world, Config, G)
	end)
	deco("lakes", function()
		return Scenery.lakes(sceneryHelpers, world, Config, G)
	end)
	local doorPos = nil
	deco("castlePlateau", function()
		local count, door = Scenery.castlePlateau(sceneryHelpers, world, Config, G)
		doorPos = door
		return count
	end)
	deco("castle", function()
		local cw, cn = Scenery.castle(sceneryHelpers, world, Castle, doorPos)
		result.castle = cw
		builtCastle = cw
		return cn
	end)
	deco("arena", function()
		return Scenery.arena(sceneryHelpers, world, Config)
	end)
	deco("secrets", function()
		return Scenery.secrets(sceneryHelpers, world, Config)
	end)

	-- Voyage rapide (Config.TRAVEL2) : 4 portails sur la rose des portails, un tapis de retour vers la place près de chaque arrivée, une arche
	-- « Retour à la base » par base sur la place (prompt serveur, tag « FastTravel », attribut Dest ; le serveur valide tout)
	result.fastTravel = {}
	do
		local folder = Instance.new("Folder")
		folder.Name = "FastTravel"
		folder.Parent = world
		local function pad(x, z, dest, label, color, arch)
			local p = part({ Name = "TravelPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(x, 0.55, z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 0.25, CanCollide = false }, folder)
			part({ Name = "TravelRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 8.4, 8.4), CFrame = CFrame.new(x, 0.52, z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Transparency = 0.5, CanCollide = false }, folder)
			if arch then -- arche : deux piliers et un linteau (on passe dessous)
				for _, sx in ipairs({ -4, 4 }) do
					part({ Name = "TravelArch", Size = Vector3.new(1, 9, 1), Position = Vector3.new(x + sx, 4.5, z), Color = color:Lerp(Color3.fromRGB(80, 70, 60), 0.4), Material = Enum.Material.Slate }, folder)
				end
				part({ Name = "TravelArch", Size = Vector3.new(9.6, 1.2, 1.2), Position = Vector3.new(x, 9.4, z), Color = color, Material = Enum.Material.Neon, CanCollide = false }, folder)
			end
			sign(p, label, color:Lerp(Color3.new(1, 1, 1), 0.4), arch and 11 or 4.5, 190)
			local pr = Instance.new("ProximityPrompt")
			pr.ActionText = dest < 0 and "Rentrer à la base" or "Voyage rapide"
			pr.ObjectText = label
			pr.HoldDuration = 0.6
			pr.MaxActivationDistance = 8
			pr.RequiresLineOfSight = false
			pr:SetAttribute("Dest", dest)
			pr.Parent = p
			CollectionService:AddTag(pr, "FastTravel")
			result.fastTravel[#result.fastTravel + 1] = { prompt = pr, dest = dest, pos = Vector3.new(x, 0.3, z) }
		end
		local cols = { Color3.fromRGB(255, 130, 90), Color3.fromRGB(170, 120, 230), Color3.fromRGB(110, 200, 120), Color3.fromRGB(90, 190, 255) }
		for k, pt in ipairs(G.portals) do
			pad(pt.pad.x, pt.pad.z, k, "🌀 " .. pt.name .. (pt.chapter > 0 and ("\n🔒 chapitre " .. pt.chapter) or ""), cols[(k - 1) % #cols + 1], true)
			pad(pt.back.x, pt.back.z, 0, "🌀 Place du marché", Color3.fromRGB(255, 214, 120), false)
		end
		for i, a in ipairs(G.homeArches) do
			if i <= N then
				pad(a.x, a.z, -i, "🏠 Retour à la base " .. i, PLOT_COLORS[(i - 1) % #PLOT_COLORS + 1], true)
			end
		end
	end

	-- Pièges des territoires (REFONTE lot 4) : le plan vient de Traps.layout (pur, dérivé de Config.TERR) ; < 40 Parts au total. Le serveur (Main) les anime.
	result.traps = { layouts = {}, lights = {}, plates = {}, gate = nil, parts = 0 }
	do
		local function addPart(props, parent)
			props.CanCollide = props.CanCollide == true
			result.traps.parts += 1
			return part(props, parent)
		end
		for _, key in ipairs(Config.TERR_ORDER) do
			local L = TrapsMod.layout(Config, key)
			if L then
				result.traps.layouts[key] = L
				local folder = Instance.new("Folder")
				folder.Name = "Traps_" .. key
				folder.Parent = world
				local gy = G.groundY(L.cx, L.cz)
				for _, b in ipairs(L.bells) do
					local len = math.sqrt((b.bx - b.ax) ^ 2 + (b.bz - b.az) ^ 2)
					for _, e in ipairs({ { b.ax, b.az }, { b.bx, b.bz } }) do
						addPart({ Name = "BellPost", Size = Vector3.new(0.5, 3.4, 0.5), Position = Vector3.new(e[1], gy + 1.7, e[2]), Color = Color3.fromRGB(110, 76, 46), Material = Enum.Material.Wood }, folder)
					end
					local wire = addPart({ Name = "BellWire", Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt(Vector3.new(b.x, gy + 2.7, b.z), Vector3.new(b.bx, gy + 2.7, b.bz)), Color = Color3.fromRGB(255, 214, 90), Material = Enum.Material.Metal }, folder)
					sign(wire, "🔔", Color3.fromRGB(255, 226, 120), 1.2, 60)
				end
				for _, m in ipairs(L.mud) do
					addPart({ Name = "MudPuddle", Size = Vector3.new(0.15, m.r * 2, m.r * 2), CFrame = CFrame.new(m.x, gy + 0.3, m.z) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(88, 62, 42), Material = Enum.Material.Mud }, folder)
				end
				for plIdx, pl in ipairs(L.plates) do
					local plate = addPart({ Name = "AlarmPlate", Size = Vector3.new(0.25, pl.r * 2, pl.r * 2), CFrame = CFrame.new(pl.x, gy + 0.32, pl.z) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(150, 60, 60), Material = Enum.Material.Metal }, folder)
					result.traps.plates[#result.traps.plates + 1] = { part = plate, key = key, index = plIdx }
				end
				for liIdx, l in ipairs(L.lights) do
					addPart({ Name = "LanternPole", Size = Vector3.new(0.6, 5.2, 0.6), Position = Vector3.new(l.x, gy + 2.6, l.z), Color = Color3.fromRGB(70, 70, 78), Material = Enum.Material.Metal }, folder)
					local beam = addPart({ Name = "LanternBeam", Size = Vector3.new(0.5, 0.5, l.range), Position = Vector3.new(l.x, gy + 5.2, l.z + l.range / 2), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon, Transparency = 0.55 }, folder)
					result.traps.lights[#result.traps.lights + 1] = { part = beam, key = key, index = liIdx, light = l, y = gy + 5.2 }
				end
			end
		end
		-- herse de la cour de Zed : la Part CourtGate de Scenery (levée, sans collision) devient une vraie herse de la hauteur du mur, animée par le serveur
		for _, d in ipairs(world:GetDescendants()) do
			if d.Name == "CourtGate" and d:IsA("BasePart") then
				d.Size = Vector3.new(d.Size.X, 8, d.Size.Z)
				result.traps.gate = { part = d, baseCF = d.CFrame, lift = -1 }
				break
			end
		end
	end

	local total = 0
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BasePart") then
			total += 1
		end
	end
	result.partCount = total
	result.sceneryParts = sceneryParts
	if total > Config.Map.budgetParts then
		warn("[Builder] budget mobile dépassé : " .. total .. " Parts (budget " .. Config.Map.budgetParts .. "). Réduis le décor (Scenery) ou Config.Map.budgetParts.")
	else
		print("[Builder] carte construite : " .. total .. " Parts (budget " .. Config.Map.budgetParts .. ")")
	end

	result.treadmillContains = function(p)
		local rel = result.treadmill.cf:PointToObjectSpace(p)
		local s = result.treadmill.size
		return math.abs(rel.X) <= s.X / 2 and math.abs(rel.Z) <= s.Z / 2 and rel.Y > 0 and rel.Y < 8
	end

	return result
end

---------------------------------------------------------------- Effets
-- Explosion de particules + flash lumineux à l'éclosion (disparaît seule).
function Builder.burst(position, color, count, big)
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(big and 14 or 8, big and 32 or 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.8 or 1), NumberSequenceKeypoint.new(1, 0) })
	e.Rate = 0
	e.Parent = anchor
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = big and 26 or 14
	l.Brightness = big and 6 or 3
	l.Parent = anchor
	anchor.Parent = workspace
	e:Emit(count)
	local ring = Instance.new("Part")
	ring.Name = "Shockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 3, 3)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring:SetAttribute("Big", big == true)
	CollectionService:AddTag(ring, "Shockwave") -- animée côté client
	ring.Parent = workspace
	game:GetService("Debris"):AddItem(ring, 1.5)
	game:GetService("TweenService"):Create(l, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	game:GetService("Debris"):AddItem(anchor, 2.5)
end

-- Œuf qui vole vers le joueur qui vient de le prendre (animé côté client grâce au tag FlyEgg).
function Builder.flyEgg(tier, fromPos, userId)
	local egg = Builder.egg(tier, true)
	egg.Name = "FlyEgg"
	egg.CFrame = CFrame.new(fromPos)
	egg:SetAttribute("Target", userId)
	egg:SetAttribute("Start", fromPos)
	CollectionService:AddTag(egg, "FlyEgg")
	egg.Parent = workspace
	game:GetService("Debris"):AddItem(egg, 1.2)
	return egg
end

-- Pet suiveur : version miniature d'un pet, sans étiquette.
-- Aura d'une rareté élevée : cercle runique, particules, pilier de lumière (voir Scenery.aura), détruite seule. Retourne true si créée.
function Builder.aura(position, color, tier, secret)
	local style = Config.auraStyle(tier, secret, false)
	if not style then
		return false
	end
	local ok, anchor = pcall(function()
		local a = Scenery.aura({ part = part, ball = ball }, position, workspace, style, color)
		CollectionService:AddTag(a, "AuraFx")
		return a
	end)
	if not ok then
		return false
	end
	game:GetService("Debris"):AddItem(anchor, style.seconds)
	return true
end

-- Nid sous un œuf (paille : plateau, bord, brins) ; remplacé par le modèle Blender NidOeufs si disponible. Retourne le nombre de Parts du repli.
-- Protection Blender de l'œuf d'un emplacement selon la rareté (nid à barrière, dôme de verre, cage, cristaux) : mise à la largeur cible, vitre du dôme
-- translucide, lumière proportionnelle à la rareté. `budget` = { used = n } (Parts de protection déjà posées dans la base). Retourne le nombre de Parts
-- posées ou nil (repli : nid procédural). Ne lève jamais d'erreur.
function Builder.eggGuard(position, parent, tier, budget)
	if not eggAssets or not eggAssets.cloneModel then
		return nil
	end
	local key = Config.eggGuardKey(tier)
	local st = eggAssets.status and eggAssets.status["m:eggguard." .. key]
	local cost = (st and st.ok and st.parts) or 0
	if cost <= 0 or (budget and budget.used + cost > Config.Assets.eggGuardBudgetPerBase) then
		return nil
	end
	local clone = eggAssets.cloneModel("eggguard", key)
	if not clone then
		return nil
	end
	local ok, count = eggAssets.place(clone, position.X, position.Z, 0, nil, parent, Config.Assets.eggGuardWidth[key], position.Y)
	if not ok then
		return nil
	end
	pcall(function()
		clone.Name = "EggGuard"
		local glow = Config.eggGuardGlow(tier)
		local tint = Config.TIERS[math.min(math.max(tier, 1), #Config.TIERS)].color
		local first
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				first = first or d
				if AssetsMod.baseName(d.Name) == "Dome_Verre" then
					d.Transparency = 0.7
					d.Material = Enum.Material.Glass
					d.Color = d.Color:Lerp(tint, 0.35)
					d.CastShadow = false
				end
			end
		end
		if first then
			local l = Instance.new("PointLight")
			l.Name = "RarityGlow"
			l.Color = tint
			l.Brightness = glow.brightness
			l.Range = glow.range
			l.Parent = first
		end
	end)
	if budget then
		budget.used = budget.used + (count or cost)
	end
	pcall(function()
		parent:SetAttribute("GuardParts", count or cost) -- relu par clearPad pour rendre le budget à la base
	end)
	return count or cost
end

function Builder.nest(position, parent, tier, budget)
	if tier and Builder.eggGuard(position, parent, tier, budget) then
		return 0
	end
	-- modèle Blender NidOeufs s'il est chargé (cloné, jamais rechargé), sinon nid de paille procédural
	local clone = eggAssets and eggAssets.cloneProp and eggAssets.cloneProp("nest")
	if clone then
		local ok = eggAssets.place(clone, position.X, position.Z, 0, Config.Assets.propsHeight.nest, parent, nil, position.Y)
		if ok then
			return 0
		end
	end
	local ok, n = pcall(Scenery.nest, { part = part, ball = ball }, position, parent)
	return ok and n or 0
end

-- Pose les accessoires Blender sur la carte une fois chargés (arbres, sapins, rochers, buissons, cabanes, barrières, ponts) avec un budget de Parts :
-- le placement s'arrête dès que Config.Assets.propsBudgetParts serait dépassé. Positions déterministes, hors domaines, secrets, rivières et bases.
-- Retourne le nombre de Parts posées. Ne lève jamais d'erreur (tout sous pcall) ; rien n'est posé si les modèles sont absents (la carte reste procédurale).
function Builder.dressWorld(assets)
	local total, placed = 0, 0
	local ok = pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do -- la carte est construite en parallèle : on l'attend (30 s au plus)
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "BlenderProps"
		folder.Parent = world
		-- Pose PLANIFIÉE (Placement) : grille, empreintes sans recouvrement, rien dans l'eau ni sur un chemin, cabanes face à leur domaine, barrières
		-- alignées, ponts centrés sur leurs rivières et plus longs qu'elles.
		local plan = PlacementMod.new(Config).plan()
		local huts, treeIdx, fences = 0, 0, 0
		local function put(key, x, z, rot, length, gy)
			if total + (Config.Assets.propsMaxParts[key] or 0) > Config.Assets.propsBudgetParts then
				return
			end
			local clone, height = nil, Config.Assets.propsHeight[key]
			if key == "bridge" then
				clone = assets.cloneModel("props", "bridge_rail") -- pont à rampes (repli : pont simple)
			elseif key == "hut" then
				huts = huts + 1
				local alt = huts % 2 == 1 and "hut_big" or "hut_small"
				clone = assets.cloneModel("props", alt)
				height = clone and Config.Assets.targetHeights[alt] or height
			end
			if key == "fence" then
				fences = fences + 1
				clone = assets.cloneModel("props", fences % 4 == 0 and "fence_gate" or "fence_corner") -- barrières Blender (le catalogue d'accessoires reste le repli)
			end
			if key == "tree" or key == "fir" then
				treeIdx = treeIdx + 1
				local variant = PlacementMod.treeVariant(Config, key, x, z, treeIdx)
				local st = assets.status and assets.status["m:trees." .. variant]
				local vc = st and st.ok and st.parts or Config.Assets.propsMaxParts[key]
				if st and st.ok and total + vc <= Config.Assets.propsBudgetParts then
					clone = assets.cloneModel("trees", variant)
					if clone then
						height = (Config.Assets.treeHeights[variant] or height) * PlacementMod.jitter(x, z, Config.Assets.treeScaleJitter)
					end
				end
			end
			clone = clone or assets.cloneProp(key)
			if not clone then
				return
			end
			local okPlace, count = assets.place(clone, x, z, rot, height, folder, length, gy)
			if okPlace then
				total = total + count
				placed = placed + 1
			end
		end
		for _, it in ipairs(plan.items) do
			put(it.kind, it.x, it.z, it.rot, nil, it.y)
		end
		for _, b in ipairs(plan.bridges) do
			put("bridge", b.x, b.z, b.rot, b.length)
		end
	end)
	return ok and total or 0, placed
end

function Builder.follower(petIdx, sizeIdx, mutIdx)
	local model = Builder.pet(petIdx, sizeIdx, mutIdx)
	model:ScaleTo(0.45)
	model:SetAttribute("Seed", petIdx * 31 + sizeIdx * 7 + mutIdx)
	return model
end

---------------------------------------------------------------- Corbeau chipeur et tapis privé (lot 7)
-- Corbeau du vol à distance : modèle Blender `npc.raven` s'il a été chargé (aucun ID pour l'instant : REPLI procédural), sinon 6 Parts minuscules (corps, tête, bec, 2 ailes,
-- queue), sans collision, TEMPORAIRES (détruites à la fin du vol ; au plus un par joueur voleur). Retourne le modèle (PrimaryPart = corps) ; `Builder.ravenFlap` bat des ailes.
function Builder.raven(parent)
	local ok, model = pcall(function()
		local clone = eggAssets and eggAssets.cloneModel and eggAssets.cloneModel("npc", "raven")
		if not (clone and clone:IsA("Model")) then
			if clone then
				clone:Destroy()
			end
			return nil
		end
		local first
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				first = first or d
			end
		end
		if not first then
			clone:Destroy()
			return nil
		end
		clone.PrimaryPart = clone.PrimaryPart or first
		clone.Name = "Raven"
		return clone
	end)
	if not (ok and model) then
		model = Instance.new("Model")
		model.Name = "Raven"
		local black, grey = Color3.fromRGB(28, 28, 36), Color3.fromRGB(52, 52, 64)
		local function bit(name, size, off, color)
			local p = part({ Name = name, Size = size, CFrame = CFrame.new(off.X, off.Y, off.Z), Color = color, CanCollide = false, CanTouch = false, CanQuery = false }, model)
			return p
		end
		local body = bit("Body", Vector3.new(1.6, 1.4, 2.6), Vector3.new(0, 0, 0), black)
		bit("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 0.5, -1.7), black)
		bit("Beak", Vector3.new(0.4, 0.4, 0.9), Vector3.new(0, 0.4, -2.5), Color3.fromRGB(235, 170, 50))
		bit("WingL", Vector3.new(2.6, 0.2, 1.6), Vector3.new(-2, 0.2, 0), grey)
		bit("WingR", Vector3.new(2.6, 0.2, 1.6), Vector3.new(2, 0.2, 0), grey)
		bit("Tail", Vector3.new(1, 0.2, 1.4), Vector3.new(0, 0, 1.9), grey)
		model.PrimaryPart = body
	end
	model:SetAttribute("Flap", false)
	model.Parent = parent
	return model
end

-- Bat des ailes (alterne deux poses : pas de rotation, simple décalage vertical) : appelée quelques fois par seconde par le serveur pendant le vol.
function Builder.ravenFlap(model, up)
	local body = model and model.PrimaryPart
	if not body then
		return
	end
	local dy = up and 0.55 or -0.2
	for name, dx in pairs({ WingL = -2, WingR = 2 }) do
		local w = model:FindFirstChild(name)
		if w then
			w.CFrame = body.CFrame * CFrame.new(dx, dy, 0)
		end
	end
end

-- Tapis privé d'une base (pass PrivateBelt) : un dossier « PrivateBelt » dans le modèle de la base, avec le tapis 10 x 3 (1 Part, prompt réservé au propriétaire) et un petit œuf
-- par œuf en attente (3 au plus) : 4 Parts au maximum, détruit avec le propriétaire. `tiers` = raretés en attente. Retourne le dossier.
function Builder.privateBelt(plot, ownerId, tiers)
	Builder.clearPrivateBelt(plot)
	local P = Config.BELT.private
	local folder = Instance.new("Folder")
	folder.Name = "PrivateBelt"
	local belt = part({ Name = "PrivateBeltStrip", Size = Vector3.new(P.width, 0.3, P.depth), CFrame = plot.cf * CFrame.new(P.x or 0, 1.3, P.z), Color = Color3.fromRGB(46, 50, 62), Material = Enum.Material.Metal, CanCollide = false }, folder)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Prendre l'œuf gratuit"
	pr.ObjectText = "Tapis privé"
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Enabled = #tiers > 0
	pr:SetAttribute("Kind", "PrivBelt")
	pr:SetAttribute("Owner", ownerId)
	pr.Parent = belt
	local label = #tiers > 0 and ("🥚 " .. #tiers .. " œuf(s) à prendre") or "🛤️ Tapis privé"
	sign(belt, label, Color3.fromRGB(255, 235, 170), 3.5, 220)
	for i, t in ipairs(tiers) do
		local def = Config.TIERS[t]
		if def then
			local egg = ball({ Name = "PrivateEgg" .. i, Size = Vector3.new(1.9, 1.9, 1.9), CFrame = plot.cf * CFrame.new((P.x or 0) + (i - 2) * 3.4, 2.4, P.z), Color = def.color, Material = Enum.Material.SmoothPlastic, CanTouch = false, CanQuery = false }, folder)
			sign(egg, def.name, def.color, 2, 120)
		end
	end
	folder.Parent = plot.model
	plot.privateBelt = folder
	return folder
end

function Builder.clearPrivateBelt(plot)
	local f = plot and plot.privateBelt
	plot.privateBelt = nil
	if f then
		pcall(function()
			f:Destroy()
		end)
	end
end

return Builder

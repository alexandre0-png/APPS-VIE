-- ModuleScript : ServerScriptService/Builder
-- Construit TOUT le visuel avec des Parts, matériaux et particules de base Roblox (aucun asset externe).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))
local Castle = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Castle"))

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
		local _, size = clone:GetBoundingBox()
		if size.Y < 0.05 then
			error("hauteur nulle")
		end
		clone:ScaleTo(Config.Assets.targetHeight / size.Y)
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
		if look.halo then
			addHalo(p, look.halo)
		end
		if look.particles then
			addParticles(p, look.particles)
		end
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
		local _, sz = clone:GetBoundingBox()
		if sz.Y < 0.05 then
			error("hauteur nulle")
		end
		local height = Config.Assets.petHeight * size.scale
		clone:ScaleTo(height / sz.Y)
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
	local R = 1.5 * size.scale
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
	if def.tier <= 3 then
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
		local _, size = clone:GetBoundingBox()
		if size.Y < 0.05 then
			error("hauteur nulle")
		end
		clone:ScaleTo(height / size.Y)
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
			clone:ScaleTo(height / size.Y)
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
			put("castle", "tower", ex + sx, 0, ez, nil, 24, 0, "CastleTowerModel")
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
			local chest = put("props", "chest", w.chest.Position.X, 0, w.chest.Position.Z, nil, 4, 0, "CastleChestModel")
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
		put("ground", "plaza", 0, 0.08, 0, 56, nil, 0, "ArenaPlaza")
		for k = 0, 3 do
			local a = k * math.pi / 2
			put("props", "bench", math.sin(a) * 24, 0, -math.cos(a) * 24, nil, 2.4, a, "ArenaBench") -- le banc regarde le monument
			local b = a + math.pi / 4
			put("props", "lamp", math.sin(b) * 28, 0, -math.cos(b) * 28, nil, 9, 0, "ArenaLamp")
		end
		local cx, cz = Config.rivalCenter(1)
		local mill = put("props", "mill", cx - 44, 0, cz + 22, nil, 13, math.pi / 6, "ArenaMill")
		if mill then
			local p1, p2 = findNamed(mill, "Pales"), findNamed(mill, "Pales2")
			if p1 then
				millVis = { p1 = p1, b1 = p1.CFrame, p2 = p2, b2 = p2 and p2.CFrame }
			end
		end
		put("props", "pen", cx + 30, 0, cz + 44, 16, nil, 0, "ArenaPen")
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
	local s = sign(body, "🐕 Gardien de " .. r.name, Color3.fromRGB(255, 120, 120), 4, 220)
	s.TextSize = 14
	return model
end

---------------------------------------------------------------- Éclairage
-- Ambiance « jour doré » : soleil chaud, brume légère, bloom discret, étalonnage plus vif.
function Builder.setupLighting()
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(95, 105, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 135, 155)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 205)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.25
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
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(199, 220, 255)
	atm.Decay = Color3.fromRGB(255, 214, 170)
	atm.Glare = 0.25
	atm.Haze = 1.4

	effect("BloomEffect", "ChipeBloom", { Intensity = 0.4, Size = 28, Threshold = 0.95 })
	effect("SunRaysEffect", "ChipeSunRays", { Intensity = 0.15, Spread = 0.8 })
	effect("ColorCorrectionEffect", "ChipeGrade", { Saturation = 0.18, Contrast = 0.1, Brightness = 0.02 })
end

---------------------------------------------------------------- Monument du Grand Nid (identité du jeu, au centre de l'arène)
function Builder.monument(parent)
	local gold = Color3.fromRGB(255, 214, 120)
	part({ Name = "MonumentBase", Size = Vector3.new(1.4, 17, 17), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(176, 160, 128), Material = Enum.Material.Slate }, parent)
	part({ Name = "MonumentStep", Size = Vector3.new(0.8, 12, 12), CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(130, 116, 92), Material = Enum.Material.Slate }, parent)
	local egg = Instance.new("Part")
	egg.Name = "GrandNid"
	egg.Anchored = true
	egg.Size = Vector3.new(8, 11, 8)
	egg.CFrame = CFrame.new(0, 8.1, 0)
	egg.Color = gold
	egg.Material = Enum.Material.Metal
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Range = 28
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
	for k, c in ipairs({ { 0, 9.5, -3.7, 0.3 }, { 1.2, 6.6, -3.75, -0.5 }, { -1.1, 4.2, -3.6, 0.6 } }) do -- fissures lumineuses
		part({ Name = "Crack" .. k, Size = Vector3.new(0.35, 3.2, 0.35), CFrame = CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, 0, c[4]), Color = Color3.fromRGB(255, 248, 200), Material = Enum.Material.Neon, CanCollide = false }, parent)
	end
	-- Quatre runes cardinales (Nord = côté des rivaux). Chaque joueur règle ses propres runes : le symbole affiché est local au client
	-- (étiquette « Label » modifiée côté client), l'état est tenu par le serveur.
	local dirs = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
	for k, dv in ipairs(dirs) do
		local x, z = dv[1] * 9.5, dv[2] * 9.5
		local stone = part({ Name = "RuneStone", Size = Vector3.new(2.4, 5, 1.2), CFrame = CFrame.lookAt(Vector3.new(x, 3.2, z), Vector3.new(0, 3.2, 0)), Color = Color3.fromRGB(110, 104, 96), Material = Enum.Material.Slate }, parent)
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
	confirm.ObjectText = "Grand Nid"
	confirm.HoldDuration = 0.5
	confirm.MaxActivationDistance = 14
	confirm.RequiresLineOfSight = false
	confirm:SetAttribute("Kind", "RuneConfirm")
	confirm.Parent = egg
	-- Panneau de l'énigme de Mère Poule (texte mis à jour chaque jour par le serveur), lisible des deux côtés
	local board = part({ Name = "RiddleBoard", Size = Vector3.new(12, 4.6, 0.5), Position = Vector3.new(0, 3.8, 14), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, parent)
	part({ Name = "RiddlePostL", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(-5.4, 2, 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
	part({ Name = "RiddlePostR", Size = Vector3.new(0.7, 4, 0.7), Position = Vector3.new(5.4, 2, 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, parent)
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
		title.Text = "📜 Énigme de Mère Poule"
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
		body.Text = "…"
		body.Parent = sg
		labels[#labels + 1] = body
	end
	local result = { labels = labels, center = Vector3.new(0, 8.1, 0) }
	local t = sign(egg, "✨ Le Grand Nid ✨\nReconstruis la Couvée, Chipeur !", gold, 9, 340)
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
	local label = sign(body, "🐔 Mère Poule\nGardienne du Grand Nid", Color3.fromRGB(255, 220, 140), 5.5, 260)
	label.TextSize = 17
	model:SetAttribute("Seed", 3)
	CollectionService:AddTag(model, "Hen")
	model:PivotTo(CFrame.lookAt(Vector3.new(-9, 3.2, 13), Vector3.new(0, 3.2, 0))) -- regarde le Grand Nid
	model.Parent = parent
	return model
end

---------------------------------------------------------------- Monde
local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80), Color3.fromRGB(255, 230, 90), Color3.fromRGB(140, 230, 110),
	Color3.fromRGB(80, 220, 200), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 130, 220),
	Color3.fromRGB(235, 235, 235), Color3.fromRGB(170, 190, 160),
}
Builder.PLOT_COLORS = PLOT_COLORS
local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 130, 255), Color3.fromRGB(255, 150, 70),
}

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

-- Retourne { plots, nests, treadmill, guards, treadmillContains }
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

	-- Sol, relief et décor ----------------------------------------------------------
	part({ Name = "Ground", Size = Vector3.new(Config.Map.groundSize, 2, Config.Map.groundSize), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(92, 160, 82), Material = Enum.Material.Grass }, world)
	local rng = Random.new(7)
	local half = Config.Map.groundSize / 2
	for _ = 1, 40 do -- taches d'herbe plus claires / plus sombres
		local d = rng:NextNumber(40, 100)
		local c = rng:NextNumber() < 0.5 and Color3.fromRGB(104, 172, 90) or Color3.fromRGB(80, 146, 74)
		part({ Name = "Patch", Size = Vector3.new(0.1, d, d), CFrame = CFrame.new(rng:NextNumber(-half + 40, half - 40), 0.03, rng:NextNumber(-half + 40, half - 40)) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = c, Material = Enum.Material.Grass, CanCollide = false }, world)
	end
	for k = 0, 23 do -- collines à l'horizon (hors de la zone de jeu)
		local a = k / 24 * math.pi * 2
		local sz = rng:NextNumber(240, 380)
		ball({ Name = "Hill", Size = Vector3.new(sz, sz, sz), Position = Vector3.new(math.sin(a) * (half + 90), -sz * 0.36, math.cos(a) * (half + 90)), Color = Color3.fromRGB(78 + (k % 3) * 8, 150 + (k % 2) * 10, 80), Material = Enum.Material.Grass }, world)
	end
	for _, w in ipairs({ { 0, half - 2, half * 2, 4 }, { 0, -half + 2, half * 2, 4 }, { half - 2, 0, 4, half * 2 }, { -half + 2, 0, 4, half * 2 } }) do -- murs invisibles : on ne tombe plus dans le vide
		part({ Name = "Wall", Size = Vector3.new(w[3], 100, w[4]), Position = Vector3.new(w[1], 50, w[2]), Transparency = 1 }, world).CanQuery = false
	end
	part({ Name = "ArenaRim", Size = Vector3.new(0.2, 156, 156), CFrame = CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(150, 125, 85), Material = Enum.Material.Sand, CanCollide = false }, world)
	part({ Name = "Arena", Size = Vector3.new(0.3, 150, 150), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(214, 190, 140), Material = Enum.Material.Sand, CanCollide = false }, world)

	local monument = Builder.monument(world)
	Builder.hen(world)

	local function inDomain(x, z)
		for i = 1, #Config.RIVALS do
			local dx, dz = Config.rivalCenter(i)
			if math.sqrt((x - dx) ^ 2 + (z - dz) ^ 2) < Config.Map.domainRadius + 14 then
				return true
			end
		end
		return false
	end
	for _ = 1, 38 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(90, 125)
		local tx, tz = math.sin(a) * r, math.cos(a) * r
		if not inDomain(tx, tz) then
			tree(Vector3.new(tx, 0, tz), world, rng)
		end
	end
	for _ = 1, 110 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, 136)
		ball({ Name = "Flower", Size = Vector3.new(0.9, 0.9, 0.9), Position = Vector3.new(math.sin(a) * r, 0.45, math.cos(a) * r), Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)] }, world)
	end
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(80, 138)
		local sz = rng:NextNumber(2.5, 5)
		ball({ Name = "Rock", Size = Vector3.new(sz, sz, sz), Position = Vector3.new(math.sin(a) * r, sz * 0.15, math.cos(a) * r), Color = Color3.fromRGB(130, 134, 140), Material = Enum.Material.Slate }, world)
	end

	local result = { plots = {}, nests = {}, guards = {}, riddleLabels = monument.labels, monumentCenter = monument.center }

	-- Rivaux PNJ (au nord, z négatif) ------------------------------------------------
	local sceneryHelpers = { part = part, ball = ball, tree = tree, torch = torch, sign = sign }
	local sceneryParts = 0
	for i, riv in ipairs(Config.RIVALS) do
		local cx, cz = Config.rivalCenter(i)
		local folder = Instance.new("Folder")
		folder.Name = "Rival_" .. riv.name
		folder.Parent = world
		part({ Name = "GlowRing", Size = Vector3.new(0.4, 38, 38), CFrame = CFrame.new(cx, 0.3, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = riv.color, Material = Enum.Material.Neon, CanCollide = false }, folder)
		part({ Name = "Disc", Size = Vector3.new(1, 34, 34), CFrame = CFrame.new(cx, 0.5, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = riv.color:Lerp(Color3.fromRGB(70, 55, 40), 0.55), Material = Enum.Material.Slate, CanCollide = false }, folder)
		for k = 0, 13 do -- palissade sur l'arrière (le devant reste ouvert vers l'arène)
			local t = -0.15 * math.pi + k * (1.3 * math.pi / 13)
			local pp = Vector3.new(cx + 17.5 * math.cos(t), 0, cz - 17.5 * math.sin(t))
			part({ Name = "Post", Size = Vector3.new(1, 4, 1), Position = pp + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(100, 70, 46), Material = Enum.Material.Wood }, folder)
			ball({ Name = "PostCap", Size = Vector3.new(0.9, 0.9, 0.9), Position = pp + Vector3.new(0, 4.9, 0), Color = riv.color, Material = Enum.Material.Neon }, folder)
		end
		torch(Vector3.new(cx - 15, 0.5, cz + 9), folder)
		torch(Vector3.new(cx + 15, 0.5, cz + 9), folder)
		sceneryParts += Scenery.moat(sceneryHelpers, cx, cz, folder, Config)
		local theme = Scenery[Config.Map.zoneKeys[i]]
		if theme then
			local okS, countS = pcall(theme, sceneryHelpers, cx, cz, folder, Random.new(100 + i))
			if okS then
				sceneryParts += countS
			else
				warn("[Builder] décor du domaine " .. riv.name .. " : " .. tostring(countS))
			end
		end
		local zone = Config.ZONES[i]
		if zone and zone.chapter > 0 then
			-- Barrière du domaine verrouillé. Elle est solide pour tous ; le client la rend traversable (localement) dès que le
			-- joueur a réussi le chapitre requis. Le serveur refuse de toute façon tout vol dans une zone verrouillée.
			local gate = part({ Name = "ZoneGate", Size = Vector3.new(12, 40, 40), CFrame = CFrame.new(cx, 6, cz) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 70, 90), Material = Enum.Material.Neon, Transparency = 0.6 }, folder)
			gate:SetAttribute("Rival", i)
			gate:SetAttribute("Chapter", zone.chapter)
			CollectionService:AddTag(gate, "ZoneGate")
			sign(gate, "🔒 " .. zone.name .. "\nHistoire : chapitre " .. zone.chapter, Color3.fromRGB(255, 210, 210), 10, 300)
		end
		local pole = part({ Name = "Sign", Size = Vector3.new(1, 9, 1), Position = Vector3.new(cx, 4.5, cz - 14), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, folder)
		part({ Name = "Flag", Size = Vector3.new(0.2, 3, 5), Position = Vector3.new(cx + 0.2, 8, cz - 11.5), Color = riv.color, Material = Enum.Material.Fabric, CanCollide = false }, folder)
		local t = sign(pole, riv.emoji .. " " .. riv.name .. "  " .. string.rep("★", riv.stars), Color3.fromRGB(255, 220, 90), 7, 260)
		t.TextSize = 22
		for j = 1, 3 do
			local nx = cx + (j - 2) * 8
			local mound = part({ Name = "Nest", Size = Vector3.new(0.7, 6, 6), CFrame = CFrame.new(nx, 1, cz - 3) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.Wood, CanCollide = false }, folder)
			part({ Name = "NestStraw", Size = Vector3.new(0.3, 4.4, 4.4), CFrame = CFrame.new(nx, 1.25, cz - 3) * CFrame.Angles(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(226, 196, 120), Material = Enum.Material.Fabric, CanCollide = false }, folder)
			Scenery.marker(sceneryHelpers, Vector3.new(nx, 0.5, cz - 3), folder, "✋", 8)
			sceneryParts += 1
			result.nests[#result.nests + 1] = { rival = i, pos = Vector3.new(nx, 3.2, cz - 3), mound = mound, folder = folder, egg = nil, rt = math.random() * 6 }
		end
		local g = Builder.guard(i)
		g.Parent = folder
		builtGuards[#builtGuards + 1] = { model = g, rival = i }
		result.guards[#result.guards + 1] = {
			model = g, rival = i, cx = cx, patrolZ = cz + 12, pos = Vector3.new(cx, 2.4, cz + 12),
			dir = (i % 2 == 0) and -1 or 1, state = "patrol", cd = 0, lost = 0,
		}
		g:PivotTo(CFrame.new(cx, 2.4, cz + 12))
	end

	-- Tapis roulant (les rayures sont animées côté client grâce au tag BeltStripe) -----
	do
		local belt = part({ Name = "Treadmill", Size = Vector3.new(16, 1, 40), Position = Vector3.new(0, 0.6, 38), Color = Color3.fromRGB(45, 48, 56), Material = Enum.Material.Metal }, world)
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, -14) -- le tapis pousse vers -Z : il faut courir vers +Z
		for k = 0, 7 do
			local stripe = part({ Name = "Stripe", Size = Vector3.new(14, 0.1, 1.2), Position = Vector3.new(0, 1.16, 38 - 17.5 + k * 5), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon, CanCollide = false }, belt)
			stripe:SetAttribute("Z0", -17.5 + k * 5)
			stripe:SetAttribute("CenterZ", 38)
			CollectionService:AddTag(stripe, "BeltStripe")
		end
		for _, sx in ipairs({ -8.6, 8.6 }) do
			part({ Name = "Rail", Size = Vector3.new(0.8, 1.6, 40), Position = Vector3.new(sx, 1.1, 38), Color = Color3.fromRGB(255, 210, 63), Material = Enum.Material.Neon }, world)
		end
		local pole = part({ Name = "TreadSign", Size = Vector3.new(1, 8, 1), Position = Vector3.new(-11, 4, 38), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, world)
		sign(pole, "🏃 TAPIS ROULANT\nCours dessus pour gagner en vitesse !", Color3.fromRGB(255, 220, 90), 6, 300)
		result.treadmill = { cf = belt.CFrame, size = belt.Size }
	end

	-- Bases des joueurs ---------------------------------------------------------------
	local N = Config.PLOT_COUNT
	local radius = Config.Map.plotRadius
	for i = 1, N do
		local pc = PLOT_COLORS[(i - 1) % #PLOT_COLORS + 1]
		local a = (i - 1) / N * math.pi * 2
		local pos = Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- l'avant (-Z) regarde le centre
		local model = Instance.new("Model")
		model.Name = "Plot" .. i
		model.Parent = world
		local plat = part({ Name = "Platform", Size = Vector3.new(52, 1, 52), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(62, 112, 88):Lerp(pc, 0.15), Material = Enum.Material.Concrete }, model)
		for _, e in ipairs({ { 0, -25.5, 52, 1 }, { 0, 25.5, 52, 1 }, { -25.5, 0, 1, 52 }, { 25.5, 0, 1, 52 } }) do -- liseré néon aux couleurs de la base
			part({ Name = "Edge", Size = Vector3.new(e[3], 0.25, e[4]), CFrame = cf * CFrame.new(e[1], 1.1, e[2]), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
		end
		for _, c in ipairs({ { -25, -25 }, { 25, -25 }, { -25, 25 }, { 25, 25 } }) do -- lampadaires
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
		spawn.CFrame = cf * CFrame.new(0, 1.2, -20)
		spawn.Color = pc
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.4
		spawn.Parent = model

		local pads = {}
		for idx = 1, 12 do
			local lx, lz = Config.padLocal(idx)
			local frame = part({ Name = "PadFrame" .. idx, Size = Vector3.new(8.8, 0.3, 8.8), CFrame = cf * CFrame.new(lx, 1.12, lz), Color = pc, Material = Enum.Material.Neon, CanCollide = false }, model)
			local pad = part({ Name = "Pad" .. idx, Size = Vector3.new(8, 0.4, 8), CFrame = cf * CFrame.new(lx, 1.2, lz), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7, CanCollide = false }, model)
			local lockText = sign(pad, "🔒", Color3.new(1, 1, 1), 2.5, 80)
			pads[idx] = { part = pad, lock = lockText.Parent, frame = frame, content = nil }
			if Config.Map.pedestals then
				sceneryParts += Scenery.pedestal(sceneryHelpers, (cf * CFrame.new(lx, 0.62, lz)).Position, model, nil)
			end
		end

		local board = part({ Name = "Board", Size = Vector3.new(1, 7, 1), CFrame = cf * CFrame.new(0, 4.5, 24), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }, model)
		local plank = part({ Name = "Plank", Size = Vector3.new(18, 4.2, 0.7), CFrame = cf * CFrame.new(0, 8.6, 23.6), Color = Color3.fromRGB(120, 84, 56), Material = Enum.Material.WoodPlanks }, model)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front -- face -Z de la planche = côté arène
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

		result.plots[i] = { model = model, cf = cf, pads = pads, spawn = spawn, nameLabel = nameLabel, owner = nil, platform = plat, color = pc }
	end

	-- Chemins, repères lointains, relief, secrets (chaque bloc est isolé : une erreur de décor ne bloque jamais le jeu)
	local srng = Random.new(2024)
	for name, fn in pairs({
		paths = function()
			return Scenery.paths(sceneryHelpers, world, Config)
		end,
		rivers = function()
			return Scenery.rivers(sceneryHelpers, world, Config)
		end,
		castle = function()
			local cw, cn = Scenery.castle(sceneryHelpers, world, Castle)
			result.castle = cw
			builtCastle = cw
			return cn
		end,
		landmarks = function()
			return Scenery.landmarks(sceneryHelpers, world, srng)
		end,
		relief = function()
			return Scenery.relief(sceneryHelpers, world, srng, Config)
		end,
		secrets = function()
			return Scenery.secrets(sceneryHelpers, world, Config)
		end,
	}) do
		local okS, countS = pcall(fn)
		if okS then
			sceneryParts += countS
		else
			warn("[Builder] décor « " .. name .. " » : " .. tostring(countS))
		end
	end
	local total = 0
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BasePart") then
			total += 1
		end
	end
	result.partCount = total
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
function Builder.nest(position, parent)
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
		local rng = Random.new(77)
		local half = Config.Map.groundSize / 2
		local function free(x, z)
			for i = 1, #Config.RIVALS do
				local cx, cz = Config.rivalCenter(i)
				if math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) < 110 then
					return false
				end
			end
			for _, sct in ipairs(Config.SECRETS) do
				if math.sqrt((x - sct.x) ^ 2 + (z - sct.z) ^ 2) < 40 then
					return false
				end
			end
			if math.abs(z - 330) < 14 or math.abs(x + 380) < 14 then
				return false
			end
			local d = math.sqrt(x * x + z * z)
			return d > 270 and math.abs(x) < half - 40 and math.abs(z) < half - 40
		end
		local function put(key, x, z, rot, length)
			if total + (Config.Assets.propsMaxParts[key] or 0) > Config.Assets.propsBudgetParts then
				return
			end
			local clone = assets.cloneProp(key)
			if not clone then
				return
			end
			local okPlace, count = assets.place(clone, x, z, rot, Config.Assets.propsHeight[key], folder, length)
			if okPlace then
				total = total + count
				placed = placed + 1
			end
		end
		for _, key in ipairs({ "tree", "fir", "rock", "bush" }) do
			local n, tries = Config.Assets.propsPlan[key] or 0, 0
			while n > 0 and tries < 400 do
				tries = tries + 1
				local x, z = rng:NextNumber(-half + 60, half - 60), rng:NextNumber(-half + 60, half - 60)
				if free(x, z) then
					put(key, x, z, rng:NextNumber(0, 360))
					n = n - 1
				end
			end
		end
		for i = 1, #Config.RIVALS do -- une cabane et des barrières par domaine, côté arène
			local cx, cz = Config.rivalCenter(i)
			put("hut", cx + 34, cz + 16, 200)
			for k = 0, 3 do
				if k < math.ceil((Config.Assets.propsPlan.fence or 0) / #Config.RIVALS) then
					put("fence", cx - 18 + k * 12, cz + 34, 0)
				end
			end
		end
		for _, b in ipairs({ { -150, 330, 90 }, { 150, 330, 90 }, { -380, -150, 0 }, { -380, 150, 0 } }) do
			put("bridge", b[1], b[2], b[3], Config.Assets.bridgeLength)
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

return Builder

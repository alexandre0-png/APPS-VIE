-- WorldBuilder.luau : construit tout le monde en blocs Roblox classiques (lobby, parcelles, bâtiments).
-- Aucun asset externe : uniquement des Parts, matériaux et polices natifs.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DinoFactory = require(Shared.DinoFactory)
local HumanFactory = require(Shared.HumanFactory)

local W = {}

local FONT = Enum.Font.FredokaOne
local M = Enum.Material

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
function W.part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Cylindre vertical (axe Y) : height, diameter
function W.cylinder(parent, name, height, diameter, pos, color, material)
	local cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	return W.part(parent, name, Vector3.new(height, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

function W.ball(parent, name, diameter, pos, color, material)
	return W.part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material, Enum.PartType.Ball)
end

-- Ellipsoïde : un bloc avec SpecialMesh sphérique (un Ball natif impose des dimensions uniformes)
function W.ellipsoid(parent, name, size, cf, color, material)
	local p = W.part(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function W.decor(p)
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

function W.label(parent, text, size, offsetY, color, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = size or UDim2.fromOffset(200, 60)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or 90
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	t.Parent = bb
	return t
end

-- Panneau avec texte sur la face avant (-Z locale de cf)
function W.sign(parent, name, size, cf, text, bg, fg)
	local p = W.part(parent, name, size, cf, bg or Color3.fromRGB(95, 65, 40), M.Wood)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = fg or Color3.fromRGB(255, 240, 200)
	t.Parent = sg
	return p, t
end

function W.prompt(parent, actionText, objectText, distance)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText or ""
	pp.HoldDuration = 0
	pp.MaxActivationDistance = distance or 12
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = parent
	return pp
end

local function tree(parent, pos, scale, leaf)
	scale = scale or 1
	local trunk = W.decor(W.part(parent, "Tronc", Vector3.new(1.6 * scale, 6 * scale, 1.6 * scale), CFrame.new(pos + Vector3.new(0, 3 * scale, 0)), Color3.fromRGB(110, 75, 45), M.Wood))
	trunk.CanCollide = false
	local f1 = W.decor(W.ball(parent, "Feuilles", 7 * scale, pos + Vector3.new(0, 8 * scale, 0), leaf or Color3.fromRGB(60, 150, 60), M.Grass))
	local f2 = W.decor(W.ball(parent, "Feuilles2", 5 * scale, pos + Vector3.new(1.5 * scale, 10.5 * scale, 0.5 * scale), leaf or Color3.fromRGB(70, 165, 70), M.Grass))
	f1.CanCollide = false
	f2.CanCollide = false
end
W.tree = tree

local function rock(parent, pos, scale, color)
	local r = W.decor(W.part(parent, "Rocher", Vector3.new(3 * scale, 2 * scale, 2.6 * scale), CFrame.new(pos + Vector3.new(0, scale, 0)) * CFrame.Angles(0, math.rad(pos.X * 13 % 180), 0), color or Color3.fromRGB(125, 125, 130), M.Slate))
	return r
end
W.rock = rock

----------------------------------------------------------------------
-- Lumière / ambiance
----------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 160)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.25
		a.Color = Color3.fromRGB(200, 215, 235)
		a.Haze = 0.6
		a.Parent = Lighting
	end
	Lighting.ShadowSoftness = 0.25
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 220)
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Contrast = 0.08
		cc.Saturation = 0.18
		cc.TintColor = Color3.fromRGB(255, 250, 240)
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local sr = Instance.new("SunRaysEffect")
		sr.Intensity = 0.06
		sr.Spread = 0.6
		sr.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.25
		b.Size = 20
		b.Threshold = 1.5
		b.Parent = Lighting
	end
end

----------------------------------------------------------------------
-- Parcelle : géométrie locale
----------------------------------------------------------------------
local PEN_THEMES = {
	{ name = "Prairie", floor = Color3.fromRGB(110, 175, 75), mat = M.Grass, fence = M.Wood, fenceColor = Color3.fromRGB(150, 105, 60) },
	{ name = "Forêt", floor = Color3.fromRGB(60, 130, 55), mat = M.Grass, fence = M.Wood, fenceColor = Color3.fromRGB(110, 75, 45) },
	{ name = "Volcan", floor = Color3.fromRGB(80, 55, 55), mat = M.Slate, fence = M.Slate, fenceColor = Color3.fromRGB(50, 40, 40) },
	{ name = "Lagon", floor = Color3.fromRGB(235, 215, 160), mat = M.Sand, fence = M.Wood, fenceColor = Color3.fromRGB(200, 170, 120) },
	{ name = "Glacier", floor = Color3.fromRGB(225, 240, 250), mat = M.Snow, fence = M.Ice, fenceColor = Color3.fromRGB(170, 215, 245) },
	{ name = "Royal", floor = Color3.fromRGB(235, 195, 80), mat = M.Marble, fence = M.Metal, fenceColor = Color3.fromRGB(255, 215, 90) },
}

-- Convertit une position locale de parcelle en CFrame monde
local function L(plot, x, y, z)
	return plot.cf * CFrame.new(x, y, z)
end
function W.toWorld(plot, v)
	return plot.cf:PointToWorldSpace(v)
end

function W.buildPen(plot, index)
	local def = Config.Pens[index]
	local theme = PEN_THEMES[index]
	local folder = Instance.new("Folder")
	folder.Name = "Pen" .. index
	folder.Parent = plot.dyn
	local c = def.center
	local sx, sz = Config.PenSize.X, Config.PenSize.Z
	local floor = W.decor(W.part(folder, "Sol", Vector3.new(sx, 0.3, sz), L(plot, c.X, 0.3, c.Z), theme.floor, theme.mat))
	floor.CanCollide = true
	-- clôture
	local h = 2.6
	local function fence(name, size, x, z)
		local f = W.part(folder, name, size, L(plot, c.X + x, h / 2 + 0.3, c.Z + z), theme.fenceColor, theme.fence)
		f.CanQuery = false
		return f
	end
	fence("ClotureN", Vector3.new(sx, h, 0.8), 0, -sz / 2)
	fence("ClotureS", Vector3.new(sx, h, 0.8), 0, sz / 2)
	fence("ClotureO", Vector3.new(0.8, h, sz), -sx / 2, 0)
	fence("ClotureE", Vector3.new(0.8, h, sz), sx / 2, 0)
	-- panneau (face au chemin central)
	local side = c.X < 0 and 1 or -1
	local signCF = L(plot, c.X + side * (sx / 2 + 0.6), 5, c.Z - sz / 2 + 3) * CFrame.Angles(0, math.rad(side == 1 and -90 or 90), 0)
	W.sign(folder, "Panneau", Vector3.new(7, 2.4, 0.4), signCF, theme.name, Color3.fromRGB(80, 55, 35))
	-- décor selon le thème
	local function at(dx, dz)
		return W.toWorld(plot, Vector3.new(c.X + dx, 0.3, c.Z + dz))
	end
	if index == 1 or index == 2 then
		tree(folder, at(-15, -10), 0.8)
		tree(folder, at(15, 10), 0.9)
		rock(folder, at(0, 0), 0.8)
	elseif index == 3 then
		for _, o in ipairs({ { -14, -9 }, { 13, 9 }, { 0, 0 } }) do
			local lava = W.decor(W.part(folder, "Lave", Vector3.new(5, 0.2, 5), CFrame.new(at(o[1], o[2]) + Vector3.new(0, 0.15, 0)), Color3.fromRGB(255, 110, 20), M.Neon))
			lava.CanCollide = false
		end
		rock(folder, at(-6, 8), 1.2, Color3.fromRGB(60, 50, 50))
		rock(folder, at(8, -8), 1.4, Color3.fromRGB(60, 50, 50))
	elseif index == 4 then
		local w = W.decor(W.part(folder, "Lac", Vector3.new(12, 0.2, 9), CFrame.new(at(0, 0) + Vector3.new(0, 0.2, 0)), Color3.fromRGB(70, 160, 230), M.Glass))
		w.Transparency = 0.35
		w.CanCollide = false
		tree(folder, at(-15, 10), 0.8, Color3.fromRGB(90, 170, 90))
		rock(folder, at(14, -9), 0.9)
	elseif index == 5 then
		for _, o in ipairs({ { -14, -9 }, { 14, 9 }, { 0, 10 } }) do
			local spike = W.decor(W.part(folder, "Glacon", Vector3.new(2, 5, 2), CFrame.new(at(o[1], o[2]) + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0.5, 0.1), Color3.fromRGB(190, 230, 255), M.Ice))
			spike.Transparency = 0.2
		end
	else
		for _, o in ipairs({ { -15, -10 }, { 15, -10 }, { -15, 10 }, { 15, 10 } }) do
			W.decor(W.cylinder(folder, "Colonne", 8, 2, at(o[1], o[2]) + Vector3.new(0, 4, 0), Color3.fromRGB(250, 245, 235), M.Marble))
		end
	end
	return folder
end

function W.buildShop(plot, def)
	local folder = Instance.new("Folder")
	folder.Name = def.id
	folder.Parent = plot.dyn
	local c = def.center
	local col = def.color
	if def.id == "ride" then
		-- grande roue : roue dans le plan YZ, axe le long de X
		local r = 11
		local hubY = 15
		W.decor(W.part(folder, "Pied1", Vector3.new(2, 15, 2), L(plot, c.X - 4, 7, c.Z) * CFrame.Angles(0, 0, math.rad(15)), Color3.fromRGB(230, 230, 235), M.Metal))
		W.decor(W.part(folder, "Pied2", Vector3.new(2, 15, 2), L(plot, c.X + 4, 7, c.Z) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(230, 230, 235), M.Metal))
		W.decor(W.part(folder, "Axe", Vector3.new(10, 2.5, 2.5), L(plot, c.X, hubY, c.Z), Color3.fromRGB(255, 220, 90), M.Metal, Enum.PartType.Cylinder))
		local n = 10
		local hub = W.toWorld(plot, Vector3.new(c.X, hubY, c.Z))
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local py, pz = math.sin(a) * r, math.cos(a) * r
			local rim = W.toWorld(plot, Vector3.new(c.X, hubY + py, c.Z + pz))
			local mid = (hub + rim) / 2
			local spoke = W.decor(W.part(folder, "Rayon" .. i, Vector3.new(0.4, 0.4, r), CFrame.lookAt(mid, rim), Color3.fromRGB(240, 240, 245), M.Metal))
			spoke.CanCollide = false
			local gondola = W.decor(W.part(folder, "Nacelle" .. i, Vector3.new(2.4, 2.4, 2.4), CFrame.new(rim), Color3.fromHSV(i / n, 0.6, 1), M.SmoothPlastic))
			gondola.CanCollide = false
		end
		W.sign(folder, "Enseigne", Vector3.new(9, 2.4, 0.4), L(plot, c.X, 3, c.Z - 7), "GRANDE ROUE", Color3.fromRGB(200, 60, 80))
		return folder
	end
	-- bâtiment standard : base, toit, enseigne
	local w, d, h = 14, 10, 6
	if def.id == "hotel" then
		w, d, h = 16, 12, 11
	end
	W.part(folder, "Murs", Vector3.new(w, h, d), L(plot, c.X, h / 2, c.Z), col, M.Brick)
	W.part(folder, "Toit", Vector3.new(w + 2, 1, d + 2), L(plot, c.X, h + 0.5, c.Z), Color3.fromRGB(150, 60, 50), M.Slate)
	local door = W.decor(W.part(folder, "Porte", Vector3.new(3, 4, 0.4), L(plot, c.X, 2, c.Z - d / 2 - 0.1), Color3.fromRGB(80, 55, 40), M.Wood))
	W.decor(W.part(folder, "Vitre", Vector3.new(4, 2.4, 0.3), L(plot, c.X + w / 3, 3, c.Z - d / 2 - 0.1), Color3.fromRGB(170, 220, 255), M.Glass))
	door.CanCollide = false
	W.sign(folder, "Enseigne", Vector3.new(w - 2, 2.2, 0.4), L(plot, c.X, h + 2.4, c.Z - d / 2 - 0.4), string.upper(def.name), Color3.fromRGB(60, 40, 30))
	if def.id == "cafe" then
		W.cylinder(folder, "Table", 0.4, 3, W.toWorld(plot, Vector3.new(c.X - 5, 2.4, c.Z - d / 2 - 3)), Color3.fromRGB(240, 240, 240), M.SmoothPlastic)
		W.cylinder(folder, "Pied", 2.2, 0.6, W.toWorld(plot, Vector3.new(c.X - 5, 1.2, c.Z - d / 2 - 3)), Color3.fromRGB(60, 60, 60), M.Metal)
	end
	return folder
end

function W.buildStand(plot, slot)
	local folder = Instance.new("Folder")
	folder.Name = "Stand" .. slot
	folder.Parent = plot.dyn
	local c = Config.Stands[slot]
	W.cylinder(folder, "Socle", 2.2, 5, W.toWorld(plot, Vector3.new(c.X, 1.1, c.Z)), Color3.fromRGB(190, 190, 200), M.Concrete)
	W.cylinder(folder, "Plaque", 0.3, 4, W.toWorld(plot, Vector3.new(c.X, 2.35, c.Z)), Color3.fromRGB(70, 200, 255), M.Neon)
	local egg = W.decor(W.ellipsoid(folder, "Oeuf", Vector3.new(2.6, 3.4, 2.6), CFrame.new(W.toWorld(plot, Vector3.new(c.X, 4.2, c.Z))), Color3.fromRGB(235, 225, 195), M.SmoothPlastic))
	egg.CanCollide = false
	egg.Transparency = 1
	local pp = W.prompt(folder.Socle, "Placer un œuf", "Incubateur " .. slot, 11)
	return folder, egg, pp, folder.Socle
end

function W.buildDigger(plot, index)
	local folder = Instance.new("Folder")
	folder.Name = "Ouvrier" .. index
	folder.Parent = plot.dyn
	local offs = { Vector3.new(-9, 0, -8), Vector3.new(9, 0, -8), Vector3.new(-9, 0, 9), Vector3.new(9, 0, 9) }
	local o = Config.DigCenter + offs[index]
	local human = HumanFactory.build({ name = "Ouvrier", hat = Color3.fromRGB(255, 200, 30), shirt = Color3.fromRGB(240, 120, 30), skin = Color3.fromRGB(255, 204, 153) })
	local face = Config.DigCenter
	local cf = CFrame.lookAt(W.toWorld(plot, o), W.toWorld(plot, Vector3.new(face.X, 0, face.Z)))
	HumanFactory.pose(human, cf, 0, 0.4)
	human:SetAttribute("Worker", true)
	human:SetAttribute("BaseCF", cf)
	human.Parent = folder
	-- pioche posée
	local pick = W.decor(W.part(folder, "Caisse", Vector3.new(3, 2, 3), cf * CFrame.new(3, 1, 0), Color3.fromRGB(140, 100, 60), M.Wood))
	pick.CanCollide = true
	return folder
end

function W.buildHelipad(plot)
	local folder = Instance.new("Folder")
	folder.Name = "Helipad"
	folder.Parent = plot.dyn
	local c = Config.HelipadCenter
	W.cylinder(folder, "Piste", 0.5, 14, W.toWorld(plot, Vector3.new(c.X, 0.4, c.Z + 4)), Color3.fromRGB(60, 62, 70), M.Concrete)
	local hv = Vector3.new(0.8, 0.1, 5)
	W.decor(W.part(folder, "H1", hv, L(plot, c.X - 1.8, 0.7, c.Z + 4), Color3.fromRGB(255, 255, 255), M.Neon))
	W.decor(W.part(folder, "H2", hv, L(plot, c.X + 1.8, 0.7, c.Z + 4), Color3.fromRGB(255, 255, 255), M.Neon))
	W.decor(W.part(folder, "H3", Vector3.new(3.6, 0.1, 0.8), L(plot, c.X, 0.7, c.Z + 4), Color3.fromRGB(255, 255, 255), M.Neon))
	-- hélicoptère
	local hc = L(plot, c.X, 3, c.Z + 4)
	W.part(folder, "CorpsHeli", Vector3.new(4, 3, 7), hc, Color3.fromRGB(220, 50, 50), M.SmoothPlastic)
	W.part(folder, "Cockpit", Vector3.new(3.4, 2, 2.4), hc * CFrame.new(0, 0.3, -3.2), Color3.fromRGB(150, 210, 255), M.Glass)
	W.part(folder, "Queue", Vector3.new(0.8, 0.8, 5), hc * CFrame.new(0, 0.5, 5.5), Color3.fromRGB(220, 50, 50), M.SmoothPlastic)
	W.part(folder, "Rotor", Vector3.new(14, 0.2, 0.8), hc * CFrame.new(0, 2.2, 0), Color3.fromRGB(40, 40, 45), M.Metal)
	W.part(folder, "Rotor2", Vector3.new(0.8, 0.2, 14), hc * CFrame.new(0, 2.2, 0), Color3.fromRGB(40, 40, 45), M.Metal)
	return folder
end

-- Bouton d'achat au sol. Retourne la Part (avec BillboardGui).
function W.buildPad(plot, def)
	local colors = { pen = Color3.fromRGB(80, 200, 100), incubator = Color3.fromRGB(80, 190, 255), digger = Color3.fromRGB(255, 170, 60), shop = Color3.fromRGB(255, 110, 150), helipad = Color3.fromRGB(200, 120, 255) }
	local p = W.cylinder(plot.padFolder, "Pad_" .. def.id, 0.6, 6, W.toWorld(plot, Vector3.new(def.pad.X, 0.55, def.pad.Z)), colors[def.kind] or Color3.fromRGB(255, 255, 255), M.Neon)
	p.CanCollide = false
	p.CanQuery = false
	p:SetAttribute("BuildableId", def.id)
	local txt = W.label(p, def.name, UDim2.fromOffset(220, 70), 4.5, Color3.new(1, 1, 1), 70)
	txt.Text = def.name
	local cost = Instance.new("TextLabel")
	cost.Name = "Cost"
	cost.BackgroundTransparency = 1
	cost.Size = UDim2.fromScale(1, 0.5)
	cost.Position = UDim2.fromScale(0, 0.55)
	cost.Font = FONT
	cost.TextScaled = true
	cost.TextColor3 = Color3.fromRGB(255, 230, 90)
	cost.TextStrokeTransparency = 0
	cost.Parent = p.Label
	txt.Size = UDim2.fromScale(1, 0.55)
	return p
end

----------------------------------------------------------------------
-- Parcelle statique
----------------------------------------------------------------------
local function buildPlotStatic(index, cf)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local plot = { index = index, cf = cf, model = model, refs = {}, owner = nil }

	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = model
	plot.dyn = dyn
	plot.padFolder = Instance.new("Folder")
	plot.padFolder.Name = "Pads"
	plot.padFolder.Parent = model
	local static = Instance.new("Folder")
	static.Name = "Static"
	static.Parent = model

	local pw, pd = Config.PlotWidth, Config.PlotDepth
	local ground = W.decor(W.part(static, "Terrain", Vector3.new(pw, 0.4, pd), L(plot, 0, 0.05, 0), Color3.fromRGB(105, 170, 80), M.Grass))
	ground.CanCollide = true
	-- chemin central
	W.decor(W.part(static, "Chemin", Vector3.new(10, 0.1, 112), L(plot, 0, 0.27, -26), Color3.fromRGB(190, 175, 150), M.Cobblestone))
	W.decor(W.part(static, "Place", Vector3.new(pw - 8, 0.1, 22), L(plot, 0, 0.27, 28), Color3.fromRGB(200, 185, 160), M.Cobblestone))
	W.decor(W.part(static, "ChemRoute", Vector3.new(14, 0.1, 30), L(plot, 0, 0.27, -92), Color3.fromRGB(170, 170, 175), M.Concrete))

	-- clôture périmétrique
	local fenceColor = Color3.fromRGB(120, 85, 50)
	local function fence(name, size, x, z)
		local f = W.part(static, name, size, L(plot, x, 2, z), fenceColor, M.Wood)
		f.CanQuery = false
		return f
	end
	fence("ClotureG", Vector3.new(1, 4, pd), -pw / 2, 0)
	fence("ClotureD", Vector3.new(1, 4, pd), pw / 2, 0)
	fence("ClotureFond", Vector3.new(pw, 4, 1), 0, pd / 2)
	local fw = (pw - 14) / 2
	fence("ClotureAvG", Vector3.new(fw, 4, 1), -(7 + fw / 2), -pd / 2)
	fence("ClotureAvD", Vector3.new(fw, 4, 1), (7 + fw / 2), -pd / 2)

	-- portail
	W.part(static, "PilierG", Vector3.new(3, 12, 3), L(plot, -8, 6, -pd / 2), Color3.fromRGB(200, 190, 170), M.Brick)
	W.part(static, "PilierD", Vector3.new(3, 12, 3), L(plot, 8, 6, -pd / 2), Color3.fromRGB(200, 190, 170), M.Brick)
	local _, gateText = W.sign(static, "EnseignePortail", Vector3.new(19, 4, 1.2), L(plot, 0, 11, -pd / 2), "PARC LIBRE", Color3.fromRGB(70, 110, 60), Color3.fromRGB(255, 245, 200))
	plot.refs.gateText = gateText

	-- point d'apparition
	plot.refs.spawnCF = L(plot, 0, 4, -66) * CFrame.Angles(0, math.rad(180), 0)

	-- enclos 1 (gratuit)
	-- (construit dynamiquement à la prise de parcelle pour partager le code)

	-- zone de fouille
	local dc = Config.DigCenter
	local dirt = W.decor(W.part(static, "ZoneFouille", Vector3.new(44, 0.3, 36), L(plot, dc.X, 0.35, dc.Z), Color3.fromRGB(135, 95, 60), M.Ground))
	dirt.CanCollide = true
	local mounds = {}
	local moundSpots = { { -12, -8 }, { 0, -11 }, { 12, -8 }, { -13, 7 }, { 0, 10 }, { 13, 7 } }
	for i, o in ipairs(moundSpots) do
		local m = W.ellipsoid(static, "Monticule" .. i, Vector3.new(7, 4.2, 7), L(plot, dc.X + o[1], 0.9, dc.Z + o[2]), Color3.fromRGB(150, 105, 65), M.Ground)
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 28
		cd.Parent = m
		local pp = W.prompt(m, "Creuser", "Fossiles", 14)
		table.insert(mounds, { part = m, click = cd, prompt = pp })
	end
	plot.refs.mounds = mounds
	W.sign(static, "PanneauFouille", Vector3.new(12, 3, 0.5), L(plot, dc.X, 3.5, dc.Z - 20), "ZONE DE FOUILLE", Color3.fromRGB(110, 70, 40))
	local digMarker = W.decor(W.part(static, "RepereFouille", Vector3.new(1, 1, 1), L(plot, dc.X, 3, dc.Z), Color3.new(1, 1, 1), M.SmoothPlastic))
	digMarker.Transparency = 1
	digMarker.CanCollide = false
	plot.refs.digCenter = digMarker

	-- laboratoire
	local lc = Config.LabCenter
	W.part(static, "LabSol", Vector3.new(34, 0.3, 26), L(plot, lc.X, 0.35, lc.Z), Color3.fromRGB(225, 230, 235), M.Concrete)
	W.part(static, "LabFond", Vector3.new(34, 9, 1), L(plot, lc.X, 4.5, lc.Z + 13), Color3.fromRGB(235, 240, 245), M.Concrete)
	W.part(static, "LabG", Vector3.new(1, 9, 26), L(plot, lc.X - 17, 4.5, lc.Z), Color3.fromRGB(235, 240, 245), M.Concrete)
	W.part(static, "LabD", Vector3.new(1, 9, 26), L(plot, lc.X + 17, 4.5, lc.Z), Color3.fromRGB(235, 240, 245), M.Concrete)
	local roof = W.part(static, "LabToit", Vector3.new(36, 1, 28), L(plot, lc.X, 9.5, lc.Z), Color3.fromRGB(60, 130, 200), M.Metal)
	roof.Transparency = 0.3
	-- le toit est décoratif : pas de collision pour ne pas gêner la caméra/le saut
	roof.CanCollide = false
	W.sign(static, "EnseigneLab", Vector3.new(16, 3, 0.5), L(plot, lc.X, 12.3, lc.Z - 13), "LABORATOIRE", Color3.fromRGB(40, 90, 150))
	W.part(static, "Ecran", Vector3.new(10, 5, 0.4), L(plot, lc.X, 5, lc.Z + 12.3), Color3.fromRGB(20, 40, 60), M.Neon)

	-- kiosque (collecte des pièces)
	local bc = Config.BoothCenter
	W.part(static, "KiosqueBase", Vector3.new(12, 5, 7), L(plot, bc.X, 2.5, bc.Z + 2), Color3.fromRGB(240, 200, 90), M.Brick)
	W.part(static, "KiosqueToit", Vector3.new(14, 1, 9), L(plot, bc.X, 8, bc.Z + 2), Color3.fromRGB(210, 60, 60), M.Slate)
	W.part(static, "KiosquePilG", Vector3.new(1, 3, 1), L(plot, bc.X - 6, 6.5, bc.Z - 2), Color3.fromRGB(110, 75, 45), M.Wood)
	W.part(static, "KiosquePilD", Vector3.new(1, 3, 1), L(plot, bc.X + 6, 6.5, bc.Z - 2), Color3.fromRGB(110, 75, 45), M.Wood)
	W.sign(static, "EnseigneKiosque", Vector3.new(11, 2, 0.4), L(plot, bc.X, 6.5, bc.Z - 2.6), "BILLETTERIE", Color3.fromRGB(150, 40, 40))
	local bp = Config.BoothPad
	local boothPad = W.cylinder(static, "PadCollecte", 0.6, 8, W.toWorld(plot, Vector3.new(bp.X, 0.6, bp.Z)), Color3.fromRGB(60, 230, 110), M.Neon)
	boothPad.CanCollide = false
	local lbl = W.label(boothPad, "💰 0", UDim2.fromOffset(240, 70), 5, Color3.fromRGB(255, 240, 120), 80)
	plot.refs.boothPad = boothPad
	plot.refs.boothLabel = lbl

	-- 4 emplacements d'incubateur : le 1 est gratuit
	plot.refs.stands = {}

	-- quelques arbres décoratifs fixes
	for _, o in ipairs({ { -52, 22 }, { 52, 40 }, { -52, 78 }, { 52, 78 }, { 14, 76 }, { -52, -70 }, { 52, -70 } }) do
		tree(static, W.toWorld(plot, Vector3.new(o[1], 0.2, o[2])), 0.9 + (math.abs(o[1] + o[2]) % 3) * 0.1)
	end

	model.Parent = Workspace:FindFirstChild("Plots")
	return plot
end

----------------------------------------------------------------------
-- Lobby
----------------------------------------------------------------------
local function buildLobby(root)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = root
	local stone = Color3.fromRGB(200, 190, 165)

	W.cylinder(folder, "Place", 0.6, 230, Vector3.new(0, 0.3, 0), stone, M.Cobblestone)
	W.cylinder(folder, "Anneau", 0.7, 90, Vector3.new(0, 0.35, 0), Color3.fromRGB(150, 140, 120), M.Slate)
	-- point d'apparition par défaut (lobby)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLobby"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1, 60)
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	-- statue centrale : T-Rex doré géant sur un piédestal
	W.cylinder(folder, "Piedestal", 4, 30, Vector3.new(0, 2.6, 0), Color3.fromRGB(150, 145, 140), M.Concrete)
	W.cylinder(folder, "PiedestalHaut", 2, 24, Vector3.new(0, 5.6, 0), Color3.fromRGB(190, 185, 175), M.Marble)
	local statue = DinoFactory.build("rex:g", { scaleMul = 2.6 })
	if statue then
		statue:PivotTo(CFrame.new(0, 6.6, 0) * CFrame.Angles(0, math.rad(180), 0))
		statue.Name = "StatueRex"
		for _, p in ipairs(statue:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanQuery = false
			end
		end
		statue.Parent = folder
	end
	W.sign(folder, "Titre", Vector3.new(34, 7, 1), CFrame.new(0, 21, 70) * CFrame.Angles(0, math.rad(180), 0), "🦖 DINO DIG PARK", Color3.fromRGB(40, 90, 50), Color3.fromRGB(255, 240, 160))
	W.part(folder, "TitrePoteauG", Vector3.new(2, 18, 2), CFrame.new(-16, 9, 70.2), Color3.fromRGB(110, 75, 45), M.Wood)
	W.part(folder, "TitrePoteauD", Vector3.new(2, 18, 2), CFrame.new(16, 9, 70.2), Color3.fromRGB(110, 75, 45), M.Wood)

	-- panneau d'aide
	W.sign(folder, "Aide", Vector3.new(22, 9, 0.8), CFrame.new(-46, 6, 34) * CFrame.Angles(0, math.rad(150), 0),
		"1. Creuse des fossiles ⛏\n2. Fais éclore des œufs 🥚\n3. Les dinos rapportent des 💰\n4. Agrandis ton parc !", Color3.fromRGB(70, 50, 35))

	-- tableau des scores
	local board = W.part(folder, "TableauScores", Vector3.new(26, 18, 1), CFrame.new(60, 11, -10) * CFrame.Angles(0, math.rad(-75), 0), Color3.fromRGB(30, 35, 45), M.SmoothPlastic)
	W.part(folder, "PoteauScore1", Vector3.new(2, 11, 2), CFrame.new(60, 5.5, -10) * CFrame.new(-9, 0, 0), Color3.fromRGB(80, 80, 90), M.Metal)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.Font = FONT
	title.TextScaled = true
	title.Text = "🏆 MEILLEURS PARCS"
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.Parent = sg
	local lines = {}
	for i = 1, 10 do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.92, 0, 0.075, 0)
		t.Position = UDim2.new(0.04, 0, 0.13 + (i - 1) * 0.086, 0)
		t.Font = FONT
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = i .. ". —"
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = sg
		lines[i] = t
	end
	W.leaderboardLines = lines

	-- arbres, lampadaires, bancs autour de la place
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		local r = 100
		local pos = Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
		-- laisse libres les routes vers les parcelles
		local skip = false
		for k = 0, Config.PlotCount - 1 do
			local pa = (k / Config.PlotCount) * math.pi * 2
			local diff = math.abs(math.atan2(math.sin(a - pa), math.cos(a - pa)))
			if diff < 0.16 then
				skip = true
			end
		end
		if not skip then
			tree(folder, pos, 1.1)
		end
	end
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.3
		local pos = Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)
		W.decor(W.part(folder, "LampadairePied", Vector3.new(0.8, 12, 0.8), CFrame.new(pos + Vector3.new(0, 6, 0)), Color3.fromRGB(50, 50, 55), M.Metal))
		local lamp = W.decor(W.ball(folder, "LampadaireLampe", 2.4, pos + Vector3.new(0, 12.5, 0), Color3.fromRGB(255, 235, 170), M.Neon))
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 225, 160)
		light.Parent = lamp
	end
	return folder
end

local function buildGoldBones(root)
	local spots = {
		Vector3.new(13, 8.2, 12), -- derrière la statue
		Vector3.new(-92, 2, -48),
		Vector3.new(36, 1.8, 92),
	}
	for j = 1, 2 do
		local a = math.rad(20 + (j - 1) * 130)
		table.insert(spots, Vector3.new(math.cos(a) * 430, 2, math.sin(a) * 430))
	end
	local folder = Instance.new("Folder")
	folder.Name = "OsDores"
	folder.Parent = root
	W.bones = {}
	for j = 1, Config.GoldBoneCount do
		local pos = spots[j]
		local bone = Instance.new("Model")
		bone.Name = "OsDore" .. j
		local gold = Color3.fromRGB(255, 210, 60)
		local shaft = W.part(bone, "Os", Vector3.new(0.7, 0.7, 3), CFrame.new(pos) * CFrame.Angles(0, math.rad(j * 40), math.rad(20)), gold, M.Metal)
		shaft.CanCollide = false
		for _, dz in ipairs({ -1.5, 1.5 }) do
			for _, dx in ipairs({ -0.35, 0.35 }) do
				local k = W.part(bone, "Bout", Vector3.new(0.8, 0.8, 0.8), shaft.CFrame * CFrame.new(dx, 0, dz), gold, M.Metal, Enum.PartType.Ball)
				k.CanCollide = false
			end
		end
		local att = Instance.new("Attachment")
		att.Parent = shaft
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 3
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.Size = NumberSequence.new(0.7, 0)
		pe.LightEmission = 1
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
		pe.Parent = att
		local pp = W.prompt(shaft, "Ramasser", "Os doré ?", 8)
		pp:SetAttribute("BoneId", j)
		bone.Parent = folder
		W.bones[j] = pp
	end
end

----------------------------------------------------------------------
-- Construction globale
----------------------------------------------------------------------
function W.build()
	setupLighting()

	local root = Workspace:FindFirstChild("DinoWorld")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "DinoWorld"
	root.Parent = Workspace

	-- Sol global
	local base = Workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local ground = W.part(root, "Sol", Vector3.new(1200, 2, 1200), CFrame.new(0, -1, 0), Color3.fromRGB(95, 160, 75), M.Grass)
	ground.CanCollide = true

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	buildLobby(root)
	buildGoldBones(root)

	local plots = {}
	local n = Config.PlotCount
	local rc = 280
	for i = 1, n do
		local a = ((i - 1) / n) * math.pi * 2
		local center = Vector3.new(math.cos(a) * rc, 0, math.sin(a) * rc)
		local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0))
		-- on ne garde que la rotation autour de Y
		local _, yaw, _ = cf:ToEulerAnglesYXZ()
		cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
		plots[i] = buildPlotStatic(i, cf)

		-- route vers le lobby
		local from = Vector3.new(math.cos(a) * 110, 0.3, math.sin(a) * 110)
		local to = Vector3.new(math.cos(a) * 200, 0.3, math.sin(a) * 200)
		local mid = (from + to) / 2
		local road = W.decor(W.part(root, "Route" .. i, Vector3.new(14, 0.2, (to - from).Magnitude), CFrame.lookAt(mid, to), Color3.fromRGB(170, 170, 175), M.Concrete))
		road.CanCollide = true
	end
	return plots
end

return W

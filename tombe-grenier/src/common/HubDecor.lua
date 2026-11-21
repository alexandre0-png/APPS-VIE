--[[
  HubDecor : décor du hub, thème grenier et maison hantée. Construit à partir de Shared.HubLayout.
  - Tout est décoratif : aucune collision, aucune requête, aucun clic (aucune invite, aucun détecteur de clic),
    aucune plaque cachée. La zone d'arrivée autour de l'apparition reste dégagée (HubLayout.CLEAR_RADIUS).
  - Modèles Roblox (Config.Assets) : chargés après la construction, côté serveur, avec InsertService
    (pcall et délai maximum) et AssetLoad. Un modèle valide remplace l'élément procédural ; sinon l'élément
    procédural reste. Config.Assets.Enabled = false coupe le chargement.
  - Limites : pièces (HubLayout.MAX_PARTS) et lumières (RoomBudget.qualityLimits) respectées par HubLayout.plan.
  - Config.Hub.Decor = false coupe tout le décor.
]]
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetLoad = require(Shared.AssetLoad)
local HubLayout = require(Shared.HubLayout)
local RoomBudget = require(Shared.RoomBudget)
local Audio = require(Shared.Audio)

local HubDecor = {}

local WOOD = Color3.fromRGB(92, 62, 40)
local DARK_WOOD = Color3.fromRGB(45, 30, 20)
local WARM = Color3.fromRGB(255, 190, 120)

-- Face visible d'un panneau selon son orientation
local FACE = {
	["-z"] = Enum.NormalId.Front,
	["+z"] = Enum.NormalId.Back,
	["+x"] = Enum.NormalId.Right,
	["-x"] = Enum.NormalId.Left,
}

-- Rotation autour de y pour faire regarder un modèle (face avant = -Z) vers la direction voulue
local YAW = { ["-z"] = 0, ["+z"] = math.pi, ["+x"] = -math.pi / 2, ["-x"] = math.pi / 2 }

-- Pièce décorative : ancrée, sans collision, sans requête, sans contact
local function part(parent, name, size, pos, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(size[1], size[2], size[3])
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Wood
	if extra and extra.transparency then
		p.Transparency = extra.transparency
	end
	p.Parent = parent
	return p
end

local function addLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Texte sur une face d'un panneau
local function writeOn(board, face, text, pixels)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(232, 220, 190)
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
end

local flames = {} -- lumières de bougie (vacillement)

-- Un constructeur par type. c = centre du hub, it = élément, size = taille dans les axes du monde, g = groupe
local BUILD = {}

function BUILD.etagere(g, it, size, c, y0)
	local sx, sy, sz = size[1], size[2], size[3]
	local x, z = c.X + it.x, c.Z + it.z
	for _, side in ipairs({ -1, 1 }) do
		part(g, "montant", { sx, sy, 0.3 }, Vector3.new(x, y0 + sy / 2, z + side * (sz / 2 - 0.15)), DARK_WOOD)
	end
	local levels = { 1, 3.5, 6 }
	for _, h in ipairs(levels) do
		part(g, "planche", { sx, 0.25, sz }, Vector3.new(x, y0 + h, z), WOOD)
	end
	local colors = {
		Color3.fromRGB(90, 40, 35),
		Color3.fromRGB(40, 60, 45),
		Color3.fromRGB(60, 50, 35),
		Color3.fromRGB(70, 45, 70),
	}
	for i, col in ipairs(colors) do
		local h = levels[(i - 1) % 3 + 1]
		part(g, "livre", { 0.6, 0.9, 0.5 }, Vector3.new(x, y0 + h + 0.58, z - 2 + i * 0.9), col, Enum.Material.Fabric)
	end
end

function BUILD.malle(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	part(g, "malle", { size[1], 1.6, size[3] }, Vector3.new(x, y0 + 0.8, z), WOOD)
	part(g, "couvercle", { size[1], 0.9, size[3] }, Vector3.new(x, y0 + 2.05, z), DARK_WOOD)
	part(
		g,
		"sangle",
		{ 0.3, size[2], size[3] + 0.1 },
		Vector3.new(x, y0 + size[2] / 2, z),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal
	)
end

function BUILD.cadre(g, it, size, c, y0)
	local pos = Vector3.new(c.X + it.x, y0 + it.y, c.Z + it.z)
	part(g, "cadre", size, pos, DARK_WOOD)
	-- La toile dépasse un peu de chaque côté du cadre : elle se voit de la face visible
	part(
		g,
		"toile peinte",
		{ size[1] + 0.02, size[2] - 0.4, size[3] - 0.4 },
		pos,
		Color3.fromRGB(70, 66, 58),
		Enum.Material.Fabric
	)
end

function BUILD.tapis(g, it, size, c, y0)
	local pos = Vector3.new(c.X + it.x, y0, c.Z + it.z)
	part(
		g,
		"bordure",
		{ size[1] + 0.8, 0.04, size[3] + 0.8 },
		pos + Vector3.new(0, 0.02, 0),
		Color3.fromRGB(120, 95, 50),
		Enum.Material.Fabric
	)
	part(g, "tapis", size, pos + Vector3.new(0, 0.05, 0), Color3.fromRGB(95, 35, 35), Enum.Material.Fabric)
end

function BUILD.toile(g, it, size, c, y0)
	part(
		g,
		"toile d'araignée",
		size,
		Vector3.new(c.X + it.x, y0 + it.y, c.Z + it.z),
		Color3.fromRGB(225, 225, 225),
		Enum.Material.Fabric,
		{ transparency = 0.7 }
	)
end

function BUILD.plante_morte(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	part(g, "pot", { 1.4, 1.2, 1.4 }, Vector3.new(x, y0 + 0.6, z), Color3.fromRGB(110, 70, 50), Enum.Material.Slate)
	for i, tilt in ipairs({ -0.3, 0.05, 0.35 }) do
		local branch = part(
			g,
			"branche sèche",
			{ 0.12, 2.0, 0.12 },
			Vector3.new(x + tilt * 1.5, y0 + 2.0, z + (i - 2) * 0.2),
			Color3.fromRGB(70, 55, 40),
			Enum.Material.Wood
		)
		branch.CFrame = CFrame.new(branch.Position) * CFrame.Angles(0, 0, tilt)
	end
end

function BUILD.bougie(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	local base = y0 + (it.y or 0)
	part(
		g,
		"bougeoir",
		{ 0.6, 0.08, 0.6 },
		Vector3.new(x, base + 0.04, z),
		Color3.fromRGB(80, 70, 40),
		Enum.Material.Metal
	)
	part(
		g,
		"bougie",
		{ 0.3, 0.6, 0.3 },
		Vector3.new(x, base + 0.38, z),
		Color3.fromRGB(225, 210, 170),
		Enum.Material.SmoothPlastic
	)
	local flame = part(
		g,
		"flamme",
		{ 0.14, 0.22, 0.14 },
		Vector3.new(x, base + 0.79, z),
		Color3.fromRGB(255, 170, 80),
		Enum.Material.Neon
	)
	if it.light and not it.noLight then
		table.insert(flames, addLight(flame, WARM, 12, 0.8))
	end
end

function BUILD.lampe(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	part(g, "pied", { 1.6, 0.3, 1.6 }, Vector3.new(x, y0 + 0.15, z), Color3.fromRGB(40, 38, 36), Enum.Material.Metal)
	part(g, "tige", { 0.25, 5.4, 0.25 }, Vector3.new(x, y0 + 3.0, z), Color3.fromRGB(40, 38, 36), Enum.Material.Metal)
	local shade = part(
		g,
		"abat-jour",
		{ 1.6, 1.0, 1.6 },
		Vector3.new(x, y0 + 5.9, z),
		Color3.fromRGB(255, 205, 140),
		Enum.Material.Neon,
		{ transparency = 0.2 }
	)
	if not it.noLight then
		addLight(shade, WARM, 28, 1.1)
	end
end

function BUILD.poutre(g, it, size, c, y0)
	local beam = part(g, "poutre", size, Vector3.new(c.X + it.x, y0 + it.y, c.Z + it.z), DARK_WOOD)
	-- Poussière : tombe doucement de la poutre (légère, coupée par Config.Visual.Dust)
	if Config.Visual.Dust then
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "Poussière"
		dust.Rate = math.max(1, Config.Visual.DustRate)
		dust.Lifetime = NumberRange.new(8, 12)
		dust.Speed = NumberRange.new(0.2, 0.8)
		dust.Acceleration = Vector3.new(0, -0.1, 0)
		dust.Drag = 1
		dust.SpreadAngle = Vector2.new(80, 80)
		dust.EmissionDirection = Enum.NormalId.Bottom
		dust.Size = NumberSequence.new(0.12)
		dust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
		dust.LightEmission = 0.2
		dust.Shape = Enum.ParticleEmitterShape.Box
		dust.Parent = beam
	end
end

-- Panneau explicatif devant une borne (solo ou duo)
function BUILD.panneau(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	local board = part(
		g,
		"Panneau " .. it.label,
		{ size[1], 3.0, size[3] },
		Vector3.new(x, y0 + 3.4, z),
		Color3.fromRGB(30, 26, 24)
	)
	for _, side in ipairs({ -1, 1 }) do
		part(g, "poteau", { 0.3, 1.9, 0.3 }, Vector3.new(x + side * 3.0, y0 + 0.95, z), DARK_WOOD)
	end
	writeOn(board, FACE[it.facing], HubLayout.padText(it.label, Config), 60)
end

-- Tableau des règles, contre le bord du hub
function BUILD.tableau_regles(g, it, size, c, y0)
	local x, z = c.X + it.x, c.Z + it.z
	local board =
		part(g, "TableauRegles", { size[1], 6, size[3] }, Vector3.new(x, y0 + 4.5, z), Color3.fromRGB(30, 26, 24))
	for _, side in ipairs({ -1, 1 }) do
		part(g, "poteau", { 0.4, 1.5, 0.4 }, Vector3.new(x, y0 + 0.75, z + side * 6), DARK_WOOD)
	end
	writeOn(board, FACE[it.facing], HubLayout.rulesText(Config), 40)
end

-- Chargement d'un modèle avec délai maximum (même principe que ModelLoader)
local function loadWithTimeout(id)
	local result, done = nil, false
	task.spawn(function()
		local ok, container = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		result = ok and container or nil
		done = true
	end)
	local limit = (Config.Assets and Config.Assets.Timeout) or 8
	local waited = 0
	while not done and waited < limit do
		task.wait(0.2)
		waited = waited + 0.2
	end
	return result
end

-- Remplace les éléments procéduraux par les modèles chargés (decor pur : jamais de collision)
local function swapModels(folder, groups)
	if Config.Assets and Config.Assets.Enabled == false then
		return
	end
	local cache = Instance.new("Folder")
	cache.Name = "ModèlesHub"
	for kind, key in pairs(HubLayout.ASSETS) do
		local id = Config.Assets and Config.Assets[key]
		if typeof(id) == "number" and id > 0 and groups[kind] then
			local report = AssetLoad.install({ { name = key, id = id } }, loadWithTimeout, cache)
			local template = cache:FindFirstChild(key)
			if #report.ok == 0 or not template then
				print(("[Boot] HubDecor : modèle « %s » non chargé, le décor procédural reste"):format(key))
			else
				for _, entry in ipairs(groups[kind]) do
					pcall(function()
						local model = template:Clone()
						local _, box = model:GetBoundingBox()
						local ratio = math.min(
							entry.size[1] / math.max(box.X, 0.1),
							entry.size[2] / math.max(box.Y, 0.1),
							entry.size[3] / math.max(box.Z, 0.1)
						)
						if ratio > 0 and ratio < math.huge then
							model:ScaleTo(ratio)
						end
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("BasePart") then
								d.Anchored = true
								d.CanCollide = false
								d.CanQuery = false
								d.CanTouch = false
							end
						end
						local cf, newBox = model:GetBoundingBox()
						local floorShift = entry.floor - (cf.Position.Y - newBox.Y / 2)
						model:PivotTo(
							CFrame.new(entry.pos.X, model:GetPivot().Position.Y + floorShift, entry.pos.Z)
								* CFrame.Angles(0, YAW[entry.facing or "-z"], 0)
						)
						model.Parent = folder
						entry.group:Destroy()
					end)
				end
			end
		end
	end
	cache:Destroy()
end

-- Vacillement doux des bougies
local function startFlicker()
	if not Config.Hub.CandleFlicker or #flames == 0 then
		return
	end
	task.spawn(function()
		local rng = Random.new(77)
		while flames[1] and flames[1].Parent do
			for _, light in ipairs(flames) do
				if light.Parent then
					light.Brightness = 0.6 + rng:NextNumber() * 0.4
				end
			end
			task.wait(0.25)
		end
	end)
end

-- Construit le décor dans `parent` (dossier du hub), autour de `center`. Ne lève jamais d'erreur.
function HubDecor.build(parent, center)
	if not Config.Hub.Decor then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Décor"
	folder.Parent = parent
	local limits = RoomBudget.qualityLimits(Config.Visual.RoomLightQuality)
	local plan = HubLayout.plan(
		HubLayout.ITEMS,
		HubLayout.MAX_PARTS,
		math.max(0, HubLayout.lightLimit(limits) - HubLayout.EXISTING_LIGHTS)
	)
	flames = {}
	local groups = {}
	local floorY = center.Y
	for _, it in ipairs(plan.items) do
		local spec = HubLayout.KINDS[it.kind]
		local size = it.size or spec.size
		local ok, err = pcall(function()
			local g = Instance.new("Model")
			g.Name = it.kind
			g.Parent = folder
			BUILD[it.kind](g, it, size, center, floorY)
			if HubLayout.ASSETS[it.kind] then
				groups[it.kind] = groups[it.kind] or {}
				table.insert(groups[it.kind], {
					group = g,
					size = size,
					floor = floorY,
					pos = Vector3.new(center.X + it.x, floorY, center.Z + it.z),
					facing = it.facing,
				})
			end
		end)
		if not ok then
			warn(("[HubDecor] « %s » non construit : %s"):format(it.kind, tostring(err)))
		end
	end
	if plan.dropped > 0 then
		print(
			("[Boot] HubDecor : %d éléments écartés (limite de %d pièces)"):format(
				plan.dropped,
				HubLayout.MAX_PARTS
			)
		)
	end
	-- Ambiance douce, très basse
	if Config.Hub.Music then
		pcall(Audio.play, "ambiance_longue", folder, { volume = Config.Hub.MusicVolume, range = 120, looped = true })
	end
	startFlicker()
	task.spawn(function()
		local ok, err = pcall(swapModels, folder, groups)
		if not ok then
			warn("[HubDecor] modèles non posés : " .. tostring(err))
		end
	end)
	return folder
end

return HubDecor

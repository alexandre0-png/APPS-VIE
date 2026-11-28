-- ModuleScript : ServerScriptService/Sellers
-- LOT 16 : 8 VENDEURS PNJ du hub, un par catégorie de la boutique du kiosque. Modèle Blender par vendeur (SellersData.VENDORS[i].asset) avec REPLI
-- PROCEDURAL obligatoire (étal simple + silhouette + enseigne), mêmes noms de pièces (Etiquette, Lueur), donc mêmes prompts. Ils ne bougent pas, n'interpellent
-- jamais. Chaque vendeur porte une étiquette flottante (BillboardGui, 60 studs) et un ProximityPrompt « Parler » qui ouvre la boutique du kiosque sur son onglet.
-- Module AUTONOME : il ne modifie ni Main, ni Data, ni Config (branchement : roblox/OFFERS_SELLERS_INTEGRATION_NOTES.md). Style : pas de `+=`, pas de `continue`.
--   Sellers.build(parent, config) -> Folder, prompts, info     (idempotent)
--     config = { Config (requis), assets (module Assets : cloneModel("hub", key)), loadAsset = function(id) -> Model, quiet, data = SellersData,
--                kioskData = KioskData, decor = DecorData, center = { x, z } }
--     info = { vendors = { [id] = { model, prompt, billboard, x, z, yaw, usedAsset, reason, parts } }, layout, missing }
--   Sellers.handle(player, action, ctx) -> { ok, id, tab, payload } | { ok = false, reason }   (validation serveur PURE)
--   Sellers.inRange(info, id, px, pz, data) -> bool   (portée mesurée par le serveur)
local Sellers = {}

local function loadSellersData(cfg)
	if type(cfg) == "table" and type(cfg.data) == "table" then
		return cfg.data
	end
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SellersData"))
end

local function loadKioskData(cfg)
	if type(cfg) == "table" and type(cfg.kioskData) == "table" then
		return cfg.kioskData
	end
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KioskData"))
end

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function xyz(v)
	local ok, x, y, z = pcall(function()
		return v.X, v.Y, v.Z
	end)
	if ok and isNum(x) and isNum(y) and isNum(z) then
		return x, y, z
	end
	return nil
end

local function destroy(inst)
	if inst ~= nil then
		pcall(function()
			inst:Destroy()
		end)
	end
end

local function baseName(name)
	if type(name) ~= "string" then
		return ""
	end
	local n = name:gsub("%.%d+$", "")
	n = n:gsub("__%x%x%x%x%x%x$", "")
	return n
end

local BLOCKED = { "Script", "LocalScript", "ModuleScript", "Tool", "HopperBin", "RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction" }
local function blockedClass(Config, className)
	if type(Config.isBlockedClass) == "function" then
		local ok, res = pcall(Config.isBlockedClass, className)
		if ok then
			return res == true
		end
	end
	for _, c in ipairs(BLOCKED) do
		if c == className then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- modèle Blender

local function fetchModel(cfg, D, vendor)
	if cfg.Config.Assets and cfg.Config.Assets.Enabled == false then
		return nil, "Assets désactivé"
	end
	local ok, res
	if type(cfg.assets) == "table" and type(cfg.assets.cloneModel) == "function" then
		ok, res = pcall(cfg.assets.cloneModel, D.ASSET_GROUP, vendor.key)
		if not ok then
			return nil, "cloneModel : " .. tostring(res)
		end
		if res == nil then
			return nil, "modèle hub." .. vendor.key .. " non préchargé"
		end
		return res
	end
	local loader = cfg.loadAsset
	if type(loader) ~= "function" then
		loader = function(id)
			return game:GetService("InsertService"):LoadAsset(id)
		end
	end
	ok, res = pcall(loader, vendor.asset)
	if not ok then
		return nil, "LoadAsset : " .. tostring(res)
	end
	if res == nil then
		return nil, "LoadAsset : rien reçu"
	end
	local okKids, kids = pcall(function()
		return res:GetChildren()
	end)
	if okKids and type(kids) == "table" and #kids == 1 then
		local okM, isModel = pcall(function()
			return kids[1]:IsA("Model")
		end)
		if okM and isModel == true then
			local inner = kids[1]
			inner.Parent = nil
			destroy(res)
			return inner
		end
	end
	return res
end

local function vetModel(model, cfg, D)
	local Config = cfg.Config
	local okList, list = pcall(function()
		return model:GetDescendants()
	end)
	if not okList or type(list) ~= "table" then
		return false, "modèle illisible"
	end
	local blocked = {}
	for _, d in ipairs(list) do
		local okC, cls = pcall(function()
			return d.ClassName
		end)
		if not okC or type(cls) ~= "string" then
			return false, "instance corrompue"
		end
		if blockedClass(Config, cls) then
			blocked[#blocked + 1] = d
		end
	end
	for _, d in ipairs(blocked) do
		destroy(d)
	end
	local okAfter, after = pcall(function()
		return model:GetDescendants()
	end)
	if not okAfter or type(after) ~= "table" then
		return false, "modèle illisible après nettoyage"
	end
	local parts = 0
	for _, d in ipairs(after) do
		local okP, isPart = pcall(function()
			return d:IsA("BasePart")
		end)
		if okP and isPart == true then
			parts = parts + 1
			d.Anchored = true
		end
	end
	if parts < 1 then
		return false, "aucune Part"
	end
	if parts > D.MAX_PARTS then
		return false, "trop de Parts (" .. parts .. " > " .. D.MAX_PARTS .. ")"
	end
	local function width()
		local okE, e = pcall(function()
			return model:GetExtentsSize()
		end)
		local ex, _, ez = xyz(okE and e or nil)
		if ex == nil then
			return nil
		end
		return math.max(ex, ez)
	end
	local w = width()
	if w == nil or w < 0.5 then
		return false, "mesure impossible"
	end
	if math.abs(w - D.WIDTH) > D.SIZE_TOLERANCE * D.WIDTH then
		if w < D.WIDTH / 4 or w > D.WIDTH * 4 then
			return false, "dimensions absurdes (" .. tostring(w) .. " studs)"
		end
		local okS = pcall(function()
			model:ScaleTo(model:GetScale() * D.WIDTH / w)
		end)
		w = okS and width() or nil
		if w == nil or math.abs(w - D.WIDTH) > D.SIZE_TOLERANCE * D.WIDTH then
			return false, "dimensions hors tolérance"
		end
	end
	return true, parts
end

local function indexParts(model)
	local out = {}
	local okList, list = pcall(function()
		return model:GetDescendants()
	end)
	if okList and type(list) == "table" then
		for _, d in ipairs(list) do
			local okP, isPart = pcall(function()
				return d:IsA("BasePart")
			end)
			if okP and isPart == true then
				local n = baseName(d.Name)
				if out[n] == nil then
					out[n] = d
				end
			end
		end
	end
	return out
end

---------------------------------------------------------------- repli procédural

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function part(props, parent)
	props.Anchored = true
	if props.Material == nil then
		props.Material = Enum.Material.SmoothPlastic
	end
	props.TopSurface, props.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return mk("Part", props, parent)
end

-- Étal simple en Parts de base. Repère local : devant vers -Z. Retourne le nombre de Parts.
local function buildProcedural(model, v, x, z, theta, D, K)
	local n = 0
	local y0 = D.GROUND_Y
	local col = rgb(v.color)
	local function world(lx, lz)
		return K.toWorld(x, z, theta, lx, lz)
	end
	local function P(props, lx, ly, lz, ang)
		local wx, wz = world(lx, lz)
		props.CFrame = CFrame.new(wx, y0 + ly, wz) * CFrame.Angles(0, theta + (ang or 0), 0)
		n = n + 1
		return part(props, model)
	end
	P({ Name = "Comptoir", Size = Vector3.new(D.WIDTH, 2.4, 1.8), Color = Color3.fromRGB(150, 104, 62), Material = Enum.Material.WoodPlanks }, 0, 1.2, -1.6)
	P({ Name = "Etagere", Size = Vector3.new(D.WIDTH - 0.8, 0.4, 1.2), Color = Color3.fromRGB(120, 84, 50), Material = Enum.Material.Wood }, 0, 2.6, 0.9)
	for _, sx in ipairs({ -2.9, 2.9 }) do
		P({ Name = "Poteau", Size = Vector3.new(0.5, 5.6, 0.5), Color = Color3.fromRGB(110, 78, 46), Material = Enum.Material.Wood }, sx, 2.8, -1.4)
	end
	P({ Name = "Auvent", Size = Vector3.new(D.WIDTH + 0.6, 0.4, 3.6), Color = col, Material = Enum.Material.Fabric }, 0, 5.7, -1.0)
	P({ Name = "Corps", Size = Vector3.new(1.8, 2.6, 1.2), Color = col, Material = Enum.Material.Fabric }, 0, 2.2, 0.6)
	P({ Name = "Tete", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Color = Color3.fromRGB(240, 200, 160) }, 0, 4.1, 0.6)
	local et = P({ Name = D.LABEL_PART, Size = Vector3.new(4, 1.2, 0.25), Color = Color3.fromRGB(58, 44, 36), Material = Enum.Material.Wood }, 0, 6.2, -2.95)
	local lueur = P({ Name = D.LIGHT_PART, Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false }, 0, 5.2, -1.0)
	return n, et, lueur
end

---------------------------------------------------------------- étiquettes, prompt

-- Face de la planche dont la normale pointe le plus vers (ux, uz) (devant du vendeur) ; Front par défaut si la mesure échoue.
local function bestFace(et, ux, uz)
	local faces = { { Enum.NormalId.Front, 0, -1 }, { Enum.NormalId.Back, 0, 1 }, { Enum.NormalId.Right, 1, 0 }, { Enum.NormalId.Left, -1, 0 } }
	local best, bestDot = Enum.NormalId.Front, -2
	for _, f in ipairs(faces) do
		local ok, wx, wz = pcall(function()
			local w = et.CFrame:VectorToWorldSpace(Vector3.new(f[2], 0, f[3]))
			return w.X, w.Z
		end)
		if ok and isNum(wx) and isNum(wz) then
			local dot = wx * ux + wz * uz
			if dot > bestDot then
				best, bestDot = f[1], dot
			end
		end
	end
	return best
end

local function addLabel(et, v, D, face)
	local gui = mk("SurfaceGui", { Name = "EtiquetteGui", Face = face, LightInfluence = 0, PixelsPerStud = 40 }, et)
	mk("TextLabel", {
		Name = "Texte", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = D.labelText(v), TextScaled = true, Font = Enum.Font.GothamBold,
		TextColor3 = rgb(v.color), TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
	}, gui)
	return gui
end

local function addBillboard(et, v, D, Config)
	local B = D.BILLBOARD
	local gui = mk("BillboardGui", {
		Name = "SellerBillboard", Adornee = et, Size = UDim2.fromOffset(B.width, B.height), StudsOffsetWorldSpace = Vector3.new(0, B.offsetY, 0),
		MaxDistance = B.maxDistance, AlwaysOnTop = false, LightInfluence = 0, ResetOnSpawn = false,
	}, et)
	local box = mk("Frame", { Name = "Fond", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 24, 34), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, box)
	local function line(name, text, y, h, size, color)
		return mk("TextLabel", {
			Name = name, Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, h), BackgroundTransparency = 1, Text = text, TextSize = size,
			Font = Enum.Font.GothamBold, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
		}, box)
	end
	line("Icone", v.emoji .. " " .. v.title, 4, 36, 28, rgb(v.color))
	line("Prix", D.priceLine(v, Config), 42, 30, 20, Color3.fromRGB(255, 255, 255))
	line("Exemple1", v.lines[1], 74, 24, 16, Color3.fromRGB(215, 215, 225))
	line("Exemple2", v.lines[2], 98, 24, 16, Color3.fromRGB(215, 215, 225))
	return gui
end

local function addPrompt(target, v, D)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "SellerPrompt_" .. v.id
	pr.ActionText = D.PROMPT.action
	pr.ObjectText = v.title
	pr.HoldDuration = D.PROMPT.hold
	pr.MaxActivationDistance = D.PROMPT.distance
	pr.RequiresLineOfSight = D.PROMPT.requiresLineOfSight
	pr:SetAttribute("SellerAction", v.id)
	pr.Parent = target
	pcall(function()
		game:GetService("CollectionService"):AddTag(pr, "SellerPrompt")
	end)
	return pr
end

---------------------------------------------------------------- construction

local function buildOne(folder, v, spot, cfg, D, K)
	local Config = cfg.Config
	local res = { x = spot.x, z = spot.z, usedAsset = false, parts = 0 }
	local ux, uz = spot.faceX - spot.x, spot.faceZ - spot.z
	local model, found, et, lueur
	local okAsset, reason = pcall(function()
		local m, why = fetchModel(cfg, D, v)
		if m == nil then
			error(why or "modèle absent", 0)
		end
		local okVet, n = vetModel(m, cfg, D)
		if not okVet then
			destroy(m)
			error(tostring(n), 0)
		end
		local idx = indexParts(m)
		local pv = m:GetPivot()
		local lx, lz = 0, -1
		local ep = idx[D.LABEL_PART]
		local bx, _, bz = xyz(ep ~= nil and ep.Position or nil)
		local px, _, pz = xyz(pv.Position)
		if bx ~= nil and px ~= nil and (bx - px) ^ 2 + (bz - pz) ^ 2 > 1e-6 then
			lx, lz = bx - px, bz - pz
		end
		local theta = K.yawFor(lx, lz, ux, uz)
		m.Name = "Vendor_" .. v.id
		m:PivotTo(CFrame.new(spot.x, D.GROUND_Y, spot.z) * CFrame.Angles(0, theta, 0))
		m.Parent = folder
		model, found, res.yaw, res.parts = m, idx, theta, n
		res.usedAsset = true
	end)
	if not okAsset then
		res.reason = tostring(reason)
		if cfg.quiet ~= true then
			pcall(function()
				warn("[Sellers] modèle " .. v.id .. " indisponible, repli procédural : " .. res.reason)
			end)
		end
		if model ~= nil then
			destroy(model)
		end
		model = Instance.new("Model")
		model.Name = "Vendor_" .. v.id
		local theta = K.yawFor(0, -1, ux, uz)
		res.yaw = theta
		res.usedAsset = false
		local n, e, l = buildProcedural(model, v, spot.x, spot.z, theta, D, K)
		res.parts = n
		model.Parent = folder
		found = { [D.LABEL_PART] = e, [D.LIGHT_PART] = l }
	end
	et = found[D.LABEL_PART]
	if et == nil then -- modèle sans planche : planche invisible-lisible posée devant l'étal
		local c, s = math.cos(res.yaw), math.sin(res.yaw)
		local lxw, lzw = 0, -3.0
		local wx = spot.x + lxw * c + lzw * s
		local wz = spot.z - lxw * s + lzw * c
		et = part({ Name = D.LABEL_PART, Size = Vector3.new(4, 1.2, 0.25), CFrame = CFrame.new(wx, D.GROUND_Y + 6.2, wz) * CFrame.Angles(0, res.yaw, 0), Color = Color3.fromRGB(58, 44, 36), Material = Enum.Material.Wood }, model)
		found[D.LABEL_PART] = et
		res.parts = res.parts + 1
	end
	lueur = found[D.LIGHT_PART]
	if lueur == nil then
		lueur = part({ Name = D.LIGHT_PART, Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Position = Vector3.new(spot.x, D.GROUND_Y + 5.2, spot.z), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, model)
		res.parts = res.parts + 1
	end
	if lueur:FindFirstChildOfClass("PointLight") == nil then
		mk("PointLight", { Color = Color3.fromRGB(255, 226, 160), Range = 12, Brightness = 0.8 }, lueur)
	end
	addLabel(et, v, D, bestFace(et, ux, uz))
	res.billboard = addBillboard(et, v, D, Config)
	res.prompt = addPrompt(et, v, D)
	model:SetAttribute("SellerId", v.id)
	res.model = model
	return res
end

-- Construit (ou reconstruit : idempotent) les vendeurs dans `parent`. Ne lève jamais d'erreur après la validation de `config`.
function Sellers.build(parent, config)
	assert(type(config) == "table" and type(config.Config) == "table", "Sellers.build : config.Config requis")
	local D = loadSellersData(config)
	local K = loadKioskData(config)
	local okKids, kids = pcall(function()
		return parent:GetChildren()
	end)
	if okKids and type(kids) == "table" then
		for _, k in ipairs(kids) do
			if k.Name == D.MODEL_NAME then
				destroy(k)
			end
		end
	end
	local layout = D.layout(config.Config.Map2, K, { decor = config.decor, center = config.center })
	local folder = Instance.new("Folder")
	folder.Name = D.MODEL_NAME
	local prompts, info = {}, { vendors = {}, layout = layout, missing = layout.missing, center = layout.center }
	for _, spot in ipairs(layout.list) do
		local v = D.vendor(spot.id)
		local res = buildOne(folder, v, spot, config, D, K)
		info.vendors[v.id] = res
		prompts[v.id] = res.prompt
	end
	folder.Parent = parent
	info.folder = folder
	return folder, prompts, info
end

---------------------------------------------------------------- validation serveur

local lastAt = setmetatable({}, { __mode = "k" })

local function refuse(reason)
	return { ok = false, reason = reason }
end

function Sellers.forget(player)
	lastAt[player] = nil
end

-- Le joueur (px, pz) est-il à portée du vendeur `id` ? Mesure SERVEUR à partir de la position construite.
function Sellers.inRange(info, id, px, pz, data)
	local D = data or loadSellersData(nil)
	local v = type(info) == "table" and type(info.vendors) == "table" and info.vendors[id] or nil
	if v == nil or not isNum(px) or not isNum(pz) then
		return false
	end
	return math.sqrt((px - v.x) ^ 2 + (pz - v.z) ^ 2) <= D.SERVER_RANGE
end

-- Traite une demande « Parler » (prompt). ctx = { Config (requis), inRange = function(player, id) -> bool (requis), clock = function() (facultatif), data = SellersData }.
-- Retourne { ok = true, id, tab, payload = { panel = "shop", tab, vendor } } ou { ok = false, reason } : contexte, joueur, action, distance, pause, erreur.
function Sellers.handle(player, action, ctx)
	if type(ctx) ~= "table" or type(ctx.Config) ~= "table" or type(ctx.inRange) ~= "function" then
		return refuse("contexte")
	end
	if player == nil then
		return refuse("joueur")
	end
	local id = action
	if type(action) == "table" then
		id = action.id
	end
	local D = loadSellersData(ctx)
	if type(id) ~= "string" or #id > 24 or D.ACTIONS[id] ~= true then
		return refuse("action")
	end
	local okR, near = pcall(ctx.inRange, player, id)
	if not okR or near ~= true then
		return refuse("distance")
	end
	local clock = type(ctx.clock) == "function" and ctx.clock or os.clock
	local t = clock()
	if not isNum(t) then
		return refuse("contexte")
	end
	local prev = lastAt[player]
	if isNum(prev) and t - prev < D.COOLDOWN and t >= prev then
		return refuse("pause")
	end
	local v = D.vendor(id)
	if v == nil then
		return refuse("erreur")
	end
	lastAt[player] = t
	return { ok = true, id = id, tab = v.tab, payload = { panel = "shop", tab = v.tab, vendor = id } }
end

return Sellers

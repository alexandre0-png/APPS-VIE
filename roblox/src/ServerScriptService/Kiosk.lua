-- ModuleScript : ServerScriptService/Kiosk
-- LOT 8B-kiosque : KIOSQUE CENTRAL de la place (comptoir face à la halle). Modèle Blender hub.kiosk (id 90238570290603) avec REPLI PROCEDURAL obligatoire :
-- si le chargement échoue (Assets désactivé, délai, modèle vide, trop lourd, mal dimensionné), un kiosque en Parts de base est construit à la place, avec les
-- mêmes noms de panneaux, donc les mêmes prompts. 4 interactions par ProximityPrompt (étiquetés « KioskPrompt », attribut KioskAction) :
-- shop (boutique Robux existante), calendar (calendrier ; pastille rouge si une récompense est réclamable), odds (probabilités du tapis et prix), ranking (saison).
-- Ce module est AUTONOME : il ne modifie ni Main, ni Data, ni Config. Le branchement (Main : PromptTriggered, remote « Kiosk ») est décrit dans
-- roblox/KIOSK_INTEGRATION_NOTES.md. Style : pas de `+=`, pas de `continue`, valeurs d'origine incertaine gardées par type avant toute comparaison.
--   Kiosk.build(parent, center, config) -> Model, prompts, info
--     center = { x, z } (nil : KioskData.CENTER) ; config = { Config = Config (requis), assets = module Assets de Main (facultatif : cloneModel("hub", "kiosk")),
--     loadAsset = function(id) -> Model (facultatif ; sans assets ni loadAsset : InsertService:LoadAsset, dans un pcall), quiet = true (pas d'avertissement
--     de repli), data = KioskData (facultatif, tests) }
--   Kiosk.handle(player, action, ctx) -> { ok, id | reason, payload }  : validation serveur PURE (aucun service Roblox), voir plus bas.
local Kiosk = {}

local function loadData(cfg)
	if type(cfg) == "table" and type(cfg.data) == "table" then
		return cfg.data
	end
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KioskData"))
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Composantes (x, y, z) d'un Vector3 (userdata dans Roblox, table dans le runtime factice), ou nil si illisibles.
local function xyz(v)
	local ok, x, y, z = pcall(function()
		return v.X, v.Y, v.Z
	end)
	if ok and isNum(x) and isNum(y) and isNum(z) then
		return x, y, z
	end
	return nil
end

-- Nom de base d'une pièce Blender : sans suffixe de couleur « __RRGGBB » ni de doublon « .001 ».
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

local function destroy(inst)
	if inst ~= nil then
		pcall(function()
			inst:Destroy()
		end)
	end
end

---------------------------------------------------------------- modèle Blender

-- Charge le modèle : module Assets (déjà nettoyé et mis en cache) ou chargeur injecté ou InsertService. Retourne (modèle | nil, raison).
local function fetchModel(cfg, D)
	if cfg.Config.Assets and cfg.Config.Assets.Enabled == false then
		return nil, "Assets désactivé"
	end
	local ok, res
	if type(cfg.assets) == "table" and type(cfg.assets.cloneModel) == "function" then
		ok, res = pcall(cfg.assets.cloneModel, D.ASSET_GROUP, D.ASSET_KEY)
		if not ok then
			return nil, "cloneModel : " .. tostring(res)
		end
		if res == nil then
			return nil, "modèle hub.kiosk non préchargé"
		end
		return res
	end
	local loader = cfg.loadAsset
	if type(loader) ~= "function" then
		loader = function(id)
			return game:GetService("InsertService"):LoadAsset(id)
		end
	end
	ok, res = pcall(loader, D.ASSET_ID)
	if not ok then
		return nil, "LoadAsset : " .. tostring(res)
	end
	if res == nil then
		return nil, "LoadAsset : rien reçu"
	end
	-- LoadAsset enveloppe le modèle dans un Model conteneur : on le déballe s'il ne contient qu'un Model
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

-- Nettoie, borne et mesure le modèle. Retourne (true, nombre de Parts) ou (false, raison). Le modèle refusé est détruit par l'appelant.
local function vetModel(model, cfg, D)
	local Config = cfg.Config
	local okList, list = pcall(function()
		return model:GetDescendants()
	end)
	if not okList or type(list) ~= "table" then
		return false, "modèle illisible"
	end
	local blocked, parts = {}, 0
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
	local maxParts = D.MAX_PARTS
	if type(Config.Assets) == "table" and isNum(Config.Assets.decorMaxParts) then
		maxParts = math.min(maxParts, math.max(Config.Assets.decorMaxParts, 1))
	end
	if parts > maxParts then
		return false, "trop de Parts (" .. parts .. " > " .. maxParts .. ")"
	end
	-- taille : largeur mesurée à +-25 % de la largeur attendue ; une seule remise à l'échelle, puis remesure
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

-- Retrouve les pièces nommées du modèle : { PanneauBoutique = part, ..., Lueur = part, PastilleCalendrier = part }.
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

local function cylinder(props, parent, diameter, height, pos)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props, parent)
end

-- Construit le kiosque en Parts de base dans `model` ; retourne le nombre de Parts. Repère local : comptoir (boutique) vers -Z, rotation theta.
local function buildProcedural(model, cx, cz, theta, D)
	local n = 0
	local y0 = D.GROUND_Y
	local function world(lx, lz)
		return D.toWorld(cx, cz, theta, lx, lz)
	end
	local function P(props)
		n = n + 1
		return part(props, model)
	end
	n = n + 1
	cylinder({ Name = "Socle", Color = Color3.fromRGB(176, 160, 130), Material = Enum.Material.Cobblestone }, model, D.WIDTH, 0.8, Vector3.new(cx, y0 + 0.4, cz))
	for _, corner in ipairs({ { 5.4, 5.4 }, { -5.4, 5.4 }, { 5.4, -5.4 }, { -5.4, -5.4 } }) do
		local wx, wz = world(corner[1], corner[2])
		P({ Name = "Pilier", Size = Vector3.new(0.9, 8.6, 0.9), Position = Vector3.new(wx, y0 + 0.8 + 4.3, wz), Color = Color3.fromRGB(226, 214, 190), Material = Enum.Material.Marble })
	end
	n = n + 1
	cylinder({ Name = "Toit", Color = Color3.fromRGB(196, 110, 80), Material = Enum.Material.Slate }, model, D.WIDTH - 1, 0.7, Vector3.new(cx, y0 + 9.5, cz))
	n = n + 1
	cylinder({ Name = "ToitHaut", Color = Color3.fromRGB(176, 96, 70), Material = Enum.Material.Slate }, model, 8.4, 1.3, Vector3.new(cx, y0 + 10.5, cz))
	P({ Name = "Pointe", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = Vector3.new(cx, y0 + 11.7, cz), Color = Color3.fromRGB(255, 214, 120), Material = Enum.Material.Metal })
	local lueur = P({ Name = D.LIGHT_PART, Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.7, 1.7), Position = Vector3.new(cx, y0 + 6.2, cz), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false })
	mk("PointLight", { Color = Color3.fromRGB(255, 226, 160), Range = 22, Brightness = 1.2 }, lueur)
	for _, p in ipairs(D.PANELS) do
		local wx, wz = world(p.rel.x, p.rel.z)
		local lean = 0.8 -- le panneau est reculé de 0,8 vers le centre par rapport au comptoir
		local ix, iz = world(p.rel.x * (1 - lean / D.RADIUS), p.rel.z * (1 - lean / D.RADIUS))
		P({ Name = "Comptoir_" .. p.id, Size = Vector3.new(8, 2.6, 1.6), CFrame = CFrame.new(wx, y0 + 0.8 + 1.3, wz) * CFrame.Angles(0, theta + p.ang, 0), Color = Color3.fromRGB(150, 104, 62), Material = Enum.Material.WoodPlanks })
		local board = P({ Name = p.part, Size = Vector3.new(7, 3.4, 0.4), CFrame = CFrame.new(ix, y0 + 0.8 + 4.5, iz) * CFrame.Angles(0, theta + p.ang, 0), Color = Color3.fromRGB(58, 44, 36), Material = Enum.Material.Wood })
		local gui = mk("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, PixelsPerStud = 40 }, board)
		mk("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = p.emoji .. " " .. p.title .. "\n" .. p.sub, TextScaled = true, Font = Enum.Font.GothamBold,
			TextColor3 = rgb(p.color), TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		}, gui)
	end
	return n
end

---------------------------------------------------------------- prompts, pastille, ambiance

local function addPrompt(target, p, D)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "KioskPrompt_" .. p.id
	pr.ActionText = p.action
	pr.ObjectText = p.object
	pr.HoldDuration = D.PROMPT.hold
	pr.MaxActivationDistance = D.PROMPT.distance
	pr.RequiresLineOfSight = D.PROMPT.requiresLineOfSight
	pr:SetAttribute("KioskAction", p.id)
	pr.Parent = target
	pcall(function()
		game:GetService("CollectionService"):AddTag(pr, "KioskPrompt")
	end)
	return pr
end

-- Son d'ambiance : boucle, volume bas, atténuation par la distance. Aucun Sound si Config.SOUNDS_ENABLED == false ou si l'id est vide.
local function addAmbience(parent, Config, D)
	if Config.SOUNDS_ENABLED == false then
		return nil
	end
	local def = D.SOUND
	local over = type(Config.SOUNDS) == "table" and Config.SOUNDS[D.SOUND.key] or nil
	local id, vol = def.id, def.vol
	if type(over) == "table" then
		if type(over.id) == "string" then
			id = over.id
		end
		if isNum(over.vol) then
			vol = over.vol
		end
	end
	if type(id) ~= "string" or id == "" or not isNum(vol) or vol <= 0 then
		return nil
	end
	return mk("Sound", {
		Name = "KioskAmbience", SoundId = id, Volume = math.min(vol, 0.5), Looped = true, RollOffMode = Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = def.minDist, RollOffMaxDistance = def.maxDist, Playing = true,
	}, parent)
end

local function ensureBadge(model, found, D)
	local badge = found[D.BADGE_NAME]
	if badge == nil then
		local anchor = found[D.panel("calendar").part]
		local pos = Vector3.new(0, 0, 0)
		local ax, ay, az = xyz(anchor ~= nil and anchor.Position or nil)
		if ax ~= nil then
			pos = Vector3.new(ax, ay + 3.2, az)
		end
		badge = part({ Name = D.BADGE_NAME, Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Position = pos, Color = Color3.fromRGB(235, 40, 40), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, model)
	end
	badge.Transparency = 1
	badge:SetAttribute("Ready", false)
	return badge
end

-- Pastille du calendrier : visible seulement quand une récompense est réclamable (calculé par l'appelant). Idempotent.
function Kiosk.setBadge(info, ready)
	if type(info) ~= "table" then
		return
	end
	local on = ready == true
	if info.ready == on then
		return
	end
	info.ready = on
	if info.badge ~= nil then
		pcall(function()
			info.badge.Transparency = on and 0 or 1
			info.badge:SetAttribute("Ready", on)
		end)
	end
	local pr = info.prompts and info.prompts.calendar
	if pr ~= nil then
		pcall(function()
			pr.ObjectText = on and "Calendrier : récompense prête !" or "Calendrier des œufs"
		end)
	end
end

-- Une vue de Calendar.view (ou nil) justifie-t-elle la pastille ? Jour du jour réclamable, ou jour manqué rattrapable avec un jeton.
function Kiosk.badgeNeeded(view)
	if type(view) ~= "table" then
		return false
	end
	if view.canToday == true then
		return true
	end
	if view.eligible == true and isNum(view.catch) and view.catch > 0 and type(view.states) == "string" and string.find(view.states, "m", 1, true) ~= nil then
		return true
	end
	return false
end

---------------------------------------------------------------- construction

-- Construit (ou reconstruit : idempotent) le kiosque dans `parent`. Retourne (Model, prompts, info). Ne lève jamais d'erreur après la validation de `config`.
function Kiosk.build(parent, center, config)
	assert(type(config) == "table" and type(config.Config) == "table", "Kiosk.build : config.Config requis")
	local D = loadData(config)
	local Config = config.Config
	local cx = type(center) == "table" and isNum(center.x) and center.x or D.CENTER.x
	local cz = type(center) == "table" and isNum(center.z) and center.z or D.CENTER.z

	-- idempotence : un kiosque déjà présent est détruit (aucune copie en double, aucune instance orpheline)
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

	local info = { center = Vector3.new(cx, D.GROUND_Y, cz), ready = false, usedAsset = false, reason = nil, parts = 0, yaw = 0 }
	local fx, fz = D.FACE.x - cx, D.FACE.z - cz
	local model
	local found = {}

	local okAsset, reason = pcall(function()
		local m, why = fetchModel(config, D)
		if m == nil then
			error(why or "modèle absent", 0)
		end
		local okVet, res = vetModel(m, config, D)
		if not okVet then
			destroy(m)
			error(tostring(res), 0)
		end
		local idx = indexParts(m)
		-- orientation : le PanneauBoutique doit regarder la halle, d'après sa position réelle par rapport au pivot du modèle
		local pv = m:GetPivot()
		local lx, lz = 0, -1
		local pb = idx[D.panel("shop").part]
		local bx, _, bz = xyz(pb ~= nil and pb.Position or nil)
		local px, _, pz = xyz(pv.Position)
		if bx ~= nil and px ~= nil then
			lx, lz = bx - px, bz - pz
		end
		local theta = D.yawFor(lx, lz, fx, fz)
		m.Name = D.MODEL_NAME
		m:PivotTo(CFrame.new(cx, D.GROUND_Y, cz) * CFrame.Angles(0, theta, 0))
		m.Parent = parent
		model, found, info.yaw, info.parts = m, idx, theta, res
		info.usedAsset = true
	end)
	if not okAsset then
		info.reason = tostring(reason)
		if config.quiet ~= true then
			pcall(function()
				warn("[Kiosk] modèle Blender indisponible, repli procédural : " .. info.reason)
			end)
		end
		if model ~= nil then
			destroy(model)
			model = nil
		end
		model = Instance.new("Model")
		model.Name = D.MODEL_NAME
		local theta = D.yawFor(0, -1, fx, fz)
		info.yaw = theta
		info.usedAsset = false
		info.parts = buildProcedural(model, cx, cz, theta, D)
		model.Parent = parent
		found = indexParts(model)
	end

	-- prompts : un par panneau ; panneau absent du modèle = socle invisible à l'emplacement attendu
	local prompts = {}
	local c, s = math.cos(info.yaw), math.sin(info.yaw)
	for _, p in ipairs(D.PANELS) do
		local target = found[p.part]
		if target == nil then
			local wx = cx + p.rel.x * c + p.rel.z * s
			local wz = cz - p.rel.x * s + p.rel.z * c
			target = part({ Name = p.part, Size = Vector3.new(4, 3, 1), Position = Vector3.new(wx, D.GROUND_Y + 3.5, wz), Transparency = 1, CanCollide = false, CanQuery = false }, model)
			found[p.part] = target
			info.parts = info.parts + 1
		end
		prompts[p.id] = addPrompt(target, p, D)
	end
	info.prompts = prompts
	info.badge = ensureBadge(model, found, D)
	local lueur = found[D.LIGHT_PART]
	if lueur == nil then
		lueur = part({ Name = D.LIGHT_PART, Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = info.center + Vector3.new(0, 6, 0), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, model)
		found[D.LIGHT_PART] = lueur
	end
	if lueur:FindFirstChildOfClass("PointLight") == nil then
		mk("PointLight", { Color = Color3.fromRGB(255, 226, 160), Range = 22, Brightness = 1.2 }, lueur)
	end
	info.light = lueur
	info.sound = addAmbience(lueur, Config, D)
	model:SetAttribute("KioskCenterX", cx)
	model:SetAttribute("KioskCenterZ", cz)
	info.model = model
	return model, prompts, info
end

---------------------------------------------------------------- données affichées (pures)

local function pctText(v)
	local fmt = "%.3f"
	if v >= 10 then
		fmt = "%.1f"
	elseif v >= 0.1 then
		fmt = "%.2f"
	end
	local s = string.format(fmt, v)
	s = s:gsub("%.", ",")
	return s
end

local function weightsTotal(list)
	local total = 0
	if type(list) == "table" then
		for _, w in ipairs(list) do
			if isNum(w) and w > 0 then
				total = total + w
			end
		end
	end
	return total
end

-- Probabilités du tapis (poids normalisés en %, tapis normal et doré) et prix des œufs en Robux / pièces (Config.PRICING). Retourne { rows, prices, lines }.
function Kiosk.oddsData(Config)
	local rows, lines, prices = {}, {}, {}
	local belt = type(Config.BELT) == "table" and type(Config.BELT.weights) == "table" and Config.BELT.weights or {}
	local nTot, gTot = weightsTotal(belt.normal), weightsTotal(belt.golden)
	local refs = type(Config.ODDS) == "table" and type(Config.ODDS.REF) == "table" and Config.ODDS.REF or {}
	local tiers = type(Config.TIERS) == "table" and Config.TIERS or {}
	local fmt = type(Config.fmt) == "function" and Config.fmt or tostring
	for i = 1, #tiers do
		local wn = type(belt.normal) == "table" and isNum(belt.normal[i]) and belt.normal[i] or 0
		local wg = type(belt.golden) == "table" and isNum(belt.golden[i]) and belt.golden[i] or 0
		local normal = nTot > 0 and wn / nTot * 100 or 0
		local golden = gTot > 0 and wg / gTot * 100 or 0
		local name = type(tiers[i]) == "table" and tostring(tiers[i].name) or ("Rareté " .. i)
		rows[#rows + 1] = { tier = i, name = name, normal = normal, golden = golden, ref = isNum(refs[i]) and refs[i] or nil }
		if normal > 0 or golden > 0 then
			lines[#lines + 1] = name .. " : " .. pctText(normal) .. " % (tapis doré " .. pctText(golden) .. " %)"
		else
			lines[#lines + 1] = name .. " : hors tapis"
		end
	end
	if type(Config.PRICING) == "table" then
		local keys = {}
		for k in pairs(Config.PRICING) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			local ta, tb = Config.PRICING[a].tier, Config.PRICING[b].tier
			ta, tb = isNum(ta) and ta or 0, isNum(tb) and tb or 0
			if ta ~= tb then
				return ta < tb
			end
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			local d = Config.PRICING[k]
			if type(d) == "table" then
				local tname = type(tiers[d.tier]) == "table" and tostring(tiers[d.tier].name) or "?"
				local coins = isNum(d.coinCost) and d.coinCost or nil
				prices[#prices + 1] = { key = k, tier = d.tier, name = tname, robux = isNum(d.robuxCost) and d.robuxCost or nil, coins = coins, coinsText = coins and fmt(coins) or "jamais en pièces", where = tostring(d.where) }
				lines[#lines + 1] = tname .. " : " .. (isNum(d.robuxCost) and (d.robuxCost .. " R$") or "?") .. " ou " .. (coins and ("🪙 " .. fmt(coins)) or "jamais en pièces")
			end
		end
	end
	return { rows = rows, prices = prices, lines = lines, version = type(Config.ODDS) == "table" and Config.ODDS.version or nil }
end

-- Entrées de classement assainies : au plus `max`, nom texte de 24 caractères, trophées entiers bornés.
local function cleanTop(list, max)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, e in ipairs(list) do
		if #out >= max then
			break
		end
		if type(e) == "table" and isNum(e.trophies) then
			local name = type(e.name) == "string" and e.name or "?"
			out[#out + 1] = { name = string.sub(name, 1, 24), trophies = math.min(100000, math.max(0, math.floor(e.trophies))) }
		end
	end
	return out
end

---------------------------------------------------------------- validation serveur

local lastAt = setmetatable({}, { __mode = "k" }) -- joueur -> horloge de sa dernière action acceptée (clés faibles : aucune fuite)

local function refuse(reason)
	return { ok = false, reason = reason }
end

-- À appeler à PlayerRemoving (facultatif : la table est à clés faibles).
function Kiosk.forget(player)
	lastAt[player] = nil
end

-- Traite une demande d'interaction. TOUT est revérifié ici, que l'action vienne d'un prompt ou d'un remote :
--   player : le joueur (jamais lu pour ses données, seulement transmis à ctx) ; action : identifiant (chaîne) ou { id = chaîne } ;
--   ctx = { Config (requis), inRange = function(player) -> bool (requis : distance réelle au kiosque, mesurée par le serveur),
--           clock = function() -> secondes (facultatif, os.clock), now = function() -> heure UTC en secondes (facultatif, os.time),
--           calView = function(player) -> Calendar.view | nil, top = function(season, count) -> { {name, trophies} }, mine = function(player) -> table | nil }.
-- Retourne { ok = true, id, payload } ou { ok = false, reason } avec reason parmi : contexte, joueur, action, distance, pause, erreur.
function Kiosk.handle(player, action, ctx)
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
	local D = loadData(ctx)
	if type(id) ~= "string" or #id > 24 or D.ACTIONS[id] ~= true then
		return refuse("action")
	end
	local okR, inRange = pcall(ctx.inRange, player)
	if not okR or inRange ~= true then
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
	local Config = ctx.Config
	local okP, payload = pcall(function()
		if id == "shop" then
			return { panel = "shop" }
		elseif id == "calendar" then
			local view = type(ctx.calView) == "function" and ctx.calView(player) or nil
			if type(view) ~= "table" then
				view = nil
			end
			return { panel = "calendar", view = view, ready = Kiosk.badgeNeeded(view) }
		elseif id == "odds" then
			local od = Kiosk.oddsData(Config)
			od.panel = "odds"
			return od
		end
		local now = type(ctx.now) == "function" and ctx.now() or os.time()
		now = isNum(now) and now or 0
		local seasonSeconds = type(Config.PVP) == "table" and isNum(Config.PVP.seasonSeconds) and Config.PVP.seasonSeconds > 0 and Config.PVP.seasonSeconds or 7 * 86400
		local season = type(Config.pvpSeason) == "function" and Config.pvpSeason(now) or math.floor(now / seasonSeconds)
		local entries = type(ctx.top) == "function" and ctx.top(season, D.MAX_ENTRIES) or {}
		local mine = type(ctx.mine) == "function" and ctx.mine(player) or nil
		return { panel = "ranking", season = season, secondsLeft = math.max(0, (math.floor(now / seasonSeconds) + 1) * seasonSeconds - now), entries = cleanTop(entries, D.MAX_ENTRIES), mine = type(mine) == "table" and mine or nil }
	end)
	if not okP or type(payload) ~= "table" then
		return refuse("erreur")
	end
	lastAt[player] = t
	return { ok = true, id = id, payload = payload }
end

return Kiosk

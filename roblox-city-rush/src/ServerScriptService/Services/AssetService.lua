--[[
	AssetService : chargement sécurisé de modèles Roblox externes (apparence des voitures, épaves, décor).
	Règles :
	  * serveur uniquement, InsertService:LoadAsset dans un pcall avec délai maximum
	  * suppression de tout Script / LocalScript / ModuleScript / RemoteEvent / BindableEvent (et assimilés)
	  * un véhicule doit avoir un PrimaryPart ou des roues identifiables, sinon il est rejeté (voiture intégrée conservée)
	  * la physique reste celle du jeu : la carrosserie chargée est soudée, sans collision ni masse
	  * Config.Assets.Enabled = false : aucun chargement
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SkinMath = require(Shared:WaitForChild("SkinMath"))

local AssetService = {}

local templates = {} -- [id] = Model nettoyé
local failures = {} -- [id] = raison
local pending = {} -- [id] = true pendant le chargement
local rng = Random.new()
local store

AssetService.stats = { loaded = 0, failed = 0, removed = 0 }

-- Classes interdites : jamais conservées dans un modèle externe
local FORBIDDEN = {
	Script = true, LocalScript = true, ModuleScript = true, RemoteEvent = true, RemoteFunction = true,
	BindableEvent = true, BindableFunction = true, Tool = true, HopperBin = true, Sound = true, ForceField = true,
	Humanoid = true, ProximityPrompt = true, ClickDetector = true, Seat = true, VehicleSeat = true,
	-- jointures du modèle d'origine : remplacées par nos soudures
	Weld = true, WeldConstraint = true, Motor6D = true, ManualWeld = true, Snap = true,
}
AssetService.FORBIDDEN = FORBIDDEN

local WHEEL_WORDS = { "wheel", "tire", "tyre", "roue", "rim" }

local function isWheelName(name)
	local n = string.lower(name)
	for _, w in ipairs(WHEEL_WORDS) do
		if string.find(n, w, 1, true) then
			return true
		end
	end
	return false
end

local function cfg()
	return Config.Assets
end

-- Supprime les instances interdites ; retourne (nb supprimées, nb de BaseParts)
local function sanitize(root)
	local removed, parts = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if FORBIDDEN[d.ClassName] then
			d:Destroy()
			removed += 1
		end
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return removed, parts
end
AssetService.sanitize = sanitize

-- Charge un modèle avec délai maximum. Retourne (conteneur | nil, raison)
local function rawLoad(id)
	local done, result, err, timedOut = false, nil, nil, false
	task.spawn(function()
		local ok, res = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok then
			result = res
		else
			err = tostring(res)
		end
		done = true
		if timedOut and result then
			result:Destroy() -- arrivé trop tard : jeté
		end
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < cfg().LoadTimeout do
		task.wait(0.1)
	end
	if not done then
		timedOut = true
		return nil, "délai dépassé"
	end
	if not result then
		return nil, err or "chargement refusé"
	end
	return result, nil
end

-- kind = "vehicle" | "wreck" | "decor". Retourne (Model nettoyé | nil, raison)
local function prepare(id, kind)
	local container, reason = rawLoad(id)
	if not container then
		return nil, reason
	end
	-- un seul Model racine (ou on regroupe les parts)
	local root = container:FindFirstChildOfClass("Model")
	if not root then
		root = Instance.new("Model")
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("BasePart") then
				c.Parent = root
			end
		end
	end
	container:Destroy()
	local removed, parts = sanitize(root)
	AssetService.stats.removed += removed
	if parts == 0 then
		root:Destroy()
		return nil, "modèle vide"
	end
	if parts > cfg().MaxParts then
		root:Destroy()
		return nil, "trop de parts (" .. parts .. ")"
	end
	if kind == "vehicle" and not root.PrimaryPart then
		-- pas de PrimaryPart : acceptable seulement si des roues sont identifiables
		local wheels, biggest, bigVol = 0, nil, -1
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				if isWheelName(d.Name) then
					wheels += 1
				end
				local vol = d.Size.X * d.Size.Y * d.Size.Z
				if vol > bigVol then
					biggest, bigVol = d, vol
				end
			end
		end
		if wheels < 2 or not biggest then
			root:Destroy()
			return nil, "ni PrimaryPart ni roues identifiables"
		end
		root.PrimaryPart = biggest
	end
	local _, size = root:GetBoundingBox()
	local ok, why = SkinMath.sizeOk(size.X, size.Y, size.Z, cfg().MaxSize)
	if not ok then
		root:Destroy()
		return nil, why
	end
	return root, nil
end

local function ensureLoaded(id, kind)
	if templates[id] or failures[id] or pending[id] then
		return
	end
	pending[id] = true
	local ok, root, reason = pcall(prepare, id, kind)
	pending[id] = nil
	if ok and root then
		root.Name = "Template_" .. id
		root.Parent = store
		templates[id] = root
		AssetService.stats.loaded += 1
	else
		failures[id] = ok and reason or tostring(root)
		AssetService.stats.failed += 1
		warn(string.format("[AssetService] modèle %s ignoré : %s", tostring(id), tostring(failures[id])))
	end
end

function AssetService.getTemplate(id)
	return templates[id]
end

function AssetService.failureReason(id)
	return failures[id]
end

-- Précharge tous les modèles configurés (en parallèle, avec délai maximum). Retourne quand tout est terminé.
function AssetService.preload()
	local c = cfg()
	if not c.Enabled then
		return
	end
	local jobs = {}
	local function add(id, kind)
		if type(id) == "number" and id > 0 then
			table.insert(jobs, { id = id, kind = kind })
		end
	end
	for _, id in pairs(c.Vehicles) do
		add(id, "vehicle")
	end
	for _, id in pairs(c.PoliceCars) do
		add(id, "vehicle")
	end
	add(c.Wreck, "wreck")
	for _, d in pairs(c.Decor) do
		add(d.id, "decor")
	end
	local remaining = #jobs
	for _, j in ipairs(jobs) do
		task.spawn(function()
			ensureLoaded(j.id, j.kind)
			remaining -= 1
		end)
	end
	local t0 = os.clock()
	while remaining > 0 and os.clock() - t0 < c.LoadTimeout + 5 do
		task.wait(0.1)
	end
end

-- ---------------------------------------------------------------- pose d'un modèle sur un repère
-- Met à l'échelle (longueur cible), oriente (axe long = Z), pose le bas à `bottomY` dans le repère `frame`.
local function fit(clone, frame, targetLength, bottomY, extraYawDeg)
	local _, size0 = clone:GetBoundingBox()
	local scale = SkinMath.fitScale(size0.X, size0.Z, targetLength)
	clone:ScaleTo(clone:GetScale() * scale)
	local bboxCF, size = clone:GetBoundingBox()
	local yaw = SkinMath.yawRadians(size.X, size.Z, extraYawDeg or 0)
	local target = frame * CFrame.new(0, bottomY + size.Y / 2, 0) * CFrame.Angles(0, yaw, 0)
	local pivot = clone:GetPivot()
	local pivotToBBox = pivot:ToObjectSpace(bboxCF)
	clone:PivotTo(target * pivotToBBox:Inverse())
end

local function weldAll(clone, chassis, collide)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = collide == true
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = chassis
			w.Part1 = d
			w.Parent = d
		end
	end
end

-- Remplace l'apparence d'un véhicule construit par VehicleBuilder. Retourne true si la carrosserie externe est en place.
function AssetService.skinVehicle(vehicle, id)
	if not cfg().Enabled or type(id) ~= "number" then
		return false
	end
	local template = templates[id]
	local chassis = vehicle.PrimaryPart
	if not template or not chassis then
		return false
	end
	local ok, err = pcall(function()
		local clone = template:Clone()
		sanitize(clone) -- ceinture et bretelles : le gabarit est déjà propre
		fit(clone, chassis.CFrame, chassis.Size.Z + 1, -2.2, (cfg().Yaw or {})[id])
		weldAll(clone, chassis, false)
		clone.Name = "Skin"
		-- on masque la carrosserie intégrée, on garde colliders, sièges et lumières
		for _, d in ipairs(vehicle:GetChildren()) do
			if d:IsA("BasePart") and d ~= chassis and d.Name ~= "Collider" and d.Name ~= "DriverSeat" and d.Name ~= "PassengerSeat" then
				d.Transparency = 1
			end
		end
		chassis.Transparency = 1
		clone.Parent = vehicle
	end)
	if not ok then
		warn("[AssetService] apparence ignorée : " .. tostring(err))
		local bad = vehicle:FindFirstChild("Skin")
		if bad then
			bad:Destroy()
		end
		return false
	end
	vehicle:SetAttribute("Skin", id)
	return true
end

function AssetService.vehicleId(key)
	local id = cfg().Vehicles[key]
	return type(id) == "number" and id or nil
end

function AssetService.pickPublicSkin(baseSpecId)
	local c = cfg()
	if #c.PublicVariants > 0 and rng:NextNumber() < c.PublicVariantChance then
		return AssetService.vehicleId(c.PublicVariants[rng:NextInteger(1, #c.PublicVariants)])
	end
	return AssetService.vehicleId(c.VehicleSkins[baseSpecId] or "")
end

function AssetService.pickPoliceSkin()
	local c = cfg()
	if rng:NextNumber() < c.PoliceTruckChance then
		return c.PoliceCars.truck
	end
	return c.PoliceCars.cruiser
end

-- ---------------------------------------------------------------- épaves et décor (statique, ancré, jamais jouable)
local function placeStatic(id, cf, targetSize, solid, parent)
	local template = templates[id]
	if not template then
		return nil
	end
	local ok, res = pcall(function()
		local clone = template:Clone()
		sanitize(clone)
		fit(clone, cf, targetSize, 0, 0)
		local bboxCF, size = clone:GetBoundingBox()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.Massless = true
			end
		end
		if solid then
			local hit = Instance.new("Part")
			hit.Name = "SolidBox"
			hit.Anchored = true
			hit.Transparency = 1
			hit.CanQuery = false
			hit.Size = size
			hit.CFrame = bboxCF
			hit.Parent = clone
		end
		clone.Parent = parent
		return clone
	end)
	if not ok then
		warn("[AssetService] décor ignoré : " .. tostring(res))
		return nil
	end
	return res
end

function AssetService.placeWrecks(world)
	local c = cfg()
	if not c.Enabled or not templates[c.Wreck] then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = "Wrecks"
	folder.Parent = world.Root
	local n = 0
	for i, pos in ipairs(world.WreckSpots or {}) do
		if i > c.WreckCount then
			break
		end
		local m = placeStatic(c.Wreck, CFrame.new(pos) * CFrame.Angles(0, i * 1.7, 0), 13, false, folder)
		if m then
			m.Name = "Wreck"
			m:SetAttribute("Wreck", true)
			n += 1
		end
	end
	return n
end

function AssetService.placeDecor(world)
	local c = cfg()
	if not c.Enabled or not world.DecorSpots then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor3D"
	folder.Parent = world.Root
	local n = 0
	for key, spots in pairs(world.DecorSpots) do
		local d = c.Decor[key]
		if d and templates[d.id] then
			for i, spot in ipairs(spots) do
				if i > d.count then
					break
				end
				local m = placeStatic(d.id, spot, d.size, d.solid, folder)
				if m then
					m.Name = key
					n += 1
				end
			end
		end
	end
	return n
end

function AssetService.init()
	store = ServerStorage:FindFirstChild("CityRushAssets")
	if not store then
		store = Instance.new("Folder")
		store.Name = "CityRushAssets"
		store.Parent = ServerStorage
	end
end

return AssetService

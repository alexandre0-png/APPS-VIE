-- AssetLoader.luau : chargement SÛR de modèles externes (InsertService:LoadAsset), côté serveur uniquement.
-- Règles : pcall, délai maximum, nouvelle tentative limitée, nettoyage par liste blanche (tout script,
-- RemoteEvent, BindableEvent ou autre classe non prévue est supprimé), limite de pièces, repli sans effet de bord.

local AssetLoader = {}

-- classes conservées en plus de toutes les BasePart
local KEEP = {
	Model = true,
	Folder = true,
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	FileMesh = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
	Attachment = true,
	Weld = true,
	WeldConstraint = true,
}
-- classes dangereuses comptées à part (supprimées comme tout ce qui n'est pas dans KEEP)
local DANGEROUS = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	UnreliableRemoteEvent = true,
}

local customLoader = nil

-- Permet d'injecter un chargeur factice (tests) : fn(id) -> Instance
function AssetLoader.setLoader(fn)
	customLoader = fn
end

function AssetLoader.validId(id)
	return type(id) == "number" and id > 0 and id % 1 == 0 and id < 2 ^ 53
end

local function scanDanger(node)
	local n = DANGEROUS[node.ClassName] and 1 or 0
	for _, c in ipairs(node:GetChildren()) do
		n = n + scanDanger(c)
	end
	return n
end

-- Supprime tout ce qui n'est pas autorisé. Retourne { removed, dangerous, parts }.
function AssetLoader.sanitize(root)
	local stats = { removed = 0, dangerous = 0, parts = 0 }
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("BasePart") then
				stats.parts = stats.parts + 1
				walk(child)
			elseif KEEP[child.ClassName] then
				walk(child)
			else
				stats.dangerous = stats.dangerous + scanDanger(child)
				stats.removed = stats.removed + 1
				child:Destroy()
			end
		end
	end
	-- la racine elle-même ne peut pas être un script
	if DANGEROUS[root.ClassName] then
		stats.dangerous = stats.dangerous + 1
	end
	walk(root)
	return stats
end

-- Appel de LoadAsset avec délai maximum. Retourne instance ou nil, raison.
local function fetch(id, timeout)
	local result, err, done, timedOut = nil, nil, false, false
	task.spawn(function()
		local ok, res = pcall(function()
			if customLoader then
				return customLoader(id)
			end
			return game:GetService("InsertService"):LoadAsset(id)
		end)
		if ok then
			result = res
		else
			err = tostring(res)
		end
		done = true
		if timedOut and result then
			pcall(function()
				result:Destroy() -- arrivée tardive : on jette
			end)
		end
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
	if not done then
		timedOut = true
		return nil, "délai dépassé (" .. timeout .. " s)"
	end
	if err then
		return nil, err
	end
	if typeof(result) ~= "Instance" then
		return nil, "résultat invalide"
	end
	return result
end

-- Charge, nettoie et emballe un modèle. Retourne Model (sans parent), stats  -- ou nil, raison
function AssetLoader.load(id, opts)
	opts = opts or {}
	if not AssetLoader.validId(id) then
		return nil, "identifiant invalide"
	end
	local attempts = opts.attempts or 2
	local lastReason = "échec"
	for attempt = 1, attempts do
		local container, reason = fetch(id, opts.timeout or 12)
		if container then
			local stats = AssetLoader.sanitize(container)
			if stats.parts < 1 then
				container:Destroy()
				return nil, "modèle vide après nettoyage"
			end
			if stats.parts > (opts.maxParts or 1500) then
				container:Destroy()
				return nil, "trop de pièces (" .. stats.parts .. ")"
			end
			local model = Instance.new("Model")
			model.Name = "Asset_" .. tostring(id)
			for _, child in ipairs(container:GetChildren()) do
				child.Parent = model
			end
			container:Destroy()
			-- décor : figé, sans collision, sans coût physique
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
					d.Massless = true
				end
			end
			return model, stats
		end
		lastReason = reason or lastReason
		if attempt < attempts then
			task.wait(1)
		end
	end
	return nil, lastReason
end

-- Met le modèle à la hauteur voulue. Retourne true si possible.
function AssetLoader.fit(model, targetHeight)
	local _, size = model:GetBoundingBox()
	if size.Y <= 0.01 or targetHeight <= 0 then
		return false
	end
	local k = math.clamp(targetHeight / size.Y, 0.01, 100)
	model:ScaleTo(k)
	return true
end

-- Pose le modèle (centré, base au sol) à groundPos avec une rotation yaw
function AssetLoader.placeOnGround(model, groundPos, yaw)
	local centerCF, size = model:GetBoundingBox()
	local pivotToCenter = model:GetPivot():ToObjectSpace(centerCF)
	local target = CFrame.new(groundPos + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0)
	model:PivotTo(target * pivotToCenter:Inverse())
end

return AssetLoader

-- Modèles Roblox du catalogue : chargement serveur uniquement (InsertService:LoadAsset), nettoyage strict, habillage
-- des animaux et décors de zones. Tout est protégé : en cas d'échec ou de délai dépassé, le jeu garde ses animaux
-- dessinés par le code (voir Config.Assets).

local InsertService = game:GetService("InsertService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local AssetService = {}

-- Classes toujours supprimées d'un modèle importé (code, messages réseau, physique de personnage, sons).
local BANNED = {
	"Script",
	"LocalScript",
	"ModuleScript",
	"RemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
	"Humanoid",
	"Animator",
	"Sound",
}

local rng = Random.new()

AssetService.Stats = { loaded = 0, failed = 0, removed = 0, skins = 0, decor = 0, rejected = 0 }
AssetService.loader = function(id)
	return InsertService:LoadAsset(id)
end

local skins = {} -- { template, name (minuscules), pack }
local decorTemplates = {} -- { template, item }
local pools = {} -- cache : id d'espèce -> liste de modèles

function AssetService.SetLoader(fn)
	AssetService.loader = fn
end

function AssetService.Reset()
	skins = {}
	decorTemplates = {}
	pools = {}
	AssetService.Stats = { loaded = 0, failed = 0, removed = 0, skins = 0, decor = 0, rejected = 0 }
end

local function isBanned(instance)
	for _, class in ipairs(BANNED) do
		if instance:IsA(class) then
			return true
		end
	end
	return false
end

-- Supprime tout élément interdit (le modèle racine inclus dans l'inspection de ses descendants). Renvoie le nombre supprimé.
function AssetService.Sanitize(root)
	local removed = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if isBanned(descendant) then
			descendant:Destroy()
			removed = removed + 1
		end
	end
	AssetService.Stats.removed = AssetService.Stats.removed + removed
	return removed
end

local function countParts(root)
	local count = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count = count + 1
		end
	end
	return count
end

local function hasDirectPart(model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			return true
		end
	end
	return false
end

-- Modèles utilisables d'un conteneur chargé : un modèle portant directement des pièces compte comme un animal.
local function candidates(container, depth, out)
	if container:IsA("Model") and hasDirectPart(container) then
		table.insert(out, container)
		return
	end
	if depth >= 4 then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			candidates(child, depth + 1, out)
		end
	end
end

-- Charge un identifiant avec délai maximum, dans un pcall. Renvoie le conteneur nettoyé ou nil.
function AssetService.Load(id)
	local result, finished = nil, false
	task.spawn(function()
		local ok, value = pcall(function()
			return AssetService.loader(id)
		end)
		if ok then
			result = value
		end
		finished = true
	end)
	local t0 = os.clock()
	while not finished and os.clock() - t0 < Config.Assets.LoadTimeout do
		task.wait(0.1)
	end
	if not finished or result == nil then
		AssetService.Stats.failed = AssetService.Stats.failed + 1
		warn("[Assets] modèle " .. tostring(id) .. " indisponible : les éléments actuels sont conservés")
		return nil
	end
	local ok = pcall(function()
		AssetService.Sanitize(result)
	end)
	if not ok then
		AssetService.Stats.failed = AssetService.Stats.failed + 1
		return nil
	end
	AssetService.Stats.loaded = AssetService.Stats.loaded + 1
	return result
end

local function addSkins(container, pack)
	local found = {}
	candidates(container, 0, found)
	for _, model in ipairs(found) do
		if countParts(model) <= Config.Assets.MaxParts then
			table.insert(skins, { template = model, name = string.lower(model.Name), pack = pack })
			AssetService.Stats.skins = AssetService.Stats.skins + 1
		else
			AssetService.Stats.rejected = AssetService.Stats.rejected + 1
		end
	end
	pools = {}
end

-- Charge les packs d'animaux (appelé en tâche de fond : ne bloque jamais la partie).
function AssetService.LoadAnimals()
	if not (Config.Assets.Enabled and Config.Assets.Skins) then
		return
	end
	for _, pack in ipairs(Config.Assets.Animals) do
		local container = AssetService.Load(pack.id)
		if container then
			local ok, err = pcall(addSkins, container, pack)
			if not ok then
				warn("[Assets] pack ignoré : " .. tostring(err))
			end
		end
	end
end

local function packServes(pack, def)
	if not pack.zones then
		return true
	end
	for _, zone in ipairs(Config.Zones) do
		local inPack = false
		for _, key in ipairs(pack.zones) do
			if key == zone.key then
				inPack = true
			end
		end
		if inPack then
			if zone.boss == def.id then
				return true
			end
			for _, id in ipairs(zone.animals) do
				if id == def.id then
					return true
				end
			end
		end
	end
	return false
end

-- Modèle correspondant à une espèce (mots-clés du nom) ou nil : l'espèce garde alors son apparence dessinée.
function AssetService.Pick(def)
	if not (Config.Assets.Enabled and Config.Assets.Skins) or #skins == 0 then
		return nil
	end
	local pool = pools[def.id]
	if not pool then
		pool = {}
		local words = Config.Assets.Aliases[def.id] or { def.id }
		for _, skin in ipairs(skins) do
			if packServes(skin.pack, def) then
				for _, word in ipairs(words) do
					if string.find(skin.name, word, 1, true) then
						table.insert(pool, skin.template)
						break
					end
				end
			end
		end
		pools[def.id] = pool
	end
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function tint(root, color, amount)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = descendant.Color:Lerp(color, amount)
		end
	end
end

local function prepareParts(model, anchored)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

-- Ajuste un clone : taille cible, pieds au sol, orientation. `bottomY` = hauteur du bas du modèle, `centerXZ` = (x, z).
local function placeOnGround(clone, scale, centerX, bottomY, centerZ, yawDegrees)
	clone:ScaleTo(scale)
	if yawDegrees ~= 0 then
		clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, math.rad(yawDegrees), 0))
	end
	local boxCFrame, size = clone:GetBoundingBox()
	local wanted = Vector3.new(centerX, bottomY + size.Y / 2, centerZ)
	clone:PivotTo(clone:GetPivot() + (wanted - boxCFrame.Position))
end

-- Habille un animal : clone le modèle, le met à l'échelle de l'espèce et le soude à Root (qui reste la hitbox).
-- Renvoie true si l'habillage est en place ; en cas d'échec le modèle n'est pas modifié.
function AssetService.Dress(model, root, def, variantIdx, template)
	local clone = template:Clone()
	local ok = pcall(function()
		prepareParts(clone, false)
		local _, size = clone:GetBoundingBox()
		local longest = math.max(size.X, size.Z)
		if longest <= 0.01 or size.Y <= 0.01 then
			error("modèle sans dimension")
		end
		local length = def.body.s.Z * Config.Assets.LengthFactor
		local height = (def.rootY + def.body.s.Y / 2) * 1.35 + 1
		local scale = math.clamp(math.min(length / longest, height / size.Y), 0.005, 500)
		placeOnGround(clone, scale, 0, -def.rootY, 0, Config.Assets.Yaw)
		if variantIdx == 2 then
			tint(clone, Color3.fromRGB(110, 210, 255), 0.5)
		elseif variantIdx == 3 then
			tint(clone, Color3.fromRGB(255, 205, 60), 0.6)
		end
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end)
	if not ok then
		clone:Destroy()
		return false
	end
	clone.Name = "Skin"
	clone.Parent = model
	root.Transparency = 1
	root.CastShadow = false
	model:SetAttribute("Skinned", true)
	return true
end

-- Décors : chargés une fois, posés le long de la piste dans les zones prévues. `parent` = dossier du monde.
function AssetService.LoadDecor()
	if not (Config.Assets.Enabled and Config.Assets.Decor) then
		return
	end
	for _, item in ipairs(Config.Assets.DecorItems) do
		local container = AssetService.Load(item.id)
		if container then
			local ok = pcall(function()
				local found = {}
				candidates(container, 0, found)
				if #found == 0 and countParts(container) > 0 then
					found = { container }
				end
				for _, model in ipairs(found) do
					if countParts(model) <= Config.Assets.MaxParts then
						table.insert(decorTemplates, { template = model, item = item })
						AssetService.Stats.decor = AssetService.Stats.decor + 1
						break
					end
				end
			end)
			if not ok then
				AssetService.Stats.failed = AssetService.Stats.failed + 1
			end
		end
	end
end

function AssetService.PlaceDecor(parent)
	local placed = 0
	local folder = Instance.new("Folder")
	folder.Name = "AssetDecor"
	for _, entry in ipairs(decorTemplates) do
		for _, zoneKey in ipairs(entry.item.zones) do
			local zone = Config.zoneByKey(zoneKey)
			if zone then
				local from = math.max(zone.from, zone.start, 40)
				local to = math.min(zone.to, Config.Track.FinishZ)
				for i = 1, entry.item.count do
					local clone = entry.template:Clone()
					local ok = pcall(function()
						prepareParts(clone, true)
						local _, size = clone:GetBoundingBox()
						local scale = math.clamp(
							entry.item.height * (0.8 + rng:NextNumber() * 0.4) / math.max(size.Y, 0.01),
							0.01,
							200
						)
						local side = (i % 2 == 0) and 1 or -1
						local x = side * (Config.Track.HalfWidth + 6 + rng:NextNumber() * 14)
						local z = from + (i - 0.5) / entry.item.count * (to - from) + (rng:NextNumber() - 0.5) * 20
						placeOnGround(clone, scale, x, Config.Track.FloorTop, z, rng:NextInteger(0, 359))
					end)
					if ok then
						clone.Name = entry.item.name
						clone.Parent = folder
						placed = placed + 1
					else
						clone:Destroy()
					end
				end
			end
		end
	end
	folder.Parent = parent
	return placed
end

-- Chargement complet en tâche de fond (animaux, puis décors). Ne lève jamais d'erreur.
function AssetService.Init(parent)
	if not Config.Assets.Enabled then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			AssetService.LoadAnimals()
			AssetService.LoadDecor()
			AssetService.PlaceDecor(parent or workspace)
		end)
		if not ok then
			warn("[Assets] chargement interrompu : " .. tostring(err))
		end
	end)
end

return AssetService

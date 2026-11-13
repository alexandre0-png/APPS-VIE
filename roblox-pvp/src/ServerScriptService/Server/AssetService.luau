--!nonstrict
-- Intégration des modèles Roblox importés : apparence des armes (skins), vendeur de l'armurerie, tables du décor,
-- réserve d'armes. Chargement en arrière-plan, jamais bloquant ; tout échec = repli sur les armes et le décor actuels.
-- Aucune règle de jeu ne dépend de ces modèles (tirs, dégâts, cooldowns restent dans Weapons.luau).
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local AssetLogic = require(Shared.AssetLogic)
local AssetLoader = require(Server.AssetLoader)
local DummyService = require(Server.DummyService)

local AssetService = {}

AssetService.Skins = {} -- [weaponId] = Model modèle (jamais parenté au monde)
AssetService.Status = {} -- [nom] = "ok" | raison de l'échec / de l'écartement

function AssetService.GetSkin(weaponId)
	return AssetService.Skins[weaponId]
end

-- Choisit, parmi des noms de candidats, quel candidat sert de skin à chaque arme (pur, testé).
function AssetService.SelectSkins(names, skinKeywords)
	local picks = {}
	for weaponId, keywords in pairs(skinKeywords) do
		picks[weaponId] = AssetLogic.PickByKeywords(names, keywords)
	end
	return picks
end

local function candidatesOf(container)
	local list = container:GetChildren()
	if #list == 1 and #list[1]:GetChildren() > 1 then
		list = list[1]:GetChildren()
	end
	local out = {}
	for _, c in ipairs(list) do
		if c:IsA("Model") or c:IsA("Tool") or c:IsA("BasePart") then
			table.insert(out, c)
		end
	end
	return out
end

-- Convertit un candidat (Model / Tool / pièce) en Model autonome.
local function toModel(candidate)
	if candidate:IsA("Model") then
		return candidate:Clone()
	end
	local model = Instance.new("Model")
	if candidate:IsA("Tool") then
		for _, child in ipairs(candidate:GetChildren()) do
			child:Clone().Parent = model
		end
	else
		candidate:Clone().Parent = model
	end
	return model
end

local function opts()
	return { Timeout = Config.Assets.TimeoutSeconds, MaxParts = Config.Assets.MaxParts }
end

local function anchorAll(model, collide)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
		end
	end
end

local function addPrompt(model, text, menu)
	local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Ouvrir l'armurerie"
	pp.ObjectText = text
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp:SetAttribute("OpenMenu", menu)
	pp.Parent = host
end

local function placeVendor(map, model)
	model.Name = "Armurier"
	model:SetAttribute("Dummy", nil)
	anchorAll(model, false)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
	end
	local ff = Instance.new("ForceField") -- le vendeur ne peut jamais être blessé
	ff.Visible = false
	ff.Parent = model
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * AssetLogic.ScaleFor(size.Y, 5.6))
	model:PivotTo(CFrame.lookAt(map.VendorSpot, map.VendorSpot + Vector3.new(0, 0, -1)))
	addPrompt(model, "Armurier", "Shop")
	model.Parent = workspace:FindFirstChild("Map") or workspace
end

local function fallbackVendor(map)
	local ground = CFrame.lookAt(map.VendorSpot - Vector3.new(0, 1.4, 0), map.VendorSpot + Vector3.new(0, -1.4, -1))
	local model = DummyService.Build(ground, { Label = "Armurier", Health = 100, TorsoColor = Color3.fromRGB(150, 96, 52) })
	model.Name = "Armurier"
	model:SetAttribute("Dummy", nil)
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = model
	addPrompt(model, "Armurier", "Shop")
	model.Parent = workspace:FindFirstChild("Map") or workspace
end

local function placeTable(model, position)
	anchorAll(model, true)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * AssetLogic.ScaleFor(math.max(size.X, size.Z), Config.Assets.TableWidth))
	local _, scaled = model:GetBoundingBox()
	model:PivotTo(CFrame.new(position + Vector3.new(0, scaled.Y / 2, 0)))
	model.Parent = workspace:FindFirstChild("Map") or workspace
end

local function record(name, reason)
	AssetService.Status[name] = reason or "ok"
	if reason then
		warn(("[AssetService] %s non chargé (%s) : repli sur l'existant"):format(name, reason))
	end
end

local function loadAll(map)
	local A = Config.Assets

	-- vendeur
	local vendorContainer, why = AssetLoader.Prepare(A.Ids.Vendor, opts())
	local vendorCandidates = vendorContainer and candidatesOf(vendorContainer) or {}
	if #vendorCandidates > 0 then
		placeVendor(map, toModel(vendorCandidates[1]))
		record("Vendor")
	else
		record("Vendor", why or "modèle vide")
		fallbackVendor(map)
	end

	-- tables du décor
	for i, key in ipairs({ "WeaponTable", "SuppliesTable" }) do
		local container, reason = AssetLoader.Prepare(A.Ids[key], opts())
		local c = container and candidatesOf(container)[1]
		if c then
			placeTable(toModel(c), map.TableSpots[i])
			record(key)
		else
			record(key, reason or "modèle vide")
		end
	end

	-- pistolet
	local pistolContainer, pistolWhy = AssetLoader.Prepare(A.Ids.Pistol, opts())
	local pistolCandidate = pistolContainer and candidatesOf(pistolContainer)[1]
	if pistolCandidate then
		AssetService.Skins.pistol = toModel(pistolCandidate)
		record("Pistol")
	else
		record("Pistol", pistolWhy or "modèle vide")
	end

	-- pack d'armes : un skin par arme selon les noms
	local pack, packWhy = AssetLoader.Prepare(A.Ids.WeaponPack, opts())
	if pack then
		local list = candidatesOf(pack)
		local names = {}
		for i, c in ipairs(list) do
			names[i] = c.Name
		end
		local found = 0
		for weaponId, index in pairs(AssetService.SelectSkins(names, A.Skins)) do
			if index then
				AssetService.Skins[weaponId] = toModel(list[index])
				found += 1
			end
		end
		if found > 0 then
			record("WeaponPack")
		else
			record("WeaponPack", "aucun nom d'arme reconnu")
		end
	else
		record("WeaponPack", packWhy)
	end

	-- réserve (saisons / armes rares) : rangée dans ServerStorage, jamais envoyée aux clients
	if A.LoadReserve then
		local reserve, reserveWhy = AssetLoader.Prepare(A.Ids.Reserve, opts())
		if reserve then
			reserve.Name = "WeaponReserve"
			reserve.Parent = ServerStorage
			record("Reserve")
		else
			record("Reserve", reserveWhy)
		end
	end
end

function AssetService.Init(map)
	if not Config.Assets.Enabled then
		fallbackVendor(map)
		return
	end
	task.spawn(function()
		local ok, err = pcall(loadAll, map)
		if not ok then
			warn("[AssetService] " .. tostring(err))
		end
	end)
end

return AssetService

-- LocalScript : StarterPlayer/StarterPlayerScripts/EggAura (lot graphismes 4 : halos d'œufs et bulles de protection).
-- Applique ReplicatedStorage/EggAura (pur, testé) : chaque œuf taggé « EggAura » par Builder.egg (tapis, portés, posés, nids) reçoit, s'il est parmi les plus
-- proches de la caméra, un halo néon de la couleur de sa rareté (pulsation lente) ; un œuf protégé (attribut ShieldUntil dans le futur : bouclier de base ;
-- attribut Guarded : nid surveillé par un gardien) reçoit en plus une bulle translucide. AUCUNE PointLight (budget de LightLod : <= 4 allumées).
-- Parts locales (jamais répliquées), sans collision ni requête, dans un dossier « EggAuraFx » ; réservoir borné (EggAura.newManager) : pas de fuite.
-- Mobile : plafonds et cadences réduits (EggAura.caps). Coupé par Config.EGG_AURA.enabled = false ; une erreur le désactive proprement.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EggAura = require(Shared:WaitForChild("EggAura"))

local cfg = EggAura.cfg(Config)
if not cfg.enabled then
	return
end
local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local caps = EggAura.caps(Config, mobile)

local folder = Instance.new("Folder")
folder.Name = "EggAuraFx"
folder.Parent = workspace

local function newPart(kind)
	local p = Instance.new("Part")
	p.Name = kind == "halo" and "EggHaloFx" or "EggBubbleFx"
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Locked = true
	p.Material = kind == "halo" and Enum.Material.Neon or Enum.Material.ForceField
	p.Transparency = 1
	p.Parent = folder
	return p
end

local manager = EggAura.newManager({
	make = newPart,
	hide = function(p)
		p.Transparency = 1
		p.CFrame = CFrame.new(0, -500, 0)
	end,
	destroy = function(p)
		p:Destroy()
	end,
}, math.max(caps.halos, caps.bubbles))

local eggs = {} -- clé -> Part de l'œuf (sélection courante)
local styles = {} -- clé -> style de halo
local phases = {} -- clé -> déphasage
local keyOf = setmetatable({}, { __mode = "k" }) -- Part d'œuf -> clé stable
local nextKey = 0

local function stableKey(egg)
	local k = keyOf[egg]
	if not k then
		nextKey = nextKey + 1
		k = nextKey
		keyOf[egg] = k
	end
	return k
end

local function protectOf(egg)
	if egg:GetAttribute("Guarded") == true then
		return "guard"
	end
	local untilT = egg:GetAttribute("ShieldUntil")
	if type(untilT) == "number" and untilT > workspace:GetServerTimeNow() then
		return "shield"
	end
	return nil
end

local function reselect()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local items, byKey = {}, {}
	for _, egg in ipairs(CollectionService:GetTagged("EggAura")) do
		if egg:IsA("BasePart") and egg.Name ~= "FlyEgg" and egg:IsDescendantOf(workspace) then
			local tier = egg:GetAttribute("Tier")
			if type(tier) == "number" then
				local key = stableKey(egg)
				local pos = egg.Position
				items[#items + 1] = { key = key, x = pos.X, y = pos.Y, z = pos.Z, tier = tier, protect = protectOf(egg) }
				byKey[key] = egg
			end
		end
	end
	local sel = EggAura.select(items, { x = cp.X, y = cp.Y, z = cp.Z }, caps)
	eggs = byKey
	for _, it in ipairs(sel.halos) do
		if not styles[it.key] or styles[it.key].tier ~= it.tier then
			styles[it.key] = EggAura.halo(Config, it.tier)
			phases[it.key] = (it.key * 1.7) % (2 * math.pi)
		end
	end
	local live = manager.sync(sel)
	for key in pairs(styles) do
		if not live.halo[key] then
			styles[key], phases[key] = nil, nil
		end
	end
	for _, it in ipairs(sel.bubbles) do
		local b = live.bubble[it.key]
		local st = EggAura.bubble(Config, it.protect)
		if b then
			b.Color = Color3.fromRGB(st.color[1], st.color[2], st.color[3])
			b.Transparency = st.transparency
		end
	end
	for key, h in pairs(live.halo) do
		local st = styles[key]
		if st and st.color then
			h.Color = st.color
		end
	end
end

local function place(t)
	local live = manager.live
	for key, h in pairs(live.halo) do
		local egg, st = eggs[key], styles[key]
		if egg and egg.Parent and st then
			local s = egg.Size
			local d = EggAura.diameter(Config, st.tier, math.max(s.X, s.Y, s.Z), "halo")
			h.Size = Vector3.new(d, d, d)
			h.CFrame = egg.CFrame
			h.Transparency = EggAura.alpha(st, t, phases[key])
		else
			h.Transparency = 1
		end
	end
	for key, b in pairs(live.bubble) do
		local egg = eggs[key]
		if egg and egg.Parent then
			local s = egg.Size
			local d = EggAura.diameter(Config, egg:GetAttribute("Tier"), math.max(s.X, s.Y, s.Z), "bubble")
			b.Size = Vector3.new(d, d, d)
			b.CFrame = egg.CFrame
		else
			b.Transparency = 1
		end
	end
end

local lastSel, lastFrame = -math.huge, -math.huge
local conn
conn = RunService.RenderStepped:Connect(function()
	local ok, err = pcall(function()
		local now = os.clock()
		if now - lastSel >= caps.interval then
			lastSel = now
			reselect()
		end
		if now - lastFrame >= caps.frameStep then
			lastFrame = now
			place(now)
		end
	end)
	if not ok then
		warn("[EggAura] désactivé : " .. tostring(err))
		conn:Disconnect()
		manager.clear()
		folder:Destroy()
	end
end)

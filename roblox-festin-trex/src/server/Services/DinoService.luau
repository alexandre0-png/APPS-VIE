--!nonstrict
-- Le T-Rex central : construction du modèle (blocs Roblox), satiété, favori, festin et croissance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))
local DinoCore = require(Shared:WaitForChild("DinoCore"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimLogic = require(Shared:WaitForChild("AnimLogic"))
local AssetLogic = require(Shared:WaitForChild("AssetLogic"))
local AssetService = require(script.Parent.AssetService)

local PlayerService = require(script.Parent.PlayerService)

local DinoService = {}

local core = DinoCore.new()
local model: Model
local mouthZone: BasePart
local hitParts: { Instance } = {}
-- Animation : chaque pièce mobile mémorise sa position/rotation à l'échelle 1 et son groupe.
local animated: { { part: BasePart, pos: Vector3, rot: CFrame, group: string } } = {}
local pupils: { BasePart } = {}
local eyes: { BasePart } = {}
local HINGE = Vector3.new(0, 20, 13.5)
local HEAD_PIVOT = Vector3.new(0, 18, 4)
local TAIL_PIVOTS = { Vector3.new(0, 13, -8), Vector3.new(0, 12.5, -18), Vector3.new(0, 12, -27) }
local SHOULDER_L = Vector3.new(5.9, 16.5, 6)
local SHOULDER_R = Vector3.new(-5.9, 16.5, 6)
local roarStart = -10
local aimTarget: Vector3? = nil
local aimUntil = 0
local aimYaw = 0
local reaction = 0
-- Apparence alternative (modèle externe validé) : null = T-Rex intégré.
local skin: { model: Model, basePos: Vector3, baseRot: CFrame, jaw: BasePart?, jawRelPos: Vector3?, jawRelRot: CFrame? }? = nil
local favorite = "pomme"
local state: Instance
local chompStart = -10
local feastBusy = false
local currentScale = 1

local function setAttr(name: string, value: any)
	if state:GetAttribute(name) ~= value then
		state:SetAttribute(name, value)
	end
end

-- ---------------------------------------------------------------- construction

local function addPart(name: string, size: Vector3, pos: Vector3, color: Color3, opts: any?): Part
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CFrame = CFrame.new(pos) * (opts.rot or CFrame.new())
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = opts.collide ~= false
	p.CanQuery = opts.query == true
	p.CanTouch = false
	p.CastShadow = opts.shadow ~= false
	if opts.hidden then
		p.Transparency = 1
	end
	p.Parent = model
	return p
end

local function buildModel()
	model = Instance.new("Model")
	model.Name = "Dino"

	local green = Color3.fromRGB(88, 170, 80)
	local darkGreen = Color3.fromRGB(66, 138, 62)
	local belly = Color3.fromRGB(240, 230, 150)
	local orange = Color3.fromRGB(255, 150, 60)
	local white = Color3.fromRGB(250, 250, 250)

	local root = addPart("Root", Vector3.new(1, 1, 1), Vector3.new(0, 0, 0), green, { hidden = true, collide = false, shadow = false })
	model.PrimaryPart = root

	addPart("LegL", Vector3.new(4, 10, 5.5), Vector3.new(3.8, 5, 0), darkGreen)
	addPart("LegR", Vector3.new(4, 10, 5.5), Vector3.new(-3.8, 5, 0), darkGreen)
	addPart("FootL", Vector3.new(4.4, 1.6, 8), Vector3.new(3.8, 0.8, 1.5), darkGreen)
	addPart("FootR", Vector3.new(4.4, 1.6, 8), Vector3.new(-3.8, 0.8, 1.5), darkGreen)
	addPart("Body", Vector3.new(11, 10, 17), Vector3.new(0, 15, -1.5), green)
	addPart("Belly", Vector3.new(11.2, 4, 15), Vector3.new(0, 11.2, -0.5), belly)
	addPart("Tail1", Vector3.new(6.5, 6.5, 10), Vector3.new(0, 13.5, -13), green)
	addPart("Tail2", Vector3.new(4.5, 4.5, 10), Vector3.new(0, 12.5, -22), green)
	addPart("Tail3", Vector3.new(2.8, 2.8, 9), Vector3.new(0, 12, -30.5), green)
	addPart("Head", Vector3.new(9, 8.5, 9), Vector3.new(0, 21.5, 8.5), green)
	addPart("Snout", Vector3.new(7.5, 3.2, 8.5), Vector3.new(0, 22.6, 17.75), Color3.fromRGB(100, 185, 90))
	addPart("MouthInside", Vector3.new(6, 1.2, 7), Vector3.new(0, 21, 17.3), Color3.fromRGB(160, 40, 50), { collide = false })
	addPart("ArmL", Vector3.new(1.8, 1.8, 4.5), Vector3.new(5.9, 16.5, 8), green)
	addPart("ArmR", Vector3.new(1.8, 1.8, 4.5), Vector3.new(-5.9, 16.5, 8), green)

	-- Yeux
	for _, side in ipairs({ 1, -1 }) do
		addPart("Eye", Vector3.new(0.8, 2.4, 2.4), Vector3.new(4.55 * side, 24, 10.5), white, { collide = false })
		addPart("Pupil", Vector3.new(0.5, 1.3, 1.3), Vector3.new(4.9 * side, 24, 10.9), Color3.fromRGB(20, 20, 20), { collide = false })
	end

	-- Dents du haut
	for _, x in ipairs({ -2.5, -0.85, 0.85, 2.5 }) do
		addPart("Tooth", Vector3.new(0.9, 1.3, 0.9), Vector3.new(x, 20.4, 21.4), white, { collide = false })
	end
	for _, side in ipairs({ 1, -1 }) do
		for _, z in ipairs({ 16.5, 19 }) do
			addPart("Tooth", Vector3.new(0.9, 1.1, 0.9), Vector3.new(3.4 * side, 20.5, z), white, { collide = false })
		end
	end

	-- Piques dorsaux
	local spikes = { { -7, 21.2 }, { -3, 21.2 }, { 1, 21.2 }, { -13, 17.6 }, { -22, 15.4 } }
	for _, s in ipairs(spikes) do
		addPart("Spike", Vector3.new(2, 2.6, 2), Vector3.new(0, s[2], s[1]), orange, { rot = CFrame.Angles(0, math.rad(45), 0), collide = false })
	end

	-- Mâchoire (animée) : mâchoire, langue, dents du bas.
	local function jaw(name: string, size: Vector3, pos: Vector3, color: Color3)
		addPart(name, size, pos, color, { collide = false })
	end
	jaw("LowerJaw", Vector3.new(7, 2.2, 8), Vector3.new(0, 19.9, 17.5), Color3.fromRGB(100, 185, 90))
	jaw("Tongue", Vector3.new(4, 0.6, 6), Vector3.new(0, 21.1, 17), Color3.fromRGB(240, 110, 130))
	for _, x in ipairs({ -2.2, -0.75, 0.75, 2.2 }) do
		jaw("LowerTooth", Vector3.new(0.8, 1.1, 0.8), Vector3.new(x, 21.4, 21.3), white)
	end

	-- Hitbox invisibles (seules parties interrogeables par les lancers).
	mouthZone = addPart("MouthZone", Vector3.new(9, 6.5, 9), Vector3.new(0, 21.2, 17.8), white, { hidden = true, collide = false, query = true, shadow = false })
	local head = addPart("HeadHit", Vector3.new(9, 8.5, 9), Vector3.new(0, 21.5, 8.5), white, { hidden = true, collide = false, query = true, shadow = false })
	local body = addPart("BodyHit", Vector3.new(11, 20, 25), Vector3.new(0, 10, -5), white, { hidden = true, collide = false, query = true, shadow = false })
	hitParts = { mouthZone, head, body }

	-- Affectation des groupes d'animation (positions à l'échelle 1, avant ScaleTo).
	for _, p in ipairs(model:GetChildren()) do
		local group = nil
		local n = p.Name
		if n == "Head" or n == "Snout" or n == "MouthInside" or n == "Eye" or n == "Pupil" or n == "Tooth" then
			group = "head"
		elseif n == "LowerJaw" or n == "Tongue" or n == "LowerTooth" then
			group = "jaw"
		elseif n == "Tail1" then
			group = "t1"
		elseif n == "Tail2" then
			group = "t2"
		elseif n == "Tail3" then
			group = "t3"
		elseif n == "LegL" or n == "FootL" then
			group = "legL"
		elseif n == "LegR" or n == "FootR" then
			group = "legR"
		elseif n == "ArmL" then
			group = "armL"
		elseif n == "ArmR" then
			group = "armR"
		elseif n == "Spike" then
			local z = p.Position.Z
			group = if z < -20 then "t2" elseif z < -10 then "t1" else nil
		end
		if group then
			table.insert(animated, { part = p, pos = p.Position, rot = p.CFrame.Rotation, group = group })
		end
		if n == "Pupil" then
			table.insert(pupils, p)
		elseif n == "Eye" then
			table.insert(eyes, p)
		end
	end

	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = workspace
	model:ScaleTo(Config.Dino.Stages[1].Scale)
	currentScale = Config.Dino.Stages[1].Scale
end

-- ---------------------------------------------------------------- apparence alternative

-- Remplace le visuel du T-Rex par un modèle externe SI et seulement si la validation passe (mâchoire reconnaissable,
-- limites). Hitbox, satiété, festin et animations (mâchoire, rugissement, marche, tête) restent ceux du jeu.
local function trySkin()
	local key, id = AssetLogic.pickDinoSkin(Config.Assets)
	if not key then
		return
	end
	local loaded = AssetService.fetch(id)
	if not loaded then
		return -- chargement impossible : modèle intégré conservé
	end
	local ok, err = pcall(function()
		local names, parts = {}, {}
		for _, d in ipairs(loaded:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				table.insert(names, d.Name)
			end
		end
		local jawIndex = AssetLogic.findJawIndex(names)
		local valid, reason = AssetLogic.validateDino({ partCount = #parts, hasJaw = jawIndex ~= nil }, Config.Assets.Dino)
		if not valid then
			error(reason)
		end
		for _, p in ipairs(parts) do
			p.CanCollide = false -- les collisions et lancers restent gérés par le T-Rex intégré (hitbox invisibles)
			p.CanQuery = false
		end
		-- Mise à l'échelle et orientation (à l'échelle actuelle du T-Rex), pieds au sol.
		local _, size = loaded:GetBoundingBox()
		local fit = AssetLogic.fitScale(size.Y, Config.Assets.Dino.TargetHeight * currentScale, 0.02, 200)
		loaded:ScaleTo(fit)
		local cf, newSize = loaded:GetBoundingBox()
		local off = Config.Assets.Dino.Offset
		local rel = cf:ToObjectSpace(loaded:GetPivot())
		local yaw = CFrame.Angles(0, math.rad(Config.Assets.Dino.FacingYaw), 0)
		loaded:PivotTo(CFrame.new(off[1] * currentScale, newSize.Y / 2, off[3] * currentScale) * yaw * rel)
		loaded.Parent = model

		local pivot = loaded:GetPivot()
		local jaw = if jawIndex then parts[jawIndex] else nil
		local entry = {
			model = loaded,
			basePos = pivot.Position / currentScale,
			baseRot = pivot.Rotation,
			jaw = jaw,
			jawRelPos = nil,
			jawRelRot = nil,
		}
		if jaw then
			local jr = pivot:ToObjectSpace(jaw.CFrame)
			entry.jawRelPos = jr.Position / currentScale
			entry.jawRelRot = jr.Rotation
		end
		-- Le visuel intégré devient invisible (les parties animées et hitbox restent en place).
		for _, a in ipairs(model:GetChildren()) do
			if a:IsA("BasePart") and a.Name ~= "MouthZone" and a.Name ~= "HeadHit" and a.Name ~= "BodyHit" and a.Name ~= "Root" then
				a.Transparency = 1
			end
		end
		skin = entry
	end)
	if not ok then
		warn("[FestinTRex] Apparence « " .. key .. " » non appliquée : " .. tostring(err))
		pcall(function()
			loaded:Destroy()
		end)
	end
end

-- ---------------------------------------------------------------- état public

local function publish()
	local stage = Config.Dino.Stages[core.stage]
	setAttr("Satiety", math.floor(core.satiety))
	setAttr("Need", stage.Need)
	setAttr("Stage", core.stage)
	setAttr("StageName", stage.Name)
	setAttr("Favorite", favorite)
	setAttr("Hungry", core:isHungry())
	setAttr("Feasts", core.feasts)
end

local function pickFavorite()
	local items = {}
	for _, f in ipairs(Config.Foods) do
		if f.Id ~= favorite then
			table.insert(items, { id = f.Id, weight = f.Weight })
		end
	end
	favorite = Util.weightedPick(items, math.random())
end

-- ---------------------------------------------------------------- API

function DinoService.getFavorite(): string
	return favorite
end

function DinoService.isHungry(): boolean
	return core:isHungry()
end

function DinoService.getStage(): number
	return core.stage
end

function DinoService.getMouthPosition(): Vector3
	return mouthZone.Position
end

-- Instances interrogeables par les lancers : hitbox du dino + carte (ajoutée par init).
local rayTargets: { Instance } = {}
function DinoService.getRayTargets(): { Instance }
	return rayTargets
end

-- Fait regarder la tête vers un point (le lanceur) pendant ~2,5 s.
function DinoService.lookAt(pos: Vector3)
	aimTarget = pos
	aimUntil = os.clock() + 2.5
end

function DinoService.roar()
	roarStart = os.clock()
end

function DinoService.chomp()
	chompStart = os.clock()
end

local function growTo(newScale: number)
	local from = currentScale
	local steps = 40
	for i = 1, steps do
		local alpha = i / steps
		local eased = alpha * alpha * (3 - 2 * alpha)
		currentScale = from + (newScale - from) * eased
		model:ScaleTo(currentScale)
		task.wait(1 / 30)
	end
end

local function runFeast()
	if feastBusy then
		return
	end
	feastBusy = true
	DinoService.roar()
	local contrib, total, finishedStage = core:completeFeast()
	local stageName = Config.Dino.Stages[finishedStage].Name

	-- Meilleur contributeur
	local topId, topValue = 0, -1
	for userId, v in pairs(contrib) do
		if v > topValue then
			topId, topValue = userId, v
		end
	end

	local topName = ""
	for userId, value in pairs(contrib) do
		local player = Players:GetPlayerByUserId(userId)
		if player and PlayerService.get(player) then
			local data = PlayerService.get(player)
			local share = value / math.max(total, 1)
			local coins = Economy.feastCoins(finishedStage, share, data.rebirths)
			PlayerService.addCoins(player, coins)
			PlayerService.record(player, "feast", 1)
			data.stats.feasts += 1
			local eggText = ""
			if userId == topId or (share >= Config.Feast.MinShareForEgg and math.random() < Config.Feast.EggChance) then
				PlayerService.addEggs(player, 1)
				eggText = " + 1 œuf 🥚"
			end
			if userId == topId then
				topName = player.DisplayName
			end
			PlayerService.notify(player, string.format("Festin ! +%s pièces%s", Util.formatNumber(coins), eggText), "gold")
			PlayerService.markDirty(player)
		end
	end

	Remotes.get("FeastFx"):FireAllClients(stageName, topName)
	pickFavorite()
	publish()

	if core.stage > finishedStage then
		local chapter = Config.Story[core.stage]
		if chapter then
			for _, p in ipairs(Players:GetPlayers()) do
				PlayerService.notify(p, "📖 " .. chapter, "info")
			end
		end
	end
	local newScale = Config.Dino.Stages[core.stage].Scale
	if math.abs(newScale - currentScale) > 0.001 then
		task.wait(1.2)
		growTo(newScale)
	end
	feastBusy = false
	publish()
end

-- Appelé par FoodService quand un aliment entre dans la bouche. Retourne true si festin déclenché.
function DinoService.feed(userId: number, satiety: number): boolean
	if feastBusy then
		return false
	end
	local reached = core:add(userId, satiety)
	publish()
	if reached then
		task.spawn(runFeast)
	end
	return reached
end

function DinoService.init(mapFolder: Instance)
	state = ReplicatedStorage:FindFirstChild("GameState")
	if not state then
		state = Instance.new("Configuration")
		state.Name = "GameState"
		state.Parent = ReplicatedStorage
	end
	buildModel()
	rayTargets = { mapFolder, mouthZone, hitParts[2], hitParts[3] }
	pickFavorite()
	publish()
	task.spawn(trySkin)

	-- Décroissance de la satiété.
	task.spawn(function()
		local step = 0.25
		while true do
			task.wait(step)
			if not feastBusy then
				core:decay(step)
				publish()
			end
		end
	end)

	-- Changement de plat préféré régulier.
	task.spawn(function()
		while true do
			task.wait(Config.Dino.FavoriteEvery)
			if not feastBusy then
				pickFavorite()
				publish()
			end
		end
	end)

	-- Animation (~20 Hz) : respiration, tête, mâchoire, queue en chaîne, bras, clignement, rugissement.
	local function around(pivot: Vector3, rot: CFrame, s: number): CFrame
		return CFrame.new(pivot * s) * rot * CFrame.new(-pivot * s)
	end
	local acc = 0
	local blinking = false
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local t = os.clock()
		local s = currentScale
		local since = t - chompStart
		local chompOpen = if since < 0.4 then 0.05 + 0.5 * math.sin((since / 0.4) * math.pi) else 0
		local rs = t - roarStart
		local roar = if rs < 1.8 then math.sin(math.pi * rs / 1.8) else 0
		local breathe = math.sin(t * 1.4)
		local open = 0.12 + 0.08 * math.sin(t * 1.6) + chompOpen + 0.8 * roar

		-- Cible de réaction : sauce active = sursaut, frénésie = danse joyeuse.
		local targetReaction = 0
		AnimLogic.run(Config.Animations, "DinoReact", function()
			local id, phase = state:GetAttribute("EventId"), state:GetAttribute("EventPhase")
			if id == "sauce" and (phase == "warning" or phase == "active") then
				targetReaction = 1
			elseif id == "frenzy" and phase == "active" then
				targetReaction = 0.6
			end
		end)
		reaction += (targetReaction - reaction) * 0.2

		-- Tête tournée vers le dernier lanceur (lissée).
		local targetYaw = 0
		AnimLogic.run(Config.Animations, "DinoHeadAim", function()
			if aimTarget and t < aimUntil then
				targetYaw = AnimLogic.aimYaw(0, 0, aimTarget.X, aimTarget.Z, 0.35)
			end
		end)
		aimYaw += (targetYaw - aimYaw) * 0.25

		local headM = CFrame.new(0, 0.25 * breathe * s, 0) * around(HEAD_PIVOT, CFrame.Angles(0.03 * breathe - 0.38 * roar - 0.2 * reaction, aimYaw, 0), s)

		-- Cycle de marche sur place : les pattes se lèvent en alternance.
		local liftL, liftR = 0, 0
		AnimLogic.run(Config.Animations, "DinoWalk", function()
			local amp = 0.2 + 1.2 * roar + 0.9 * reaction
			local speed = 4 + 5 * math.max(roar, reaction)
			liftL = AnimLogic.stompLift(t, amp, speed, 0)
			liftR = AnimLogic.stompLift(t, amp, speed, math.pi)
		end)
		local m1 = around(TAIL_PIVOTS[1], CFrame.Angles(0, 0.08 * math.sin(t * 1.8), 0), s)
		local m2 = m1 * around(TAIL_PIVOTS[2], CFrame.Angles(0, 0.14 * math.sin(t * 1.8 - 0.6), 0), s)
		local m3 = m2 * around(TAIL_PIVOTS[3], CFrame.Angles(0, 0.2 * math.sin(t * 1.8 - 1.2), 0), s)
		local groups = {
			head = headM,
			jaw = headM * around(HINGE, CFrame.Angles(open, 0, 0), s),
			t1 = m1,
			t2 = m2,
			t3 = m3,
			legL = CFrame.new(0, liftL * s, 0),
			legR = CFrame.new(0, liftR * s, 0),
			armL = around(SHOULDER_L, CFrame.Angles(0.2 * math.sin(t * 2), 0, 0), s),
			armR = around(SHOULDER_R, CFrame.Angles(0.2 * math.sin(t * 2 + 1), 0, 0), s),
		}
		for _, a in ipairs(animated) do
			a.part.CFrame = groups[a.group] * (CFrame.new(a.pos * s) * a.rot)
		end

		-- Apparence alternative : respiration, saut de marche, cap de la tête, rugissement ; mâchoire par charnière.
		if skin then
			local sk = skin
			local okSkin = pcall(function()
				local lift = (liftL + liftR) / 2
				local world = CFrame.new(sk.basePos * s + Vector3.new(0, (0.25 * breathe + lift) * s, 0))
					* CFrame.Angles(-0.12 * roar - 0.08 * reaction, aimYaw * 0.6, 0)
					* sk.baseRot
				sk.model:PivotTo(world)
				if sk.jaw and sk.jawRelPos and sk.jawRelRot then
					local jawCF = world * CFrame.new(sk.jawRelPos * s) * sk.jawRelRot
					local h = Vector3.new(0, sk.jaw.Size.Y / 2, -sk.jaw.Size.Z / 2)
					sk.jaw.CFrame = jawCF * CFrame.new(h) * CFrame.Angles(open * Config.Assets.Dino.JawSign, 0, 0) * CFrame.new(-h)
				end
			end)
			if not okSkin then
				skin = nil -- en cas d'erreur d'animation, on revient au T-Rex intégré
				pcall(function()
					sk.model:Destroy()
				end)
				for _, a in ipairs(model:GetChildren()) do
					if a:IsA("BasePart") and a.Name ~= "MouthZone" and a.Name ~= "HeadHit" and a.Name ~= "BodyHit" and a.Name ~= "Root" then
						a.Transparency = 0
					end
				end
			end
		end

		-- Clignement toutes les ~4,3 s.
		local shouldBlink = (t % 4.3) < 0.12
		if shouldBlink ~= blinking and not skin then
			blinking = shouldBlink
			for _, p in ipairs(pupils) do
				p.Transparency = if blinking then 1 else 0
			end
			for _, e in ipairs(eyes) do
				e.Color = if blinking then Color3.fromRGB(88, 170, 80) else Color3.fromRGB(250, 250, 250)
			end
		end
	end)
end

return DinoService

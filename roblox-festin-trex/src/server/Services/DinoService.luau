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

local PlayerService = require(script.Parent.PlayerService)

local DinoService = {}

local core = DinoCore.new()
local model: Model
local mouthZone: BasePart
local hitParts: { Instance } = {}
local jawParts: { { part: BasePart, offset: Vector3 } } = {}
local HINGE = Vector3.new(0, 20, 13.5)
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

local function c3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
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
		local p = addPart(name, size, pos, color, { collide = false })
		table.insert(jawParts, { part = p, offset = pos - HINGE })
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

	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = workspace
	model:ScaleTo(Config.Dino.Stages[1].Scale)
	currentScale = Config.Dino.Stages[1].Scale
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

	-- Animation de la mâchoire (~20 Hz).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local t = os.clock()
		local open
		local since = t - chompStart
		if since < 0.4 then
			open = 0.05 + 0.5 * math.sin((since / 0.4) * math.pi)
		else
			open = 0.12 + 0.08 * math.sin(t * 1.6)
		end
		local s = currentScale
		local pivot = CFrame.new(HINGE * s) * CFrame.Angles(open, 0, 0)
		for _, j in ipairs(jawParts) do
			j.part.CFrame = pivot * CFrame.new(j.offset * s)
		end
	end)
end

return DinoService

--!nonstrict
-- Lancers de nourriture : validation serveur complète, simulation balistique, récompenses.
-- Le client n'envoie QUE la position visée ; origine, portée, cadence, munitions et résultat
-- sont décidés ici. Le trajet est simulé en une fois (raycasts), puis rejoué visuellement par les clients.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerService = require(script.Parent.PlayerService)
local DinoService = require(script.Parent.DinoService)
local EventService = require(script.Parent.EventService)

local FoodService = {}

local ThrowFx: any
local FeedFx: any

local MAX_FLIGHTS_PER_PLAYER = 4
local THROW_BUCKET_MAX = 8 -- anti-spam du RemoteEvent (en plus de la cadence)

local function isFiniteVector(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local lim = 1e5
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < lim and math.abs(v.Y) < lim and math.abs(v.Z) < lim
end

-- Anti-spam : seau à jetons par joueur.
local function allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local s = PlayerService.session(player)
	if not s then
		return false
	end
	local bucket = s.rate[key]
	local now = os.clock()
	if not bucket then
		bucket = { tokens = burst, t = now }
		s.rate[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.t) * perSecond)
	bucket.t = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end
FoodService.allow = allow

-- ---------------------------------------------------------------- nourriture en main

local function c3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function refreshHeldFood(player: Player)
	local char = player.Character
	local data, s = PlayerService.get(player), PlayerService.session(player)
	if not char or not data or not s then
		return
	end
	local old = char:FindFirstChild("HeldFood")
	if old then
		old:Destroy()
	end
	if s.ammo <= 0 then
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local food = Economy.findFood(data.selectedFood)
	if not hand or not food then
		return
	end
	local p = Instance.new("Part")
	p.Name = "HeldFood"
	p.Shape = Enum.PartType[food.Shape]
	p.Size = Vector3.new(food.Size[1], food.Size[2], food.Size[3])
	p.Color = c3(food.Color)
	p.Material = Enum.Material[food.Material]
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = hand.CFrame * CFrame.new(0, -1, -0.8)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = p
	weld.Parent = p
	p.Parent = char
end
FoodService.refreshHeldFood = refreshHeldFood

-- ---------------------------------------------------------------- simulation

local function simulate(origin: Vector3, v: Vector3, T: number, g: number): (string, Vector3, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = DinoService.getRayTargets()

	local dt = 1 / Config.Throw.StepsPerSecond
	local maxT = T + Config.Throw.TrailTime
	local prev = origin
	local t = 0
	while t < maxT do
		t += dt
		local x, y, z = Ballistics.position(origin.X, origin.Y, origin.Z, v.X, v.Y, v.Z, t, g)
		local pos = Vector3.new(x, y, z)
		local result = workspace:Raycast(prev, pos - prev, params)
		if result then
			local name = result.Instance.Name
			local kind = "ground"
			if name == "MouthZone" then
				kind = "mouth"
			elseif name == "HeadHit" or name == "BodyHit" then
				kind = "body"
			end
			local frac = (result.Position - prev).Magnitude / math.max((pos - prev).Magnitude, 1e-4)
			return kind, result.Position, math.max(0.05, t - dt + dt * frac)
		end
		prev = pos
	end
	return "none", prev, maxT
end

-- ---------------------------------------------------------------- résolution

local function resolveHit(player: Player, foodId: string, kind: string, hitPos: Vector3)
	local data, s = PlayerService.get(player), PlayerService.session(player)
	if not data or not s then
		return
	end
	s.flights = math.max(0, (s.flights or 1) - 1)

	if kind ~= "mouth" then
		if s.combo > 1 then
			PlayerService.notify(player, "Combo perdu !", "bad")
		end
		s.combo = 0
		if kind == "body" then
			FeedFx:FireAllClients(hitPos, 0, player.UserId, "thud", 0)
		end
		return
	end

	local food = Economy.findFood(foodId)
	if not food then
		return
	end
	local now = os.clock()
	if now - s.lastHit <= Config.Combo.Window then
		s.combo += 1
	else
		s.combo = 1
	end
	s.lastHit = now

	local isFav = DinoService.getFavorite() == food.Id
	local hungry = DinoService.isHungry()
	local stats = Economy.stats(data)
	local coins = Economy.hitReward(food.Value, s.combo, isFav, hungry, EventService.getCoinMult(), stats.coinMult)

	PlayerService.addCoins(player, coins)
	PlayerService.addFed(player, 1)
	PlayerService.record(player, "feed", 1)
	PlayerService.record(player, "combo", s.combo)
	if isFav then
		PlayerService.record(player, "fav", 1)
	end
	if s.combo > data.stats.bestCombo then
		data.stats.bestCombo = s.combo
	end

	DinoService.chomp()
	FeedFx:FireAllClients(hitPos, coins, player.UserId, if isFav then "fav" else "ok", s.combo)
	DinoService.feed(player.UserId, food.Value * (if isFav then 2 else 1))
end

-- ---------------------------------------------------------------- lancer

local function onThrow(player: Player, aim: any)
	if not allow(player, "throw", 12, THROW_BUCKET_MAX) then
		return
	end
	if not isFiniteVector(aim) then
		return
	end
	local data, s = PlayerService.get(player), PlayerService.session(player)
	if not data or not s or not s.loaded then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if hrp.Position.Magnitude > Config.Throw.MaxArenaRadius then
		return
	end

	local stats = Economy.stats(data)
	local now = os.clock()
	if now - s.lastThrow < stats.cooldown * Config.Throw.CooldownTolerance then
		return
	end
	if (s.flights or 0) >= MAX_FLIGHTS_PER_PLAYER then
		return
	end
	if s.ammo <= 0 then
		if now - (s.lastEmptyNotice or -10) > 3 then
			s.lastEmptyNotice = now
			PlayerService.notify(player, "Panier vide ! Va chercher de la nourriture aux stands 🧺", "bad")
		end
		return
	end

	s.lastThrow = now
	s.ammo -= 1
	s.flights = (s.flights or 0) + 1
	local foodId = data.selectedFood
	local food = Economy.findFood(foodId)
	if not food then
		s.flights -= 1
		return
	end

	-- Origine calculée par le serveur.
	local flat = Vector3.new(aim.X - hrp.Position.X, 0, aim.Z - hrp.Position.Z)
	local dirFlat = if flat.Magnitude > 0.01 then flat.Unit else hrp.CFrame.LookVector
	local origin = hrp.Position + Vector3.new(0, 1.6, 0) + dirFlat * 1.8

	-- Portée maximale imposée par les améliorations.
	local offset = aim - origin
	if offset.Magnitude > stats.range then
		aim = origin + offset.Unit * stats.range
	end
	-- Assistance de visée : si le point visé est proche de la bouche, on vise le centre.
	local mouth = DinoService.getMouthPosition()
	if (aim - mouth).Magnitude <= stats.assist and (origin - mouth).Magnitude <= stats.range then
		aim = mouth
	end

	local g = workspace.Gravity
	local distance = (aim - origin).Magnitude
	local T = Ballistics.flightTime(distance, Config.Throw.Speed, Config.Throw.MinFlight, Config.Throw.MaxFlight)
	local vx, vy, vz = Ballistics.launchVelocity(origin.X, origin.Y, origin.Z, aim.X, aim.Y, aim.Z, T, g)
	local v = Vector3.new(vx, vy, vz)

	local kind, hitPos, tHit = simulate(origin, v, T, g)
	DinoService.lookAt(origin)

	ThrowFx:FireAllClients(player.UserId, foodId, origin, v, tHit, kind, hitPos)
	refreshHeldFood(player)
	PlayerService.markDirty(player)

	task.delay(tHit, function()
		if player.Parent then
			resolveHit(player, foodId, kind, hitPos)
		end
	end)
end

-- ---------------------------------------------------------------- stands

local function onStandTriggered(prompt: ProximityPrompt, player: Player)
	if not allow(player, "stand", 3, 3) then
		return
	end
	local data = PlayerService.get(player)
	if not data then
		return
	end
	local foodId = prompt:GetAttribute("FoodId")
	local food = type(foodId) == "string" and Economy.findFood(foodId)
	if not food then
		return
	end
	if not data.foods[food.Id] then
		PlayerService.notify(player, string.format("%s %s verrouillé : débloque-le à la boutique (%s 🪙)", food.Emoji, food.Name, Util.formatNumber(food.Price)), "bad")
		return
	end
	PlayerService.refillBasket(player, food.Id)
	refreshHeldFood(player)
	PlayerService.notify(player, string.format("%s %s : panier rempli !", food.Emoji, food.Name), "good")
end

local function bindStand(prompt: Instance)
	if prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			onStandTriggered(prompt, player)
		end)
	end
end

function FoodService.init()
	ThrowFx = Remotes.get("ThrowFx")
	FeedFx = Remotes.get("FeedFx")
	Remotes.get("Throw").OnServerEvent:Connect(onThrow)

	CollectionService:GetInstanceAddedSignal("FoodStand"):Connect(bindStand)
	for _, inst in ipairs(CollectionService:GetTagged("FoodStand")) do
		bindStand(inst)
	end

	-- Rechargement du panier au réapparition + nourriture en main.
	PlayerService.onCharacter(function(player)
		local s = PlayerService.session(player)
		if s then
			PlayerService.refillBasket(player)
		end
		task.wait(0.5)
		refreshHeldFood(player)
	end)
end

return FoodService

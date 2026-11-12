--!nonstrict
-- Bots d'arène : gladiateurs-mannequins qui poursuivent et frappent les joueurs.
-- Maintenus uniquement quand il y a peu de joueurs ; actifs seulement pendant une manche.
-- Mouvement par déplacement du modèle (ancré), avec détection de murs et de vide/lave.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local BotLogic = require(Shared.BotLogic)
local MatchLogic = require(Shared.MatchLogic)
local CombatService = require(Server.CombatService)
local DummyService = require(Server.DummyService)

local BotService = {}

local map
local bots = {}
local rng = Random.new()
local nameCounter = 0
local accumulator = 0

local function humansInArena()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InArena") then
			table.insert(list, p)
		end
	end
	return list
end

local function removeBot(bot)
	for i, b in ipairs(bots) do
		if b == bot then
			table.remove(bots, i)
			break
		end
	end
end

local function spawnBot(humans)
	local points, enemies = {}, {}
	for i, sp in ipairs(map.ArenaSpawns) do
		points[i] = { X = sp.Position.X, Z = sp.Position.Z }
	end
	for _, p in ipairs(humans) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(enemies, { X = root.Position.X, Z = root.Position.Z })
		end
	end
	local sp = map.ArenaSpawns[math.max(1, MatchLogic.PickSpawn(points, enemies, rng:NextNumber()))]
	local B = Config.Bots
	nameCounter += 1
	local name = ("%s %d"):format(B.Names[(nameCounter - 1) % #B.Names + 1], nameCounter)
	local ground = CFrame.new(sp.Position.X, 0, sp.Position.Z)
	local model, humanoid = DummyService.Build(ground, {
		Label = "🤖 " .. name,
		Health = B.Health,
		TorsoColor = Color3.fromRGB(70, 90, 160),
	})
	model.Name = "Bot"
	model:SetAttribute("Bot", true)
	model:SetAttribute("BotName", name)
	CollectionService:AddTag(model, "Dummy") -- ciblable par les armes
	model.Parent = workspace
	local bot = { Model = model, Humanoid = humanoid, Root = model.PrimaryPart, LastAttack = 0, Side = rng:NextInteger(0, 1) * 2 - 1, Dead = false }
	table.insert(bots, bot)
	CombatService.Track(humanoid)
	humanoid.Died:Connect(function()
		bot.Dead = true
		removeBot(bot)
		task.delay(1.5, function()
			model:Destroy()
		end)
	end)
end

local function groundBelow(x, y, z, params)
	return workspace:Raycast(Vector3.new(x, y + 4, z), Vector3.new(0, -14, 0), params)
end

local function stepBot(bot, dt, targets)
	local root = bot.Root
	if not root or not root.Parent or bot.Dead then
		return
	end
	local pos = root.Position
	local B = Config.Bots
	local index, dist = BotLogic.NearestTarget(pos.X, pos.Z, targets, B.Sight)
	if not index then
		return
	end
	local target = targets[index]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.Model, target.Character }
	-- attaque
	if BotLogic.CanAttack(dist, B.Range, os.clock(), bot.LastAttack, B.Cooldown) then
		local los = workspace:Raycast(pos + Vector3.new(0, 1, 0), target.Root.Position - pos - Vector3.new(0, 1, 0), params)
		if not los then
			bot.LastAttack = os.clock()
			CombatService.BotDamage(bot.Model, target.Player, B.Damage)
		end
	end
	-- déplacement
	if dist > B.Range * 0.7 then
		local stepLen = B.Speed * dt
		local ux, uz = BotLogic.Steer(target.X - pos.X, target.Z - pos.Z, function(dx, dz)
			local wall = workspace:Raycast(pos, Vector3.new(dx, 0, dz) * (stepLen + 2.5), params)
			if wall then
				return true
			end
			local g = groundBelow(pos.X + dx * (stepLen + 1), pos.Y - 3, pos.Z + dz * (stepLen + 1), params)
			return g == nil or g.Instance.Name == "Lava"
		end, bot.Side)
		if ux then
			local nx, nz = pos.X + ux * stepLen, pos.Z + uz * stepLen
			local g = groundBelow(nx, pos.Y - 3, nz, params)
			if g then
				local newPos = Vector3.new(nx, g.Position.Y + 3, nz)
				bot.Model:PivotTo(CFrame.lookAt(newPos, Vector3.new(target.X, newPos.Y, target.Z)))
			end
		else
			bot.Side = -bot.Side
		end
	else
		bot.Model:PivotTo(CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z)))
	end
end

local function step(dt)
	local humans = humansInArena()
	local B = Config.Bots
	-- ajuste le nombre de bots
	local want = BotLogic.DesiredCount(#humans, B.MinCombatants, B.MaxBots)
	local state = workspace:GetAttribute("MatchState")
	while #bots > want do
		local bot = table.remove(bots)
		bot.Dead = true
		bot.Model:Destroy()
	end
	if #bots < want and (state == "Intermission" or state == "Playing") then
		spawnBot(humans)
	end
	if state ~= "Playing" then
		return
	end
	local targets = {}
	for _, p in ipairs(humans) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			table.insert(targets, { Id = p.UserId, X = root.Position.X, Z = root.Position.Z, Root = root, Character = char, Player = p })
		end
	end
	for _, bot in ipairs(table.clone(bots)) do
		stepBot(bot, dt, targets)
	end
end

function BotService.Init(mapRefs)
	map = mapRefs
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			local elapsed = accumulator
			accumulator = 0
			local ok, err = pcall(step, elapsed)
			if not ok then
				warn("[BotService] " .. tostring(err))
			end
		end
	end)
end

return BotService

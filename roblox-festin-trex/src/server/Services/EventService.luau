--!nonstrict
-- Événements périodiques : Marée de sauce (survie), Pluie gourmande (collecte), Frénésie (x2 pièces).
-- L'état est publié dans ReplicatedStorage.GameState : les clients dessinent les effets eux-mêmes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Util = require(Shared:WaitForChild("Util"))

local PlayerService = require(script.Parent.PlayerService)
local DinoService = require(script.Parent.DinoService)

local EventService = {}

local state: Instance
local coinMult = 1
local lastEvent = ""

function EventService.getCoinMult(): number
	return coinMult
end

local function setEvent(id: string, phase: string, startAt: number, endAt: number)
	state:SetAttribute("EventId", id)
	state:SetAttribute("EventPhase", phase)
	state:SetAttribute("EventStart", startAt)
	state:SetAttribute("EventEnd", endAt)
end

local function clearEvent()
	setEvent("", "", 0, 0)
end

local function broadcast(text: string, kind: string)
	for _, p in ipairs(Players:GetPlayers()) do
		PlayerService.notify(p, text, kind)
	end
end

-- ---------------------------------------------------------------- Marée de sauce

local function sauceBounds(): (number, number)
	-- La vague traverse l'arène sur l'axe X ; les clients dessinent la même vague.
	return -Config.Events.Sauce.Half, Config.Events.Sauce.Half
end

local function runSauce()
	local cfg = Config.Events.Sauce
	local now = workspace:GetServerTimeNow()
	local startAt = now + cfg.Warning
	local endAt = startAt + cfg.Duration
	local dir = if math.random() < 0.5 then 1 else -1
	state:SetAttribute("SauceDir", dir)
	setEvent("sauce", "warning", startAt, endAt)
	broadcast("⚠️ " .. cfg.Name .. " dans " .. cfg.Warning .. "s ! Grimpe sur une table !", "bad")
	task.wait(cfg.Warning)
	setEvent("sauce", "active", startAt, endAt)

	local from, to = sauceBounds()
	if dir < 0 then
		from, to = to, from
	end
	local caught: { [Player]: boolean } = {}
	local lastFling: { [Player]: number } = {}
	local halfWidth = 6

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = (workspace:GetServerTimeNow() - startAt) / cfg.Duration
		if t < 0 or t > 1 then
			return
		end
		local waveX = from + (to - from) * t
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local pos = hrp.Position
				if math.abs(pos.X - waveX) < halfWidth and pos.Y - 3 < cfg.Height then
					caught[player] = true
					local nowC = os.clock()
					if nowC - (lastFling[player] or -10) > 2 then
						lastFling[player] = nowC
						-- Projection spectaculaire, sans dégâts.
						hrp.AssemblyLinearVelocity = Vector3.new(dir * 45, 50, (math.random() - 0.5) * 30)
						hum.PlatformStand = true
						task.delay(1.2, function()
							if hum.Parent then
								hum.PlatformStand = false
							end
						end)
						PlayerService.notify(player, "Éclaboussé ! 🍅", "bad")
					end
				end
			end
		end
	end)

	task.wait(cfg.Duration)
	conn:Disconnect()
	setEvent("sauce", "ended", startAt, endAt)

	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerService.get(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if data and hum and hum.Health > 0 and not caught[player] then
			local coins = math.floor(cfg.Reward * (1 + DinoService.getStage()) * Economy.rebirthMult(data.rebirths))
			PlayerService.addCoins(player, coins)
			PlayerService.record(player, "survive", 1)
			data.stats.survived += 1
			PlayerService.notify(player, string.format("Survivant ! +%s pièces 🏆", Util.formatNumber(coins)), "gold")
			PlayerService.markDirty(player)
		end
	end
	task.wait(2)
	clearEvent()
end

-- ---------------------------------------------------------------- Pluie gourmande

local function spawnDrop(folder: Folder)
	local cfg = Config.Events.Rain
	local angle = math.random() * math.pi * 2
	local radius = 20 + math.random() * 70
	local drop = Instance.new("Part")
	drop.Name = "Drop"
	drop.Shape = Enum.PartType.Ball
	drop.Size = Vector3.new(2.2, 2.2, 2.2)
	drop.Color = Color3.fromRGB(255, 205, 40)
	drop.Material = Enum.Material.Neon
	drop.CanCollide = false
	drop.CanQuery = false
	drop.Anchored = true
	local ground = Vector3.new(math.cos(angle) * radius, 2.5, 20 + math.sin(angle) * radius)
	drop.Position = ground + Vector3.new(0, 70, 0)
	drop.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = drop.Color
	light.Range = 10
	light.Parent = drop

	local taken = false
	drop.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or not PlayerService.get(player) then
			return
		end
		taken = true
		local data = PlayerService.get(player)
		local stats = Economy.stats(data)
		local coins = math.floor(cfg.DropValue * (1 + DinoService.getStage()) * stats.coinMult)
		PlayerService.addCoins(player, coins)
		PlayerService.markDirty(player)
		drop:Destroy()
	end)

	TweenService:Create(drop, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = ground }):Play()
	task.delay(cfg.DropLife, function()
		if drop.Parent then
			drop:Destroy()
		end
	end)
end

local function runRain()
	local cfg = Config.Events.Rain
	local now = workspace:GetServerTimeNow()
	local startAt = now + cfg.Warning
	local endAt = startAt + cfg.Duration
	setEvent("rain", "warning", startAt, endAt)
	broadcast("🍗 " .. cfg.Name .. " dans " .. cfg.Warning .. "s ! Ramasse les boules dorées !", "gold")
	task.wait(cfg.Warning)
	setEvent("rain", "active", startAt, endAt)

	local folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = workspace
	local elapsed = 0
	while elapsed < cfg.Duration do
		spawnDrop(folder)
		task.wait(cfg.DropEvery)
		elapsed += cfg.DropEvery
	end
	task.wait(cfg.DropLife)
	folder:Destroy()
	clearEvent()
end

-- ---------------------------------------------------------------- Frénésie

local function runFrenzy()
	local cfg = Config.Events.Frenzy
	local now = workspace:GetServerTimeNow()
	local startAt = now + cfg.Warning
	local endAt = startAt + cfg.Duration
	setEvent("frenzy", "warning", startAt, endAt)
	broadcast("🔥 " .. cfg.Name .. " ! Toutes les pièces x" .. cfg.Mult .. " bientôt !", "gold")
	task.wait(cfg.Warning)
	setEvent("frenzy", "active", startAt, endAt)
	coinMult = cfg.Mult
	state:SetAttribute("CoinEvent", coinMult)
	task.wait(cfg.Duration)
	coinMult = 1
	state:SetAttribute("CoinEvent", 1)
	clearEvent()
end

local runners = { sauce = runSauce, rain = runRain, frenzy = runFrenzy }

function EventService.init()
	state = ReplicatedStorage:WaitForChild("GameState")
	state:SetAttribute("CoinEvent", 1)
	clearEvent()

	task.spawn(function()
		task.wait(Config.Events.FirstDelay)
		while true do
			local pick
			repeat
				local ids = { "sauce", "rain", "frenzy" }
				pick = ids[math.random(#ids)]
			until pick ~= lastEvent
			lastEvent = pick
			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(runners[pick])
				if not ok then
					warn("[FestinTRex] Événement " .. pick .. " en erreur : " .. tostring(err))
					coinMult = 1
					state:SetAttribute("CoinEvent", 1)
					clearEvent()
				end
			end
			task.wait(math.random(Config.Events.MinInterval, Config.Events.MaxInterval))
		end
	end)
end

return EventService

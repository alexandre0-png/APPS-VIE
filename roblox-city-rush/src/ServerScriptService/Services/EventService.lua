--[[
	EventService : événements mondiaux récurrents
	- Largage de caisses : des caisses d'argent apparaissent dans la ville, premier arrivé premier servi
	- Heure double XP
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)

local EventService = {}

local rng = Random.new()
local World
local crates = {}

local function randomRoadPoint()
	local line = rng:NextInteger(0, 5)
	local c = -500 + Config.Map.Pitch * line
	local t = rng:NextNumber(-460, 460)
	if rng:NextInteger(0, 1) == 1 then
		return Vector3.new(c, 3, t)
	end
	return Vector3.new(t, 3, c)
end

local function runAirdrop()
	local cfg = Config.Airdrop
	local folder = Instance.new("Folder")
	folder.Name = "Airdrop"
	folder.Parent = World.Root
	local positions = {}
	for _ = 1, cfg.Crates do
		local pos = randomRoadPoint()
		table.insert(positions, pos)
		local crate = Instance.new("Part")
		crate.Name = "AirdropCrate"
		crate.Size = Vector3.new(4, 4, 4)
		crate.Position = pos + Vector3.new(0, 1, 0)
		crate.Anchored = true
		crate.CanCollide = false
		crate.Color = Color3.fromRGB(90, 230, 120)
		crate.Material = Enum.Material.Neon
		crate.Parent = folder
		local beam = Instance.new("Part")
		beam.Size = Vector3.new(120, 2, 2)
		beam.CFrame = CFrame.new(pos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Shape = Enum.PartType.Cylinder
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Transparency = 0.7
		beam.Color = crate.Color
		beam.Material = Enum.Material.Neon
		beam.Parent = crate
		table.insert(crates, { part = crate, pos = pos })
	end
	RemoteService.fireAll("Banner", {
		kind = "airdrop",
		text = string.format("LARGAGE DE CAISSES ! %d caisses d'argent dans la ville (%d s)", cfg.Crates, cfg.Duration),
		positions = positions,
		duration = cfg.Duration,
	})
	local t0 = os.clock()
	while os.clock() - t0 < cfg.Duration and #crates > 0 do
		task.wait(0.3)
		for i = #crates, 1, -1 do
			local c = crates[i]
			for _, player in ipairs(Players:GetPlayers()) do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - c.pos).Magnitude < 10 then
					local paid = EconomyService.addCash(player, cfg.Reward, "airdrop")
					EconomyService.addXP(player, 20)
					RemoteService.notify(player, string.format("Caisse récupérée ! +%s", Util.formatCash(paid)), "good")
					c.part:Destroy()
					table.remove(crates, i)
					break
				end
			end
		end
	end
	for _, c in ipairs(crates) do
		c.part:Destroy()
	end
	crates = {}
	folder:Destroy()
	RemoteService.fireAll("Banner", { kind = "airdrop_end", text = "Largage terminé.", positions = {}, duration = 0 })
end

local function runDoubleXP()
	local cfg = Config.DoubleXP
	EconomyService.DoubleXP = true
	for _, p in ipairs(Players:GetPlayers()) do
		EconomyService.markState(p)
	end
	RemoteService.fireAll("Banner", { kind = "doublexp", text = "HEURE DOUBLE XP ! (5 minutes)", positions = {}, duration = cfg.Duration })
	task.wait(cfg.Duration)
	EconomyService.DoubleXP = false
	for _, p in ipairs(Players:GetPlayers()) do
		EconomyService.markState(p)
	end
end

function EventService.start(world)
	World = world
	Util.supervise("EventService", function()
		task.wait(150)
		while true do
			if #Players:GetPlayers() > 0 then
				runAirdrop()
			end
			task.wait(rng:NextNumber(Config.Airdrop.MinInterval, Config.Airdrop.MaxInterval))
		end
	end)
	Util.supervise("EventService", function()
		task.wait(600)
		while true do
			if #Players:GetPlayers() > 0 then
				runDoubleXP()
			end
			task.wait(rng:NextNumber(Config.DoubleXP.MinInterval, Config.DoubleXP.MaxInterval))
		end
	end)
end

return EventService

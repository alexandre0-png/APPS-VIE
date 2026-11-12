-- EventService.luau : événement serveur "Pluie de météores" (récompense fossiles + boost de revenus).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)

local PlotService = require(script.Parent.PlotService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local EventService = {}
local GameService = nil
local rng = Random.new()

local function spawnMeteor(player, plot)
	local x = rng:NextNumber(-6, 6)
	local z = rng:NextNumber(-60, 14)
	local target = plot.cf:PointToWorldSpace(Vector3.new(x, 1.6, z))
	local startPos = target + Vector3.new(rng:NextNumber(-25, 25), 90, rng:NextNumber(-25, 25))

	local m = WorldBuilder.ball(Workspace, "Meteore", 4.5, startPos, Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	m.CanCollide = false
	m.CanTouch = false
	m.CanQuery = false
	m:SetAttribute("OwnerUserId", player.UserId)
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 12
	fire.Parent = m
	local tween = TweenService:Create(m, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target })
	tween:Play()
	tween.Completed:Connect(function()
		if not m.Parent then
			return
		end
		m.Size = Vector3.new(3.5, 3.5, 3.5)
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 40
		cd.Parent = m
		local pp = WorldBuilder.prompt(m, "Récupérer", "Météore", 14)
		local taken = false
		local function collect(p)
			if taken or p ~= player then
				return
			end
			taken = true
			local s = GameService.getSession(player)
			if s then
				local amount = math.max(25, Economy.digAmount(s.data) * 12)
				GameService.addFossils(player, amount)
				GameService.addBoost(player, 30)
				GameService.notify(player, "☄ Météore : +" .. amount .. " 🦴 et boost x2 (30 s) !", "good")
				Remotes.Fx:FireClient(player, { t = "meteor", amount = amount })
			end
			m:Destroy()
		end
		cd.MouseClick:Connect(collect)
		pp.Triggered:Connect(collect)
		task.delay(25, function()
			if m.Parent then
				m:Destroy()
			end
		end)
	end)
end

local function runEvent()
	local ev = Config.Event
	local endsAt = os.time() + ev.duration
	Workspace:SetAttribute("EventName", "☄ Pluie de météores")
	Workspace:SetAttribute("EventEndsAt", endsAt)
	for _, p in ipairs(Players:GetPlayers()) do
		GameService.notify(p, "☄ Pluie de météores ! Cours sur le chemin de ton parc pour les récupérer.", "good")
	end
	local alive = {}
	while os.time() < endsAt do
		for _, player in ipairs(Players:GetPlayers()) do
			local plot = PlotService.getPlot(player)
			if plot then
				local count = 0
				for _, inst in ipairs(Workspace:GetChildren()) do
					if inst.Name == "Meteore" and inst:GetAttribute("OwnerUserId") == player.UserId then
						count = count + 1
					end
				end
				if count < ev.maxAlive then
					spawnMeteor(player, plot)
				end
			end
		end
		task.wait(ev.spawnEvery)
	end
	Workspace:SetAttribute("EventName", nil)
	Workspace:SetAttribute("EventEndsAt", nil)
end

function EventService.init(gameService)
	GameService = gameService
	task.spawn(function()
		task.wait(120) -- premier événement 2 minutes après le démarrage du serveur
		while true do
			local ok, err = pcall(runEvent)
			if not ok then
				warn("[EventService]", err)
			end
			task.wait(Config.Event.interval)
		end
	end)
end

return EventService

--[[
	WantedService : niveau de recherche (0-5 étoiles), policiers à pied et voitures de police (IA),
	arrestations, Pay'n'Spray. Toute la logique est côté serveur.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local PedestrianService = require(script.Parent.PedestrianService)
local VehicleService = require(script.Parent.VehicleService)

local WantedService = {}
WantedService.Busted = Util.newSignal() -- (player)

local W = Config.Wanted
local World
local rng = Random.new()
local states = {} -- [player] = state
local copTemplate
local copFolder

local function starsFromHeat(heat)
	if heat < 1 then
		return 0
	end
	return math.min(W.MaxStars, math.ceil(heat / W.HeatPerStar))
end

local function getState(player)
	local s = states[player]
	if not s then
		s = { heat = 0, stars = 0, cops = {}, cruisers = {}, lastNear = os.clock(), immuneUntil = 0, sentStars = -1, sentEvading = false, stopTimer = 0, spawning = false }
		states[player] = s
	end
	return s
end

local function hrpOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function playerSpeed(player)
	local v = VehicleService.getOccupiedVehicle(player)
	if v and v.PrimaryPart then
		return v.PrimaryPart.AssemblyLinearVelocity.Magnitude, true
	end
	local hrp = hrpOf(player)
	return hrp and hrp.AssemblyLinearVelocity.Magnitude or 0, false
end

local function push(player, s, evading)
	if s.sentStars ~= s.stars or s.sentEvading ~= evading then
		s.sentStars = s.stars
		s.sentEvading = evading
		RemoteService.fire("Wanted", player, s.stars, evading)
	end
end

-- ====================================================================
-- API
-- ====================================================================
function WantedService.addHeat(player, amount, reason)
	local s = getState(player)
	if os.clock() < s.immuneUntil or not DataService.get(player) then
		return
	end
	local before = s.stars
	s.heat = math.min(100, s.heat + amount)
	s.stars = starsFromHeat(s.heat)
	s.lastNear = os.clock()
	if s.stars > before then
		RemoteService.notify(player, string.format("%s ! Niveau de recherche : %d", reason or "Recherché", s.stars), "bad")
		if s.stars >= 5 then
			EconomyService.addStat(player, "fiveStars", 1)
		end
	end
	push(player, s, false)
end

function WantedService.getStars(player)
	local s = states[player]
	return s and s.stars or 0
end

local function removeCops(s)
	for _, m in ipairs(s.cops) do
		if m.Parent then
			m:Destroy()
		end
	end
	for _, c in ipairs(s.cruisers) do
		if c.model and c.model.Parent then
			c.model:Destroy()
		end
	end
	s.cops = {}
	s.cruisers = {}
end

function WantedService.clear(player)
	local s = getState(player)
	s.heat = 0
	s.stars = 0
	removeCops(s)
	push(player, s, false)
end

function WantedService.copNear(player, radius)
	local hrp = hrpOf(player)
	if not hrp then
		return false
	end
	for _, m in ipairs(copFolder:GetChildren()) do
		local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if r and (r.Position - hrp.Position).Magnitude < radius then
			return true
		end
	end
	return false
end

local function bust(player)
	local s = getState(player)
	if os.clock() < s.immuneUntil then
		return
	end
	s.immuneUntil = os.clock() + 6
	local cash = EconomyService.getCash(player)
	local lost = EconomyService.loseCash(player, math.min(math.floor(cash * W.BustedCashPercent), W.BustedMaxLoss))
	EconomyService.addStat(player, "busted", 1)
	RemoteService.fire("Busted", player, lost)
	WantedService.clear(player)
	WantedService.Busted:Fire(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = false
	end
	task.delay(0.6, function()
		local c2 = player.Character
		if c2 and c2.Parent then
			c2:PivotTo(World.PolicePoint)
			local ff = Instance.new("ForceField")
			ff.Visible = true
			ff.Parent = c2
			task.delay(5, function()
				ff:Destroy()
			end)
		end
	end)
end

-- ====================================================================
-- Policiers à pied
-- ====================================================================
local function groundPointNear(pos, minD, maxD)
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minD, maxD)
		local p = pos + Vector3.new(math.cos(a) * d, 60, math.sin(a) * d)
		local r = workspace:Raycast(p, Vector3.new(0, -120, 0))
		if r and r.Position.Y < 3 and r.Position.Y > -1 then
			return r.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

local function spawnCop(player, s)
	if not copTemplate then
		return
	end
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	local pos = groundPointNear(hrp.Position, 70, 120)
	if not pos then
		return
	end
	local m = copTemplate:Clone()
	m.Name = "Policier"
	m:SetAttribute("Cop", true)
	m:SetAttribute("Target", player.UserId)
	m:PivotTo(CFrame.new(pos))
	m.Parent = copFolder
	local r = m:FindFirstChild("HumanoidRootPart")
	if r then
		r:SetNetworkOwner(nil)
	end
	PedestrianService.setupAnimation(m, true)
	table.insert(s.cops, m)
end

local function copStep(player, s, hrp)
	local speed, inVehicle = playerSpeed(player)
	local walk = 12 + s.stars * 2.5
	for i = #s.cops, 1, -1 do
		local m = s.cops[i]
		local r = m.Parent and m:FindFirstChild("HumanoidRootPart")
		if not r then
			table.remove(s.cops, i)
		else
			local hum = m:FindFirstChildOfClass("Humanoid")
			local d = (r.Position - hrp.Position).Magnitude
			if d > 260 or r.Position.Y < -8 then
				-- trop loin ou tombé : se replace près du joueur
				local p = groundPointNear(hrp.Position, 90, 130)
				if p then
					m:PivotTo(CFrame.new(p))
				end
			else
				hum.WalkSpeed = walk
				hum:MoveTo(hrp.Position)
				if r.AssemblyLinearVelocity.Magnitude < 1.5 and d > 6 then
					hum.Jump = true
				end
			end
			if d < 5.5 and (not inVehicle or speed < 10) and speed < 24 then
				bust(player)
				return
			end
		end
	end
end

-- ====================================================================
-- Voitures de police (IA arcade, suit le réseau de routes)
-- ====================================================================
local function gridLine(n)
	return -500 + Config.Map.Pitch * n
end

local function nearestLine(v)
	local n = math.clamp(math.floor((v + 500) / Config.Map.Pitch + 0.5), 0, 5)
	return n, gridLine(n)
end

local function lineOfSight(from, to, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local origin = from + Vector3.new(0, 3, 0)
	local r = workspace:Raycast(origin, (to + Vector3.new(0, 3, 0)) - origin, params)
	return r == nil
end

local function spawnCruiser(player, s)
	local hrp = hrpOf(player)
	if not hrp then
		return
	end
	-- intersection à 150-380 studs
	local best
	for _ = 1, 12 do
		local ix, iz = rng:NextInteger(0, 5), rng:NextInteger(0, 5)
		local p = World.RoadNodes[ix][iz]
		local d = Util.flatDistance(p, hrp.Position)
		if d > 150 and d < 380 then
			best = p
			break
		end
	end
	if not best then
		return
	end
	local dir = Util.flat(hrp.Position - best)
	local axisDir = math.abs(dir.X) > math.abs(dir.Z) and Vector3.new(math.sign(dir.X), 0, 0) or Vector3.new(0, 0, math.sign(dir.Z))
	local at = best + Vector3.new(0, 2.6, 0)
	local model = VehicleService.spawnCruiser(CFrame.lookAt(at, at + axisDir))
	table.insert(s.cruisers, { model = model, cmd = 0, stuck = 0, reverseUntil = 0, plan = nil })
end

local function cruiserStep(c, target, stars, dt)
	local model = c.model
	local chassis = model.PrimaryPart
	local lv = chassis and chassis:FindFirstChild("DriveVelocity")
	local av = chassis and chassis:FindFirstChild("TurnVelocity")
	if not lv or not av then
		return
	end
	local pos = chassis.Position
	local look = chassis.CFrame.LookVector
	local right = chassis.CFrame.RightVector
	local vel = chassis.AssemblyLinearVelocity
	local fwd = vel:Dot(look)
	local flatLook = Util.flat(look)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
	local now = os.clock()

	-- waypoint
	local waypoint
	local dist = Util.flatDistance(pos, target)
	if dist < 110 and lineOfSight(pos, target, { model, copFolder, workspace:FindFirstChild("Pedestrians"), workspace:FindFirstChild("Vehicles") }) then
		waypoint = target
		c.plan = nil
	else
		local alongZ = math.abs(flatLook.Z) >= math.abs(flatLook.X)
		local sgn = alongZ and math.sign(flatLook.Z) or math.sign(flatLook.X)
		if sgn == 0 then
			sgn = 1
		end
		local s = alongZ and pos.Z or pos.X
		local _, lateralLine = nearestLine(alongZ and pos.X or pos.Z)
		-- intersection devant le véhicule
		local aheadIdx = sgn > 0 and 5 or 0
		if sgn > 0 then
			for n = 0, 5 do
				if gridLine(n) > s + 12 then
					aheadIdx = n
					break
				end
			end
		else
			for n = 5, 0, -1 do
				if gridLine(n) < s - 12 then
					aheadIdx = n
					break
				end
			end
		end
		local nodeAlong = gridLine(aheadIdx)
		local node = alongZ and Vector3.new(lateralLine, 0, nodeAlong) or Vector3.new(nodeAlong, 0, lateralLine)
		local dNode = Util.flatDistance(pos, node)
		waypoint = node
		if dNode < 45 then
			-- décision au carrefour : on choisit la sortie la plus proche de la cible
			if not c.plan or c.plan.node ~= node then
				local options = {}
				local fwdDir = alongZ and Vector3.new(0, 0, sgn) or Vector3.new(sgn, 0, 0)
				local rightDir = Vector3.new(-fwdDir.Z, 0, fwdDir.X)
				for _, dir in ipairs({ fwdDir, rightDir, -rightDir }) do
					local nxt = node + dir * Config.Map.Pitch
					if math.abs(nxt.X) <= 500 and math.abs(nxt.Z) <= 500 then
						table.insert(options, { p = nxt, d = Util.flatDistance(nxt, target) })
					end
				end
				table.sort(options, function(a, b)
					return a.d < b.d
				end)
				c.plan = { node = node, nxt = options[1] and options[1].p or node + fwdDir * Config.Map.Pitch }
			end
			waypoint = c.plan.nxt
		else
			c.plan = nil
		end
	end

	-- direction souhaitée
	local to = Util.flat(waypoint - pos)
	local toUnit = to.Magnitude > 0.1 and to.Unit or flatLook
	local x = right:Dot(toUnit)
	local zc = look:Dot(toUnit)
	local steer = math.clamp(x * 2.4, -1, 1)
	if zc < -0.2 then
		steer = x >= 0 and 1 or -1
	end

	-- récupération si bloqué
	if math.abs(fwd) < 4 and now > c.reverseUntil then
		c.stuck += dt
		if c.stuck > 1.6 then
			c.reverseUntil = now + 1.1
			c.stuck = 0
		end
	elseif math.abs(fwd) >= 4 then
		c.stuck = 0
	end
	local maxSpeed = Config.Police.maxSpeed * (0.72 + 0.06 * stars)
	local targetSpeed = maxSpeed * math.clamp(1 - math.abs(x) * 0.55, 0.4, 1)
	if now < c.reverseUntil then
		targetSpeed = -22
		steer = -steer
	end
	local rate = fwd < targetSpeed and Config.Police.accel or 60
	local cmd = fwd + math.clamp(targetSpeed - fwd, -rate * dt, rate * dt)
	lv.PlaneVelocity = Vector2.new(0, -cmd)
	local speedFactor = math.clamp(math.abs(fwd) / 18, 0, 1) * (1 - 0.4 * math.min(1, math.abs(fwd) / maxSpeed))
	av.AngularVelocity = Vector3.new(0, -steer * Config.Police.turn * speedFactor * (fwd >= 0 and 1 or -1), 0)

	-- redresse si retourné
	if chassis.CFrame.UpVector.Y < 0.3 then
		chassis.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
	end
end

local function cruiserLoop()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now
		for player, s in pairs(states) do
			local hrp = hrpOf(player)
			for i = #s.cruisers, 1, -1 do
				local c = s.cruisers[i]
				if not c.model or not c.model.Parent or not c.model.PrimaryPart then
					table.remove(s.cruisers, i)
				elseif not hrp or s.stars == 0 then
					c.model:Destroy()
					table.remove(s.cruisers, i)
				else
					local chassis = c.model.PrimaryPart
					local d = (chassis.Position - hrp.Position).Magnitude
					if chassis.Position.Y < -8 or d > 520 then
						c.model:Destroy()
						table.remove(s.cruisers, i)
					else
						cruiserStep(c, hrp.Position, s.stars, dt)
						-- arrestation : voiture de police collée au joueur immobilisé
						local speed = playerSpeed(player)
						if d < 14 and speed < 7 then
							s.stopTimer += dt
							if s.stopTimer > 1.8 then
								s.stopTimer = 0
								bust(player)
							end
						end
					end
				end
			end
			if s.stars == 0 or #s.cruisers == 0 then
				s.stopTimer = 0
			end
		end
	end
end

-- ====================================================================
-- Boucle principale (4 Hz)
-- ====================================================================
local function mainLoop()
	local last = os.clock()
	while true do
		task.wait(0.25)
		local now = os.clock()
		local dt = now - last
		last = now
		for _, player in ipairs(Players:GetPlayers()) do
			local s = states[player]
			local hrp = hrpOf(player)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if s and hrp and hum and hum.Health > 0 then
				if s.stars > 0 then
					local near = WantedService.copNear(player, W.LoseDistance)
					if not near then
						for _, c in ipairs(s.cruisers) do
							if c.model.PrimaryPart and (c.model.PrimaryPart.Position - hrp.Position).Magnitude < W.LoseDistance then
								near = true
							end
						end
					end
					if near then
						s.lastNear = now
					else
						s.heat = math.max(0, s.heat - W.DecayPerSec * dt)
						local newStars = starsFromHeat(s.heat)
						if newStars ~= s.stars then
							s.stars = newStars
							if newStars == 0 then
								RemoteService.notify(player, "Tu as semé la police !", "good")
								removeCops(s)
							end
						end
					end
					push(player, s, not near)
					-- maintien des effectifs
					local wantCops = W.MaxCopsByStars[s.stars] or 0
					if #s.cops < wantCops and not s.spawning then
						spawnCop(player, s)
					end
					local wantCruisers = W.MaxCruisersByStars[s.stars] or 0
					if #s.cruisers < wantCruisers and now - (s.lastCruiser or 0) > 5 then
						s.lastCruiser = now
						spawnCruiser(player, s)
					end
					copStep(player, s, hrp)
				end
			elseif s and hum and hum.Health <= 0 and s.stars > 0 then
				WantedService.clear(player)
			end
		end
	end
end

-- ====================================================================
-- Pay'n'Spray
-- ====================================================================
local function setupSprayPrompt(pad)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Se faire oublier"
	prompt.ObjectText = "Pay'n'Spray"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		local s = states[player]
		if not s or s.stars == 0 then
			RemoteService.notify(player, "Tu n'es pas recherché !", "info")
			return
		end
		local cost = W.SprayCostPerStar * s.stars
		if EconomyService.spendCash(player, cost) then
			WantedService.clear(player)
			RemoteService.notify(player, string.format("Casier effacé pour %s", Util.formatCash(cost)), "good")
		else
			RemoteService.notify(player, string.format("Il faut %s pour te faire oublier.", Util.formatCash(cost)), "bad")
		end
	end)
end

function WantedService.init(world)
	World = world
	copFolder = Instance.new("Folder")
	copFolder.Name = "Cops"
	copFolder.Parent = workspace

	local function onChar(player, char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				if states[player] and states[player].stars > 0 then
					WantedService.clear(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		getState(player)
		player.CharacterAdded:Connect(function(c)
			onChar(player, c)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		getState(player)
		player.CharacterAdded:Connect(function(c)
			onChar(player, c)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s then
			removeCops(s)
			states[player] = nil
		end
	end)

	for _, pad in ipairs(CollectionService:GetTagged("SprayHub")) do
		setupSprayPrompt(pad)
	end
end

function WantedService.start()
	-- Gabarit policier (créé une fois, cloné ensuite)
	task.spawn(function()
		copTemplate = PedestrianService.newRig({
			head = Color3.fromRGB(234, 184, 146),
			torso = Color3.fromRGB(30, 50, 120),
			arms = Color3.fromRGB(30, 50, 120),
			legs = Color3.fromRGB(25, 30, 60),
		})
	end)
	task.spawn(mainLoop)
	task.spawn(cruiserLoop)
end

return WantedService

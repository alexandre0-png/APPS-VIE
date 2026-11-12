-- Cœur du gameplay : monter une bête, bondir, lasso, dressage, chute, élimination, arrivée.
-- Le serveur est autoritaire : positions des bêtes, portée du lasso, score et états sont validés ici.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local State = require(script.Parent.State)
local CreatureService = require(script.Parent.CreatureService)
local ProgressService = require(script.Parent.ProgressService)
local Fx = require(script.Parent.Fx)

local RideService = {}

local rng = Random.new()

-- ---------------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------------

local function getParts(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return nil
	end
	return char, hrp, hum
end

local function setStatus(player, run, status)
	run.status = status
	Remotes.Status:FireClient(player, status)
end

local function feedback(player, kind, title, sub)
	Remotes.Feedback:FireClient(player, { kind = kind, title = title, sub = sub })
end

local function comboMult(run)
	return 1 + math.min(run.combo, Config.Ride.ComboMax) * Config.Ride.ComboStep
end

local function comboWindow(player)
	return Config.Ride.ComboWindowBase + Config.Ride.ComboWindowPerLevel * ProgressService.GetUpgradeLevel(player, "combo")
end

local function setDust(creature, enabled)
	local attachment = creature.root:FindFirstChild("DustAttachment")
	local dust = attachment and attachment:FindFirstChild("Dust")
	if dust then
		dust.Enabled = enabled
	end
end

local function addScore(run, amount)
	run.score = run.score + amount
end

function RideService.NewRun()
	return {
		status = "Riding",
		score = 0,
		combo = 0,
		maxCombo = 0,
		lastHookT = 0,
		hooks = 0,
		tames = 0,
		distance = 0,
		bestZ = 0,
		z = 0,
		creature = nil,
		weld = nil,
		mountT = 0,
		tameT = 0,
		airStart = 0,
		lastCreature = nil,
		lastCreatureUntil = 0,
		downUntil = 0,
		pubT = 0,
		finishPlace = 0,
		coins = 0,
		rank = 0,
	}
end

function RideService.ToLobby(player)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp then
		hrp.Anchored = false
		local old = hrp:FindFirstChild("RideWeld")
		if old then
			old:Destroy()
		end
	end
	if hum then
		hum.Sit = false
	end
	local offset = CFrame.new((rng:NextNumber() - 0.5) * 70, 4, (rng:NextNumber() - 0.5) * 70)
	char:PivotTo(State.LobbyCFrame * offset)
end

-- ---------------------------------------------------------------------------
-- Monter / quitter une bête
-- ---------------------------------------------------------------------------

function RideService.Detach(run)
	if run.weld then
		run.weld:Destroy()
		run.weld = nil
	end
	local creature = run.creature
	if creature then
		creature.rider = nil
		creature.steer = 0
		creature.angry = false
		if not creature.removed then
			creature.model:SetAttribute("Ridden", false)
			creature.model:SetAttribute("Angry", false)
			setDust(creature, false)
		end
		run.creature = nil
	end
end

function RideService.Mount(player, run, creature)
	local _, hrp, hum = getParts(player)
	if not hrp then
		return false
	end
	RideService.Detach(run)

	creature.rider = player
	creature.steer = 0
	creature.angry = false
	run.creature = creature
	run.mountT = 0
	run.tameT = 0

	hrp.Anchored = false
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	hrp.CFrame = CreatureService.SeatWorldCFrame(creature)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "RideWeld"
	weld.Part0 = creature.root
	weld.Part1 = hrp
	weld.Parent = hrp
	run.weld = weld

	hum.Sit = true
	creature.model:SetAttribute("Ridden", true)
	setDust(creature, true)

	local label = creature.def.name
	if creature.variantIdx > 1 then
		label = label .. " " .. creature.variant.name
	end
	player:SetAttribute("RideName", label)
	player:SetAttribute("TameProgress", 0)

	setStatus(player, run, "Riding")
	return true
end

-- Quitte la monture avec une vitesse donnée (bond, geyser, désarçonnement).
-- Traînée colorée derrière le cavalier pendant le vol (couleur de sa corde).
function RideService.AddTrail(player, hrp)
	local old = hrp:FindFirstChild("FlightTrail")
	if old then
		old:Destroy()
	end
	local color = ProgressService.GetRopeStyle(player)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "FlightTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = hrp
	Debris:AddItem(trail, 2.2)
	Debris:AddItem(a0, 2.2)
	Debris:AddItem(a1, 2.2)
end

local function launch(player, run, velocity)
	local _, hrp, hum = getParts(player)
	if not hrp then
		return false
	end
	-- la bête qu'on vient de quitter ne peut pas être relassoée aussitôt (sinon le bond ne sert à rien)
	run.lastCreature = run.creature
	run.lastCreatureUntil = os.clock() + 1.0
	RideService.Detach(run)
	hum.Sit = false
	hrp.Anchored = false
	hrp.AssemblyLinearVelocity = velocity
	pcall(function()
		hrp:SetNetworkOwner(player)
	end)
	run.airStart = os.clock()
	player:SetAttribute("TameProgress", 0)
	RideService.AddTrail(player, hrp)
	setStatus(player, run, "Air")
	Remotes.Launched:FireClient(player, velocity)
	return true
end

function RideService.Boost(player, velocity)
	local run = State.Participants[player]
	if not run then
		return false
	end
	local s = run.status
	if s ~= "Riding" and s ~= "Air" and s ~= "Down" then
		return false
	end
	return launch(player, run, velocity)
end

local function downPlayer(player, run, title, sub)
	run.combo = 0
	run.downUntil = os.clock() + Config.Ride.DownTime
	local _, hrp = getParts(player)
	if hrp then
		hrp.Anchored = false
	end
	player:SetAttribute("TameProgress", 0)
	if hrp then
		Fx.burst(hrp.Position - Vector3.new(0, 2, 0), Color3.fromRGB(214, 190, 150), 18, 18)
	end
	setStatus(player, run, "Down")
	feedback(player, "down", title or "RATÉ !", sub or "Rattrape une bête qui passe !")
end

-- Projette un joueur au sol (météore).
function RideService.Knock(player)
	local run = State.Participants[player]
	if not run then
		return false
	end
	local s = run.status
	if s ~= "Riding" and s ~= "Air" and s ~= "Down" then
		return false
	end
	local _, hrp, hum = getParts(player)
	if not hrp then
		return false
	end
	RideService.Detach(run)
	hum.Sit = false
	hrp.Anchored = false
	hrp.AssemblyLinearVelocity = Vector3.new((rng:NextNumber() - 0.5) * 40, 45, 0)
	pcall(function()
		hrp:SetNetworkOwner(player)
	end)
	downPlayer(player, run, "TOUCHÉ !", "Un météore t'a éjecté !")
	return true
end

local function rescue(player, run)
	local _, hrp = getParts(player)
	if not hrp then
		return
	end
	local pos = hrp.Position
	local creature = CreatureService.FindRescue(pos.X, pos.Z)
	if not creature then
		local x = math.clamp(pos.X, -Config.Track.HalfWidth + 8, Config.Track.HalfWidth - 8)
		creature = CreatureService.Spawn(x, math.max(pos.Z, State.WallZ + 30) + 14, "boar", 1, 1)
	end
	RideService.Mount(player, run, creature)
end

-- ---------------------------------------------------------------------------
-- Combo, dressage
-- ---------------------------------------------------------------------------

local function onHookSuccess(player, run, creature, distance)
	local now = os.clock()
	if run.combo > 0 and now - run.lastHookT > comboWindow(player) then
		run.combo = 0
	end
	run.combo = run.combo + 1
	run.maxCombo = math.max(run.maxCombo, run.combo)
	run.lastHookT = now
	run.hooks = run.hooks + 1

	local mult = comboMult(run)
	local points = Config.Score.HookBonus * mult
	local title = "LASSO !"
	if distance >= Config.Score.LongHookDistance then
		points = points + Config.Score.LongHookBonus
		title = "LONG LASSO !"
	end
	addScore(run, points)

	local sub = ("+%d"):format(math.floor(points))
	if run.combo >= 2 then
		sub = sub .. (" · COMBO x%.1f"):format(mult)
	end
	feedback(player, "hook", title, sub)
end

local function tameTimeNeeded(player, creature)
	local level = ProgressService.GetUpgradeLevel(player, "taming")
	local factor = 1 - Config.Tame.PerLevel * level
	return math.max(Config.Tame.MinTime, creature.def.tameTime * factor)
end

local function doTame(player, run, creature)
	creature.tamed = true
	run.tames = run.tames + 1
	local points = Config.Score.TameBase * creature.def.value * creature.variant.mult
	addScore(run, points)
	local result = ProgressService.RecordTame(player, creature.def, creature.variantIdx)
	run.coins = run.coins + result.coins

	local name = creature.def.name
	if creature.variantIdx > 1 then
		name = name .. " " .. creature.variant.name
	end
	local sub = ("%s · +%d pts · +%d pièces"):format(name, math.floor(points), result.coins)
	if result.complete then
		sub = sub .. " · ESPÈCE COMPLÈTE !"
	elseif result.first then
		sub = sub .. " · NOUVELLE DÉCOUVERTE"
	end
	feedback(player, "tame", "DOMPTÉ !", sub)
	Fx.burst(creature.root.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 220, 90), 40, 30)
end

-- ---------------------------------------------------------------------------
-- Remotes
-- ---------------------------------------------------------------------------

function RideService.HandleLaunch(player)
	if State.Phase ~= "Running" then
		return
	end
	local run = State.Participants[player]
	if not run or run.status ~= "Riding" or not run.creature then
		return
	end
	if not Util.allow(player, "Launch", 0.15) then
		return
	end
	local c = run.creature
	local velocity = Vector3.new(c.vx, Config.Ride.LaunchUp, c.speed + Config.Ride.LaunchBoost)
	launch(player, run, velocity)
end

function RideService.HandleSteer(player, value)
	if not Util.isFiniteNumber(value) or not Util.allow(player, "Steer", 0.04) then
		return
	end
	local run = State.Participants[player]
	if not run or run.status ~= "Riding" or not run.creature then
		return
	end
	run.creature.steer = math.clamp(value, -1, 1)
end

local function spawnRope(player, hrp, creature, duration)
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) or hrp
	local color, neon = ProgressService.GetRopeStyle(player)

	local a0 = Instance.new("Attachment")
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Position = creature.seat.Position
	a1.Parent = creature.root

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.Segments = 8
	beam.LightEmission = neon and 1 or 0
	beam.Parent = hand

	local life = duration + 0.25
	Debris:AddItem(beam, life)
	Debris:AddItem(a0, life)
	Debris:AddItem(a1, life)
end

function RideService.HandleHook(player, id)
	if not Util.isFiniteNumber(id) or id % 1 ~= 0 or State.Phase ~= "Running" then
		return
	end
	local run = State.Participants[player]
	if not run or (run.status ~= "Air" and run.status ~= "Down") then
		return
	end
	if not Util.allow(player, "Hook", Config.Ride.HookCooldown) then
		return
	end
	local creature = State.Creatures[id]
	if not creature or creature.removed or creature.rider then
		return
	end
	local _, hrp = getParts(player)
	if not hrp then
		return
	end

	local seatCF = CreatureService.SeatWorldCFrame(creature)
	local delta = seatCF.Position - hrp.Position
	local range = (player:GetAttribute("HookRange") or Config.Ride.HookBaseRange) + Config.Ride.HookTolerance
	if delta.Magnitude > range then
		return
	end
	-- en l'air : la bête doit être devant (marge de latence) ; au sol : elle peut passer à côté
	local minDz = run.status == "Air" and -4 or -25
	if delta.Z < minDz then
		return
	end
	if creature == run.lastCreature and os.clock() < (run.lastCreatureUntil or 0) then
		return
	end

	-- Réserver la bête immédiatement : personne d'autre ne peut la lasso.
	creature.rider = player
	run.status = "Hooking"
	Remotes.Status:FireClient(player, "Hooking")
	hrp.Anchored = true -- le serveur déplace le joueur pendant l'attraction (mouvement fluide, sans conflit)

	local distance = delta.Magnitude
	local duration = math.clamp(distance / 200, 0.08, 0.3)
	spawnRope(player, hrp, creature, duration)

	task.spawn(function()
		local startCF = hrp.CFrame
		local t0 = os.clock()
		local aborted = false
		while true do
			local alpha = (os.clock() - t0) / duration
			if alpha >= 1 then
				break
			end
			if run.status ~= "Hooking" or not hrp.Parent or creature.removed then
				aborted = true
				break
			end
			local target = CreatureService.SeatWorldCFrame(creature)
			local eased = alpha * alpha * (3 - 2 * alpha)
			hrp.CFrame = startCF:Lerp(target, eased)
			RunService.Heartbeat:Wait()
		end

		if not aborted and (run.status ~= "Hooking" or not hrp.Parent or creature.removed) then
			aborted = true
		end

		if aborted then
			if creature.rider == player then
				creature.rider = nil
			end
			if hrp.Parent then
				hrp.Anchored = false
			end
			-- Si le joueur est toujours en jeu (la bête a disparu), il tombe.
			if run.status == "Hooking" and player.Parent then
				downPlayer(player, run)
			end
			return
		end

		if RideService.Mount(player, run, creature) then
			onHookSuccess(player, run, creature, distance)
		else
			creature.rider = nil
			downPlayer(player, run)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Fin de course d'un joueur
-- ---------------------------------------------------------------------------

function RideService.Eliminate(player, run, reason)
	if run.status == "Out" or run.status == "Finished" then
		return
	end
	RideService.Detach(run)
	run.status = "Out"
	Remotes.Status:FireClient(player, "Out")
	player:SetAttribute("TameProgress", 0)
	feedback(player, "out", "ÉLIMINÉ", reason or "Tu es hors course.")
	RideService.ToLobby(player)
end

local function finish(player, run)
	State.FinishCount = State.FinishCount + 1
	local place = State.FinishCount
	run.finishPlace = place
	local bonus = Config.Score.Finish[place] or Config.Score.FinishOther
	addScore(run, bonus)
	RideService.Detach(run)
	run.status = "Finished"
	Remotes.Status:FireClient(player, "Finished")
	player:SetAttribute("TameProgress", 0)
	feedback(player, "finish", "ARRIVÉE !", ("%de · +%d pts"):format(place, bonus))
	local char, hrp, hum = getParts(player)
	if char then
		hrp.Anchored = false
		hum.Sit = false
		char:PivotTo(State.FinishCFrame * CFrame.new((rng:NextNumber() - 0.5) * 80, 0, (rng:NextNumber() - 0.5) * 40))
	end
end

-- ---------------------------------------------------------------------------
-- Boucle principale (appelée à chaque Heartbeat pendant la manche)
-- ---------------------------------------------------------------------------

local function publish(player, run, now)
	player:SetAttribute("RunScore", math.floor(run.score))
	player:SetAttribute("Combo", run.combo)
	local left = 0
	if run.combo > 0 then
		left = math.clamp(1 - (now - run.lastHookT) / comboWindow(player), 0, 1)
	end
	player:SetAttribute("ComboLeft", math.floor(left * 20) / 20)
	player:SetAttribute("ComboMult", math.floor(comboMult(run) * 10) / 10)
	local c = run.creature
	if c and run.status == "Riding" and not c.tamed then
		local needed = tameTimeNeeded(player, c)
		player:SetAttribute("TameProgress", math.floor(math.clamp(run.tameT / needed, 0, 1) * 20) / 20)
	elseif c and c.tamed then
		player:SetAttribute("TameProgress", 1)
	end
end

local function stepRiding(player, run, hum, hrp, dt, now)
	local c = run.creature
	if not c or c.removed or c.rider ~= player then
		downPlayer(player, run)
		return
	end
	run.mountT = run.mountT + dt

	local rate = Config.Score.RidePerSecond * c.def.value * c.variant.mult * comboMult(run)
	addScore(run, rate * dt)

	if run.combo > 0 and now - run.lastHookT > comboWindow(player) then
		run.combo = 0
	end

	if not c.tamed then
		run.tameT = run.tameT + dt
		if run.tameT >= tameTimeNeeded(player, c) then
			doTame(player, run, c)
		end
	end

	local buckAfter = c.def.buckAfter
	if buckAfter then
		if run.mountT >= buckAfter - Config.Ride.BuckWarning and not c.angry then
			c.angry = true
			c.model:SetAttribute("Angry", true)
			feedback(player, "warn", "ATTENTION !", "La bête s'énerve : bondis avant qu'elle te désarçonne !")
		end
		if run.mountT >= buckAfter then
			local velocity = Vector3.new(c.vx, Config.Ride.LaunchUp * 1.12, c.speed * 1.2 + Config.Ride.LaunchBoost)
			if launch(player, run, velocity) then
				feedback(player, "buck", "DÉSARÇONNÉ !", "Bond bonus : rattrape une autre bête !")
			end
		end
	end
end

local function stepAir(player, run, hrp, now)
	local elapsed = now - run.airStart
	local pos = hrp.Position
	local tooFast = hrp.AssemblyLinearVelocity.Magnitude > 260
	if elapsed > Config.Ride.AirMax or tooFast or pos.Y < -30 then
		downPlayer(player, run)
	elseif elapsed > 0.2 and pos.Y < Config.Track.FloorTop + 5.5 then
		downPlayer(player, run)
	end
end

function RideService.Step(dt)
	local now = os.clock()
	for player, run in pairs(State.Participants) do
		local status = run.status
		if status ~= "Out" and status ~= "Finished" then
			local _, hrp, hum = getParts(player)
			if not hrp then
				RideService.Eliminate(player, run, "Tu as quitté la course.")
			else
				local pos = hrp.Position
				run.z = pos.Z

				if pos.Z > run.bestZ then
					local gain = pos.Z - run.bestZ
					run.bestZ = pos.Z
					run.distance = run.distance + gain
					addScore(run, gain * Config.Score.DistanceFactor)
				end

				if pos.Z < State.WallZ + 2 then
					RideService.Eliminate(player, run, "Le mur de lave t'a rattrapé !")
				elseif pos.Z >= Config.Track.FinishZ and status ~= "Hooking" then
					finish(player, run)
				else
					if status == "Riding" then
						stepRiding(player, run, hum, hrp, dt, now)
					elseif status == "Air" then
						stepAir(player, run, hrp, now)
					elseif status == "Down" then
						if pos.Y < -30 or now >= run.downUntil then
							rescue(player, run)
						end
					end
				end

				run.pubT = run.pubT + dt
				if run.pubT >= 0.1 then
					run.pubT = 0
					publish(player, run, now)
				end
			end
		end
	end
end

function RideService.Init()
	Remotes.Launch.OnServerEvent:Connect(RideService.HandleLaunch)
	Remotes.Steer.OnServerEvent:Connect(RideService.HandleSteer)
	Remotes.Hook.OnServerEvent:Connect(RideService.HandleHook)

	Players.PlayerRemoving:Connect(function(player)
		local run = State.Participants[player]
		if run then
			RideService.Detach(run)
			run.status = "Out"
		end
	end)
end

return RideService

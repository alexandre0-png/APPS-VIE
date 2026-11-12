-- Cœur du gameplay : monter un animal, bondir, lasso, cœurs et captures, vies, boss, zones, arrivée.
-- Le serveur est autoritaire : positions des bêtes, portée du lasso, score et états sont validés ici.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Zoo = require(Shared.Zoo)

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
	return Config.Ride.ComboWindowBase
		+ Config.Ride.ComboWindowPerLevel * ProgressService.GetUpgradeLevel(player, "combo")
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

function RideService.NewRun(lives, lassoCharges)
	return {
		lives = lives or Config.Run.BaseLives,
		maxLives = lives or Config.Run.BaseLives,
		lasso = lassoCharges or Config.Run.BaseLasso,
		lassoAt = 0,
		captures = 0,
		gold = 0,
		bones = 0,
		names = {},
		zoneIdx = 1,
		deadAt = 0,
		revived = false,
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
	local home = State.PlotCFrames[player] or State.LobbyCFrame
	char:PivotTo(home * CFrame.new((rng:NextNumber() - 0.5) * 6, 0, (rng:NextNumber() - 0.5) * 6))
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
	run.lastCreatureUntil = os.clock() + (run.creature and run.creature.boss and 0.4 or 1.0)
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

-- Le joueur titube sans perdre de vie (animal disparu, accroche avortée) ; il est remonté sur un animal.
local function stumble(player, run)
	run.combo = 0
	run.downUntil = os.clock() + Config.Ride.DownTime
	local _, hrp = getParts(player)
	if hrp then
		hrp.Anchored = false
	end
	player:SetAttribute("TameProgress", 0)
	setStatus(player, run, "Down")
end

-- Mort : plus de vie. Une fenêtre permet d'acheter « Continuer » avant le retour au zoo.
local function die(player, run)
	RideService.Detach(run)
	local zone = Config.zoneAt(run.z)
	run.deadAt = os.clock()
	local _, hrp = getParts(player)
	if hrp then
		hrp.Anchored = true
		Fx.burst(hrp.Position, zone.hazard.color, 40, 40)
	end
	player:SetAttribute("TameProgress", 0)
	setStatus(player, run, "Dead")
	feedback(player, "out", "TOMBÉ !", zone.hazard.death)
end

-- Le joueur touche le sol mortel : il perd une vie, ou meurt s'il n'en a plus.
local function downPlayer(player, run, title)
	run.combo = 0
	run.lives = run.lives - 1
	local _, hrp = getParts(player)
	if hrp then
		Fx.burst(hrp.Position - Vector3.new(0, 2, 0), Config.zoneAt(run.z).hazard.color, 24, 22)
	end
	if run.lives <= 0 then
		die(player, run)
		return
	end
	stumble(player, run)
	feedback(player, "down", title or "VIE PERDUE !", ("Il te reste %d vie(s). Rattrape un animal !"):format(run.lives))
end

-- « Continuer » acheté pendant la fenêtre de mort : une vie de plus, retour sur un animal.
function RideService.Revive(player)
	local run = State.Participants[player]
	if not run or run.status ~= "Dead" or State.Phase ~= "Running" then
		return false
	end
	if os.clock() - run.deadAt > Config.Run.ReviveWindow then
		return false
	end
	run.lives = 1
	run.revived = true
	local _, hrp = getParts(player)
	if hrp then
		hrp.Anchored = false
	end
	feedback(player, "tame", "ON REPART !", "Tu as une vie de plus.")
	stumble(player, run)
	return true
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
	run.combo = 0
	run.airStart = os.clock()
	setStatus(player, run, "Air")
	Remotes.Launched:FireClient(player, Vector3.new(0, 45, 20))
	feedback(player, "down", "TOUCHÉ !", "Rattrape un animal avant de tomber !")
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
		creature = CreatureService.Spawn(x, pos.Z + 14, nil, 1, 1)
	end
	RideService.Mount(player, run, creature)
end

-- ---------------------------------------------------------------------------
-- Combo, dressage
-- ---------------------------------------------------------------------------

local function onHookSuccess(player, run, distance)
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

-- Secondes en selle pour gagner la confiance d'un animal à cœur.
local function tameTimeNeeded(player, creature)
	if creature.boss then
		return creature.def.bossRide
	end
	local level = ProgressService.GetUpgradeLevel(player, "taming")
	local factor = 1 - Config.Tame.PerLevel * level
	return math.max(Config.Tame.MinTime, creature.def.tameTime * factor)
end

local function creatureLabel(creature)
	local name = creature.def.name
	if creature.variantIdx > 1 and not creature.boss then
		name = name .. " " .. creature.variant.name
	end
	return name
end

-- La confiance est gagnée : le cœur bat, le joueur a quelques secondes pour récupérer l'animal.
local function markReady(player, creature)
	creature.tamed = true
	creature.tamedBy = player
	creature.collectUntil = os.clock() + Config.Run.CollectWindow
	creature.model:SetAttribute("Ready", true)
	feedback(player, "tame", "♥ RÉCUPÈRE-LE !", "Appuie sur RÉCUPÉRER avant qu'il ne t'échappe.")
	Fx.burst(creature.root.Position + Vector3.new(0, 5, 0), Color3.fromRGB(255, 120, 170), 30, 26)
end

-- Le cœur disparaît : l'animal a repris sa liberté (désarçonnement avant la récupération).
local function loseHeart(creature)
	creature.hearted = false
	creature.tamed = false
	creature.tamedBy = nil
	if not creature.removed then
		creature.model:SetAttribute("Heart", false)
		creature.model:SetAttribute("Ready", false)
	end
end

-- L'animal rejoint le zoo : or, os, points, effets. `how` = "ride" ou "lasso".
local function captureCreature(player, run, creature, how)
	local result = ProgressService.RecordCapture(player, creature.def, creature.variantIdx)
	run.captures = run.captures + 1
	run.gold = run.gold + result.gold
	run.bones = run.bones + result.bones
	table.insert(run.names, creatureLabel(creature))
	local points = Config.Score.CapturePoints * creature.def.value * Zoo.variantMult(creature.def, creature.variantIdx)
	addScore(run, points)

	local name = creatureLabel(creature)
	local title = result.new and "NOUVEAU PENSIONNAIRE !" or "DÉJÀ AU ZOO !"
	local sub = ("%s · +%d or"):format(name, result.gold)
	if result.bones > 0 then
		sub = sub .. (" · +%d os"):format(result.bones)
	end
	if result.complete then
		sub = sub .. " · ESPÈCE COMPLÈTE !"
	end
	Fx.burst(creature.root.Position + Vector3.new(0, 5, 0), Color3.fromRGB(255, 120, 170), 50, 34)
	if creature.boss then
		Remotes.Feedback:FireAllClients({
			kind = "event",
			title = "BOSS CAPTURÉ !",
			sub = player.DisplayName .. " a gagné " .. name,
		})
	else
		feedback(player, "tame", title, sub)
	end
	if how == "ride" then
		-- l'animal part au zoo en bondissant : le joueur est propulsé en avant
		launch(
			player,
			run,
			Vector3.new(creature.vx, Config.Ride.LaunchUp * 1.1, creature.speed + Config.Ride.LaunchBoost * 1.5)
		)
	end
	CreatureService.Remove(creature)
	return result
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
			-- Si le joueur est toujours en jeu (l'animal a disparu), il titube puis est remonté.
			if run.status == "Hooking" and player.Parent then
				stumble(player, run)
			end
			return
		end

		if RideService.Mount(player, run, creature) then
			onHookSuccess(player, run, distance)
		else
			creature.rider = nil
			stumble(player, run)
		end
	end)
end

-- Récupérer l'animal qu'on monte (confiance gagnée, cœur prêt).
function RideService.HandleCollect(player)
	if State.Phase ~= "Running" or not Util.allow(player, "Collect", 0.3) then
		return
	end
	local run = State.Participants[player]
	local c = run and run.creature
	if not run or run.status ~= "Riding" or not c or c.removed or c.rider ~= player then
		return
	end
	if not c.tamed or c.tamedBy ~= player or os.clock() > c.collectUntil then
		return
	end
	captureCreature(player, run, c, "ride")
end

-- Lasso de capture : vise un animal à cœur à distance (visée assistée côté client, tout est revalidé ici).
function RideService.HandleLasso(player, id)
	if not Util.isFiniteNumber(id) or id % 1 ~= 0 or State.Phase ~= "Running" then
		return
	end
	local run = State.Participants[player]
	if not run or (run.status ~= "Riding" and run.status ~= "Air" and run.status ~= "Down") then
		return
	end
	if run.lasso <= 0 or os.clock() - run.lassoAt < Config.Run.LassoCooldown then
		return
	end
	if not Util.allow(player, "Lasso", 0.5) then
		return
	end
	local creature = State.Creatures[id]
	if not creature or creature.removed or creature.rider or not creature.hearted or creature.boss then
		return
	end
	local _, hrp = getParts(player)
	if not hrp then
		return
	end
	local range = (player:GetAttribute("LassoRange") or Config.Run.LassoRange) + Config.Ride.HookTolerance
	local distance = (creature.root.Position - hrp.Position).Magnitude
	if distance > range then
		return
	end

	run.lasso = run.lasso - 1
	run.lassoAt = os.clock()
	spawnRope(player, hrp, creature, 0.35)
	local chance = Config.Run.LassoBaseChance - Config.Run.LassoVariantPenalty * (creature.variantIdx - 1)
	if rng:NextNumber() <= chance then
		task.delay(0.3, function()
			if
				not creature.removed
				and creature.hearted
				and not creature.rider
				and State.Participants[player] == run
			then
				captureCreature(player, run, creature, "lasso")
			end
		end)
	else
		feedback(player, "warn", "RATÉ !", ("L'animal s'est débattu. Il te reste %d lasso(s)."):format(run.lasso))
	end
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
	feedback(player, "out", "FIN D'EXPÉDITION", reason or "Tu es hors course.")
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
	feedback(player, "finish", "EXPÉDITION COMPLÈTE !", ("%de · +%d pts"):format(place, bonus))
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
	player:SetAttribute("Lives", run.lives)
	player:SetAttribute("MaxLives", run.maxLives)
	player:SetAttribute("Lasso", run.lasso)
	player:SetAttribute("Captures", run.captures)
	player:SetAttribute("RunGold", run.gold)
	player:SetAttribute("ZoneIdx", run.zoneIdx)
	local c = run.creature
	local hearted = c ~= nil and run.status == "Riding" and c.hearted
	player:SetAttribute("RideHeart", hearted)
	player:SetAttribute("CanCollect", hearted and c.tamed and c.tamedBy == player or false)
	player:SetAttribute("RideBoss", c ~= nil and c.boss or false)
	if hearted and not c.tamed then
		local needed = tameTimeNeeded(player, c)
		local got = c.boss and (c.progress[player] or 0) or run.tameT
		player:SetAttribute("TameProgress", math.floor(math.clamp(got / needed, 0, 1) * 20) / 20)
	elseif hearted then
		player:SetAttribute("TameProgress", 1)
	else
		player:SetAttribute("TameProgress", 0)
	end
	if run.status == "Dead" then
		player:SetAttribute("ReviveLeft", math.max(0, math.ceil(Config.Run.ReviveWindow - (now - run.deadAt))))
	else
		player:SetAttribute("ReviveLeft", 0)
	end
end

local function stepRiding(player, run, hrp, dt, now)
	local c = run.creature
	if not c or c.removed or c.rider ~= player then
		stumble(player, run)
		return
	end
	run.mountT = run.mountT + dt

	-- filet de sécurité : si la soudure ne suit pas l'animal (physique inattendue), on recale le cavalier
	local seat = CreatureService.SeatWorldCFrame(c)
	if (hrp.Position - seat.Position).Magnitude > 4 then
		hrp.CFrame = seat
	end

	local rate = Config.Score.RidePerSecond * c.def.value * Zoo.variantMult(c.def, c.variantIdx) * comboMult(run)
	addScore(run, rate * dt)

	if run.combo > 0 and now - run.lastHookT > comboWindow(player) then
		run.combo = 0
	end

	-- confiance : seulement sur un animal à cœur
	if c.hearted and not c.tamed then
		if c.boss then
			c.progress[player] = (c.progress[player] or 0) + dt
			if c.progress[player] >= tameTimeNeeded(player, c) then
				markReady(player, c)
			end
		else
			run.tameT = run.tameT + dt
			if run.tameT >= tameTimeNeeded(player, c) then
				markReady(player, c)
			end
		end
	end

	-- l'animal prêt s'échappe si on ne le récupère pas à temps
	if c.tamed and now > c.collectUntil then
		loseHeart(c)
		feedback(player, "down", "IL T'A ÉCHAPPÉ !", "Le cœur a disparu. Rattrape un autre animal !")
		launch(player, run, Vector3.new(c.vx, Config.Ride.LaunchUp * 1.12, c.speed * 1.2 + Config.Ride.LaunchBoost))
		return
	end

	local buckAfter = c.boss and Config.Run.BossBuckAfter or c.def.buckAfter
	if buckAfter then
		if run.mountT >= buckAfter - Config.Ride.BuckWarning and not c.angry then
			c.angry = true
			c.model:SetAttribute("Angry", true)
			feedback(player, "warn", "ATTENTION !", "L'animal s'énerve : bondis avant qu'il te désarçonne !")
		end
		if run.mountT >= buckAfter then
			if c.tamed then
				loseHeart(c)
			end
			-- un boss te projette en arrière : il file devant et tu peux le relasser pour continuer
			local forward = c.boss and c.speed * 0.55 or c.speed * 1.2 + Config.Ride.LaunchBoost
			local velocity = Vector3.new(c.vx, Config.Ride.LaunchUp * 1.12, forward)
			if launch(player, run, velocity) then
				if c.boss then
					feedback(player, "buck", "IL T'A PROJETÉ !", "Relance-toi sur le boss : ta confiance est gardée.")
				else
					feedback(player, "buck", "DÉSARÇONNÉ !", "Bond bonus : rattrape un autre animal !")
				end
			end
		end
	end
end

local function stepAir(player, run, hrp, now)
	local elapsed = now - run.airStart
	local pos = hrp.Position
	local tooFast = hrp.AssemblyLinearVelocity.Magnitude > 260
	local touchedGround = elapsed > 0.2 and pos.Y < Config.Track.FloorTop + 5.5
	if elapsed > Config.Ride.AirMax or tooFast or pos.Y < -30 or touchedGround then
		downPlayer(player, run)
	end
end

-- Zone atteinte : bannière, quête, boss de la zone.
local function trackZones(player, run, pos)
	local idx = Config.zoneIndex(pos.Z)
	if idx > run.zoneIdx then
		run.zoneIdx = idx
		local zone = Config.Zones[idx]
		ProgressService.NoteZone(player, idx)
		feedback(player, "event", "ZONE " .. idx .. " : " .. zone.name, "Danger : " .. zone.hazard.name .. " !")
	end
	-- le boss d'une zone apparaît quand le premier joueur approche de sa fin
	for index, zone in ipairs(Config.Zones) do
		local limit = math.min(zone.to, Config.Track.FinishZ)
		if not State.BossesSpawned[index] and index == idx and pos.Z >= limit - 330 then
			State.BossesSpawned[index] = true
			local x = (rng:NextNumber() * 2 - 1) * (Config.Track.HalfWidth - 14)
			local boss = CreatureService.Spawn(x, pos.Z + 160, zone.boss, 1, 1)
			Remotes.Feedback:FireAllClients({
				kind = "danger",
				title = "BOSS : " .. boss.def.name:upper(),
				sub = "Monte-le 9 s pour le récupérer. Il se débat !",
			})
			workspace:SetAttribute("BossActive", true)
		end
	end
end

function RideService.Step(dt)
	local now = os.clock()
	for player, run in pairs(State.Participants) do
		local status = run.status
		if status == "Dead" then
			if now - run.deadAt > Config.Run.ReviveWindow then
				RideService.Eliminate(player, run, "Ton expédition s'arrête ici.")
			end
			run.pubT = run.pubT + dt
			if run.pubT >= 0.1 then
				run.pubT = 0
				publish(player, run, now)
			end
		elseif status ~= "Out" and status ~= "Finished" then
			local _, hrp = getParts(player)
			if not hrp then
				RideService.Eliminate(player, run, "Tu as quitté l'expédition.")
			else
				local pos = hrp.Position
				run.z = pos.Z

				if pos.Z > run.bestZ then
					local gain = pos.Z - run.bestZ
					run.bestZ = pos.Z
					run.distance = run.distance + gain
					addScore(run, gain * Config.Score.DistanceFactor)
				end
				trackZones(player, run, pos)

				if pos.Z >= Config.Track.FinishZ and status ~= "Hooking" then
					finish(player, run)
				else
					if status == "Riding" then
						stepRiding(player, run, hrp, dt, now)
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
	Remotes.Collect.OnServerEvent:Connect(RideService.HandleCollect)
	Remotes.Lasso.OnServerEvent:Connect(RideService.HandleLasso)

	Players.PlayerRemoving:Connect(function(player)
		local run = State.Participants[player]
		if run then
			RideService.Detach(run)
			run.status = "Out"
		end
	end)
end

return RideService

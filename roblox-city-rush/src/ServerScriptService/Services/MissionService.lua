--[[
	MissionService : livraison, taxi, course de rue, braquage.
	Tout est validé côté serveur : positions des objectifs, temps, récompenses.
	Le client ne reçoit que l'état d'affichage (titre, objectif, position, échéance).
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local VehicleService = require(script.Parent.VehicleService)
local WantedService = require(script.Parent.WantedService)
local PedestrianService = require(script.Parent.PedestrianService)

local MissionService = {}

local rng = Random.new()
local World
local active = {} -- [player] = mission
local cooldowns = {} -- [player] = { [type] = os.clock() }
local passenger = {} -- [player] = model (passager de taxi visible au point de prise en charge)

local function now()
	return workspace:GetServerTimeNow()
end

local function hrpOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function seated(player)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.SeatPart ~= nil
end

local function sendMission(player)
	local m = active[player]
	if not m then
		RemoteService.fire("Mission", player, nil)
		return
	end
	RemoteService.fire("Mission", player, {
		type = m.type,
		title = m.title,
		text = m.text,
		target = m.target,
		radius = m.radius,
		deadline = m.deadline,
		step = m.step,
		steps = m.steps,
		reward = m.reward,
		color = m.color,
	})
end

local function clearPassenger(player)
	local p = passenger[player]
	if p then
		p:Destroy()
		passenger[player] = nil
	end
end

local function finish(player, success, message, kind)
	local m = active[player]
	if not m then
		return
	end
	active[player] = nil
	clearPassenger(player)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][m.type] = os.clock()
	if message then
		RemoteService.notify(player, message, kind or (success and "good" or "bad"))
	end
	sendMission(player)
end

local function reward(player, cash, xp, statKey)
	local paid = EconomyService.addCash(player, cash, "mission")
	EconomyService.addXP(player, xp)
	EconomyService.addStat(player, "missions", 1)
	if statKey then
		EconomyService.addStat(player, statKey, 1)
	end
	return paid
end

local function pickFar(list, from, minD, maxD)
	local candidates = {}
	for _, p in ipairs(list) do
		local d = Util.flatDistance(p, from)
		if d >= minD and d <= maxD then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		for _, p in ipairs(list) do
			if Util.flatDistance(p, from) >= minD then
				table.insert(candidates, p)
			end
		end
	end
	if #candidates == 0 then
		candidates = list
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- ====================================================================
-- Démarrage des missions
-- ====================================================================
local function canStart(player, kind)
	local profile = DataService.get(player)
	local cfg = Config.Missions[kind]
	if not profile or not cfg then
		return false
	end
	if active[player] then
		RemoteService.notify(player, "Termine ou abandonne ta mission en cours.", "info")
		return false
	end
	if profile.Level < cfg.minLevel then
		RemoteService.notify(player, string.format("%s : niveau %d requis.", cfg.title, cfg.minLevel), "bad")
		return false
	end
	local cd = cooldowns[player] and cooldowns[player][kind]
	if cd and os.clock() - cd < cfg.cooldown then
		RemoteService.notify(player, string.format("Reviens dans %d s.", math.ceil(cfg.cooldown - (os.clock() - cd))), "info")
		return false
	end
	if kind ~= "heist" and WantedService.getStars(player) > 0 then
		RemoteService.notify(player, "Tu es recherché ! Sème la police d'abord.", "bad")
		return false
	end
	local hrp = hrpOf(player)
	if not hrp then
		return false
	end
	return true, profile, cfg, hrp
end

local function startDelivery(player)
	local ok, profile, cfg, hrp = canStart(player, "delivery")
	if not ok then
		return
	end
	local target = pickFar(World.DeliveryPoints, hrp.Position, 180, 700)
	local dist = Util.flatDistance(target, hrp.Position)
	local limit = cfg.timeBase + dist / cfg.studsPerSec
	active[player] = {
		type = "delivery", title = cfg.title, text = "Livre la pizza avant la fin du temps !",
		target = target, radius = 9, startPos = hrp.Position, dist = dist,
		deadline = now() + limit, limit = limit, step = 1, steps = 1,
		reward = math.floor(cfg.baseReward + dist * cfg.perStud), color = Color3.fromRGB(255, 150, 80),
	}
	RemoteService.notify(player, "Pizza chargée ! Direction le point de livraison.", "good")
	sendMission(player)
end

local function startTaxi(player)
	local ok, profile, cfg, hrp = canStart(player, "taxi")
	if not ok then
		return
	end
	if not seated(player) then
		RemoteService.notify(player, "Monte dans une voiture pour faire le taxi.", "info")
		return
	end
	local pickup = pickFar(World.TaxiStops, hrp.Position, 40, 450)
	local drop = pickFar(World.TaxiStops, pickup, 250, 800)
	local limit = cfg.timeBase + (Util.flatDistance(pickup, hrp.Position) + Util.flatDistance(pickup, drop)) / cfg.studsPerSec
	active[player] = {
		type = "taxi", title = cfg.title, text = "Va chercher le client.",
		target = pickup, radius = 14, pickup = pickup, drop = drop, startPos = hrp.Position,
		deadline = now() + limit, limit = limit, step = 1, steps = 2,
		reward = math.floor(cfg.baseReward + Util.flatDistance(pickup, drop) * cfg.perStud), color = Color3.fromRGB(255, 214, 0),
	}
	-- passager visible
	task.spawn(function()
		local rig = PedestrianService.newRig({
			head = Color3.fromRGB(234, 184, 146), torso = Color3.fromRGB(240, 130, 60),
			arms = Color3.fromRGB(240, 130, 60), legs = Color3.fromRGB(50, 60, 90),
		})
		if rig then
			rig.Name = "Client"
			rig:PivotTo(CFrame.new(pickup + Vector3.new(0, 3, 0)))
			local r = rig:FindFirstChild("HumanoidRootPart")
			if r then
				r.Anchored = true
			end
			rig.Parent = workspace
			if active[player] and active[player].pickup == pickup then
				passenger[player] = rig
			else
				rig:Destroy()
			end
		end
	end)
	RemoteService.notify(player, "Client en attente ! Va le chercher.", "good")
	sendMission(player)
end

local function startRace(player)
	local ok, profile, cfg, hrp = canStart(player, "race")
	if not ok then
		return
	end
	if not seated(player) then
		RemoteService.notify(player, "Il faut un véhicule pour courir !", "info")
		return
	end
	local circuit = World.RaceCircuit
	active[player] = {
		type = "race", title = cfg.title, text = "Passe tous les points de contrôle !",
		target = circuit[1], radius = 32, index = 1, startPos = hrp.Position,
		deadline = now() + cfg.timeLimit, limit = cfg.timeLimit, startedAt = now(),
		step = 1, steps = #circuit, reward = cfg.baseReward, color = Color3.fromRGB(255, 70, 70),
	}
	RemoteService.notify(player, "Course lancée ! Fonce !", "good")
	sendMission(player)
end

local crackers = {} -- joueurs en train de percer le coffre

local function startHeist(player)
	local ok, profile, cfg, hrp = canStart(player, "heist")
	if not ok then
		return
	end
	active[player] = {
		type = "heist", title = cfg.title, text = "Rejoins la planque avec le butin !",
		target = World.Hideout, radius = 12, startPos = hrp.Position,
		deadline = now() + 240, limit = 240, step = 1, steps = 1,
		reward = cfg.baseReward, color = Color3.fromRGB(80, 255, 120),
	}
	WantedService.addHeat(player, Config.Wanted.HeistHeat, "Braquage")
	RemoteService.notify(player, "Coffre vidé ! La police arrive, fonce à la planque !", "bad")
	sendMission(player)
end

local STARTERS = { delivery = startDelivery, taxi = startTaxi, race = startRace, heist = startHeist }

-- ====================================================================
-- Progression (boucle 4 Hz)
-- ====================================================================
local function completeMission(player, m)
	local cfg = Config.Missions[m.type]
	local t = now()
	if m.type == "delivery" then
		local timeLeft = m.deadline - t
		local bonus = math.floor(math.max(0, timeLeft) * 2)
		local paid = reward(player, m.reward + bonus, cfg.xp, "deliveries")
		finish(player, true, string.format("Livraison réussie ! +%s", Util.formatCash(paid)))
	elseif m.type == "taxi" then
		local timeLeft = m.deadline - t
		local bonus = math.floor(math.max(0, timeLeft) * 3)
		local paid = reward(player, m.reward + bonus, cfg.xp, "taxis")
		finish(player, true, string.format("Course terminée ! +%s", Util.formatCash(paid)))
	elseif m.type == "race" then
		local elapsed = t - m.startedAt
		local timeLeft = math.max(0, m.deadline - t)
		local bonus = math.floor(timeLeft * 10)
		local paid = reward(player, m.reward + bonus, cfg.xp, "races")
		local profile = DataService.get(player)
		if profile and (profile.Stats.bestRace == 0 or elapsed < profile.Stats.bestRace) then
			profile.Stats.bestRace = math.floor(elapsed * 10) / 10
			DataService.markDirty(player)
		end
		finish(player, true, string.format("Course gagnée en %s ! +%s", Util.formatTime(elapsed), Util.formatCash(paid)))
	elseif m.type == "heist" then
		local paid = reward(player, m.reward, cfg.xp, "heists")
		finish(player, true, string.format("Casse réussi ! +%s", Util.formatCash(paid)))
	end
end

local function step()
	for player, m in pairs(active) do
		local hrp = hrpOf(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			finish(player, false, "Mission échouée.")
		elseif now() > m.deadline then
			finish(player, false, "Temps écoulé ! Mission échouée.")
		else
			local near = Util.flatDistance(hrp.Position, m.target) <= m.radius and math.abs(hrp.Position.Y - m.target.Y) < 30
			if near then
				if m.type == "taxi" then
					if m.step == 1 and seated(player) then
						clearPassenger(player)
						m.step = 2
						m.target = m.drop
						m.text = "Dépose le client à destination."
						RemoteService.notify(player, "Client à bord ! En route.", "good")
						sendMission(player)
					elseif m.step == 2 and seated(player) then
						completeMission(player, m)
					end
				elseif m.type == "race" then
					if not seated(player) then
						-- on exige d'être en véhicule : pas de raccourci à pied
					elseif m.index >= #World.RaceCircuit then
						completeMission(player, m)
					else
						m.index += 1
						m.step = m.index
						m.target = World.RaceCircuit[m.index]
						sendMission(player)
					end
				else
					completeMission(player, m)
				end
			end
		end
	end
end

-- ====================================================================
-- Prompts
-- ====================================================================
local function attachMissionPrompt(pad)
	local kind = pad:GetAttribute("Mission")
	if not STARTERS[kind] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = pad:GetAttribute("Label") or "Démarrer"
	prompt.ObjectText = Config.Missions[kind].title
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	if kind == "heist" then
		prompt.HoldDuration = Config.Missions.heist.crackTime
		prompt.ActionText = "Percer le coffre"
	else
		prompt.HoldDuration = 0.3
	end
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		STARTERS[kind](player)
	end)
end

local function attachDealerPrompt(pad)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Voir les véhicules"
	prompt.ObjectText = "Concessionnaire"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		RemoteService.fire("OpenPanel", player, "dealer")
	end)
end

function MissionService.failFor(player, message)
	if active[player] then
		finish(player, false, message)
	end
end

function MissionService.init(world)
	World = world
	for _, pad in ipairs(CollectionService:GetTagged("MissionHub")) do
		attachMissionPrompt(pad)
	end
	for _, pad in ipairs(CollectionService:GetTagged("DealerHub")) do
		attachDealerPrompt(pad)
	end

	RemoteService.on("AbandonMission", 1, nil, function(player)
		if active[player] then
			finish(player, false, "Mission abandonnée.", "info")
		end
	end)

	WantedService.Busted:Connect(function(player)
		local m = active[player]
		if m then
			if m.type == "heist" then
				finish(player, false, "Butin confisqué par la police !", "bad")
			else
				finish(player, false, "Mission interrompue.", "bad")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPassenger(player)
		active[player] = nil
		cooldowns[player] = nil
		crackers[player] = nil
	end)
end

function MissionService.start()
	Util.supervise("MissionService", function()
		while true do
			task.wait(0.25)
			step()
		end
	end)
end

return MissionService

-- Boucle d'expéditions : attente des joueurs prêts -> compte à rebours -> expédition -> résultats.
-- Les joueurs prêts partent ensemble dans la zone choisie par la majorité. Les récompenses sont versées ici.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local CreatureService = require(script.Parent.CreatureService)
local RideService = require(script.Parent.RideService)
local EventService = require(script.Parent.EventService)
local Fx = require(script.Parent.Fx)
local MapBuilder = require(script.Parent.MapBuilder)

local RoundService = {}

local function isReady(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hrp ~= nil and hum.Health > 0 and DataService.Get(player) ~= nil
end

-- Joueurs qui ont choisi de partir (bouton « Partir en expédition »).
local function readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if State.Ready[player] and isReady(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function broadcastScores()
	local list = {}
	for player, run in pairs(State.Participants) do
		table.insert(list, { n = player.DisplayName, s = math.floor(run.score), st = run.status, id = player.UserId })
	end
	table.sort(list, function(a, b)
		return a.s > b.s
	end)
	local top = {}
	for i = 1, math.min(#list, 12) do
		top[i] = list[i]
	end
	Remotes.Scores:FireAllClients(top)
end

local function intermission()
	local waiting = true
	workspace:SetAttribute("Waiting", true)
	State.SetPhase("Intermission", 0)
	local endAt = 0
	local lastText = 0

	while true do
		local ready = #readyPlayers()
		workspace:SetAttribute("ReadyCount", ready)
		if ready >= Config.Round.MinPlayers then
			if waiting then
				waiting = false
				endAt = os.clock() + Config.Round.Intermission
				workspace:SetAttribute("Waiting", false)
				State.SetPhase("Intermission", Config.Round.Intermission)
			end
			if os.clock() >= endAt then
				return
			end
		elseif not waiting then
			waiting = true
			workspace:SetAttribute("Waiting", true)
			State.SetPhase("Intermission", 0)
		end

		if os.clock() - lastText >= 1 then
			lastText = os.clock()
			if waiting then
				MapBuilder.SetStatus("Choisis ta zone et pars en expédition !")
			else
				MapBuilder.SetStatus(
					("Départ dans %d s (%d prêt(s))"):format(math.max(0, math.ceil(endAt - os.clock())), ready)
				)
			end
		end
		task.wait(0.25)
	end
end

local function startPositions(index)
	local col = (index - 1) % 6
	local row = math.floor((index - 1) / 6)
	return (col - 2.5) * 16, 8 + row * 16
end

-- Zone de départ : celle que choisit la majorité des joueurs prêts (égalité : la moins avancée).
local function chooseZone(participants)
	local votes = {}
	for _, player in ipairs(participants) do
		local data = DataService.Get(player)
		local _, index = Config.zoneByKey(data and data.zone or "savane")
		index = index or 1
		votes[index] = (votes[index] or 0) + 1
	end
	local best, bestVotes = 1, -1
	for index = 1, #Config.Zones do
		if (votes[index] or 0) > bestVotes then
			best, bestVotes = index, votes[index] or 0
		end
	end
	return best
end

local function computeResults(zoneIdx)
	local ranking = {}
	for player, run in pairs(State.Participants) do
		table.insert(ranking, { player = player, run = run })
	end
	table.sort(ranking, function(a, b)
		if a.run.score ~= b.run.score then
			return a.run.score > b.run.score
		end
		return a.run.distance > b.run.distance
	end)

	local competitive = #ranking >= 2
	local payload = {}

	for rank, entry in ipairs(ranking) do
		local player, run = entry.player, entry.run
		run.rank = rank
		local roundGold = Config.Rewards.Participation
		if player.Parent then
			roundGold = roundGold + ProgressService.GoldForRun(player, run.score)
		end
		if competitive then
			roundGold = roundGold + (Config.Rewards.Place[rank] or 0)
		end

		if player.Parent and DataService.Get(player) then
			local data = DataService.Get(player)
			data.rounds = data.rounds + 1
			data.hooks = data.hooks + run.hooks
			data.distance = data.distance + run.distance
			if rank == 1 and competitive then
				data.wins = data.wins + 1
			end
			if run.score > data.bestScore then
				data.bestScore = math.floor(run.score)
				DataService.SubmitBest(player, run.score)
			end
			DataService.MarkDirty(player)
			ProgressService.AddQuest(player, "rounds", 1)
			ProgressService.AddQuest(player, "hooks", run.hooks)
			ProgressService.AddQuest(player, "distance", math.floor(run.distance))
			ProgressService.AddQuest(player, "combo", run.maxCombo)
			ProgressService.AddQuest(player, "score", math.floor(run.score))
			ProgressService.AddCoins(player, roundGold)
		end

		table.insert(payload, {
			id = player.UserId,
			n = player.DisplayName,
			score = math.floor(run.score),
			rank = rank,
			gold = roundGold + run.gold,
			bones = run.bones,
			captures = run.captures,
			names = run.names,
			hooks = run.hooks,
			dist = math.floor(run.distance),
			finish = run.finishPlace,
			combo = run.maxCombo,
			zone = math.max(zoneIdx, run.zoneIdx),
		})
	end
	return payload
end

local function runRound()
	local participants = readyPlayers()
	if #participants < Config.Round.MinPlayers then
		return
	end

	State.RoundId = State.RoundId + 1
	local roundId = State.RoundId
	local zoneIdx = chooseZone(participants)
	local zone = Config.Zones[zoneIdx]
	local startZ = zone.start

	State.Participants = {}
	State.FinishCount = 0
	State.Frozen = true
	State.RunElapsed = 0
	State.StartZone = zoneIdx
	State.BossesSpawned = {}
	workspace:SetAttribute("BossActive", false)
	workspace:SetAttribute("StartZone", zoneIdx)
	CreatureService.Clear()
	Fx.clear()
	EventService.Reset()

	local heartBonus = 0
	for _, player in ipairs(participants) do
		local data = DataService.Get(player)
		heartBonus = math.max(heartBonus, Config.Zoo.HeartBonus * (data and data.zooUp.hearts or 0))
	end
	State.HeartBonus = heartBonus

	for index, player in ipairs(participants) do
		State.Ready[player] = nil
		local lives = ProgressService.Lives(player)
		ProgressService.ConsumeStoredRevive(player)
		local run = RideService.NewRun(lives, ProgressService.LassoCharges(player))
		State.Participants[player] = run
		local x, z = startPositions(index)
		z = startZ + z
		local starter = CreatureService.Spawn(x, z, zone.animals[1], 1, 1)
		run.z = z
		run.bestZ = z
		run.zoneIdx = zoneIdx
		ProgressService.NoteZone(player, zoneIdx)
		if not RideService.Mount(player, run, starter) then
			run.status = "Out"
		end
	end
	CreatureService.FillInitial(startZ)
	broadcastScores()

	-- Compte à rebours
	State.SetPhase("Countdown", Config.Round.Countdown)
	MapBuilder.SetStatus("Expédition en cours : " .. zone.name)
	task.wait(Config.Round.Countdown)

	-- Expédition
	State.Frozen = false
	State.SetPhase("Running", Config.Round.Duration)
	local endsAt = os.clock() + Config.Round.Duration
	local lastBroadcast = 0
	local allDoneSince = nil
	while os.clock() < endsAt and State.RoundId == roundId do
		task.wait(0.1)
		if os.clock() - lastBroadcast >= 0.5 then
			lastBroadcast = os.clock()
			broadcastScores()
		end
		if State.CountActive() == 0 then
			allDoneSince = allDoneSince or os.clock()
			if os.clock() - allDoneSince > 2.5 then
				break
			end
		else
			allDoneSince = nil
		end
	end

	-- Résultats
	State.Frozen = true
	State.SetPhase("Results", Config.Round.Results)
	workspace:SetAttribute("BossActive", false)
	broadcastScores()
	for _, run in pairs(State.Participants) do
		RideService.Detach(run)
		if run.status ~= "Out" and run.status ~= "Finished" then
			run.status = "Out"
		end
	end
	local payload = computeResults(zoneIdx)
	for player in pairs(State.Participants) do
		if player.Parent then
			RideService.ToLobby(player)
			for _, name in ipairs({ "TameProgress", "RideHeart", "CanCollect", "RideBoss", "ReviveLeft" }) do
				player:SetAttribute(name, nil)
			end
			player:SetAttribute("RideName", nil)
			Remotes.Status:FireClient(player, "Lobby")
		end
	end
	Remotes.Results:FireAllClients({ list = payload, round = roundId })
	MapBuilder.SetStatus("Résultats de l'expédition")
	task.wait(Config.Round.Results)

	-- Nettoyage
	State.Participants = {}
	CreatureService.Clear()
	Fx.clear()
end

function RoundService.Run()
	while true do
		intermission()
		runRound()
	end
end

return RoundService

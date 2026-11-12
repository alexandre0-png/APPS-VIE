-- Boucle de manches : Intermission -> Compte à rebours -> Course -> Résultats.
-- Les manches durent 2 minutes. Les récompenses sont calculées et versées ici.

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
local WallService = require(script.Parent.WallService)
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

local function readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if isReady(player) then
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
				MapBuilder.SetStatus("En attente de joueurs...")
			else
				MapBuilder.SetStatus(("Prochaine manche dans %d s"):format(math.max(0, math.ceil(endAt - os.clock()))))
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

local function computeResults()
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
		local roundCoins = math.floor(run.score * Config.Rewards.ScoreToCoins) + Config.Rewards.Participation
		if competitive then
			roundCoins = roundCoins + (Config.Rewards.Place[rank] or 0)
		end
		if player.Parent then
			roundCoins = math.floor(roundCoins * ProgressService.CoinMultiplier(player))
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
			ProgressService.AddCoins(player, roundCoins)
		end

		table.insert(payload, {
			id = player.UserId,
			n = player.DisplayName,
			score = math.floor(run.score),
			rank = rank,
			coins = roundCoins + run.coins,
			tames = run.tames,
			hooks = run.hooks,
			dist = math.floor(run.distance),
			finish = run.finishPlace,
			combo = run.maxCombo,
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

	State.Participants = {}
	State.FinishCount = 0
	State.Frozen = true
	CreatureService.Clear()
	Fx.clear()
	WallService.Reset()
	EventService.Reset()

	for index, player in ipairs(participants) do
		local run = RideService.NewRun()
		State.Participants[player] = run
		local x, z = startPositions(index)
		local starter = CreatureService.Spawn(x, z, "boar", 1, 1)
		run.z = z
		run.bestZ = z
		if not RideService.Mount(player, run, starter) then
			run.status = "Out"
		end
	end
	CreatureService.FillInitial()
	broadcastScores()

	-- Compte à rebours
	State.SetPhase("Countdown", Config.Round.Countdown)
	MapBuilder.SetStatus("Manche en cours...")
	task.wait(Config.Round.Countdown)

	-- Course
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
	broadcastScores()
	for _, run in pairs(State.Participants) do
		RideService.Detach(run)
		if run.status ~= "Out" and run.status ~= "Finished" then
			run.status = "Out"
		end
	end
	local payload = computeResults()
	for player in pairs(State.Participants) do
		if player.Parent then
			RideService.ToLobby(player)
			player:SetAttribute("TameProgress", 0)
			player:SetAttribute("RideName", nil)
			Remotes.Status:FireClient(player, "Lobby")
		end
	end
	Remotes.Results:FireAllClients({ list = payload, round = roundId })
	MapBuilder.SetStatus("Résultats de la manche")
	task.wait(Config.Round.Results)

	-- Nettoyage
	State.Participants = {}
	CreatureService.Clear()
	Fx.clear()
	WallService.Reset()
end

function RoundService.Run()
	while true do
		intermission()
		runRound()
	end
end

return RoundService

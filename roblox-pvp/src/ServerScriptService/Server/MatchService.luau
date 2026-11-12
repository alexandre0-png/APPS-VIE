--!nonstrict
-- Machine à états des manches (Waiting -> Intermission -> Playing -> Results),
-- modes Mêlée générale / Guerre des couleurs, équipes, apparitions, scores,
-- récompenses de fin de manche, soins, orbe de rage, lave et vide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local MatchLogic = require(Shared.MatchLogic)
local Remotes = require(Shared.Remotes)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)
local QuestService = require(Server.QuestService)
local CombatService = require(Server.CombatService)

local MatchService = {}

local map
local rng = Random.new()
local modeIndex = 0
local matchId = 0
local stats = {} -- [userId] = {Name, Kills, Deaths, Team}
local scores = { Red = 0, Blue = 0 }
local earlyEnd = false

local function now()
	return workspace:GetServerTimeNow()
end

local function setState(state, duration)
	workspace:SetAttribute("MatchState", state)
	workspace:SetAttribute("MatchEndsAt", duration and (now() + duration) or 0)
end

local function arenaPlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InArena") then
			table.insert(list, p)
		end
	end
	return list
end

local function setScores(red, blue)
	scores.Red, scores.Blue = red, blue
	workspace:SetAttribute("RedScore", red)
	workspace:SetAttribute("BlueScore", blue)
end

local function newStats(player)
	stats[player.UserId] = { Name = player.DisplayName, Kills = 0, Deaths = 0, Team = player:GetAttribute("Team") or "" }
end

local function teamCounts()
	local red, blue = 0, 0
	for _, p in ipairs(arenaPlayers()) do
		local t = p:GetAttribute("Team")
		if t == "Red" then
			red += 1
		elseif t == "Blue" then
			blue += 1
		end
	end
	return red, blue
end

local function assignTeam(player)
	if workspace:GetAttribute("MatchMode") == "TEAM" then
		local red, blue = teamCounts()
		local team = MatchLogic.BalanceTeam(red, blue, scores.Red, scores.Blue, rng:NextNumber())
		player:SetAttribute("Team", team)
	else
		player:SetAttribute("Team", "")
	end
	if stats[player.UserId] then
		stats[player.UserId].Team = player:GetAttribute("Team")
	end
end

-- ===== Apparition =====
local function pickArenaSpawn(player)
	local spawns, points = map.ArenaSpawns, {}
	for i, sp in ipairs(spawns) do
		points[i] = { X = sp.Position.X, Z = sp.Position.Z }
	end
	local enemies = {}
	local mode = workspace:GetAttribute("MatchMode")
	for _, other in ipairs(arenaPlayers()) do
		if other ~= player then
			local sameTeam = mode == "TEAM" and other:GetAttribute("Team") == player:GetAttribute("Team")
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local hum = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if not sameTeam and root and hum and hum.Health > 0 then
				table.insert(enemies, { X = root.Position.X, Z = root.Position.Z })
			end
		end
	end
	local index = MatchLogic.PickSpawn(points, enemies, rng:NextNumber())
	return spawns[math.max(1, index)]
end

local function preSpawn(player)
	if player:GetAttribute("InArena") then
		player.RespawnLocation = pickArenaSpawn(player)
	else
		player.RespawnLocation = map.LobbySpawn
	end
end

local function onCharacter(player, character)
	if not player:GetAttribute("InArena") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = character
	Debris:AddItem(ff, Config.Match.SpawnProtection)
	if humanoid then
		humanoid.Died:Connect(function()
			local s = stats[player.UserId]
			if s and workspace:GetAttribute("MatchState") == "Playing" then
				s.Deaths += 1
			end
		end)
	end
end

-- ===== Rejoindre / quitter =====
function MatchService.Join(player)
	if player:GetAttribute("InArena") then
		return false, "Vous êtes déjà dans l'arène"
	end
	if not DataService.Get(player) then
		return false, "Profil en cours de chargement"
	end
	player:SetAttribute("InArena", true)
	player:SetAttribute("Streak", 0)
	assignTeam(player)
	if not stats[player.UserId] then
		newStats(player)
	end
	task.defer(PlayerService.Respawn, player)
	Remotes.Match:FireClient(player, { Type = "Joined" })
	return true, "Bonne chance !"
end

function MatchService.Leave(player)
	if not player:GetAttribute("InArena") then
		return false, "Vous êtes déjà dans le hub"
	end
	player:SetAttribute("InArena", false)
	player:SetAttribute("Team", "")
	player:SetAttribute("Streak", 0)
	task.defer(PlayerService.Respawn, player)
	Remotes.Match:FireClient(player, { Type = "Left" })
	return true, "De retour au hub"
end

-- ===== Scores =====
local function onKill(killer, victim)
	if workspace:GetAttribute("MatchState") ~= "Playing" then
		return
	end
	local ks = stats[killer.UserId]
	if ks then
		ks.Kills += 1
		killer:SetAttribute("MatchKills", ks.Kills)
	end
	if workspace:GetAttribute("MatchMode") == "TEAM" then
		local team = killer:GetAttribute("Team")
		if team == "Red" then
			setScores(scores.Red + 1, scores.Blue)
		elseif team == "Blue" then
			setScores(scores.Red, scores.Blue + 1)
		end
		if math.max(scores.Red, scores.Blue) >= Config.Match.TeamScoreLimit then
			earlyEnd = true
		end
	elseif ks and ks.Kills >= Config.Match.FFAScoreLimit then
		earlyEnd = true
	end
end

-- ===== Manche =====
local function finishMatch(mode)
	local present = {}
	for _, p in ipairs(arenaPlayers()) do
		present[p.UserId] = p
	end

	local winnersById = {}
	local headline
	if mode == "TEAM" then
		local w = MatchLogic.TeamWinner(scores.Red, scores.Blue)
		if w == "Draw" then
			headline = "Égalité !"
		else
			headline = ("Victoire des %s !"):format(Config.TeamNames[w])
			for userId, p in pairs(present) do
				if p:GetAttribute("Team") == w then
					winnersById[userId] = true
				end
			end
		end
	else
		local entries = {}
		for userId in pairs(present) do
			table.insert(entries, { Id = userId, Score = stats[userId] and stats[userId].Kills or 0 })
		end
		local winners = MatchLogic.FFAWinners(entries)
		local names = {}
		for _, id in ipairs(winners) do
			winnersById[id] = true
			table.insert(names, stats[id].Name)
		end
		headline = #names > 0 and ("Vainqueur : %s"):format(table.concat(names, ", ")) or "Aucun vainqueur"
	end

	local board = {}
	for userId, s in pairs(stats) do
		if present[userId] then
			table.insert(board, { Name = s.Name, Kills = s.Kills, Deaths = s.Deaths, Team = s.Team, UserId = userId })
		end
	end
	table.sort(board, function(a, b)
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end
		return a.Deaths < b.Deaths
	end)
	local top = {}
	for i = 1, math.min(8, #board) do
		top[i] = board[i]
	end

	local R = Config.Rewards
	for userId, player in pairs(present) do
		local won = winnersById[userId] == true
		local coins = R.ParticipationCoins + (won and R.WinCoins or 0)
		local xp = R.ParticipationXP + (won and R.WinXP or 0)
		PlayerService.AddCoins(player, coins)
		PlayerService.AddXP(player, xp)
		PlayerService.Increment(player, "MatchesPlayed", 1)
		QuestService.Notify(player, "MatchPlayed", 1)
		if won then
			PlayerService.Increment(player, "Wins", 1)
			QuestService.Notify(player, "Win", 1)
		end
		Remotes.Match:FireClient(player, {
			Type = "Results",
			Mode = mode,
			ModeName = Config.ModeNames[mode],
			Headline = headline,
			Won = won,
			Board = top,
			RedScore = scores.Red,
			BlueScore = scores.Blue,
			Coins = coins,
			XP = xp,
		})
	end
end

local function runLoop()
	while true do
		setState("Waiting")
		workspace:SetAttribute("NextMode", "")
		while #arenaPlayers() == 0 do
			task.wait(0.5)
		end

		-- intermission
		local nextMode
		nextMode, modeIndex = MatchLogic.NextMode(Config.Match.Modes, modeIndex)
		workspace:SetAttribute("NextMode", nextMode)
		setState("Intermission", Config.Match.IntermissionSeconds)
		local untilT = os.clock() + Config.Match.IntermissionSeconds
		while os.clock() < untilT and #arenaPlayers() > 0 do
			task.wait(0.25)
		end

		if #arenaPlayers() > 0 then
			-- début de manche
			matchId += 1
			earlyEnd = false
			stats = {}
			workspace:SetAttribute("MatchId", matchId)
			workspace:SetAttribute("MatchMode", nextMode)
			setScores(0, 0)
			local list = arenaPlayers()
			for i = #list, 2, -1 do -- mélange (Fisher-Yates)
				local j = rng:NextInteger(1, i)
				list[i], list[j] = list[j], list[i]
			end
			for i, p in ipairs(list) do
				p:SetAttribute("Streak", 0)
				p:SetAttribute("MatchKills", 0)
				p:SetAttribute("Team", nextMode == "TEAM" and (i % 2 == 0 and "Red" or "Blue") or "")
				newStats(p)
			end
			setState("Playing", Config.Match.MatchSeconds)
			for _, p in ipairs(list) do
				task.defer(PlayerService.Respawn, p)
			end

			local endAt = os.clock() + Config.Match.MatchSeconds
			while os.clock() < endAt and not earlyEnd and #arenaPlayers() > 0 do
				task.wait(0.25)
			end

			-- résultats
			setState("Results", Config.Match.ResultsSeconds)
			finishMatch(nextMode)
			task.wait(Config.Match.ResultsSeconds)
		end
	end
end

-- ===== Éléments d'arène =====
local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid, model
	end
	return nil
end

local function setupPickups()
	for _, pack in ipairs(map.HealthPacks) do
		pack.Touched:Connect(function(hit)
			if pack:GetAttribute("Cooling") then
				return
			end
			local player, humanoid = playerFromHit(hit)
			if player and player:GetAttribute("InArena") and humanoid.Health < humanoid.MaxHealth then
				pack:SetAttribute("Cooling", true)
				CombatService.Heal(humanoid, Config.HealthPack.Heal)
				pack.Transparency = 1
				for _, c in ipairs(pack:GetChildren()) do
					if c:IsA("BillboardGui") then
						c.Enabled = false
					end
				end
				task.delay(Config.HealthPack.Respawn, function()
					pack.Transparency = 0
					pack:SetAttribute("Cooling", nil)
					for _, c in ipairs(pack:GetChildren()) do
						if c:IsA("BillboardGui") then
							c.Enabled = true
						end
					end
				end)
			end
		end)
	end

	local orb = map.RageOrb
	orb.Touched:Connect(function(hit)
		if orb:GetAttribute("Cooling") then
			return
		end
		local player, _, model = playerFromHit(hit)
		if not player or not player:GetAttribute("InArena") then
			return
		end
		orb:SetAttribute("Cooling", true)
		QuestService.Notify(player, "Orb", 1)
		local duration = Config.RageOrb.Duration
		player:SetAttribute("BoostUntil", now() + duration)
		PlayerService.Notify(player, "Boost", "RAGE ! Dégâts ×" .. tostring(Config.RageOrb.Multiplier), { Duration = duration })
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 40, 40)
		hl.FillTransparency = 0.75
		hl.OutlineColor = Color3.fromRGB(255, 90, 90)
		hl.Parent = model
		Debris:AddItem(hl, duration)
		orb.Transparency = 1
		for _, c in ipairs(orb:GetChildren()) do
			if c:IsA("BillboardGui") or c:IsA("PointLight") then
				c.Enabled = false
			end
		end
		task.delay(Config.RageOrb.Respawn, function()
			orb.Transparency = 0
			orb:SetAttribute("Cooling", nil)
			for _, c in ipairs(orb:GetChildren()) do
				if c:IsA("BillboardGui") or c:IsA("PointLight") then
					c.Enabled = true
				end
			end
		end)
	end)

	for _, lava in ipairs(map.Lava) do
		lava.Touched:Connect(function(hit)
			local player, humanoid = playerFromHit(hit)
			if player and player:GetAttribute("InArena") and not humanoid.Parent:FindFirstChildOfClass("ForceField") then
				CombatService.EnvironmentKill(humanoid)
			end
		end)
	end

	-- portail du hub
	local debounce = {}
	map.Portal.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and not player:GetAttribute("InArena") and not debounce[player] then
			debounce[player] = true
			MatchService.Join(player)
			task.delay(3, function()
				debounce[player] = nil
			end)
		end
	end)
end

function MatchService.Init(mapRefs)
	map = mapRefs
	workspace:SetAttribute("MatchMode", "FFA")
	workspace:SetAttribute("RedScore", 0)
	workspace:SetAttribute("BlueScore", 0)
	PlayerService.PreSpawnCallbacks[#PlayerService.PreSpawnCallbacks + 1] = preSpawn
	PlayerService.CharacterCallbacks[#PlayerService.CharacterCallbacks + 1] = onCharacter
	CombatService.OnKill(onKill)
	setupPickups()

	Players.PlayerRemoving:Connect(function(player)
		stats[player.UserId] = nil
	end)

	-- chute dans le vide
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and root.Position.Y < -30 then
					CombatService.EnvironmentKill(humanoid)
				end
			end
		end
	end)

	task.spawn(runLoop)
end

return MatchService

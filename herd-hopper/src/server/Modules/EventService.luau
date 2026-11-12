-- Événements de manche : Geysers (gros bonds gratuits) et Pluie de météores (éjecte les cavaliers).
-- Chaque événement est annoncé par un anneau au sol ("télégraphie") avant d'agir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local RideService = require(script.Parent.RideService)

local EventService = {}

local rng = Random.new()
local nextEventAt = 0

local function activeRuns()
	local list = {}
	for player, run in pairs(State.Participants) do
		local s = run.status
		if s == "Riding" or s == "Air" or s == "Down" then
			table.insert(list, { player = player, run = run })
		end
	end
	return list
end

local function playersInRadius(position, radius)
	local found = {}
	for player, run in pairs(State.Participants) do
		local s = run.status
		if s == "Riding" or s == "Air" or s == "Down" then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - position
				local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
				if flat <= radius and d.Y < 40 then
					table.insert(found, player)
				end
			end
		end
	end
	return found
end

local function announce(kind, title, sub)
	Remotes.Feedback:FireAllClients({ kind = kind, title = title, sub = sub })
end

local function randomPositionAhead(zMin, zMax)
	local x = (rng:NextNumber() * 2 - 1) * (Config.Track.HalfWidth - 14)
	local z = math.clamp(zMin + rng:NextNumber() * (zMax - zMin), 40, Config.Track.FinishZ - 80)
	return Vector3.new(x, 0, z)
end

-- Tourbillon : un cercle de couleur, puis une colonne qui propulse tout cavalier dedans (bonus de saut).
local function geyser(position, roundId, color)
	local radius = Config.Events.GeyserRadius
	Fx.ring(position, radius, color, Config.Events.Telegraph)
	task.delay(Config.Events.Telegraph, function()
		if State.RoundId ~= roundId or State.Phase ~= "Running" then
			return
		end
		Fx.column(position, radius, 70, color, 0.9)
		for _, player in ipairs(playersInRadius(position, radius)) do
			if player.Parent then
				RideService.Boost(player, Vector3.new(0, 90, 70))
				Remotes.Feedback:FireClient(
					player,
					{ kind = "geyser", title = "SUPER BOND !", sub = "Rattrape un animal en l'air !" }
				)
			end
		end
	end)
end

-- Surgissement / météore : un cercle rouge, puis une explosion qui éjecte les cavaliers.
local function strike(position, roundId, color)
	local radius = Config.Events.StrikeRadius
	Fx.ring(position, radius, Color3.fromRGB(255, 70, 40), Config.Events.Telegraph)
	task.delay(Config.Events.Telegraph, function()
		if State.RoundId ~= roundId or State.Phase ~= "Running" then
			return
		end
		Fx.explosion(Vector3.new(position.X, 6, position.Z), radius, color)
		for _, player in ipairs(playersInRadius(position, radius)) do
			if player.Parent then
				RideService.Knock(player)
			end
		end
	end)
end

function EventService.Reset()
	nextEventAt = Config.Events.FirstDelay
end

-- Appelé à chaque Heartbeat pendant la manche ; `elapsed` = secondes écoulées depuis le départ.
-- Chaque zone a son événement : tourbillons (bonus) dans la savane et le désert, surgissements dans le marais
-- et météores dans le volcan (éjectent les cavaliers).
function EventService.Step(elapsed)
	if elapsed < nextEventAt then
		return
	end
	local runs = activeRuns()
	nextEventAt = elapsed + Config.Events.MinGap + rng:NextNumber() * (Config.Events.MaxGap - Config.Events.MinGap)
	if #runs == 0 then
		return
	end

	local leaderZ = -math.huge
	for _, entry in ipairs(runs) do
		leaderZ = math.max(leaderZ, entry.run.z or 0)
	end
	local roundId = State.RoundId
	local event = Config.zoneAt(leaderZ).event

	if event.kind == "geyser" then
		announce("event", event.name .. " !", "Fonce dans les cercles pour un super bond.")
		for _ = 1, 2 do
			geyser(randomPositionAhead(leaderZ + 70, leaderZ + 180), roundId, event.color)
		end
	else
		announce("danger", event.name .. " !", "Évite les cercles rouges !")
		for _ = 1, 3 do
			strike(randomPositionAhead(leaderZ + 40, leaderZ + 160), roundId, event.color)
		end
	end
end

return EventService

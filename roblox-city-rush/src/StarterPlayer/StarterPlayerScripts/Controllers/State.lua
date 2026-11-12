--[[
	State.lua : état client synchronisé avec le serveur (lecture seule côté UI).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local State = {}
State.Changed = Util.newSignal() -- (data)
State.MissionChanged = Util.newSignal() -- (mission|nil)
State.WantedChanged = Util.newSignal() -- (stars, evading)
State.Notified = Util.newSignal() -- (text, kind)
State.Banner = Util.newSignal() -- (info)
State.PanelRequested = Util.newSignal() -- (name)
State.BustedSignal = Util.newSignal() -- (lost)
State.LeaderboardChanged = Util.newSignal() -- (rows)
State.CollectedChanged = Util.newSignal() -- (list, total)
State.CinematicRequested = Util.newSignal() -- (id)

State.data = nil
State.cinematicsReady = false
State.pendingCinematics = {}
State.mission = nil
State.stars = 0
State.evading = false
State.collected = {}
State.totalStars = 30
State.leaderboard = {}
State.serverOffset = 0

local remotes

function State.remote(name)
	return remotes:WaitForChild(name)
end

function State.send(name, ...)
	local r = remotes:FindFirstChild(name)
	if r then
		r:FireServer(...)
	end
end

function State.init()
	remotes = ReplicatedStorage:WaitForChild("CityRushRemotes")

	State.remote("State").OnClientEvent:Connect(function(data)
		State.data = data
		State.Changed:Fire(data)
	end)
	State.remote("Notify").OnClientEvent:Connect(function(text, kind)
		State.Notified:Fire(text, kind)
	end)
	State.remote("Wanted").OnClientEvent:Connect(function(stars, evading)
		State.stars = stars
		State.evading = evading
		State.WantedChanged:Fire(stars, evading)
	end)
	State.remote("Mission").OnClientEvent:Connect(function(m)
		State.mission = m
		State.MissionChanged:Fire(m)
	end)
	State.remote("Banner").OnClientEvent:Connect(function(info)
		State.Banner:Fire(info)
	end)
	State.remote("OpenPanel").OnClientEvent:Connect(function(name)
		State.PanelRequested:Fire(name)
	end)
	State.remote("Busted").OnClientEvent:Connect(function(lost)
		State.BustedSignal:Fire(lost)
	end)
	State.remote("Leaderboard").OnClientEvent:Connect(function(rows)
		State.leaderboard = rows
		State.LeaderboardChanged:Fire(rows)
	end)
	State.remote("Cinematic").OnClientEvent:Connect(function(id)
		if type(id) == "string" then
			if State.cinematicsReady then
				State.CinematicRequested:Fire(id)
			else
				table.insert(State.pendingCinematics, id) -- reçue avant l'initialisation du lecteur
			end
		end
	end)
	State.remote("Collected").OnClientEvent:Connect(function(list, total)
		State.collected = {}
		for _, id in ipairs(list) do
			State.collected[id] = true
		end
		State.totalStars = total or State.totalStars
		State.CollectedChanged:Fire(list, total)
	end)

	State.send("RequestState")
end

return State

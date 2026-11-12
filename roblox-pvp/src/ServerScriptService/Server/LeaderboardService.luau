--!nonstrict
-- Classement mondial des éliminations (OrderedDataStore). Si le DataStore est
-- indisponible (Studio sans accès API), affiche le classement du serveur courant.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local DataService = require(Server.DataService)

local LeaderboardService = {}

local store
local nameCache = {}

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.DataStore.LeaderboardName)
		end)
		store = ok and result or false
	end
	return store
end

local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Joueur " .. userId)
	return nameCache[userId]
end

local function pushScores()
	local ds = getStore()
	if not ds then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(player)
		if profile and not profile.Ephemeral and profile.Kills > 0 then
			pcall(function()
				ds:SetAsync(tostring(player.UserId), profile.Kills)
			end)
		end
	end
end

local function render(rows, entries, suffix)
	for i, label in ipairs(rows) do
		local e = entries[i]
		if e then
			label.Text = ("%d.  %s  —  %d%s"):format(i, e.Name, e.Value, suffix or "")
		else
			label.Text = ("%d.  —"):format(i)
		end
	end
end

local function refresh(rows)
	pushScores()
	local entries
	local ds = getStore()
	if ds then
		local ok, pages = pcall(function()
			return ds:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local okPage, data = pcall(function()
				return pages:GetCurrentPage()
			end)
			if okPage then
				entries = {}
				for _, item in ipairs(data) do
					table.insert(entries, { Name = nameOf(tonumber(item.key) or 0), Value = item.value })
				end
			end
		end
	end
	if not entries then
		-- repli : classement du serveur
		entries = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile then
				table.insert(entries, { Name = player.DisplayName, Value = profile.Kills })
			end
		end
		table.sort(entries, function(a, b)
			return a.Value > b.Value
		end)
		render(rows, entries, "  (serveur)")
		return
	end
	render(rows, entries)
end

function LeaderboardService.Init(map)
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh, map.LeaderboardRows)
			if not ok then
				warn("[LeaderboardService] " .. tostring(err))
			end
			task.wait(Config.DataStore.LeaderboardRefresh)
		end
	end)
end

return LeaderboardService

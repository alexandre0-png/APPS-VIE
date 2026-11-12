--!nonstrict
-- Classement mondial « Plus gros nourrisseurs » (OrderedDataStore) + tableau dans le monde.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local PlayerService = require(script.Parent.PlayerService)

local LeaderboardService = {}

local ordered: any = nil
local top: { { name: string, value: number } } = {}
local nameCache: { [number]: string } = {}
local lastWritten: { [number]: number } = {}
local labels: { TextLabel } = {}

local function getOrdered()
	if not ordered then
		ordered = DataStoreService:GetOrderedDataStore(Config.Data.FedBoardName)
	end
	return ordered
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else ("Joueur " .. userId)
	return nameCache[userId]
end

local function writeScore(player: Player, data: any)
	if PlayerService.session(player) and PlayerService.session(player).temporary then
		return
	end
	local value = math.floor(data.totalFed)
	if value <= 0 or lastWritten[player.UserId] == value then
		return
	end
	local ok = pcall(function()
		getOrdered():SetAsync(tostring(player.UserId), value)
	end)
	if ok then
		lastWritten[player.UserId] = value
	end
end

local function refresh()
	local ok, entries = pcall(function()
		return getOrdered():GetSortedAsync(false, #labels > 0 and #labels or 10):GetCurrentPage()
	end)
	if not ok then
		return
	end
	local list = {}
	for _, entry in ipairs(entries) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(list, { name = nameFor(userId), value = entry.value })
		end
	end
	top = list
	for i, label in ipairs(labels) do
		local e = list[i]
		label.Text = if e then string.format("%d. %s — %s", i, e.name, Util.formatNumber(e.value)) else string.format("%d. —", i)
	end
end

function LeaderboardService.getTop()
	return top
end

function LeaderboardService.init(boardLabels: { TextLabel })
	labels = boardLabels
	PlayerService.onSave(writeScore)
	task.spawn(function()
		while true do
			refresh()
			task.wait(60)
		end
	end)
end

return LeaderboardService

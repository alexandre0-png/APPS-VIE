-- Leaderboard.luau : classement global (OrderedDataStore) des meilleurs parcs, affiché dans le lobby.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Leaderboard = {}

local store = nil
local nameCache = {}
local lastSubmit = {}

local function getStore()
	if store == nil then
		local ok, res = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
		end)
		if ok then
			store = res
		end
	end
	return store
end

-- score = total des pièces gagnées sur toute la vie du parc
function Leaderboard.submit(player, score)
	local now = os.clock()
	if lastSubmit[player] and now - lastSubmit[player] < 120 then
		return
	end
	lastSubmit[player] = now
	local s = getStore()
	if not s then
		return
	end
	local v = math.floor(Util.clamp(score, 0, 9e15))
	task.spawn(function()
		pcall(function()
			s:SetAsync("P_" .. player.UserId, v)
		end)
	end)
end

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Joueur " .. userId)
	return nameCache[userId]
end

local function refresh()
	local s = getStore()
	local lines = WorldBuilder.leaderboardLines
	if not s or not lines then
		return
	end
	local ok, pages = pcall(function()
		return s:GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local ok2, top = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then
		return
	end
	for i = 1, 10 do
		local entry = top[i]
		if entry then
			local userId = tonumber(string.match(entry.key, "P_(%d+)"))
			lines[i].Text = i .. ". " .. nameFor(userId or 0) .. "  —  " .. Util.formatNumber(entry.value)
		else
			lines[i].Text = i .. ". —"
		end
	end
end

function Leaderboard.init()
	Players.PlayerRemoving:Connect(function(p)
		lastSubmit[p] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(90)
		end
	end)
end

return Leaderboard

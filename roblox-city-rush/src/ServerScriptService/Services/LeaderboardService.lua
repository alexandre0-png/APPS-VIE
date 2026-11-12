--[[
	LeaderboardService : classement mondial de l'argent (OrderedDataStore)
	affiché sur le panneau de la place centrale et dans le menu Profil.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)

local LeaderboardService = {}

local names = {}
local latest = {}

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and n or ("Joueur " .. userId)
	return names[userId]
end

local function buildGui(board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(880, 480)
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundColor3 = Color3.fromRGB(255, 196, 0)
	title.BorderSizePixel = 0
	title.Text = "TOP 10 - FORTUNES"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(20, 22, 30)
	title.Parent = bg
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0, 20, 0, 60 + (i - 1) * 41)
		row.Size = UDim2.new(1, -40, 0, 38)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextSize = 28
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(235, 235, 240)
		row.Text = ""
		row.Parent = bg
		rows[i] = row
	end
	return rows
end

local function refresh(rows)
	local board = DataService.getBoard()
	if not board then
		return
	end
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local ok2, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then
		return
	end
	latest = {}
	for i, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local n = userId and nameOf(userId) or "?"
		latest[i] = { name = n, cash = entry.value }
		if rows[i] then
			rows[i].Text = string.format("%d.  %s  -  %s", i, n, Util.formatCash(entry.value))
		end
	end
	for i = #page + 1, 10 do
		if rows[i] then
			rows[i].Text = ""
		end
	end
	RemoteService.fireAll("Leaderboard", latest)
end

function LeaderboardService.start(world)
	local board = world.Root:FindFirstChild("Decor") and nil
	for _, d in ipairs(world.Root:GetDescendants()) do
		if d.Name == "LeaderboardBoard" then
			board = d
			break
		end
	end
	local rows = board and buildGui(board) or {}
	Players.PlayerAdded:Connect(function(player)
		task.delay(8, function()
			if player.Parent and #latest > 0 then
				RemoteService.fire("Leaderboard", player, latest)
			end
		end)
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			refresh(rows)
			task.wait(120)
		end
	end)
end

return LeaderboardService

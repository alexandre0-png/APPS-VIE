-- Le zoo de chaque joueur : une parcelle dans le parc central, des enclos qui se remplissent d'animaux,
-- une caisse qui accumule de l'or, des visiteurs (affichés côté client). Reconstruite quand le zoo change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Zoo = require(Shared.Zoo)

local State = require(script.Parent.State)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local CreatureService = require(script.Parent.CreatureService)

local ZooService = {}

local H = Config.Hub
local plots = {} -- [Player] = { index, center, folder }
local usedIndex = {}
local zooFolder = nil

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function plotCenter(index)
	local col = (index - 1) % H.Columns
	local row = math.floor((index - 1) / H.Columns)
	return V(
		H.Center.X + (col - (H.Columns - 1) / 2) * H.PlotSpacing,
		H.Center.Y + 4,
		H.Center.Z + (row - (H.Rows - 1) / 2) * H.PlotSpacing
	)
end

local function slotCenter(center, slotIndex)
	local col = (slotIndex - 1) % H.SlotColumns
	local row = math.floor((slotIndex - 1) / H.SlotColumns)
	local rows = math.ceil(Config.Zoo.MaxSlots / H.SlotColumns)
	return center + V((col - (H.SlotColumns - 1) / 2) * H.SlotSpacing, 0, (row - (rows - 1) / 2) * H.SlotSpacing - 4)
end

local function part(parent, name, size, position, color, material, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = opts and opts.collide == true or false
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	if opts and opts.trans then
		p.Transparency = opts.trans
	end
	p.Parent = parent
	return p
end

local function label(parent, adornee, text, offset, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, width or 150, 0, 34)
	gui.StudsOffset = offset
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 1, 0)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = C(255, 255, 255)
	t.TextStrokeTransparency = 0.3
	t.Parent = gui
	return gui
end

-- Dispose les animaux possédés, les meilleurs d'abord, dans les enclos débloqués.
local function sortedAnimals(data)
	local list = {}
	for key, entry in pairs(data.animals) do
		local def, variant = Zoo.parseKey(key)
		if def then
			table.insert(list, {
				key = key,
				def = def,
				variant = variant,
				level = entry.level or 1,
				income = Zoo.animalIncome(def, variant, entry.level or 1),
			})
		end
	end
	table.sort(list, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.key < b.key
	end)
	return list
end

local function buildPlotContent(player, plot)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if plot.folder then
		plot.folder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Zoo_" .. player.UserId
	folder.Parent = zooFolder
	plot.folder = folder

	local center = plot.center
	local size = H.PlotSize
	part(
		folder,
		"PlotGround",
		V(size, 1, size),
		center - V(0, 0.5, 0),
		C(112, 170, 92),
		Enum.Material.Grass,
		{ collide = true }
	)
	part(folder, "PlotPath", V(6, 0.2, size), center + V(0, 0.05, 0), C(214, 196, 150), Enum.Material.Sand)

	-- panneau à l'entrée
	local postPos = center + V(0, 4, size / 2 - 4)
	local sign = part(folder, "Sign", V(30, 7, 1), postPos, C(60, 44, 30), Enum.Material.Wood)
	label(sign, sign, player.DisplayName .. " · ZOO", V(0, 0, 0), 280)
	for _, side in ipairs({ -1, 1 }) do
		part(folder, "Post", V(1.5, 8, 1.5), postPos + V(side * 16, 0, 0), C(90, 62, 40), Enum.Material.Wood)
	end

	local slots = Zoo.slots(data.zooUp.slots, ProgressService.HasPass(player, "zoo"))
	local animals = sortedAnimals(data)
	for slot = 1, Config.Zoo.MaxSlots do
		local sc = slotCenter(center, slot)
		local unlocked = slot <= slots
		part(
			folder,
			"Pad" .. slot,
			V(10, 0.3, 10),
			sc + V(0, 0.1, 0),
			unlocked and C(150, 120, 80) or C(70, 74, 82),
			Enum.Material.Slate
		)
		if unlocked then
			for _, d in ipairs({
				{ V(10, 1.4, 0.4), V(0, 0.9, 5) },
				{ V(10, 1.4, 0.4), V(0, 0.9, -5) },
				{ V(0.4, 1.4, 10), V(5, 0.9, 0) },
				{ V(0.4, 1.4, 10), V(-5, 0.9, 0) },
			}) do
				part(folder, "Rail", d[1], sc + d[2], C(120, 84, 52), Enum.Material.Wood)
			end
			local entry = animals[slot]
			if entry then
				local model, root = CreatureService.BuildModel(entry.def, entry.variant)
				model.Name = "Zoo_" .. entry.key
				local extent = math.max(entry.def.body.s.Z * 1.6, entry.def.body.s.X * 1.6)
				local scale = math.clamp(7.5 / extent, 0.22, 0.85)
				model:ScaleTo(scale)
				local y = entry.def.rootY * scale + 0.3
				model:PivotTo(CFrame.new(sc + V(0, y, 0)) * CFrame.Angles(0, math.rad((slot * 67) % 360), 0))
				model:SetAttribute("Static", true)
				model:SetAttribute("BaseSpeed", 10)
				model.Parent = folder
				label(root, root, ("%s · niv %d"):format(entry.def.name, entry.level), V(0, 5 + y, 0), 170)
			else
				part(
					folder,
					"Empty" .. slot,
					V(2, 2, 2),
					sc + V(0, 1.2, 0),
					C(255, 255, 255),
					Enum.Material.Neon,
					{ trans = 0.9 }
				)
			end
		else
			local lock = part(folder, "Lock" .. slot, V(3, 3, 0.4), sc + V(0, 2, 0), C(40, 44, 52), Enum.Material.Metal)
			label(lock, lock, "Verrouillé", V(0, 2, 0), 100)
		end
	end
end

function ZooService.Refresh(player)
	local plot = plots[player]
	if plot and player.Parent then
		buildPlotContent(player, plot)
	end
end

local function assign(player)
	for index = 1, H.Columns * H.Rows do
		if not usedIndex[index] then
			usedIndex[index] = player
			local center = plotCenter(index)
			plots[player] = { index = index, center = center }
			State.PlotCFrames[player] = CFrame.new(center + V(0, 4, H.PlotSize / 2 - 8))
			player:SetAttribute("PlotCenter", center)
			return true
		end
	end
	return false
end

function ZooService.OnPlayerReady(player)
	if not plots[player] then
		if not assign(player) then
			return
		end
	end
	ZooService.Refresh(player)
end

local function release(player)
	local plot = plots[player]
	if plot then
		usedIndex[plot.index] = nil
		if plot.folder then
			plot.folder:Destroy()
		end
		plots[player] = nil
	end
	State.PlotCFrames[player] = nil
	State.Ready[player] = nil
end

local function handleReady(player, zoneKey, wants)
	if type(wants) ~= "boolean" then
		return
	end
	if type(zoneKey) == "string" then
		ProgressService.SetZone(player, zoneKey)
		ProgressService.Push(player)
	end
	local run = State.Participants[player]
	local busy = run ~= nil and State.Phase ~= "Intermission" and run.status ~= "Out" and run.status ~= "Finished"
	if busy then
		return
	end
	State.Ready[player] = wants and DataService.Get(player) ~= nil or nil
end

function ZooService.Init()
	zooFolder = Instance.new("Folder")
	zooFolder.Name = "ZooAnimals"
	zooFolder.Parent = workspace
	ProgressService.OnZooChanged = ZooService.Refresh
	Remotes.Ready.OnServerEvent:Connect(handleReady)
	Players.PlayerRemoving:Connect(release)
end

return ZooService

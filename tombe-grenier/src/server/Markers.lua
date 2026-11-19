--[[
  Markers (serveur) : pose sur chaque objet interactif de la partie un halo coloré et une pastille
  (catégorie lisible de loin), et garantit un nom au survol (ObjectText des invites).
  Le décor n'est pas touché : seules les pièces portant une étiquette interactive sont marquées.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MarkerStyles = require(Shared.Markers)
local Quests = require(script.Parent.Quests)

local Markers = {}

local entries = {} -- { part, glow, gui, tags } des objets marqués de la partie
local loopStarted = false

local function color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function mark(part, style)
	if part:GetAttribute("Marked") then
		return
	end
	part:SetAttribute("Marked", style.category)
	pcall(function()
		local glow = Instance.new("Highlight")
		glow.Name = "Halo"
		glow.Adornee = part
		glow.FillTransparency = 1
		glow.OutlineColor = color(style.color)
		glow.OutlineTransparency = 0.45
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = part
		table.insert(entries, { part = part, glow = glow, tags = CollectionService:GetTags(part) })

		local gui = Instance.new("BillboardGui")
		gui.Name = "Pastille"
		gui.Size = UDim2.fromOffset(64, 20)
		gui.StudsOffset = Vector3.new(0, 1.2, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = MarkerStyles.MAX_DISTANCE
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
		label.BackgroundTransparency = 0.35
		label.TextColor3 = color(style.color)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = style.icon
		label.Parent = gui
		gui.Parent = part
		entries[#entries].gui = gui
	end)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and (child.ObjectText == nil or child.ObjectText == "") then
			child.ObjectText = part:GetAttribute("DisplayName") or style.label
		end
	end
end

-- Halo fort pour l'objet de l'étape active, discret pour les autres ; au plus MAX_HALOS halos allumés
-- (les plus utiles d'abord : étape active puis distance au joueur le plus proche).
function Markers.refresh()
	local progress = Quests.progress()
	local step = progress and progress.current
	local roots = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(roots, root.Position)
		end
	end
	local list, alive = {}, {}
	for _, e in ipairs(entries) do
		if e.part.Parent then
			local best = math.huge
			for _, pos in ipairs(roots) do
				best = math.min(best, (e.part.Position - pos).Magnitude)
			end
			e.current = MarkerStyles.isCurrent(step, e.tags)
			table.insert(alive, e)
			table.insert(list, { dist = best, current = e.current })
		end
	end
	entries = alive
	local keep = MarkerStyles.select(list, MarkerStyles.MAX_HALOS)
	for i, e in ipairs(entries) do
		pcall(function()
			e.glow.Enabled = keep[i] == true
			e.glow.OutlineTransparency = e.current and 0 or 0.8
			e.glow.FillTransparency = e.current and 0.75 or 1
			if e.gui then
				e.gui.MaxDistance = e.current and 45 or 10
			end
		end)
	end
end

-- À appeler après Objectives.setup / Quests.setup / Props.setup
function Markers.apply()
	if Config.Design and Config.Design.Markers == false then
		return
	end
	if not loopStarted then
		loopStarted = true
		task.spawn(function()
			while true do
				task.wait(1)
				Markers.refresh()
			end
		end)
	end
	local seen = {}
	for _, style in ipairs(MarkerStyles.STYLES) do
		for _, tag in ipairs(style.tags) do
			for _, part in ipairs(CollectionService:GetTagged(tag)) do
				if part:IsA("BasePart") and not seen[part] then
					seen[part] = true
					mark(part, MarkerStyles.styleFor(CollectionService:GetTags(part)))
				end
			end
		end
	end
	Markers.refresh()
end

return Markers

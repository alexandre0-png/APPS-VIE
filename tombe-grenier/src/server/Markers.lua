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

local Markers = {}

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
	end)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and (child.ObjectText == nil or child.ObjectText == "") then
			child.ObjectText = part:GetAttribute("DisplayName") or style.label
		end
	end
end

-- À appeler après Objectives.setup / Quests.setup / Props.setup
function Markers.apply()
	if Config.Design and Config.Design.Markers == false then
		return
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
end

return Markers

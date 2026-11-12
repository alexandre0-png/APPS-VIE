--[[
	MapView : carte nord en haut (nord = -Z). Utilisée pour le mini-radar et la grande carte.
	Le décor de la carte est dessiné à partir de Config (grille, quartiers, POI).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local MapView = {}
MapView.__index = MapView

local HALF = Config.Map.GroundHalf
local COLORS = {
	residential = Color3.fromRGB(190, 200, 170), industrial = Color3.fromRGB(140, 140, 145),
	downtown = Color3.fromRGB(120, 135, 160), plaza = Color3.fromRGB(215, 200, 170),
	harbor = Color3.fromRGB(150, 150, 160), beach = Color3.fromRGB(231, 208, 150),
	stadium = Color3.fromRGB(110, 170, 110), park = Color3.fromRGB(80, 150, 70),
	payspray = Color3.fromRGB(200, 195, 160), police = Color3.fromRGB(120, 140, 190), dealer = Color3.fromRGB(150, 190, 215),
}

function MapView.new(parent, size, scale, props)
	local self = setmetatable({}, MapView)
	self.scale = scale
	self.size = size
	props = props or {}
	props.Size = UDim2.fromOffset(size.X, size.Y)
	props.BackgroundColor3 = Color3.fromRGB(30, 100, 150)
	props.ClipsDescendants = true
	props.BorderSizePixel = 0
	props.Parent = parent
	self.frame = UI.new("Frame", props)
	UI.corner(self.frame, 12)
	UI.stroke(self.frame, UI.Theme.Accent, 2)

	local total = HALF * 2 * scale
	self.canvas = UI.new("Frame", {
		Size = UDim2.fromOffset(total, total),
		BackgroundColor3 = Color3.fromRGB(96, 150, 78),
		BorderSizePixel = 0,
		Parent = self.frame,
	})
	local function rect(x, z, w, d, color, z_index)
		return UI.new("Frame", {
			Position = UDim2.fromOffset((x - w / 2 + HALF) * scale, (z - d / 2 + HALF) * scale),
			Size = UDim2.fromOffset(math.max(1, w * scale), math.max(1, d * scale)),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z_index or 1, Parent = self.canvas,
		})
	end
	for j = 1, Config.Map.Grid do
		for i = 1, Config.Map.Grid do
			local c = Config.blockCenter(i, j)
			rect(c.X, c.Z, Config.Map.BlockSize, Config.Map.BlockSize, COLORS[Config.Districts[j][i]] or Color3.new(1, 1, 1), 2)
		end
	end
	for k = 0, 5 do
		local c = -500 + Config.Map.Pitch * k
		rect(c, 0, Config.Map.RoadWidth, 1040, Color3.fromRGB(70, 72, 80), 1)
		rect(0, c, 1040, Config.Map.RoadWidth, Color3.fromRGB(70, 72, 80), 1)
	end
	for _, poi in ipairs(Config.POIs) do
		local dot = UI.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((poi.x + HALF) * scale, (poi.z + HALF) * scale),
			Size = UDim2.fromOffset(18, 18), BackgroundColor3 = poi.color, Text = poi.glyph,
			Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = Color3.new(0, 0, 0), ZIndex = 5, Parent = self.canvas,
		})
		UI.corner(dot, 9)
	end

	self.blipLayer = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = self.canvas })
	self.pool = {}
	self.used = 0
	self.me = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1, Text = "▲", Font = Enum.Font.GothamBlack, TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 10, Parent = self.frame,
	})
	UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = self.me })
	return self
end

function MapView:blip(worldPos, color, size, glyph)
	self.used += 1
	local b = self.pool[self.used]
	if not b then
		b = UI.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Text = "", Font = Enum.Font.GothamBlack,
			TextSize = 11, TextColor3 = Color3.new(0, 0, 0), ZIndex = 6, Parent = self.blipLayer,
		})
		UI.corner(b, 20)
		self.pool[self.used] = b
	end
	b.Visible = true
	b.BackgroundColor3 = color
	b.Size = UDim2.fromOffset(size or 10, size or 10)
	b.Text = glyph or ""
	b.Position = UDim2.fromOffset((worldPos.X + HALF) * self.scale, (worldPos.Z + HALF) * self.scale)
end

function MapView:update(centerPos, heading)
	self.used = 0
	local s = self.scale
	self.canvas.Position = UDim2.fromOffset(self.size.X / 2 - (centerPos.X + HALF) * s, self.size.Y / 2 - (centerPos.Z + HALF) * s)
	if heading then
		self.me.Rotation = heading
	end
	local m = State.mission
	if m and m.target then
		self:blip(m.target, m.color or Color3.new(1, 1, 1), 16, "★")
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Players.LocalPlayer then
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				self:blip(hrp.Position, Color3.fromRGB(120, 220, 255), 8)
			end
		end
	end
	local cops = workspace:FindFirstChild("Cops")
	if cops then
		for _, c in ipairs(cops:GetChildren()) do
			local r = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
			if r then
				self:blip(r.Position, Color3.fromRGB(70, 110, 255), 9)
			end
		end
	end
	local drops = State.airdropPositions
	if drops then
		for _, p in ipairs(drops) do
			self:blip(p, Color3.fromRGB(90, 230, 120), 12, "$")
		end
	end
	for i = self.used + 1, #self.pool do
		self.pool[i].Visible = false
	end
end

return MapView

-- LocalScript : StarterPlayerScripts/HubClient (lieu HUB uniquement)
-- Interface du hub : bouton « Amis » en haut à droite qui ouvre la liste des parties ouvertes de tes amis (bouton Rejoindre), messages en
-- haut à droite. Tout est ancré aux bords, la zone centrale reste libre (voir Layout.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.Game.roleFor(game.PlaceId) == "game" then
	return
end
local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local remote = ReplicatedStorage:WaitForChild("HubRemote")
local player = Players.LocalPlayer

local COL = {
	bg = Color3.fromRGB(15, 42, 27), panel = Color3.fromRGB(29, 77, 51), pill = Color3.fromRGB(10, 30, 20),
	yellow = Color3.fromRGB(255, 210, 63), text = Color3.fromRGB(244, 255, 246), muted = Color3.fromRGB(159, 199, 173),
	green = Color3.fromRGB(91, 227, 125), red = Color3.fromRGB(255, 107, 107),
}
local FONT = Enum.Font.GothamBold

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local gui = make("ScreenGui", { Name = "HubUI", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets }, player:WaitForChild("PlayerGui"))
local root = make("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 520) }, gui)
local scale = make("UIScale", { Scale = 1 }, root)

-- Bouton « Amis » : en haut à droite
local friendsBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(120, 44), BackgroundColor3 = COL.pill, Text = "👥 Amis", Font = FONT, TextSize = 18, TextColor3 = COL.text, AutoButtonColor = true }, root)
corner(friendsBtn, 14)
make("UIStroke", { Color = COL.yellow, Thickness = 2 }, friendsBtn)

-- Panneau des parties : sous le bouton, côté droit
local panel = make("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(300, 260), BackgroundColor3 = COL.bg, Visible = false }, root)
corner(panel, 14)
make("UIStroke", { Color = COL.panel, Thickness = 2 }, panel)
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Font = FONT, TextSize = 18, TextColor3 = COL.yellow, TextXAlignment = Enum.TextXAlignment.Left, Text = "Parties ouvertes de tes amis" }, panel)
local list = make("ScrollingFrame", { Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local empty = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 60), Font = FONT, TextSize = 14, TextWrapped = true, TextColor3 = COL.muted, Text = "Aucune partie ouverte pour l'instant. Lance la tienne dans un portail : tes amis pourront la rejoindre !" }, panel)

-- Messages : sous le bouton Amis
local msg = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(300, 44), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, Font = FONT, TextSize = 14, TextColor3 = COL.text, TextWrapped = true, Text = "", Visible = false }, root)
corner(msg, 12)
make("UIStroke", { Color = COL.yellow, Thickness = 2 }, msg)
local msgToken = 0
local function toast(text, kind)
	msgToken += 1
	local token = msgToken
	msg.Text = text
	msg.TextColor3 = kind == "error" and COL.red or COL.text
	msg.Visible = true
	task.delay(5, function()
		if token == msgToken then
			msg.Visible = false
		end
	end)
end

local function applyLayout()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(900, 520)
	if vs.X < 50 or vs.Y < 50 then
		return
	end
	local s = Layout.scaleFor(vs.X, vs.Y)
	scale.Scale = s
	local dw = vs.X / s
	root.Size = UDim2.fromOffset(dw, vs.Y / s)
	local e = Layout.EDGE
	friendsBtn.Position = UDim2.fromOffset(dw - e, e)
	panel.Position = UDim2.fromOffset(dw - e, e + 52)
	panel.Size = UDim2.fromOffset(math.min(300, dw - 2 * e), 260)
	msg.Position = UDim2.fromOffset(dw - e, e + 52 + (panel.Visible and 268 or 0))
	msg.Size = UDim2.fromOffset(math.min(300, dw - 2 * e), 44)
end
applyLayout()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
end

local function render(parties)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	empty.Visible = #parties == 0
	for i, p in ipairs(parties) do
		local row = make("Frame", { Size = UDim2.new(1, -4, 0, 48), BackgroundColor3 = COL.panel, LayoutOrder = i }, list)
		corner(row, 10)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -110, 0, 24), Font = FONT, TextSize = 15, TextColor3 = COL.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "🏠 " .. tostring(p.hostName) }, row)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -110, 0, 20), Font = FONT, TextSize = 12, TextColor3 = COL.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(p.count) .. "/" .. tostring(p.size) .. " joueurs" }, row)
		local join = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(88, 34), BackgroundColor3 = COL.green, Font = FONT, TextSize = 14, TextColor3 = Color3.fromRGB(10, 40, 20), Text = "Rejoindre" }, row)
		corner(join, 12)
		join.Activated:Connect(function()
			join.Text = "…"
			remote:FireServer("join", p.id)
		end)
	end
end

local function refresh()
	remote:FireServer("parties")
end
friendsBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
	applyLayout()
	if panel.Visible then
		refresh()
	end
end)
task.spawn(function()
	while true do
		task.wait(8)
		if panel.Visible then
			refresh()
		end
	end
end)

remote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "msg" then
		toast(tostring(a), b)
	elseif kind == "parties" then
		if type(a) == "table" then
			render(a)
		end
		if b == false then
			toast("Liste des amis indisponible pour l'instant.", "info")
		end
	end
end)
TweenService:Create(friendsBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(120, 44) }):Play()

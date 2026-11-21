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
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -110, 0, 20), Font = FONT, TextSize = 12, TextColor3 = COL.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(math.max(0, p.size - p.count)) .. " place(s) libre(s) · " .. tostring(p.count) .. "/" .. tostring(p.size) }, row)
		local join = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(100, 34), BackgroundColor3 = COL.green, Font = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(10, 40, 20), Text = "Rejoindre l'ami" }, row)
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

-- Une seule étiquette de portail à la fois : celle du portail le plus proche (à moins de Config.PORTAL_LABEL.maxDist studs) ; les autres sont masquées.
task.spawn(function()
	local CollectionService = game:GetService("CollectionService")
	while true do
		pcall(function()
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local portals, labels = {}, CollectionService:GetTagged("PortalLabel")
			local seen = {}
			for _, bb in ipairs(labels) do
				local key = bb:GetAttribute("PortalKey")
				local adornee = bb.Adornee
				if key and adornee and not seen[key] then
					seen[key] = true
					portals[#portals + 1] = { key = key, x = adornee.Position.X, z = adornee.Position.Z }
				end
			end
			local near = root and Config.nearestPortal(root.Position.X, root.Position.Z, portals) or nil
			for _, bb in ipairs(labels) do
				bb.Enabled = near ~= nil and bb:GetAttribute("PortalKey") == near
			end
		end)
		task.wait(0.25)
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

---------------------------------------------------------------- Survol d'accueil : la fontaine puis les portails (CinematicKit)
-- 5 secondes, première arrivée seulement (pas au retour d'une partie), passage d'un tap, d'un clic, d'Entrée ou du bouton, 8 s au plus par construction ;
-- le personnage garde le contrôle, la caméra est restituée quoi qu'il arrive (fin, passage, erreur, sécurité).
task.spawn(function()
	if not Config.cineEnabled("hub") then
		return
	end
	local ok, err = pcall(function()
		local UserInputService = game:GetService("UserInputService")
		local RunService = game:GetService("RunService")
		local Shared = ReplicatedStorage:WaitForChild("Shared")
		local Easing = require(Shared:WaitForChild("Easing"))
		local CK = require(Shared:WaitForChild("CinematicKit"))
		local Kit = CK.new(Easing, require(Shared:WaitForChild("Cinema")).new(Easing))
		local t0 = os.clock()
		while os.clock() - t0 < 15 and not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) do
			task.wait(0.25)
		end
		task.wait(1.5)
		if player:GetAttribute("ReturnVisit") then
			return
		end
		local cam = workspace.CurrentCamera
		local saved = nil
		local cine = make("ScreenGui", { Name = "HubCine", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false }, player:WaitForChild("PlayerGui"))
		local function bar(y)
			make("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.1, BorderSizePixel = 0, Active = false }, cine)
		end
		bar(0)
		bar(1)
		local title = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(420, 70), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = COL.text, TextStrokeTransparency = 0.3, Text = "", Active = false }, cine)
		local caption = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.93, 0), Size = UDim2.fromOffset(520, 40), BackgroundTransparency = 1, Font = FONT, TextSize = 20, TextColor3 = COL.yellow, TextWrapped = true, Text = "", Active = false }, cine)
		local skipBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0.02, 0), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = COL.yellow, Text = "Passer ▶", Font = FONT, TextSize = 15, TextColor3 = Color3.fromRGB(43, 34, 0) }, cine)
		corner(skipBtn, 10)
		local lastShot = 0
		local host = {
			takeCamera = function()
				saved = { cameraType = cam.CameraType, fov = cam.FieldOfView }
				cam.CameraType = Enum.CameraType.Scriptable
				cine.Enabled = true
			end,
			giveCameraBack = function()
				cine.Enabled = false
				if saved then
					cam.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
					cam.FieldOfView = saved.fov
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						cam.CameraSubject = hum
					end
					saved = nil
				end
			end,
			apply = function(index, progress, shot)
				local pos, look, fov = Kit.cameraAt(shot, progress)
				local off = Kit.shakeOffset(shot, progress, os.clock())
				cam.CFrame = CFrame.lookAt(Vector3.new(pos[1] + off[1], pos[2] + off[2], pos[3] + off[3]), Vector3.new(look[1], look[2], look[3]))
				cam.FieldOfView = fov
				if index ~= lastShot then
					lastShot = index
					title.Text = shot.title or ""
					caption.Text = shot.text or ""
				end
			end,
		}
		local runner = Kit.runner(host)
		local started = runner.start(CK.PLANS.hub_survol, os.clock())
		if started ~= "playing" then
			warn("[Hub] survol d'accueil non démarré : " .. tostring(started))
			return
		end
		local function stop()
			pcall(function()
				RunService:UnbindFromRenderStep("HubSurvol")
			end)
			runner.abort()
		end
		RunService:BindToRenderStep("HubSurvol", Enum.RenderPriority.Camera.Value + 1, function()
			local status = runner.update(os.clock())
			if status ~= "playing" then
				stop()
			end
		end)
		skipBtn.Activated:Connect(function()
			runner.skip(os.clock())
			stop()
		end)
		UserInputService.InputBegan:Connect(function(input)
			if runner.isActive() and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonB) then
				runner.skip(os.clock())
				stop()
			end
		end)
		task.delay(CK.MAX_SECONDS + 2, stop) -- sécurité : la caméra revient de force
	end)
	if not ok then
		warn("[Hub] survol d'accueil abandonné : " .. tostring(err))
		pcall(function()
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		end)
	end
end)


--[[
	Hud.lua : interface de jeu permanente (niveau, argent, radar, étoiles de recherche,
	mission, notifications, compteur de vitesse, bannières d'événements, écran d'arrestation).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local MapView = require(script.Parent.MapView)
local VehicleController = require(script.Parent.VehicleController)

local Hud = {}
local T = UI.Theme
local player = Players.LocalPlayer
local KIND_COLORS = {
	good = T.Good, bad = T.Bad, info = T.Info, levelup = T.Accent, star = T.Accent, achv = Color3.fromRGB(170, 100, 255),
}

local gui, root
local refs = {}
local pillar, pillarGui

local function ping(id)
	local s = Instance.new("Sound")
	s.SoundId = id or "rbxasset://sounds/electronicpingshort.wav"
	s.Volume = 0.5
	s.Parent = SoundService
	s:Play()
	task.delay(2, function()
		s:Destroy()
	end)
end

-- ====================================================================
-- Notifications
-- ====================================================================
local function toast(text, kind)
	local color = KIND_COLORS[kind] or T.Info
	local f = UI.panel({
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Parent = refs.toasts,
	})
	UI.stroke(f, color, 2)
	UI.padding(f, 10)
	local l = UI.label({
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = text,
		TextSize = kind == "levelup" and 22 or 17, TextColor3 = color == T.Info and T.Text or color, Parent = f,
	})
	f.BackgroundTransparency = 1
	UI.tween(f, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 })
	if kind == "levelup" or kind == "star" or kind == "good" or kind == "achv" then
		ping()
	end
	task.delay(4.5, function()
		if f.Parent then
			UI.tween(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			UI.tween(l, TweenInfo.new(0.4), { TextTransparency = 1 })
			task.wait(0.45)
			f:Destroy()
		end
	end)
end

-- ====================================================================
-- Construction
-- ====================================================================
local function buildLevel()
	local f = UI.panel({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(240, 56), Parent = root })
	UI.stroke(f, T.PanelLight)
	refs.level = UI.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(120, 24), Text = "Niv. 1", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	refs.vip = UI.label({ Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(48, 24), Text = "", TextSize = 16, TextColor3 = T.Accent, Parent = f })
	local bar = UI.new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 14), BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Parent = f })
	UI.corner(bar, 7)
	refs.xpFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar })
	UI.corner(refs.xpFill, 7)
	refs.xpText = UI.label({ Size = UDim2.fromScale(1, 1), Text = "0 / 120 XP", TextSize = 11, TextColor3 = Color3.new(0, 0, 0), Parent = bar })
	refs.xp2 = UI.label({ Position = UDim2.fromOffset(105, 4), Size = UDim2.fromOffset(100, 24), Text = "", TextSize = 13, TextColor3 = T.Good, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
end

local function buildCash()
	local f = UI.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(230, 46), Parent = root })
	UI.stroke(f, T.Good, 2)
	refs.cash = UI.label({ Size = UDim2.fromScale(1, 1), Text = "0 $", TextSize = 26, TextColor3 = T.Good, Font = Enum.Font.GothamBlack, Parent = f })
end

local function buildMenuButtons()
	local row = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 60), Size = UDim2.fromOffset(238, 46),
		BackgroundTransparency = 1, Parent = root,
	})
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), Parent = row })
	local defs = {
		{ "garage", "🚗", "Garage (G)" }, { "shop", "💎", "Boutique (B)" }, { "profile", "🏆", "Profil (P)" },
		{ "map", "🗺", "Carte (M)" }, { "daily", "🎁", "Cadeau" },
	}
	refs.menuButtons = {}
	for _, d in ipairs(defs) do
		local b = UI.button({ Size = UDim2.fromOffset(42, 42), Text = d[2], TextSize = 22, BackgroundColor3 = T.Panel, Parent = row }, function()
			State.PanelRequested:Fire(d[1])
		end)
		UI.stroke(b, T.PanelLight)
		refs.menuButtons[d[1]] = b
	end
end

local function buildWanted()
	local f = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(230, 44), BackgroundTransparency = 1, Parent = root })
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), Parent = f })
	refs.stars = {}
	for i = 1, 5 do
		refs.stars[i] = UI.label({ Size = UDim2.fromOffset(40, 44), Text = "★", TextSize = 40, TextColor3 = Color3.fromRGB(80, 80, 90), Font = Enum.Font.GothamBlack, Visible = false, Parent = f })
		UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = refs.stars[i] })
	end
	refs.wantedFrame = f
	refs.wantedText = UI.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(260, 20), Text = "", TextSize = 15, TextColor3 = T.Muted, Parent = root })
end

local function buildToasts()
	refs.toasts = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(400, 200), BackgroundTransparency = 1, Parent = root })
	UI.new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = refs.toasts })
end

local function buildMission()
	local f = UI.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 114), Size = UDim2.fromOffset(270, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = root })
	refs.missionPanel = f
	UI.padding(f, 10)
	UI.new("UIListLayout", { Padding = UDim.new(0, 4), Parent = f })
	refs.mTitle = UI.label({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 19, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = f })
	refs.mText = UI.label({ Size = UDim2.new(1, 0, 0, 36), Text = "", TextSize = 14, TextColor3 = T.Text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Parent = f })
	refs.mTime = UI.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 28, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, Parent = f })
	refs.mInfo = UI.label({ Size = UDim2.new(1, 0, 0, 18), Text = "", TextSize = 14, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4, Parent = f })
	refs.mReward = UI.label({ Size = UDim2.new(1, 0, 0, 18), Text = "", TextSize = 15, TextColor3 = T.Good, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 5, Parent = f })
	local ab = UI.button({ Size = UDim2.new(1, 0, 0, 30), Text = "Abandonner", TextSize = 14, BackgroundColor3 = Color3.fromRGB(110, 50, 50), LayoutOrder = 6, Parent = f }, function()
		State.send("AbandonMission")
	end)
	refs.abandon = ab
end

local function buildSpeedo()
	local f = UI.panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(240, 78), Visible = false, Parent = root })
	UI.stroke(f, T.Accent, 2)
	refs.speedo = f
	refs.speed = UI.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(150, 46), Text = "0", TextSize = 44, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	UI.label({ Position = UDim2.fromOffset(160, 24), Size = UDim2.fromOffset(60, 20), Text = "km/h", TextSize = 16, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	local bar = UI.new("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Parent = f })
	UI.corner(bar, 5)
	refs.boostFill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 140, 30), BorderSizePixel = 0, Parent = bar })
	UI.corner(refs.boostFill, 5)
	if UserInputService.TouchEnabled then
		local b = UI.button({
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -130, 1, -150), Size = UDim2.fromOffset(78, 78), Text = "NITRO",
			TextSize = 16, BackgroundColor3 = Color3.fromRGB(255, 140, 30), Visible = false, Parent = root,
		})
		UI.corner(b, 40)
		b.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				VehicleController.setBoost(true)
			end
		end)
		b.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				VehicleController.setBoost(false)
			end
		end)
		refs.boostButton = b
	end
end

local function buildBanner()
	refs.banner = UI.panel({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(520, 56),
		BackgroundColor3 = Color3.fromRGB(20, 80, 40), Parent = root,
	})
	UI.stroke(refs.banner, T.Good, 2)
	refs.bannerText = UI.label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18, TextWrapped = true, Parent = refs.banner })
end

local function buildBusted()
	refs.busted = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 30, 90), BackgroundTransparency = 1, Visible = false, ZIndex = 50, Parent = root })
	refs.bustedText = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 120), Text = "ARRÊTÉ !", TextSize = 72, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 51, Parent = refs.busted })
	refs.bustedSub = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(600, 40), Text = "", TextSize = 24, TextColor3 = T.Accent, ZIndex = 51, Parent = refs.busted })
end

local function buildHints()
	if UserInputService.TouchEnabled then
		return
	end
	UI.label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -8), Size = UDim2.fromOffset(520, 18),
		Text = "G Garage · B Boutique · M Carte · P Profil · Shift Nitro · R Redresser · Saut = sortir", TextSize = 13,
		TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = root,
	})
end

-- ====================================================================
-- Mise à jour
-- ====================================================================
local function onState(d)
	refs.level.Text = "Niv. " .. d.Level
	refs.xpFill.Size = UDim2.fromScale(math.clamp(d.XP / d.XPNeed, 0, 1), 1)
	refs.xpText.Text = string.format("%d / %d XP", d.XP, d.XPNeed)
	refs.cash.Text = Util.formatCash(d.Cash)
	refs.vip.Text = d.Vip and "VIP" or ""
	refs.xp2.Text = d.DoubleXP and "XP x2 !" or ""
	if refs.menuButtons and refs.menuButtons.daily then
		refs.menuButtons.daily.BackgroundColor3 = d.DailyAvailable and T.Accent or T.Panel
	end
end

local function onWanted(stars, evading)
	for i, s in ipairs(refs.stars) do
		s.Visible = stars > 0
		s.TextColor3 = i <= stars and Color3.fromRGB(255, 215, 40) or Color3.fromRGB(80, 80, 90)
	end
	refs.wantedText.Text = stars > 0 and (evading and "Fuis hors de vue de la police..." or "La police te poursuit !") or ""
	refs.wantedText.TextColor3 = evading and T.Muted or T.Bad
end

local function clearPillar()
	if pillar then
		pillar:Destroy()
		pillar = nil
	end
end

local function onMission(m)
	clearPillar()
	if not m then
		refs.missionPanel.Visible = false
		return
	end
	refs.missionPanel.Visible = true
	refs.mTitle.Text = m.title
	refs.mText.Text = m.text
	refs.mReward.Text = "Gain : " .. Util.formatCash(m.reward) .. (m.steps > 1 and m.type == "race" and string.format("  (point %d/%d)", m.step, m.steps) or "")
	refs.mTitle.TextColor3 = m.color or T.Accent

	pillar = Instance.new("Part")
	pillar.Name = "MissionPillar"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(300, m.radius * 1.4, m.radius * 1.4)
	pillar.CFrame = CFrame.new(m.target + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	pillar.Material = Enum.Material.Neon
	pillar.Color = m.color or T.Accent
	pillar.Transparency = 0.6
	pillar.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 90, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.Parent = pillar
	pillarGui = UI.label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, BackgroundColor3 = Color3.new(0, 0, 0), Parent = bb })
	UI.corner(pillarGui, 8)
end

local function onBanner(info)
	if info.kind == "airdrop" then
		State.airdropPositions = info.positions
		task.delay(info.duration or 120, function()
			State.airdropPositions = nil
		end)
	elseif info.kind == "airdrop_end" then
		State.airdropPositions = nil
	end
	refs.bannerText.Text = info.text
	UI.tween(refs.banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 110) })
	ping()
	task.delay(7, function()
		UI.tween(refs.banner, TweenInfo.new(0.4), { Position = UDim2.new(0.5, 0, 0, -80) })
	end)
end

local function onBusted(lost)
	refs.busted.Visible = true
	refs.bustedSub.Text = lost > 0 and ("Amende : " .. Util.formatCash(lost)) or "Tu t'en sors sans amende."
	refs.busted.BackgroundTransparency = 0.2
	UI.tween(refs.busted, TweenInfo.new(2.6), { BackgroundTransparency = 1 })
	task.delay(2.6, function()
		refs.busted.Visible = false
	end)
end

function Hud.init(screenGui)
	gui = screenGui
	root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	buildLevel()
	buildCash()
	buildMenuButtons()
	buildWanted()
	buildToasts()
	buildMission()
	buildSpeedo()
	buildBanner()
	buildBusted()
	buildHints()

	local radarSize = UserInputService.TouchEnabled and 130 or 170
	refs.radar = MapView.new(root, Vector2.new(radarSize, radarSize), 0.32, { Position = UDim2.fromOffset(10, 72) })

	State.Changed:Connect(onState)
	State.WantedChanged:Connect(onWanted)
	State.MissionChanged:Connect(onMission)
	State.Notified:Connect(toast)
	State.Banner:Connect(onBanner)
	State.BustedSignal:Connect(onBusted)
	if State.data then
		onState(State.data)
	end
	if State.mission then
		onMission(State.mission)
	end

	VehicleController.Updated:Connect(function(speed, boost, driving)
		refs.speedo.Visible = driving
		if refs.boostButton then
			refs.boostButton.Visible = driving
		end
		if driving then
			refs.speed.Text = tostring(math.floor(speed))
			refs.boostFill.Size = UDim2.fromScale(boost, 1)
		end
	end)

	-- boucle d'affichage (radar 10 Hz, mission, étoiles clignotantes)
	local acc = 0
	local blink = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		blink += dt
		if State.stars > 0 and State.evading then
			local on = math.floor(blink * 3) % 2 == 0
			for i, s in ipairs(refs.stars) do
				if i <= State.stars then
					s.TextTransparency = on and 0 or 0.6
				end
			end
		end
		local m = State.mission
		if m and refs.missionPanel.Visible then
			local left = m.deadline - (workspace:GetServerTimeNow())
			refs.mTime.Text = Util.formatTime(left)
			refs.mTime.TextColor3 = left < 15 and T.Bad or T.Text
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = Util.flatDistance(hrp.Position, m.target)
				refs.mInfo.Text = string.format("Distance : %d m", math.floor(d * 0.28))
				if pillarGui then
					pillarGui.Text = string.format("%d m", math.floor(d * 0.28))
				end
			end
		end
		if acc < 0.1 then
			return
		end
		acc = 0
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local look = workspace.CurrentCamera.CFrame.LookVector
			refs.radar:update(hrp.Position, math.deg(math.atan2(look.X, -look.Z)))
		end
	end)
end

return Hud

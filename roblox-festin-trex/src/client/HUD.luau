--!nonstrict
-- Interface permanente : pièces, niveau, état du T-Rex, événements, panier, combo, boutons, notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local C = UIKit.Colors
local HUD = {}

local gui: ScreenGui
local refs: any = {}
local comboToken = 0
local coinValue = Instance.new("NumberValue")
local satTween: Tween? = nil

local function scaled(group: Frame, baseWidth: number, baseHeight: number)
	local s = Instance.new("UIScale")
	s.Parent = group
	local function update()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		s.Scale = math.clamp(math.min(vp.X / baseWidth, vp.Y / baseHeight), 0.62, 1.2)
	end
	update()
	task.defer(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end)
	return s
end

local function group(name: string, anchor: Vector2, pos: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.Parent = gui
	return f
end

-- ---------------------------------------------------------------- blocs

local function buildTopLeft()
	local g = group("TopLeft", Vector2.new(0, 0), UDim2.new(0, 12, 0, 8), UDim2.fromOffset(250, 96))
	scaled(g, 1000, 560)
	local pill = UIKit.frame(g, { Size = UDim2.fromOffset(250, 46), BackgroundColor3 = C.panel, BackgroundTransparency = 0.15 })
	UIKit.corner(pill, 23)
	UIKit.gradient(pill)
	UIKit.stroke(pill, C.gold, 2)
	refs.coins = UIKit.label(pill, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "🪙 0", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne, TextColor3 = C.gold })

	local lv = UIKit.frame(g, { Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(250, 34), BackgroundColor3 = C.panel, BackgroundTransparency = 0.15 })
	UIKit.corner(lv, 12)
	refs.level = UIKit.label(lv, { Size = UDim2.fromOffset(90, 34), Position = UDim2.fromOffset(8, 0), Text = "Niv. 1", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
	local bg, fill = UIKit.bar(lv, { Position = UDim2.fromOffset(86, 10), Size = UDim2.fromOffset(150, 14) }, C.blue)
	refs.levelFill = fill
	refs.mult = UIKit.label(g, { Position = UDim2.fromOffset(4, 90), Size = UDim2.fromOffset(250, 18), Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
end

local function buildDino()
	local g = group("DinoPanel", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(400, 140))
	scaled(g, 1000, 560)
	local p = UIKit.frame(g, { Size = UDim2.fromOffset(400, 84), BackgroundTransparency = 0.12 })
	UIKit.corner(p, 14)
	UIKit.gradient(p)
	UIKit.stroke(p, Color3.fromRGB(88, 170, 80), 3)
	refs.dinoName = UIKit.label(p, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(190, 24), Text = "🦖 Bébé Rex", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne })
	refs.fav = UIKit.label(p, { Position = UDim2.fromOffset(190, 6), Size = UDim2.fromOffset(200, 24), Text = "Envie : 🍎 x3", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.gold })
	local bg, fill = UIKit.bar(p, { Position = UDim2.fromOffset(12, 36), Size = UDim2.fromOffset(376, 26) }, Color3.fromRGB(255, 140, 60))
	refs.satFill = fill
	refs.satText = UIKit.label(bg, { Size = UDim2.fromScale(1, 1), Text = "0 / 600", TextSize = 16, ZIndex = 3 })
	refs.hungry = UIKit.label(p, { Position = UDim2.fromOffset(12, 63), Size = UDim2.fromOffset(376, 18), Text = "", TextSize = 14, TextColor3 = C.good })

	-- Bandeau d'événement
	local banner = UIKit.frame(g, { Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(400, 40), BackgroundColor3 = C.bad, Visible = false })
	UIKit.corner(banner, 12)
	UIKit.stroke(banner, Color3.new(1, 1, 1), 2)
	refs.banner = banner
	refs.bannerText = UIKit.label(banner, { Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18 })
end

local function buildSideButtons(openPanel: (string) -> ())
	local g = group("Side", Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0), UDim2.fromOffset(78, 380))
	scaled(g, 1000, 560)
	local layout = UIKit.list(g, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local defs = {
		{ "shop", "🛒", "Boutique" },
		{ "quests", "📜", "Quêtes" },
		{ "pets", "🥚", "Nid" },
		{ "leaderboard", "🏆", "Top" },
		{ "rebirth", "✨", "Évolution" },
	}
	refs.sideButtons = {}
	for i, d in ipairs(defs) do
		local b = UIKit.button(g, {
			LayoutOrder = i,
			Size = UDim2.fromOffset(74, 68),
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0.1,
			Text = d[2] .. "\n" .. d[3],
			TextSize = 15,
			Callback = function()
				openPanel(d[1])
			end,
		})
		UIKit.stroke(b, C.accent, 2)
		local dot = UIKit.frame(b, { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -14, 0, -4), BackgroundColor3 = C.bad, Visible = false })
		UIKit.corner(dot, 9)
		refs.sideButtons[d[1]] = dot
	end
end

local function buildBottom(throwCenter: () -> ())
	local g = group("Bottom", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12), UDim2.fromOffset(420, 110))
	scaled(g, 1000, 560)
	refs.hint = UIKit.label(g, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(420, 30), Text = "", TextSize = 16, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3 })
	local p = UIKit.frame(g, { Position = UDim2.fromOffset(40, 34), Size = UDim2.fromOffset(340, 66), BackgroundTransparency = 0.12 })
	UIKit.corner(p, 14)
	UIKit.stroke(p, C.accent, 2)
	refs.foodIcon = UIKit.label(p, { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(60, 58), Text = "🍎", TextSize = 40 })
	refs.foodName = UIKit.label(p, { Position = UDim2.fromOffset(72, 6), Size = UDim2.fromOffset(150, 22), Text = "Pomme", TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne })
	refs.ammo = UIKit.label(p, { Position = UDim2.fromOffset(220, 6), Size = UDim2.fromOffset(112, 22), Text = "x6/6", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.gold })
	local bg, fill = UIKit.bar(p, { Position = UDim2.fromOffset(72, 38), Size = UDim2.fromOffset(256, 16) }, C.good)
	refs.ammoFill = fill

	-- Bouton LANCER (tactile / manette) : vise le centre de l'écran.
	if UserInputService.TouchEnabled or UserInputService.GamepadEnabled then
		local btn = UIKit.button(gui, {
			Name = "ThrowButton",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -110, 1, -40),
			Size = UDim2.fromOffset(120, 120),
			BackgroundColor3 = C.bad,
			Text = "LANCER\n🍎",
			TextSize = 20,
			Callback = throwCenter,
		})
		btn.Active = true
		UIKit.corner(btn, 60)
		UIKit.stroke(btn, Color3.new(1, 1, 1), 3)
		scaled(btn, 1000, 560)
		refs.throwBtn = btn
	end
end

local function buildCombo()
	local l = UIKit.label(gui, {
		Name = "Combo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(300, 60),
		Text = "",
		TextSize = 40,
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.gold,
		TextStrokeTransparency = 0,
		Visible = false,
	})
	refs.combo = l
end

local function buildToasts()
	local g = group("Toasts", Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), UDim2.fromOffset(360, 220))
	scaled(g, 1000, 560)
	local layout = UIKit.list(g, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.toasts = g
end

-- ---------------------------------------------------------------- API

function HUD.toast(text: string, kind: string?)
	if not refs.toasts then
		return
	end
	local color = C.panel
	if kind == "good" then
		color = Color3.fromRGB(40, 120, 70)
	elseif kind == "bad" then
		color = Color3.fromRGB(140, 50, 50)
	elseif kind == "gold" then
		color = Color3.fromRGB(150, 110, 20)
	end
	local f = UIKit.frame(refs.toasts, { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = color, BackgroundTransparency = 0.1 })
	UIKit.corner(f, 10)
	UIKit.padding(f, 8)
	UIKit.label(f, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	local children = refs.toasts:GetChildren()
	local count = 0
	for _, c in ipairs(children) do
		if c:IsA("Frame") then
			count += 1
		end
	end
	if count > 5 then
		for _, c in ipairs(children) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(5, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.wait(0.5)
			f:Destroy()
		end
	end)
end

function HUD.showCombo(n: number)
	comboToken += 1
	local token = comboToken
	if n < 2 then
		refs.combo.Visible = false
		return
	end
	refs.combo.Visible = true
	refs.combo.Text = string.format("COMBO x%d  (+%d%%)", n, math.floor(Economy.comboMult(n) * 100 - 100))
	refs.combo.TextColor3 = if n >= 20 then Color3.fromRGB(255, 90, 220) elseif n >= 10 then Color3.fromRGB(255, 150, 50) else C.gold
	refs.combo.TextSize = 52
	TweenService:Create(refs.combo, TweenInfo.new(0.2, Enum.EasingStyle.Back), { TextSize = 40 }):Play()
	task.delay(Config.Combo.Window, function()
		if token == comboToken then
			refs.combo.Visible = false
		end
	end)
end

function HUD.hideCombo()
	comboToken += 1
	refs.combo.Visible = false
end

local function refreshState(s: any)
	-- Compteur de pièces : défilement fluide vers la nouvelle valeur.
	TweenService:Create(coinValue, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = s.coins }):Play()
	refs.level.Text = "Niv. " .. s.level
	refs.levelFill.Size = UDim2.fromScale(s.levelProgress, 1)
	refs.mult.Text = string.format("Pièces x%.2f  ·  Évolution %d", s.stats.coinMult, s.rebirths)

	local food = Economy.findFood(s.selectedFood)
	if food then
		refs.foodIcon.Text = food.Emoji
		refs.foodName.Text = food.Name
		if refs.throwBtn then
			refs.throwBtn.Text = "LANCER\n" .. food.Emoji
		end
	end
	refs.ammo.Text = string.format("x%d/%d", s.ammo, s.capacity)
	refs.ammoFill.Size = UDim2.fromScale(math.clamp(s.ammo / math.max(1, s.capacity), 0, 1), 1)
	refs.ammoFill.BackgroundColor3 = if s.ammo == 0 then C.bad else C.good

	if s.ammo <= 0 then
		refs.hint.Text = "🧺 Panier vide ! Va prendre de la nourriture à un stand (touche E)"
	elseif s.totalFed == 0 then
		refs.hint.Text = "👆 Clique / touche pour lancer, vise la BOUCHE du T-Rex !"
	else
		refs.hint.Text = ""
	end

	-- Pastille rouge sur les quêtes : une récompense est à réclamer.
	local claimable = s.canDaily
	for _, q in ipairs(s.quests) do
		if q.progress >= q.target and not q.claimed then
			claimable = true
		end
	end
	refs.sideButtons.quests.Visible = claimable
	refs.sideButtons.pets.Visible = s.eggs > 0
end

local function refreshDino(state: Instance)
	local name = state:GetAttribute("StageName") or "Bébé Rex"
	local sat = state:GetAttribute("Satiety") or 0
	local need = state:GetAttribute("Need") or 1
	local fav = Economy.findFood(state:GetAttribute("Favorite") or "pomme")
	refs.dinoName.Text = "🦖 " .. name
	local ratio = math.clamp(sat / need, 0, 1)
	if satTween then
		satTween:Cancel()
	end
	satTween = TweenService:Create(refs.satFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = Color3.fromRGB(255, 140, 60):Lerp(Color3.fromRGB(110, 220, 90), ratio),
	})
	satTween:Play()
	refs.satText.Text = string.format("Festin : %s / %s", Util.formatNumber(sat), Util.formatNumber(need))
	if fav then
		local text = string.format("Envie : %s %s x%d", fav.Emoji, fav.Name, Config.FavoriteMult)
		if refs.fav.Text ~= text then
			refs.fav.Text = text
			refs.fav.TextSize = 24
			TweenService:Create(refs.fav, TweenInfo.new(0.4, Enum.EasingStyle.Back), { TextSize = 16 }):Play()
		end
	end
	refs.hungry.Text = if state:GetAttribute("Hungry") then string.format("🍽️ Faim de loup ! Pièces x%.1f", Config.HungryMult) else ""
end

local function refreshBanner(state: Instance)
	local id = state:GetAttribute("EventId") or ""
	local phase = state:GetAttribute("EventPhase") or ""
	if id == "" or phase == "" then
		refs.banner.Visible = false
		return
	end
	local cfg = ({ sauce = Config.Events.Sauce, rain = Config.Events.Rain, frenzy = Config.Events.Frenzy })[id]
	if not cfg then
		refs.banner.Visible = false
		return
	end
	local now = workspace:GetServerTimeNow()
	local startAt = state:GetAttribute("EventStart") or 0
	local endAt = state:GetAttribute("EventEnd") or 0
	refs.banner.Visible = true
	if phase == "warning" then
		refs.banner.BackgroundColor3 = Color3.fromRGB(220, 130, 30)
		refs.bannerText.Text = string.format("⚠️ %s dans %ds !", cfg.Name, math.max(0, math.ceil(startAt - now)))
		if id == "sauce" then
			refs.bannerText.Text ..= " Monte sur une table !"
		end
	elseif phase == "active" then
		refs.banner.BackgroundColor3 = if id == "sauce" then C.bad else C.good
		refs.bannerText.Text = string.format("%s — %ds", cfg.Name, math.max(0, math.ceil(endAt - now)))
	else
		refs.banner.Visible = false
	end
end

function HUD.init(openPanel: (string) -> (), throwCenter: () -> ())
	local player = Players.LocalPlayer
	gui = Instance.new("ScreenGui")
	gui.Name = "FestinHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	buildTopLeft()
	buildDino()
	buildSideButtons(openPanel)
	buildBottom(throwCenter)
	buildCombo()
	buildToasts()

	local state = ReplicatedStorage:WaitForChild("GameState")
	coinValue:GetPropertyChangedSignal("Value"):Connect(function()
		refs.coins.Text = "🪙 " .. Util.formatNumber(math.floor(coinValue.Value + 0.5))
	end)
	Store.onChange(refreshState)
	local function dino()
		refreshDino(state)
	end
	state.AttributeChanged:Connect(dino)
	dino()

	task.spawn(function()
		while true do
			refreshBanner(state)
			task.wait(0.25)
		end
	end)
end

function HUD.gui(): ScreenGui
	return gui
end

return HUD

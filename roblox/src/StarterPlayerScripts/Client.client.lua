-- LocalScript : StarterPlayer/StarterPlayerScripts/Client
-- Interface 100 % générée par code (aucune image à importer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))
local Reveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reveal"))
local Easing = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Easing"))
local RevealFx = require(script.Parent:WaitForChild("RevealFx"))
local CoinIcon = require(script.Parent:WaitForChild("CoinIcon"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RState, RNotify, RHatch, RAction = Remotes:WaitForChild("State"), Remotes:WaitForChild("Notify"), Remotes:WaitForChild("Hatch"), Remotes:WaitForChild("Action")
local RTop = Remotes:WaitForChild("Top")
local fmt = Config.fmt

local COL = {
	bg = Color3.fromRGB(15, 42, 27),
	panel = Color3.fromRGB(29, 77, 51),
	pill = Color3.fromRGB(10, 30, 20),
	yellow = Color3.fromRGB(255, 210, 63),
	text = Color3.fromRGB(244, 255, 246),
	muted = Color3.fromRGB(159, 199, 173),
	red = Color3.fromRGB(255, 107, 107),
	green = Color3.fromRGB(91, 227, 125),
	dis = Color3.fromRGB(75, 91, 81),
	dark = Color3.fromRGB(43, 34, 0),
}
local FONT = Enum.Font.GothamBold

local state = nil
local tryOfferLater, lastMilestone = nil, nil -- offre d'achat (définie avec le HUD) ; dernier palier d'éclosions vu
local topData = nil
local panel = nil -- { name, tab, confirm }
local costBtns = {}

---------------------------------------------------------------- Helpers UI
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end
-- Retour tactile : le bouton se rétrécit légèrement quand on appuie.
-- Sons : voir Config.SOUNDS (clé -> { id, speed, vol }). Un id vide ou introuvable reste silencieux.
local function playSound(key)
	local def = Config.SOUNDS[key]
	if not Config.SOUNDS_ENABLED or not def or def.id == "" then
		return
	end
	local snd = Instance.new("Sound")
	snd.SoundId = def.id
	snd.Volume = def.vol or 0.5
	snd.PlaybackSpeed = def.speed or 1
	snd.Parent = workspace
	snd:Play()
	Debris:AddItem(snd, 6)
end

local lastPress = 0 -- horodatage du dernier appui : sert à ne pas reconstruire un panneau sous le doigt du joueur
local function pressFx(btn)
	local sc = Instance.new("UIScale")
	sc.Parent = btn
	local function to(v)
		TweenService:Create(sc, TweenInfo.new(0.08), { Scale = v }):Play()
	end
	btn.MouseButton1Down:Connect(function()
		lastPress = os.clock()
		playSound("click")
		to(0.93)
	end)
	btn.MouseButton1Up:Connect(function()
		to(1)
	end)
	btn.MouseLeave:Connect(function()
		to(1)
	end)
end

local function text(parent, props)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or COL.text
	return make("TextLabel", props, parent)
end

-- Style « cartoon glossy » : contour foncé épais, dégradé, coins très arrondis, reflet. kind = fonction (Config.UI.kinds) : colore le bouton.
-- Sans kind, la couleur existante est gardée (boutons de coût, recolorés selon les pièces). Retourne le style ou nil.
local function glossy(obj, kind, radius, thickness)
	if not Config.UI.glossy then
		return nil
	end
	local st = kind and Config.btnStyle(kind) or nil
	if st then
		obj.BackgroundColor3 = st.base
		obj.BackgroundTransparency = 0
	end
	local cr = obj:FindFirstChildOfClass("UICorner") or make("UICorner", {}, obj)
	cr.CornerRadius = UDim.new(0, radius or 14)
	local stroke = obj:FindFirstChildOfClass("UIStroke") or make("UIStroke", {}, obj)
	stroke.Color = st and st.stroke or Color3.fromRGB(14, 24, 18)
	stroke.Thickness = thickness or 3
	make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 176, 176)), Rotation = 90 }, obj)
	local shine = make("Frame", { Name = "Shine", Size = UDim2.new(1, -12, 0.26, 0), Position = UDim2.fromOffset(6, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, Active = false }, obj)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(6, (radius or 14) - 4)) }, shine)
	return st
end

local gui = make("ScreenGui", { Name = "ChipeUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets }, player:WaitForChild("PlayerGui"))

-- HUD fixe : conteneur mis à l'échelle (téléphone, tablette, PC) dont tous les éléments sont ancrés aux bords (voir Layout.lua, testé).
-- Les menus (panneau, éclosion) restent hors du conteneur : ils sont temporaires et s'adaptent à l'écran en fractions.
local hudRoot = make("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 520) }, gui)
local hudScale = make("UIScale", { Scale = 1 }, hudRoot)
local hudParts = {} -- nom de Layout -> objet à placer

local function pill(y, icon, tint)
	local f = make("Frame", { Size = UDim2.fromOffset(196, 52), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.05 }, hudRoot)
	corner(f, 26)
	make("UIStroke", { Color = tint, Thickness = 2, Transparency = 0.15 }, f)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(34, 88, 58), Color3.fromRGB(10, 30, 20)), Rotation = 90 }, f)
	local scale = make("UIScale", { Scale = 1 }, f)
	text(f, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(38, 52), Text = icon, TextSize = 28 })
	local big = text(f, { Position = UDim2.fromOffset(50, 4), Size = UDim2.new(1, -56, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 24, Text = "0", TextStrokeTransparency = 0.6 })
	local small = text(f, { Position = UDim2.fromOffset(50, 31), Size = UDim2.new(1, -56, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, TextColor3 = COL.muted, Text = "" })
	return big, small, scale, f
end
local coinsBig, coinsSmall, coinsScale, coinsFrame = pill(8, "🪙", COL.yellow)
local speedBig, speedSmall, _, speedFrame = pill(66, "⚡", Color3.fromRGB(110, 190, 255))
hudParts.pillCoins, hudParts.pillSpeed = coinsFrame, speedFrame
speedSmall.Text = "VITESSE"

local carryLbl = text(hudRoot, { Size = UDim2.fromOffset(170, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Text = "", BackgroundTransparency = 0.2, BackgroundColor3 = COL.pill })
corner(carryLbl, 13)
carryLbl.Visible = false

local banner = text(hudRoot, { Size = UDim2.fromOffset(330, 40), TextWrapped = true, TextSize = 13, TextColor3 = COL.yellow, BackgroundTransparency = 0.12, BackgroundColor3 = COL.pill, Text = "", Visible = false })
corner(banner, 15)
make("UIStroke", { Color = COL.yellow, Thickness = 2 }, banner)

-- Barre de vie (visible seulement quand les pv sont entamés) : rouge dégradé, contour épais, texte « ❤ 86/100 ». Attributs Hp / MaxHp du joueur (serveur).
local hpFrame = make("Frame", { Size = UDim2.fromOffset(170, 22), BackgroundColor3 = Color3.fromRGB(40, 12, 14), Visible = false }, hudRoot)
corner(hpFrame, 11)
make("UIStroke", { Color = Color3.fromRGB(20, 8, 10), Thickness = 3 }, hpFrame)
local hpFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 82, 82) }, hpFrame)
corner(hpFill, 11)
make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Rotation = 90 }, hpFill)
local hpText = text(hpFrame, { Size = UDim2.fromScale(1, 1), TextSize = 12, Text = "", TextStrokeTransparency = 0.3, ZIndex = 3 })
hudParts.hp = hpFrame
local function refreshHp()
	local hp, maxHp = player:GetAttribute("Hp"), player:GetAttribute("MaxHp")
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 then
		hpFrame.Visible = false
		return
	end
	hpFrame.Visible = hp < maxHp
	hpText.Text = "❤ " .. hp .. "/" .. maxHp
	TweenService:Create(hpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) }):Play()
end
player:GetAttributeChangedSignal("Hp"):Connect(refreshHp)
player:GetAttributeChangedSignal("MaxHp"):Connect(refreshHp)

local toasts = make("Frame", { Size = UDim2.fromOffset(240, 76), BackgroundTransparency = 1, ClipsDescendants = false }, hudRoot)
make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toasts)

local hint = text(hudRoot, { Size = UDim2.fromOffset(260, 44), TextSize = 14, TextColor3 = COL.dark, BackgroundColor3 = COL.yellow, BackgroundTransparency = 0, TextWrapped = true, Text = "", Visible = false })
corner(hint, 12)

local function toast(msg)
	for _, c in ipairs(toasts:GetChildren()) do
		if c:IsA("TextLabel") and #toasts:GetChildren() > 3 then
			c:Destroy()
			break
		end
	end
	local accent = COL.panel
	if msg:find("^🌟") then
		accent = COL.yellow
	elseif msg:find("^😡") or msg:find("^🐕") or msg:find("^🥷") or msg:find("Pas assez") or msg:find("Sac plein") or msg:find("Base pleine") then
		accent = COL.red
	elseif msg:find("^🎯") or msg:find("^🎁") or msg:find("^♻") then
		accent = COL.green
	end
	local t = text(toasts, { Size = UDim2.new(1, 0, 0, 30), TextSize = 14, Text = msg, BackgroundColor3 = COL.pill, BackgroundTransparency = 0.08, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y })
	corner(t, 10)
	make("UIStroke", { Color = accent, Thickness = 1.5 }, t)
	make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, t)
	local sc = make("UIScale", { Scale = 0.6 }, t)
	TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Debris:AddItem(t, 3.2)
end

---------------------------------------------------------------- Pop d'éclosion
local pop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.fromOffset(340, 240), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, gui)
local popScale = make("UIScale", { Scale = 1 }, pop)
local popRarity = text(pop, { Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Text = "", TextStrokeTransparency = 0 })
local popEmoji = text(pop, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 110), TextSize = 96, Text = "" })
local popName = text(pop, { Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 36), TextSize = 28, Text = "", TextStrokeTransparency = 0 })
local popInfo = text(pop, { Position = UDim2.fromOffset(0, 180), Size = UDim2.new(1, 0, 0, 28), TextSize = 20, Text = "", TextStrokeTransparency = 0 })
local popOdds = text(pop, { Position = UDim2.fromOffset(0, 208), Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Text = "", TextColor3 = COL.muted, TextStrokeTransparency = 0.4 })
local popToken = 0
local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, gui)

local function hatchPop(info)
	local def = Config.PETS[info.p]
	if def.tier >= 4 and tryOfferLater then
		tryOfferLater("rare")
	end
	local tier = Config.TIERS[def.tier]
	popToken += 1
	local token = popToken
	popEmoji.Text = def.emoji
	popEmoji.Rotation = -14
	TweenService:Create(popEmoji, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	popRarity.Text = def.tier >= 4 and ("★ " .. string.upper(tier.name) .. " ★") or string.upper(tier.name)
	popRarity.TextColor3 = tier.color
	popRarity.TextSize = def.tier >= 4 and 28 or 20
	popName.Text = Config.petName(info.p, info.s, info.m)
	popName.TextColor3 = tier.color
	popInfo.Text = tier.name .. "  ·  +" .. fmt(info.inc) .. "/s"
	pop.Visible = true
	popScale.Scale = 0.2
	-- Révélation par rareté : style calculé (Reveal.style) d'après la rareté et la probabilité réelle « 1 sur N » envoyée par le serveur.
	local oneIn = type(info.oneIn) == "number" and info.oneIn > 0 and info.oneIn or nil
	popOdds.Text = oneIn and Config.fmtOdds(oneIn) or ""
	local reduced = Config.REVEAL.forceReduced or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	local st = Reveal.style(Config, def.tier, oneIn, reduced)
	if st.secret then
		popRarity.Text = "✦ " .. st.label .. " ✦"
		popRarity.TextColor3 = st.color
		popRarity.TextSize = 26
	end
	if Config.REVEAL.Enabled then
		RevealFx.play(gui, st, UDim2.new(0.5, 0, 0.3, -35))
	end
	local big = def.tier >= 4 or info.m > 1 or info.s >= 4
	if st.flash > 0 then
		flash.BackgroundColor3 = Config.MUTS[info.m].color or st.color
		flash.BackgroundTransparency = 1 - 0.7 * st.flash
		TweenService:Create(flash, TweenInfo.new(0.35 + 0.5 * st.flash), { BackgroundTransparency = 1 }):Play()
	end
	playSound((big or st.secret) and "rare" or "hatch")
	if st.shake > 0.2 then -- secousse de la caméra proportionnelle à la rareté
		task.spawn(function()
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then
				return
			end
			local frames = math.floor(8 + 12 * st.shake)
			for k = 1, frames do
				local amp = 0.8 * st.shake * (1 - k / frames)
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
				task.wait(0.03)
			end
			hum.CameraOffset = Vector3.zero
		end)
	end
	TweenService:Create(popScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(st.secret and 3.4 or 2.6, function()
		if token == popToken then
			pop.Visible = false
		end
	end)
end

---------------------------------------------------------------- Promesse d'accueil : visible tout de suite, ne bloque rien
-- Une carte compacte (titre, promesse, bouton vert « Jouer ») en haut au centre pendant Config.PROMISE.seconds ; le joueur peut agir pendant ce temps
-- (l'œuf de départ éclot en quelques secondes). Une seule fois par session.
local function showPromise()
	local card = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(340, 104), BackgroundColor3 = COL.bg, ZIndex = 30 }, gui)
	corner(card, 20)
	make("UIStroke", { Color = Color3.fromRGB(14, 24, 18), Thickness = 4 }, card)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 160, 110), Color3.fromRGB(20, 60, 40)), Rotation = 90 }, card)
	text(card, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30), Text = "🥚 " .. Config.TITLE, TextSize = 24, TextColor3 = COL.yellow, TextStrokeTransparency = 0.3, ZIndex = 31 })
	text(card, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 36), Text = Config.TAGLINE, TextSize = 13, TextWrapped = true, ZIndex = 31 })
	local play = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(120, 28), Text = Config.PROMISE.button, Font = FONT, TextSize = 15, ZIndex = 32 }, card)
	local st = glossy(play, "play", 12, 2)
	if st then
		play.TextColor3 = st.text
	end
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -140) }):Play()
		Debris:AddItem(card, 0.5)
	end
	play.Activated:Connect(close)
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 10) }):Play()
	task.delay(Config.PROMISE.seconds, close)
end

---------------------------------------------------------------- Introduction (nouveaux joueurs uniquement)
local introChecked = false
local function showIntro()
	local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 22, 15), BackgroundTransparency = 0.04, ZIndex = 50 }, gui)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(30, 80, 55), Color3.fromRGB(6, 16, 11)), Rotation = 90 }, f)
	local box = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 340), BackgroundTransparency = 1, ZIndex = 51 }, f)
	text(box, { Size = UDim2.new(1, 0, 0, 70), Text = "🥚 " .. Config.TITLE, TextSize = 44, TextColor3 = COL.yellow, TextStrokeTransparency = 0.4, ZIndex = 52 })
	text(box, { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 44), Text = Config.TAGLINE, TextSize = 18, TextWrapped = true, ZIndex = 52 })
	text(box, { Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 0, 140), Text = Config.LORE, TextSize = 14, TextWrapped = true, TextColor3 = COL.muted, Font = Enum.Font.Gotham, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 52 })
	local go = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 54), BackgroundColor3 = COL.yellow, Text = "Commencer l'aventure", Font = FONT, TextSize = 20, TextColor3 = COL.dark, ZIndex = 52 }, box)
	corner(go, 14)
	pressFx(go)
	go.Activated:Connect(function()
		playSound("claim")
		f:Destroy()
	end)
end

---------------------------------------------------------------- Panneaux
local panelFrame = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.8), BackgroundColor3 = COL.bg, Visible = false }, gui)
corner(panelFrame, 18)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 470) }, panelFrame)
make("UIStroke", { Color = COL.panel, Thickness = 2 }, panelFrame)
local titleLbl = text(panelFrame, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, Text = "" })
local closeBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = COL.panel, Text = "✕", Font = FONT, TextSize = 16, TextColor3 = COL.text }, panelFrame)
local closeStyle = glossy(closeBtn, "close", 12, 3)
if closeStyle then
	closeBtn.TextColor3 = closeStyle.text
end
corner(closeBtn, 17)
pressFx(closeBtn)
local tabsFrame = make("Frame", { Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1 }, panelFrame)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabsFrame)
local scroll = make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 1, -96), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panelFrame)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

local function coins()
	return player:GetAttribute("Coins") or 0
end

local function paintCost(btn, cost)
	local ok = coins() >= cost
	btn.BackgroundColor3 = ok and COL.yellow or COL.dis
	btn.TextColor3 = ok and COL.dark or Color3.fromRGB(152, 168, 158)
end

local function addRow(o)
	local f = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = COL.panel }, scroll)
	corner(f, 14)
	local ic = text(f, { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 0.7, BackgroundColor3 = Color3.new(0, 0, 0), Text = o.icon or "", TextSize = 28 })
	corner(ic, 12)
	if o.iconColor then
		make("UIStroke", { Color = o.iconColor, Thickness = 2 }, ic)
	end
	local rightPad = (o.btn and 130 or 20) + (o.btn2 and 50 or 0)
	text(f, { Position = UDim2.fromOffset(62, 5), Size = UDim2.new(1, -62 - rightPad, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, Text = o.title or "", TextColor3 = o.titleColor or COL.text, TextTruncate = Enum.TextTruncate.AtEnd })
	text(f, { Position = UDim2.fromOffset(62, 29), Size = UDim2.new(1, -62 - rightPad, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 12, Text = o.desc or "", TextColor3 = COL.muted, TextWrapped = true, Font = Enum.Font.Gotham })
	if o.btn2 then
		local b2 = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -126, 0.5, 0), Size = UDim2.fromOffset(42, 40), Text = o.btn2, Font = FONT, TextSize = 18, BackgroundColor3 = o.btn2Color or COL.dis, TextColor3 = COL.dark }, f)
		corner(b2, 10)
		pressFx(b2)
		if o.onClick2 then
			b2.Activated:Connect(o.onClick2)
		end
	end
	if o.btn then
		local b = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(112, 40), Text = o.btn, Font = FONT, TextSize = 14, AutoButtonColor = true, BackgroundColor3 = o.btnColor or COL.yellow, TextColor3 = o.btnText or COL.dark }, f)
		corner(b, 10)
		glossy(b, nil, 10, 2)
		pressFx(b)
		if o.cost then
			costBtns[b] = o.cost
			paintCost(b, o.cost)
		end
		if o.onClick then
			b.Activated:Connect(o.onClick)
		end
	end
	return f
end

local function addNote(msg)
	local l = text(scroll, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 13, TextWrapped = true, Text = msg, TextColor3 = COL.muted, Font = Enum.Font.Gotham })
	return l
end

local function avgInc(tier)
	local sum, n = 0, 0
	for _, p in ipairs(Config.PETS) do
		if p.tier == tier then
			sum += p.inc
			n += 1
		end
	end
	return sum / n
end

local tabsDef = {
	shop = { { "eggs", "🥚 Œufs" }, { "up", "⬆️ Améliorations" } },
	dex = { { "eggs", "🥚 Œufs" }, { "pets", "🐾 Pets" }, { "boosts", "⚡ Boosts" }, { "titles", "🏷 Titres" }, { "col", "📖 Index" }, { "ach", "🏅 Succès" } },
	quests = { { "story", "📜 Histoire" }, { "puzzle", "🔮 Énigme" }, { "daily", "🎯 Quotidiennes" } },
}
local titles = { shop = "Boutique", dex = "Collection", quests = "Missions", bonus = "Bonus", top = "Classement", more = "Plus" }

local render
local function setTab(t)
	panel.tab = t
	panel.confirm = false
	render()
	scroll.CanvasPosition = Vector2.new(0, 0)
end

function render()
	if not panel or not state then
		return
	end
	local keep = scroll.CanvasPosition
	for _, c in ipairs(scroll:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	for _, c in ipairs(tabsFrame:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	costBtns = {}
	titleLbl.Text = titles[panel.name]

	local tabs = tabsDef[panel.name]
	tabsFrame.Visible = tabs ~= nil
	scroll.Position = tabs and UDim2.fromOffset(10, 86) or UDim2.fromOffset(10, 50)
	scroll.Size = tabs and UDim2.new(1, -20, 1, -96) or UDim2.new(1, -20, 1, -60)
	if tabs then
		for _, t in ipairs(tabs) do
			local on = panel.tab == t[1]
			local b = make("TextButton", { Size = UDim2.new(1 / #tabs, -6, 1, 0), BackgroundColor3 = on and COL.yellow or COL.panel, Text = t[2], Font = FONT, TextSize = 14, TextScaled = #tabs > 4, TextColor3 = on and COL.dark or COL.muted }, tabsFrame)
			corner(b, 17)
			pressFx(b)
			b.Activated:Connect(function()
				setTab(t[1])
			end)
		end
	end

	if panel.name == "shop" then
		-- Fortune : icône de richesse dessinée par le code (1 pièce, petite pile, grosse pile, coffre)
		local wt = Config.wealthTier(coins())
		local wf = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = COL.bg }, scroll)
		corner(wf, 14)
		make("UIStroke", { Color = COL.panel, Thickness = 2 }, wf)
		local icon = CoinIcon.build(wf, wt, 52)
		if icon then
			icon.Position = UDim2.fromOffset(8, 6)
		end
		text(wf, { Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18, TextColor3 = COL.yellow, Text = "🪙 " .. fmt(coins()) })
		text(wf, { Position = UDim2.fromOffset(70, 34), Size = UDim2.new(1, -80, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, TextColor3 = COL.muted, Text = Config.WEALTH[wt].name })
	end
	if panel.name == "shop" and panel.tab == "eggs" then
		addNote("Achète un œuf : il va directement dans ta base. Voler chez les rivaux est gratuit mais risqué.\n🎁 Pitié : un pet de rareté supérieure est garanti dans " .. math.max(1, Config.PITY_EVERY - state.pity) .. " éclosion(s) si aucun n'est tombé d'ici là.")
		-- Carrousel d'œufs : l'œuf choisi est mis en avant, les voisins sont plus petits et sombres
		panel.eggSel = panel.eggSel or Config.carouselDefault(coins())
		local sel = panel.eggSel
		local holder = make("Frame", { Size = UDim2.new(1, -8, 0, 330), BackgroundColor3 = COL.bg }, scroll)
		corner(holder, 18)
		make("UIStroke", { Color = COL.panel, Thickness = 2 }, holder)
		local function eggCard(tierIdx, big, xScale)
			local t = Config.TIERS[tierIdx]
			local look = Config.eggLook(tierIdx)
			local color = look and look.color or t.color
			local w, h = big and 150 or 96, big and 200 or 128
			local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(xScale, 0, 0, big and 10 or 38), Size = UDim2.fromOffset(w, h), BackgroundColor3 = big and Color3.fromRGB(24, 62, 44) or Color3.fromRGB(14, 38, 28), ZIndex = big and 3 or 2 }, holder)
			corner(f, 20)
			make("UIStroke", { Color = big and color or COL.panel, Thickness = big and 4 or 2, Transparency = big and 0 or 0.3 }, f)
			make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), big and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(110, 110, 110)), Rotation = 90 }, f)
			local egg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, big and 14 or 10), Size = UDim2.fromOffset(w * 0.46, h * 0.46), BackgroundColor3 = color, ZIndex = f.ZIndex + 1 }, f)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
			make("UIStroke", { Color = Color3.fromRGB(20, 20, 30), Thickness = big and 3 or 2 }, egg)
			make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Rotation = 90 }, egg)
			local gloss = make("Frame", { Position = UDim2.fromScale(0.2, 0.12), Size = UDim2.fromScale(0.24, 0.2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = f.ZIndex + 2 }, egg)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gloss)
			text(f, { Position = UDim2.new(0, 0, 0.58, 0), Size = UDim2.new(1, 0, 0, big and 26 or 20), Text = t.name, TextSize = big and 18 or 13, TextColor3 = t.color, TextStrokeTransparency = 0.3, ZIndex = f.ZIndex + 1 })
			text(f, { Position = UDim2.new(0, 0, 0.58, big and 28 or 20), Size = UDim2.new(1, 0, 0, big and 22 or 16), Text = "🪙 " .. fmt(Config.EGG_PRICE[tierIdx]), TextSize = big and 14 or 11, TextColor3 = COL.text, ZIndex = f.ZIndex + 1 })
			if big then
				text(f, { Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 22), Text = look and look.name or "", TextSize = 12, TextColor3 = COL.muted, ZIndex = f.ZIndex + 1 })
			end
			if not big then
				f.Active = true
			end
			return f
		end
		local n = #Config.TIERS
		local prev, nxt = Config.carouselStep(sel, -1, n), Config.carouselStep(sel, 1, n)
		local leftCard, rightCard = eggCard(prev, false, 0.2), eggCard(nxt, false, 0.8)
		eggCard(sel, true, 0.5)
		for _, pair in ipairs({ { leftCard, -1 }, { rightCard, 1 } }) do
			local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8 }, pair[1])
			hit.Activated:Connect(function()
				panel.eggSel = Config.carouselStep(sel, pair[2], n)
				render()
			end)
		end
		for _, side in ipairs({ { "◀", -1, 0 }, { "▶", 1, 1 } }) do
			local ab = make("TextButton", { AnchorPoint = Vector2.new(side[3], 0), Position = UDim2.new(side[3], side[3] == 0 and 6 or -6, 0, 86), Size = UDim2.fromOffset(40, 56), Text = side[1], Font = FONT, TextSize = 22, TextColor3 = COL.dark, ZIndex = 9 }, holder)
			local st = glossy(ab, "options", 14, 3)
			if st then
				ab.TextColor3 = st.text
			end
			pressFx(ab)
			ab.Activated:Connect(function()
				panel.eggSel = Config.carouselStep(sel, side[2], n)
				render()
			end)
		end
		local info = text(holder, { Position = UDim2.fromOffset(12, 218), Size = UDim2.new(1, -24, 0, 40), TextSize = 13, TextWrapped = true, TextColor3 = COL.muted, Font = Enum.Font.Gotham, Text = "Éclot en " .. Config.fmtTime(Config.HATCH[sel] * 0.9 ^ state.up.inc) .. " · ~" .. fmt(avgInc(sel) * state.mult) .. "/s en moyenne\n" .. (sel < n and ("Un pet " .. Config.TIERS[sel + 1].name .. " est possible (pet de rareté supérieure)") or "Rareté maximale") })
		info.TextYAlignment = Enum.TextYAlignment.Top
		local buy = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(220, 52), Text = "🥚 Acheter  🪙 " .. fmt(Config.EGG_PRICE[sel]), Font = FONT, TextSize = 18, TextColor3 = COL.dark, ZIndex = 9 }, holder)
		local buyStyle = glossy(buy, "play", 18, 3)
		if buyStyle then
			buy.TextColor3 = buyStyle.text
		end
		pressFx(buy)
		costBtns[buy] = Config.EGG_PRICE[sel]
		buy.Activated:Connect(function()
			RAction:FireServer("buyEgg", sel)
		end)
	elseif panel.name == "shop" then
		for _, u in ipairs(Config.UPGRADES) do
			local l = state.up[u.key] or 0
			local maxed = l >= u.max
			addRow({
				icon = u.emoji, title = u.name .. "  (niv. " .. l .. "/" .. u.max .. ")",
				desc = maxed and "Niveau maximum" or u.desc(l),
				btn = maxed and "MAX" or ("🪙 " .. fmt(u.cost(l))), cost = (not maxed) and u.cost(l) or nil,
				btnColor = maxed and COL.dis or nil,
				onClick = (not maxed) and function()
					RAction:FireServer("buyUp", u.key)
				end or nil,
			})
		end
	elseif panel.name == "dex" and panel.tab == "col" then
		local got = 0
		for k in pairs(state.dex) do
			got += 1
		end
		addNote("📖 INDEX " .. got .. "/" .. #Config.PETS .. " · les espèces non obtenues restent grisées (❓).")
		addNote("📚 Bonus de collection : +" .. math.floor((state.collection - 1) * 100 + 0.5) .. "% de revenus définitifs (" .. got .. "/" .. #Config.PETS .. " espèces ; +" .. math.floor(Config.COLLECTION_BONUS * 100 + 0.5) .. "% tous les " .. Config.COLLECTION_STEP .. " espèces découvertes). Tailles et mutations rares multiplient aussi les revenus.")
		for i, p in ipairs(Config.PETS) do
			local d = state.dex[tostring(i)]
			local tier = Config.TIERS[p.tier]
			addRow({
				icon = d and p.emoji or "❓", iconColor = d and tier.color or nil,
				title = d and p.name or "???", titleColor = d and tier.color or COL.muted,
				desc = tier.name .. (d and (" · obtenu x" .. d.n .. " · record x" .. fmt(d.b)) or ""),
			})
		end
	elseif panel.name == "dex" and panel.tab == "ach" then
		addNote("🏅 Chaque succès a 4 paliers. Réclame ta récompense à chaque palier atteint.")
		for _, a in ipairs(Config.ACHIEVEMENTS) do
			local tier = state.ach[a.id] or 0
			local maxed = tier >= #a.goals
			local goal = a.goals[math.min(tier + 1, #a.goals)]
			local value = state.stats[a.stat] or 0
			local ready = (not maxed) and value >= goal
			addRow({
				icon = a.emoji, title = a.name .. "  (palier " .. tier .. "/" .. #a.goals .. ")",
				desc = maxed and "Tous les paliers sont réclamés !" or (fmt(math.floor(value)) .. "/" .. fmt(goal) .. " " .. a.unit .. " · récompense 🪙 " .. fmt(Config.achReward(tier + 1, player:GetAttribute("Income") or 0))),
				btn = maxed and "MAX" or (ready and "Réclamer" or "…"), btnColor = ready and COL.green or COL.dis,
				onClick = ready and function()
					RAction:FireServer("claimAch", a.id)
				end or nil,
			})
		end
	elseif panel.name == "dex" and panel.tab == "boosts" then
		local list = {}
		list[#list + 1] = { "✖️", "Multiplicateur de revenus", "x" .. string.format("%.2f", state.mult) .. " (renaissances, collection, améliorations, passes)" }
		list[#list + 1] = { "📚", "Bonus de collection", "+" .. math.floor((state.collection - 1) * 100 + 0.5) .. " % de revenus" }
		if state.luckLeft and state.luckLeft > 0 then
			list[#list + 1] = { "🧪", "Potion de chance", Config.fmtTime(state.luckLeft) .. " restantes" }
		end
		local anyPass = false
		for name, def in pairs(Config.PASSES) do
			if state.passes[name] then
				anyPass = true
				list[#list + 1] = { def.emoji, def.name, "Actif, pour toujours" }
			end
		end
		for _, b in ipairs(list) do
			addRow({ icon = b[1], title = b[2], desc = b[3] })
		end
		if not anyPass then
			addNote("Aucun pass actif. Les passes (revenus x2, chance, vitesse, VIP) sont dans l'onglet Bonus.")
		end
	elseif panel.name == "dex" and panel.tab == "titles" then
		local list = Config.titles(state.stats)
		local got = 0
		for _, t in ipairs(list) do
			if t.unlocked then
				got += 1
			end
		end
		addNote("🏷 " .. got .. "/" .. #list .. " titres. Ils se débloquent avec les paliers de succès.")
		for _, t in ipairs(list) do
			addRow({ icon = t.unlocked and "🏷" or "🔒", title = t.unlocked and t.name or "???", titleColor = t.unlocked and COL.yellow or COL.muted, desc = t.desc })
		end
	elseif panel.name == "dex" and panel.tab == "eggs" then
		local n = 0
		for i = 1, state.cap do
			local sl = state.slots[i]
			if sl and sl.k == "e" then
				n += 1
				addRow({
					icon = "🥚", iconColor = Config.TIERS[sl.t].color, title = "Œuf " .. Config.TIERS[sl.t].name, titleColor = Config.TIERS[sl.t].color,
					desc = "En train d'éclore · revente à " .. math.floor(Config.EGG_SELL_RATIO * 100) .. " % du prix",
					btn = "Vendre " .. fmt(Config.eggSellValue(sl.t)), btnColor = COL.red, btnText = COL.text,
					onClick = function()
						RAction:FireServer("sellEgg", i)
					end,
				})
			end
		end
		if n == 0 then
			addNote("Aucun œuf dans ta base. Achète-en dans la boutique ou chipe-en chez un rival !")
		end
	elseif panel.name == "dex" then
		local n = 0
		local dupes, dupeTotal = Config.dupesToSell(state.slots, state.cap)
		if #dupes > 0 then
			addRow({
				icon = "♻️", title = "Revendre les doublons (" .. #dupes .. ")", desc = "Garde le meilleur pet de chaque espèce.",
				btn = "+" .. fmt(dupeTotal), btnColor = COL.green,
				onClick = function()
					RAction:FireServer("sellDupes")
				end,
			})
		end
		for i = 1, state.cap do
			local sl = state.slots[i]
			if sl and sl.k == "p" then
				n += 1
				local p = Config.PETS[sl.p]
				local equipped = false
				for _, v in ipairs(state.equip) do
					if v == i then
						equipped = true
					end
				end
				addRow({
					icon = p.emoji, iconColor = Config.TIERS[p.tier].color, title = Config.petName(sl.p, sl.s, sl.m),
					desc = "+" .. fmt(Config.petIncome(sl.p, sl.s, sl.m) * state.mult) .. "/s" .. (equipped and " · te suit 🐾" or ""),
					btn2 = "🐾", btn2Color = equipped and COL.green or COL.dis,
					onClick2 = function()
						RAction:FireServer("equip", i)
					end,
					btn = "Vendre " .. fmt(Config.sellValue(sl.p, sl.s, sl.m)), btnColor = COL.red, btnText = COL.text,
					onClick = function()
						RAction:FireServer("sell", i)
					end,
				})
			end
		end
		if n == 0 then
			addNote("Aucun pet pour l'instant. Fais éclore des œufs !")
		else
			addNote("🐾 = fais-le te suivre (3 maximum). Il continue de produire dans ta base.")
		end
	elseif panel.name == "quests" and panel.tab == "story" then
		local ch = state.story.ch
		local total = #Config.STORY
		local rank = Config.rankFor(ch)
		local nextRank
		for _, r in ipairs(Config.RANKS) do
			if r.chapter > ch and not nextRank then
				nextRank = r
			end
		end
		addRow({
			icon = rank.emoji, iconColor = COL.yellow, title = "Rang : " .. rank.name,
			desc = "Chapitres réussis : " .. ch .. "/" .. total .. (nextRank and (" · prochain rang (" .. nextRank.name .. ") au chapitre " .. nextRank.chapter) or " · rang suprême !"),
		})
		local c = Config.STORY[ch + 1]
		if c then
			addNote("📜 Chapitre " .. (ch + 1) .. " : " .. c.title .. "\n" .. c.text)
			local ready = state.story.prog >= c.goal
			addRow({
				icon = "🎯", title = Config.storyGoalText(c),
				desc = fmt(math.floor(state.story.prog)) .. "/" .. fmt(c.goal) .. " · récompense 🪙 " .. fmt(Config.storyReward(c, player:GetAttribute("Income") or 0)),
				btn = ready and "Réclamer" or "…", btnColor = ready and COL.green or COL.dis,
				onClick = ready and function()
					RAction:FireServer("claimStory")
				end or nil,
			})
		else
			addNote("👑 Histoire terminée : tu es Roi des Couvées ! Les missions quotidiennes et les événements continuent.")
		end
		for _, z in ipairs(Config.ZONES) do
			if z.chapter > ch then
				addRow({ icon = "🔒", title = z.name, desc = "S'ouvre au chapitre " .. z.chapter .. " de l'histoire (ses œufs sont plus rares)." })
			end
		end
		if ch > 0 then
			local done = {}
			for i = 1, ch do
				done[#done + 1] = "✅ " .. i .. ". " .. Config.STORY[i].title
			end
			addNote(table.concat(done, "\n"))
		end
	elseif panel.name == "quests" and panel.tab == "puzzle" then
		addNote("📜 Énigme de Mère Poule (elle change chaque jour) :\n" .. state.riddle)
		local cur = {}
		for i, dir in ipairs(Config.RUNE_DIRECTIONS) do
			cur[#cur + 1] = dir .. " " .. Config.RUNES[state.runes[i]]
		end
		addRow({
			icon = state.puzzleDone and "✅" or "🔮",
			title = state.puzzleDone and "Énigme résolue aujourd'hui !" or ("Tes runes : " .. table.concat(cur, " · ")),
			desc = state.puzzleDone and "Reviens demain pour une nouvelle énigme." or "Tourne chaque rune autour du Grand Nid, puis touche le Nid pour valider.",
		})
		addNote("Le Nord est du côté des rivaux. Chaque rune a 4 symboles : " .. table.concat(Config.RUNES, " ") .. ". Récompense : un œuf " .. Config.TIERS[Config.PUZZLE_EGG_TIER].name .. " et des pièces. Une résolution par jour (une pause de quelques secondes suit chaque erreur). Énigmes résolues : " .. state.puzzleSolved .. ".")
	elseif panel.name == "quests" then
		addNote("Les missions se renouvellent chaque jour.")
		for i, q in ipairs(state.quests) do
			local done = q.prog >= q.goal
			addRow({
				icon = q.claimed and "✅" or "🎯", title = Config.questText(q.t, q.goal),
				desc = fmt(math.floor(q.prog)) .. "/" .. fmt(q.goal) .. " · récompense " .. Config.questRewardText(q),
				btn = q.claimed and "Fait" or (done and "Réclamer" or "…"),
				btnColor = (done and not q.claimed) and COL.green or COL.dis,
				onClick = (done and not q.claimed) and function()
					RAction:FireServer("claimQuest", i)
				end or nil,
			})
		end
	elseif panel.name == "top" then
		if not topData then
			addNote("Chargement du classement…")
		elseif #topData == 0 then
			addNote("Le classement est vide pour l'instant (ou indisponible dans Studio). Renaître et faire éclore des œufs te fait monter.")
		else
			addNote("Classé par renaissances puis par œufs éclos.")
			for i, e in ipairs(topData) do
				addRow({ icon = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or tostring(i), title = e.name, desc = "♻️ " .. e.rb .. " renaissance(s) · 🥚 " .. fmt(e.hatched) .. " éclos" })
			end
		end
	elseif panel.name == "bonus" then
		addRow({
			icon = "🎁", title = "Bonus quotidien",
			desc = state.dailyReady and ("Série " .. state.streak .. " jour(s) → 🪙 " .. fmt(state.dailyReward)) or "Reviens demain !",
			btn = state.dailyReady and "Récupérer" or "Pris", btnColor = state.dailyReady and COL.green or COL.dis,
			onClick = state.dailyReady and function()
				RAction:FireServer("daily")
			end or nil,
		})
		local passNames = {}
		for name in pairs(Config.PASSES) do
			passNames[#passNames + 1] = name
		end
		table.sort(passNames)
		for _, name in ipairs(passNames) do
			local def = Config.PASSES[name]
			local owned = state.passes[name]
			addRow({
				icon = def.emoji, title = def.name, desc = def.desc,
				btn = owned and "✅ Actif" or (Config.purchasable(def) and "Acheter" or "Bientôt"),
				btnColor = (owned or not Config.purchasable(def)) and COL.dis or COL.green,
				onClick = (not owned) and function()
					if Config.purchasable(def) then
						MarketplaceService:PromptGamePassPurchase(player, def.id)
					else
						toast(Config.UNAVAILABLE_MESSAGE)
					end
				end or nil,
			})
		end
		if state.luckLeft and state.luckLeft > 0 then
			addNote("🧪 Potion de chance active : " .. Config.fmtTime(state.luckLeft) .. " restantes.")
		end
		local prodNames = {}
		for name in pairs(Config.PRODUCTS) do
			prodNames[#prodNames + 1] = name
		end
		table.sort(prodNames)
		for _, name in ipairs(prodNames) do
			local def = Config.PRODUCTS[name]
			local used = def.once == true and state.starter == true
			addRow({
				icon = def.emoji, title = def.name, desc = def.desc,
				btn = used and "✅ Acheté" or (Config.purchasable(def) and "Acheter" or "Bientôt"), btnColor = (used or not Config.purchasable(def)) and COL.dis or COL.green,
				onClick = used and nil or function()
					if Config.purchasable(def) then
						MarketplaceService:PromptProductPurchase(player, def.id)
					else
						toast(Config.UNAVAILABLE_MESSAGE)
					end
				end,
			})
		end
	elseif panel.name == "more" then
		local cost = Config.rebirthCost(state.rb)
		addRow({
			icon = "♻️", title = "Renaissance" .. (state.rb > 0 and (" (x" .. state.rb .. ")") or ""),
			desc = "Remet pièces, pets et améliorations à zéro. Garde vitesse et collection. Revenus +50% définitif.",
			btn = panel.confirm and "Confirmer ?" or ("🪙 " .. fmt(cost)),
			btnColor = panel.confirm and COL.red or nil, btnText = panel.confirm and COL.text or nil, cost = (not panel.confirm) and cost or nil,
			onClick = function()
				if coins() < cost then
					return toast("Il te faut 🪙 " .. fmt(cost) .. " pour renaître.")
				end
				if panel.confirm then
					RAction:FireServer("rebirth")
					panel.confirm = false
					render()
				else
					panel.confirm = true
					render()
				end
			end,
		})
		if Config.Game.roleFor(game.PlaceId) == "game" then
			addRow({ icon = "🏠", title = "Retour au hub", desc = "Quitte la partie (ta progression est sauvegardée) pour choisir une autre partie.", btn = "Partir", btnColor = COL.green, onClick = function()
				RAction:FireServer("toHub")
			end })
		end
		local function replay(kind)
			return function()
				local ev = ReplicatedStorage:FindFirstChild("ReplayCinematic")
				if ev then
					hidePanel()
					ev:Fire(kind)
				else
					toast("🎬 La cinématique n'est pas disponible pour l'instant.")
				end
			end
		end
		if Config.Cinematics.replay and Config.cineEnabled("intro") then
			addRow({ icon = "🎬", title = "Revoir l'intro", desc = "La ferme, Mère Poule et le but du jeu (tu peux la passer).", btn = "Lancer", btnColor = COL.green, onClick = replay("intro") })
		end
		if Config.Cinematics.replay and Config.cineEnabled("tutorial") then
			addRow({ icon = "🎓", title = "Revoir le tutoriel", desc = "Récolte, éclosion et zones en quelques secondes.", btn = "Lancer", btnColor = COL.green, onClick = replay("tutorial") })
		end
		addNote(string.format("Œufs volés : %d · Œufs éclos : %d · Vitesse : %s", state.stolen, state.hatched, fmt(player:GetAttribute("Speed") or 0)))
		addNote(Config.oddsText())
		addNote("📖 " .. Config.LORE)
		addNote("Comment jouer : maintiens le bouton de vol devant un œuf pour le prendre (évite le gardien 🐕), rapporte-le dans ta base, touche-le pour accélérer l'éclosion. Cours sur le tapis pour gagner en vitesse. Les autres joueurs peuvent voler tes œufs non protégés 🛡 !")
	end
	task.defer(function()
		scroll.CanvasPosition = keep
	end)
end

-- Transitions : le menu s'ouvre en rebondissant légèrement et se referme en rétrécissant (Config.Animations.menuTransitions).
local panelScale = make("UIScale", { Scale = 1 }, panelFrame)
local hideToken = 0
local function showPanel()
	hideToken += 1 -- annule une fermeture en cours
	panelFrame.Visible = true
	panelScale.Scale = 1
	if Config.animEnabled("menuTransitions") then
		pcall(function()
			panelScale.Scale = 0.88
			TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end
end
local function hidePanel()
	panel = nil
	if Config.animEnabled("menuTransitions") then
		local ok = pcall(function()
			hideToken += 1
			local token = hideToken
			TweenService:Create(panelScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.92 }):Play()
			task.delay(0.1, function()
				if token == hideToken and not panel then
					panelFrame.Visible = false
					panelScale.Scale = 1
				end
			end)
		end)
		if ok then
			return
		end
	end
	panelFrame.Visible = false
end

local function openPanel(name)
	if panel and panel.name == name then
		hidePanel()
		return
	end
	panel = { name = name, tab = tabsDef[name] and tabsDef[name][1][1] or "", confirm = false }
	showPanel()
	if name == "top" then
		RAction:FireServer("top")
	end
	render()
end
closeBtn.Activated:Connect(hidePanel)

-- Manette et clavier : X = boutique, Y = missions, B (ou Échap) = fermer ; clavier B / M / Q / O. Un appui sur la touche du menu ouvert le ferme.
-- (Config.HUD.shortcuts). À la manette, le premier bouton du menu est sélectionné pour naviguer avec le stick.
if Config.HUD.shortcuts then
	local function bind(name, handler, ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				handler()
			end
			return Enum.ContextActionResult.Pass
		end, false, ...)
	end
	bind("ChipeShop", function()
		openPanel("shop")
	end, Enum.KeyCode.ButtonX, Enum.KeyCode.B)
	bind("ChipeQuests", function()
		openPanel("quests")
	end, Enum.KeyCode.ButtonY, Enum.KeyCode.Q)
	bind("ChipeMore", function()
		openPanel("more")
	end, Enum.KeyCode.ButtonSelect, Enum.KeyCode.O)
	bind("ChipeClose", function()
		if panelFrame.Visible then
			hidePanel()
		end
	end, Enum.KeyCode.ButtonB)
	local function selectFirst()
		if UserInputService.GamepadEnabled and panelFrame.Visible then
			pcall(function()
				GuiService.SelectedObject = closeBtn
			end)
		end
	end
	panelFrame:GetPropertyChangedSignal("Visible"):Connect(selectFirst)
end

---------------------------------------------------------------- Boutons de navigation (colonne gauche)
local navDefs = { { "shop", "🛒", "Boutique" }, { "dex", "📖", "Pets" }, { "quests", "🎯", "Missions" }, { "bonus", "🎁", "Bonus" }, { "top", "🏆", "Top" }, { "more", "♻️", "Plus" } }
local navBar = make("Frame", { Size = UDim2.fromOffset(Layout.NAV_BUTTON, #navDefs * (Layout.NAV_BUTTON + Layout.NAV_GAP) - Layout.NAV_GAP), BackgroundTransparency = 1 }, hudRoot)
make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, Layout.NAV_GAP), HorizontalAlignment = Enum.HorizontalAlignment.Center }, navBar)
local navDots = {}
for _, n in ipairs(navDefs) do
	local b = make("TextButton", { Size = UDim2.fromOffset(52, 52), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = true }, navBar)
	corner(b, 14)
	pressFx(b)
	local navStyle = glossy(b, Config.UI.nav[n[1]], 14, 3)
	if not navStyle then
		make("UIStroke", { Color = COL.panel, Thickness = 2 }, b)
	end
	local navText = navStyle and navStyle.text or COL.text
	text(b, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 2), Text = n[2], TextSize = 22, TextColor3 = navText })
	text(b, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 33), Text = n[3], TextSize = 10, TextColor3 = navText })
	local dot = make("Frame", { Size = UDim2.fromOffset(13, 13), Position = UDim2.new(1, -14, 0, 1), BackgroundColor3 = COL.red, Visible = false, ZIndex = 5 }, b)
	corner(dot, 7)
	navDots[n[1]] = dot
	b.Activated:Connect(function()
		openPanel(n[1])
	end)
end

-- Carte « objectif en cours » : chapitre de l'histoire, avancement, un appui ouvre Missions > Histoire.
local objCard = make("TextButton", { Size = UDim2.fromOffset(196, 62), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false, Visible = false }, hudRoot)
corner(objCard, 14)
local objStroke = make("UIStroke", { Color = COL.panel, Thickness = 2 }, objCard)
local objTitle = text(objCard, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 17), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextColor3 = COL.yellow, Text = "", TextTruncate = Enum.TextTruncate.AtEnd })
local objText = text(objCard, { Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 11, TextColor3 = COL.text, TextWrapped = true, Text = "" })
local objBarBg = make("Frame", { Position = UDim2.fromOffset(8, 47), Size = UDim2.new(1, -16, 0, 8), BackgroundColor3 = COL.bg }, objCard)
corner(objBarBg, 4)
local objBar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.green }, objBarBg)
corner(objBar, 4)
objCard.Activated:Connect(function()
	openPanel("quests")
end)
local function refreshObjective()
	local tut = state and Config.tutorial(state.stats)
	if tut then -- tutoriel des premières minutes : prioritaire sur l'objectif de l'histoire
		objCard.Visible = not panelFrame.Visible
		objTitle.Text = "🎯 Objectif " .. tut.index .. "/" .. tut.total
		objText.Text = tut.text .. " (" .. fmt(tut.prog) .. "/" .. fmt(tut.goal) .. ")"
		objStroke.Color = COL.yellow
		TweenService:Create(objBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(tut.goal > 0 and tut.prog / tut.goal or 1, 1) }):Play()
		return
	end
	local o = state and Config.HUD.objective and Config.objective(state.story)
	objCard.Visible = o ~= nil and o ~= false and not (panelFrame.Visible)
	if not o then
		return
	end
	objTitle.Text = (o.done and "✅ " or "📜 ") .. o.index .. "/" .. o.total .. " · " .. o.title
	objText.Text = o.done and "Terminé ! Touche pour réclamer ta récompense." or (o.text .. " (" .. fmt(o.prog) .. "/" .. fmt(o.goal) .. ")")
	objStroke.Color = o.done and COL.green or COL.panel
	TweenService:Create(objBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(o.goal > 0 and o.prog / o.goal or 1, 1) }):Play()
end

-- Offre d'achat « au bon moment » (Config.boostOffer) : carte non bloquante, un appui ouvre les bonus, ✕ la ferme, elle disparaît seule.
local offerCard = text(hudRoot, { Size = UDim2.fromOffset(260, 44), TextSize = 13, TextColor3 = COL.dark, BackgroundColor3 = COL.green, BackgroundTransparency = 0, TextWrapped = true, Text = "", Visible = false })
offerCard.Active = true
corner(offerCard, 12)
local offerClose = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = COL.panel, Text = "✕", Font = FONT, TextSize = 14, TextColor3 = COL.text }, offerCard)
corner(offerClose, 13)
local offerToken, offerShown, offerLast, joinedAt = 0, 0, nil, os.clock()
local function hideOffer()
	offerToken += 1
	offerCard.Visible = false
end
local offerBtn = make("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, -36, 1, 0), Text = "", ZIndex = 2 }, offerCard)
offerBtn.Activated:Connect(function()
	hideOffer()
	openPanel("bonus")
end)
offerClose.Activated:Connect(hideOffer)
local function tryOffer(ev)
	if not state or panelFrame.Visible then
		return
	end
	local o = Config.boostOffer(ev, state.passes, os.clock(), offerLast, offerShown, joinedAt)
	if not o then
		return
	end
	offerShown += 1
	offerLast = os.clock()
	offerToken += 1
	local token = offerToken
	local def = Config.PASSES[o.pass]
	offerCard.Text = "   " .. def.emoji .. " " .. o.text .. " ›"
	offerCard.Visible = true
	task.delay(12, function()
		if token == offerToken then
			offerCard.Visible = false
		end
	end)
end

tryOfferLater = tryOffer

hudParts.objective, hudParts.carry, hudParts.banner, hudParts.toasts, hudParts.hint, hudParts.nav, hudParts.offer = objCard, carryLbl, banner, toasts, hint, navBar, offerCard

-- Place tout le HUD selon la taille réelle de l'écran (recalculé quand la fenêtre change : rotation, redimensionnement de Studio).
local function applyLayout()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(900, 520)
	if vs.X < 50 or vs.Y < 50 then
		return
	end
	local rects, scale, dw, dh = Layout.rects(vs.X, vs.Y, #navDefs)
	hudScale.Scale = scale
	hudRoot.Size = UDim2.fromOffset(dw, dh)
	for name, obj in pairs(hudParts) do
		local r = rects[name]
		if r then
			obj.Position = UDim2.fromOffset(r.x, r.y)
			if name == "banner" or name == "hint" or name == "toasts" or name == "offer" then
				obj.Size = UDim2.fromOffset(r.w, r.h)
			end
		end
	end
end
applyLayout()
local function watchViewport()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	end
end
watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchViewport()
	applyLayout()
end)

---------------------------------------------------------------- Réseau
-- Symboles des runes : l'état est propre à chaque joueur, on affiche donc le sien sur les pierres (modification locale uniquement).
local function updateRuneLabels()
	if not state then
		return
	end
	for _, stone in ipairs(CollectionService:GetTagged("RuneStone")) do
		local lbl = stone:FindFirstChild("Label")
		local txt = lbl and lbl:FindFirstChild("Text")
		local idx = stone:GetAttribute("Idx")
		if txt and idx then
			txt.Text = Config.RUNES[state.runes[idx]] or "?"
		end
	end
end

-- Reconstruire le panneau détruit ses boutons : si le joueur vient d'appuyer, on attend que le clic soit terminé.
local renderToken = 0
local function renderSoon()
	local waitTime = 0.6 - (os.clock() - lastPress)
	if waitTime <= 0 then
		render()
		return
	end
	renderToken += 1
	local token = renderToken
	task.delay(waitTime, function()
		if token == renderToken then
			render()
		end
	end)
end

RState.OnClientEvent:Connect(function(snap)
	state = snap
	updateRuneLabels()
	if not introChecked then
		introChecked = true
		if snap.story.ch == 0 and snap.hatched == 0 and not Config.cineEnabled("intro") then
			showIntro() -- version texte, seulement si la cinématique d'intro est coupée
		end
	end
	if panel then
		renderSoon()
	end
end)
RNotify.OnClientEvent:Connect(function(msg, sfx)
	toast(msg)
	if sfx then
		playSound(sfx)
	end
end)
RHatch.OnClientEvent:Connect(hatchPop)
RTop.OnClientEvent:Connect(function(list)
	topData = list
	if panel and panel.name == "top" then
		renderSoon()
	end
end)

local function refreshStats()
	coinsBig.Text = fmt(coins())
	coinsSmall.Text = "+" .. fmt(player:GetAttribute("Income") or 0) .. "/s"
	speedBig.Text = fmt(math.floor(player:GetAttribute("Speed") or 0))
	for b, cost in pairs(costBtns) do
		if b.Parent then
			paintCost(b, cost)
		else
			costBtns[b] = nil
		end
	end
end
local lastCoins = nil
player:GetAttributeChangedSignal("Coins"):Connect(function()
	local c = coins()
	local delta = lastCoins and (c - lastCoins) or 0
	lastCoins = c
	if delta > math.max((player:GetAttribute("Income") or 0) * 2.5, 8) then
		coinsScale.Scale = 1.18
		TweenService:Create(coinsScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local f = text(hudRoot, { Position = UDim2.fromOffset(212, 16), Size = UDim2.fromOffset(120, 30), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, TextColor3 = COL.green, Text = "+" .. fmt(delta), TextStrokeTransparency = 0.3 })
		TweenService:Create(f, TweenInfo.new(1.1), { Position = UDim2.fromOffset(212, -6), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(f, 1.2)
	end
end)
for _, a in ipairs({ "Coins", "Income", "Speed" }) do
	player:GetAttributeChangedSignal(a):Connect(refreshStats)
end
refreshStats()

task.spawn(function() -- promesse d'accueil dès que l'état est reçu (une fois)
	repeat
		task.wait(0.2)
	until state
	pcall(showPromise)
end)

task.spawn(function()
	repeat
		RAction:FireServer("sync")
		task.wait(1.5)
	until state
end)

---------------------------------------------------------------- Bannière d'événement, compteur de sac, conseils
task.spawn(function()
	while true do
		local key = workspace:GetAttribute("EventKey")
		local ends = workspace:GetAttribute("EventEnds")
		banner.Visible = false
		if key and ends then
			for _, e in ipairs(Config.EVENTS) do
				if e.key == key then
					banner.Text = e.emoji .. " " .. e.name .. " · " .. e.desc .. " · " .. math.max(0, ends - os.time()) .. "s"
					banner.Visible = true
				end
			end
		end
		if state then
			local claimable = state.story.prog >= (Config.STORY[state.story.ch + 1] and Config.STORY[state.story.ch + 1].goal or math.huge)
			for _, q in ipairs(state.quests) do
				if q.prog >= q.goal and not q.claimed then
					claimable = true
				end
			end
			navDots.quests.Visible = claimable
			navDots.bonus.Visible = state.dailyReady
			local achReady = false
			for _, a in ipairs(Config.ACHIEVEMENTS) do
				local tier = state.ach[a.id] or 0
				if tier < #a.goals and (state.stats[a.stat] or 0) >= a.goals[tier + 1] then
					achReady = true
				end
			end
			navDots.dex.Visible = achReady
			updateRuneLabels()
			carryLbl.Visible = state.carry > 0
			carryLbl.Text = "🥚 " .. state.carry .. "/" .. state.carryCap
			local nextHint = Config.nextHint({ hatched = state.hatched, stolen = state.stolen, speed = player:GetAttribute("Speed") or 0 })
			local msg = nextHint and nextHint.text
			if Config.tutorial(state.stats) then
				msg = nil -- la barre d'objectif du tutoriel guide déjà : un seul conseil à l'écran
			end
			hint.Visible = msg ~= nil and not panelFrame.Visible and not offerCard.Visible
			local ms = math.floor(state.hatched / 25)
			if ms > (lastMilestone or ms) then
				tryOffer("milestone")
			end
			lastMilestone = ms
			refreshObjective()
			hint.Text = msg or ""
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Prompts de vol : durée selon ton niveau, cachés pour ton propre œuf
-- (propriétés modifiées côté client uniquement : elles ne se répliquent pas au serveur)
task.spawn(function()
	while true do
		local lvl = state and state.up.fing or 0
		for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
			pr.HoldDuration = Config.stealTime(lvl)
			local rival = pr:GetAttribute("Rival")
			local open = rival == nil or (state ~= nil and Config.zoneUnlocked(state.story.ch, rival))
			pr.Enabled = pr:GetAttribute("Owner") ~= player.UserId and open
		end
		-- (les barrières de zone sont gérées par Animations.client.lua)
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Pets qui "respirent" (animation locale)
local bobBase = setmetatable({}, { __mode = "k" })
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, m in ipairs(CollectionService:GetTagged("Bob")) do
		local base = bobBase[m]
		if not base and m.PrimaryPart then
			base = m:GetPivot()
			bobBase[m] = base
		end
		if base then
			if Config.animEnabled("petStates") then
				-- états des pets : respiration (idle) ; capacité (saut en vrille) pour les raretés élevées, périodique
				local seed = base.X + base.Z
				local ability = nil
				if (m:GetAttribute("Tier") or 1) >= Config.PET_STATES.abilityMinTier then
					ability = Easing.abilityProgress(t, seed, Config.PET_STATES.abilityInterval)
				end
				local pose = ability and Easing.petPose("ability", t, seed, ability) or Easing.petPose("idle", t, seed)
				m:PivotTo(base * CFrame.new(0, pose.y, 0) * CFrame.Angles(pose.pitch, pose.yaw, 0))
			else
				m:PivotTo(base * CFrame.new(0, math.sin(t * 3 + base.X + base.Z) * 0.25, 0))
			end
		end
	end
end)

---------------------------------------------------------------- Flèche de guidage (faisceau jaune vers le prochain objectif)
local guideBeam, guideA0, guideA1, guideTarget
local function setGuide(target)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (target and root and target.Parent) then
		if guideBeam then
			guideBeam.Enabled = false
		end
		guideTarget = nil
		return
	end
	if not guideBeam then
		guideA0 = Instance.new("Attachment")
		guideA1 = Instance.new("Attachment")
		guideBeam = Instance.new("Beam")
		guideBeam.Attachment0 = guideA0
		guideBeam.Attachment1 = guideA1
		guideBeam.Width0 = 0.6
		guideBeam.Width1 = 0.6
		guideBeam.Color = ColorSequence.new(COL.yellow)
		guideBeam.Transparency = NumberSequence.new(0.25)
		guideBeam.LightEmission = 1
		guideBeam.FaceCamera = true
		guideBeam.Parent = workspace
	end
	if guideA0.Parent ~= root then
		guideA0.Parent = root
	end
	if guideTarget ~= target then
		guideA1.Parent = target
		guideTarget = target
	end
	guideBeam.Enabled = true
end

task.spawn(function()
	while true do
		local target = nil
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if state and root then
			if state.carry > 0 then
				local spawnPad = player.RespawnLocation
				target = spawnPad
			elseif state.hatched > 0 and state.stolen == 0 then
				local best, bd = nil, math.huge
				for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
					if pr:GetAttribute("Owner") == nil and pr.Parent and pr.Parent:IsA("BasePart") then
						local dd = (pr.Parent.Position - root.Position).Magnitude
						if dd < bd then
							best, bd = pr.Parent, dd
						end
					end
				end
				target = best
			elseif (player:GetAttribute("Speed") or 0) < 8 and state.stolen > 0 then
				local w = workspace:FindFirstChild("World")
				target = w and w:FindFirstChild("Treadmill")
			end
		end
		setGuide(target)
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Pets suiveurs (mouvement fluide calculé localement)
RunService.RenderStepped:Connect(function(dt)
	for _, m in ipairs(CollectionService:GetTagged("Follower")) do
		local owner = Players:GetPlayerByUserId(m:GetAttribute("OwnerId") or 0)
		local char = owner and owner.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and m.PrimaryPart then
			local n = m:GetAttribute("Idx") or 1
			local target = CFrame.new(root.Position) * root.CFrame.Rotation * CFrame.new((n - 2) * 3, -2.2 + math.sin(os.clock() * 4 + n) * 0.15, 4)
			if Config.animEnabled("petStates") then
				-- état « move » : bonds penchés vers l'avant quand le propriétaire se déplace, sinon respiration
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
				local pose = Easing.petPose(moving and "move" or "idle", os.clock(), n * 1.7)
				target = target * CFrame.new(0, pose.y, 0) * CFrame.Angles(pose.pitch, pose.yaw, 0)
			end
			m:PivotTo(m:GetPivot():Lerp(target, 1 - math.exp(-8 * dt)))
		end
	end
end)

---------------------------------------------------------------- Effets du monde
-- Apparition des pets, onde de choc, récolte, œufs, visages, barrières de zone, confettis : voir Animations.client.lua (activables dans Config.Animations).

-- Tapis roulant : les rayures défilent à la vitesse du tapis (-14 studs/s).
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, st in ipairs(CollectionService:GetTagged("BeltStripe")) do
		local z0, cz = st:GetAttribute("Z0"), st:GetAttribute("CenterZ")
		if z0 and cz then
			local rel = ((z0 - 14 * t + 20) % 40) - 20
			local p = st.Position
			st.Position = Vector3.new(p.X, p.Y, cz + rel)
		end
	end
end)

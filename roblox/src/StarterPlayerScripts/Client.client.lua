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
local SlotFx = require(script.Parent:WaitForChild("SlotFx"))
local VfxKitMod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VfxKit"))
local Vfx = VfxKitMod.new(Config, Easing)
local CoinIcon = require(script.Parent:WaitForChild("CoinIcon"))
local Riddle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Riddle")) -- énigme de la Mère Poule (règles pures, lot 6)
local Calendar = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calendar")) -- calendrier de 30 jours (règles pures, lot 9b : textes des cartes)
local HenUi = require(script.Parent:WaitForChild("HenUi")) -- dialogue, ❗, plumes, berceuse, cible du faisceau
-- Lot 10 : compteur « 1 sur N », écran d'éclosion (HatchPlan + HatchFx), icônes Decal publiées par le serveur. Table unique (limite de 200 variables locales).
local L10 = {
	Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")),
	HatchPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HatchPlan")),
	HatchFx = require(script.Parent:WaitForChild("HatchFx")),
	seenTier = {}, -- raretés déjà vues dans cette session (écran non passable seulement la toute première fois, r >= 8)
}
-- « 1 sur N » figé par le serveur, ou « — » (pet éclos avant le lot 10, jamais recalculé).
function L10.oddsText(o)
	if type(o) == "number" and o == o and o >= 1 then
		local t = L10.Odds.label(o)
		if type(t) == "string" and t ~= "" then
			return t
		end
	end
	return "—"
end
-- Clé d'icône d'une récompense du calendrier (tirage, œuf de rareté, cosmétique, titre, plumes, jetons, parchemins, pièces).
function L10.calIcon(rw)
	if rw.draw then
		return "r_mystere"
	elseif rw.egg then
		return "egg_r" .. rw.egg
	elseif rw.cosm then
		return "r_cosmetique_traine"
	elseif rw.title then
		return "r_titre"
	elseif rw.plumes then
		return "r_plume"
	elseif rw.tokens then
		return "r_jeton_combat"
	elseif rw.scrolls then
		return "r_parchemin_xp"
	end
	return (rw.c or 0) >= 40 and "r_coins_l" or ((rw.c or 0) >= 15 and "r_coins_m" or "r_coins_s")
end
-- Icône d'interface (Config.ICONS) : URL d'image publiée par le serveur (attribut du dossier ReplicatedStorage.Icons), sinon nil (l'appelant garde son emoji).
function L10.iconUrl(key)
	local folder = ReplicatedStorage:FindFirstChild("Icons")
	local url = folder and folder:GetAttribute(key)
	if type(url) == "string" and url ~= "" then
		return url
	end
	return nil
end
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RState, RNotify, RHatch, RAction = Remotes:WaitForChild("State"), Remotes:WaitForChild("Notify"), Remotes:WaitForChild("Hatch"), Remotes:WaitForChild("Action")
local RTop = Remotes:WaitForChild("Top")
local RHen = Remotes:WaitForChild("Hen")
local RRaven = Remotes:WaitForChild("Raven") -- Corbeau chipeur (lot 7) : alerte de la victime, liste des cibles
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
local henUi = nil -- interface de l'énigme (créée après le HUD)
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
-- Un seul objet Sound par type (réutilisé), volume = définition x réglage général (menu Plus), rien (hors clics) avant que la carte soit prête,
-- aucune erreur si un son ne se charge pas (tout sous pcall).
local soundPool = {}
local soundReady = false -- vrai à la première réception de l'état du joueur (carte et joueur prêts)
local volumeIdx = 1
local function masterVolume()
	return Config.VOLUME_STEPS[volumeIdx] or 1
end
local function getSound(key)
	local snd = soundPool[key]
	if snd and snd.Parent then
		return snd
	end
	local def = Config.SOUNDS[key]
	if not def or def.id == "" then
		return nil
	end
	local alias = Config.SOUND_ALIAS[key] and Config.SOUNDS[Config.SOUND_ALIAS[key]] -- lot 10 : ancienne clé jouée avec le son approuvé (nom et volume d'origine)
	local soundId = (alias and alias.id ~= "") and alias.id or def.id
	local ok, made = pcall(function()
		local s = Instance.new("Sound")
		s.Name = "Sfx_" .. key
		s.SoundId = soundId
		s.PlaybackSpeed = (soundId ~= def.id) and (alias.speed or 1) or (def.speed or 1)
		s.Looped = def.loop == true
		s.Parent = game:GetService("SoundService")
		return s
	end)
	if ok then
		soundPool[key] = made
		return made
	end
	return nil
end
local function playSound(key)
	if not soundReady and key ~= "click" and key ~= "menu" then
		return
	end
	local vol = Config.soundVolume(key, masterVolume())
	if vol <= 0 then
		return
	end
	pcall(function()
		local snd = getSound(key)
		if snd then
			snd.Volume = vol
			snd.TimePosition = 0
			snd:Play()
		end
	end)
end
-- Boucle (ambiance, lame, boulet) : factor 0..1 = proximité ; en dessous de 1 % elle s'arrête.
local function setLoop(key, factor)
	pcall(function()
		local vol = Config.soundVolume(key, masterVolume()) * (factor or 1)
		local snd = vol > 0.005 and getSound(key) or soundPool[key]
		if not snd then
			return
		end
		if vol > 0.005 then
			snd.Volume = vol
			if not snd.IsPlaying then
				snd:Play()
			end
		elseif snd.IsPlaying then
			snd:Stop()
		end
	end)
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

local banner = text(hudRoot, { Size = UDim2.fromOffset(330, 40), TextWrapped = true, TextSize = 14, TextColor3 = COL.yellow, BackgroundTransparency = 0.12, BackgroundColor3 = COL.pill, Text = "", Visible = false })
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
	elseif msg:find("^🎯") or msg:find("^🎁") or msg:find("^🌅") or msg:find("^⭐") then
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

-- Effets 3D (VfxKit) : modèles d'effets publiés par le serveur dans ReplicatedStorage.VfxTemplates ; qualité Basse sur tactile (3 effets simultanés
-- au plus, 40 particules par émetteur, pas de faisceau) ; un modèle absent ou une erreur = l'effet est simplement sauté.
local function vfxEnv()
	return {
		clone = function(key)
			local folder = ReplicatedStorage:FindFirstChild("VfxTemplates")
			local t = folder and folder:FindFirstChild(key)
			return t and t:Clone() or nil
		end,
		tween = TweenService, debris = Debris, parent = workspace, delay = task.delay, color = Color3.fromRGB,
	}
end
local function padCFrame(slot)
	local pc = player:GetAttribute("PlotCF")
	if typeof(pc) == "CFrame" and type(slot) == "number" then
		local lx, lz = Config.padLocal(slot)
		return pc * CFrame.new(lx, 0.4, lz)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root.CFrame * CFrame.new(0, -2.6, -6)) or nil
end
local function playVfxAt(names, tier, cf)
	if not Config.animEnabled("vfx3d") or not cf then
		return
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local q = VfxKitMod.quality(touch, Config.VFX.quality)
	for _, name in ipairs(names) do
		if not Vfx.admit(Vfx.active, q) then
			break
		end
		local plan = Vfx.plan(name, tier, q, 1)
		if plan then
			Vfx.play(vfxEnv(), plan, cf)
		end
	end
end
local function playHatchVfx(info, tier, secret)
	if not Config.animEnabled("vfx3d") then
		return
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local q = VfxKitMod.quality(touch, Config.VFX.quality)
	local cf = padCFrame(info.slot)
	if not cf then
		return
	end
	for _, plan in ipairs(Vfx.hatchPlans(tier, secret, q, Vfx.active)) do
		Vfx.play(vfxEnv(), plan, cf)
	end
end

-- Animations d'interface (Config.Animations.uiFx / pulse) : balayage de brillance sur le bandeau de rareté, flash de vignette coloré, pulsation légère de
-- ColorCorrection et Bloom. Tout sous pcall, nettoyé par Debris ; coupé sur demande.
local function shineSweep(label, tint)
	if not Config.animEnabled("uiFx") then
		return
	end
	pcall(function()
		label.ClipsDescendants = true
		local shine = make("Frame", { Name = "Shine", Size = UDim2.new(0.18, 0, 1.6, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(Easing.shineX(0), 0.5), Rotation = 18, BackgroundColor3 = tint or Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 5 }, label)
		TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(Easing.shineX(1), 0.5), BackgroundTransparency = 1 }):Play()
		Debris:AddItem(shine, 1.1)
	end)
end
local function vignetteFlash(color, strength)
	if not Config.animEnabled("uiFx") then
		return
	end
	pcall(function()
		local g = make("ScreenGui", { Name = "UiFxVignette", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40 }, player:WaitForChild("PlayerGui"))
		local function edge(anchor, pos, size, rot)
			local f = make("Frame", { AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = color, BackgroundTransparency = 1 - 0.55 * strength, BorderSizePixel = 0, Active = false }, g)
			make("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
			TweenService:Create(f, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		end
		edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90)
		edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.22), -90)
		edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0)
		edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.16, 1), 180)
		Debris:AddItem(g, 1)
	end)
end
local function pulseLighting(strength)
	if not Config.animEnabled("pulse") then
		return
	end
	pcall(function()
		local Lighting = game:GetService("Lighting")
		local bloom, grade = Lighting:FindFirstChild("ChipeBloom"), Lighting:FindFirstChild("ChipeGrade")
		if bloom and bloom:IsA("BloomEffect") and not bloom:GetAttribute("Pulsing") then
			local base = bloom.Intensity
			bloom:SetAttribute("Pulsing", true)
			TweenService:Create(bloom, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Intensity = base + 0.5 * strength }):Play()
			task.delay(0.2, function()
				TweenService:Create(bloom, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Intensity = base }):Play()
				task.delay(1, function()
					bloom.Intensity = base
					bloom:SetAttribute("Pulsing", nil)
				end)
			end)
		end
		if grade and grade:IsA("ColorCorrectionEffect") and not grade:GetAttribute("Pulsing") then
			local base = grade.Brightness
			grade:SetAttribute("Pulsing", true)
			TweenService:Create(grade, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Brightness = base + 0.07 * strength }):Play()
			task.delay(0.2, function()
				TweenService:Create(grade, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Brightness = base }):Play()
				task.delay(1, function()
					grade.Brightness = base
					grade:SetAttribute("Pulsing", nil)
				end)
			end)
		end
	end)
end

-- Montée de niveau de la maison (D.4) : échafaudage, poussière + onde, ancienne maison qui s'enfonce, nouvelle qui monte (BaseUpgradeFx, toutes les bases
-- visibles) ; bannière, fanfare et confettis arrivent avec la notification « levelup » du serveur ; la caméra large est gérée par Cinematics.
do
	local skipEvent = Instance.new("BindableEvent")
	skipEvent.Name = "SkipBaseUpgrade"
	skipEvent.Parent = ReplicatedStorage
	local okFx, fxErr = pcall(function()
		local UpgradeMod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Upgrade"))
		local BaseUpgradeFx = require(script.Parent:WaitForChild("BaseUpgradeFx"))
		BaseUpgradeFx.start({ Config = Config, Upgrade = UpgradeMod.new(Config, Easing), vfx = playVfxAt, skipEvent = skipEvent })
	end)
	if not okFx then
		warn("[BaseUpgradeFx] " .. tostring(fxErr))
	end
end

local function revealCard(info, viaFx)
	local def = Config.PETS[info.p]
	if Config.tierAtLeast(def.tier, "announce") and tryOfferLater then
		tryOfferLater("rare")
	end
	local tier = Config.TIERS[def.tier]
	popToken += 1
	local token = popToken
	popEmoji.Text = def.emoji
	popEmoji.Rotation = -14
	TweenService:Create(popEmoji, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	popRarity.Text = Config.tierAtLeast(def.tier, "announce") and ("★ " .. string.upper(tier.name) .. " ★") or string.upper(tier.name)
	popRarity.TextColor3 = tier.color
	popRarity.TextSize = Config.tierAtLeast(def.tier, "announce") and 28 or 20
	popName.Text = Config.petName(info.p, info.s, info.m)
	popName.TextColor3 = tier.color
	popInfo.Text = tier.name .. "  ·  +" .. fmt(info.inc) .. "/s"
	pop.Visible = true
	popScale.Scale = 0.2
	-- Révélation par rareté : style calculé (Reveal.style) d'après la rareté et la probabilité réelle « 1 sur N » envoyée par le serveur.
	local oneIn = type(info.oneIn) == "number" and info.oneIn > 0 and info.oneIn or nil
	-- lot 10 : compteur de référence figé par le serveur (Odds.label, identique pour tous) ; repli sur la probabilité réelle si le serveur ne l'a pas envoyé
	popOdds.Text = (type(info.o) == "number" and L10.oddsText(info.o)) or (oneIn and Config.fmtOdds(oneIn)) or ""
	local reduced = Config.REVEAL.forceReduced or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	local st = Reveal.style(Config, def.tier, oneIn, reduced)
	if info.upgraded == true and Config.TIERS[info.egg] then
		popRarity.Text = "⬆ AMÉLIORÉ ! " .. Config.TIERS[info.egg].name .. " → " .. tier.name
		popRarity.TextSize = 22
	end
	if st.secret then
		popRarity.Text = "✦ " .. st.label .. " ✦"
		popRarity.TextColor3 = st.color
		popRarity.TextSize = 26
	end
	if Config.REVEAL.Enabled and not viaFx then -- lot 10 : remplacé par HatchFx quand l'écran d'éclosion a tourné
		RevealFx.play(gui, st, UDim2.new(0.5, 0, 0.3, -35))
	end
	local big = Config.tierAtLeast(def.tier, "announce") or info.m > 1 or info.s >= 4
	if st.flash > 0 then
		flash.BackgroundColor3 = Config.MUTS[info.m].color or st.color
		flash.BackgroundTransparency = 1 - 0.7 * st.flash
		TweenService:Create(flash, TweenInfo.new(0.35 + 0.5 * st.flash), { BackgroundTransparency = 1 }):Play()
	end
	if not viaFx then -- lot 10 : HatchFx joue hatch_r1..r10 lui-même
		playSound(Config.hatchSoundKey(def.tier, st.secret))
	end
	pcall(playHatchVfx, info, def.tier, st.secret) -- effets 3D en plus de la révélation en interface, selon la qualité
	if Config.tierAtLeast(def.tier, "shine") then -- rareté croissante : brillance sur le bandeau dès Épique, vignette colorée et pulsation dès Légendaire
		shineSweep(popRarity, tier.color:Lerp(Color3.new(1, 1, 1), 0.6))
		if Config.tierAtLeast(def.tier, "announce") or st.secret then
			vignetteFlash(st.secret and st.color or tier.color, math.min(1, 0.4 + 0.15 * def.tier))
			pulseLighting(math.min(1.5, 0.5 + 0.2 * def.tier))
		end
	end
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

-- Lot 10 : sons de l'écran d'éclosion. Avant la révélation : l'œuf tremble (egg_shake) ; à la révélation : hatch_r1..r10 de la rareté, fanfare et tirage secret
-- (N >= 1 000 000) = jackpot_rare (une seule fois par éclosion). « divine » (r10, au départ) n'ajoute rien : hatch_r10 sonne déjà à la révélation.
function L10.hatchSound(key, r, st)
	if not st.revealed then
		if key == "hatch" or key == "hatchSecret" then
			playSound("egg_shake")
		end
	elseif key == "fanfare" or key == "secret" then
		if not st.jackpot then
			st.jackpot = true
			playSound("jackpot_rare")
		end
	elseif key ~= "divine" and not st.tierSound then
		st.tierSound = true
		playSound(Config.hatchSoundR(r))
	end
end
-- Écran d'éclosion du lot 10 (HatchPlan + HatchFx) ; la carte du pet (revealCard) s'affiche à la révélation. Retourne faux si désactivé (ancienne révélation).
function L10.hatch(info, def)
	if not (Config.HATCH_FX.Enabled and Config.REVEAL.Enabled) then
		return false
	end
	local r = def.tier
	local o = (type(info.o) == "number" and info.o == info.o and info.o >= 1) and info.o or nil
	local reduced = Config.REVEAL.forceReduced or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) -- mobile : particules / 2
	local carry = player:GetAttribute("Carry")
	local first = info.first == true and not L10.seenTier[r]
	L10.seenTier[r] = true
	local okPlan, plan = pcall(L10.HatchPlan.plan, r, o, { reduced = reduced, firstTime = first, still = type(carry) == "number" and carry > 0 })
	if not okPlan or type(plan) ~= "table" then
		return false
	end
	if type(plan.beats) == "table" then -- la machine à sous (SlotFx) a déjà tourné avant : pas de seconde machine dans l'écran d'éclosion
		local kept = {}
		for _, b in ipairs(plan.beats) do
			if not (type(b) == "table" and b.kind == "slot") then
				kept[#kept + 1] = b
			end
		end
		plan.beats = kept
	end
	local tier = Config.TIERS[r]
	local st = { revealed = false }
	L10.HatchFx.play(gui, plan, {
		colors = { main = tier.color, second = tier.color2 },
		rarityName = tier.name,
		petText = def.emoji,
		fmtOdds = L10.Odds.label,
		sound = function(key)
			L10.hatchSound(key, r, st)
		end,
		onReveal = function()
			st.revealed = true
			revealCard(info, true)
		end,
	})
	return true
end
local function revealPop(info)
	local def = Config.PETS[info.p]
	if def and L10.hatch(info, def) then
		return
	end
	revealCard(info, false)
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
	text(card, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 36), Text = Config.TAGLINE, TextSize = 14, TextWrapped = true, ZIndex = 31 })
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
	return n > 0 and sum / n or 0
end

local tabsDef = {
	shop = { { "eggs", "🥚 Œufs" }, { "up", "⬆️ Améliorations" } },
	dex = { { "eggs", "🥚 Œufs" }, { "pets", "🐾 Pets" }, { "boosts", "⚡ Boosts" }, { "titles", "🏷 Titres" }, { "col", "📖 Index" }, { "ach", "🏅 Succès" } },
	quests = { { "story", "📜 Histoire" }, { "puzzle", "🔮 Énigme" }, { "daily", "🎯 Quotidiennes" } },
	bonus = { { "daily", "🎁 Bonus" }, { "cal", "📅 Calendrier" } }, -- lot 9b : calendrier des œufs sur 30 jours
}
local titles = { shop = "Boutique", dex = "Collection", quests = "Missions", bonus = "Bonus", top = "Classement", more = "Plus", raven = "🐦‍⬛ Corbeau" }
local ravenData = nil -- dernière liste de cibles reçue du serveur (lot 7)
local function agoText(at) -- « il y a 5 min » d'après l'heure du serveur
	local d = math.max(0, workspace:GetServerTimeNow() - (type(at) == "number" and at or 0))
	if d < 60 then
		return "à l'instant"
	elseif d < 3600 then
		return "il y a " .. math.floor(d / 60) .. " min"
	end
	return "il y a " .. math.floor(d / 3600) .. " h"
end
local function offerShown_(def, owned) -- une offre payante est-elle montrée ? (ID renseigné ; offres à hasard cachées tant que PolicyService n'a pas confirmé)
	return owned or Config.offerVisible(def, state and state.restricted)
end

local render
local function setTab(t)
	if t == "cal" and panel.tab ~= "cal" then
		playSound("calendar_open") -- lot 10 : son approuvé à l'ouverture du calendrier
	end
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
			if (t[1] == "puzzle" and type(state.hen) == "table" and state.hen.alert == true) or (panel.name == "bonus" and ((t[1] == "cal" and type(state.cal) == "table" and state.cal.canToday == true) or (t[1] == "daily" and state.dailyReady))) then -- pastille « 1 » : l'énigme du jour, le calendrier ou le bonus attend
				local badge = make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, -3), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = COL.red, Text = "1", TextSize = 12, Font = FONT, TextColor3 = COL.text, ZIndex = 5 }, b)
				corner(badge, 9)
			end
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
		addNote("Achète un œuf : il va directement dans ta base. Voler chez les rivaux est gratuit mais risqué.\n⬆ L'œuf fixe la rareté du pet ; " .. Config.UPGRADE.base .. "% de chances d'une amélioration d'un cran (signalée « AMÉLIORÉ ! »).\n🎪 Mythique et Cosmique : seulement au tapis du marché (prix x " .. Config.BELT.priceRatio .. ", rareté visible).")
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
		local prev, nxt = Config.shopStep(sel, -1), Config.shopStep(sel, 1) -- lot 9 : seulement les raretés publiées <= SHOP_MAX_TIER
		local leftCard, rightCard = eggCard(prev, false, 0.2), eggCard(nxt, false, 0.8)
		eggCard(sel, true, 0.5)
		for _, pair in ipairs({ { leftCard, -1 }, { rightCard, 1 } }) do
			local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8 }, pair[1])
			hit.Activated:Connect(function()
				panel.eggSel = Config.shopStep(sel, pair[2])
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
				panel.eggSel = Config.shopStep(sel, side[2])
				render()
			end)
		end
		local info = text(holder, { Position = UDim2.fromOffset(12, 218), Size = UDim2.new(1, -24, 0, 40), TextSize = 14, TextWrapped = true, TextColor3 = COL.muted, Font = Enum.Font.Gotham, Text = "Éclot en " .. Config.fmtTime(Config.HATCH[sel] * 0.9 ^ state.up.inc) .. " · ~" .. fmt(avgInc(sel) * state.mult) .. "/s en moyenne\n" .. (Config.eggUpShare(sel, Config.effectiveUp(sel, Config.UPGRADE.base, Config.dexTopTier(state.dex))) > 0 and ("Un pet " .. Config.TIERS[Config.nextLiveTier(sel)].name .. " est possible (pet de rareté supérieure)") or (Config.eggUpShare(sel, Config.UPGRADE.base) > 0 and ("Un pet " .. Config.TIERS[Config.nextLiveTier(sel)].name .. " sera possible une fois cette rareté découverte") or "Rareté fixe")) })
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
		if state.srv and state.srv.luck and state.srv.luck > 0 then
			list[#list + 1] = { "🌧️", "Pluie de chance du serveur", "+" .. Config.SERVER_LUCK.bonus .. " points · " .. Config.fmtTime(state.srv.luck) .. " restantes" .. (state.srv.luckBy and (" · offerte par " .. state.srv.luckBy) or "") }
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
		local list = Config.allTitles(state.stats)
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
		if type(state.cal) == "table" then -- lot 9b : titres et cosmétiques du calendrier de 30 jours
			for id, t in pairs(Config.CALENDAR.titles) do
				local on = state.cal.titles and state.cal.titles[id] == true
				addRow({ icon = on and "📅" or "🔒", title = on and t.name or "???", titleColor = on and COL.yellow or COL.muted, desc = t.desc })
			end
			for id, c in pairs(Config.CALENDAR.cosmetics) do
				local on = state.cal.cosm and state.cal.cosm[id] == true
				addRow({ icon = on and c.emoji or "🔒", title = on and c.name or "???", titleColor = on and COL.yellow or COL.muted, desc = "Cosmétique du calendrier" })
			end
		end
	elseif panel.name == "dex" and panel.tab == "eggs" then
		local n = 0
		do
			local lv, nxt, _, left, need = Config.baseLevel(state.baseScore, state.dex, state.baseLevelFloor)
			addNote("🏠 Base niveau " .. lv .. " · " .. Config.BASE_LEVELS[lv].name .. (nxt and (" · encore " .. fmt(left) .. " pt pour " .. nxt.name) or " · niveau maximum") .. (need and (" · il te faut un pet " .. Config.TIERS[need].name .. " découvert") or "") .. ". Chaque pet éclos fait grandir ta base, d'autant plus qu'il est rare.")
		end
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
				icon = "⭐", title = "Échanger les doublons (" .. #dupes .. ")", desc = "Garde le meilleur pet de chaque espèce, échange les autres contre des pièces.",
				btn = "Échanger " .. fmt(dupeTotal), btnColor = COL.green,
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
		local hen = type(state.hen) == "table" and state.hen or nil
		if not hen or hen.avail ~= true then
			addNote("🐔 " .. Config.HEN_LINES.locked)
		else
			local step = type(hen.step) == "number" and hen.step or 0
			local k = type(hen.count) == "number" and hen.count or 0
			if step == 4 then
				local h, m = Riddle.untilNext(os.time())
				addRow({ icon = "✅", title = "Berceuse chantée aujourd'hui !", desc = Riddle.format(Config.HEN_LINES.done, { h = h, mm = string.format("%02d", m) }) })
			else
				addNote("🐔 La Mère Poule t'attend près du Grand Œuf (à l'est de la place). Une berceuse par jour, la même pour tous.")
				local mark = { step > 1 and "✅" or (step == 1 and "🪶" or "⬜"), step > 2 and "✅" or (step == 2 and "🔮" or "⬜"), step >= 3 and "🎵" or "⬜" }
				addRow({ icon = mark[1], title = "① Les 4 plumes dorées · " .. k .. "/4", desc = step == 0 and "Parle à la Mère Poule pour commencer." or "Suis la flèche jaune : elle te mène vers la plume la plus proche." })
				addRow({ icon = mark[2], title = "② Les 4 runes autour du Grand Œuf", desc = "Chaque plume parle de la rune de sa direction. Règle-la, puis touche le Grand Œuf." })
				addRow({ icon = mark[3], title = "③ La berceuse", desc = step == 3 and ("Répète la suite de pierres (" .. (type(hen.lullabyPos) == "number" and hen.lullabyPos or 0) .. "/" .. Config.HEN.lullabyLength .. ").") or "Les pierres s'allument : touche-les dans le même ordre." })
				local found = {}
				for dir = 1, 4 do
					if type(hen.clues) == "table" and hen.clues[dir] then
						found[#found + 1] = Riddle.format(Config.HEN_LINES.feather, { dir = Riddle.DIR_OF[dir], clue = hen.clues[dir] })
					end
				end
				if #found > 0 then
					addNote(table.concat(found, "\n"))
				end
				local cur = {}
				for i, dir in ipairs(Config.RUNE_DIRECTIONS) do
					local unlocked = type(hen.feathers) == "number" and Riddle.hasFeather(hen.feathers, i)
					cur[#cur + 1] = dir .. " " .. (unlocked and Config.RUNES[state.runes[i]] or "🔒")
				end
				addRow({ icon = "🔮", title = "Tes runes : " .. table.concat(cur, " · "), desc = "🔒 = la rune attend sa plume. Le Grand Œuf dit combien de runes sont justes (pas lesquelles)." })
			end
			local fr = type(hen.fragments) == "number" and hen.fragments or 0
			addNote("🥚 Fragments du Grand Œuf : " .. fr % Config.HEN.fragmentsForEgg .. "/" .. Config.HEN.fragmentsForEgg .. " (" .. fr .. " au total). À 7 : un œuf Légendaire et le titre « Ami de la Mère Poule ». Récompense du jour : un œuf " .. Config.TIERS[Config.PUZZLE_EGG_TIER].name .. ", des pièces et 1 fragment. 💡 Un coup de bec (2 indices par jour) se demande à la Mère Poule.")
		end
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
				addRow({ icon = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or tostring(i), title = e.name, desc = "🌅 " .. e.rb .. " renaissance(s) · 🥚 " .. fmt(e.hatched) .. " éclos" })
			end
		end
	elseif panel.name == "bonus" and panel.tab == "cal" then
		-- Lot 9b : calendrier des œufs sur 30 jours. Tout est décidé par le serveur (jour UTC, éligibilité, ressources) ; ici : cartes, barre, détail, demandes { day, how }.
		local cal, CC = state.cal, Config.CALENDAR
		if type(cal) ~= "table" then
			addNote("📅 Calendrier : chargement…")
		else
			local legTier = Config.TIERS[CC.rewards[CC.legendaryDay].egg]
			if not cal.eligible then
				addNote(cal.reason == "age" and "🔒 Calendrier : il faut un compte Roblox d'au moins " .. CC.minAccountAgeDays .. " jour." or ("🔒 Calendrier : encore " .. (cal.playLeft or CC.minPlayMinutes) .. " min de jeu avant de commencer."))
			end
			-- barre « jour N sur 30 »
			local barF = make("Frame", { Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = COL.bg }, scroll)
			corner(barF, 14)
			text(barF, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextColor3 = COL.yellow, Text = "📅 Jour " .. cal.idx .. " sur " .. CC.days .. " · " .. cal.claimed .. " récompense(s) · série " .. cal.streak })
			local barBg = make("Frame", { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 9), BackgroundColor3 = COL.panel }, barF)
			corner(barBg, 5)
			local barFill = make("Frame", { Size = UDim2.fromScale(math.min(1, math.max(0.02, cal.idx / CC.days)), 1), BackgroundColor3 = COL.green }, barBg)
			corner(barFill, 5)
			for _, m in ipairs(CC.milestones) do -- jalons : repères sur la barre
				make("Frame", { Position = UDim2.fromScale((m - 0.5) / CC.days, 0), Size = UDim2.fromOffset(2, 9), BackgroundColor3 = COL.yellow, BorderSizePixel = 0, ZIndex = 2 }, barBg)
			end
			-- Légendaire du jour 3 : mis en avant (compte à rebours visible dès le jour 1)
			local legGot = string.sub(cal.states, CC.legendaryDay, CC.legendaryDay) == "c"
			local lf = addRow({
				icon = "🌟", iconColor = legTier.color, title = cal.legendary, titleColor = legTier.color,
				desc = Calendar.rewardText(Config, CC.legendaryDay), btn = legGot and "✅ Obtenu" or (string.sub(cal.states, CC.legendaryDay, CC.legendaryDay) == "t" and "Réclamer" or "Voir"),
				btnColor = legGot and COL.dis or (string.sub(cal.states, CC.legendaryDay, CC.legendaryDay) == "t" and COL.green or COL.yellow),
				onClick = function()
					panel.sel = CC.legendaryDay
					if string.sub(cal.states, CC.legendaryDay, CC.legendaryDay) == "t" then
						RAction:FireServer("calClaim", { day = CC.legendaryDay, how = "today" })
					else
						render()
					end
				end,
			})
			make("UIStroke", { Color = legTier.color, Thickness = 3 }, lf)
			-- grille des 30 cartes (5 colonnes)
			local grid = make("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, scroll)
			make("UIGridLayout", { CellSize = UDim2.new(0.2, -6, 0, 58), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
			local milestone = {}
			for _, m in ipairs(CC.milestones) do
				milestone[m] = true
			end
			for d = 1, CC.days do
				local st = string.sub(cal.states, d, d)
				local rw = CC.rewards[d]
				local icon = rw.draw and "🎲" or (rw.egg and "🥚" or (rw.cosm and CC.cosmetics[rw.cosm].emoji or (rw.title and "🏷" or ((rw.plumes and "🪶") or (rw.tokens and "⚔️") or (rw.scrolls and "📜") or "🪙"))))
				local col = st == "c" and COL.dis or (st == "t" and COL.green or (st == "m" and Color3.fromRGB(120, 60, 60) or COL.panel))
				local url = st ~= "c" and L10.iconUrl(L10.calIcon(rw)) or nil -- lot 10 : icône Decal publiée par le serveur, sinon emoji
				local b = make("TextButton", { LayoutOrder = d, BackgroundColor3 = col, Text = url and ("J" .. d) or ((st == "c" and "✅" or icon) .. "\nJ" .. d), TextYAlignment = url and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center, Font = FONT, TextSize = 14, TextColor3 = st == "t" and COL.dark or COL.text, AutoButtonColor = true }, grid)
				if url then
					make("ImageLabel", { BackgroundTransparency = 1, Image = url, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(32, 32), ScaleType = Enum.ScaleType.Fit }, b)
				end
				corner(b, 10)
				pressFx(b)
				if d == CC.legendaryDay then
					make("UIStroke", { Color = legTier.color, Thickness = 3 }, b)
				elseif milestone[d] then
					make("UIStroke", { Color = COL.yellow, Thickness = 2 }, b)
				elseif panel.sel == d then
					make("UIStroke", { Color = COL.text, Thickness = 2 }, b)
				end
				b.Activated:Connect(function()
					panel.sel = d
					render()
				end)
			end
			-- détail de la carte choisie (par défaut : le jour à réclamer, sinon le jour en cours)
			local sel = panel.sel or cal.idx
			sel = math.min(CC.days, math.max(1, sel))
			local sst = string.sub(cal.states, sel, sel)
			local random = CC.rewards[sel].draw == true
			addRow({
				icon = sst == "c" and "✅" or (sst == "m" and "⏳" or (sst == "t" and "🎁" or "🔜")), title = "Jour " .. sel .. (sst == "t" and " : aujourd'hui" or (sst == "m" and " : manqué" or (sst == "c" and " : réclamé" or ""))),
				desc = Calendar.rewardText(Config, sel), btn = sst == "t" and "Réclamer" or nil, btnColor = COL.green,
				onClick = sst == "t" and function()
					RAction:FireServer("calClaim", { day = sel, how = "today" })
				end or nil,
			})
			if sst == "m" then
				local grace, qc, catch = cal.grace or 0, cal.qc or 0, cal.catch or 0
				addRow({ icon = "🛡", title = "Jour de grâce (" .. grace .. " disponible)", desc = "Gratuit : 1 jour manqué pardonné toutes les " .. CC.graceEvery .. " jours.", btn = grace > 0 and "Rattraper" or "Aucun", btnColor = grace > 0 and COL.green or COL.dis,
					onClick = grace > 0 and function()
						RAction:FireServer("calClaim", { day = sel, how = "grace" })
					end or nil })
				addRow({ icon = "🎯", title = "3 missions (" .. math.min(qc, CC.catchupQuests) .. "/" .. CC.catchupQuests .. ")", desc = "Réclame " .. CC.catchupQuests .. " missions du jour : elles paient ce rattrapage.", btn = qc >= CC.catchupQuests and "Rattraper" or "…", btnColor = qc >= CC.catchupQuests and COL.green or COL.dis,
					onClick = qc >= CC.catchupQuests and function()
						RAction:FireServer("calClaim", { day = sel, how = "quest" })
					end or nil })
				local def = Config.PRODUCTS.CalendarCatchup
				if random and state.restricted then
					addNote("🎲 Ce jour a un tirage au sort : le rattrapage payant n'est pas proposé pour ton compte.")
				elseif catch > 0 then
					addRow({ icon = "📅", title = "Rattrapage (" .. catch .. ")", desc = "Utilise un rattrapage déjà acheté.", btn = "Utiliser", btnColor = COL.green, onClick = function()
						RAction:FireServer("calClaim", { day = sel, how = "paid" })
					end })
				elseif def and Config.purchasable(def) then
					addRow({ icon = def.emoji, title = def.name .. " : " .. def.robux .. " R$", desc = def.desc, btn = "Acheter", btnColor = COL.green, onClick = function()
						MarketplaceService:PromptProductPurchase(player, def.id)
					end })
				else
					addRow({ icon = "📅", title = "Rattrapage payant", desc = "Bientôt disponible.", btn = "Bientôt", btnColor = COL.dis })
				end
			end
			addNote("🎒 📜 " .. (cal.scrolls or 0) .. " parchemin(s) · 🪶 " .. (cal.plumes or 0) .. " plume(s) · ⚔️ " .. (cal.ftokens or 0) .. " jeton(s) de combat. Le jour est décidé par le serveur (UTC) ; les jours manqués se rattrapent jusqu'à la fin du cycle. Un jour de grâce est offert tous les " .. CC.graceEvery .. " jours.")
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
		if state.tokens and state.tokens > 0 or Config.offerVisible(Config.PRODUCTS.RemoteSteal, false) then
			addRow({ icon = "🐦‍⬛", title = "Corbeau chipeur : " .. (state.tokens or 0) .. "/" .. Config.REMOTE_STEAL.tokenMax .. " jeton(s)", desc = "Envoie un corbeau chercher un œuf en incubation chez un joueur du serveur.", btn = "Ouvrir", btnColor = COL.green, onClick = function()
				panel = { name = "raven", tab = "", confirm = false }
				RAction:FireServer("ravenList")
				render()
			end })
		end
		for _, name in ipairs(passNames) do
			local def = Config.PASSES[name]
			local owned = state.passes[name]
			if offerShown_(def, owned) then
			addRow({
				icon = def.emoji, title = def.name, desc = def.desc,
				btn = owned and "✅ Actif" or (Config.purchasable(def) and "Acheter" or "Bientôt"),
				btnColor = (owned or not Config.purchasable(def)) and COL.dis or COL.green,
				onClick = (not owned) and function()
					if Config.purchasable(def) then
						if not Config.offerVisible(def, state and state.restricted) then
							return toast("Cette offre n'est pas disponible pour ton compte.") -- offre à hasard : seulement après confirmation serveur « non restreint » (état relu au clic)
						end
						MarketplaceService:PromptGamePassPurchase(player, def.id)
					else
						toast(Config.UNAVAILABLE_MESSAGE)
					end
				end or nil,
			})
			end
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
			local packN = Config.REMOTE_STEAL.packs[name]
			local full = packN ~= nil and (state.tokens or 0) + packN > Config.REMOTE_STEAL.tokenMax -- plafond de jetons : l'achat serait refusé (rien n'est jamais perdu)
			local srvLeft = (name == "GoldenBelt" and state.srv and state.srv.golden) or (name == "ServerLuck" and state.srv and state.srv.luck) or 0
			local capLeft = name == "GoldenBelt" and Config.BELT.golden or (name == "ServerLuck" and Config.SERVER_LUCK) or nil
			local maxed = capLeft ~= nil and srvLeft + capLeft.seconds > capLeft.maxSeconds
			if Config.offerVisible(def, state.restricted) then
				addRow({
					icon = def.emoji, title = def.name, desc = def.desc .. (def.random and "\n🎲 Probabilités affichées : tapis (panneau du marché), menu Plus." or ""),
					btn = used and "✅ Acheté" or (full and "Max" or (maxed and "Au max" or "Acheter")), btnColor = (used or full or maxed) and COL.dis or COL.green,
					onClick = (used or full or maxed) and function()
						toast(full and "🐦‍⬛ Tu as déjà le maximum de jetons." or "Déjà au maximum pour l'instant.")
					end or function()
						if not Config.offerVisible(def, state and state.restricted) then
							return toast("Cette offre n'est pas disponible pour ton compte.") -- état relu au clic (offres à hasard : confirmation serveur « non restreint »)
						end
						MarketplaceService:PromptProductPurchase(player, def.id)
					end,
				})
			end
		end
	elseif panel.name == "raven" then
		local RVc = Config.REMOTE_STEAL
		addNote("🐦‍⬛ Jetons : " .. (state.tokens or 0) .. "/" .. RVc.tokenMax .. " · Vols restants aujourd'hui : " .. (state.ravenLeft or 0) .. "/" .. RVc.dailyMax .. ". Le corbeau vole " .. RVc.flightSeconds .. " s ; la victime peut le chasser (jeton rendu). Son nom t'est toujours montré, et le tien à elle.")
		if not ravenData then
			addNote("Chargement…")
		elseif ravenData.blocked then
			addNote(ravenData.blocked)
		elseif #ravenData.targets == 0 then
			addNote("Aucun joueur éligible pour l'instant (protection débutant, bouclier, œuf trop rare, trop proche de l'éclosion…).")
		else
			for _, tg in ipairs(ravenData.targets) do
				addRow({ icon = "👤", title = tg.name, desc = #tg.eggs .. " œuf(s) éligible(s)", btn = panel.sel == tg.u and "Ouvert" or "Choisir", btnColor = COL.green, onClick = function()
					panel.sel = tg.u
					render()
				end })
				if panel.sel == tg.u then
					for _, e in ipairs(tg.eggs) do
						local t = Config.TIERS[e.t]
						addRow({ icon = "🥚", iconColor = t.color, title = "Œuf " .. t.name, desc = "Éclôt dans " .. Config.fmtTime(e.left) .. " · emplacement " .. e.i, btn = "Envoyer 🐦‍⬛", btnColor = COL.yellow, onClick = function()
							RAction:FireServer("ravenGo", { u = tg.u, i = e.i })
							hidePanel()
						end })
					end
				end
			end
		end
	elseif panel.name == "more" then
		do -- lot 7 : réglage du corbeau et journal « Qui m'a volé ? »
			local blockOn = state.settings and state.settings.blockFriendRavens == true
			addRow({ icon = "🐦‍⬛", title = "Refuser les corbeaux de mes amis", desc = blockOn and "Activé : tes amis ne peuvent pas t'envoyer de corbeau." or "Désactivé : touche pour refuser les corbeaux de tes amis.", btn = blockOn and "Activé" or "Désactivé", btnColor = blockOn and COL.green or COL.dis, onClick = function()
				RAction:FireServer("setBlockRavens", not blockOn)
			end })
			addRow({ icon = "🐦‍⬛", title = "Corbeau chipeur", desc = (state.tokens or 0) .. " jeton(s) · menu des cibles", btn = "Ouvrir", btnColor = COL.green, onClick = function()
				panel = { name = "raven", tab = "", confirm = false }
				RAction:FireServer("ravenList")
				render()
			end })
			local log = state.stealLog or {}
			addNote("🕵️ Qui m'a volé ? (10 derniers vols)" .. (#log == 0 and " : personne pour l'instant." or ""))
			for _, e in ipairs(log) do
				local t = Config.TIERS[e.t]
				addRow({ icon = e.k == "r" and "🐦‍⬛" or "🥷", title = e.n, desc = "Œuf " .. (t and t.name or "?") .. " · " .. (e.k == "r" and "corbeau" or "vol à pied") .. " · " .. agoText(e.at) })
			end
		end
		local cost = Config.rebirthCost(state.rb)
		addRow({
			icon = "🌅", title = "Renaissance" .. (state.rb > 0 and (" (x" .. state.rb .. ")") or ""),
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
		do -- progression de la base : niveau, apparence, points et prochain palier
			local lv, nxt, progress, left, need = Config.baseLevel(state.baseScore, state.dex, state.baseLevelFloor)
			local cur = Config.BASE_LEVELS[lv]
			local w = Config.BASE_WEIGHTS
			local gain = Config.levelSlots(lv) .. " emplacement(s) de maison · revenus +" .. math.floor((cur.income or 0) * 100 + 0.5) .. " %"
			local weights = "Commun " .. w[1] .. ", Rare " .. w[2] .. ", Épique " .. w[3] .. ", Légendaire " .. w[4] .. ", Mythique " .. w[5] .. ", Secret " .. w[6]
			addRow({
				icon = cur.emoji, title = "Ma base : niveau " .. lv .. "/" .. #Config.BASE_LEVELS .. " · " .. cur.name,
				desc = gain .. "\n" .. (nxt and (math.floor(progress * 100) .. " % vers " .. nxt.emoji .. " " .. nxt.name .. " (encore " .. fmt(left) .. " pt)" .. (need and (" · découvre un pet " .. Config.TIERS[need].name) or "") .. " · " .. weights) or "Niveau maximum : ton château est en or !"),
			})
		end
		addRow({
			icon = volumeIdx == #Config.VOLUME_STEPS and "🔇" or "🔊", title = "Son : " .. Config.volumeLabel(volumeIdx), desc = "Volume général (effets et ambiances). Touche pour changer.",
			btn = "Changer", btnColor = COL.green,
			onClick = function()
				volumeIdx = volumeIdx % #Config.VOLUME_STEPS + 1
				render()
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
	playSound("menu")
	panel = { name = name, tab = tabsDef[name] and tabsDef[name][1][1] or "", confirm = false }
	showPanel()
	if name == "top" then
		RAction:FireServer("top")
	elseif name == "raven" then
		RAction:FireServer("ravenList")
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
local navDefs = { { "shop", "🛒", "Boutique" }, { "dex", "📖", "Pets" }, { "quests", "🎯", "Missions" }, { "bonus", "🎁", "Bonus" }, { "top", "🏆", "Top" }, { "more", "⚙️", "Plus" } }
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
	text(b, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 33), Text = n[3], TextSize = 11, TextColor3 = navText })
	local dot = make("Frame", { Size = UDim2.fromOffset(13, 13), Position = UDim2.new(1, -14, 0, 1), BackgroundColor3 = COL.red, Visible = false, ZIndex = 5 }, b)
	corner(dot, 7)
	navDots[n[1]] = dot
	b.Activated:Connect(function()
		openPanel(n[1])
	end)
end

-- Carte « objectif en cours » : chapitre de l'histoire, avancement, un appui ouvre Missions > Histoire.
local objCard = make("TextButton", { Size = UDim2.fromOffset(196, 78), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false, Visible = false }, hudRoot)
corner(objCard, 14)
local objStroke = make("UIStroke", { Color = COL.panel, Thickness = 2 }, objCard)
local objTitle = text(objCard, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 17), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, TextColor3 = COL.yellow, Text = "", TextTruncate = Enum.TextTruncate.AtEnd })
local objText = text(objCard, { Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14, TextColor3 = COL.text, TextWrapped = true, Text = "" })
local objBarBg = make("Frame", { Position = UDim2.fromOffset(8, 63), Size = UDim2.new(1, -16, 0, 8), BackgroundColor3 = COL.bg }, objCard)
corner(objBarBg, 4)
local objBar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.green }, objBarBg)
corner(objBar, 4)
objCard.Activated:Connect(function()
	openPanel("quests")
end)
local onboardSkipped = false
local skipBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), Size = UDim2.fromOffset(62, 18), BackgroundColor3 = COL.panel, Text = "Passer ›", Font = FONT, TextSize = 12, TextColor3 = COL.text, Visible = false, ZIndex = 3 }, objCard)
corner(skipBtn, 9)
local refreshObjective
skipBtn.Activated:Connect(function()
	onboardSkipped = true
	skipBtn.Visible = false
	refreshObjective()
end)
-- Étape courante des 3 premières secondes (nil : terminé, passé ou joueur déjà expérimenté).
local function onboardStep()
	if onboardSkipped or not state then
		return nil
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local plot = player:GetAttribute("PlotCF")
	local near = root ~= nil and typeof(plot) == "CFrame" and (root.Position - plot.Position).Magnitude < 30
	local remaining
	for i = 1, Config.SLOTS_MAX do
		local sl = state.slots and state.slots[i]
		if sl and sl.k == "e" then
			remaining = sl.ends - os.time()
			break
		end
	end
	return Config.onboarding(state.hatched or 0, near, remaining, { stolen = state.stolen or 0, carry = state.carry or 0, welcome = state.welcome })
end
function refreshObjective()
	local ob = onboardStep()
	if ob then
		objCard.Visible = not panelFrame.Visible
		objTitle.Text = "🎯 Étape " .. ob.index .. "/" .. ob.total
		objText.Text = ob.text
		objStroke.Color = COL.yellow
		skipBtn.Visible = true
		TweenService:Create(objBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ob.index / ob.total, 1) }):Play()
		return
	end
	skipBtn.Visible = false
	local tut = state and Config.tutorial(state.stats)
	if tut then -- tutoriel des premières minutes : prioritaire sur l'objectif de l'histoire
		objCard.Visible = not panelFrame.Visible
		objTitle.Text = "🎯 Objectif " .. tut.index .. "/" .. tut.total
		objText.Text = tut.text .. " (" .. fmt(tut.prog) .. "/" .. fmt(tut.goal) .. ")"
		objStroke.Color = COL.yellow
		TweenService:Create(objBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(tut.goal > 0 and tut.prog / tut.goal or 1, 1) }):Play()
		return
	end
	local hq = state and henUi and henUi.objective(state) -- énigme de la Mère Poule : « 🐔 La Mère Poule t'appelle » puis « 📜 Berceuse du jour »
	if hq then
		objCard.Visible = not panelFrame.Visible
		objTitle.Text = hq.title
		objText.Text = hq.text
		objStroke.Color = COL.yellow
		TweenService:Create(objBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(hq.frac, 0, 1), 1) }):Play()
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
local offerCard = text(hudRoot, { Size = UDim2.fromOffset(260, 44), TextSize = 14, TextColor3 = COL.dark, BackgroundColor3 = COL.green, BackgroundTransparency = 0, TextWrapped = true, Text = "", Visible = false })
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
local offerMode = "bonus" -- "bonus" (achat de boost) ou "revive" (relance au château)
offerBtn.Activated:Connect(function()
	hideOffer()
	if offerMode == "revive" then
		local def = Config.PRODUCTS.Revive
		if Config.purchasable(def) then
			MarketplaceService:PromptProductPurchase(player, def.id)
		end
	else
		openPanel("bonus")
	end
end)
-- Relance au château : après une défaite, carte non bloquante « Relancer maintenant » (20 s), seulement si le produit est disponible (ID renseigné).
task.spawn(function()
	while true do
		pcall(function()
			local until_ = player:GetAttribute("ReviveUntil")
			local active = type(until_) == "number" and until_ > os.time() and Config.purchasable(Config.PRODUCTS.Revive)
			if active and not (offerCard.Visible and offerMode == "revive") then
				offerMode = "revive"
				offerToken += 1
				offerCard.Text = "   " .. Config.PRODUCTS.Revive.emoji .. " Relancer maintenant ›"
				offerCard.Visible = true
			elseif not active and offerCard.Visible and offerMode == "revive" then
				hideOffer()
			end
		end)
		task.wait(0.5)
	end
end)
offerClose.Activated:Connect(hideOffer)
local function tryOffer(ev)
	if not state or panelFrame.Visible then
		return
	end
	local o = Config.boostOffer(ev, state.passes, os.clock(), offerLast, offerShown, joinedAt)
	if o and not Config.offerVisible(Config.PASSES[o.pass], state.restricted) then
		o = nil -- offre à hasard masquée pour ce joueur (PolicyService)
	end
	if not o then
		return
	end
	offerMode = "bonus"
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

-- Carte « Gains pendant ton absence » (revenu hors ligne mis de côté, à récupérer d'un clic) et indicateur de revenus en pause (joueur inactif).
local awayCard = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(300, 44), BackgroundColor3 = COL.green, TextColor3 = COL.dark, Font = FONT, TextSize = 14, TextWrapped = true, Text = "", Visible = false, ZIndex = 20 }, hudRoot)
corner(awayCard, 12)
awayCard.Activated:Connect(function()
	RAction:FireServer("claimAway")
	awayCard.Visible = false
end)
local idleLabel = text(hudRoot, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(300, 22), TextSize = 14, TextColor3 = Color3.fromRGB(255, 220, 140), Text = "💤 Inactif : revenus en pause (bouge pour reprendre)", Visible = false })
player:GetAttributeChangedSignal("Idle"):Connect(function()
	idleLabel.Visible = player:GetAttribute("Idle") == true
end)
-- Boutons de base (lot 4) : « Fermer la porte » (durée selon le niveau, recharge 60 s) et « Je suis prêt pour le PvP » (fin de la protection débutant, 🐣) ;
-- compte à rebours de fraîcheur de l'œuf porté (Légendaire+ chez Zed). Le client n'envoie que des intentions : le serveur décide.
local toolsFrame = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 70), Size = UDim2.fromOffset(160, 124), BackgroundTransparency = 1, ZIndex = 20 }, hudRoot)
local doorBtn = make("TextButton", { Size = UDim2.fromOffset(160, 36), BackgroundColor3 = COL.green, TextColor3 = COL.dark, Font = FONT, TextSize = 14, TextWrapped = true, Text = "🔒 Fermer la porte", ZIndex = 20 }, toolsFrame)
corner(doorBtn, 10)
doorBtn.Activated:Connect(function()
	RAction:FireServer("lockDoor")
end)
local newbieBtn = make("TextButton", { Position = UDim2.fromOffset(0, 42), Size = UDim2.fromOffset(160, 40), BackgroundColor3 = COL.green, TextColor3 = COL.dark, Font = FONT, TextSize = 13, TextWrapped = true, Text = "🐣 Je suis prêt pour le PvP", Visible = false, ZIndex = 20 }, toolsFrame)
corner(newbieBtn, 10)
newbieBtn.Activated:Connect(function()
	RAction:FireServer("newbieOff")
end)
local freshLabel = text(toolsFrame, { Position = UDim2.fromOffset(0, 88), Size = UDim2.fromOffset(160, 24), TextSize = 14, TextColor3 = Color3.fromRGB(160, 220, 255), Text = "", Visible = false })
task.spawn(function()
	while true do
		local nowRaw = workspace:GetServerTimeNow()
		local now = type(nowRaw) == "number" and nowRaw or os.time() -- jamais de comparaison table / nombre (Luau refuse)
		local untilT, readyT = player:GetAttribute("DoorUntil") or 0, player:GetAttribute("DoorReady") or 0
		if now < untilT then
			doorBtn.Text = "🔒 Porte fermée : " .. math.ceil(untilT - now) .. " s"
		elseif now < readyT then
			doorBtn.Text = "🔒 Recharge : " .. math.ceil(readyT - now) .. " s"
		else
			doorBtn.Text = "🔒 Fermer la porte"
		end
		newbieBtn.Visible = player:GetAttribute("Newbie") == true
		local fresh = player:GetAttribute("FreshLeft") or 0
		freshLabel.Visible = fresh > 0
		freshLabel.Text = "🧊 Apporte l'œuf : " .. fresh .. " s"
		task.wait(0.25)
	end
end)
RState.OnClientEvent:Connect(function(snap)
	state = snap
	if henUi then
		pcall(henUi.onState, snap)
	end
	if type(snap.away) == "number" and snap.away >= 1 then
		awayCard.Text = "💤 Gains pendant ton absence : " .. fmt(snap.away) .. " 🪙\nTouche pour récupérer"
		awayCard.Visible = true
	else
		awayCard.Visible = false
	end
	soundReady = true
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
-- Corbeau chipeur : carte d'alerte de la victime (compte à rebours de 8 s : « Touche l'œuf pour le chasser ») et liste des cibles du voleur.
local ravenCard = text(hudRoot, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(330, 56), TextWrapped = true, TextSize = 14, TextColor3 = COL.text, BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(60, 20, 30), Text = "", Visible = false, ZIndex = 20 })
corner(ravenCard, 15)
make("UIStroke", { Color = COL.red, Thickness = 2 }, ravenCard)
local ravenToken = 0
RRaven.OnClientEvent:Connect(function(kind, data)
	if type(data) ~= "table" then
		return
	end
	if kind == "alert" and type(data.who) == "string" and type(data.tier) == "number" and type(data.secs) == "number" then
		ravenToken += 1
		local token = ravenToken
		local tier = Config.TIERS[data.tier]
		local ends = os.clock() + data.secs
		ravenCard.Visible = true
		task.spawn(function()
			while token == ravenToken and os.clock() < ends do
				ravenCard.Text = "🐦‍⬛ Le corbeau de " .. string.sub(data.who, 1, 24) .. " vise ton œuf " .. (tier and tier.name or "") .. " !\nTouche l'œuf pour le chasser (" .. math.ceil(ends - os.clock()) .. " s)."
				task.wait(0.2)
			end
			if token == ravenToken then
				ravenCard.Visible = false
			end
		end)
	elseif kind == "end" then
		ravenToken += 1
		ravenCard.Visible = false
	elseif kind == "list" and type(data.targets) == "table" then
		ravenData = data
		if panel and panel.name == "raven" then
			renderSoon()
		end
	end
end)
RNotify.OnClientEvent:Connect(function(msg, sfx)
	if type(msg) == "string" and msg ~= "" then
		toast(msg)
	end
	if sfx == "fanfare" or sfx == "levelup" then -- victoire du château ou montée de niveau de la maison : pluie d'étincelles autour du joueur
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			pcall(playVfxAt, { "etincelles", "onde_de_choc" }, 5, root.CFrame * CFrame.new(0, -2.6, 0))
		end
	end
	if sfx then
		playSound(sfx)
	end
end)
-- Écran de tirage « machine à sous » (rareté / taille / mutation) avant la révélation. Un tirage banal ou un appareil tactile utilise les durées courtes ;
-- un deuxième tirage reçu pendant l'animation termine aussitôt le précédent (jamais deux écrans empilés). Désactivable : Config.REVEAL.slot.enabled.
local slotActive = nil
local function hatchPop(info)
	local def = Config.PETS[info.p]
	if not (Config.REVEAL.Enabled and Config.REVEAL.slot.enabled and def and Config.SIZES[info.s] and Config.MUTS[info.m]) then
		return revealPop(info)
	end
	if slotActive then
		pcall(slotActive) -- termine l'écran précédent (révèle son pet), puis enchaîne
		slotActive = nil
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local oneIn = type(info.oneIn) == "number" and info.oneIn > 0 and info.oneIn or nil
	local st = Reveal.style(Config, def.tier, oneIn, false)
	local fast = touch or Config.REVEAL.forceReduced or (not Config.tierAtLeast(def.tier, "shine") and info.s == 2 and info.m == 1)
	local plan = Reveal.slotPlan(Config, def.tier, info.s, info.m, fast)
	plan.phoenix = def.tier >= Config.REVEAL.slot.phoenixFromTier
	local done = false
	local function go()
		if done then
			return
		end
		done = true
		slotActive = nil
		revealPop(info)
	end
	slotActive = go
	local box = SlotFx.play(gui, plan, Config.REVEAL.slot.cell, { secret = st.secret, reduced = touch, onDone = go, slotPos = Reveal.slotPos, onStop = function(k)
		playSound(k == 3 and "coin" or "click")
	end })
	if not box then
		go()
	end
end
RHatch.OnClientEvent:Connect(hatchPop)
RTop.OnClientEvent:Connect(function(list)
	topData = list
	if panel and panel.name == "top" then
		renderSoon()
	end
end)

local shownCoins = coins()
local function refreshStats()
	if not Config.animEnabled("uiFx") then
		shownCoins = coins()
	end
	coinsBig.Text = fmt(shownCoins)
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
-- Compteur de pièces qui défile vers sa valeur (Easing.rollTo, approche exponentielle) au lieu de sauter.
task.spawn(function()
	while true do
		if Config.animEnabled("uiFx") then
			local target = coins()
			if shownCoins ~= target then
				shownCoins = Easing.rollTo(shownCoins, target, 1 / 30)
				coinsBig.Text = fmt(shownCoins)
			end
		end
		task.wait(1 / 30)
	end
end)

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
			navDots.quests.Visible = claimable or (type(state.hen) == "table" and state.hen.alert == true)
			navDots.bonus.Visible = state.dailyReady or (type(state.cal) == "table" and state.cal.canToday == true)
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
			pr.HoldDuration = Config.stealTime(lvl, pr:GetAttribute("Terr")) -- temps de base du territoire (le serveur mesure lui-même)
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
			local ob = onboardStep()
			local henT = nil -- énigme : la Mère Poule, puis la plume la plus proche, puis le Grand Œuf (la piste d'entraînement garde la priorité à l'étape 0)
			if not ob and state.carry == 0 and henUi and type(state.hen) == "table" and (state.hen.step ~= 0 or (player:GetAttribute("Speed") or 0) >= 8) then
				henT = henUi.guideTarget(root)
			end
			if ob and ob.target == "home" then
				target = player.RespawnLocation -- flèche vers la base : œuf offert (étape 1) ou œuf du tapis à poser (étape 3)
			elseif ob and ob.target == "belt" then
				local w = workspace:FindFirstChild("World")
				target = w and w:FindFirstChild("CentralBelt") -- tapis roulant du marché, vers (10, 0)
				for _, pr in ipairs(CollectionService:GetTagged("BeltEgg")) do
					if pr:GetAttribute("ForUser") == player.UserId and pr.Parent and pr.Parent:IsA("BasePart") then
						target = pr.Parent -- l'œuf de bienvenue à son nom, dès qu'il est posé
					end
				end
			elseif ob and ob.target == "wild" then
				for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
					local pp = pr.Parent
					if pr:GetAttribute("Owner") == nil and pp and pp:IsA("BasePart") then
						local W = Config.TERR.wild
						if math.sqrt((pp.Position.X - W.x) ^ 2 + (pp.Position.Z - W.z) ^ 2) <= W.r + 2 then
							target = pp -- un nid de l'enclos sauvage (75, -105)
							break
						end
					end
				end
			elseif ob then
				target = nil
			elseif state.carry > 0 then
				local spawnPad = player.RespawnLocation
				target = spawnPad
			elseif henT then
				target = henT
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
				target = w and w:FindFirstChild("TrainingTrack") -- piste d'entraînement (ancien tapis)
			end
		end
		setGuide(target)
		pcall(refreshObjective) -- l'étape change avec la position et le compte à rebours de l'œuf
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Tapis du marché : œuf de bienvenue d'un autre joueur masqué, annonce visuelle des œufs Légendaire et plus
-- Léger : une pulsation de Highlight par œuf rare (quelques-uns à la fois, 12 œufs au plus sur le tapis) ; tout est enfant de l'œuf, donc détruit avec lui.
local function onBeltPrompt(pr)
	local owner = pr:GetAttribute("ForUser")
	if owner ~= nil and owner ~= player.UserId then
		pr.Enabled = false -- l'œuf de bienvenue d'un autre : visible, mais pas pour moi (le serveur refuse de toute façon)
	end
end
for _, pr in ipairs(CollectionService:GetTagged("BeltEgg")) do
	onBeltPrompt(pr)
end
CollectionService:GetInstanceAddedSignal("BeltEgg"):Connect(onBeltPrompt)
local function onBeltRare(egg)
	if not egg:IsA("BasePart") then
		return
	end
	local tier = egg:GetAttribute("Tier") or 4
	local def = Config.TIERS[tier]
	local hl = Instance.new("Highlight")
	hl.Name = "BeltRareGlow"
	hl.FillColor = def and def.color or COL.yellow
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.7
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = egg
	TweenService:Create(hl, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.25 }):Play()
end
for _, egg in ipairs(CollectionService:GetTagged("BeltRare")) do
	onBeltRare(egg)
end
CollectionService:GetInstanceAddedSignal("BeltRare"):Connect(onBeltRare)

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
			local cur = m:GetPivot()
			if (cur.Position - target.Position).Magnitude > 40 then
				m:PivotTo(target) -- après une téléportation (voyage rapide, retour à la base) : le pet suit aussitôt au lieu de traverser la carte
			else
				local nxt = cur:Lerp(target, 1 - math.exp(-8 * dt))
				-- orientation vers la direction de marche du pet (sinon celle du propriétaire)
				local fx, fz = Easing.travelDir(nxt.Position.X - cur.Position.X, nxt.Position.Z - cur.Position.Z, dt, 1.5)
				if fx then
					local face = CFrame.lookAt(nxt.Position, nxt.Position + Vector3.new(fx, 0, fz))
					nxt = CFrame.new(nxt.Position) * nxt.Rotation:Lerp(face.Rotation, 0.35) -- tourne progressivement vers la marche
				end
				m:PivotTo(nxt)
			end
		end
	end
end)

---------------------------------------------------------------- Effets du monde
-- Apparition des pets, onde de choc, récolte, œufs, visages, barrières de zone, confettis : voir Animations.client.lua (activables dans Config.Animations).

-- Piste d'entraînement (ancien tapis roulant) : les rayures défilent à la vitesse de la piste (-14 studs/s).
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

---------------------------------------------------------------- Ambiances et sons de pièges (boucles)
-- Prairie dehors, château dedans ; lame et boulet : volume selon la distance. Rien avant que la carte soit prête ; une erreur coupe seulement les boucles.
do
	local Castle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Castle"))
	task.spawn(function()
		local failed = false
		while not failed do
			local ok = pcall(function()
				if not soundReady then
					return
				end
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not root then
					return
				end
				local p = root.Position
				local inCastle = Castle.roomAt(p.X, p.Z) ~= nil
				local amb = Config.ambienceKey(true, inCastle)
				setLoop(amb, 1)
				setLoop(inCastle and "ambMeadow" or "ambCastle", 0)
				local nearBlade, nearBall = 0, 0
				if inCastle then
					for _, b in ipairs(CollectionService:GetTagged("CastleBlade")) do
						nearBlade = math.max(nearBlade, Config.loopFade((b.Position - p).Magnitude, 32))
					end
					for _, b in ipairs(CollectionService:GetTagged("CastleBall")) do
						if b.Position.Y > 0 then
							nearBall = math.max(nearBall, Config.loopFade((b.Position - p).Magnitude, 40))
						end
					end
				end
				setLoop("blade", nearBlade)
				setLoop("ball", nearBall)
				-- lot 10 : tapis du marché (boucle atténuée par la distance au segment du tapis, 40 studs) et étals (ambiance de kiosque, 30 studs)
				local M2 = Config.Map2
				local nearBelt, nearKiosk = 0, 0
				if not inCastle then
					local bx = math.min(math.max(p.X, M2.belt.x0), M2.belt.x1)
					nearBelt = Config.loopFade(math.sqrt((p.X - bx) ^ 2 + (p.Z - M2.belt.z) ^ 2), 40)
					for _, st in ipairs(M2.stalls) do
						nearKiosk = math.max(nearKiosk, Config.loopFade(math.sqrt((p.X - st.x) ^ 2 + (p.Z - st.z) ^ 2), 30))
					end
				end
				setLoop("belt_loop", nearBelt)
				setLoop("kiosk_ambience", nearKiosk)
			end)
			if not ok then
				failed = true
				warn("[Sons] boucles désactivées pour cette session après une erreur")
			end
			task.wait(0.5)
		end
	end)
end

-- Énigme de la Mère Poule (lot 6) : dialogue, ❗, plumes, berceuse. Sous pcall : une erreur ici ne doit jamais bloquer le reste du client.
pcall(function()
	henUi = HenUi.start({ Config = Config, Riddle = Riddle, player = player, gui = gui, make = make, corner = corner, COL = COL, FONT = FONT, RAction = RAction, RHen = RHen, playSound = playSound })
	if state then
		henUi.onState(state)
	end
end)

-- Mini-carte (coin droit, bouton 🗺 ou touche M) : toi, ta base, les zones, les portails de voyage rapide et les gardiens proches.
pcall(function()
	local MiniMapMod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MiniMap"))
	local MiniMapUi = require(script.Parent:WaitForChild("MiniMapUi"))
	local mg = Instance.new("ScreenGui")
	mg.Name = "MiniMapGui"
	mg.ResetOnSpawn = false
	mg.DisplayOrder = 5
	mg.Parent = player:WaitForChild("PlayerGui")
	MiniMapUi.start(Config, MiniMapMod, player, mg, function()
		return state
	end, UserInputService, RunService)
end)

-- Arène des pets (PvE) : bouton ⚔️ (écran d'équipe, tour des Dresseurs, combat tour par tour résolu par le serveur).
pcall(function()
	local BattleMod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Battle"))
	local BattleUi = require(script.Parent:WaitForChild("BattleUi"))
	local bg = Instance.new("ScreenGui")
	bg.Name = "BattleGui"
	bg.ResetOnSpawn = false
	bg.DisplayOrder = 20
	bg.Parent = player:WaitForChild("PlayerGui")
	BattleUi.start(Config, BattleMod, player, bg, function()
		return state
	end, function(action, arg)
		RAction:FireServer(action, arg)
	end, Remotes:WaitForChild("Battle"), { -- lot 10 : intro de combat, effets par type, sons, icônes
		Odds = L10.Odds,
		IntroPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntroPlan")),
		BattleIntro = require(script.Parent:WaitForChild("BattleIntro")),
		TypeFx = require(script.Parent:WaitForChild("TypeFx")),
		TypeFxData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TypeFx")),
		sound = playSound,
		reduced = Config.REVEAL.forceReduced or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled),
		iconUrl = L10.iconUrl,
	})
end)

-- Boussole : flèche vers la prochaine zone (la plus avancée débloquée), avec distance et temps de marche ; masquée une fois sur place.
do
	local arrow = text(hudRoot, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(190, 24), TextSize = 14, TextColor3 = COL.yellow, TextStrokeTransparency = 0.4, Text = "", Visible = false })
	local pointer = text(arrow, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -2, 0.5, 0), Size = UDim2.fromOffset(26, 26), TextSize = 22, TextColor3 = COL.yellow, Text = "⬆", ZIndex = 3 })
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(function()
				local cam = workspace.CurrentCamera
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not (cam and root and state and state.story) then
					arrow.Visible = false
					return
				end
				local i = Config.frontierZone(state.story.ch)
				local tx, tz = Config.travelPoint(i)
				local look = cam.CFrame.LookVector
				local a, dist = Config.compass(root.Position.X, root.Position.Z, look.X, look.Z, tx, tz)
				arrow.Visible = dist > 45
				if arrow.Visible then
					pointer.Rotation = a
					arrow.Text = Config.ZONES[i].name .. " · " .. math.floor(dist) .. " m (" .. math.ceil(dist / 16) .. " s)"
				end
			end)
		end
	end)
end

pcall(function()
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReportUi")).start(Config, player, ReplicatedStorage, UserInputService)
end)

---------------------------------------------------------------- Compteur de debug (FPS, ping, Parts) : F3 l'affiche ou le masque ; coupé par défaut
do
	local dbg = Instance.new("ScreenGui")
	dbg.Name = "DebugStats"
	dbg.ResetOnSpawn = false
	dbg.DisplayOrder = 80
	dbg.Enabled = Config.HUD.debugStats == true
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundColor3 = Color3.new(0, 0, 0)
	lbl.BackgroundTransparency = 0.45
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	lbl.Position = UDim2.new(0.5, 0, 0, 4)
	lbl.Size = UDim2.fromOffset(300, 22)
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(180, 255, 190)
	lbl.Text = ""
	lbl.Active = false
	lbl.Parent = dbg
	pcall(function()
		dbg.Parent = player:WaitForChild("PlayerGui")
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.F3 then
				dbg.Enabled = not dbg.Enabled
			end
		end)
	end)
	task.spawn(function()
		local frames, t0 = 0, os.clock()
		local conn = RunService.RenderStepped:Connect(function()
			frames += 1
		end)
		while conn.Connected do
			task.wait(0.5)
			if dbg.Enabled then
				local now = os.clock()
				local fps = frames / math.max(0.001, now - t0)
				frames, t0 = 0, now
				local ping = "?"
				pcall(function()
					ping = string.format("%d", game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
				end)
				lbl.Text = string.format("FPS %d · ping %s ms", math.floor(fps + 0.5), ping)
			else
				frames, t0 = 0, os.clock()
			end
		end
	end)
end

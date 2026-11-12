--!nonstrict
-- Petite boîte à outils d'interface (style Roblox : coins arrondis, polices Fredoka/Gotham).

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIKit = {}

UIKit.Colors = {
	panel = Color3.fromRGB(34, 36, 48),
	panel2 = Color3.fromRGB(48, 51, 68),
	accent = Color3.fromRGB(255, 170, 40),
	good = Color3.fromRGB(70, 200, 100),
	bad = Color3.fromRGB(235, 80, 80),
	gold = Color3.fromRGB(255, 210, 60),
	blue = Color3.fromRGB(70, 140, 255),
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(170, 175, 190),
}

function UIKit.sfx(key: string, volume: number?, pitch: number?)
	local id = Config.Sounds[key]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

function UIKit.corner(inst: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
	return c
end

function UIKit.stroke(inst: GuiObject, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- Dégradé vertical discret (à réserver aux cadres sans texte propre : UIGradient teinte aussi le texte).
function UIKit.gradient(inst: GuiObject, bottomShade: number?)
	local g = Instance.new("UIGradient")
	local k = bottomShade or 0.78
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(k, k, k))
	g.Rotation = 90
	g.Parent = inst
	return g
end

function UIKit.frame(parent: Instance, props: any): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UIKit.Colors.panel
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

function UIKit.label(parent: Instance, props: any): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = UIKit.Colors.text
	l.TextSize = 18
	l.TextWrapped = true
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Bouton : props.Callback appelé au clic / toucher.
function UIKit.button(parent: Instance, props: any): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = UIKit.Colors.accent
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 18
	b.TextWrapped = true
	local callback = nil
	for k, v in pairs(props or {}) do
		if k == "Callback" then
			callback = v
		else
			b[k] = v
		end
	end
	UIKit.corner(b, 10)
	-- Reflet du haut du bouton (relief « plastique » façon Roblox).
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.88
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -8, 0.42, 0)
	shine.Position = UDim2.fromOffset(4, 3)
	shine.Active = false
	shine.Parent = b
	UIKit.corner(shine, 8)
	if callback then
		b.Activated:Connect(function()
			UIKit.sfx("Click", 0.3)
			callback()
		end)
	end
	b.Parent = parent
	return b
end

function UIKit.scroll(parent: Instance, props: any): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	for k, v in pairs(props or {}) do
		s[k] = v
	end
	s.Parent = parent
	return s
end

function UIKit.list(parent: Instance, padding: number?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function UIKit.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

-- Barre de progression : retourne (fond, remplissage).
function UIKit.bar(parent: Instance, props: any, color: Color3): (Frame, Frame)
	local bg = UIKit.frame(parent, props)
	bg.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
	UIKit.corner(bg, 8)
	local fill = UIKit.frame(bg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color })
	UIKit.corner(fill, 8)
	return bg, fill
end

return UIKit

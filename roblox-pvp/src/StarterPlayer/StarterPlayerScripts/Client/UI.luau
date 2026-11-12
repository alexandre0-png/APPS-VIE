--!nonstrict
-- Petite boîte à outils d'interface (style Roblox : coins arrondis, polices Gotham).
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Bg = Color3.fromRGB(22, 25, 34),
	Panel = Color3.fromRGB(34, 38, 52),
	PanelLight = Color3.fromRGB(48, 54, 72),
	Text = Color3.fromRGB(240, 242, 248),
	Dim = Color3.fromRGB(165, 172, 190),
	Accent = Color3.fromRGB(88, 140, 255),
	Good = Color3.fromRGB(80, 214, 120),
	Bad = Color3.fromRGB(235, 80, 80),
	Gold = Color3.fromRGB(255, 200, 60),
	Red = Color3.fromRGB(231, 76, 60),
	Blue = Color3.fromRGB(52, 152, 219),
}

function UI.New(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.Corner(parent, radius)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function UI.Stroke(parent, color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.Frame(parent, props)
	local f = UI.New("Frame", {
		BackgroundColor3 = UI.Colors.Panel,
		BorderSizePixel = 0,
	})
	for k, v in pairs(props or {}) do
		if k ~= "Radius" and k ~= "Stroke" then
			f[k] = v
		end
	end
	if props and props.Radius ~= false then
		UI.Corner(f, props and props.Radius or 8)
	end
	if props and props.Stroke then
		UI.Stroke(f, props.Stroke, 1.5, 0.3)
	end
	f.Parent = parent
	return f
end

function UI.Label(parent, props)
	local l = UI.New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	})
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

function UI.Button(parent, props)
	local b = UI.New("TextButton", {
		BackgroundColor3 = UI.Colors.Accent,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextSize = 16,
		Text = "",
	})
	for k, v in pairs(props or {}) do
		if k ~= "Radius" then
			b[k] = v
		end
	end
	UI.Corner(b, props and props.Radius or 8)
	b.Parent = parent
	return b
end

function UI.Tween(inst, duration, goal, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Échelle d'interface adaptée à la taille de l'écran (téléphone -> console).
function UI.AttachScale(gui, baseWidth, baseHeight)
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	UI.Scale = scale
	local function update()
		local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(baseWidth, baseHeight)
		scale.Scale = math.clamp(math.min(size.X / baseWidth, size.Y / baseHeight), 0.55, 1.35)
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

-- Convertit une position écran (pixels) en offset UI (corrige le UIScale).
function UI.ScreenToOffset(pos)
	local s = UI.Scale and UI.Scale.Scale or 1
	return UDim2.fromOffset(pos.X / s, pos.Y / s)
end

function UI.FormatNumber(n)
	n = math.floor(n)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""))
end

return UI

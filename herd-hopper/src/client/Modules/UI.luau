-- Petite boîte à outils d'interface dans le style Roblox (coins arrondis, police Fredoka).

local TweenService = game:GetService("TweenService")

local UI = {}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

UI.Colors = {
	Panel = C(30, 36, 56),
	PanelLight = C(46, 54, 84),
	Accent = C(255, 200, 70),
	Good = C(90, 200, 110),
	Bad = C(230, 80, 80),
	Warn = C(255, 150, 60),
	Info = C(110, 200, 255),
	Text = C(255, 255, 255),
	Muted = C(170, 182, 210),
	Dark = C(18, 22, 36),
}

UI.Font = Enum.Font.FredokaOne
UI.FontBody = Enum.Font.GothamMedium

function UI.make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(parent, radius)
	return UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function UI.stroke(parent, color, thickness, transparency)
	return UI.make("UIStroke", {
		Color = color or UI.Colors.Dark,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UI.padding(parent, px)
	return UI.make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	}, parent)
end

function UI.frame(parent, props)
	local p = { BackgroundColor3 = UI.Colors.Panel, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.make("Frame", p, parent)
end

-- Texte avec contour ; textSize = taille maximale (le texte se réduit pour tenir dans le cadre).
function UI.text(parent, props)
	local p = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Colors.Text,
		Font = UI.Font,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
		BorderSizePixel = 0,
	}
	local maxSize = props.maxSize or 28
	local outline = props.outline
	for k, v in pairs(props) do
		if k ~= "maxSize" and k ~= "outline" then
			p[k] = v
		end
	end
	local label = UI.make("TextLabel", p, parent)
	UI.make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, label)
	if outline ~= false then
		UI.make("UIStroke", {
			Color = UI.Colors.Dark,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, label)
	end
	return label
end

function UI.button(parent, props)
	local p = {
		BackgroundColor3 = UI.Colors.Accent,
		TextColor3 = UI.Colors.Dark,
		Font = UI.Font,
		TextScaled = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
	}
	local maxSize = props.maxSize or 24
	for k, v in pairs(props) do
		if k ~= "maxSize" then
			p[k] = v
		end
	end
	local button = UI.make("TextButton", p, parent)
	UI.corner(button, 12)
	UI.stroke(button, UI.Colors.Dark, 2)
	UI.make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, button)

	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.18) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = base }):Play()
	end)
	return button
end

function UI.tween(inst, seconds, props, style)
	local tween = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

return UI

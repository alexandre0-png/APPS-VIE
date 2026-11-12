--[[
	UI.lua : petites fabriques d'interface au style Roblox (Gotham, coins arrondis).
]]

local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UI = {}
UI.Theme = Config.Theme

function UI.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(parent, radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UI.stroke(parent, color, thickness)
	return UI.new("UIStroke", {
		Color = color or UI.Theme.PanelLight,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.padding(parent, px)
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function UI.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Theme.Panel
	props.BorderSizePixel = 0
	local f = UI.new("Frame", props)
	UI.corner(f, 12)
	return f
end

function UI.label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or UI.Theme.Text
	props.TextSize = props.TextSize or 18
	return UI.new("TextLabel", props)
end

-- Bouton avec petit effet de pression
function UI.button(props, onClick)
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Theme.PanelLight
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or UI.Theme.Text
	props.TextSize = props.TextSize or 18
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	local b = UI.new("TextButton", props)
	UI.corner(b, 10)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function UI.tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

return UI

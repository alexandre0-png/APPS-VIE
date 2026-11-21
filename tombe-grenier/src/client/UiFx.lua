--[[
  UiFx : animations d'interface dans le style glossy (client). Tout est sous pcall et désactivable :
  Config.Animations.Enabled = false coupe tout, UiBounce / UiPress / UiShine / UiFloat / UiPulse coupent chaque geste.
  Apparition avec rebond, compteur qui défile, bouton écrasé au clic, balayage de brillance, texte flottant,
  flash de vignette et pulsation légère de ColorCorrection / Bloom (pas sur téléphone).
]]
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local UiFx = {}

local function on(flag)
	local a = Config.Animations
	return a ~= nil and a.Enabled == true and a[flag] ~= false
end

local function scaleOf(obj)
	local s = obj:FindFirstChild("FxScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "FxScale"
		s.Scale = 1
		s.Parent = obj
	end
	return s
end

-- Apparition : l'objet grossit avec un rebond en fondu
function UiFx.bounceIn(obj, duration)
	if not on("UiBounce") then
		return false
	end
	return pcall(function()
		local s = scaleOf(obj)
		s.Scale = 0.6
		TweenService
			:Create(s, TweenInfo.new(duration or 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
end

-- Compteur qui défile de `from` à `to` ; format reçoit l'entier courant et rend le texte
function UiFx.countUp(label, from, to, duration, format)
	if not on("UiBounce") or from == to then
		pcall(function()
			label.Text = format and format(to) or tostring(to)
		end)
		return false
	end
	task.spawn(function()
		pcall(function()
			local steps = 12
			for i = 1, steps do
				local value = math.floor(from + (to - from) * (i / steps) + 0.5)
				label.Text = format and format(value) or tostring(value)
				task.wait((duration or 0.5) / steps)
			end
			label.Text = format and format(to) or tostring(to)
		end)
	end)
	return true
end

-- Bouton écrasé quand on appuie, qui revient avec élasticité quand on relâche
function UiFx.press(button)
	if not on("UiPress") then
		return false
	end
	return pcall(function()
		local s = scaleOf(button)
		button.MouseButton1Down:Connect(function()
			pcall(function()
				TweenService:Create(s, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
			end)
		end)
		button.MouseButton1Up:Connect(function()
			pcall(function()
				TweenService
					:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
					:Play()
			end)
		end)
	end)
end

-- Balayage de brillance sur un bouton (une fois)
function UiFx.shine(button)
	if not on("UiShine") then
		return false
	end
	return pcall(function()
		button.ClipsDescendants = true
		local band = Instance.new("Frame")
		band.Name = "Brillance"
		band.Size = UDim2.new(0.25, 0, 1.4, 0)
		band.Position = UDim2.new(-0.4, 0, -0.2, 0)
		band.Rotation = 18
		band.BackgroundColor3 = Color3.new(1, 1, 1)
		band.BackgroundTransparency = 0.8
		band.BorderSizePixel = 0
		band.ZIndex = (button.ZIndex or 1) + 1
		band.Parent = button
		local tween = TweenService:Create(
			band,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine),
			{ Position = UDim2.new(1.2, 0, -0.2, 0) }
		)
		tween:Play()
		task.delay(0.8, function()
			pcall(function()
				band:Destroy()
			end)
		end)
	end)
end

-- Texte qui monte et s'efface (« +1 », « Trouvé »)
function UiFx.floatText(gui, text, position, color)
	if not on("UiFloat") then
		return false
	end
	return pcall(function()
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = position or UDim2.fromScale(0.5, 0.6)
		label.Size = UDim2.fromOffset(240, 40)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 24
		label.TextColor3 = color or Color3.fromRGB(255, 226, 150)
		label.TextStrokeTransparency = 0.4
		label.Text = text
		label.ZIndex = 50
		label.Parent = gui
		local goal = label.Position - UDim2.fromOffset(0, 70)
		TweenService:Create(
			label,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad),
			{ Position = goal, TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
		task.delay(1.3, function()
			pcall(function()
				label:Destroy()
			end)
		end)
	end)
end

-- Flash de vignette : bords colorés qui se dissipent
function UiFx.vignette(gui, color, alpha, duration)
	if not on("UiPulse") then
		return false
	end
	return pcall(function()
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = color or Color3.fromRGB(120, 20, 30)
		frame.BackgroundTransparency = 1 - (alpha or 0.25)
		frame.BorderSizePixel = 0
		frame.ZIndex = 44
		frame.Parent = gui
		TweenService
			:Create(frame, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
			:Play()
		task.delay((duration or 0.6) + 0.1, function()
			pcall(function()
				frame:Destroy()
			end)
		end)
	end)
end

-- Pulsation légère de l'image (ColorCorrection et Bloom), seulement hors téléphone ; effets créés puis détruits
function UiFx.pulseScreen(touch)
	if touch or not on("UiPulse") then
		return false
	end
	return pcall(function()
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness = 0
		cc.Parent = Lighting
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.2
		bloom.Parent = Lighting
		TweenService:Create(
			cc,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
			{ Brightness = 0.06 }
		):Play()
		TweenService:Create(
			bloom,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
			{ Intensity = 0.5 }
		):Play()
		task.delay(0.7, function()
			pcall(function()
				cc:Destroy()
				bloom:Destroy()
			end)
		end)
	end)
end

return UiFx

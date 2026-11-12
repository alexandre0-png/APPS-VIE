-- Ui.luau : thème et petits composants d'interface (tout est construit par code, sans asset externe).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local DinoFactory = require(Shared.DinoFactory)

local Ui = {}

Ui.font = Enum.Font.FredokaOne
Ui.colors = {
	bg = Color3.fromRGB(34, 40, 56),
	panel = Color3.fromRGB(48, 56, 78),
	row = Color3.fromRGB(62, 72, 98),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(175, 185, 210),
	gold = Color3.fromRGB(255, 214, 80),
	green = Color3.fromRGB(80, 200, 110),
	red = Color3.fromRGB(235, 90, 85),
	blue = Color3.fromRGB(80, 160, 255),
	purple = Color3.fromRGB(170, 100, 255),
	orange = Color3.fromRGB(255, 160, 60),
	disabled = Color3.fromRGB(95, 100, 115),
}

Ui.settings = { sfx = true }

local player = Players.LocalPlayer

----------------------------------------------------------------------
-- Sons
----------------------------------------------------------------------
local soundCache = {}
function Ui.playSound(name, volume, pitch)
	if not Ui.settings.sfx then
		return
	end
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local snd = soundCache[name]
	if not snd then
		snd = Instance.new("Sound")
		snd.Name = "Sfx_" .. name
		snd.SoundId = id
		snd.Volume = volume or 0.5
		snd.Parent = SoundService
		soundCache[name] = snd
	end
	snd.TimePosition = 0
	snd.PlaybackSpeed = pitch or 1
	snd:Play()
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------
function Ui.new(class, props, children)
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

function Ui.corner(parent, radius)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Ui.stroke(parent, color, thickness)
	return Ui.new("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Ui.label(parent, props)
	local l = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.font,
		TextColor3 = props.color or Ui.colors.text,
		TextSize = props.size or 18,
		Text = props.text or "",
		TextXAlignment = props.align or Enum.TextXAlignment.Center,
		TextYAlignment = props.valign or Enum.TextYAlignment.Center,
		TextWrapped = props.wrap or false,
		TextScaled = props.scaled or false,
		RichText = props.rich or false,
		Size = props.sizeUdim or UDim2.fromScale(1, 1),
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		ZIndex = props.z or 1,
		Name = props.name or "Label",
		Parent = parent,
	})
	if props.stroke then
		l.TextStrokeTransparency = 0.3
		l.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
	end
	return l
end

-- Bouton avec effet d'appui. props : text, size(UDim2), pos, color, onClick, textSize
function Ui.button(parent, props)
	local b = Ui.new("TextButton", {
		Name = props.name or "Button",
		Text = props.text or "",
		Font = Ui.font,
		TextSize = props.textSize or 20,
		TextColor3 = Ui.colors.text,
		BackgroundColor3 = props.color or Ui.colors.green,
		AutoButtonColor = false,
		Size = props.size or UDim2.fromOffset(120, 44),
		Position = props.pos or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(0, 0),
		ZIndex = props.z or 1,
		RichText = props.rich or false,
		Parent = parent,
	})
	Ui.corner(b, props.radius or 12)
	Ui.stroke(b, Color3.fromRGB(15, 18, 30), 2)
	-- léger dégradé vertical : relief "bouton Roblox"
	Ui.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
		Rotation = 90,
		Parent = b,
	})
	local base = b.BackgroundColor3
	b:SetAttribute("BaseColor", base)
	local scale = Ui.new("UIScale", { Scale = 1, Parent = b })
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.93 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	if props.onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Disabled") then
				Ui.playSound("error", 0.25)
				return
			end
			Ui.playSound("click", 0.35)
			props.onClick()
		end)
	end
	return b
end

function Ui.setEnabled(button, enabled, color)
	button:SetAttribute("Disabled", not enabled)
	button.BackgroundColor3 = enabled and (color or button:GetAttribute("BaseColor")) or Ui.colors.disabled
end

----------------------------------------------------------------------
-- Racine
----------------------------------------------------------------------
function Ui.createRoot()
	local gui = Ui.new("ScreenGui", {
		Name = "DinoUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = Ui.new("UIScale", { Parent = gui })
	local function update()
		local cam = Workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.Y / 620, size.X / 900), 0.62, 1.35)
	end
	update()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	Ui.root = gui
	return gui
end

----------------------------------------------------------------------
-- Panneaux modaux (un seul ouvert à la fois)
----------------------------------------------------------------------
Ui.panels = {}
Ui.openName = nil

function Ui.closePanels()
	for name, p in pairs(Ui.panels) do
		p.frame.Visible = false
		p.dim.Visible = false
	end
	Ui.openName = nil
end

function Ui.openPanel(name)
	local p = Ui.panels[name]
	if not p then
		return
	end
	Ui.closePanels()
	p.dim.Visible = true
	p.frame.Visible = true
	Ui.openName = name
	if p.onOpen then
		p.onOpen()
	end
	local sc = p.frame:FindFirstChild("PopScale")
	if sc then
		sc.Scale = 0.85
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	Ui.playSound("click", 0.3)
end

function Ui.togglePanel(name)
	if Ui.openName == name then
		Ui.closePanels()
	else
		Ui.openPanel(name)
	end
end

-- Crée un panneau : retourne { frame, body (ScrollingFrame) }
function Ui.createPanel(name, title, size, opts)
	opts = opts or {}
	local dim = Ui.new("TextButton", {
		Name = name .. "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Parent = Ui.root,
	})
	dim.Activated:Connect(Ui.closePanels)

	local frame = Ui.new("Frame", {
		Name = name,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Ui.colors.bg,
		Visible = false,
		ZIndex = 21,
		Parent = Ui.root,
	})
	Ui.corner(frame, 18)
	Ui.stroke(frame, Color3.fromRGB(12, 14, 24), 3)
	Ui.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 210, 225)), Rotation = 90, Parent = frame })
	Ui.new("UIScale", { Name = "PopScale", Parent = frame })

	local header = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = opts.color or Ui.colors.blue,
		ZIndex = 22,
		Parent = frame,
	})
	Ui.corner(header, 18)
	-- masque l'arrondi du bas de l'en-tête
	Ui.new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = header.BackgroundColor3, BorderSizePixel = 0, ZIndex = 22, Parent = header })
	Ui.label(header, { text = title, size = 28, stroke = true, z = 23, name = "Title" })
	local close = Ui.button(header, {
		text = "✕", size = UDim2.fromOffset(40, 40), pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5),
		color = Ui.colors.red, z = 24, textSize = 22, onClick = Ui.closePanels,
	})

	local body = Ui.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.new(0, 10, 0, 62),
		Size = UDim2.new(1, -20, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
		Parent = frame,
	})
	local panel = { frame = frame, dim = dim, body = body, header = header, close = close }
	Ui.panels[name] = panel
	return panel
end

----------------------------------------------------------------------
-- ViewportFrame de dinosaure
----------------------------------------------------------------------
-- options : silhouette (bool), rotate (bool, retourne un connecteur à déconnecter)
function Ui.dinoViewport(parent, key, options)
	options = options or {}
	local vp = Ui.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = options.size or UDim2.fromScale(1, 1),
		Position = options.pos or UDim2.new(),
		Ambient = options.silhouette and Color3.new(0, 0, 0) or Color3.fromRGB(190, 190, 200),
		LightColor = options.silhouette and Color3.new(0, 0, 0) or Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, 1),
		ZIndex = options.z or 1,
		Parent = parent,
	})
	local model = DinoFactory.build(key, { sparkle = true })
	if not model then
		return vp
	end
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local center = cf.Position
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 0.9
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0.7, 0.45, -1.0).Unit * dist, center)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp:SetAttribute("Center", center)
	return vp, model
end

return Ui

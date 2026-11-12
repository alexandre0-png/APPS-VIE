--!nonstrict
-- Cibles d'entraînement du hub : se réparent seules après destruction.
local CollectionService = game:GetService("CollectionService")

local DummyService = {}

-- opts : Label, Health, TorsoColor. Renvoie (modèle, humanoïde) ; cf = niveau du sol.
local function build(cf, opts)
	opts = opts or {}
	local model = Instance.new("Model")
	model.Name = "Cible"
	model:SetAttribute("Dummy", true)

	local function part(name, size, offset, color, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Anchored = true
		p.CanCollide = collide
		p.CFrame = cf * CFrame.new(offset)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), Color3.new(1, 1, 1), false)
	root.Transparency = 1
	part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), opts.TorsoColor or Color3.fromRGB(214, 64, 64), true)
	part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), Color3.fromRGB(240, 190, 120), true)
	part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), Color3.fromRGB(240, 240, 240), true)
	part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), Color3.fromRGB(240, 240, 240), true)
	part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), Color3.fromRGB(240, 240, 240), true)
	part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), Color3.fromRGB(240, 240, 240), true)
	-- poteau de soutien visuel
	part("Post", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.3, 0), Color3.fromRGB(100, 70, 40), false).Transparency = 1

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = opts.Health or 150
	humanoid.Health = opts.Health or 150
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root

	-- plaque + barre de vie
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 36)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.Adornee = model.Head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = opts.Label or "Cible d'entraînement"
	label.Parent = gui
	local bg = Instance.new("Frame")
	bg.Position = UDim2.new(0.5, -45, 0, 22)
	bg.Size = UDim2.fromOffset(90, 7)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = model.Head
	humanoid.HealthChanged:Connect(function(h)
		fill.Size = UDim2.fromScale(math.clamp(h / humanoid.MaxHealth, 0, 1), 1)
	end)

	return model, humanoid
end

DummyService.Build = build

local function spawnDummy(cf)
	local model, humanoid = build(cf)
	CollectionService:AddTag(model, "Dummy")
	model.Parent = workspace
	humanoid.Died:Connect(function()
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 0.8
				p.CanCollide = false
			end
		end
		task.wait(3)
		model:Destroy()
		spawnDummy(cf)
	end)
end

function DummyService.Init(cframes)
	for _, cf in ipairs(cframes) do
		spawnDummy(cf)
	end
end

return DummyService

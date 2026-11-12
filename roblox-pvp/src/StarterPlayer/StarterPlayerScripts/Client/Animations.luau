--!nonstrict
-- Animations de personnage (procédurales, sans ressource ni sang) :
-- inclinaison à la course, poussière de saut, glissade, esquive à image rémanente, garde,
-- matérialisation à la réapparition. Tout passe par AnimGuard (Config.Animations + pcall).
-- Glissade et esquive sont purement visuelles/de confort : le serveur ne leur donne aucun avantage de combat.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent
local Config = require(Shared.Config)
local Lore = require(Shared.Lore)
local AnimLogic = require(Shared.AnimLogic)
local AnimGuard = require(Client.AnimGuard)

local Animations = {}

local player = Players.LocalPlayer
local state = { Sliding = false, Dodging = false, Guarding = false, LastSlide = 0, LastDodge = 0 }
local joints = setmetatable({}, { __mode = "k" }) -- [Motor6D] = C0 d'origine

local function heroColor(p)
	local hero = Lore.Hero(tostring(p:GetAttribute("Hero")))
	return Color3.fromHex(hero and hero.Color or "FFFFFF")
end

local function rootJoint(character)
	local lower = character:FindFirstChild("LowerTorso")
	return lower and lower:FindFirstChild("Root") -- R15 uniquement (axes du joint R6 différents)
end

local function motorBase(motor)
	if not joints[motor] then
		joints[motor] = motor.C0
	end
	return joints[motor]
end

local function dust(position, color)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6))
	e.Size = NumberSequence.new(0.8, 0)
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 20)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(8)
	Debris:AddItem(anchor, 1)
end

-- ===== Course : inclinaison de la taille =====
local function updateLean(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local motor = character and rootJoint(character)
	if not humanoid or not motor then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local pose = AnimLogic.MoveState(speed, grounded, state.Sliding, state.Dodging, state.Guarding)
	local target = 0
	if pose == "Run" then
		target = AnimLogic.LeanAngle(speed, Config.Player.WalkSpeed, 10)
	elseif pose == "Slide" then
		target = math.rad(55)
	elseif pose == "Dodge" then
		target = math.rad(30)
	end
	local base = motorBase(motor)
	local angle = (motor:GetAttribute("LeanAngle") or 0)
	angle += (target - angle) * math.min(1, dt * 10)
	motor:SetAttribute("LeanAngle", angle)
	motor.C0 = base * CFrame.Angles(angle, 0, 0)
end

-- ===== Saut : poussière au décollage et à la réception =====
local function hookJump(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Landed then
			AnimGuard.Run("Jump", dust, root.Position - Vector3.new(0, 2.8, 0), heroColor(player))
		end
	end)
end

-- ===== Glissade =====
local function slide()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if state.Sliding or not AnimLogic.CanTrigger(os.clock(), state.LastSlide, 1.5, grounded, speed, 8) then
		return
	end
	state.Sliding, state.LastSlide = true, os.clock()
	local dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	root.AssemblyLinearVelocity = dir.Unit * 38 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	dust(root.Position - Vector3.new(0, 2.8, 0), heroColor(player))
	task.delay(0.55, function()
		state.Sliding = false
	end)
end

-- ===== Esquive : image rémanente + impulsion =====
local GHOST_PARTS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function afterimage(character, color)
	for _, name in ipairs(GHOST_PARTS) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local ghost = Instance.new("Part")
			ghost.Size = part.Size
			ghost.CFrame = part.CFrame
			ghost.Anchored, ghost.CanCollide, ghost.CanQuery, ghost.CanTouch, ghost.CastShadow = true, false, false, false, false
			ghost.Material = Enum.Material.Neon
			ghost.Color = color
			ghost.Transparency = 0.45
			ghost.Parent = workspace
			TweenService:Create(ghost, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Transparency = 1, Size = part.Size * 0.6 }):Play()
			Debris:AddItem(ghost, 0.5)
		end
	end
end

local function dodge()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if state.Dodging or not AnimLogic.CanTrigger(os.clock(), state.LastDodge, 1.2, grounded, 99, 0) then
		return
	end
	state.Dodging, state.LastDodge = true, os.clock()
	local move = humanoid.MoveDirection
	local dir = if move.Magnitude > 0.1 then move.Unit else -root.CFrame.LookVector -- sans direction : pas en arrière
	afterimage(character, heroColor(player))
	root.AssemblyLinearVelocity = dir * 48 + Vector3.new(0, 6, 0)
	task.delay(0.35, function()
		state.Dodging = false
	end)
end

-- ===== Garde : posture bras croisés + lueur =====
local function setGuard(on)
	local character = player.Character
	if not character then
		return
	end
	state.Guarding = on
	local old = character:FindFirstChild("GuardGlow")
	if old then
		old:Destroy()
	end
	for _, name in ipairs({ "RightUpperArm", "LeftUpperArm" }) do
		local arm = character:FindFirstChild(name)
		local motor = arm and (arm:FindFirstChild("RightShoulder") or arm:FindFirstChild("LeftShoulder"))
		if motor then
			local base = motorBase(motor)
			local sign = name == "RightUpperArm" and -1 or 1
			TweenService:Create(motor, TweenInfo.new(0.12), { C0 = on and base * CFrame.Angles(-1.3, 0, sign * 0.7) or base }):Play()
		end
	end
	if on then
		local glow = Instance.new("Highlight")
		glow.Name = "GuardGlow"
		glow.FillColor = heroColor(player)
		glow.FillTransparency = 0.8
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.OutlineTransparency = 0.3
		glow.Parent = character
	end
end

-- ===== Réapparition : matérialisation =====
local function materialize(character, who)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.15)
	local color = heroColor(who)
	local originals = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			originals[d] = d.Transparency
			d.Transparency = 1
		end
	end
	for part, t in pairs(originals) do
		TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Transparency = t }):Play()
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 9, 9), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.8)
end

local function onAnyCharacter(who, character)
	AnimGuard.Run("Respawn", materialize, character, who)
end

local function watchPlayer(who)
	who.CharacterAdded:Connect(function(character)
		onAnyCharacter(who, character)
	end)
	if who.Character then
		task.spawn(onAnyCharacter, who, who.Character)
	end
end

function Animations.Init()
	RunService.RenderStepped:Connect(function(dt)
		AnimGuard.Run("Run", updateLean, dt)
	end)
	player.CharacterAdded:Connect(function(character)
		state.Sliding, state.Dodging = false, false
		if state.Guarding then
			state.Guarding = false
		end
		task.spawn(hookJump, character)
	end)
	if player.Character then
		task.spawn(hookJump, player.Character)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.C or k == Enum.KeyCode.ButtonX then
			AnimGuard.Run("Slide", slide)
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonB then
			AnimGuard.Run("Dodge", dodge)
		elseif k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonY then
			AnimGuard.Run("Guard", setGuard, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local k = input.KeyCode
		if (k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonY) and state.Guarding then
			AnimGuard.Run("Guard", setGuard, false)
		end
	end)
end

return Animations

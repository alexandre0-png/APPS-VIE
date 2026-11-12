--!nonstrict
-- Entrées de combat côté client : clic / toucher maintenu -> direction de visée -> serveur.
-- Le client ne décide ni des dégâts, ni des cibles, ni de la cadence (revalidée serveur).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Weapons)
local Remotes = require(Shared.Remotes)
local AnimGuard = require(script.Parent.AnimGuard)
local TweenService = game:GetService("TweenService")

local WeaponClient = {}

local player = Players.LocalPlayer
local currentTool = nil
local currentDef = nil
local lastFire = {}
local holding = false
local touchHolding = false
local loopRunning = false
local bound = setmetatable({}, { __mode = "k" })

function WeaponClient.GetEquipped()
	return currentDef, currentTool
end

-- Fraction de recharge restante (1 = tout juste tiré, 0 = prêt).
function WeaponClient.CooldownLeft(weaponId)
	local def = Weapons.Get(weaponId)
	if not def or not lastFire[weaponId] then
		return 0
	end
	return math.clamp(1 - (os.clock() - lastFire[weaponId]) / def.Cooldown, 0, 1)
end

-- Position écran de la visée (souris, ou centre de l'écran en tactile / verrouillé).
function WeaponClient.AimScreenPos()
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	if locked or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) or UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		return Vector2.new(size.X / 2, size.Y / 2)
	end
	return UserInputService:GetMouseLocation()
end

-- Direction (unitaire) de la tête du joueur vers le point visé.
local function computeAim()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not head or not camera then
		return nil
	end
	local pos = WeaponClient.AimScreenPos()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = result and result.Position or (ray.Origin + ray.Direction * 600)
	local dir = target - head.Position
	if dir.Magnitude < 0.5 then
		return ray.Direction
	end
	return dir.Unit
end

-- Rechargement visuel : l'arme bascule puis revient pendant le délai de recharge.
function WeaponClient.ReloadAnim(tool, cooldown)
	local base = tool.Grip
	local half = math.max(0.1, cooldown * 0.45)
	local down = TweenService:Create(tool, TweenInfo.new(half, Enum.EasingStyle.Quad), { Grip = base * CFrame.Angles(0.7, 0, 0) })
	down:Play()
	down.Completed:Once(function()
		if tool.Parent then
			TweenService:Create(tool, TweenInfo.new(half, Enum.EasingStyle.Back), { Grip = base }):Play()
		end
	end)
end

local function tryAttack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not currentTool or not currentDef or not humanoid or humanoid.Health <= 0 or currentTool.Parent ~= character then
		return
	end
	local last = lastFire[currentDef.Id] or 0
	if os.clock() - last < currentDef.Cooldown then
		return
	end
	local aim = computeAim()
	if not aim then
		return
	end
	lastFire[currentDef.Id] = os.clock()
	Remotes.Attack:FireServer(aim)
	if currentDef.Class == "Ranged" and currentDef.Cooldown >= 0.8 then
		AnimGuard.Run("Reload", WeaponClient.ReloadAnim, currentTool, currentDef.Cooldown)
	end
end

local function ensureLoop()
	if loopRunning then
		return
	end
	loopRunning = true
	task.spawn(function()
		while (holding or touchHolding) and currentTool do
			tryAttack()
			RunService.Heartbeat:Wait()
		end
		loopRunning = false
	end)
end

function WeaponClient.SetTouchHold(state)
	touchHolding = state
	if state then
		ensureLoop()
	end
end

local function bindTool(tool)
	local def = Weapons.Get(tool:GetAttribute("WeaponId"))
	if not def then
		return
	end
	if bound[tool] then
		if tool.Parent == player.Character then
			currentTool, currentDef = tool, def
		end
		return
	end
	bound[tool] = true
	tool.Equipped:Connect(function()
		currentTool, currentDef = tool, def
	end)
	tool.Unequipped:Connect(function()
		if currentTool == tool then
			currentTool, currentDef = nil, nil
			holding = false
		end
	end)
	tool.Activated:Connect(function()
		holding = true
		ensureLoop()
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	if tool.Parent == player.Character then
		currentTool, currentDef = tool, def
	end
end

local function onCharacter(character)
	currentTool, currentDef, holding = nil, nil, false
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			bindTool(child)
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			bindTool(child)
		end
	end)
	local backpack = player:WaitForChild("Backpack")
	local function watch(container)
		container.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("WeaponId") then
				bindTool(child)
			end
		end)
	end
	watch(backpack)
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			bindTool(child)
		end
	end
end

function WeaponClient.Init()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return WeaponClient

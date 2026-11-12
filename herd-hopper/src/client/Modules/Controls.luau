-- Contrôles à une seule action, contextuelle (clavier, souris, tactile, manette) :
--   * en selle   : SAUTER (quitte la monture avec un bond vers l'avant)
--   * en l'air   : LASSO (maintenir = lasso automatique dès qu'une bête est à portée)
-- Direction : A/D, flèches, joystick (pilote la monture, ou le vol en l'air).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ClientState = require(script.Parent.ClientState)
local CreatureFx = require(script.Parent.CreatureFx)
local Sfx = require(script.Parent.Sfx)

local Controls = {}

local player = Players.LocalPlayer

local pressed = false
local pressedSource = nil
local armedUntil = 0
local lastHookAt = 0
local lastSteer = 0
local lastSteerAt = 0
local controlsObject = nil

local air = { active = false, vx = 0, vz = 0 }

local function getHrp()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- Direction latérale demandée, exprimée sur l'axe X du monde (caméra tournée vers +Z : droite écran = -X).
local function getSteer()
	if controlsObject then
		local ok, v = pcall(function()
			return controlsObject:GetMoveVector()
		end)
		if ok and v then
			return -v.X
		end
	end
	local hum = getHum()
	return hum and hum.MoveDirection.X or 0
end

function Controls.press(source)
	if pressed then
		return
	end
	pressed = true
	pressedSource = source
	local status = ClientState.Status
	if status == "Riding" then
		Remotes.Launch:FireServer()
		Sfx.play("launch")
	elseif status == "Air" or status == "Down" then
		armedUntil = os.clock() + 0.45
	end
end

function Controls.release(source)
	if pressed and pressedSource == source then
		pressed = false
		pressedSource = nil
	end
end

-- Branche un bouton d'interface (tactile / souris) sur l'action.
function Controls.bindButton(button)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Controls.press("button")
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Controls.release("button")
		end
	end)
end

function Controls.onLaunched(velocity)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	-- attendre que la soudure de selle ait disparu (réplication)
	local t0 = os.clock()
	while hrp:FindFirstChild("RideWeld") and os.clock() - t0 < 0.5 do
		RunService.Heartbeat:Wait()
	end
	hum.Sit = false
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = velocity
	air.active = true
	air.vx = velocity.X
	air.vz = velocity.Z
end

local function setupCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	air.active = false

	-- masquer le bouton de saut tactile par défaut (notre bouton d'action le remplace)
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui")
		local touchGui = gui:WaitForChild("TouchGui", 5)
		if touchGui then
			local frame = touchGui:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if jump then
				jump.Visible = false
			end
		end
	end)
end

function Controls.init()
	-- Module de contrôles Roblox : permet de lire le stick / les touches indépendamment de la caméra.
	task.spawn(function()
		local ok, result = pcall(function()
			local scripts = player:WaitForChild("PlayerScripts")
			local module = scripts:WaitForChild("PlayerModule", 10)
			return require(module):GetControls()
		end)
		if ok then
			controlsObject = result
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			Controls.press("key")
		elseif t == Enum.UserInputType.MouseButton1 then
			Controls.press("mouse")
		elseif t == Enum.UserInputType.Touch then
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 1000)
			if input.Position.X > viewport.X * 0.5 then
				Controls.press("touch")
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			Controls.release("key")
		elseif t == Enum.UserInputType.MouseButton1 then
			Controls.release("mouse")
		elseif t == Enum.UserInputType.Touch then
			Controls.release("touch")
		end
	end)

	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)

	ClientState.connect("Status", function(status)
		if status ~= "Air" then
			air.active = false
		end
		if status == "Down" then
			Sfx.play("land")
		end
		if status == "Riding" or status == "Lobby" then
			CreatureFx.setTarget(nil)
			-- un nouvel appui est nécessaire pour bondir (évite un état "appuyé" resté coincé)
			pressed = false
			pressedSource = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local status = ClientState.Status
		local now = os.clock()
		local hrp = getHrp()
		if not hrp then
			return
		end

		if status == "Riding" then
			local x = getSteer()
			if math.abs(x) < 0.15 then
				x = 0
			end
			x = math.clamp(x, -1, 1)
			if math.abs(x - lastSteer) > 0.05 or (now - lastSteerAt > 0.5 and x ~= 0) then
				lastSteer = x
				lastSteerAt = now
				Remotes.Steer:FireServer(x)
			end
		elseif lastSteer ~= 0 then
			lastSteer = 0
		end

		if status == "Air" and air.active then
			local v = hrp.AssemblyLinearVelocity
			local target = getSteer() * Config.Ride.AirLateral
			air.vx = air.vx + (target - air.vx) * math.min(1, dt * 4)
			hrp.AssemblyLinearVelocity = Vector3.new(air.vx, v.Y, air.vz)
		end

		if status == "Air" or status == "Down" then
			local range = player:GetAttribute("HookRange") or Config.Ride.HookBaseRange
			local model = CreatureFx.bestTarget(hrp.Position, range, status == "Air" and 5 or -25)
			CreatureFx.setTarget(model)
			if model and (pressed or now < armedUntil) and now - lastHookAt > Config.Ride.HookCooldown then
				lastHookAt = now
				armedUntil = 0
				Remotes.Hook:FireServer(model:GetAttribute("Id"))
				Sfx.play("hook")
			end
		elseif status == "Hooking" then
			CreatureFx.setTarget(nil)
		end
	end)
end

return Controls

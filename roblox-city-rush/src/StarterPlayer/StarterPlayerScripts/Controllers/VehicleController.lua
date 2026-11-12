--[[
	VehicleController : pilotage arcade du véhicule par le client du conducteur.
	Lit les entrées du VehicleSeat (clavier, manette, joystick tactile gérés par Roblox),
	écrit la vitesse cible dans les contraintes créées par le serveur.
	Nitro : Shift / bouton X manette / bouton tactile. R : remettre le véhicule sur ses roues.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local State = require(script.Parent.State)

local VehicleController = {}
VehicleController.Updated = Util.newSignal() -- (kmh, boostFraction, driving)
VehicleController.Driving = false

local player = Players.LocalPlayer
local boostHeld = false
local conn
local flipTimer = 0

function VehicleController.setBoost(on)
	boostHeld = on
end

local function uprightReset(chassis)
	local pos = chassis.Position
	local look = chassis.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	chassis.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, yaw, 0)
end

local function stop(camera)
	if conn then
		conn:Disconnect()
		conn = nil
	end
	VehicleController.Driving = false
	boostHeld = false
	VehicleController.Updated:Fire(0, 0, false)
	if camera then
		camera.FieldOfView = 70
	end
end

local function startDriving(hum, seat)
	local model = seat.Parent
	local chassis = model.PrimaryPart
	local lv = chassis and chassis:FindFirstChild("DriveVelocity")
	local av = chassis and chassis:FindFirstChild("TurnVelocity")
	if not lv or not av then
		return
	end
	local camera = workspace.CurrentCamera
	local maxSpeed = model:GetAttribute("MaxSpeed") or 80
	local accel = model:GetAttribute("Accel") or 40
	local turn = model:GetAttribute("Turn") or 2
	local boost = Config.BoostMax
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 80, 30))
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.LightEmission = 1
	emitter.Parent = chassis

	VehicleController.Driving = true
	if conn then
		conn:Disconnect()
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.05)
		if not seat.Parent or seat.Occupant ~= hum or not chassis.Parent then
			emitter:Destroy()
			stop(camera)
			return
		end
		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat
		local look = chassis.CFrame.LookVector
		local vel = chassis.AssemblyLinearVelocity
		local fwd = vel:Dot(look)
		local data = State.data
		local hasBoostPass = data and data.Boost

		local boosting = boostHeld and boost > 0 and throttle > 0
		if boosting then
			boost = math.max(0, boost - Config.BoostDrainPerSec * (hasBoostPass and 0.5 or 1) * dt)
		else
			boost = math.min(Config.BoostMax, boost + Config.BoostRegenPerSec * (hasBoostPass and 2 or 1) * dt)
		end
		emitter.Rate = boosting and 60 or 0

		local mul = boosting and 1.35 or 1
		local target
		if throttle >= 0 then
			target = throttle * maxSpeed * mul
		else
			target = throttle * maxSpeed * 0.35
		end
		local rate
		if throttle == 0 then
			rate = 24
		elseif throttle * fwd < 0 then
			rate = 120 -- freinage
		else
			rate = accel * (boosting and 1.7 or 1)
		end
		local cmd = fwd + math.clamp(target - fwd, -rate * dt, rate * dt)
		lv.PlaneVelocity = Vector2.new(0, -cmd)

		local speedFactor = math.clamp(math.abs(fwd) / 18, 0, 1) * (1 - 0.4 * math.min(1, math.abs(fwd) / (maxSpeed * 1.3)))
		av.AngularVelocity = Vector3.new(0, -steer * turn * speedFactor * (fwd >= 0 and 1 or -1), 0)

		-- retournement automatique
		if chassis.CFrame.UpVector.Y < 0.35 then
			flipTimer += dt
			if flipTimer > 1.5 then
				flipTimer = 0
				uprightReset(chassis)
			end
		else
			flipTimer = 0
		end

		camera.FieldOfView = camera.FieldOfView + ((70 + math.clamp(math.abs(fwd) / maxSpeed, 0, 1.3) * 16 + (boosting and 6 or 0)) - camera.FieldOfView) * math.min(1, dt * 4)
		VehicleController.Updated:Fire(math.abs(fwd), boost / Config.BoostMax, true, steer, throttle, maxSpeed, fwd)
	end)
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Seated:Connect(function(active, seat)
		if active and seat and seat:IsA("VehicleSeat") and seat:GetAttribute("CRVehicle") then
			startDriving(hum, seat)
		end
	end)
end

function VehicleController.init()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonX then
			boostHeld = true
		elseif input.KeyCode == Enum.KeyCode.R and not processed and VehicleController.Driving then
			local c = player.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			if seat and seat.Parent and seat.Parent.PrimaryPart then
				uprightReset(seat.Parent.PrimaryPart)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonX then
			boostHeld = false
		end
	end)
end

return VehicleController

-- Caméra de course : derrière et au-dessus du cavalier, regardant vers +Z (sens de la piste).
-- Actif pendant la course ; en spectateur, suit le leader. Sinon, caméra Roblox par défaut.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)

local CameraRig = {}

local player = Players.LocalPlayer
local active = false
local pos = Vector3.new(0, 0, 0)
local lastFocus = nil
local speedSmooth = 0
local shakeUntil = 0
local shakePower = 0

local function hrpOf(plr)
	local char = plr and plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function focusPart()
	local s = ClientState.Status
	if s == "Riding" or s == "Air" or s == "Hooking" or s == "Down" then
		return hrpOf(player)
	end
	if (s == "Out" or s == "Finished") and workspace:GetAttribute("Phase") == "Running" then
		-- spectateur : suivre le premier du classement encore en course
		for _, entry in ipairs(ClientState.Scores) do
			if entry.id ~= player.UserId and (entry.st == "Riding" or entry.st == "Air" or entry.st == "Hooking" or entry.st == "Down") then
				local other = Players:GetPlayerByUserId(entry.id)
				local part = hrpOf(other)
				if part then
					return part
				end
			end
		end
		return hrpOf(player)
	end
	return nil
end

function CameraRig.shake(power, seconds)
	shakePower = power
	shakeUntil = os.clock() + seconds
end

local function release(camera)
	if active then
		active = false
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
end

local function update(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local part = focusPart()
	if not part then
		release(camera)
		lastFocus = nil
		return
	end

	local focus = part.Position
	local snap = false
	if not active then
		active = true
		snap = true
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local desired = focus + Vector3.new(0, 14, -30)
	if snap then
		pos = desired
	else
		pos = pos:Lerp(desired, 1 - math.exp(-dt * 9))
	end

	local cf = CFrame.lookAt(pos, focus + Vector3.new(0, 3, 36))
	if os.clock() < shakeUntil then
		local k = shakePower * (shakeUntil - os.clock())
		cf = cf * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end
	camera.CFrame = cf

	-- champ de vision selon la vitesse
	if lastFocus and dt > 0 then
		local speed = (focus - lastFocus).Magnitude / dt
		speedSmooth = speedSmooth + (math.min(speed, 120) - speedSmooth) * math.min(1, dt * 3)
	end
	lastFocus = focus
	camera.FieldOfView = 70 + math.clamp(speedSmooth / 70, 0, 1) * 16
end

function CameraRig.init()
	RunService:BindToRenderStep("HerdHopperCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraRig

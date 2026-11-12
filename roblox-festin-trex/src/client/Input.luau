--!nonstrict
-- Entrées : clic souris, tap tactile (distingué d'un glissement de caméra), bouton LANCER, gâchette de manette.
-- Le client n'envoie que le point visé ; le serveur décide de tout le reste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Store = require(script.Parent.Store)

local Input = {}

local localPlayer = Players.LocalPlayer
local throwRemote: any
local lastSent = 0
local touches: { [InputObject]: { pos: Vector3, t: number } } = {}

local TAP_MAX_DISTANCE = 14 -- pixels
local TAP_MAX_TIME = 0.35 -- secondes
local RAY_LENGTH = 600
local FALLBACK_DISTANCE = 80

local function aimFromRay(ray: Ray): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character)
	end
	local pets = workspace:FindFirstChild("LocalPets")
	if pets then
		table.insert(ignore, pets)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * FALLBACK_DISTANCE
end

local function send(aim: Vector3)
	local state = Store.state
	if not state then
		return
	end
	local now = os.clock()
	-- Anti-spam local : le serveur applique de toute façon la vraie cadence.
	if now - lastSent < state.stats.cooldown * 0.8 then
		return
	end
	lastSent = now
	throwRemote:FireServer(aim)
end

local function throwAtScreen(x: number, y: number)
	local cam = workspace.CurrentCamera
	if cam then
		send(aimFromRay(cam:ScreenPointToRay(x, y)))
	end
end

function Input.throwCenter()
	local cam = workspace.CurrentCamera
	if cam then
		local size = cam.ViewportSize
		send(aimFromRay(cam:ViewportPointToRay(size.X / 2, size.Y / 2)))
	end
end

function Input.init()
	throwRemote = Remotes.get("Throw")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 then
			throwAtScreen(input.Position.X, input.Position.Y)
		elseif kind == Enum.UserInputType.Touch then
			touches[input] = { pos = input.Position, t = os.clock() }
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.F then
			Input.throwCenter()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local info = touches[input]
		if not info then
			return
		end
		touches[input] = nil
		local moved = (input.Position - info.pos).Magnitude
		if moved <= TAP_MAX_DISTANCE and os.clock() - info.t <= TAP_MAX_TIME then
			throwAtScreen(input.Position.X, input.Position.Y)
		end
	end)
end

return Input

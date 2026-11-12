-- Mur de lave : avance de plus en plus vite. Les joueurs rattrapés sont éliminés (voir RideService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)

local WallService = {}

local wall = nil

local function place()
	if wall then
		wall.CFrame = CFrame.new(0, 35, State.WallZ - 8)
	end
end

function WallService.Init(wallPart)
	wall = wallPart
	WallService.Reset()
end

function WallService.Reset()
	State.WallZ = Config.Wall.StartZ
	State.RunElapsed = 0
	place()
end

function WallService.Speed()
	return math.min(Config.Wall.MaxSpeed, Config.Wall.Speed0 + Config.Wall.Accel * State.RunElapsed)
end

function WallService.Step(dt)
	State.RunElapsed = State.RunElapsed + dt
	State.WallZ = State.WallZ + WallService.Speed() * dt
	place()
end

return WallService

--!nonstrict
-- Éléments de décor animés côté client : objets rotatifs, jump pads,
-- contours des coéquipiers en mode équipe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local World = {}

local player = Players.LocalPlayer
local spinning = {}

local function register(part)
	if part:IsA("BasePart") and not spinning[part] then
		spinning[part] = { Base = part.Position, Phase = math.random() * 6.28 }
	end
end

local function setupSpin()
	for _, part in ipairs(CollectionService:GetTagged("Spin")) do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(part)
		spinning[part] = nil
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for part, info in pairs(spinning) do
			if part.Parent then
				part.CFrame = CFrame.new(info.Base + Vector3.new(0, math.sin(t * 2 + info.Phase) * 0.5, 0)) * CFrame.Angles(0, t * 1.5 + info.Phase, 0)
			else
				spinning[part] = nil
			end
		end
	end)
end

local function setupJumpPads()
	local function onCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local last = 0
		root.Touched:Connect(function(hit)
			if hit:GetAttribute("JumpPad") and os.clock() - last > 0.6 then
				last = os.clock()
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, hit:GetAttribute("Power") or 70, v.Z)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- Contour (visible à travers les murs) des coéquipiers en mode équipe.
local function setupTeamOutlines()
	local outlines = {}
	local function clear(p)
		if outlines[p] then
			outlines[p]:Destroy()
			outlines[p] = nil
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.75)
			local team = player:GetAttribute("Team")
			local teamMode = workspace:GetAttribute("MatchMode") == "TEAM" and player:GetAttribute("InArena") and team ~= nil and team ~= ""
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local char = other.Character
					local ally = teamMode and char and other:GetAttribute("InArena") and other:GetAttribute("Team") == team
					if ally then
						if not outlines[other] or outlines[other].Adornee ~= char then
							clear(other)
							local hl = Instance.new("Highlight")
							hl.FillTransparency = 1
							hl.OutlineColor = Color3.fromHex(Config.TeamColors[team])
							hl.OutlineTransparency = 0
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Adornee = char
							hl.Parent = char
							outlines[other] = hl
						end
					else
						clear(other)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(clear)
end

function World.Init()
	setupSpin()
	setupJumpPads()
	setupTeamOutlines()
end

return World
